-- Rollback SPEC-222 A: tira do estoque o que as notas ativas somaram e volta as funções da migration 233.
-- Sem BEGIN/COMMIT.

UPDATE public.estoque_itens e
   SET quantidade = e.quantidade - s.quantidade, atualizado_em = now()
  FROM (SELECT pi.produto_id, sum(x.quantidade) AS quantidade
          FROM public.notas_fiscais_compra n
          JOIN public.nota_fiscal_compra_itens x ON x.nota_id = n.id
          JOIN public.pedido_compra_itens pi ON pi.id = x.pedido_item_id
         WHERE n.cancelada_em IS NULL AND n.estoque_somado_em IS NOT NULL
         GROUP BY pi.produto_id) s
 WHERE e.produto_id = s.produto_id AND e.local = 'Estoque'::public.estoque_local;

CREATE OR REPLACE FUNCTION public.registrar_entrada_nota_compra(p_pedido_id uuid, p_itens jsonb, p_nota jsonb, p_parcelas jsonb DEFAULT '[]'::jsonb, p_antecipacoes jsonb DEFAULT '[]'::jsonb, p_fornecedor_id uuid DEFAULT NULL::uuid, p_vinculos jsonb DEFAULT '[]'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_ped        record;
  v_forn       uuid;
  v_numero_nf  text := nullif(trim(coalesce(p_nota->>'numero_nf', '')), '');
  v_valor      numeric := round(coalesce(nullif(p_nota->>'valor', '')::numeric, 0), 2);
  v_chave      text := nullif(regexp_replace(coalesce(p_nota->>'chave_acesso', ''), '\D', '', 'g'), '');
  v_plano      uuid := nullif(p_nota->>'plano_contas_id', '')::uuid;
  v_nota_id    uuid;
  v_res        jsonb;
  v_el         jsonb;
  v_n          integer := 0;
  v_soma_parc  numeric := 0;
  v_aplicado   numeric := 0;
  v_pag        record;
  v_saldo      numeric;
  v_qtd        numeric;
  v_vinc       record;
  v_reservado  numeric := 0;
BEGIN
  IF NOT public.hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar') THEN
    RAISE EXCEPTION 'Sem permissao para dar entrada em pedido de compra.' USING ERRCODE = '42501';
  END IF;

  SELECT id, numero, status, fornecedor_id, empresa_id INTO v_ped
    FROM public.pedidos_compra WHERE id = p_pedido_id FOR UPDATE;
  IF v_ped.id IS NULL THEN
    RAISE EXCEPTION 'Pedido de compra nao encontrado.' USING ERRCODE = 'P0001';
  END IF;
  IF v_numero_nf IS NULL THEN
    RAISE EXCEPTION 'Informe o numero da nota fiscal.' USING ERRCODE = 'P0001';
  END IF;
  IF v_valor <= 0 THEN
    RAISE EXCEPTION 'Informe o valor total da nota.' USING ERRCODE = 'P0001';
  END IF;
  IF v_chave IS NOT NULL AND length(v_chave) <> 44 THEN
    RAISE EXCEPTION 'A chave de acesso tem 44 numeros (veio com %).', length(v_chave) USING ERRCODE = 'P0001';
  END IF;
  IF EXISTS (SELECT 1 FROM public.notas_fiscais_compra
              WHERE pedido_compra_id = p_pedido_id AND trim(numero_nf) = v_numero_nf AND cancelada_em IS NULL) THEN
    RAISE EXCEPTION 'A nota % ja foi registrada neste pedido.', v_numero_nf USING ERRCODE = 'P0001';
  END IF;
  -- Apropriação: a informada ou COMPRAS - REVENDA
  IF v_plano IS NULL THEN
    SELECT id INTO v_plano FROM public.plano_de_contas WHERE codigo_connect = 2050001;
  ELSIF NOT EXISTS (SELECT 1 FROM public.plano_de_contas WHERE id = v_plano) THEN
    RAISE EXCEPTION 'Apropriacao (plano de contas) nao encontrada.' USING ERRCODE = 'P0001';
  END IF;

  -- Fornecedor da nota diferente do pedido (ex.: pedido Emétris, nota Spot LED): o pedido passa a ser dele.
  v_forn := v_ped.fornecedor_id;
  IF p_fornecedor_id IS NOT NULL AND p_fornecedor_id IS DISTINCT FROM v_ped.fornecedor_id THEN
    IF NOT EXISTS (SELECT 1 FROM public.contatos WHERE id = p_fornecedor_id) THEN
      RAISE EXCEPTION 'Fornecedor nao encontrado.' USING ERRCODE = 'P0001';
    END IF;
    UPDATE public.pedidos_compra SET fornecedor_id = p_fornecedor_id, atualizado_em = now() WHERE id = p_pedido_id;
    v_forn := p_fornecedor_id;
  END IF;

  -- Quantidades (mesmas regras de antes; muda o status do pedido)
  v_res := public.registrar_entrada_pedido_compra(p_pedido_id, p_itens);

  INSERT INTO public.notas_fiscais_compra
    (pedido_compra_id, numero_nf, data_emissao, valor, valor_st, arquivo_url, observacao,
     criado_por, fornecedor_id, empresa_id,
     chave_acesso, data_entrega, data_entrada, plano_contas_id, valor_desconto, valor_despesas_acessorias)
  VALUES (p_pedido_id, v_numero_nf, nullif(p_nota->>'data_emissao', '')::date, v_valor,
          nullif(round(coalesce(nullif(p_nota->>'valor_st', '')::numeric, 0), 2), 0),
          nullif(p_nota->>'arquivo_url', ''), nullif(trim(coalesce(p_nota->>'observacao', '')), ''),
          auth.uid(), v_forn, v_ped.empresa_id,
          v_chave, nullif(p_nota->>'data_entrega', '')::date,
          coalesce(nullif(p_nota->>'data_entrada', '')::date, current_date), v_plano,
          nullif(round(coalesce(nullif(p_nota->>'valor_desconto', '')::numeric, 0), 2), 0),
          nullif(round(coalesce(nullif(p_nota->>'valor_despesas_acessorias', '')::numeric, 0), 2), 0))
  RETURNING id INTO v_nota_id;

  -- SPEC-218: quanto de cada item entrou por esta nota (o cancelamento devolve). SPEC-220: + valores da nota.
  INSERT INTO public.nota_fiscal_compra_itens
    (nota_id, pedido_item_id, quantidade, valor_unitario, valor_ipi, valor_icms, valor_st)
  SELECT v_nota_id, (e->>'pedido_item_id')::uuid, sum(nullif(e->>'quantidade', '')::numeric),
         max(nullif(e->>'valor_unitario', '')::numeric), max(nullif(e->>'valor_ipi', '')::numeric),
         max(nullif(e->>'valor_icms', '')::numeric), max(nullif(e->>'valor_st', '')::numeric)
    FROM jsonb_array_elements(coalesce(p_itens, '[]'::jsonb)) e
   WHERE coalesce(nullif(e->>'quantidade', '')::numeric, 0) > 0
   GROUP BY (e->>'pedido_item_id')::uuid;

  -- SPEC-220: vínculo com o cliente — entrega futura -> reserva, com limitador por peça e por L.
  FOR v_vinc IN
    SELECT (e->>'produto_id')::uuid AS produto_id, (e->>'projeto_item_id')::uuid AS projeto_item_id,
           sum(round(coalesce(nullif(e->>'quantidade', '')::numeric, 0), 3)) AS quantidade
      FROM jsonb_array_elements(coalesce(p_vinculos, '[]'::jsonb)) e
     GROUP BY 1, 2
  LOOP
    CONTINUE WHEN v_vinc.quantidade = 0;
    IF v_vinc.quantidade < 0 THEN
      RAISE EXCEPTION 'Quantidade vinculada nao pode ser negativa.' USING ERRCODE = 'P0001';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.projeto_itens WHERE id = v_vinc.projeto_item_id AND produto_id = v_vinc.produto_id) THEN
      RAISE EXCEPTION 'Vinculo com um L de outra peca.' USING ERRCODE = 'P0001';
    END IF;
    SELECT q_entrega_futura INTO v_saldo FROM public.estoque_saldos_projeto_item
     WHERE projeto_item_id = v_vinc.projeto_item_id FOR UPDATE;
    IF coalesce(v_saldo, 0) < v_vinc.quantidade THEN
      RAISE EXCEPTION 'O L espera % em entrega futura e foi vinculado %.', coalesce(v_saldo, 0), v_vinc.quantidade
        USING ERRCODE = 'P0001';
    END IF;
    UPDATE public.estoque_saldos_projeto_item
       SET q_entrega_futura = q_entrega_futura - v_vinc.quantidade,
           q_reserva = q_reserva + v_vinc.quantidade,
           atualizado_em = now()
     WHERE projeto_item_id = v_vinc.projeto_item_id;
    INSERT INTO public.estoque_movimentos_projeto_item
      (projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por)
    VALUES (v_vinc.projeto_item_id, 'recebimento_para_reserva', v_vinc.quantidade, 'nota_fiscal_compra', v_nota_id,
            format('NF %s (pedido %s): entrega futura -> reserva', v_numero_nf, v_ped.numero), auth.uid());
    INSERT INTO public.nota_fiscal_compra_vinculos (nota_id, produto_id, projeto_item_id, quantidade, criado_por)
    VALUES (v_nota_id, v_vinc.produto_id, v_vinc.projeto_item_id, v_vinc.quantidade, auth.uid());
    v_reservado := v_reservado + v_vinc.quantidade;
  END LOOP;

  -- Limitador por peça: o vinculado não passa do que chegou nesta nota.
  PERFORM 1
    FROM (SELECT produto_id, sum(quantidade) q FROM public.nota_fiscal_compra_vinculos WHERE nota_id = v_nota_id GROUP BY 1) v
    LEFT JOIN (SELECT pi.produto_id, sum(x.quantidade) q
                 FROM public.nota_fiscal_compra_itens x JOIN public.pedido_compra_itens pi ON pi.id = x.pedido_item_id
                WHERE x.nota_id = v_nota_id GROUP BY 1) c ON c.produto_id = v.produto_id
   WHERE v.q > coalesce(c.q, 0) + 0.0001;
  IF FOUND THEN
    RAISE EXCEPTION 'Vinculado aos clientes mais do que chegou de uma peca.' USING ERRCODE = 'P0001';
  END IF;

  -- Pagamentos antecipados usados nesta nota
  FOR v_el IN SELECT * FROM jsonb_array_elements(coalesce(p_antecipacoes, '[]'::jsonb))
  LOOP
    v_qtd := round(coalesce(nullif(v_el->>'valor', '')::numeric, 0), 2);
    CONTINUE WHEN v_qtd = 0;
    IF v_qtd < 0 THEN
      RAISE EXCEPTION 'Valor da antecipacao nao pode ser negativo.' USING ERRCODE = 'P0001';
    END IF;
    SELECT * INTO v_pag FROM public.pagamentos_antecipados
     WHERE id = (v_el->>'pagamento_id')::uuid FOR UPDATE;
    IF v_pag.id IS NULL OR v_pag.cancelado_em IS NOT NULL THEN
      RAISE EXCEPTION 'Pagamento antecipado nao encontrado ou cancelado.' USING ERRCODE = 'P0001';
    END IF;
    IF NOT (v_pag.fornecedor_id IN (v_ped.fornecedor_id, v_forn) OR v_pag.pedido_compra_id = p_pedido_id) THEN
      RAISE EXCEPTION 'Pagamento antecipado de outro fornecedor.' USING ERRCODE = 'P0001';
    END IF;
    v_saldo := v_pag.valor - coalesce((SELECT sum(valor_aplicado) FROM public.pagamento_antecipado_vinculos
                                        WHERE pagamento_id = v_pag.id), 0);
    IF v_qtd > v_saldo + 0.001 THEN
      RAISE EXCEPTION 'Valor usado (%) maior que o saldo do pagamento antecipado (%).', v_qtd, v_saldo
        USING ERRCODE = 'P0001';
    END IF;
    INSERT INTO public.pagamento_antecipado_vinculos (pagamento_id, nota_id, valor_aplicado, criado_por)
    VALUES (v_pag.id, v_nota_id, v_qtd, auth.uid());
    v_aplicado := v_aplicado + v_qtd;
  END LOOP;

  -- Parcelas da nota (o restante depois da antecipação)
  FOR v_el IN SELECT * FROM jsonb_array_elements(coalesce(p_parcelas, '[]'::jsonb))
  LOOP
    v_qtd := round(coalesce(nullif(v_el->>'valor', '')::numeric, 0), 2);
    IF v_qtd <= 0 THEN
      RAISE EXCEPTION 'Toda parcela precisa ter valor maior que zero.' USING ERRCODE = 'P0001';
    END IF;
    IF nullif(v_el->>'data_vencimento', '') IS NULL THEN
      RAISE EXCEPTION 'Toda parcela precisa ter vencimento.' USING ERRCODE = 'P0001';
    END IF;
    v_n := v_n + 1;
    INSERT INTO public.nota_fiscal_compra_parcelas (nota_id, numero_parcela, data_vencimento, valor)
    VALUES (v_nota_id, v_n, (v_el->>'data_vencimento')::date, v_qtd);
    v_soma_parc := v_soma_parc + v_qtd;
  END LOOP;

  IF v_aplicado > v_valor + 0.001 THEN
    RAISE EXCEPTION 'Antecipacao usada (%) maior que o valor da nota (%).', v_aplicado, v_valor USING ERRCODE = 'P0001';
  END IF;
  IF abs(v_soma_parc + v_aplicado - v_valor) > 0.01 THEN
    RAISE EXCEPTION 'Parcelas (%) + antecipacao (%) nao batem com o valor da nota (%).', v_soma_parc, v_aplicado, v_valor
      USING ERRCODE = 'P0001';
  END IF;

  RETURN v_res || jsonb_build_object('nota_id', v_nota_id, 'parcelas', v_n, 'antecipacao_aplicada', v_aplicado,
                                     'fornecedor_trocado', v_forn IS DISTINCT FROM v_ped.fornecedor_id,
                                     'reservado', v_reservado);
