-- SPEC-307 A2 (Debora, Central 13/11/2026 18:16): campo de FRETE separado na Entrada de NF.
-- Coluna nova notas_fiscais_compra.valor_frete; registrar_entrada_nota_compra grava p_nota->>'valor_frete'; espelho devolve o frete.
-- O total da nota continua vindo da tela (produtos + IPI + ST + frete + despesas acessorias - desconto). Mesmas assinaturas (sem sobrecarga).
BEGIN;
ALTER TABLE public.notas_fiscais_compra ADD COLUMN IF NOT EXISTS valor_frete numeric(12,2) CHECK (valor_frete IS NULL OR valor_frete >= 0);

CREATE OR REPLACE FUNCTION public.registrar_entrada_nota_compra(p_pedido_id uuid, p_itens jsonb, p_nota jsonb, p_parcelas jsonb DEFAULT '[]'::jsonb, p_antecipacoes jsonb DEFAULT '[]'::jsonb, p_fornecedor_id uuid DEFAULT NULL::uuid, p_vinculos jsonb DEFAULT '[]'::jsonb, p_pagamento jsonb DEFAULT NULL::jsonb, p_vinculos_pagamento jsonb DEFAULT NULL::jsonb)
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
  v_par        record;
  v_vinc_total numeric := 0;
  v_vinc_n     integer := 0;
  v_dup        text;
  v_pode_fin   boolean := false;
  v_forcar     boolean := false;
  v_teto       numeric;
