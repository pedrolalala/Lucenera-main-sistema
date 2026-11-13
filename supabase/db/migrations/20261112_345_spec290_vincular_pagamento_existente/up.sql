-- SPEC-290 (Reuniao 52 / Debora, 12/11/2026): Compras / Entrada de NF - vincular o pagamento JA EXISTENTE (duplicata paga da Connect ou
-- adiantamento) em vez de abrir outro Contas a Pagar. Caso real: pedido 1985 x duplicata 8405 (R$ 2.204,30, paga em 04/11, sem num_nota).
-- A) _pagamentos_existentes_candidatos (interna) + pagamentos_existentes_para_entrada(pedido, fornecedor) (SECURITY DEFINER, so o necessario).
-- B) tabela pagamento_existente_vinculos (RLS, REVOKE anon, escrita so por RPC); registrar_entrada_nota_compra ganha p_vinculos_pagamento
--    (9o parametro; DROP da assinatura de 8 para nao deixar overload) e cancelar_entrada_nota_compra cancela o vinculo.
--    O vinculo NAO cria titulo/parcela/baixa. financeiro_ponte_pedido e vw_contas_pagar_pedidos_compra NAO mudam: ja contam o valor da
--    nota (notas_fiscais_compra.valor) como consumido, inclusive a parte coberta por vinculo; somar o vinculo seria dupla contagem
--    (e a antecipacao nativa so entra pelo saldo ainda NAO aplicado a notas, como antes).
-- C) vw_financeiro_duplicatas ganha a coluna pago_antecipado no FIM (sem dependentes) para o selo no Consultar Duplicatas (Pagar);
--    pedidos_pago_antecipado_info alimenta o selo/aviso do Compras. Nada e gravado na duplicata da Connect.
-- D) trava da opcao "este pedido ja foi pago" (SPEC-289): bloqueia se houver pagamento equivalente; so quem tem acesso ao financeiro
--    forca, com observacao obrigatoria (p_pagamento.forcar_novo = true).
-- Numero 345: a 344 ja existe (SPEC-290 do PDF das parcelas, aplicada).
BEGIN;

-- ===== B1. tabela de vinculos =====
CREATE TABLE public.pagamento_existente_vinculos (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  parcela_id       uuid NOT NULL REFERENCES public.financeiro_parcelas(id),
  pedido_compra_id uuid NOT NULL REFERENCES public.pedidos_compra(id),
  nota_id          uuid NOT NULL REFERENCES public.notas_fiscais_compra(id),
  valor_aplicado   numeric(14,2) NOT NULL CHECK (valor_aplicado > 0),
  -- rotulos gravados na hora (leitura rapida pelo selo, sem depender de RLS de outras tabelas)
  duplicata        text,
  pedido_numero    text,
  numero_nf        text,
  criado_por       uuid,
  criado_em        timestamptz NOT NULL DEFAULT now(),
  cancelado_em     timestamptz,
  cancelado_por    uuid,
  motivo_cancelamento text
);
CREATE INDEX pagamento_existente_vinculos_parcela_idx ON public.pagamento_existente_vinculos (parcela_id) WHERE cancelado_em IS NULL;
CREATE INDEX pagamento_existente_vinculos_nota_idx ON public.pagamento_existente_vinculos (nota_id);
CREATE INDEX pagamento_existente_vinculos_pedido_idx ON public.pagamento_existente_vinculos (pedido_compra_id) WHERE cancelado_em IS NULL;
COMMENT ON TABLE public.pagamento_existente_vinculos IS
  'SPEC-290: cobertura de uma nota de compra por pagamento que ja existia (duplicata paga da Connect / adiantamento). Nao movimenta dinheiro; so marca. Escrita so pelas RPCs.';

ALTER TABLE public.pagamento_existente_vinculos ENABLE ROW LEVEL SECURITY;
CREATE POLICY pagamento_existente_vinculos_select ON public.pagamento_existente_vinculos FOR SELECT TO authenticated
  USING ((SELECT public.pode_acessar_sistema('necessidade-de-compra')) OR (SELECT public.pode_acessar_sistema('financeiro'))
         OR (SELECT public.pode_acessar_sistema('dashboard-financeiro')) OR (SELECT public.pode_acessar_sistema('contas-pagar')));
