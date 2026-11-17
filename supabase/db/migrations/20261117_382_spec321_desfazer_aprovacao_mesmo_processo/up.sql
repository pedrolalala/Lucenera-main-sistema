-- SPEC-321 (parte 2): desfazer aprovação financeira segue o mesmo processo do cancelamento e o financeiro (Caroline) pode usar.
BEGIN;

-- tipo do aviso: venda cancelada x aprovação desfeita
ALTER TABLE public.pedido_compra_aviso_cancelamento ADD COLUMN IF NOT EXISTS tipo text NOT NULL DEFAULT 'cancelamento';

-- Grava o aviso para a Compras (um por pedido em andamento ligado à venda) e solta o destino por projeto.
-- Chamar ANTES de apagar os itens do projeto (o vínculo de origem some em cascata).
CREATE OR REPLACE FUNCTION public._avisar_pedidos_da_venda(p_orcamento_id uuid, p_motivo text, p_tipo text)
 RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
DECLARE
  o public.orcamentos%ROWTYPE;
  v_quem text; v_cliente text; v_proj text; v_ped record; v_n integer := 0;
BEGIN
  SELECT * INTO o FROM public.orcamentos WHERE id = p_orcamento_id;
  SELECT nome INTO v_quem FROM public.usuarios WHERE id = auth.uid();
  SELECT c.nome INTO v_cliente FROM public.contatos c WHERE c.id = o.cliente_id;
  SELECT pr.codigo::text INTO v_proj FROM public.projetos pr WHERE pr.id = o.projeto_id;
  FOR v_ped IN
    SELECT ids.pedido_id,
           (SELECT jsonb_agg(jsonb_build_object('produto', p.nome, 'codigo', p.codigo_produto, 'quantidade', t.qtd) ORDER BY p.nome)
              FROM (SELECT i.produto_id, sum(i.quantidade) qtd FROM public.pedido_compra_itens i
                     WHERE i.pedido_id = ids.pedido_id AND i.id = ANY (ids.itens) GROUP BY i.produto_id) t
              JOIN public.produtos p ON p.id = t.produto_id) AS itens
      FROM (
        SELECT i.pedido_id, array_agg(DISTINCT i.id) AS itens
          FROM public.pedido_compra_itens i
         WHERE i.id IN (SELECT o2.pedido_compra_item_id FROM public.pedido_compra_item_origem o2
                          JOIN public.projeto_itens pi ON pi.id = o2.projeto_item_id WHERE pi.orcamento_id = p_orcamento_id)
            OR i.id IN (SELECT d.pedido_compra_item_id FROM public.pedido_compra_item_destino_projeto d
                         WHERE d.projeto_id = o.projeto_id AND d.liberado_em IS NULL)
         GROUP BY i.pedido_id
      ) ids
      JOIN public.pedidos_compra pc ON pc.id = ids.pedido_id AND pc.status NOT IN ('cancelado', 'recebido')
  LOOP
    INSERT INTO public.pedido_compra_aviso_cancelamento
        (pedido_id, orcamento_id, orcamento_numero, venda_numero, projeto_codigo, cliente_nome, motivo, itens, cancelado_por, cancelado_por_nome, tipo)
    VALUES (v_ped.pedido_id, p_orcamento_id, o.numero, o.numero_venda, v_proj, v_cliente, btrim(p_motivo),
            coalesce(v_ped.itens, '[]'::jsonb), auth.uid(), coalesce(v_quem, 'Usuário'), p_tipo);
    v_n := v_n + 1;
  END LOOP;
  IF o.projeto_id IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM public.orcamentos o3
        WHERE o3.projeto_id = o.projeto_id AND o3.id <> p_orcamento_id
          AND o3.status IN ('Orçamento Aprovado', 'Aprovação Financeira', 'Aprovação da Equipe', 'enviado_cliente', 'aprovado')) THEN
    UPDATE public.pedido_compra_item_destino_projeto
       SET liberado_em = now(), liberado_por = auth.uid(),
           motivo_liberacao = left('Aprovação da venda ' || coalesce(o.numero_venda, o.numero) || ' desfeita por ' || coalesce(v_quem, 'usuário') || ': ' || btrim(p_motivo), 500)
     WHERE projeto_id = o.projeto_id AND liberado_em IS NULL;
  END IF;
  RETURN v_n;
END $f$;
REVOKE ALL ON FUNCTION public._avisar_pedidos_da_venda(uuid, text, text) FROM PUBLIC, anon, authenticated;

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
  v_avisos integer := 0;
BEGIN
  IF p_motivo IS NULL OR btrim(p_motivo) = '' THEN
    RAISE EXCEPTION 'Informe o motivo antes de desfazer a aprovação financeira.' USING ERRCODE = 'P0001';
  END IF;

  SELECT u.role INTO v_user_role FROM public.usuarios u WHERE u.id = auth.uid();

  -- SPEC-321: quem trabalha no financeiro (acesso 'financeiro', ex.: Caroline) também desfaz a aprovação.
  IF NOT (
    COALESCE(auth.role(), '') = 'service_role'
    OR v_user_role IN ('admin', 'gerente')
    OR (auth.uid() IS NOT NULL AND (SELECT public.pode_acessar_sistema('financeiro')))
  ) THEN
    RAISE EXCEPTION 'Apenas admin, gerente ou o financeiro podem desfazer uma aprovação financeira.' USING ERRCODE = 'P0001';
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

  -- SPEC-321: pedido de compra em andamento NÃO bloqueia mais: avisa a Compras, solta o destino por projeto
  -- e o vínculo de origem cai junto com os itens do projeto (as peças entram no Estoque Geral ao chegar).
  v_avisos := public._avisar_pedidos_da_venda(p_orcamento_id, p_motivo, 'aprovacao_desfeita');

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
  VALUES (p_orcamento_id, v_status_anterior, 'Aprovação Financeira', auth.uid()::text,
    p_motivo || CASE WHEN v_avisos > 0 THEN format(' | %s pedido(s) de compra em andamento liberado(s): as peças entram no Estoque Geral ao chegar', v_avisos) ELSE '' END);

  RETURN jsonb_build_object(
    'orcamento_id', p_orcamento_id,
    'numero', v_numero,
    'status', 'Aprovação Financeira',
    'projeto_itens_apagados', v_itens_apagados,
    'parcelas_apagadas', v_parcelas_apagadas,
    'boletos_apagados', v_boletos_apagados,
    'pedidos_avisados', v_avisos
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.desfazer_aprovacao_financeira(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.desfazer_aprovacao_financeira(uuid, text) TO authenticated, service_role;

COMMIT;
