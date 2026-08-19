-- Migration 20260819_121
-- Pedido do usuario (18/08/2026): transacoes.status_pago tem 3 valores
-- reais (0=ABERTO, 1=PAGO, 2=CANCELADO) — cancelado nunca deve contar
-- como despesa/receita nem como "em aberto" em lugar nenhum. O Dashboard
-- Financeiro satelite (dashboard-lucenera-b02z85wa3, cash-flow.ts) estava
-- tratando status_pago=2 como "aberto" (linha `aberto = status===0 ||
-- status===2`), inflando os totais de "Em Aberto Pagar/Receber" com
-- duplicatas canceladas.
--
-- Regra criada no sistema (nao so no frontend): v_financeiro_realizado —
-- unica fonte do Dashboard Financeiro — passa a excluir status_pago=2 na
-- propria view, pra nenhum consumidor atual ou futuro reintroduzir esse
-- bug sem querer. Resto da view identico ao ultimo estado real
-- (20260805_077).

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
           FROM pc p3
             LEFT JOIN pc p2 ON p2.id = p3.parent_id
             LEFT JOIN pc p1 ON p1.id = p2.parent_id
        ), negociacao_preferida AS (
         SELECT n.id,
            n.cod_duplicata,
            n.tipo,
            n.plano_contas_id,
            n.empresa_id,
            row_number() OVER (PARTITION BY n.cod_duplicata, n.tipo ORDER BY n.created_at) AS rn
           FROM negociacoes n
             JOIN stg_duplicatas_vigentes v ON v.cod_duplicata = n.cod_duplicata AND v.tipo = n.tipo
        )
 SELECT t.id,
    t.tipo,
    t.descricao,
    h.desc_sub_grupo,
    h.desc_grupo,
        CASE
            WHEN t.tipo = 'despesa'::transacao_tipo AND (h.desc_sub_grupo ~~* '%FILIPPO%'::text OR h.desc_sub_grupo ~~* '%MANOELLA%'::text OR t.descricao ~~* '%RETIRADA LUCRO%'::text OR t.descricao ~~* '%RETIRADA DE LUCRO%'::text OR t.descricao ~~* '%LUCRO DISTRIB%'::text) THEN 'distribuicao_lucro'::text
            WHEN t.tipo = 'despesa'::transacao_tipo THEN 'despesa_operacional'::text
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
            WHEN t.tipo <> 'despesa'::transacao_tipo THEN NULL::text
            WHEN h.desc_sub_grupo = ANY (ARRAY['FIXAS'::text, 'COM PESSOAL'::text, 'ADMINISTRATIVAS'::text, 'BANCARIAS'::text, 'VEICULOS'::text]) THEN 'fixo'::text
            WHEN h.desc_sub_grupo = ANY (ARRAY['COM VENDAS'::text, 'PRODUTOS'::text]) THEN 'variavel'::text
            ELSE 'outro'::text
        END AS tipo_custo,
    t.perfil
   FROM transacoes t
     JOIN negociacao_preferida np ON np.id = t.negociacao_id AND np.rn = 1
     LEFT JOIN hierarquia h ON h.plano_contas_id = np.plano_contas_id
   WHERE t.status_pago <> 2;

COMMENT ON VIEW public.v_financeiro_realizado IS
'Fonte unica do Dashboard Financeiro satelite (dashboard-lucenera-b02z85wa3).
status_pago=2 (CANCELADO) e excluido aqui na view (20260819_121) pra
cancelado nunca contar como despesa/receita/em-aberto em lugar nenhum que
consuma esta view. status_pago: 0=ABERTO, 1=PAGO, 2=CANCELADO (excluido).';
