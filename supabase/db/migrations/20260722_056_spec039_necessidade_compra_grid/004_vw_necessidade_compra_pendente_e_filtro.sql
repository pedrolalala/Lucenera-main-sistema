-- Migration 20260722_056 - SPEC-039 (P-04) - Item 4/4
--
-- Recria vw_necessidade_compra preservando TODAS as colunas existentes
-- (confirmadas contra a ultima migration real que recriou a view --
-- 20260721_054_spec038_compras_melhorias/005_cotacoes_desconto_produto.sql)
-- e adicionando:
--   - `pendente`                    = GREATEST(0, necessidade_compra - qtd_em_pedidos_abertos)
--   - `qtd_pedidos_abertos`
--   - `proxima_data_prevista_entrega`
--   - `status_mais_critico` (status cru do pedido em aberto com entrega mais
--     proxima -- frontend traduz o rotulo, ver P-02)
--
-- Decisao do usuario (P-04, 21/07/2026): o filtro que decide QUAIS produtos
-- aparecem na lista muda de `qtd_reservada > qtd_estoque` (so estoque
-- fisico) para `pendente > 0` (tambem descontando pedidos de compra ja em
-- aberto) -- um produto some da lista quando o deficit ja esta 100% coberto
-- por pedido de compra em aberto, mesmo antes do recebimento efetivo. A
-- coluna `necessidade_compra` (deficit bruto, sem descontar pedidos)
-- CONTINUA existindo e sendo exibida -- so a visibilidade da linha muda.
--
-- ATENCAO (mesma ressalva ja registrada em 20260721_054_.../005_...): este
-- agente nao tem acesso ao Supabase real nesta sessao para confirmar que a
-- definicao aplicada bate 100% com a ultima migration desta pasta -- rodar
-- `SELECT pg_get_viewdef('public.vw_necessidade_compra', true)` antes de
-- aplicar esta migration em producao, e comparar com a base usada abaixo.
--
-- Depende de 003_vw_necessidade_compra_pedido_resumo.sql (view
-- vw_necessidade_compra_pedidos_abertos) ja ter sido aplicada nesta mesma
-- pasta de migration.

CREATE OR REPLACE VIEW public.vw_necessidade_compra
WITH (security_invoker = true)
AS
WITH base AS (
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
        forn.nome                                        AS fornecedor_nome,
        p.percentual_desconto_compra                     AS percentual_desconto_compra,
        coalesce(pca.qtd_pedidos_abertos, 0)              AS qtd_pedidos_abertos,
        coalesce(pca.qtd_em_pedidos_abertos, 0)           AS qtd_em_pedidos_abertos,
        pca.proxima_data_prevista_entrega                 AS proxima_data_prevista_entrega,
        pca.status_mais_critico                           AS status_mais_critico
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
    LEFT JOIN public.vw_necessidade_compra_pedidos_abertos pca
        ON pca.produto_id = p.id
    WHERE p.ativo = true
)
SELECT
    base.*,
    GREATEST(0, base.necessidade_compra - base.qtd_em_pedidos_abertos) AS pendente
FROM base
WHERE GREATEST(0, base.necessidade_compra - base.qtd_em_pedidos_abertos) > 0
ORDER BY base.necessidade_compra DESC, base.produto;

COMMENT ON VIEW public.vw_necessidade_compra IS
'SPEC-039 (P-04, estende migration 20260721_054/005_cotacoes_desconto_produto.sql).
Adiciona `pendente` (deficit ainda nao coberto por pedido de compra em
aberto: GREATEST(0, necessidade_compra - qtd_em_pedidos_abertos)),
`qtd_pedidos_abertos` e `proxima_data_prevista_entrega` (via
vw_necessidade_compra_pedidos_abertos). O filtro de visibilidade da linha
passa a ser `pendente > 0` (antes: `qtd_reservada > qtd_estoque`) -- decisao
do usuario P-04: produto some da lista quando ja tem pedido de compra aberto
cobrindo 100% do deficit, mesmo antes do recebimento efetivo. A coluna
`necessidade_compra` (deficit bruto) continua exibida, sem descontar
pedidos. SECURITY INVOKER.';

GRANT SELECT ON TABLE public.vw_necessidade_compra TO authenticated;
