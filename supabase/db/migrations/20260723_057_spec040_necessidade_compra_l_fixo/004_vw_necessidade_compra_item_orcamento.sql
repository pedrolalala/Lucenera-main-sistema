-- Migration 20260723_057 - SPEC-040 - Item 4/4
--
-- View nova para o Fluxo B ("Por Item de Orçamento") da tela Necessidade de
-- Compra (compras-lucenera-3o23t98ee). NÃO substitui nem altera
-- vw_necessidade_compra_detalhe (SPEC-022) nem vw_necessidade_compra
-- (Fluxo A) -- ambas continuam intactas, servindo a aba "Por Produto".
--
-- Granularidade: 1 linha por projeto_item_id (== 1:1 com orcamento_item_id
-- desde que a FK exista, ver 001/002/003 desta pasta).
--
-- Decisão do usuário P-06 (21/07/2026): uma linha de projeto_itens SEM
-- orcamento_item_id (legado ou caso ambíguo do backfill, ver 003) não
-- aparece nesta view -- filtro `WHERE pi.orcamento_item_id IS NOT NULL`
-- já resolve isso no banco, o frontend não precisa filtrar de novo.
--
-- "pendente_item" segue o mesmo espírito de "pendente" da SPEC-039 (P-04),
-- mas por projeto_item_id em vez de por produto_id: desconta do
-- estoque_saldos_projeto_item.q_entrega_futura da linha o que já foi
-- coberto por pedidos de compra em aberto especificamente vinculados àquele
-- projeto_item_id via pedido_compra_item_origem.quantidade_atendida
-- (SPEC-038 Item 3) -- vínculo que passa a ser OBRIGATÓRIO no Fluxo B
-- (decisão P-03), tornando essa cobertura confiável.
--
-- Visibilidade da linha: mesma lógica de "pendente > 0" do Fluxo A
-- (SPEC-039 P-04) -- só aparecem linhas com pendente_item > 0.
--
-- Fornecedor: mesma resolução em cascata já usada em vw_necessidade_compra
-- (SPEC-030): COALESCE(produtos.fornecedor_principal_id, marcas.fornecedor_id).

CREATE OR REPLACE VIEW public.vw_necessidade_compra_item_orcamento
WITH (security_invoker = true)
AS
WITH cobertura_pedidos AS (
    SELECT
        pcio.projeto_item_id,
        SUM(pcio.quantidade_atendida) AS qtd_coberta_por_pedido_aberto
    FROM public.pedido_compra_item_origem pcio
    JOIN public.pedido_compra_itens pci ON pci.id = pcio.pedido_compra_item_id
    JOIN public.pedidos_compra pc ON pc.id = pci.pedido_id
    WHERE pc.status NOT IN ('recebido', 'cancelado')
      AND pcio.quantidade_atendida IS NOT NULL
    GROUP BY pcio.projeto_item_id
),
base AS (
    SELECT
        pi.id                                            AS projeto_item_id,
        pi.produto_id,
        p.nome                                            AS produto,
        p.codigo_produto                                  AS produto_codigo,
        pi.orcamento_id,
        o.numero                                          AS orcamento_numero,
        pi.orcamento_item_id,
        pi.l_fixo,
        p.preco_custo,
        p.percentual_desconto_compra,
        mk.id                                             AS marca_id,
        mk.nome                                           AS marca_nome,
        forn.id                                           AS fornecedor_id,
        forn.nome                                         AS fornecedor_nome,
        esp.q_entrega_futura,
        COALESCE(cob.qtd_coberta_por_pedido_aberto, 0)    AS qtd_coberta_por_pedido_aberto,
        GREATEST(0, esp.q_entrega_futura - COALESCE(cob.qtd_coberta_por_pedido_aberto, 0))
                                                           AS pendente_item
    FROM public.projeto_itens pi
    JOIN public.produtos p
        ON p.id = pi.produto_id
       AND p.ativo = true
    JOIN public.estoque_saldos_projeto_item esp
        ON esp.projeto_item_id = pi.id
       AND esp.status_operacional = 'ativo'
    LEFT JOIN public.orcamentos o
        ON o.id = pi.orcamento_id
    LEFT JOIN public.marcas mk
        ON mk.id = p.marca_id
    LEFT JOIN public.contatos forn
        ON forn.id = COALESCE(p.fornecedor_principal_id, mk.fornecedor_id)
    LEFT JOIN cobertura_pedidos cob
        ON cob.projeto_item_id = pi.id
    WHERE pi.orcamento_item_id IS NOT NULL
)
SELECT *
FROM base
WHERE pendente_item > 0
ORDER BY orcamento_numero, l_fixo NULLS LAST, produto;

COMMENT ON VIEW public.vw_necessidade_compra_item_orcamento IS
'SPEC-040 (Fluxo B — Necessidade de Compra por Item de Orçamento). 1 linha
por projeto_item_id, só para linhas com orcamento_item_id preenchido
(decisão P-06: sem vínculo cai no Fluxo A agregado, não aparece aqui).
pendente_item = GREATEST(0, estoque_saldos_projeto_item.q_entrega_futura -
cobertura via pedido_compra_item_origem.quantidade_atendida de pedidos em
aberto). Fornecedor resolvido em cascata (produtos.fornecedor_principal_id,
marcas.fornecedor_id), mesmo padrão de vw_necessidade_compra (SPEC-030).
Não substitui vw_necessidade_compra nem vw_necessidade_compra_detalhe, que
permanecem intactas para a aba "Por Produto" (Fluxo A). SECURITY INVOKER.';

GRANT SELECT ON TABLE public.vw_necessidade_compra_item_orcamento TO authenticated;
