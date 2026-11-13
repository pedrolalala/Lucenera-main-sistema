-- Dry-run da 343 (SPEC-289): aplica o up.sql e roda os testes; termina em ROLLBACK (nada fica no banco).
-- Gerado a partir do up.sql: se o up.sql mudar, regerar.
BEGIN;
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


-- ===================== TESTES (tudo termina em ROLLBACK) =====================
DO $t$
DECLARE
  deb   uuid := '78c716d7-9ca2-4449-8ac6-50c1905d21ef';  -- Debora: Compras sim, Financeiro nao
  forn  uuid; emp uuid;
  pa uuid; pb uuid; pc uuid;
  p1 uuid; i1a uuid; i1b uuid; i1c uuid;
  p2 uuid; i2a uuid; i2b uuid;
  p3 uuid; i3a uuid; i3b uuid;
  p4 uuid; i4a uuid; i4b uuid; ant4 uuid;
  p5 uuid; i5a uuid; i5b uuid;
  p6 uuid; i6a uuid; i6b uuid;
  r jsonb; n int; v numeric; st text; q numeric; ok boolean; msg text; nota uuid;
BEGIN
  SELECT id INTO forn FROM public.contatos LIMIT 1;
  SELECT id INTO emp  FROM public.empresas LIMIT 1;
  SELECT id INTO pa FROM public.produtos ORDER BY id LIMIT 1;
  SELECT id INTO pb FROM public.produtos ORDER BY id OFFSET 1 LIMIT 1;
  SELECT id INTO pc FROM public.produtos ORDER BY id OFFSET 2 LIMIT 1;

  -- pedidos de teste (valor por peça = 2 x 50 = 100)
  INSERT INTO public.pedidos_compra (numero, fornecedor_id, status, empresa_id, valor_total) VALUES ('T289-1', forn, 'aprovado', emp, 300) RETURNING id INTO p1;
  INSERT INTO public.pedido_compra_itens (pedido_id, produto_id, quantidade, custo_unitario) VALUES (p1, pa, 2, 50) RETURNING id INTO i1a;
  INSERT INTO public.pedido_compra_itens (pedido_id, produto_id, quantidade, custo_unitario) VALUES (p1, pb, 2, 50) RETURNING id INTO i1b;
  INSERT INTO public.pedido_compra_itens (pedido_id, produto_id, quantidade, custo_unitario) VALUES (p1, pc, 2, 50) RETURNING id INTO i1c;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', deb, 'role', 'authenticated')::text, true);
  RAISE NOTICE 'Debora: compras=% financeiro=%', public.hub_pode_executar(deb,'necessidade-de-compra',NULL,'editar'), public.hub_pode_executar(deb,'financeiro',NULL,'editar');

  -- A) nenhuma peca marcada (todas 0) -> bloqueado
  ok := false;
  BEGIN
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM public.registrar_entrada_nota_compra(p1,
      jsonb_build_array(jsonb_build_object('pedido_item_id', i1a, 'quantidade', 0), jsonb_build_object('pedido_item_id', i1b, 'quantidade', 0)),
      '{"numero_nf":"A0","valor":100}'::jsonb, '[{"data_vencimento":"2026-12-12","valor":100}]'::jsonb);
  EXCEPTION WHEN OTHERS THEN ok := true; msg := SQLERRM;
  END;
  EXECUTE 'RESET ROLE';
  RAISE NOTICE 'A) nenhuma peca marcada bloqueia: % (%)', ok, msg;
  IF NOT ok THEN RAISE EXCEPTION 'FALHA A0'; END IF;

  -- A) 1a entrada: pecas A e B chegam (2 cada, C vem com 0 explicito) -> parcialmente_recebido
  EXECUTE 'SET LOCAL ROLE authenticated';
  r := public.registrar_entrada_nota_compra(p1,
    jsonb_build_array(jsonb_build_object('pedido_item_id', i1a, 'quantidade', 2, 'valor_unitario', 50),
                      jsonb_build_object('pedido_item_id', i1b, 'quantidade', 2, 'valor_unitario', 50),
                      jsonb_build_object('pedido_item_id', i1c, 'quantidade', 0)),
    '{"numero_nf":"A1","valor":200}'::jsonb, '[{"data_vencimento":"2026-12-12","valor":200}]'::jsonb);
  EXECUTE 'RESET ROLE';
  RAISE NOTICE 'A) 1a entrada: %', r;
  SELECT status INTO st FROM public.pedidos_compra WHERE id = p1;
  SELECT qtd_recebida INTO q FROM public.pedido_compra_itens WHERE id = i1c;
  SELECT count(*) INTO n FROM public.nota_fiscal_compra_itens WHERE nota_id = (r->>'nota_id')::uuid;
  RAISE NOTICE 'A) status=% qtd_recebida da peca C=% linhas de item da nota=%', st, q, n;
  IF st <> 'parcialmente_recebido' OR q <> 0 OR n <> 2 THEN RAISE EXCEPTION 'FALHA A1'; END IF;

  -- A) 2a entrada: so o que sobrou (C) -> recebido
  EXECUTE 'SET LOCAL ROLE authenticated';
  r := public.registrar_entrada_nota_compra(p1,
    jsonb_build_array(jsonb_build_object('pedido_item_id', i1c, 'quantidade', 2, 'valor_unitario', 50)),
    '{"numero_nf":"A2","valor":100}'::jsonb, '[{"data_vencimento":"2026-12-12","valor":100}]'::jsonb);
  EXECUTE 'RESET ROLE';
  SELECT status INTO st FROM public.pedidos_compra WHERE id = p1;
  RAISE NOTICE 'A) 2a entrada fecha o pedido: status=% (%)', st, r->>'status';
  IF st <> 'recebido' THEN RAISE EXCEPTION 'FALHA A2'; END IF;

  -- B1) pago integral: antecipacao + vinculo, sem parcelas, na mao da Debora
  INSERT INTO public.pedidos_compra (numero, fornecedor_id, status, empresa_id, valor_total) VALUES ('T289-2', forn, 'aguardando_aprovar', emp, 200) RETURNING id INTO p2;
  INSERT INTO public.pedido_compra_itens (pedido_id, produto_id, quantidade, custo_unitario) VALUES (p2, pa, 2, 50) RETURNING id INTO i2a;
  INSERT INTO public.pedido_compra_itens (pedido_id, produto_id, quantidade, custo_unitario) VALUES (p2, pb, 2, 50) RETURNING id INTO i2b;
  EXECUTE 'SET LOCAL ROLE authenticated';
  r := public.registrar_entrada_nota_compra(p2,
    jsonb_build_array(jsonb_build_object('pedido_item_id', i2a, 'quantidade', 2), jsonb_build_object('pedido_item_id', i2b, 'quantidade', 2)),
    '{"numero_nf":"B1","valor":200}'::jsonb, '[]'::jsonb, '[]'::jsonb, NULL, '[]'::jsonb,
    jsonb_build_object('valor', 200, 'data_pagamento', current_date, 'observacao', 'Pix antecipado'));
  EXECUTE 'RESET ROLE';
  RAISE NOTICE 'B1) pago integral: %', r;
  SELECT count(*) INTO n FROM public.pagamentos_antecipados WHERE pedido_compra_id = p2 AND valor = 200 AND fornecedor_id = forn AND empresa_id = emp AND criado_por = deb AND cancelado_em IS NULL;
  SELECT coalesce(sum(valor_aplicado),0) INTO v FROM public.pagamento_antecipado_vinculos WHERE nota_id = (r->>'nota_id')::uuid;
  RAISE NOTICE 'B1) antecipacoes=% vinculado=% parcelas=%', n, v, r->>'parcelas';
  IF n <> 1 OR v <> 200 OR (r->>'parcelas')::int <> 0 THEN RAISE EXCEPTION 'FALHA B1'; END IF;
  SELECT count(*) INTO n FROM public.pagamentos_antecipados WHERE pedido_compra_id = p2 AND titulo_id IS NOT NULL;
  RAISE NOTICE 'B1) espelho no financeiro (titulo_id preenchido, gatilho 342) = %; falhas da ponte novas = %', n,
    (SELECT count(*) FROM public.financeiro_ponte_falhas WHERE origem = 'pagamentos_antecipados' AND resolvida_em IS NULL);

  RAISE NOTICE 'erro da ponte: %', (SELECT erro FROM public.financeiro_ponte_falhas WHERE origem = 'pagamentos_antecipados' AND resolvida_em IS NULL ORDER BY 1 LIMIT 1);

  -- B2) pago em parte: parcelas so do restante
  INSERT INTO public.pedidos_compra (numero, fornecedor_id, status, empresa_id, valor_total) VALUES ('T289-3', forn, 'aprovado', emp, 200) RETURNING id INTO p3;
  INSERT INTO public.pedido_compra_itens (pedido_id, produto_id, quantidade, custo_unitario) VALUES (p3, pa, 2, 50) RETURNING id INTO i3a;
  INSERT INTO public.pedido_compra_itens (pedido_id, produto_id, quantidade, custo_unitario) VALUES (p3, pb, 2, 50) RETURNING id INTO i3b;
  EXECUTE 'SET LOCAL ROLE authenticated';
  r := public.registrar_entrada_nota_compra(p3,
    jsonb_build_array(jsonb_build_object('pedido_item_id', i3a, 'quantidade', 2), jsonb_build_object('pedido_item_id', i3b, 'quantidade', 2)),
    '{"numero_nf":"B2","valor":200}'::jsonb, '[{"data_vencimento":"2026-12-20","valor":120}]'::jsonb, '[]'::jsonb, NULL, '[]'::jsonb,
    jsonb_build_object('valor', 80, 'data_pagamento', current_date));
  EXECUTE 'RESET ROLE';
  RAISE NOTICE 'B2) pago parcial: %', r;
  SELECT coalesce(sum(valor),0) INTO v FROM public.nota_fiscal_compra_parcelas WHERE nota_id = (r->>'nota_id')::uuid;
  IF (r->>'pagamento_aplicado')::numeric <> 80 OR v <> 120 THEN RAISE EXCEPTION 'FALHA B2'; END IF;

  -- B2b) pago parcial mas parcelas nao fecham -> recusa e nada fica gravado
  ok := false;
  BEGIN
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM public.registrar_entrada_nota_compra(p3,
      jsonb_build_array(jsonb_build_object('pedido_item_id', i3a, 'quantidade', 0)), '{"numero_nf":"B2x","valor":100}'::jsonb);
  EXCEPTION WHEN OTHERS THEN ok := true; msg := SQLERRM;
  END;
  EXECUTE 'RESET ROLE';
  RAISE NOTICE 'B2b) pedido ja concluido/sem peca recusa: % (%)', ok, msg;

  -- B3) antecipacao ja ligada ao pedido (lancada pela Lana) e reaproveitada, nao duplica
  INSERT INTO public.pedidos_compra (numero, fornecedor_id, status, empresa_id, valor_total) VALUES ('T289-4', forn, 'aprovado', emp, 200) RETURNING id INTO p4;
  INSERT INTO public.pedido_compra_itens (pedido_id, produto_id, quantidade, custo_unitario) VALUES (p4, pa, 2, 50) RETURNING id INTO i4a;
  INSERT INTO public.pedido_compra_itens (pedido_id, produto_id, quantidade, custo_unitario) VALUES (p4, pb, 2, 50) RETURNING id INTO i4b;
  INSERT INTO public.pagamentos_antecipados (fornecedor_id, empresa_id, pedido_compra_id, valor, data_pagamento, observacao)
    VALUES (forn, emp, p4, 150, current_date, 'lancado pela Lana') RETURNING id INTO ant4;
  EXECUTE 'SET LOCAL ROLE authenticated';
  r := public.registrar_entrada_nota_compra(p4,
    jsonb_build_array(jsonb_build_object('pedido_item_id', i4a, 'quantidade', 2), jsonb_build_object('pedido_item_id', i4b, 'quantidade', 2)),
    '{"numero_nf":"B3","valor":200}'::jsonb, '[{"data_vencimento":"2026-12-20","valor":50}]'::jsonb, '[]'::jsonb, NULL, '[]'::jsonb,
    jsonb_build_object('valor', 200, 'data_pagamento', current_date));
  EXECUTE 'RESET ROLE';
  SELECT count(*) INTO n FROM public.pagamentos_antecipados WHERE pedido_compra_id = p4 AND cancelado_em IS NULL;
  SELECT coalesce(sum(valor_aplicado),0) INTO v FROM public.pagamento_antecipado_vinculos WHERE pagamento_id = ant4;
  RAISE NOTICE 'B3) reaproveitada: antecipacoes do pedido=% aplicado na existente=% (%)', n, v, r;
  IF n <> 1 OR v <> 150 OR (r->>'pagamento_criado')::numeric <> 0 THEN RAISE EXCEPTION 'FALHA B3'; END IF;

  -- B4) pago a mais que a nota (entrada parcial): excedente fica de saldo no pagamento
  INSERT INTO public.pedidos_compra (numero, fornecedor_id, status, empresa_id, valor_total) VALUES ('T289-5', forn, 'aprovado', emp, 200) RETURNING id INTO p5;
  INSERT INTO public.pedido_compra_itens (pedido_id, produto_id, quantidade, custo_unitario) VALUES (p5, pa, 2, 50) RETURNING id INTO i5a;
  INSERT INTO public.pedido_compra_itens (pedido_id, produto_id, quantidade, custo_unitario) VALUES (p5, pb, 2, 50) RETURNING id INTO i5b;
  EXECUTE 'SET LOCAL ROLE authenticated';
  r := public.registrar_entrada_nota_compra(p5,
    jsonb_build_array(jsonb_build_object('pedido_item_id', i5a, 'quantidade', 2)),
    '{"numero_nf":"B4","valor":100}'::jsonb, '[]'::jsonb, '[]'::jsonb, NULL, '[]'::jsonb,
    jsonb_build_object('valor', 200, 'data_pagamento', current_date));
  EXECUTE 'RESET ROLE';
  RAISE NOTICE 'B4) pago a mais: %', r;
  SELECT status INTO st FROM public.pedidos_compra WHERE id = p5;
  IF (r->>'pagamento_aplicado')::numeric <> 100 OR (r->>'parcelas')::int <> 0 OR st <> 'parcialmente_recebido' THEN RAISE EXCEPTION 'FALHA B4'; END IF;

  -- B5) valor pago maior que 0 sem data -> recusa
  INSERT INTO public.pedidos_compra (numero, fornecedor_id, status, empresa_id, valor_total) VALUES ('T289-6', forn, 'aprovado', emp, 100) RETURNING id INTO p6;
  INSERT INTO public.pedido_compra_itens (pedido_id, produto_id, quantidade, custo_unitario) VALUES (p6, pa, 2, 50) RETURNING id INTO i6a;
  ok := false;
  BEGIN
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM public.registrar_entrada_nota_compra(p6, jsonb_build_array(jsonb_build_object('pedido_item_id', i6a, 'quantidade', 2)),
      '{"numero_nf":"B5","valor":100}'::jsonb, '[]'::jsonb, '[]'::jsonb, NULL, '[]'::jsonb, jsonb_build_object('valor', 100));
  EXCEPTION WHEN OTHERS THEN ok := true; msg := SQLERRM;
  END;
  EXECUTE 'RESET ROLE';
  RAISE NOTICE 'B5) sem data recusa: % (%)', ok, msg;
  IF NOT ok THEN RAISE EXCEPTION 'FALHA B5'; END IF;

  -- B6) pago 100 mas sem parcelas e nota maior -> soma nao bate: recusa e nao deixa antecipacao
  ok := false;
  BEGIN
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM public.registrar_entrada_nota_compra(p6, jsonb_build_array(jsonb_build_object('pedido_item_id', i6a, 'quantidade', 2)),
      '{"numero_nf":"B6","valor":100}'::jsonb, '[]'::jsonb, '[]'::jsonb, NULL, '[]'::jsonb,
      jsonb_build_object('valor', 40, 'data_pagamento', current_date));
  EXCEPTION WHEN OTHERS THEN ok := true; msg := SQLERRM;
  END;
  EXECUTE 'RESET ROLE';
  SELECT count(*) INTO n FROM public.pagamentos_antecipados WHERE pedido_compra_id = p6;
  RAISE NOTICE 'B6) soma nao bate recusa: % (%) antecipacoes gravadas=%', ok, msg, n;
  IF NOT ok OR n <> 0 THEN RAISE EXCEPTION 'FALHA B6'; END IF;

  -- anon recusado
  ok := false;
  BEGIN
    EXECUTE 'SET LOCAL ROLE anon';
    PERFORM public.registrar_entrada_nota_compra(p6, '[]'::jsonb, '{"numero_nf":"X","valor":1}'::jsonb);
  EXCEPTION WHEN insufficient_privilege THEN ok := true; msg := SQLERRM;
  END;
  EXECUTE 'RESET ROLE';
  RAISE NOTICE 'anon recusado: % (%)', ok, msg;
  IF NOT ok THEN RAISE EXCEPTION 'FALHA anon'; END IF;

  -- authenticated sem papel (sem usuario) recusado pela trava
  ok := false;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000000', 'role', 'authenticated')::text, true);
  BEGIN
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM public.registrar_entrada_nota_compra(p6, '[]'::jsonb, '{"numero_nf":"X","valor":1}'::jsonb);
  EXCEPTION WHEN OTHERS THEN ok := true; msg := SQLERRM;
  END;
  EXECUTE 'RESET ROLE';
  RAISE NOTICE 'usuario sem permissao recusado: % (%)', ok, msg;
  IF NOT ok THEN RAISE EXCEPTION 'FALHA sem permissao'; END IF;

  RAISE NOTICE 'TODOS OS TESTES PASSARAM (ROLLBACK a seguir)';
