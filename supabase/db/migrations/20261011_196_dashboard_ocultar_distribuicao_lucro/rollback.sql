-- Rollback da 196: volta as views sem filtro, devolve o grant de anon e apaga a função.
CREATE OR REPLACE VIEW public.v_financeiro_realizado AS
WITH pc AS (
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
            row_number() OVER (PARTITION BY n.cod_duplicata, n.tipo ORDER BY n.created_at) AS rn
           FROM (negociacoes n
             JOIN stg_duplicatas_vigentes v ON (((v.cod_duplicata = n.cod_duplicata) AND (v.tipo = n.tipo))))
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
  WHERE (t.status_pago <> 2);

CREATE OR REPLACE VIEW public.v_cash_flow_lucenera AS
SELECT dt_pagamento,
    dt_vencimento,
    (tipo)::text AS tipo,
        CASE
            WHEN (((descricao ~~* '%LUCRO%'::text) OR (descricao ~~* '%RETIRADA%'::text)) AND ((tipo)::text = 'despesa'::text)) THEN 'distribuicao_lucro'::text
            ELSE (tipo)::text
        END AS categoria_fluxo,
    vl_pago,
    descricao,
    status_pago
   FROM transacoes
  WHERE ((status_pago = 1) AND (dt_pagamento IS NOT NULL));

GRANT ALL ON public.v_financeiro_realizado TO anon;
GRANT ALL ON public.v_cash_flow_lucenera TO anon;
DROP FUNCTION IF EXISTS public.pode_ver_distribuicao_lucro();