BEGIN
  IF NOT public.hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar') THEN
    RAISE EXCEPTION 'Sem permissao para dar entrada em pedido de compra.' USING ERRCODE = '42501';
  END IF;

  SELECT id, numero, status, fornecedor_id, empresa_id, valor_total, data_emissao INTO v_ped
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
     chave_acesso, data_entrega, data_entrada, plano_contas_id, valor_desconto, valor_despesas_acessorias, valor_frete)
  VALUES (p_pedido_id, v_numero_nf, nullif(p_nota->>'data_emissao', '')::date, v_valor,
          nullif(round(coalesce(nullif(p_nota->>'valor_st', '')::numeric, 0), 2), 0),
          nullif(p_nota->>'arquivo_url', ''), nullif(trim(coalesce(p_nota->>'observacao', '')), ''),
          auth.uid(), v_forn, v_ped.empresa_id,
          v_chave, nullif(p_nota->>'data_entrega', '')::date,
          coalesce(nullif(p_nota->>'data_entrada', '')::date, current_date), v_plano,
          nullif(round(coalesce(nullif(p_nota->>'valor_desconto', '')::numeric, 0), 2), 0),
          nullif(round(coalesce(nullif(p_nota->>'valor_despesas_acessorias', '')::numeric, 0), 2), 0),
          nullif(round(coalesce(nullif(p_nota->>'valor_frete', '')::numeric, 0), 2), 0))
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

  -- SPEC-290 B: vincula pagamento que JA EXISTE (duplicata paga da Connect / adiantamento) a esta nota. Nao cria titulo, parcela nem
  -- baixa: so registra a cobertura (pagamento_existente_vinculos). Cobertura total -> nota sem parcelas; parcial -> parcelas so do restante.
  -- Vem ANTES do uso automatico da antecipacao ligada ao pedido (que so aplica o que sobrar da nota).
  IF p_vinculos_pagamento IS NOT NULL AND jsonb_typeof(p_vinculos_pagamento) = 'array' THEN
    FOR v_el IN SELECT * FROM jsonb_array_elements(p_vinculos_pagamento)
    LOOP
      v_qtd := round(coalesce(nullif(v_el->>'valor', '')::numeric, 0), 2);
      CONTINUE WHEN v_qtd = 0;
      IF v_qtd < 0 THEN
        RAISE EXCEPTION 'Valor do pagamento vinculado nao pode ser negativo.' USING ERRCODE = 'P0001';
      END IF;
      IF v_ped.status = 'cancelado' THEN
        RAISE EXCEPTION 'Pedido cancelado: nao da para vincular pagamento.' USING ERRCODE = 'P0001';
      END IF;
      SELECT p.id AS parcela_id, p.valor_liquidado, p.situacao::text AS situacao,
             t.id AS titulo_id, t.natureza::text AS natureza, t.origem_tipo::text AS origem, t.cancelado_em,
             t.contato_id, t.empresa_id,
             coalesce(t.legado_cod_duplicata::text, t.numero_duplicata::text, nullif(t.documento, ''), '') AS duplicata,
             (SELECT max(b.data) FROM public.financeiro_baixas b WHERE b.parcela_id = p.id AND b.tipo = 'pagamento') AS data_pag
        INTO v_par
        FROM public.financeiro_parcelas p JOIN public.financeiro_titulos t ON t.id = p.titulo_id
       WHERE p.id = nullif(v_el->>'parcela_id', '')::uuid
         FOR UPDATE OF p;
      IF v_par.parcela_id IS NULL THEN
        RAISE EXCEPTION 'Pagamento existente nao encontrado.' USING ERRCODE = 'P0001';
      END IF;
      IF v_par.natureza <> 'pagar' OR v_par.cancelado_em IS NOT NULL OR v_par.situacao IN ('cancelada', 'substituida', 'renegociada') THEN
        RAISE EXCEPTION 'A duplicata % nao esta valida para vinculo (cancelada ou nao e de pagar).', v_par.duplicata USING ERRCODE = 'P0001';
      END IF;
      IF v_par.origem NOT IN ('legado_connect', 'adiantamento') THEN
        RAISE EXCEPTION 'So pagamento da Connect ou adiantamento pode ser vinculado (duplicata %).', v_par.duplicata USING ERRCODE = 'P0001';
      END IF;
      IF EXISTS (SELECT 1 FROM public.pagamentos_antecipados a WHERE a.titulo_id = v_par.titulo_id) THEN
        RAISE EXCEPTION 'A duplicata % e uma antecipacao do sistema: use a antecipacao, nao o vinculo.', v_par.duplicata USING ERRCODE = 'P0001';
      END IF;
      IF coalesce(v_par.valor_liquidado, 0) <= 0 THEN
        RAISE EXCEPTION 'A duplicata % ainda nao foi paga.', v_par.duplicata USING ERRCODE = 'P0001';
      END IF;
      -- fornecedor da NOTA (v_forn): com fornecedor trocado na entrada, a duplicata do fornecedor antigo nao serve (NULL-safe)
      IF v_par.contato_id IS DISTINCT FROM v_forn THEN
        RAISE EXCEPTION 'A duplicata % e de outro fornecedor.', v_par.duplicata USING ERRCODE = 'P0001';
      END IF;
      IF v_par.empresa_id IS DISTINCT FROM v_ped.empresa_id THEN
        RAISE EXCEPTION 'A duplicata % e de outra empresa.', v_par.duplicata USING ERRCODE = 'P0001';
      END IF;
      -- mesma janela da lista de candidatos: paga a partir de (emissao do pedido - 3 dias)
      IF v_par.data_pag IS NULL OR v_ped.data_emissao IS NULL OR v_par.data_pag < v_ped.data_emissao - 3 THEN
        RAISE EXCEPTION 'A duplicata % foi paga fora da janela deste pedido (a partir de 3 dias antes da emissao).', v_par.duplicata USING ERRCODE = 'P0001';
      END IF;
      v_saldo := v_par.valor_liquidado - coalesce((SELECT sum(x.valor_aplicado) FROM public.pagamento_existente_vinculos x
                                                    WHERE x.parcela_id = v_par.parcela_id AND x.cancelado_em IS NULL), 0);
      IF v_qtd > v_saldo + 0.001 THEN
        RAISE EXCEPTION 'Valor vinculado (%) maior que o saldo da duplicata % (%).', v_qtd, v_par.duplicata, v_saldo USING ERRCODE = 'P0001';
      END IF;
      INSERT INTO public.pagamento_existente_vinculos
        (parcela_id, pedido_compra_id, nota_id, valor_aplicado, duplicata, pedido_numero, numero_nf, criado_por)
      VALUES (v_par.parcela_id, p_pedido_id, v_nota_id, v_qtd, nullif(v_par.duplicata, ''), v_ped.numero, v_numero_nf, auth.uid());
      -- teto: vinculos ativos do pedido + antecipacoes aplicadas as notas ativas do pedido nao passam do valor total (+ R$ 0,01)
      IF v_ped.valor_total IS NOT NULL THEN
        v_teto := coalesce((SELECT sum(x.valor_aplicado) FROM public.pagamento_existente_vinculos x
                             WHERE x.pedido_compra_id = p_pedido_id AND x.cancelado_em IS NULL), 0)
                + coalesce((SELECT sum(x.valor_aplicado) FROM public.pagamento_antecipado_vinculos x
                              JOIN public.notas_fiscais_compra n ON n.id = x.nota_id
                             WHERE n.pedido_compra_id = p_pedido_id AND n.cancelada_em IS NULL), 0);
        IF v_teto > v_ped.valor_total + 0.01 THEN
          RAISE EXCEPTION 'Pagamentos vinculados (%) passam do valor total do pedido (%).', v_teto, v_ped.valor_total USING ERRCODE = 'P0001';
        END IF;
      END IF;
      v_aplicado := v_aplicado + v_qtd;
      v_vinc_total := v_vinc_total + v_qtd;
      v_vinc_n := v_vinc_n + 1;
    END LOOP;
  END IF;

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
      -- SPEC-290 D: se ja existe pagamento equivalente do fornecedor (duplicata paga da Connect / adiantamento sem vinculo),
      -- a opcao "ja foi pago" NAO cria outro: manda vincular o existente. So quem tem acesso ao financeiro forca, com observacao.
      IF v_vinc_total > 0 THEN
        RAISE EXCEPTION 'Esta entrada ja vincula um pagamento existente: nao marque tambem "ja foi pago".' USING ERRCODE = 'P0001';
      END IF;
      SELECT string_agg(c.duplicata, ', ') INTO v_dup
        FROM public._pagamentos_existentes_candidatos(p_pedido_id, v_forn) c
       WHERE c.equivalente OR abs(c.saldo - v_pg_valor) <= 1.00;
      IF v_dup IS NOT NULL THEN
        v_pode_fin := public.pode_acessar_sistema('financeiro') OR public.pode_acessar_sistema('dashboard-financeiro');
        v_forcar := lower(coalesce(p_pagamento->>'forcar_novo', '')) IN ('true', 't', '1');
        IF NOT v_pode_fin THEN
          RAISE EXCEPTION 'Ja existe pagamento deste fornecedor para este pedido (duplicata %). Vincule o pagamento existente em vez de lancar outro; so o Financeiro pode lancar um novo.', v_dup
            USING ERRCODE = 'P0001';
        END IF;
        IF NOT v_forcar OR v_pg_obs IS NULL THEN
          RAISE EXCEPTION 'Ja existe pagamento equivalente (duplicata %). Para lancar um novo mesmo assim, confirme e informe a observacao.', v_dup
            USING ERRCODE = 'P0001';
        END IF;
        v_pg_obs := format('Lancado apesar de pagamento existente (dup. %s): %s', v_dup, v_pg_obs);
      END IF;
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
                                     'pagamento_criado', v_pg_criado, 'pagamento_aplicado', v_pg_aplic, 'pagamento_id', v_pg_id,
                                     'vinculos_pagamento', v_vinc_n, 'vinculo_pagamento_aplicado', v_vinc_total);