REVOKE ALL ON public.pagamento_existente_vinculos FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.pagamento_existente_vinculos TO authenticated;
GRANT ALL ON public.pagamento_existente_vinculos TO service_role;
CREATE TRIGGER auditoria_registrar AFTER INSERT OR DELETE OR UPDATE ON public.pagamento_existente_vinculos
  FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar();

-- ===== A. deteccao =====
-- Parcelas PAGAS de "pagar" do mesmo fornecedor e empresa, de origem legado_connect (ou adiantamento fora do mecanismo nativo),
-- pagas a partir de (emissao do pedido - 3 dias), com saldo (pago - ja vinculado) e valor ate o total do pedido + R$ 1,00.
CREATE FUNCTION public._pagamentos_existentes_candidatos(p_pedido_id uuid, p_fornecedor_id uuid DEFAULT NULL)
 RETURNS TABLE(parcela_id uuid, duplicata text, valor numeric, saldo numeric, data_pagamento date, origem text,
               valor_igual boolean, equivalente boolean)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $f$
  WITH ped AS (
    SELECT id, coalesce(p_fornecedor_id, fornecedor_id) AS forn, empresa_id, valor_total, data_emissao
      FROM public.pedidos_compra WHERE id = p_pedido_id AND status <> 'cancelado'
  ), pag AS (
    SELECT p.id AS parcela_id, t.origem_tipo::text AS origem,
           coalesce(t.legado_cod_duplicata::text, t.numero_duplicata::text, nullif(t.documento, ''), '') AS duplicata,
           p.valor,
           p.valor_liquidado - coalesce((SELECT sum(x.valor_aplicado) FROM public.pagamento_existente_vinculos x
                                          WHERE x.parcela_id = p.id AND x.cancelado_em IS NULL), 0) AS saldo,
           (SELECT max(b.data) FROM public.financeiro_baixas b WHERE b.parcela_id = p.id AND b.tipo = 'pagamento') AS data_pag,
           ped.valor_total, ped.data_emissao
      FROM ped
      JOIN public.financeiro_titulos t ON t.natureza = 'pagar' AND t.cancelado_em IS NULL
                                      AND t.contato_id = ped.forn AND t.empresa_id = ped.empresa_id
                                      AND (t.origem_tipo = 'legado_connect'
                                           OR (t.origem_tipo = 'adiantamento'
                                               AND NOT EXISTS (SELECT 1 FROM public.pagamentos_antecipados a WHERE a.titulo_id = t.id)))
      JOIN public.financeiro_parcelas p ON p.titulo_id = t.id
                                       AND p.situacao NOT IN ('cancelada', 'substituida', 'renegociada')
                                       AND p.valor_liquidado > 0
  )
  SELECT g.parcela_id, g.duplicata, g.valor, g.saldo, g.data_pag, g.origem,
         (g.valor_total IS NOT NULL AND abs(g.saldo - g.valor_total) <= 0.01) AS valor_igual,
         (g.valor_total IS NOT NULL AND abs(g.saldo - g.valor_total) <= 1.00) AS equivalente
    FROM pag g
   WHERE g.saldo > 0.005
     AND g.data_pag IS NOT NULL
     AND g.data_pag >= g.data_emissao - 3
     AND (g.valor_total IS NULL OR g.saldo <= g.valor_total + 1.00)
   ORDER BY (g.valor_total IS NOT NULL AND abs(g.saldo - g.valor_total) <= 0.01) DESC, g.data_pag, g.duplicata;
$f$;
REVOKE ALL ON FUNCTION public._pagamentos_existentes_candidatos(uuid, uuid) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.pagamentos_existentes_para_entrada(p_pedido_id uuid, p_fornecedor_id uuid DEFAULT NULL)
 RETURNS TABLE(parcela_id uuid, duplicata text, valor numeric, saldo numeric, data_pagamento date, origem text,
               valor_igual boolean, equivalente boolean, pode_forcar boolean, outros_pedidos text)
 LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $f$
