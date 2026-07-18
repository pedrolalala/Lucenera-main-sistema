-- Migration 20260715_045 — Parte 1
-- SPEC-026: classificação Custo Fixo x Variável, extraída da reunião 13-07:
--   "energia elétrica é fixo [...] salários são custos fixos [...] comissões
--    não é custo fixo, é custo variável [...] tudo que é relativo ao vendido"
--
-- Mapeamento por desc_sub_grupo é um DEFAULT PROPOSTO, não confirmado com o
-- Filippo (SPEC-026, perguntas P-01/P-03) — fácil de ajustar depois porque é
-- só um CASE na view, sem tabela nova.

CREATE OR REPLACE VIEW public.v_financeiro_realizado AS
WITH pc AS (
  SELECT id, codigo_connect, nome, nivel, parent_id FROM public.plano_de_contas
),
hierarquia AS (
  SELECT
    p3.id AS plano_contas_id,
    COALESCE(p2.nome, p3.nome) AS desc_sub_grupo,
    COALESCE(p1.nome, p2.nome, p3.nome) AS desc_grupo
  FROM pc p3
  LEFT JOIN pc p2 ON p2.id = p3.parent_id
  LEFT JOIN pc p1 ON p1.id = p2.parent_id
),
negociacao_preferida AS (
  SELECT n.id, n.cod_duplicata, n.tipo, n.plano_contas_id, n.empresa_id,
    row_number() OVER (PARTITION BY n.cod_duplicata, n.tipo ORDER BY n.created_at) AS rn
  FROM public.negociacoes n
  JOIN public.stg_duplicatas_vigentes v ON v.cod_duplicata = n.cod_duplicata AND v.tipo = n.tipo
)
SELECT
  t.id,
  t.tipo,
  t.descricao,
  h.desc_sub_grupo,
  h.desc_grupo,
  CASE
    WHEN t.tipo = 'despesa' AND (
      h.desc_sub_grupo ILIKE '%FILIPPO%'
      OR h.desc_sub_grupo ILIKE '%MANOELLA%'
      OR t.descricao ILIKE '%RETIRADA LUCRO%'
      OR t.descricao ILIKE '%RETIRADA DE LUCRO%'
      OR t.descricao ILIKE '%LUCRO DISTRIB%'
    ) THEN 'distribuicao_lucro'
    WHEN t.tipo = 'despesa' THEN 'despesa_operacional'
    ELSE NULL
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
  -- SPEC-026: Custo Fixo x Variável — default proposto por desc_sub_grupo,
  -- pendente de validação (reunião 13-07-2026).
  CASE
    WHEN t.tipo <> 'despesa' THEN NULL
    WHEN h.desc_sub_grupo IN ('FIXAS', 'COM PESSOAL', 'ADMINISTRATIVAS', 'BANCARIAS', 'VEICULOS') THEN 'fixo'
    WHEN h.desc_sub_grupo IN ('COM VENDAS', 'PRODUTOS') THEN 'variavel'
    ELSE 'outro'
  END AS tipo_custo
FROM public.transacoes t
JOIN negociacao_preferida np ON np.id = t.negociacao_id AND np.rn = 1
LEFT JOIN hierarquia h ON h.plano_contas_id = np.plano_contas_id;
