-- Migration 20260722_056 - SPEC-039 (P-01) - Item 3/4
--
-- Views auxiliares de agregacao por produto, para alimentar:
--   (a) vw_necessidade_compra (004, coluna `pendente` + colunas de resumo);
--   (b) o painel expansivel do frontend (compras-lucenera-3o23t98ee),
--       reaproveitando o padrao ja usado por NecessidadeCompraDetalhe.tsx /
--       vw_necessidade_compra_detalhe (SPEC-022), agora tambem listando os
--       pedidos_compra em aberto daquele produto (P-01, Alternativa A: linha
--       principal = resumo agregado; expandir = 1 linha por pedido).
--
-- Regra de negocio (reafirmada, nao reaberta por esta SPEC -- ver
-- supabase/db/domains/estoque_compras.md, reuniao 08/06/2026):
-- necessidade de compra e agregada por PRODUTO, nao por pedido/cliente.
-- Estas views resumem N `pedidos_compra` numa unica linha por produto_id,
-- sem transformar a granularidade de `vw_necessidade_compra`.
--
-- "Pedido em aberto" = pedidos_compra.status NOT IN ('recebido', 'cancelado')
-- (mesmo criterio usado na formula de "Pendente" da SPEC).

-- -----------------------------------------------------------------------
-- 1. vw_necessidade_compra_pedidos_abertos: 1 linha por produto (agregado)
-- -----------------------------------------------------------------------
CREATE OR REPLACE VIEW public.vw_necessidade_compra_pedidos_abertos
WITH (security_invoker = true)
AS
WITH pedidos_abertos AS (
    -- Pedidos em aberto por item de pedido, com o saldo ainda nao recebido
    -- daquele item (quantidade - qtd_recebida).
    SELECT
        pci.produto_id,
        pc.id                                AS pedido_id,
        pc.status,
        pc.data_prevista_entrega,
        (pci.quantidade - pci.qtd_recebida)  AS qtd_pendente_item
    FROM public.pedido_compra_itens pci
    JOIN public.pedidos_compra pc ON pc.id = pci.pedido_id
    WHERE pc.status NOT IN ('recebido', 'cancelado')
),
pedido_mais_urgente AS (
    -- "status_mais_critico": status do pedido em aberto com a data prevista
    -- de entrega mais proxima daquele produto (NULLs por ultimo -- pedido
    -- sem data prevista informada e o menos urgente de se acompanhar).
    SELECT DISTINCT ON (produto_id)
        produto_id,
        status AS status_mais_critico
    FROM pedidos_abertos
    ORDER BY produto_id, data_prevista_entrega ASC NULLS LAST, pedido_id
)
SELECT
    pa.produto_id,
    count(DISTINCT pa.pedido_id)          AS qtd_pedidos_abertos,
    sum(pa.qtd_pendente_item)             AS qtd_em_pedidos_abertos,
    min(pa.data_prevista_entrega)         AS proxima_data_prevista_entrega,
    pmu.status_mais_critico
FROM pedidos_abertos pa
JOIN pedido_mais_urgente pmu ON pmu.produto_id = pa.produto_id
GROUP BY pa.produto_id, pmu.status_mais_critico;

COMMENT ON VIEW public.vw_necessidade_compra_pedidos_abertos IS
'SPEC-039 (P-01/P-04). Agregacao por produto_id de pedidos_compra em aberto
(status NOT IN (recebido, cancelado)): quantidade de pedidos abertos, soma do
saldo ainda nao recebido (qtd_em_pedidos_abertos), data prevista de entrega
mais proxima e status do pedido mais urgente. Consumida por
vw_necessidade_compra (004, coluna `pendente`). SECURITY INVOKER -- mesma
politica de SELECT das tabelas base (pedidos_compra/pedido_compra_itens ja
abertas para authenticated).';

GRANT SELECT ON TABLE public.vw_necessidade_compra_pedidos_abertos TO authenticated;

-- -----------------------------------------------------------------------
-- 2. vw_necessidade_compra_pedido_detalhe: 1 linha por pedido em aberto
--    (para o painel expansivel do frontend -- lista pedido a pedido)
-- -----------------------------------------------------------------------
CREATE OR REPLACE VIEW public.vw_necessidade_compra_pedido_detalhe
WITH (security_invoker = true)
AS
SELECT
    pci.produto_id,
    pc.id                                 AS pedido_id,
    pc.numero,
    pc.status,
    e.nome                                AS empresa_nome,
    pc.data_prevista_entrega,
    (pci.quantidade - pci.qtd_recebida)   AS qtd_pendente
FROM public.pedido_compra_itens pci
JOIN public.pedidos_compra pc ON pc.id = pci.pedido_id
LEFT JOIN public.empresas e ON e.id = pc.empresa_id
WHERE pc.status NOT IN ('recebido', 'cancelado')
ORDER BY pc.data_prevista_entrega ASC NULLS LAST;

COMMENT ON VIEW public.vw_necessidade_compra_pedido_detalhe IS
'SPEC-039 (P-01). 1 linha por pedido_compra_itens em aberto (status NOT IN
(recebido, cancelado)), com numero/status cru (frontend traduz o rotulo, ver
P-02)/empresa_nome (via pedidos_compra.empresa_id, P-03)/
data_prevista_entrega -- usada pelo painel expansivel de
NecessidadeCompraDetalhe.tsx, ao lado do detalhe por projeto ja existente
(vw_necessidade_compra_detalhe, SPEC-022). SECURITY INVOKER.';

GRANT SELECT ON TABLE public.vw_necessidade_compra_pedido_detalhe TO authenticated;