DECLARE v_forn uuid; v_emp uuid;
BEGIN
  IF NOT public.hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar') THEN
    RAISE EXCEPTION 'Sem permissao.' USING ERRCODE = '42501';
  END IF;
  SELECT coalesce(p_fornecedor_id, fornecedor_id), empresa_id INTO v_forn, v_emp FROM public.pedidos_compra WHERE id = p_pedido_id;
  -- pode_forcar: quem tem acesso ao financeiro pode lancar "ja foi pago" mesmo havendo equivalente (D2); a tela so mostra a opcao para esse usuario
  RETURN QUERY SELECT c.parcela_id, c.duplicata, c.valor, c.saldo, c.data_pagamento, c.origem, c.valor_igual, c.equivalente,
                      (public.pode_acessar_sistema('financeiro') OR public.pode_acessar_sistema('dashboard-financeiro')),
                      -- outros pedidos ABERTOS do mesmo fornecedor/empresa com valor parecido (a confirmacao e humana: qual compra o pagamento quitou?)
                      (SELECT string_agg(o.numero, ', ' ORDER BY o.numero) FROM public.pedidos_compra o
                        WHERE o.id <> p_pedido_id AND o.status NOT IN ('cancelado', 'recebido') AND o.fornecedor_id = v_forn AND o.empresa_id = v_emp
                          AND o.valor_total IS NOT NULL AND abs(o.valor_total - c.saldo) <= 1.00)
                 FROM public._pagamentos_existentes_candidatos(p_pedido_id, p_fornecedor_id) c;
END;
$f$;
REVOKE ALL ON FUNCTION public.pagamentos_existentes_para_entrada(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pagamentos_existentes_para_entrada(uuid, uuid) TO authenticated;
COMMENT ON FUNCTION public.pagamentos_existentes_para_entrada(uuid, uuid) IS
  'SPEC-290 A: pagamentos ja feitos (Connect/adiantamento) do fornecedor do pedido que podem ser vinculados na entrada da NF. So os campos necessarios.';

-- ===== C. selo/aviso no Compras: por pedido, a duplicata vinculada (selo, qualquer pedido nao cancelado) ou "falta vincular" (so pedido ABERTO,
-- condicao Antecipado, sem vinculo, sem antecipacao do sistema e sem nota ativa ja coberta). Permissao: 'visualizar' de necessidade-de-compra =====
CREATE FUNCTION public.pedidos_pago_antecipado_info(p_pedido_ids uuid[])
 RETURNS TABLE(pedido_id uuid, duplicata text, numero_nf text, falta_vincular boolean)
 LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $f$
BEGIN
  IF NOT public.hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'visualizar') THEN
    RAISE EXCEPTION 'Sem permissao.' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT v.pedido_compra_id, v.duplicata, v.numero_nf, false
    FROM public.pagamento_existente_vinculos v
   WHERE v.pedido_compra_id = ANY (p_pedido_ids) AND v.cancelado_em IS NULL
  UNION ALL
  SELECT p.id, NULL::text, NULL::text, true
    FROM public.pedidos_compra p
   WHERE p.id = ANY (p_pedido_ids) AND p.status NOT IN ('cancelado', 'recebido') AND p.numero NOT LIKE 'PC-LEGADO-%'
     AND lower(coalesce(p.condicoes_pagamento, '')) LIKE '%antecipad%'
     AND NOT EXISTS (SELECT 1 FROM public.pagamento_existente_vinculos v WHERE v.pedido_compra_id = p.id AND v.cancelado_em IS NULL)
     AND NOT EXISTS (SELECT 1 FROM public.pagamentos_antecipados a WHERE a.pedido_compra_id = p.id AND a.cancelado_em IS NULL)
     -- nota ativa ja coberta por pagamento antecipado: nao ha o que vincular
     AND NOT EXISTS (SELECT 1 FROM public.notas_fiscais_compra n JOIN public.pagamento_antecipado_vinculos x ON x.nota_id = n.id
                      WHERE n.pedido_compra_id = p.id AND n.cancelada_em IS NULL);
