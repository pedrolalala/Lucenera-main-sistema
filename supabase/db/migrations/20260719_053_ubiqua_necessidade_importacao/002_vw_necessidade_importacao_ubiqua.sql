-- Migration 20260719_053 — Parte 2
-- SPEC-037: view agregada por produto de demanda pendente de importação.
--
-- Segue o padrão arquitetural já documentado em
-- supabase/db/domains/estoque_compras.md (reunião de 08/06/2026):
-- "necessidade de compra é agregada por produto e não deve ficar amarrada
-- a cliente". Não filtra por status enum porque orcamentos_revenda_ubiqua.status
-- é text livre sem CHECK — usa os timestamps cancelado_em/rejeitado_em.

CREATE OR REPLACE VIEW public.vw_necessidade_importacao_ubiqua
WITH (security_invoker = 'true') AS
SELECT
  r.id AS produto_id,
  r.referencia,
  r.descricao,
  r.cor,
  r.desc_marca AS marca,
  r.nm_fornecedor AS fornecedor,
  r.disponivel AS disponivel_atual,
  SUM(iou.quantidade) AS qtd_pendente_importacao,
  COUNT(DISTINCT iou.orcamento_id) AS orcamentos_pendentes
FROM public.itens_orcamento_ubiqua iou
JOIN public.orcamentos_revenda_ubiqua o ON o.id = iou.orcamento_id
JOIN public.revenda_ubiqua r ON r.id = iou.produto_id
WHERE iou.sem_estoque_no_pedido = true
  AND o.cancelado_em IS NULL
  AND o.rejeitado_em IS NULL
GROUP BY r.id, r.referencia, r.descricao, r.cor, r.desc_marca, r.nm_fornecedor, r.disponivel
HAVING SUM(iou.quantidade) > 0
ORDER BY SUM(iou.quantidade) DESC;

COMMENT ON VIEW public.vw_necessidade_importacao_ubiqua IS
  'Demanda agregada por produto/variante (revenda_ubiqua.id) de itens pedidos sob '
  'encomenda (sem_estoque_no_pedido = true) em orçamentos ativos (não '
  'cancelados/rejeitados). Time de compras usa esta view para priorizar importação. '
  'SECURITY INVOKER. SPEC-037.';

GRANT SELECT ON public.vw_necessidade_importacao_ubiqua TO authenticated;
