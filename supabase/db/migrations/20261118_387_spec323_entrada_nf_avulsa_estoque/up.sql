-- Tambem corrige: cancelar nota avulsa (sem pedido) quebrava ao ler v_ped nao atribuido.
-- SPEC-323 A3 (Central 18/11/2026, Debora): entrada de NF AVULSA (sem pedido) com quantidade que SOMA no Estoque Geral.
-- O fornecedor da nota e livre (independe do fornecedor principal da peca). Contas a Pagar NAO e aberto aqui (decisao A4 pendente).
-- Cancelar a nota avulsa devolve a quantidade (mesma regra das notas de pedido). Sem sobrecarga: funcao nova + cancelar reescrita (mesma assinatura).
BEGIN;
ALTER TABLE public.notas_fiscais_compra ADD COLUMN IF NOT EXISTS quantidade_avulsa numeric(14,3) CHECK (quantidade_avulsa IS NULL OR quantidade_avulsa > 0);

CREATE OR REPLACE FUNCTION public.registrar_entrada_nota_avulsa(
  p_fornecedor_id uuid, p_empresa_id uuid, p_produto_id uuid, p_quantidade numeric, p_nota jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_numero_nf text := nullif(trim(coalesce(p_nota->>'numero_nf', '')), '');
  v_qtd       numeric := round(coalesce(p_quantidade, 0), 3);
  v_nota_id   uuid;
BEGIN
  IF NOT public.hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar') THEN
    RAISE EXCEPTION 'Sem permissao para dar entrada de nota fiscal.' USING ERRCODE = '42501';
  END IF;
  IF v_numero_nf IS NULL THEN
    RAISE EXCEPTION 'Informe o numero da nota fiscal.' USING ERRCODE = 'P0001';
  END IF;
  IF p_fornecedor_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.contatos WHERE id = p_fornecedor_id) THEN
    RAISE EXCEPTION 'Fornecedor nao encontrado.' USING ERRCODE = 'P0001';
  END IF;
  IF v_qtd < 0 THEN
    RAISE EXCEPTION 'Quantidade nao pode ser negativa.' USING ERRCODE = 'P0001';
  END IF;
  IF v_qtd > 0 AND (p_produto_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.produtos WHERE id = p_produto_id)) THEN
    RAISE EXCEPTION 'Escolha a peca para somar a quantidade no estoque.' USING ERRCODE = 'P0001';
  END IF;
  IF EXISTS (SELECT 1 FROM public.notas_fiscais_compra
              WHERE pedido_compra_id IS NULL AND fornecedor_id = p_fornecedor_id
                AND trim(numero_nf) = v_numero_nf AND cancelada_em IS NULL) THEN
    RAISE EXCEPTION 'A nota % deste fornecedor ja foi registrada.', v_numero_nf USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.notas_fiscais_compra
    (pedido_compra_id, fornecedor_id, empresa_id, produto_id, numero_nf, data_emissao, valor,
     observacao, arquivo_url, criado_por, quantidade_avulsa, data_entrada)
  VALUES (NULL, p_fornecedor_id, p_empresa_id, p_produto_id, v_numero_nf,
          nullif(p_nota->>'data_emissao', '')::date,
          nullif(round(coalesce(nullif(p_nota->>'valor', '')::numeric, 0), 2), 0),
          nullif(trim(coalesce(p_nota->>'observacao', '')), ''), nullif(p_nota->>'arquivo_url', ''),
          auth.uid(), nullif(v_qtd, 0), current_date)
  RETURNING id INTO v_nota_id;

  IF v_qtd > 0 THEN
    INSERT INTO public.estoque_itens (produto_id, local, quantidade, quantidade_reservada, atualizado_em)
    VALUES (p_produto_id, 'Estoque'::public.estoque_local, 0, 0, now())
    ON CONFLICT (produto_id, local) DO NOTHING;
    UPDATE public.estoque_itens SET quantidade = quantidade + v_qtd, atualizado_em = now()
     WHERE produto_id = p_produto_id AND local = 'Estoque'::public.estoque_local;
    UPDATE public.notas_fiscais_compra SET estoque_somado_em = now() WHERE id = v_nota_id;
  END IF;

  RETURN jsonb_build_object('nota_id', v_nota_id, 'estoque_somado', v_qtd);