END;
$f$;
REVOKE ALL ON FUNCTION public.pedidos_pago_antecipado_info(uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pedidos_pago_antecipado_info(uuid[]) TO authenticated;

-- ===== B2/B3/D. entrada da nota (9 parametros) =====
DROP FUNCTION IF EXISTS public.registrar_entrada_nota_compra(uuid, jsonb, jsonb, jsonb, jsonb, uuid, jsonb, jsonb);

CREATE FUNCTION public.registrar_entrada_nota_compra(p_pedido_id uuid, p_itens jsonb, p_nota jsonb, p_parcelas jsonb DEFAULT '[]'::jsonb, p_antecipacoes jsonb DEFAULT '[]'::jsonb, p_fornecedor_id uuid DEFAULT NULL::uuid, p_vinculos jsonb DEFAULT '[]'::jsonb, p_pagamento jsonb DEFAULT NULL::jsonb, p_vinculos_pagamento jsonb DEFAULT NULL::jsonb)
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

REVOKE ALL ON FUNCTION public.registrar_entrada_nota_compra(uuid, jsonb, jsonb, jsonb, jsonb, uuid, jsonb, jsonb, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.registrar_entrada_nota_compra(uuid, jsonb, jsonb, jsonb, jsonb, uuid, jsonb, jsonb, jsonb) TO authenticated;
COMMENT ON FUNCTION public.registrar_entrada_nota_compra(uuid, jsonb, jsonb, jsonb, jsonb, uuid, jsonb, jsonb, jsonb) IS
  'SPEC-215/220/222/289/290: entrada da nota (quantidades, nota, parcelas, antecipacao, vinculo com cliente, estoque), pedido ja pago (p_pagamento) e vinculo com pagamento ja existente (p_vinculos_pagamento).';

-- ===== B5. cancelar a entrada cancela o vinculo (a duplicata da Connect permanece intacta) =====
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
BEGIN
  IF NOT public.hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar') THEN
    RAISE EXCEPTION 'Sem permissao para cancelar entrada de nota fiscal.' USING ERRCODE = '42501';
  END IF;
  IF v_motivo IS NULL THEN
    RAISE EXCEPTION 'Informe o motivo do cancelamento.' USING ERRCODE = 'P0001';
  END IF;

  SELECT id, numero_nf, pedido_compra_id, cancelada_em, estoque_somado_em INTO v_nota
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
                            'pedido_numero', v_ped.numero, 'pedido_status', v_novo,
                            'itens_devolvidos', v_itens, 'parcelas_removidas', v_parcelas,
                            'antecipacao_devolvida', v_antecip, 'vinculo_pagamento_cancelado', v_pgex, 'reserva_desfeita', v_desfeito,
                            'estoque_retirado', v_tirado);
END;
$function$;


-- ===== C1. coluna no FIM da view (sem dependentes; security_invoker mantido) =====
CREATE OR REPLACE VIEW public.vw_financeiro_duplicatas WITH (security_invoker = true) AS
 SELECT p.id AS parcela_id,
    t.id AS titulo_id,
    t.natureza,
        CASE
            WHEN t.natureza = 'pagar'::fin_natureza THEN 'CP'::text
            ELSE 'CR'::text
        END AS tipo_operacao,
        CASE
            WHEN COALESCE(n.num_nota::text, ''::text) <> ''::text OR t.origem_tipo = 'nota_fiscal_compra'::fin_origem THEN 'Nota Fiscal'::text
            ELSE 'Normal'::text
        END AS tipo,
        CASE
            WHEN p.situacao = ANY (ARRAY['cancelada'::fin_situacao, 'substituida'::fin_situacao, 'renegociada'::fin_situacao]) THEN 'Cancelado'::text
            WHEN b.n_baixas > 0 AND p.valor_liquidado >= p.valor THEN 'Pago'::text
            WHEN p.situacao = 'prevista'::fin_situacao THEN 'Previsto'::text
            ELSE 'Pendente'::text
        END AS status,
    p.situacao,
    COALESCE(t.legado_cod_duplicata::text, t.numero_duplicata::text, t.documento, o.numero_venda, o.numero, ''::text) AS numero_documento,
    p.numero AS num_parcela,
    ( SELECT count(*) AS count
           FROM financeiro_parcelas x
          WHERE x.titulo_id = t.id AND (x.situacao = ANY (ARRAY['prevista'::fin_situacao, 'firme'::fin_situacao]))) AS total_parcelas,
    COALESCE(n.cod_venda::text, o.numero_venda, ''::text) AS venda,
    COALESCE(n.num_nota::text,
        CASE
            WHEN t.origem_tipo = 'nota_fiscal_compra'::fin_origem THEN t.documento
            ELSE NULL::text
        END, ''::text) AS fatura,
    COALESCE(NULLIF(n.nome_pessoa, ''::text), NULLIF(n.razao_pessoa, ''::text), c.nome,
        CASE
            WHEN n.cod_pessoa IS NOT NULL THEN 'Pessoa '::text || n.cod_pessoa
            ELSE NULL::text
        END, ''::text) AS nome_pagador,
    p.emissao,
    p.vencimento,
        CASE
            WHEN b.n_baixas > 0 AND p.valor_liquidado >= p.valor THEN b.ultima_data
            ELSE NULL::date
        END AS data_pagamento,
    p.valor,
        CASE
            WHEN b.n_baixas > 0 AND p.valor_liquidado >= p.valor THEN b.dinheiro
            ELSE 0::numeric
        END AS valor_pago,
    b.juros_multa,
    GREATEST(p.desconto, b.abatimento)::numeric(14,2) AS desconto,
    COALESCE(b.forma, p.forma_prevista) AS forma_pagamento,
    COALESCE(p.descricao, t.descricao) AS observacao,
    t.perfil,
    e.nome AS empresa_nome,
    t.empresa_id,
    t.contato_id,
    t.plano_contas_id,
    pc.nome AS plano_contas_nome,
    t.projeto_id,
    t.origem_tipo,
    t.especie,
    p.valor_liquidado,
    p.valor - p.valor_liquidado AS saldo,
    t.legado_cod_duplicata,
    p.legado_cod_itens_duplicata,
    COALESCE(( SELECT bo.id
           FROM financeiro_legado_ids lt
             JOIN transacoes tx ON tx.id = lt.id_antigo
             JOIN boletos bo ON bo.parcela_id = tx.parcela_id
          WHERE lt.id_novo = p.id AND lt.tabela_antiga = 'transacoes'::text AND tx.parcela_id IS NOT NULL
         LIMIT 1), ( SELECT bo.id
           FROM financeiro_legado_ids ln2
             JOIN boletos bo ON bo.nosso_numero = ('NFC-'::text || ln2.id_antigo::text)
          WHERE ln2.id_novo = p.id AND ln2.tabela_antiga = 'nota_fiscal_compra_parcelas'::text
         LIMIT 1)) AS boleto_id,
    ( SELECT string_agg(('Pedido '::text || coalesce(v.pedido_numero, '?'::text)) || ' / NF '::text || coalesce(v.numero_nf, '?'::text), '; '::text ORDER BY v.criado_em) AS string_agg
           FROM pagamento_existente_vinculos v
          WHERE v.parcela_id = p.id AND v.cancelado_em IS NULL) AS pago_antecipado
   FROM financeiro_parcelas p
     JOIN financeiro_titulos t ON t.id = p.titulo_id
     LEFT JOIN financeiro_legado_ids ln ON ln.tabela_antiga = 'negociacoes'::text AND ln.id_novo = t.id
     LEFT JOIN negociacoes n ON n.id = ln.id_antigo
     LEFT JOIN orcamentos o ON o.id = t.orcamento_id
     LEFT JOIN contatos c ON c.id = t.contato_id
     LEFT JOIN empresas e ON e.id = t.empresa_id
     LEFT JOIN plano_de_contas pc ON pc.id = t.plano_contas_id
     LEFT JOIN LATERAL ( SELECT count(*) FILTER (WHERE bx.tipo <> 'estorno'::fin_baixa_tipo) AS n_baixas,
            max(bx.data) FILTER (WHERE bx.tipo <> 'estorno'::fin_baixa_tipo) AS ultima_data,
            COALESCE(sum(
                CASE
                    WHEN bx.movimenta_caixa THEN bx.valor + bx.juros
                    WHEN bx.tipo = 'estorno'::fin_baixa_tipo AND ox.movimenta_caixa THEN - (ox.valor + ox.juros)
                    ELSE 0::numeric
                END), 0::numeric) AS dinheiro,
            COALESCE(sum(
                CASE
                    WHEN bx.movimenta_caixa THEN bx.juros + bx.multa
                    WHEN bx.tipo = 'estorno'::fin_baixa_tipo AND ox.movimenta_caixa THEN - (ox.juros + ox.multa)
                    ELSE 0::numeric
                END), 0::numeric) AS juros_multa,
            COALESCE(sum(
                CASE
                    WHEN bx.tipo = 'abatimento'::fin_baixa_tipo THEN bx.valor
                    WHEN bx.tipo = 'estorno'::fin_baixa_tipo AND ox.tipo = 'abatimento'::fin_baixa_tipo THEN - bx.valor
                    ELSE 0::numeric
                END), 0::numeric) AS abatimento,
            (array_agg(bx.forma ORDER BY bx.criado_em DESC) FILTER (WHERE bx.tipo <> 'estorno'::fin_baixa_tipo))[1] AS forma
           FROM financeiro_baixas bx
             LEFT JOIN financeiro_baixas ox ON ox.id = bx.estorno_de
          WHERE bx.parcela_id = p.id) b ON true;

NOTIFY pgrst, 'reload schema';

COMMIT;