END;
$function$;

CREATE OR REPLACE FUNCTION public.espelho_entrada_nota_compra(p_nota_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v jsonb;
BEGIN
  IF NOT (public.hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, NULL)
          OR public.pode_acessar_sistema('separacao-parcial') OR public.pode_acessar_sistema('logistica')) THEN
    RAISE EXCEPTION 'Sem permissao.' USING ERRCODE = '42501';
  END IF;
  SELECT jsonb_build_object(
    'nota', jsonb_build_object('id', n.id, 'numero_nf', n.numero_nf, 'chave_acesso', n.chave_acesso,
             'data_emissao', n.data_emissao, 'data_entrega', n.data_entrega, 'data_entrada', n.data_entrada,
             'valor', n.valor, 'valor_st', n.valor_st, 'valor_desconto', n.valor_desconto,
             'valor_despesas_acessorias', n.valor_despesas_acessorias, 'valor_frete', n.valor_frete, 'observacao', n.observacao,
             'cancelada_em', n.cancelada_em, 'criado_em', n.criado_em,
             'pedido_numero', p.numero, 'fornecedor_nome', f.nome,
             'fornecedor_documento', regexp_replace(coalesce(nullif(f.cnpj, ''), f.cpf_cnpj, ''), '\D', '', 'g'),
             'empresa_nome', e.nome, 'apropriacao', pc.nome, 'lancado_por', u.nome),
    'itens', coalesce((
      SELECT jsonb_agg(jsonb_build_object('produto_id', g.produto_id, 'codigo', g.codigo, 'produto', g.produto,
               'quantidade', g.quantidade, 'valor_unitario', g.valor_unitario, 'valor_ipi', g.valor_ipi,
               'valor_st', g.valor_st) ORDER BY g.produto)
        FROM (SELECT pi.produto_id, pr.codigo_produto AS codigo, pr.nome AS produto, sum(x.quantidade) AS quantidade,
                     max(x.valor_unitario) AS valor_unitario, max(x.valor_ipi) AS valor_ipi, max(x.valor_st) AS valor_st
                FROM public.nota_fiscal_compra_itens x
                JOIN public.pedido_compra_itens pi ON pi.id = x.pedido_item_id
                JOIN public.produtos pr ON pr.id = pi.produto_id
               WHERE x.nota_id = n.id
               GROUP BY pi.produto_id, pr.codigo_produto, pr.nome) g), '[]'::jsonb),
    'vinculos', coalesce((
      SELECT jsonb_agg(jsonb_build_object('produto_id', v.produto_id, 'quantidade', v.quantidade,
               'venda_numero', o.numero_venda, 'orcamento_numero', o.numero, 'cliente_nome', c.nome,
               'l_fixo', pit.l_fixo, 'projeto_codigo', prj.codigo) ORDER BY o.numero_venda, pit.l_fixo)
        FROM public.nota_fiscal_compra_vinculos v
        JOIN public.projeto_itens pit ON pit.id = v.projeto_item_id
        LEFT JOIN public.orcamentos o ON o.id = pit.orcamento_id
        LEFT JOIN public.projetos prj ON prj.id = pit.projeto_id
        LEFT JOIN public.contatos c ON c.id = coalesce(o.cliente_id, prj.cliente_id)
       WHERE v.nota_id = n.id), '[]'::jsonb),
    'parcelas', coalesce((
      SELECT jsonb_agg(jsonb_build_object('numero', np.numero_parcela, 'vencimento', np.data_vencimento,
               'valor', np.valor) ORDER BY np.numero_parcela)
        FROM public.nota_fiscal_compra_parcelas np WHERE np.nota_id = n.id), '[]'::jsonb),
    'antecipacao', coalesce((SELECT sum(valor_aplicado) FROM public.pagamento_antecipado_vinculos WHERE nota_id = n.id), 0))
    INTO v
    FROM public.notas_fiscais_compra n
    LEFT JOIN public.pedidos_compra p ON p.id = n.pedido_compra_id
    LEFT JOIN public.contatos f ON f.id = coalesce(n.fornecedor_id, p.fornecedor_id)
    LEFT JOIN public.empresas e ON e.id = coalesce(n.empresa_id, p.empresa_id)
    LEFT JOIN public.plano_de_contas pc ON pc.id = n.plano_contas_id
    LEFT JOIN public.usuarios u ON u.id = n.criado_por
   WHERE n.id = p_nota_id;
  IF v IS NULL THEN
    RAISE EXCEPTION 'Nota fiscal nao encontrada.' USING ERRCODE = 'P0001';
  END IF;
  RETURN v;
END;
$function$;

COMMIT;