END;
$function$;

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
BEGIN
  IF NOT public.hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar') THEN
    RAISE EXCEPTION 'Sem permissao para cancelar entrada de nota fiscal.' USING ERRCODE = '42501';
  END IF;
  IF v_motivo IS NULL THEN
    RAISE EXCEPTION 'Informe o motivo do cancelamento.' USING ERRCODE = 'P0001';
  END IF;

  SELECT id, numero_nf, pedido_compra_id, cancelada_em INTO v_nota
    FROM public.notas_fiscais_compra WHERE id = p_nota_id FOR UPDATE;
  IF v_nota.id IS NULL THEN
    RAISE EXCEPTION 'Nota fiscal nao encontrada.' USING ERRCODE = 'P0001';
  END IF;
  IF v_nota.cancelada_em IS NOT NULL THEN
    RAISE EXCEPTION 'A nota % ja foi cancelada.', v_nota.numero_nf USING ERRCODE = 'P0001';
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

    -- Devolve o que entrou por esta nota
    UPDATE public.pedido_compra_itens i
       SET qtd_recebida = greatest(0, i.qtd_recebida - x.quantidade)
      FROM public.nota_fiscal_compra_itens x
     WHERE x.nota_id = p_nota_id AND x.pedido_item_id = i.id;
    GET DIAGNOSTICS v_itens = ROW_COUNT;

    -- Status pelo que sobrou recebido (a entrada só acontece a partir de "aprovado")
    IF v_ped.status <> 'cancelado' THEN
      SELECT CASE WHEN bool_and(qtd_recebida >= quantidade) THEN 'recebido'
                  WHEN bool_or(qtd_recebida > 0) THEN 'parcialmente_recebido'
                  ELSE 'aprovado' END
        INTO v_novo FROM public.pedido_compra_itens WHERE pedido_id = v_ped.id;
      UPDATE public.pedidos_compra
         SET status = coalesce(v_novo, status),
             recebido_em = CASE WHEN v_novo = 'recebido' THEN recebido_em END,
             primeira_entrada_em = CASE WHEN v_novo = 'aprovado' THEN NULL ELSE primeira_entrada_em END,
             atualizado_em = now()
       WHERE id = v_ped.id;
    END IF;
  END IF;

  -- Parcelas da nota saem do A Pagar; antecipação usada volta a ter saldo
  DELETE FROM public.nota_fiscal_compra_parcelas WHERE nota_id = p_nota_id;
  GET DIAGNOSTICS v_parcelas = ROW_COUNT;
  SELECT coalesce(sum(valor_aplicado), 0) INTO v_antecip FROM public.pagamento_antecipado_vinculos WHERE nota_id = p_nota_id;
  DELETE FROM public.pagamento_antecipado_vinculos WHERE nota_id = p_nota_id;

  UPDATE public.notas_fiscais_compra
     SET cancelada_em = now(), cancelada_por = auth.uid(), motivo_cancelamento = v_motivo
   WHERE id = p_nota_id;

  RETURN jsonb_build_object('nota_id', p_nota_id, 'numero_nf', v_nota.numero_nf,
                            'pedido_numero', v_ped.numero, 'pedido_status', v_novo,
                            'itens_devolvidos', v_itens, 'parcelas_removidas', v_parcelas,
                            'antecipacao_devolvida', v_antecip, 'reserva_desfeita', v_desfeito);
END;
$function$;

ALTER TABLE public.notas_fiscais_compra DROP COLUMN IF EXISTS estoque_somado_em;
