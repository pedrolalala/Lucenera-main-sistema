-- Migration 20260713_033 - Estoque Completo
-- View vw_estoque_produtos: todos os produtos ativos com saldos de estoque,
-- marca e categoria. Usada pela pagina "Estoque" do compras-lucenera.

DROP VIEW IF EXISTS public.vw_estoque_produtos;

CREATE VIEW public.vw_estoque_produtos
WITH (security_invoker = true)
AS
SELECT
    p.id                                    AS produto_id,
    p.codigo_produto::text                  AS produto_codigo,
    p.nome                                  AS produto,
    p.sku,
    p.referencia,
    m.nome                                  AS marca,
    cat.nome                                AS categoria,
    p.unidade,
    -- Saldos denormalizados mantidos por triggers em produtos
    coalesce(p.estoque_total, 0)            AS estoque_total,
    coalesce(p.estoque_disponivel, 0)       AS estoque_disponivel,
    coalesce(p.estoque_showroom, 0)         AS estoque_showroom,
    -- Quantidade real de estoque_itens (fonte de verdade por local)
    coalesce(ei.qtd_estoque, 0)             AS qtd_estoque_itens,
    coalesce(ei.qtd_reservada, 0)           AS qtd_reservada,
    coalesce(p.custo_total, 0)              AS custo_total,
    p.preco_custo,
    p.preco_venda,
    p.ativo,
    p.updated_at
FROM public.produtos p
LEFT JOIN public.marcas m
    ON m.id = p.marca_id
LEFT JOIN public.categorias_produto cat
    ON cat.id = p.categoria_id
LEFT JOIN (
    SELECT
        produto_id,
        SUM(quantidade)             AS qtd_estoque,
        SUM(quantidade_reservada)   AS qtd_reservada
    FROM public.estoque_itens
    GROUP BY produto_id
) ei ON ei.produto_id = p.id
WHERE p.ativo = true;

GRANT SELECT ON public.vw_estoque_produtos TO authenticated;