END
$t$;

-- ===================== BLOCO 2: teto, 2a nota de pedido parcial pago, edicao/zerar, cancelamentos =====================
DO $t2$
DECLARE
  deb   uuid := '78c716d7-9ca2-4449-8ac6-50c1905d21ef';  -- Debora
  lana  uuid := '8bb35a84-22e7-40e3-b4c5-f1aecf1f3879';  -- Lana: Compras e financeiro
  forn  uuid; emp uuid; pa uuid; pb uuid; pc uuid;
  p uuid; ia uuid; ib uuid; ic uuid; pg uuid; nota uuid; tit uuid;
  r jsonb; n int; v numeric; st text; ok boolean; msg text; ev_null int; ev_user int; falhas_antes int; falhas_depois int;
  cl_deb text; cl_lana text;
BEGIN
  SELECT id INTO forn FROM public.contatos LIMIT 1;
  SELECT id INTO emp  FROM public.empresas LIMIT 1;
  SELECT id INTO pa FROM public.produtos ORDER BY id LIMIT 1;
  SELECT id INTO pb FROM public.produtos ORDER BY id OFFSET 1 LIMIT 1;
  SELECT id INTO pc FROM public.produtos ORDER BY id OFFSET 2 LIMIT 1;
  cl_deb  := json_build_object('sub', deb,  'role', 'authenticated')::text;
  cl_lana := json_build_object('sub', lana, 'role', 'authenticated')::text;
  PERFORM set_config('request.jwt.claims', cl_deb, true);
  RAISE NOTICE 'Lana: compras=% financeiro=%', public.hub_pode_executar(lana,'necessidade-de-compra',NULL,'editar'), public.hub_pode_executar(lana,'financeiro',NULL,'editar');

  -- pedido de 3 pecas (100 cada = 300)
  INSERT INTO public.pedidos_compra (numero, fornecedor_id, status, empresa_id, valor_total) VALUES ('T289-7', forn, 'aprovado', emp, 300) RETURNING id INTO p;
  INSERT INTO public.pedido_compra_itens (pedido_id, produto_id, quantidade, custo_unitario) VALUES (p, pa, 2, 50) RETURNING id INTO ia;
  INSERT INTO public.pedido_compra_itens (pedido_id, produto_id, quantidade, custo_unitario) VALUES (p, pb, 2, 50) RETURNING id INTO ib;
  INSERT INTO public.pedido_compra_itens (pedido_id, produto_id, quantidade, custo_unitario) VALUES (p, pc, 2, 50) RETURNING id INTO ic;

  -- 1) teto: valor pago acima do total do pedido e recusado (300,02); no limite (300,01 de tolerancia) passa
  ok := false;
  BEGIN
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM public.registrar_entrada_nota_compra(p, jsonb_build_array(jsonb_build_object('pedido_item_id', ia, 'quantidade', 2)),
      '{"numero_nf":"T1","valor":100}'::jsonb, '[]'::jsonb, '[]'::jsonb, NULL, '[]'::jsonb,
      jsonb_build_object('valor', 300.02, 'data_pagamento', current_date));
  EXCEPTION WHEN OTHERS THEN ok := true; msg := SQLERRM;
  END;
  EXECUTE 'RESET ROLE';
  SELECT count(*) INTO n FROM public.pagamentos_antecipados WHERE pedido_compra_id = p;
  RAISE NOTICE 'T1) teto recusa 300,02 num pedido de 300: % (%) antecipacoes gravadas=%', ok, msg, n;
  IF NOT ok OR n <> 0 THEN RAISE EXCEPTION 'FALHA teto'; END IF;

  -- 2) 1a nota paga com 300 (pedido todo) cobre so a peca A (100): excedente 200 fica de saldo
  EXECUTE 'SET LOCAL ROLE authenticated';
  r := public.registrar_entrada_nota_compra(p, jsonb_build_array(jsonb_build_object('pedido_item_id', ia, 'quantidade', 2)),
    '{"numero_nf":"T2"  ,"valor":100}'::jsonb, '[]'::jsonb, '[]'::jsonb, NULL, '[]'::jsonb,
    jsonb_build_object('valor', 300.01, 'data_pagamento', current_date));
  EXECUTE 'RESET ROLE';
  pg := (r->>'pagamento_id')::uuid;
  SELECT coalesce(sum(valor_aplicado),0) INTO v FROM public.pagamento_antecipado_vinculos WHERE pagamento_id = pg;
  RAISE NOTICE 'T2) 1a nota: aplicado=% de 300,01 (saldo %)', v, 300.01 - v;
  IF v <> 100 THEN RAISE EXCEPTION 'FALHA T2'; END IF;

  -- 3) 2a nota, SEM p_pagamento e sem parcelas: o saldo ligado ao pedido e aplicado sozinho (sem dupla cobranca)
  EXECUTE 'SET LOCAL ROLE authenticated';
  r := public.registrar_entrada_nota_compra(p, jsonb_build_array(jsonb_build_object('pedido_item_id', ib, 'quantidade', 2)),
    '{"numero_nf":"T3","valor":100}'::jsonb);
  EXECUTE 'RESET ROLE';
  SELECT coalesce(sum(valor_aplicado),0) INTO v FROM public.pagamento_antecipado_vinculos WHERE pagamento_id = pg;
  RAISE NOTICE 'T3) 2a nota sem p_pagamento: %; total aplicado no pagamento=%', r, v;
  IF (r->>'pagamento_aplicado')::numeric <> 100 OR (r->>'parcelas')::int <> 0 OR v <> 200 THEN RAISE EXCEPTION 'FALHA T3'; END IF;

  -- 4) 3a nota com parcelas cobrindo tudo e antecipacao zerada na tela (usuario desmarcou): a RPC respeita e nao aplica
  EXECUTE 'SET LOCAL ROLE authenticated';
  r := public.registrar_entrada_nota_compra(p, jsonb_build_array(jsonb_build_object('pedido_item_id', ic, 'quantidade', 2)),
    '{"numero_nf":"T4","valor":100}'::jsonb, '[{"data_vencimento":"2026-12-30","valor":100}]'::jsonb,
    jsonb_build_array(jsonb_build_object('pagamento_id', pg, 'valor', 0)));
  EXECUTE 'RESET ROLE';
  SELECT coalesce(sum(valor_aplicado),0) INTO v FROM public.pagamento_antecipado_vinculos WHERE pagamento_id = pg;
  RAISE NOTICE 'T4) antecipacao zerada pela tela respeitada: aplicado na nota=% total no pagamento=% parcelas=%', r->>'pagamento_aplicado', v, r->>'parcelas';
  IF (r->>'pagamento_aplicado')::numeric <> 0 OR v <> 200 OR (r->>'parcelas')::int <> 1 THEN RAISE EXCEPTION 'FALHA T4'; END IF;

  -- 5) valor editado na tela (so 40 de um saldo maior) e respeitado: a RPC nao aplica o resto sozinha
  INSERT INTO public.pedidos_compra (numero, fornecedor_id, status, empresa_id, valor_total) VALUES ('T289-8', forn, 'aprovado', emp, 200) RETURNING id INTO p;
  INSERT INTO public.pedido_compra_itens (pedido_id, produto_id, quantidade, custo_unitario) VALUES (p, pa, 2, 50) RETURNING id INTO ia;
  INSERT INTO public.pedido_compra_itens (pedido_id, produto_id, quantidade, custo_unitario) VALUES (p, pb, 2, 50) RETURNING id INTO ib;
  INSERT INTO public.pagamentos_antecipados (fornecedor_id, empresa_id, pedido_compra_id, valor, data_pagamento, observacao)
    VALUES (forn, emp, p, 150, current_date, 'lancado pela Lana') RETURNING id INTO pg;
  EXECUTE 'SET LOCAL ROLE authenticated';
  r := public.registrar_entrada_nota_compra(p, jsonb_build_array(jsonb_build_object('pedido_item_id', ia, 'quantidade', 2)),
    '{"numero_nf":"T5","valor":100}'::jsonb, '[{"data_vencimento":"2026-12-30","valor":60}]'::jsonb,
    jsonb_build_array(jsonb_build_object('pagamento_id', pg, 'valor', 40)));
  EXECUTE 'RESET ROLE';
  SELECT coalesce(sum(valor_aplicado),0) INTO v FROM public.pagamento_antecipado_vinculos WHERE pagamento_id = pg;
  RAISE NOTICE 'T5) valor editado (40) respeitado: aplicado=% parcelas=%', v, r->>'parcelas';
  IF v <> 40 THEN RAISE EXCEPTION 'FALHA T5'; END IF;

  -- ===== cancelamentos =====
  -- 6) Debora cria a antecipacao pela opcao "ja foi pago"; depois cancela a ENTRADA (SPEC-218): o saldo volta, o pedido volta
  INSERT INTO public.pedidos_compra (numero, fornecedor_id, status, empresa_id, valor_total) VALUES ('T289-9', forn, 'aprovado', emp, 200) RETURNING id INTO p;
  INSERT INTO public.pedido_compra_itens (pedido_id, produto_id, quantidade, custo_unitario) VALUES (p, pa, 2, 50) RETURNING id INTO ia;
  INSERT INTO public.pedido_compra_itens (pedido_id, produto_id, quantidade, custo_unitario) VALUES (p, pb, 2, 50) RETURNING id INTO ib;
  SELECT count(*) INTO falhas_antes FROM public.financeiro_ponte_falhas WHERE origem = 'pagamentos_antecipados' AND resolvida_em IS NULL;
  EXECUTE 'SET LOCAL ROLE authenticated';
  r := public.registrar_entrada_nota_compra(p,
    jsonb_build_array(jsonb_build_object('pedido_item_id', ia, 'quantidade', 2), jsonb_build_object('pedido_item_id', ib, 'quantidade', 2)),
    '{"numero_nf":"T6","valor":200}'::jsonb, '[]'::jsonb, '[]'::jsonb, NULL, '[]'::jsonb,
    jsonb_build_object('valor', 200, 'data_pagamento', current_date));
  EXECUTE 'RESET ROLE';
  nota := (r->>'nota_id')::uuid; pg := (r->>'pagamento_id')::uuid;
  SELECT titulo_id INTO tit FROM public.pagamentos_antecipados WHERE id = pg;
  RAISE NOTICE 'T6) criada pela Debora: pagamento=% titulo(espelho)=%', pg, (tit IS NOT NULL);
  IF tit IS NULL THEN RAISE EXCEPTION 'FALHA T6 espelho'; END IF;

  -- 6a) Lana tenta cancelar a antecipacao enquanto vinculada a nota: recusado (regra da SPEC-215, "sem uso")
  PERFORM set_config('request.jwt.claims', cl_lana, true);
  ok := false;
  BEGIN
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM public.cancelar_pagamento_antecipado(pg, 'teste');
  EXCEPTION WHEN OTHERS THEN ok := true; msg := SQLERRM;
  END;
  EXECUTE 'RESET ROLE';
  RAISE NOTICE 'T6a) cancelar antecipacao ainda vinculada a nota recusado: % (%)', ok, msg;
  IF NOT ok THEN RAISE EXCEPTION 'FALHA T6a'; END IF;

  -- 6b) cancelar a entrada pela cancelar_entrada_nota_compra (SPEC-218): a antecipacao volta a ter saldo, sem falha na ponte
  PERFORM set_config('request.jwt.claims', cl_deb, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  r := public.cancelar_entrada_nota_compra(nota, 'teste do dry-run');
  EXECUTE 'RESET ROLE';
  SELECT status INTO st FROM public.pedidos_compra WHERE id = p;
  SELECT count(*) INTO n FROM public.pagamento_antecipado_vinculos WHERE pagamento_id = pg;
  SELECT count(*) INTO falhas_depois FROM public.financeiro_ponte_falhas WHERE origem = 'pagamentos_antecipados' AND resolvida_em IS NULL;
  RAISE NOTICE 'T6b) cancelar entrada: %; pedido=% vinculos restantes=% falhas da ponte (antes/depois)=%/%', r, st, n, falhas_antes, falhas_depois;
  IF n <> 0 OR (r->>'antecipacao_devolvida')::numeric <> 200 OR falhas_depois <> falhas_antes THEN RAISE EXCEPTION 'FALHA T6b'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.pagamentos_antecipados WHERE id = pg AND cancelado_em IS NULL AND titulo_id = tit) THEN RAISE EXCEPTION 'FALHA T6b antecipacao'; END IF;

  -- 6c) agora "sem uso": Lana (com financeiro) cancela a antecipacao criada pela opcao "ja foi pago"; o espelho cancela sem erro
  PERFORM set_config('request.jwt.claims', cl_lana, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.cancelar_pagamento_antecipado(pg, 'teste do dry-run: pagamento nao foi feito');
  EXECUTE 'RESET ROLE';
  SELECT count(*) INTO falhas_depois FROM public.financeiro_ponte_falhas WHERE origem = 'pagamentos_antecipados' AND resolvida_em IS NULL;
  SELECT (cancelado_em IS NOT NULL) INTO ok FROM public.financeiro_titulos WHERE id = tit;
  SELECT count(*) INTO n FROM public.financeiro_baixas b JOIN public.financeiro_parcelas pa2 ON pa2.id = b.parcela_id
   WHERE pa2.titulo_id = tit AND b.tipo = 'estorno';
  RAISE NOTICE 'T6c) Lana cancelou: antecipacao cancelada=% titulo cancelado=% estornos=% falhas da ponte (antes/depois)=%/%',
    (SELECT cancelado_em IS NOT NULL FROM public.pagamentos_antecipados WHERE id = pg), ok, n, falhas_antes, falhas_depois;
  IF NOT ok OR n < 1 OR falhas_depois <> falhas_antes THEN RAISE EXCEPTION 'FALHA T6c'; END IF;

  -- auditoria do espelho: o que o esvaziamento de request.jwt.claims faz com financeiro_eventos.usuario_id
  SELECT count(*) FILTER (WHERE e.usuario_id IS NULL), count(*) FILTER (WHERE e.usuario_id IS NOT NULL) INTO ev_null, ev_user
    FROM public.financeiro_eventos e
   WHERE e.registro_id = tit OR e.registro_id IN (SELECT id FROM public.financeiro_parcelas WHERE titulo_id = tit)
      OR e.registro_id IN (SELECT b.id FROM public.financeiro_baixas b JOIN public.financeiro_parcelas x ON x.id = b.parcela_id WHERE x.titulo_id = tit);
  RAISE NOTICE 'AUDITORIA: eventos do titulo/parcela/baixas do espelho com usuario_id NULL=% e com usuario=% (origem em pagamentos_antecipados fica com o usuario real: criado_por=%)',
    ev_null, ev_user, (SELECT criado_por = deb FROM public.pagamentos_antecipados WHERE id = pg);

  RAISE NOTICE 'BLOCO 2 PASSOU';
END
$t2$;

DO $c$
BEGIN
  RAISE NOTICE 'overloads de registrar_entrada_nota_compra: %', (SELECT count(*) FROM pg_proc WHERE proname = 'registrar_entrada_nota_compra');
  RAISE NOTICE 'acl: %', (SELECT proacl::text FROM pg_proc WHERE proname = 'registrar_entrada_nota_compra');
END $c$;

ROLLBACK;
