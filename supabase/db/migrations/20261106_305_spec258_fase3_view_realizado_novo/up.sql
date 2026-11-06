-- SPEC-258 Fase 3 (passo 1): view v_financeiro_realizado_novo = MESMAS colunas e regras da v_financeiro_realizado, lendo do modelo novo.
-- Aditivo: a view antiga e todas as tabelas antigas ficam como estão. Os sistemas só trocam de view quando o ensaio provar 0 diferenças.
-- Para a view ser idêntica, a parcela nova passa a guardar também a emissão e a descrição da transação da Connect (copiadas, só leitura).

ALTER TABLE public.financeiro_parcelas ADD COLUMN IF NOT EXISTS emissao date;
ALTER TABLE public.financeiro_parcelas ADD COLUMN IF NOT EXISTS descricao text;
ALTER TABLE public.financeiro_parcelas ADD COLUMN IF NOT EXISTS desconto numeric(14,2) NOT NULL DEFAULT 0 CHECK (desconto >= 0);
COMMENT ON COLUMN public.financeiro_parcelas.emissao   IS 'SPEC-258: data de emissão da parcela (legado: dt_emissao da Connect).';
COMMENT ON COLUMN public.financeiro_parcelas.desconto  IS 'SPEC-258: desconto concedido na parcela (legado: vl_desconto da Connect). Informativo.';
COMMENT ON COLUMN public.financeiro_parcelas.descricao IS 'SPEC-258: descrição da parcela (legado: descricao da transação).';

UPDATE public.financeiro_parcelas p
   SET emissao = t.dt_emissao, descricao = t.descricao, desconto = greatest(coalesce(t.vl_desconto, 0), 0)
  FROM public.financeiro_legado_ids l
  JOIN public.transacoes t ON t.id = l.id_antigo
 WHERE l.tabela_antiga = 'transacoes' AND l.id_novo = p.id AND p.emissao IS NULL AND p.descricao IS NULL AND p.desconto = 0;

CREATE OR REPLACE VIEW public.v_financeiro_realizado_novo AS
SELECT y.id, y.tipo, y.descricao, y.desc_sub_grupo, y.desc_grupo, y.natureza, y.status_pago, y.dt_pagamento, y.dt_vencimento, y.dt_emissao,
       y.vl_pago, y.vl_parcela, y.vl_desconto, y.empresa_id, y.cod_duplicata, y.tipo_custo, y.perfil, y.previsao
FROM (
    SELECT x.* FROM (
        WITH hierarquia AS (
            SELECT p3.id AS plano_contas_id, COALESCE(p2.nome, p3.nome) AS desc_sub_grupo, COALESCE(p1.nome, p2.nome, p3.nome) AS desc_grupo
            FROM public.plano_de_contas p3
            LEFT JOIN public.plano_de_contas p2 ON p2.id = p3.parent_id
            LEFT JOIN public.plano_de_contas p1 ON p1.id = p2.parent_id
        )
        SELECT COALESCE(l.id_antigo, p.id) AS id,
               (CASE WHEN t.natureza = 'receber' THEN 'receita' ELSE 'despesa' END)::public.transacao_tipo AS tipo,
               p.descricao,
               h.desc_sub_grupo,
               h.desc_grupo,
               CASE
                   WHEN t.natureza = 'pagar' AND (h.desc_sub_grupo ~~* '%FILIPPO%' OR h.desc_sub_grupo ~~* '%MANOELLA%' OR p.descricao ~~* '%RETIRADA LUCRO%'
                                                  OR p.descricao ~~* '%RETIRADA DE LUCRO%' OR p.descricao ~~* '%LUCRO DISTRIB%') THEN 'distribuicao_lucro'::text
                   WHEN t.natureza = 'pagar' THEN 'despesa_operacional'::text
                   ELSE NULL::text
               END AS natureza,
               (CASE WHEN b.n_baixas > 0 AND p.valor_liquidado >= p.valor THEN 1 ELSE 0 END)::smallint AS status_pago,
               CASE WHEN b.n_baixas > 0 AND p.valor_liquidado >= p.valor THEN b.ultima_data END AS dt_pagamento,
               p.vencimento AS dt_vencimento,
               p.emissao AS dt_emissao,
               CASE WHEN b.n_baixas > 0 AND p.valor_liquidado >= p.valor THEN b.dinheiro ELSE 0 END AS vl_pago,
               p.valor AS vl_parcela,
               p.desconto AS vl_desconto,
               t.empresa_id,
               t.legado_cod_duplicata AS cod_duplicata,
               CASE
                   WHEN t.natureza <> 'pagar' THEN NULL::text
                   WHEN h.desc_sub_grupo = ANY (ARRAY['FIXAS', 'COM PESSOAL', 'ADMINISTRATIVAS', 'BANCARIAS', 'VEICULOS']) THEN 'fixo'::text
                   WHEN h.desc_sub_grupo = ANY (ARRAY['COM VENDAS', 'PRODUTOS']) THEN 'variavel'::text
                   ELSE 'outro'::text
               END AS tipo_custo,
               t.perfil,
               (p.situacao = 'prevista' AND NOT (b.n_baixas > 0 AND p.valor_liquidado >= p.valor)) AS previsao
        FROM public.financeiro_parcelas p
        JOIN public.financeiro_titulos t ON t.id = p.titulo_id
        LEFT JOIN public.financeiro_legado_ids l ON l.id_novo = p.id AND l.tabela_antiga = 'transacoes'
        LEFT JOIN hierarquia h ON h.plano_contas_id = t.plano_contas_id
        LEFT JOIN LATERAL (
            SELECT count(*) FILTER (WHERE bx.tipo <> 'estorno') AS n_baixas,
                   max(bx.data) FILTER (WHERE bx.tipo <> 'estorno') AS ultima_data,
                   coalesce(sum(CASE WHEN bx.movimenta_caixa THEN bx.valor + bx.juros
                                     WHEN bx.tipo = 'estorno' AND o.movimenta_caixa THEN -(o.valor + o.juros) ELSE 0 END), 0) AS dinheiro,
                   coalesce(sum(CASE WHEN bx.movimenta_caixa THEN bx.desconto ELSE 0 END), 0) AS desconto
            FROM public.financeiro_baixas bx LEFT JOIN public.financeiro_baixas o ON o.id = bx.estorno_de
            WHERE bx.parcela_id = p.id
        ) b ON true
        WHERE p.situacao IN ('prevista', 'firme') AND t.cancelado_em IS NULL
    ) x
    WHERE x.natureza IS DISTINCT FROM 'distribuicao_lucro'::text OR (SELECT public.pode_ver_distribuicao_lucro())
) y
WHERE (SELECT public.pode_acessar_sistema('dashboard-financeiro'));

GRANT SELECT ON public.v_financeiro_realizado_novo TO authenticated;
REVOKE ALL ON public.v_financeiro_realizado_novo FROM anon;
COMMENT ON VIEW public.v_financeiro_realizado_novo IS 'SPEC-258 Fase 3: mesma saída da v_financeiro_realizado, lendo financeiro_titulos/parcelas/baixas.';
