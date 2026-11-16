-- SPEC-289 (Reunião 52, Débora, 12/11/2026): Compras / Entrada de Nota Fiscal.
-- A) Entrada parcial por peça: nada a mudar no banco. registrar_entrada_nota_compra (234) chama registrar_entrada_pedido_compra,
--    que ignora peça com quantidade 0 / não enviada (CONTINUE), só recusa "nenhuma peça" ("Informe a quantidade recebida de ao menos 1
--    item"), mantém o status parcialmente_recebido e a peça que não veio segue no pedido com "falta" intacta. nota_fiscal_compra_itens,
--    estoque e vínculo com cliente só olham quantidade > 0. A 2ª entrada traz só o que sobrou. (Testado no dry_run.sql.)
-- B) "Este pedido já foi pago (antecipado / à vista)": registrar_entrada_nota_compra ganha o parâmetro opcional p_pagamento
--    ({valor, data_pagamento, observacao}). Cria o pagamento antecipado ligado ao pedido (fornecedor e empresa do pedido, criado_por = quem
--    deu a entrada) e o vincula à nota na mesma transação, sem aprovação da Lana. Pago integral -> sem parcelas; parcial -> parcelas só do
--    restante (a validação "parcelas + antecipação = valor da nota" da RPC continua valendo); pago a mais que a nota -> o excedente fica de
--    saldo no pagamento. Teto: p_pagamento.valor não passa do valor_total do pedido (tolerância R$ 0,01).
--    Pedido com antecipação ligada e com saldo: a RPC aplica esse saldo sozinha (min(saldo, restante da nota)), mesmo sem p_pagamento
--    (2ª nota de pedido pago em parte), e não cria outra; a tela edita o valor ou zera enviando a antecipação em p_antecipacoes.
--    O espelho no Contas a Pagar vem do gatilho da 342 (pagamentos_antecipados -> financeiro_titulos).
-- Mudou a lista de parâmetros: DROP da assinatura antiga (7 parâmetros) e CREATE da nova, para não deixar duas funções (overload).
-- Quem pode: mesma trava da RPC (hub_pode_executar 'necessidade-de-compra' + 'editar'); a Débora não precisa de Adm. Bancária.
BEGIN;

DROP FUNCTION IF EXISTS public.registrar_entrada_nota_compra(uuid, jsonb, jsonb, jsonb, jsonb, uuid, jsonb);

CREATE FUNCTION public.registrar_entrada_nota_compra(p_pedido_id uuid, p_itens jsonb, p_nota jsonb, p_parcelas jsonb DEFAULT '[]'::jsonb, p_antecipacoes jsonb DEFAULT '[]'::jsonb, p_fornecedor_id uuid DEFAULT NULL::uuid, p_vinculos jsonb DEFAULT '[]'::jsonb, p_pagamento jsonb DEFAULT NULL::jsonb)
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
  v_estoque    numeric := 0;
  v_pg_valor   numeric := 0;
  v_pg_data    date;
  v_pg_obs     text;
  v_pg_id      uuid;
  v_pg_criado  numeric := 0;
  v_pg_aplic   numeric := 0;
  v_tem_ligada boolean := false;
  v_decididas  uuid[] := '{}';
