-- Migration 20260713_035 - Necessidade de Compra: fonte de verdade = estoque_itens
--
-- Problema da versao anterior (migration 025 / 034):
--   Dependia de estoque_saldos_projeto_item.q_entrega_futura > 0
--   Esse campo estava zerado em todos os 9 registros da tabela →
--   a view retornava VAZIA mesmo com produtos em deficit real.
--
-- Raiz do deficit real (diagnosticado via API):
--   Produto 8501: qtd_estoque=0, qtd_reservada=3 → deficit de 3
--   Produto 9543: qtd_estoque=0, qtd_reservada=12 → deficit de 12
--   (estoque_itens.quantidade_reservada > quantidade = "estoque negativo efetivo")
--
-- Nova logica: fonte = estoque_itens
--   qtd_fisica       = SUM(quantidade)           por produto
--   qtd_comprometida = SUM(quantidade_reservada)  por produto
--   necessidade_compra = GREATEST(0, qtd_comprometida - qtd_fisica)
--   Exibe apenas produtos onde qtd_comprometida > qtd_fisica (deficit real)
--
-- projetos_com_entrega_futura: mantido via LEFT JOIN em
--   estoque_saldos_projeto_item para backward-compat; retorna 0 enquanto
--   a tabela nao for populada.

CREATE OR REPLACE VIEW public.vw_necessidade_compra
WITH (security_invoker = true)
AS
SELECT
    p.id                                            AS produto_id,
    p.nome                                          AS produto,
    p.codigo_produto                                AS produto_codigo,
    coalesce(ei_agg.qtd_estoque, 0)                 AS qtd_fisica,
    coalesce(ei_agg.qtd_reservada, 0)               AS qtd_comprometida,
    GREATEST(0,
        coalesce(ei_agg.qtd_reservada, 0)
        - coalesce(ei_agg.qtd_estoque, 0)
    )                                               AS necessidade_compra,
    coalesce(ei_agg.qtd_estoque, 0)
        - coalesce(ei_agg.qtd_reservada, 0)         AS qtd_disponivel,
    coalesce(proj.n_projetos, 0)                    AS projetos_com_entrega_futura
FROM public.produtos p
JOIN (
    SELECT
        produto_id,
        SUM(quantidade)             AS qtd_estoque,
        SUM(quantidade_reservada)   AS qtd_reservada
    FROM public.estoque_itens
    GROUP BY produto_id
) ei_agg ON ei_agg.produto_id = p.id
LEFT JOIN (
    SELECT
        pi.produto_id,
        count(DISTINCT pi.projeto_id) AS n_projetos
    FROM public.estoque_saldos_projeto_item esp
    JOIN public.projeto_itens pi ON pi.id = esp.projeto_item_id
    WHERE esp.status_operacional = 'ativo'
      AND (esp.q_reserva > 0 OR esp.q_entrega_futura > 0)
    GROUP BY pi.produto_id
) proj ON proj.produto_id = p.id
WHERE p.ativo = true
  AND coalesce(ei_agg.qtd_reservada, 0) > coalesce(ei_agg.qtd_estoque, 0)
ORDER BY necessidade_compra DESC, p.nome;

COMMENT ON VIEW public.vw_necessidade_compra IS
'Migration 035. Fonte: estoque_itens. Mostra produtos onde
quantidade_reservada > quantidade (deficit real). Substituiu logica
anterior baseada em estoque_saldos_projeto_item.q_entrega_futura que
estava zerado. SECURITY INVOKER.';

GRANT SELECT ON TABLE public.vw_necessidade_compra TO authenticated;
