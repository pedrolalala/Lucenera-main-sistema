-- SPEC-321 parte 2 rollback: volta o desfazer_aprovacao_financeira anterior (só admin/gerente; bloqueia com pedido de compra).
CREATE OR REPLACE FUNCTION public.desfazer_aprovacao_financeira(p_orcamento_id uuid, p_motivo text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_orcamento public.orcamentos%ROWTYPE;
  v_status_anterior text;
  v_numero text;
  v_user_role text;
  v_item record;
  v_itens_apagados integer := 0;
  v_parcelas_apagadas integer := 0;
  v_boletos_apagados integer := 0;
BEGIN
  IF p_motivo IS NULL OR btrim(p_motivo) = '' THEN
    RAISE EXCEPTION 'Informe o motivo antes de desfazer a aprovação financeira.' USING ERRCODE = 'P0001';
  END IF;

  SELECT u.role INTO v_user_role FROM public.usuarios u WHERE u.id = auth.uid();

  IF NOT (
    COALESCE(auth.role(), '') = 'service_role'
    OR v_user_role IN ('admin', 'gerente')
  ) THEN
    RAISE EXCEPTION 'Apenas admin ou gerente podem desfazer uma aprovação financeira.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_orcamento FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento não encontrado.' USING ERRCODE = 'P0001';
  END IF;

  -- SPEC-195: vínculo Connect não tem reserva para estornar — usar desvincular_orcamento_connect.
  IF v_orcamento.vinculo_connect THEN
    RAISE EXCEPTION 'Orçamento % é vínculo de venda da Connect — use "Desfazer vínculo".', coalesce(v_orcamento.numero, p_orcamento_id::text)
      USING ERRCODE = 'P0001';
  END IF;

  v_status_anterior := v_orcamento.status;
  v_numero := COALESCE(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.status <> 'Orçamento Aprovado' THEN
    RAISE EXCEPTION 'Orçamento % não está em Orçamento Aprovado. Status atual: %', v_numero, v_status_anterior
      USING ERRCODE = 'P0002';
  END IF;

  IF v_orcamento.natureza_operacao = 'devolucao' THEN
    RAISE EXCEPTION 'Orçamento % é de devolução — desfazer aprovação financeira de devolução não é suportado.', v_numero
      USING ERRCODE = 'P0001';
  END IF;

  -- SPEC-234 A: uso e consumo / descarte já baixaram o Estoque Geral (não há item de projeto para desfazer).
  IF public.tipo_operacao_regra(v_orcamento.natureza_operacao, v_orcamento.subgrupo) = 'baixa_direta' THEN
    RAISE EXCEPTION 'Orçamento % (%) já baixou o Estoque Geral — para voltar a peça, faça a entrada pela Movimentação de Peças.', v_numero, v_orcamento.subgrupo
      USING ERRCODE = 'P0001';
  END IF;

  -- Bloqueios: algo já consumiu o que essa aprovação criou.
  IF EXISTS (
    SELECT 1 FROM public.boletos b WHERE b.orcamento_id = p_orcamento_id AND b.status <> 'pendente_registro'
  ) THEN
    RAISE EXCEPTION 'Orçamento % tem boleto com status diferente de "pendente_registro" — não pode desfazer (já foi remessado/pago).', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.notas_fiscais nf
    JOIN public.boletos b ON b.id = nf.boleto_id
    WHERE b.orcamento_id = p_orcamento_id
  ) THEN
    RAISE EXCEPTION 'Orçamento % já tem nota fiscal emitida sobre um dos boletos — não pode desfazer.', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.retorno_bancario_registros rbr
    WHERE rbr.boleto_id IN (SELECT id FROM public.boletos WHERE orcamento_id = p_orcamento_id)
       OR rbr.parcela_id IN (SELECT id FROM public.projeto_parcelas WHERE orcamento_id = p_orcamento_id)
  ) THEN
    RAISE EXCEPTION 'Orçamento % já tem retorno bancário registrado — não pode desfazer.', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.projeto_parcelas pp WHERE pp.orcamento_id = p_orcamento_id AND pp.status <> 'pendente'
  ) THEN
    RAISE EXCEPTION 'Orçamento % tem parcela com status diferente de "pendente" — não pode desfazer.', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.transacoes t
    WHERE t.parcela_id IN (SELECT id FROM public.projeto_parcelas WHERE orcamento_id = p_orcamento_id)
      AND t.status_pago <> 0 -- SPEC-246: a transação em aberto da aprovação é cancelada pelo gatilho ao apagar a parcela
  ) THEN
    RAISE EXCEPTION 'Orçamento % já tem transação financeira lançada — não pode desfazer.', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.devolucoes_estoque de
    WHERE de.projeto_item_id IN (SELECT id FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id)
  ) THEN
    RAISE EXCEPTION 'Orçamento % já teve item devolvido ao estoque — não pode desfazer.', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.separacao_itens si
    WHERE si.projeto_item_id IN (SELECT id FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id)
  ) THEN
    RAISE EXCEPTION 'Orçamento % já teve item separado para entrega — não pode desfazer.', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.transferencias_estoque te
    WHERE te.origem_projeto_item_id IN (SELECT id FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id)
       OR te.destino_projeto_item_id IN (SELECT id FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id)
  ) THEN
    RAISE EXCEPTION 'Orçamento % já teve item usado em transferência de estoque — não pode desfazer.', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.pedido_compra_item_origem pio
    WHERE pio.projeto_item_id IN (SELECT id FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id)
  ) THEN
    RAISE EXCEPTION 'Orçamento % já teve item usado como origem de pedido de compra — não pode desfazer.', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.orcamento_itens oi
    WHERE oi.projeto_item_origem_id IN (SELECT id FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id)
  ) THEN
    RAISE EXCEPTION 'Orçamento % já teve item usado como origem de um orçamento de devolução — não pode desfazer.', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  -- Nenhum bloqueio: desfaz reserva de estoque item a item, depois apaga em cascata manual.
  FOR v_item IN
    SELECT id, produto_id, quantidade FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id
  LOOP
    IF v_item.produto_id IS NOT NULL AND COALESCE(v_item.quantidade, 0) > 0 THEN
      UPDATE public.estoque_itens
      SET quantidade_reservada = GREATEST(0, quantidade_reservada - v_item.quantidade),
          atualizado_em = NOW()
      WHERE produto_id = v_item.produto_id AND local = 'Estoque'::public.estoque_local;

      INSERT INTO public.estoque_movimentos_projeto_item (
        projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por
      ) VALUES (
        v_item.id, 'estorno_aprovacao_orcamento', v_item.quantidade, 'desfazer_aprovacao_financeira', p_orcamento_id,
        format('Estorno de reserva ao desfazer aprovação do orçamento %s: %s', v_numero, p_motivo),
        auth.uid()
      );
    END IF;
  END LOOP;

  DELETE FROM public.estoque_saldos_projeto_item
  WHERE projeto_item_id IN (SELECT id FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id);

  DELETE FROM public.boletos WHERE orcamento_id = p_orcamento_id;
  GET DIAGNOSTICS v_boletos_apagados = ROW_COUNT;

  DELETE FROM public.projeto_parcelas WHERE orcamento_id = p_orcamento_id;
  GET DIAGNOSTICS v_parcelas_apagadas = ROW_COUNT;

  DELETE FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id;
  GET DIAGNOSTICS v_itens_apagados = ROW_COUNT;

  UPDATE public.orcamentos
  SET status = 'Aprovação Financeira',
      requer_revisao_financeira = true
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (p_orcamento_id, v_status_anterior, 'Aprovação Financeira', auth.uid()::text, p_motivo);

  RETURN jsonb_build_object(
    'orcamento_id', p_orcamento_id,
    'numero', v_numero,
    'status', 'Aprovação Financeira',
    'projeto_itens_apagados', v_itens_apagados,
    'parcelas_apagadas', v_parcelas_apagadas,
    'boletos_apagados', v_boletos_apagados
  );
END;
$function$;
DROP FUNCTION IF EXISTS public._avisar_pedidos_da_venda(uuid, text, text);