BEGIN
  IF NOT public.hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar') THEN
    RAISE EXCEPTION 'Sem permissao para dar entrada em pedido de compra.' USING ERRCODE = '42501';
  END IF;

  SELECT id, numero, status, fornecedor_id, empresa_id, valor_total INTO v_ped
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

  -- SPEC-222: o que chegou entra no estoque físico (Estoque Geral = local 'Estoque'), vinculado ou livre.
  -- A reserva não muda aqui: a aprovação do orçamento já somou a venda inteira em quantidade_reservada.
  FOR v_vinc IN
    SELECT pi.produto_id, sum(x.quantidade) AS quantidade
      FROM public.nota_fiscal_compra_itens x
      JOIN public.pedido_compra_itens pi ON pi.id = x.pedido_item_id
     WHERE x.nota_id = v_nota_id AND pi.produto_id IS NOT NULL
     GROUP BY pi.produto_id
  LOOP
    INSERT INTO public.estoque_itens (produto_id, local, quantidade, quantidade_reservada, atualizado_em)
    VALUES (v_vinc.produto_id, 'Estoque'::public.estoque_local, 0, 0, now())
    ON CONFLICT (produto_id, local) DO NOTHING;
    UPDATE public.estoque_itens
       SET quantidade = quantidade + v_vinc.quantidade, atualizado_em = now()
     WHERE produto_id = v_vinc.produto_id AND local = 'Estoque'::public.estoque_local;
    v_estoque := v_estoque + v_vinc.quantidade;
  END LOOP;
  UPDATE public.notas_fiscais_compra SET estoque_somado_em = now() WHERE id = v_nota_id;

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

  -- SPEC-289 B4: o pedido já tem antecipação ligada (lançada pela Lana ou criada numa nota anterior) com saldo?
  -- E quais antecipações a tela já decidiu (marcadas, editadas ou desmarcadas = valor 0): essas a RPC não mexe.
  v_tem_ligada := EXISTS (SELECT 1 FROM public.pagamentos_antecipados a
                           WHERE a.pedido_compra_id = p_pedido_id AND a.cancelado_em IS NULL
                             AND a.valor > coalesce((SELECT sum(x.valor_aplicado) FROM public.pagamento_antecipado_vinculos x
                                                      WHERE x.pagamento_id = a.id), 0));
  SELECT coalesce(array_agg(DISTINCT nullif(e->>'pagamento_id', '')::uuid), '{}') INTO v_decididas
    FROM jsonb_array_elements(coalesce(p_antecipacoes, '[]'::jsonb)) e;

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

  -- SPEC-289 B4: saldo de antecipação ligada ao pedido é aplicado sozinho (min(saldo, restante da nota)), para a 2ª nota de um
  -- pedido pago em parte não ser cobrada de novo. Vale mesmo sem p_pagamento; a tela pode ter editado o valor (ou zerado) via
  -- p_antecipacoes, e aí a RPC respeita.
  FOR v_pag IN
    SELECT a.* FROM public.pagamentos_antecipados a
     WHERE a.pedido_compra_id = p_pedido_id AND a.cancelado_em IS NULL AND NOT (a.id = ANY (v_decididas))
     ORDER BY a.data_pagamento, a.criado_em
     FOR UPDATE
  LOOP
    v_saldo := v_pag.valor - coalesce((SELECT sum(valor_aplicado) FROM public.pagamento_antecipado_vinculos
                                        WHERE pagamento_id = v_pag.id), 0);
    v_qtd := round(least(v_saldo, greatest(v_valor - v_aplicado, 0)), 2);
    IF v_qtd > 0 THEN
      INSERT INTO public.pagamento_antecipado_vinculos (pagamento_id, nota_id, valor_aplicado, criado_por)
      VALUES (v_pag.id, v_nota_id, v_qtd, auth.uid());
      v_aplicado := v_aplicado + v_qtd;
      v_pg_aplic := v_pg_aplic + v_qtd;
      v_pg_id := coalesce(v_pg_id, v_pag.id);
    END IF;
  END LOOP;

  -- SPEC-289 B: "este pedido já foi pago" (antecipado / à vista) marcado na própria entrada. Vale direto, sem a Lana:
  -- cria o pagamento antecipado ligado ao pedido e já o vincula a esta nota, na mesma transação.
  -- Teto: não passa do valor total do pedido (tolerância de R$ 0,01).
  -- Se o pedido já tinha antecipação ligada com saldo, usa essa (bloco acima) em vez de criar outra.
  -- Pago a mais do que a nota: o excedente fica de saldo no pagamento para as próximas notas do pedido.
  IF p_pagamento IS NOT NULL AND jsonb_typeof(p_pagamento) = 'object' THEN
    v_pg_valor := round(coalesce(nullif(p_pagamento->>'valor', '')::numeric, 0), 2);
    IF v_pg_valor < 0 THEN
      RAISE EXCEPTION 'Valor pago nao pode ser negativo.' USING ERRCODE = 'P0001';
    END IF;
    IF v_pg_valor > 0 AND v_ped.valor_total IS NOT NULL AND v_pg_valor > v_ped.valor_total + 0.01 THEN
      RAISE EXCEPTION 'O valor pago (%) nao pode passar do valor total do pedido (%).', v_pg_valor, v_ped.valor_total
        USING ERRCODE = 'P0001';
    END IF;
    IF v_pg_valor > 0 AND NOT v_tem_ligada THEN
      v_pg_data := nullif(p_pagamento->>'data_pagamento', '')::date;
      v_pg_obs  := nullif(trim(coalesce(p_pagamento->>'observacao', '')), '');
      IF v_pg_data IS NULL THEN
        RAISE EXCEPTION 'Informe a data do pagamento.' USING ERRCODE = 'P0001';
      END IF;
      IF v_pg_data > current_date THEN
        RAISE EXCEPTION 'A data do pagamento nao pode ser futura.' USING ERRCODE = 'P0001';
      END IF;
      IF v_ped.empresa_id IS NULL THEN
        RAISE EXCEPTION 'O pedido nao tem empresa: nao da para lancar o pagamento.' USING ERRCODE = 'P0001';
      END IF;
      INSERT INTO public.pagamentos_antecipados
        (fornecedor_id, empresa_id, pedido_compra_id, valor, data_pagamento, observacao, criado_por)
      VALUES (v_forn, v_ped.empresa_id, p_pedido_id, v_pg_valor, v_pg_data,
              coalesce(v_pg_obs, format('Pago na entrada da NF %s (pedido %s)', v_numero_nf, v_ped.numero)),
              auth.uid())
      RETURNING id INTO v_pg_id;
      v_pg_criado := v_pg_valor;
      v_qtd := round(least(v_pg_valor, greatest(v_valor - v_aplicado, 0)), 2);
      IF v_qtd > 0 THEN
        INSERT INTO public.pagamento_antecipado_vinculos (pagamento_id, nota_id, valor_aplicado, criado_por)
        VALUES (v_pg_id, v_nota_id, v_qtd, auth.uid());
        v_aplicado := v_aplicado + v_qtd;
        v_pg_aplic := v_pg_aplic + v_qtd;
      END IF;
    END IF;
  END IF;

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
                                     'reservado', v_reservado, 'estoque_somado', v_estoque,
                                     'pagamento_criado', v_pg_criado, 'pagamento_aplicado', v_pg_aplic, 'pagamento_id', v_pg_id);
