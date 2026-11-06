-- SPEC-248 item 3: desfaz a base da Previsão. Não dá para tirar coluna com CREATE OR REPLACE VIEW: recria a view como era.
DROP FUNCTION IF EXISTS public.definir_previsao_transacoes(uuid[], boolean, text);
DROP VIEW IF EXISTS public.v_financeiro_realizado;
CREATE VIEW public.v_financeiro_realizado AS
 SELECT id,
    tipo,
    descricao,
    desc_sub_grupo,
    desc_grupo,
    natureza,
    status_pago,
    dt_pagamento,
    dt_vencimento,
    dt_emissao,
    vl_pago,
    vl_parcela,
    vl_desconto,
    empresa_id,
    cod_duplicata,
    tipo_custo,
    perfil
   FROM ( SELECT x.id,
            x.tipo,
            x.descricao,
            x.desc_sub_grupo,
            x.desc_grupo,
            x.natureza,
            x.status_pago,
            x.dt_pagamento,
            x.dt_vencimento,
            x.dt_emissao,
            x.vl_pago,
            x.vl_parcela,
            x.vl_desconto,
            x.empresa_id,
            x.cod_duplicata,
            x.tipo_custo,
            x.perfil
           FROM ( WITH pc AS (
                         SELECT plano_de_contas.id,
                            plano_de_contas.codigo_connect,
                            plano_de_contas.nome,
                            plano_de_contas.nivel,
                            plano_de_contas.parent_id
                           FROM plano_de_contas
                        ), hierarquia AS (
                         SELECT p3.id AS plano_contas_id,
                            COALESCE(p2.nome, p3.nome) AS desc_sub_grupo,
                            COALESCE(p1.nome, p2.nome, p3.nome) AS desc_grupo
                           FROM ((pc p3
                             LEFT JOIN pc p2 ON ((p2.id = p3.parent_id)))
                             LEFT JOIN pc p1 ON ((p1.id = p2.parent_id)))
                        ), negociacao_preferida AS (
                         SELECT n.id,
                            n.cod_duplicata,
                            n.tipo,
                            n.plano_contas_id,
                            n.empresa_id,
                            row_number() OVER (PARTITION BY
                                CASE
                                    WHEN ((v.cod_duplicata IS NOT NULL) AND (n.created_at <= COALESCE(( SELECT e.encerrado_em
                                       FROM connect_financeiro_encerrado e
                                     LIMIT 1), 'infinity'::timestamp with time zone))) THEN (n.cod_duplicata)::text
                                    ELSE (n.id)::text
                                END, n.tipo ORDER BY n.created_at) AS rn
                           FROM (negociacoes n
                             LEFT JOIN stg_duplicatas_vigentes v ON (((v.cod_duplicata = n.cod_duplicata) AND (v.tipo = n.tipo))))
                          WHERE (((v.cod_duplicata IS NOT NULL) AND (n.created_at <= COALESCE(( SELECT e.encerrado_em
                                   FROM connect_financeiro_encerrado e
                                 LIMIT 1), 'infinity'::timestamp with time zone))) OR (n.created_at > COALESCE(( SELECT e.encerrado_em
                                   FROM connect_financeiro_encerrado e
                                 LIMIT 1), 'infinity'::timestamp with time zone)))
                        )
                 SELECT t.id,
                    t.tipo,
                    t.descricao,
                    h.desc_sub_grupo,
                    h.desc_grupo,
                        CASE
                            WHEN ((t.tipo = 'despesa'::transacao_tipo) AND ((h.desc_sub_grupo ~~* '%FILIPPO%'::text) OR (h.desc_sub_grupo ~~* '%MANOELLA%'::text) OR (t.descricao ~~* '%RETIRADA LUCRO%'::text) OR (t.descricao ~~* '%RETIRADA DE LUCRO%'::text) OR (t.descricao ~~* '%LUCRO DISTRIB%'::text))) THEN 'distribuicao_lucro'::text
                            WHEN (t.tipo = 'despesa'::transacao_tipo) THEN 'despesa_operacional'::text
                            ELSE NULL::text
                        END AS natureza,
                    t.status_pago,
                    t.dt_pagamento,
                    t.dt_vencimento,
                    t.dt_emissao,
                    t.vl_pago,
                    t.vl_parcela,
                    t.vl_desconto,
                    np.empresa_id,
                    np.cod_duplicata,
                        CASE
                            WHEN (t.tipo <> 'despesa'::transacao_tipo) THEN NULL::text
                            WHEN (h.desc_sub_grupo = ANY (ARRAY['FIXAS'::text, 'COM PESSOAL'::text, 'ADMINISTRATIVAS'::text, 'BANCARIAS'::text, 'VEICULOS'::text])) THEN 'fixo'::text
                            WHEN (h.desc_sub_grupo = ANY (ARRAY['COM VENDAS'::text, 'PRODUTOS'::text])) THEN 'variavel'::text
                            ELSE 'outro'::text
                        END AS tipo_custo,
                    t.perfil
                   FROM ((transacoes t
                     JOIN negociacao_preferida np ON (((np.id = t.negociacao_id) AND (np.rn = 1))))
                     LEFT JOIN hierarquia h ON ((h.plano_contas_id = np.plano_contas_id)))
                  WHERE (t.status_pago <> 2)) x
          WHERE ((x.natureza IS DISTINCT FROM 'distribuicao_lucro'::text) OR ( SELECT pode_ver_distribuicao_lucro() AS pode_ver_distribuicao_lucro))) y
  WHERE ( SELECT pode_acessar_sistema('dashboard-financeiro'::text) AS pode_acessar_sistema);
GRANT SELECT ON public.v_financeiro_realizado TO authenticated;
ALTER TABLE public.transacoes DROP COLUMN IF EXISTS previsao;
