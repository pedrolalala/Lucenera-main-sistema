-- Migration 20260716_047 — Parte 1
-- SPEC-028: view de apoio ao Dashboard de Estoque. Centraliza no banco as
-- fórmulas já validadas na SPEC (Custo/Venda Total, Disponível, Negativos,
-- Showroom, MKP) — o frontend só agrega/exibe, não recalcula nada.

CREATE OR REPLACE VIEW public.v_estoque_produtos AS
SELECT
  p.id AS produto_id,
  p.codigo_produto,
  p.nome AS produto,
  p.marca_id,
  COALESCE(m.nome, 'SEM MARCA') AS marca,
  p.estoque_total,
  p.estoque_disponivel,
  p.estoque_showroom,
  p.custo_total AS custo_unitario,
  p.valor_venda AS venda_unitaria,

  -- Totais (todo o estoque físico)
  ROUND(p.estoque_total * p.custo_total, 2) AS valor_custo_total,
  ROUND(p.estoque_total * p.valor_venda, 2) AS valor_venda_total,

  -- Disponível (estoque_disponivel > 0)
  ROUND(GREATEST(p.estoque_disponivel, 0) * p.custo_total, 2) AS valor_custo_disponivel,
  ROUND(GREATEST(p.estoque_disponivel, 0) * p.valor_venda, 2) AS valor_venda_disponivel,

  -- Negativos / déficit (estoque_disponivel < 0, magnitude positiva = "a comprar")
  ROUND(GREATEST(-p.estoque_disponivel, 0) * p.custo_total, 2) AS valor_custo_negativo,
  ROUND(GREATEST(-p.estoque_disponivel, 0) * p.valor_venda, 2) AS valor_venda_negativo,

  -- Showroom
  ROUND(GREATEST(p.estoque_showroom, 0) * p.custo_total, 2) AS valor_custo_showroom,

  -- Markup
  CASE WHEN p.custo_total > 0 THEN ROUND(p.valor_venda / p.custo_total, 2) ELSE NULL END AS mkp

FROM public.produtos p
LEFT JOIN public.marcas m ON m.id = p.marca_id
WHERE p.ativo = true;

COMMENT ON VIEW public.v_estoque_produtos IS
  'Base do Dashboard de Estoque (SPEC-028) — uma linha por produto ativo, com '
  'valores de custo/venda já calculados (total, disponível, negativo/déficit, '
  'showroom) e markup. Fonte única de verdade das fórmulas validadas na SPEC.';

GRANT SELECT ON public.v_estoque_produtos TO authenticated;
