-- Rollback 358: volta a baixar na hora e o pedido so por lista. A coluna pedido_numero_manual fica (dados digitados nao se perdem).
BEGIN;
CREATE OR REPLACE FUNCTION public.financeiro_espelhar_pagamento_antecipado(p_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
END $function$;

CREATE OR REPLACE FUNCTION public.financeiro_lancar_antecipacao(p_natureza fin_natureza, p_empresa_id uuid, p_perfil text, p_contato_id uuid, p_responsavel_id uuid, p_emissao date, p_data_pagamento date, p_valor numeric, p_plano_contas_id uuid, p_conta_bancaria_id uuid, p_forma text DEFAULT NULL::text, p_observacao text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_tit uuid; v_par uuid;
BEGIN
    IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sem usuario autenticado.' USING ERRCODE = '42501'; END IF;
    PERFORM public.financeiro_exige('adiantamento'::public.fin_especie);
    IF p_natureza IS DISTINCT FROM 'receber' THEN
        RAISE EXCEPTION 'Antecipacao a pagar ainda nao esta liberada: use o pagamento antecipado de fornecedor (SPEC-215) ate a unificacao (SPEC-270 P5).' USING ERRCODE = 'P0001';
    END IF;
    IF coalesce(p_valor, 0) <= 0 THEN RAISE EXCEPTION 'Informe o valor da antecipacao.' USING ERRCODE = 'P0001'; END IF;
    IF p_emissao IS NULL OR p_data_pagamento IS NULL THEN RAISE EXCEPTION 'Informe a data de emissao e a data do pagamento.' USING ERRCODE = 'P0001'; END IF;
    IF p_data_pagamento > current_date THEN RAISE EXCEPTION 'A data do pagamento nao pode ser futura: a antecipacao e um valor que ja entrou.' USING ERRCODE = 'P0001'; END IF;
    IF p_perfil IS NOT NULL AND p_perfil NOT IN ('ribeirao', 'sao_paulo') THEN RAISE EXCEPTION 'Perfil da empresa invalido.' USING ERRCODE = 'P0001'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.empresas WHERE id = p_empresa_id) THEN RAISE EXCEPTION 'Empresa nao encontrada.' USING ERRCODE = 'P0001'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.contatos WHERE id = p_contato_id AND tipo = 'cliente') THEN RAISE EXCEPTION 'Informe o cliente que pagou a antecipacao.' USING ERRCODE = 'P0001'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.plano_de_contas WHERE id = p_plano_contas_id AND nivel = 3 AND ativo) THEN RAISE EXCEPTION 'Informe a apropriacao (grupo / subgrupo / apropriacao).' USING ERRCODE = 'P0001'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.contas_bancarias WHERE id = p_conta_bancaria_id) THEN RAISE EXCEPTION 'Informe a conta bancaria em que o valor entrou.' USING ERRCODE = 'P0001'; END IF;
    IF p_responsavel_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.usuarios WHERE id = p_responsavel_id) THEN
        RAISE EXCEPTION 'Informe o responsavel (equipe do orcamento).' USING ERRCODE = 'P0001';
    END IF;
    IF p_responsavel_id = auth.uid() THEN
        RAISE EXCEPTION 'O responsavel e a equipe do orcamento (quem gera a LT), nunca quem esta lancando.' USING ERRCODE = 'P0001';
    END IF;

    v_tit := public.financeiro_criar_titulo(
        jsonb_build_object('natureza', 'receber', 'origem_tipo', 'adiantamento', 'especie', 'adiantamento',
                           'empresa_id', p_empresa_id, 'perfil', p_perfil, 'contato_id', p_contato_id,
                           'plano_contas_id', p_plano_contas_id, 'descricao', nullif(btrim(coalesce(p_observacao, '')), '')),
        jsonb_build_array(jsonb_build_object('vencimento', p_data_pagamento, 'valor', round(p_valor, 2), 'situacao', 'firme',
                                             'observacao', nullif(btrim(coalesce(p_observacao, '')), ''))));
    UPDATE public.financeiro_titulos SET responsavel_id = p_responsavel_id WHERE id = v_tit;
    SELECT id INTO v_par FROM public.financeiro_parcelas WHERE titulo_id = v_tit AND numero = 1;
    UPDATE public.financeiro_parcelas SET emissao = p_emissao WHERE id = v_par;
    PERFORM public.financeiro_baixar(v_par, 'recebimento', round(p_valor, 2), p_data_pagamento, p_conta_bancaria_id,
                                     coalesce(nullif(btrim(coalesce(p_forma, '')), ''), 'Antecipacao'), NULL, 0, 0, 0, NULL, NULL, 'antecipacao');
    RETURN v_tit;
