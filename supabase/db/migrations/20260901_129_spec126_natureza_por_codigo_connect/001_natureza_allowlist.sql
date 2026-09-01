-- Migration 20260901_129 — SPEC-126 Escopo 3
-- REDIGIDA, NÃO APLICADA. Aplicar só depois do Vinícius confirmar os baldes
-- (ver "Decisão pendente" abaixo).
--
-- Problema (reunião 31/08, medido no Supabase real):
-- o CASE de `natureza` em v_financeiro_realizado marca 'distribuicao_lucro'
-- quando `desc_sub_grupo ILIKE '%FILIPPO%' / '%MANOELLA%'`. Isso varre a
-- subárvore inteira de "RETIRADAS LUCRO" — inclusive lançamentos que NÃO são
-- retirada de lucro:
--   RETIRADAS LUCRO / MANOELLA / ESCOLA            ~ R$ 91.688
--   RETIRADAS LUCRO / FILIPPO  / CLUBE MAIS VIAGENS ~ R$ 49.841
-- Isso infla "Distribuição de Lucro" e melhora artificialmente o Resultado
-- Operacional e o Ponto de Equilíbrio. As contas DESP. OPERAC. FILIPPO/MANOELLA
-- (codigo_connect 90000014 / 90000015) JÁ caíam certo em 'despesa_operacional'
-- (o pai na árvore é "OPERACIONAL"); não eram o bug.
--
-- Correção: classificar 'distribuicao_lucro' por uma allowlist explícita de
-- `plano_de_contas.codigo_connect` (retirada de lucro + lucro distribuído
-- mensal), em vez de casar pelo nome do sub-grupo. Tudo o mais = despesa
-- operacional. Os fallbacks por `descricao` ('RETIRADA DE LUCRO', 'LUCRO
-- DISTRIB') ficam como rede de segurança e não pegam ESCOLA / CLUBE MAIS.
--
-- Allowlist (confirmada por consulta a plano_de_contas em 31/08):
--   9900001  LUCRO DISTRIBUÍDO (n1)
--   6000000  RETIRADAS LUCRO (n1)
--   9999003  LUCRO DISTRIBUÍDO / MANOELLA (n2)
--   9999004  LUCRO DISTRIBUÍDO / FILIPPO (n2)
--   6010000  RETIRADAS LUCRO / MANOELLA (n2)
--   6020000  RETIRADAS LUCRO / FILIPPO (n2)
--   10000005 LUCRO DISTRIB. MENSAL (n3, ramos Filippo e Manoella)
--   6010006  RETIRADA LUCRO MANOELLA (n3)
--   6020003  RETIRADA DE LUCRO FILIPPO (n3)
--
-- Decisão pendente do Vinícius: ESCOLA, CLUBE MAIS VIAGENS e quaisquer outros
-- lançamentos pendurados em "RETIRADAS LUCRO / FILIPPO(MANOELLA)" que NÃO
-- sejam retirada mensal. Com esta migration eles passam a contar como
-- 'despesa_operacional' (bate com "clube mais = investimento", dito na
-- reunião). Se algum deles for de fato distribuição de lucro, adicionar o
-- codigo_connect da conta à allowlist antes de aplicar.
--
-- Sem alteração de linhas — só a definição da view. Rollback: recriar a view
-- com o CASE de natureza da 20260819_121.

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
            p3.codigo_connect AS codigo_connect,
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
            WHEN t.tipo = 'despesa'::transacao_tipo
                 AND ( h.codigo_connect = ANY (ARRAY[9900001, 6000000, 9999003, 9999004, 6010000, 6020000, 10000005, 6010006, 6020003])
                       OR t.descricao ~~* '%RETIRADA DE LUCRO%'::text
                       OR t.descricao ~~* '%RETIRADA LUCRO%'::text
                       OR t.descricao ~~* '%LUCRO DISTRIB%'::text )
            THEN 'distribuicao_lucro'::text
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
status_pago=2 (CANCELADO) excluido na view (20260819_121). natureza=distribuicao_lucro
classificado por allowlist de plano_de_contas.codigo_connect (SPEC-126, 20260901_129),
nao mais por nome de sub-grupo — ESCOLA / CLUBE MAIS VIAGENS deixam de contar como lucro.
status_pago: 0=ABERTO, 1=PAGO, 2=CANCELADO (excluido).';
