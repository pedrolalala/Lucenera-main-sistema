-- Migration 20260928_166 - SPEC-166
--
-- Acrescenta `referencia` (produtos.referencia) como ULTIMA coluna de
-- vw_necessidade_compra, para a tela Necessidade de Compra (Compras) exibir
-- e buscar pela referencia do fornecedor.
--
-- Base: definicao REAL lida em 2026-09-28 via
-- pg_get_viewdef('public.vw_necessidade_compra', true) -- o snapshot
-- supabase/db/current/05_views.sql esta desatualizado para esta view.
-- Todas as colunas existentes foram mantidas na mesma ordem (CREATE OR
-- REPLACE VIEW so permite acrescentar colunas no fim). Nenhuma view depende
-- de vw_necessidade_compra (conferido via pg_depend).
--
-- Rollback: rodar novamente a definicao sem a coluna `referencia` exige
-- DROP VIEW + CREATE (Postgres nao remove coluna via CREATE OR REPLACE);
-- a coluna extra e inofensiva, entao rollback normalmente nao e necessario.

CREATE OR REPLACE VIEW public.vw_necessidade_compra
WITH (security_invoker = true)
AS
WITH base AS (
    SELECT p.id AS produto_id,
        p.nome AS produto,
        p.codigo_produto AS produto_codigo,
        COALESCE(ei_agg.qtd_estoque, 0::numeric) AS qtd_fisica,
        COALESCE(ei_agg.qtd_reservada, 0::numeric) AS qtd_comprometida,
        GREATEST(0::numeric, COALESCE(ei_agg.qtd_reservada, 0::numeric) - COALESCE(ei_agg.qtd_estoque, 0::numeric)) AS necessidade_compra,
        COALESCE(ei_agg.qtd_estoque, 0::numeric) - COALESCE(ei_agg.qtd_reservada, 0::numeric) AS qtd_disponivel,
        COALESCE(proj.n_projetos, 0::bigint) AS projetos_com_entrega_futura,
        p.preco_custo,
        mk.id AS marca_id,
        mk.nome AS marca_nome,
        forn.id AS fornecedor_id,
        forn.nome AS fornecedor_nome,
        p.percentual_desconto_compra,
        COALESCE(pca.qtd_pedidos_abertos, 0::bigint) AS qtd_pedidos_abertos,
        COALESCE(pca.qtd_em_pedidos_abertos, 0::numeric) AS qtd_em_pedidos_abertos,
        pca.proxima_data_prevista_entrega,
        pca.status_mais_critico,
        p.referencia
    FROM public.produtos p
    JOIN (
        SELECT estoque_itens.produto_id,
            sum(estoque_itens.quantidade) AS qtd_estoque,
            sum(estoque_itens.quantidade_reservada) AS qtd_reservada
        FROM public.estoque_itens
        GROUP BY estoque_itens.produto_id
    ) ei_agg ON ei_agg.produto_id = p.id
    LEFT JOIN (
        SELECT pi.produto_id,
            count(DISTINCT pi.projeto_id) AS n_projetos
        FROM public.estoque_saldos_projeto_item esp
        JOIN public.projeto_itens pi ON pi.id = esp.projeto_item_id
        WHERE esp.status_operacional = 'ativo'::text
          AND (esp.q_reserva > 0::numeric OR esp.q_entrega_futura > 0::numeric)
        GROUP BY pi.produto_id
    ) proj ON proj.produto_id = p.id
    LEFT JOIN public.marcas mk ON mk.id = p.marca_id
    LEFT JOIN public.contatos forn ON forn.id = COALESCE(p.fornecedor_principal_id, mk.fornecedor_id)
    LEFT JOIN public.vw_necessidade_compra_pedidos_abertos pca ON pca.produto_id = p.id
    WHERE p.ativo = true
)
SELECT produto_id,
    produto,
    produto_codigo,
    qtd_fisica,
    qtd_comprometida,
    necessidade_compra,
    qtd_disponivel,
    projetos_com_entrega_futura,
    preco_custo,
    marca_id,
    marca_nome,
    fornecedor_id,
    fornecedor_nome,
    percentual_desconto_compra,
    qtd_pedidos_abertos,
    qtd_em_pedidos_abertos,
    proxima_data_prevista_entrega,
    status_mais_critico,
    GREATEST(0::numeric, necessidade_compra - qtd_em_pedidos_abertos) AS pendente,
    referencia
FROM base
WHERE GREATEST(0::numeric, necessidade_compra - qtd_em_pedidos_abertos) > 0::numeric
ORDER BY necessidade_compra DESC, produto;
