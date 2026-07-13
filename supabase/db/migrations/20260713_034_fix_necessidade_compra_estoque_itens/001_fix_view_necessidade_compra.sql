-- Migration 20260713_034 - Sincroniza vw_necessidade_compra com estoque_itens
--
-- Problema da versao anterior (SPEC-012 / migration 025):
--   LEFT JOIN estoque_itens ei ON ... AND ei.local = 'Estoque'
--   → ignorava locais 'Deposito', 'Showroom', etc.
--   → qtd_fisica ficava zerada para produtos so nesses locais
--
-- Correcao: subquery que agrega SUM(quantidade) de TODOS os locais
-- por produto_id, garantindo qtd_fisica = estoque fisico total real.

CREATE OR REPLACE VIEW public.vw_necessidade_compra
WITH (security_invoker = true)
AS
SELECT
    pi.produto_id,
    p.nome                              AS produto,
    p.codigo_produto                    AS produto_codigo,
    coalesce(ei_agg.qtd_total, 0)       AS qtd_fisica,
    sum(
        esp.q_reserva
        + esp.q_entrega_futura
        + esp.q_ag_separar
        + esp.q_separado
    )                                   AS qtd_comprometida,
    sum(esp.q_entrega_futura)           AS necessidade_compra,
    coalesce(ei_agg.qtd_total, 0)
      - sum(
          esp.q_reserva
          + esp.q_entrega_futura
          + esp.q_ag_separar
          + esp.q_separado
        )                               AS qtd_disponivel,
    count(DISTINCT pi.projeto_id)
        FILTER (WHERE esp.q_entrega_futura > 0)
                                        AS projetos_com_entrega_futura
FROM public.estoque_saldos_projeto_item esp
JOIN  public.projeto_itens pi   ON pi.id  = esp.projeto_item_id
LEFT JOIN public.produtos p     ON p.id   = pi.produto_id
LEFT JOIN (
    SELECT
        produto_id,
        SUM(quantidade) AS qtd_total
    FROM public.estoque_itens
    GROUP BY produto_id
) ei_agg ON ei_agg.produto_id = pi.produto_id
WHERE esp.status_operacional = 'ativo'
  AND pi.produto_id IS NOT NULL
GROUP BY
    pi.produto_id,
    p.nome,
    p.codigo_produto,
    ei_agg.qtd_total
HAVING sum(esp.q_entrega_futura) > 0
ORDER BY necessidade_compra DESC, p.nome;

COMMENT ON VIEW public.vw_necessidade_compra IS
'SPEC-012 (rev 034). Deficit agregado por produto. qtd_fisica = SUM de todos
os locais de estoque_itens (nao apenas local=Estoque). SECURITY INVOKER.';

GRANT SELECT ON TABLE public.vw_necessidade_compra TO authenticated;