END;
$function$;

-- Espelho do pagamento antecipado (342) passa a funcionar para quem não tem o financeiro (ex.: Débora na Entrada de NF).
CREATE OR REPLACE FUNCTION public.financeiro_espelhar_pagamento_antecipado(p_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
DECLARE v_claims text; a public.pagamentos_antecipados; v_tit uuid; v_par uuid; b record;
BEGIN
    SELECT * INTO a FROM public.pagamentos_antecipados WHERE id = p_id FOR UPDATE;
    IF NOT FOUND THEN RETURN; END IF;
    -- SPEC-289: o espelho é interno (ponte); quem lança na Entrada de NF (Débora) não tem acesso ao financeiro. Roda sem usuário, como os demais espelhos.
    v_claims := current_setting('request.jwt.claims', true);
    PERFORM set_config('request.jwt.claims', '', true);

    IF a.cancelado_em IS NULL AND a.titulo_id IS NULL THEN
        v_tit := public.financeiro_criar_titulo(
            jsonb_build_object('natureza', 'pagar', 'origem_tipo', 'adiantamento', 'especie', 'adiantamento',
                               'empresa_id', a.empresa_id, 'contato_id', a.fornecedor_id,
                               'plano_contas_id', public.financeiro_plano_compras(),
                               'descricao', 'Pagamento antecipado' || coalesce(' - ' || nullif(btrim(a.observacao), ''), '')),
            jsonb_build_array(jsonb_build_object('vencimento', a.data_pagamento, 'valor', a.valor, 'situacao', 'firme',
                                                 'observacao', nullif(btrim(coalesce(a.observacao, '')), ''))));
        SELECT id INTO v_par FROM public.financeiro_parcelas WHERE titulo_id = v_tit AND numero = 1;
        UPDATE public.financeiro_parcelas SET emissao = a.data_pagamento WHERE id = v_par;
        PERFORM public.financeiro_baixar(v_par, 'pagamento', a.valor, a.data_pagamento, NULL, 'Antecipacao', NULL, 0, 0, 0, NULL, NULL, 'ponte');
        UPDATE public.pagamentos_antecipados SET titulo_id = v_tit WHERE id = a.id;
    ELSIF a.cancelado_em IS NOT NULL AND a.titulo_id IS NOT NULL
          AND EXISTS (SELECT 1 FROM public.financeiro_titulos WHERE id = a.titulo_id AND cancelado_em IS NULL) THEN
        FOR b IN SELECT bx.id FROM public.financeiro_baixas bx JOIN public.financeiro_parcelas p ON p.id = bx.parcela_id
                  WHERE p.titulo_id = a.titulo_id AND bx.tipo = 'pagamento'
                    AND NOT EXISTS (SELECT 1 FROM public.financeiro_baixas e WHERE e.estorno_de = bx.id) LOOP
            PERFORM public.financeiro_estornar(b.id, 'Cancelamento do pagamento antecipado: ' || coalesce(nullif(btrim(a.motivo_cancelamento), ''), 'sem motivo informado'));
        END LOOP;
        PERFORM public.financeiro_cancelar_titulo(a.titulo_id, coalesce(nullif(btrim(a.motivo_cancelamento), ''), 'Pagamento antecipado cancelado'));
    END IF;
    PERFORM set_config('request.jwt.claims', coalesce(v_claims, ''), true);
END $f$;
REVOKE ALL ON FUNCTION public.financeiro_espelhar_pagamento_antecipado(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.registrar_entrada_nota_compra(uuid, jsonb, jsonb, jsonb, jsonb, uuid, jsonb, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.registrar_entrada_nota_compra(uuid, jsonb, jsonb, jsonb, jsonb, uuid, jsonb, jsonb) TO authenticated;

COMMENT ON FUNCTION public.registrar_entrada_nota_compra(uuid, jsonb, jsonb, jsonb, jsonb, uuid, jsonb, jsonb) IS
  'SPEC-215/220/222/289: entrada da nota (quantidades por peça, nota, parcelas, antecipação, vínculo com cliente, estoque) e, opcionalmente, pedido já pago (p_pagamento).';

COMMIT;