END $function$;

DROP FUNCTION IF EXISTS public.lancar_pagamento_antecipado(uuid, uuid, numeric, date, uuid, text, text);
CREATE OR REPLACE FUNCTION public.lancar_pagamento_antecipado(p_fornecedor_id uuid, p_empresa_id uuid, p_valor numeric, p_data_pagamento date, p_pedido_compra_id uuid DEFAULT NULL::uuid, p_observacao text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id uuid;
  v_status text;
BEGIN
  IF NOT (public.pode_acessar_sistema('financeiro') OR public.pode_acessar_sistema('dashboard-financeiro')) THEN
    RAISE EXCEPTION 'Sem permissao para lancar pagamento antecipado.' USING ERRCODE = '42501';
  END IF;
  IF coalesce(p_valor, 0) <= 0 THEN
    RAISE EXCEPTION 'Informe o valor pago.' USING ERRCODE = 'P0001';
  END IF;
  IF p_data_pagamento IS NULL THEN
    RAISE EXCEPTION 'Informe a data do pagamento.' USING ERRCODE = 'P0001';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.contatos WHERE id = p_fornecedor_id) THEN
    RAISE EXCEPTION 'Fornecedor nao encontrado.' USING ERRCODE = 'P0001';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.empresas WHERE id = p_empresa_id) THEN
    RAISE EXCEPTION 'Empresa nao encontrada.' USING ERRCODE = 'P0001';
  END IF;
  IF p_pedido_compra_id IS NOT NULL THEN
    SELECT status INTO v_status FROM public.pedidos_compra WHERE id = p_pedido_compra_id;
    IF v_status IS NULL THEN
      RAISE EXCEPTION 'Pedido de compra nao encontrado.' USING ERRCODE = 'P0001';
    END IF;
    IF v_status = 'cancelado' THEN
      RAISE EXCEPTION 'Pedido de compra cancelado.' USING ERRCODE = 'P0001';
    END IF;
  END IF;

  INSERT INTO public.pagamentos_antecipados
    (fornecedor_id, empresa_id, pedido_compra_id, valor, data_pagamento, observacao, criado_por)
  VALUES (p_fornecedor_id, p_empresa_id, p_pedido_compra_id, round(p_valor, 2), p_data_pagamento,
          nullif(trim(coalesce(p_observacao, '')), ''), auth.uid())
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$function$;
REVOKE ALL ON FUNCTION public.lancar_pagamento_antecipado(uuid, uuid, numeric, date, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.lancar_pagamento_antecipado(uuid, uuid, numeric, date, uuid, text) TO authenticated;

CREATE OR REPLACE VIEW public.vw_pagamentos_antecipados AS
 SELECT a.id,
    a.fornecedor_id,
    c.nome AS fornecedor_nome,
    regexp_replace(COALESCE(NULLIF((c.cnpj)::text, ''::text), (c.cpf_cnpj)::text, ''::text), '\D'::text, ''::text, 'g'::text) AS fornecedor_documento,
    a.empresa_id,
    e.nome AS empresa_nome,
    a.pedido_compra_id,
    p.numero AS pedido_numero,
    a.valor,
    a.data_pagamento,
    a.observacao,
    a.criado_em,
    a.criado_por,
    u.nome AS criado_por_nome,
    a.cancelado_em,
    a.motivo_cancelamento,
    (COALESCE(v.aplicado, (0)::numeric))::numeric(14,2) AS valor_aplicado,
    ((a.valor - COALESCE(v.aplicado, (0)::numeric)))::numeric(14,2) AS saldo,
    COALESCE(v.notas, ''::text) AS notas_vinculadas,
        CASE
            WHEN (a.cancelado_em IS NOT NULL) THEN 'cancelado'::text
            WHEN (COALESCE(v.aplicado, (0)::numeric) = (0)::numeric) THEN 'disponivel'::text
            WHEN (COALESCE(v.aplicado, (0)::numeric) < a.valor) THEN 'usado_em_parte'::text
            ELSE 'usado'::text
        END AS situacao
   FROM (((((pagamentos_antecipados a
     JOIN contatos c ON ((c.id = a.fornecedor_id)))
     JOIN empresas e ON ((e.id = a.empresa_id)))
     LEFT JOIN pedidos_compra p ON ((p.id = a.pedido_compra_id)))
     LEFT JOIN usuarios u ON ((u.id = a.criado_por)))
     LEFT JOIN LATERAL ( SELECT sum(x.valor_aplicado) AS aplicado,
            string_agg(n.numero_nf, ', '::text ORDER BY x.criado_em) AS notas
           FROM (pagamento_antecipado_vinculos x
             JOIN notas_fiscais_compra n ON ((n.id = x.nota_id)))
          WHERE (x.pagamento_id = a.id)) v ON (true))
  WHERE (( SELECT pode_acessar_sistema('financeiro'::text) AS pode_acessar_sistema) OR ( SELECT pode_acessar_sistema('dashboard-financeiro'::text) AS pode_acessar_sistema));

CREATE OR REPLACE VIEW public.vw_contas_pagar_pedidos_compra AS
 WITH consumo AS (
         SELECT p.id AS pedido_id,
            (COALESCE(( SELECT sum(n.valor) AS sum
                   FROM notas_fiscais_compra n
                  WHERE ((n.pedido_compra_id = p.id) AND (n.cancelada_em IS NULL))), (0)::numeric) + COALESCE(( SELECT sum((a.valor - COALESCE(( SELECT sum(x.valor_aplicado) AS sum
                           FROM pagamento_antecipado_vinculos x
                          WHERE (x.pagamento_id = a.id)), (0)::numeric))) AS sum
                   FROM pagamentos_antecipados a
                  WHERE ((a.pedido_compra_id = p.id) AND (a.cancelado_em IS NULL))), (0)::numeric)) AS consumido
           FROM pedidos_compra p
        ), parcelas AS (
         SELECT x.id,
            x.pedido_id,
            x.numero_parcela,
            x.valor,
            x.data_vencimento,
            x.status,
            x.forma_pagamento,
            x.observacao,
            x.criado_em,
            x.atualizado_em,
            count(*) OVER (PARTITION BY x.pedido_id) AS total_parcelas,
            sum(x.valor) OVER (PARTITION BY x.pedido_id ORDER BY x.numero_parcela ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS acumulado
           FROM pedido_compra_parcelas x
          WHERE (x.status <> 'cancelado'::text)
        ), previsao AS (
         SELECT x.id,
            x.pedido_id,
            x.numero_parcela,
            x.valor,
            x.data_vencimento,
            x.status,
            x.forma_pagamento,
            x.observacao,
            x.criado_em,
            x.atualizado_em,
            x.total_parcelas,
            x.acumulado,
            (GREATEST((0)::numeric, LEAST(x.valor, (x.acumulado - COALESCE(k.consumido, (0)::numeric)))))::numeric(14,2) AS restante
           FROM (parcelas x
             LEFT JOIN consumo k ON ((k.pedido_id = x.pedido_id)))
        ), nota_parcelas AS (
         SELECT np.id,
            np.nota_id,
            np.numero_parcela,
            np.data_vencimento,
            np.valor,
            np.criado_em,
            count(*) OVER (PARTITION BY np.nota_id) AS total_parcelas
           FROM nota_fiscal_compra_parcelas np
        )
 SELECT ('pc:'::text || (x.id)::text) AS id,
    'despesa'::text AS tipo,
    format('Pedido de compra %s — %s (parcela %s/%s)'::text, p.numero, COALESCE(c.nome, 'fornecedor'::text), x.numero_parcela, x.total_parcelas) AS descricao,
    'PEDIDOS DE COMPRA'::text AS desc_sub_grupo,
    'DESPESAS'::text AS desc_grupo,
    'despesa_operacional'::text AS natureza,
    0 AS status_pago,
    NULL::date AS dt_pagamento,
    x.data_vencimento AS dt_vencimento,
    p.data_emissao AS dt_emissao,
    (0)::numeric AS vl_pago,
    (x.restante)::numeric AS vl_parcela,
    (0)::numeric AS vl_desconto,
    p.empresa_id,
    NULL::integer AS cod_duplicata,
    'variavel'::text AS tipo_custo,
    p.perfil,
    'pedido_compra'::text AS origem,
    p.id AS pedido_compra_id,
    p.numero AS pedido_numero,
    p.status AS pedido_status
   FROM ((previsao x
     JOIN pedidos_compra p ON ((p.id = x.pedido_id)))
     LEFT JOIN contatos c ON ((c.id = p.fornecedor_id)))
  WHERE ((p.status = ANY (ARRAY['aprovado'::text, 'parcialmente_recebido'::text])) AND (p.numero !~~ 'PC-LEGADO-%'::text) AND (x.status = ANY (ARRAY['pendente'::text, 'atrasado'::text])) AND (x.data_vencimento IS NOT NULL) AND (x.restante > (0)::numeric) AND ( SELECT pode_acessar_sistema('dashboard-financeiro'::text) AS pode_acessar_sistema))
UNION ALL
 SELECT ('nf:'::text || (np.id)::text) AS id,
    'despesa'::text AS tipo,
    format('Nota %s — %s (parcela %s/%s, pedido %s)'::text, n.numero_nf, COALESCE(c.nome, 'fornecedor'::text), np.numero_parcela, np.total_parcelas, p.numero) AS descricao,
    COALESCE(pc2.nome, pc3.nome, 'PEDIDOS DE COMPRA'::text) AS desc_sub_grupo,
    COALESCE(pc1.nome, pc2.nome, 'DESPESAS'::text) AS desc_grupo,
    'despesa_operacional'::text AS natureza,
    0 AS status_pago,
    NULL::date AS dt_pagamento,
    np.data_vencimento AS dt_vencimento,
    COALESCE(n.data_emissao, p.data_emissao) AS dt_emissao,
    (0)::numeric AS vl_pago,
    (np.valor)::numeric AS vl_parcela,
    (0)::numeric AS vl_desconto,
    COALESCE(n.empresa_id, p.empresa_id) AS empresa_id,
    NULL::integer AS cod_duplicata,
    'variavel'::text AS tipo_custo,
    p.perfil,
    'nota_compra'::text AS origem,
    p.id AS pedido_compra_id,
    p.numero AS pedido_numero,
    p.status AS pedido_status
   FROM ((((((nota_parcelas np
     JOIN notas_fiscais_compra n ON ((n.id = np.nota_id)))
     JOIN pedidos_compra p ON ((p.id = n.pedido_compra_id)))
     LEFT JOIN contatos c ON ((c.id = COALESCE(n.fornecedor_id, p.fornecedor_id))))
     LEFT JOIN plano_de_contas pc3 ON ((pc3.id = n.plano_contas_id)))
     LEFT JOIN plano_de_contas pc2 ON ((pc2.id = pc3.parent_id)))
     LEFT JOIN plano_de_contas pc1 ON ((pc1.id = pc2.parent_id)))
  WHERE ((p.status <> 'cancelado'::text) AND (n.cancelada_em IS NULL) AND (NOT (EXISTS ( SELECT 1
           FROM negociacoes g
          WHERE ((g.tipo = 'despesa'::transacao_tipo) AND (g.empresa_id = COALESCE(n.empresa_id, p.empresa_id)) AND ((g.num_nota)::numeric = (NULLIF(regexp_replace(n.numero_nf, '\D'::text, ''::text, 'g'::text), ''::text))::numeric) AND (abs((COALESCE(( SELECT sum(t.vl_parcela) AS sum
                   FROM transacoes t
                  WHERE ((t.negociacao_id = g.id) AND (t.status_pago <> 2))), (0)::numeric) - n.valor)) <= (1)::numeric))))) AND ( SELECT pode_acessar_sistema('dashboard-financeiro'::text) AS pode_acessar_sistema))
UNION ALL
 SELECT ('pa:'::text || (a.id)::text) AS id,
    'despesa'::text AS tipo,
    format('Pagamento antecipado — %s%s'::text, COALESCE(c.nome, 'fornecedor'::text),
        CASE
            WHEN (p.numero IS NOT NULL) THEN ((' (pedido '::text || p.numero) || ')'::text)
            ELSE ''::text
        END) AS descricao,
    'PAGAMENTO ANTECIPADO'::text AS desc_sub_grupo,
    'DESPESAS'::text AS desc_grupo,
    'despesa_operacional'::text AS natureza,
    1 AS status_pago,
    a.data_pagamento AS dt_pagamento,
    a.data_pagamento AS dt_vencimento,
    a.data_pagamento AS dt_emissao,
    (a.valor)::numeric AS vl_pago,
    (a.valor)::numeric AS vl_parcela,
    (0)::numeric AS vl_desconto,
    a.empresa_id,
    NULL::integer AS cod_duplicata,
    'variavel'::text AS tipo_custo,
    p.perfil,
    'pagamento_antecipado'::text AS origem,
    p.id AS pedido_compra_id,
    p.numero AS pedido_numero,
    p.status AS pedido_status
   FROM ((pagamentos_antecipados a
     LEFT JOIN pedidos_compra p ON ((p.id = a.pedido_compra_id)))
     LEFT JOIN contatos c ON ((c.id = a.fornecedor_id)))
  WHERE ((a.cancelado_em IS NULL) AND ( SELECT pode_acessar_sistema('dashboard-financeiro'::text) AS pode_acessar_sistema));
COMMIT;
