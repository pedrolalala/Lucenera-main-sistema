-- Migration 20260716_049 — Parte 2 (SPEC-030 Parte 2)
-- Estende vw_necessidade_compra com marca e fornecedor resolvido, para
-- suportar o filtro por Marca e o fluxo de "Pedido em Lote" em
-- NecessidadeCompra.tsx.
--
-- Base real e atual da view (confirmado nas migrations, nao no snapshot
-- desatualizado de db/current/05_views.sql): 20260713_036_cotacoes_preco_custo
-- (ultima a reescrever vw_necessidade_compra, adicionou p.preco_custo em cima
-- da 20260713_035). Esta migration preserva todas as colunas ja existentes
-- (produto_id, produto, produto_codigo, qtd_fisica, qtd_comprometida,
-- necessidade_compra, qtd_disponivel, projetos_com_entrega_futura,
-- preco_custo — SPEC-013/022/026/036) e adiciona:
--   marca_id, marca_nome        <- LEFT JOIN produtos.marca_id -> marcas
--   fornecedor_id, fornecedor_nome
--     <- COALESCE(produtos.fornecedor_principal_id, marcas.fornecedor_id)
--        resolvido para contatos.nome
--
-- fornecedor_id/fornecedor_nome ficam NULL quando nem o produto tem
-- fornecedor_principal_id proprio nem a marca tem fornecedor_id preenchido
-- (marcas.fornecedor_id ainda sem backfill) — o frontend usa isso para
-- desabilitar a selecao da linha no Pedido em Lote (ver Checklist SPEC-030).

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
    coalesce(proj.n_projetos, 0)                    AS projetos_com_entrega_futura,
    p.preco_custo,
    mk.id                                            AS marca_id,
    mk.nome                                          AS marca_nome,
    forn.id                                          AS fornecedor_id,
    forn.nome                                        AS fornecedor_nome
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
LEFT JOIN public.marcas mk
    ON mk.id = p.marca_id
LEFT JOIN public.contatos forn
    ON forn.id = COALESCE(p.fornecedor_principal_id, mk.fornecedor_id)
WHERE p.ativo = true
  AND coalesce(ei_agg.qtd_reservada, 0) > coalesce(ei_agg.qtd_estoque, 0)
ORDER BY necessidade_compra DESC, p.nome;

COMMENT ON VIEW public.vw_necessidade_compra IS
'Migration 049 (SPEC-030 Parte 2). Fonte: estoque_itens (quantidade_reservada
> quantidade). Inclui preco_custo (migration 036) e, a partir desta migration,
marca_id/marca_nome (produtos.marca_id -> marcas) e fornecedor_id/fornecedor_nome
resolvido via COALESCE(produtos.fornecedor_principal_id, marcas.fornecedor_id) ->
contatos. fornecedor_id pode ser NULL enquanto marcas.fornecedor_id nao tiver
backfill. SECURITY INVOKER.';

GRANT SELECT ON TABLE public.vw_necessidade_compra TO authenticated;