END;
$function$;
REVOKE ALL ON FUNCTION public.registrar_entrada_nota_avulsa(uuid, uuid, uuid, numeric, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.registrar_entrada_nota_avulsa(uuid, uuid, uuid, numeric, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION public.cancelar_entrada_nota_compra(p_nota_id uuid, p_motivo text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_nota      record;
  v_ped       record;
  v_motivo    text := nullif(trim(coalesce(p_motivo, '')), '');
  v_itens     integer := 0;
  v_parcelas  integer := 0;
  v_antecip   numeric := 0;
  v_novo      text;
  v_vinc      record;
  v_reserva   numeric;
  v_desfeito  numeric := 0;
  v_est       record;
  v_tirado    numeric := 0;
  v_pgex      numeric := 0;
  v_ped_numero text;
BEGIN
  IF NOT public.hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar') THEN
    RAISE EXCEPTION 'Sem permissao para cancelar entrada de nota fiscal.' USING ERRCODE = '42501';
  END IF;
  IF v_motivo IS NULL THEN
    RAISE EXCEPTION 'Informe o motivo do cancelamento.' USING ERRCODE = 'P0001';
  END IF;

  SELECT id, numero_nf, pedido_compra_id, cancelada_em, estoque_somado_em, produto_id, quantidade_avulsa INTO v_nota
    FROM public.notas_fiscais_compra WHERE id = p_nota_id FOR UPDATE;
  IF v_nota.id IS NULL THEN
    RAISE EXCEPTION 'Nota fiscal nao encontrada.' USING ERRCODE = 'P0001';
  END IF;
  IF v_nota.cancelada_em IS NOT NULL THEN
    RAISE EXCEPTION 'A nota % ja foi cancelada.', v_nota.numero_nf USING ERRCODE = 'P0001';
  END IF;

  -- SPEC-222: tira do estoque físico o que esta nota somou (notas anteriores à 234 não somaram nada).
  IF v_nota.estoque_somado_em IS NOT NULL THEN
    FOR v_est IN
      SELECT pi.produto_id, p.codigo_produto, sum(x.quantidade) AS quantidade
        FROM public.nota_fiscal_compra_itens x
        JOIN public.pedido_compra_itens pi ON pi.id = x.pedido_item_id
        JOIN public.produtos p ON p.id = pi.produto_id
       WHERE x.nota_id = p_nota_id
       GROUP BY pi.produto_id, p.codigo_produto
    LOOP
      SELECT quantidade INTO v_reserva FROM public.estoque_itens
       WHERE produto_id = v_est.produto_id AND local = 'Estoque'::public.estoque_local FOR UPDATE;
      IF coalesce(v_reserva, 0) < v_est.quantidade THEN
        RAISE EXCEPTION 'A peca % tem % no estoque e esta nota deu entrada em %: parte ja saiu. Acerte o estoque antes de cancelar.',
          v_est.codigo_produto, coalesce(v_reserva, 0), v_est.quantidade USING ERRCODE = 'P0001';
      END IF;
      UPDATE public.estoque_itens
         SET quantidade = quantidade - v_est.quantidade, atualizado_em = now()
       WHERE produto_id = v_est.produto_id AND local = 'Estoque'::public.estoque_local;
      v_tirado := v_tirado + v_est.quantidade;
    END LOOP;
  END IF;

  -- SPEC-323 A3: entrada avulsa que somou estoque (sem pedido): tira a quantidade da nota do Estoque Geral.
  IF v_nota.estoque_somado_em IS NOT NULL AND v_nota.pedido_compra_id IS NULL
     AND v_nota.produto_id IS NOT NULL AND coalesce(v_nota.quantidade_avulsa, 0) > 0 THEN
    SELECT quantidade INTO v_reserva FROM public.estoque_itens
     WHERE produto_id = v_nota.produto_id AND local = 'Estoque'::public.estoque_local FOR UPDATE;
    IF coalesce(v_reserva, 0) < v_nota.quantidade_avulsa THEN
      RAISE EXCEPTION 'A peca tem % no estoque e esta nota deu entrada em %: parte ja saiu. Acerte o estoque antes de cancelar.',
        coalesce(v_reserva, 0), v_nota.quantidade_avulsa USING ERRCODE = 'P0001';
    END IF;
    UPDATE public.estoque_itens
       SET quantidade = quantidade - v_nota.quantidade_avulsa, atualizado_em = now()
     WHERE produto_id = v_nota.produto_id AND local = 'Estoque'::public.estoque_local;
    v_tirado := v_tirado + v_nota.quantidade_avulsa;
  END IF;

  -- SPEC-220: o que foi para a reserva volta para a entrega futura (se já foi separado, não dá para cancelar).
  FOR v_vinc IN SELECT * FROM public.nota_fiscal_compra_vinculos WHERE nota_id = p_nota_id
  LOOP
    SELECT q_reserva INTO v_reserva FROM public.estoque_saldos_projeto_item
     WHERE projeto_item_id = v_vinc.projeto_item_id FOR UPDATE;
    IF coalesce(v_reserva, 0) < v_vinc.quantidade THEN
      RAISE EXCEPTION 'Parte do que chegou nesta nota ja saiu da reserva (separacao). Estorne a separacao antes de cancelar.'
        USING ERRCODE = 'P0001';
    END IF;
    UPDATE public.estoque_saldos_projeto_item
       SET q_reserva = q_reserva - v_vinc.quantidade,
           q_entrega_futura = q_entrega_futura + v_vinc.quantidade,
           atualizado_em = now()
     WHERE projeto_item_id = v_vinc.projeto_item_id;
    INSERT INTO public.estoque_movimentos_projeto_item
      (projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por)
    VALUES (v_vinc.projeto_item_id, 'cancelamento', v_vinc.quantidade, 'nota_fiscal_compra', p_nota_id,
            format('Cancelada a NF %s: reserva -> entrega futura (%s)', v_nota.numero_nf, v_motivo), auth.uid());
    v_desfeito := v_desfeito + v_vinc.quantidade;
  END LOOP;
  DELETE FROM public.nota_fiscal_compra_vinculos WHERE nota_id = p_nota_id;

  IF v_nota.pedido_compra_id IS NOT NULL THEN
    SELECT id, numero, status INTO v_ped FROM public.pedidos_compra WHERE id = v_nota.pedido_compra_id FOR UPDATE;
    v_ped_numero := v_ped.numero;

    -- Devolve o que entrou por esta nota
    UPDATE public.pedido_compra_itens i
       SET qtd_recebida = greatest(0, i.qtd_recebida - x.quantidade)
      FROM public.nota_fiscal_compra_itens x
     WHERE x.nota_id = p_nota_id AND x.pedido_item_id = i.id;
    GET DIAGNOSTICS v_itens = ROW_COUNT;

    -- Status pelo que sobrou recebido. SPEC-222 D1: sem nada recebido volta para "Aguardando aprovar" (editar ou cancelar)
    IF v_ped.status <> 'cancelado' THEN
      SELECT CASE WHEN bool_and(qtd_recebida >= quantidade) THEN 'recebido'
                  WHEN bool_or(qtd_recebida > 0) THEN 'parcialmente_recebido'
                  ELSE 'aguardando_aprovar' END
        INTO v_novo FROM public.pedido_compra_itens WHERE pedido_id = v_ped.id;
      UPDATE public.pedidos_compra
         SET status = coalesce(v_novo, status),
             recebido_em = CASE WHEN v_novo = 'recebido' THEN recebido_em END,
             primeira_entrada_em = CASE WHEN v_novo = 'aguardando_aprovar' THEN NULL ELSE primeira_entrada_em END,
             aprovado_por = CASE WHEN v_novo = 'aguardando_aprovar' THEN NULL ELSE aprovado_por END,
             aprovado_em = CASE WHEN v_novo = 'aguardando_aprovar' THEN NULL ELSE aprovado_em END,
             atualizado_em = now()
       WHERE id = v_ped.id;
    END IF;
  END IF;

  -- Parcelas da nota saem do A Pagar; antecipação usada volta a ter saldo
  DELETE FROM public.nota_fiscal_compra_parcelas WHERE nota_id = p_nota_id;
  GET DIAGNOSTICS v_parcelas = ROW_COUNT;
  SELECT coalesce(sum(valor_aplicado), 0) INTO v_antecip FROM public.pagamento_antecipado_vinculos WHERE nota_id = p_nota_id;
  DELETE FROM public.pagamento_antecipado_vinculos WHERE nota_id = p_nota_id;
  -- SPEC-290 B5: o vinculo com pagamento ja existente (duplicata da Connect) e cancelado; a duplicata em si permanece intacta
  WITH u AS (
    UPDATE public.pagamento_existente_vinculos
       SET cancelado_em = now(), cancelado_por = auth.uid(), motivo_cancelamento = v_motivo
     WHERE nota_id = p_nota_id AND cancelado_em IS NULL
    RETURNING valor_aplicado)
  SELECT coalesce(sum(valor_aplicado), 0) INTO v_pgex FROM u;

  UPDATE public.notas_fiscais_compra
     SET cancelada_em = now(), cancelada_por = auth.uid(), motivo_cancelamento = v_motivo
   WHERE id = p_nota_id;

  RETURN jsonb_build_object('nota_id', p_nota_id, 'numero_nf', v_nota.numero_nf,
                            'pedido_numero', v_ped_numero, 'pedido_status', v_novo,
                            'itens_devolvidos', v_itens, 'parcelas_removidas', v_parcelas,
                            'antecipacao_devolvida', v_antecip, 'vinculo_pagamento_cancelado', v_pgex, 'reserva_desfeita', v_desfeito,
                            'estoque_retirado', v_tirado);
END;
$function$;

COMMIT;
