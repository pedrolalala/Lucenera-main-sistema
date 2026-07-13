-- SPEC-022: vw_necessidade_compra_detalhe
-- Uma linha por (produto_id, projeto_item_id) para produtos em déficit.
-- Exibe projeto, cliente e quantidades por item para o módulo de Compras.

DROP VIEW IF EXISTS public.vw_necessidade_compra_detalhe;

CREATE VIEW public.vw_necessidade_compra_detalhe
WITH (security_invoker = true)
AS
WITH deficit AS (
    SELECT
        produto_id,
        SUM(quantidade)           AS qtd_estoque,
        SUM(quantidade_reservada) AS qtd_reservada
    FROM public.estoque_itens
    GROUP BY produto_id
    HAVING SUM(quantidade_reservada) > SUM(quantidade)
)
SELECT
    -- Produto
    d.produto_id,
    p.codigo_produto                                        AS produto_codigo,
    p.nome                                                  AS produto,

    -- Totais do déficit (repetido em cada linha para facilitar o frontend)
    d.qtd_estoque,
    d.qtd_reservada,
    GREATEST(0, d.qtd_reservada - d.qtd_estoque)           AS deficit_total,

    -- Projeto / orçamento
    pi.id                                                   AS projeto_item_id,
    pr.codigo                                               AS projeto_codigo,
    pr.nome                                                 AS projeto_nome,
    o.numero                                                AS orcamento_numero,

    -- Destino: cliente que aguarda o item
    COALESCE(o.cliente_id, pr.cliente_id, pr.client_id)    AS cliente_id,
    c.nome                                                  AS cliente,

    -- Quantidades por projeto
    pi.quantidade                                           AS qtd_vendida,
    esp.q_reserva,
    esp.q_entrega_futura

FROM deficit d
JOIN public.produtos p
    ON  p.id = d.produto_id
   AND  p.ativo = true
JOIN public.projeto_itens pi
    ON  pi.produto_id = d.produto_id
JOIN public.estoque_saldos_projeto_item esp
    ON  esp.projeto_item_id = pi.id
   AND  esp.status_operacional = 'ativo'
   AND  (esp.q_reserva > 0 OR esp.q_entrega_futura > 0)
LEFT JOIN public.projetos pr
    ON  pr.id = pi.projeto_id
LEFT JOIN public.orcamentos o
    ON  o.id = pi.orcamento_id
LEFT JOIN public.contatos c
    ON  c.id = COALESCE(o.cliente_id, pr.cliente_id, pr.client_id)

ORDER BY deficit_total DESC, p.nome, pr.codigo;

COMMENT ON VIEW public.vw_necessidade_compra_detalhe IS
'SPEC-022. Uma linha por (produto_id, projeto_item_id) para produtos em deficit.
Exibe projeto, cliente e quantidades por item para o modulo de Compras.
SECURITY INVOKER — respeita RLS das tabelas base.';

GRANT SELECT ON public.vw_necessidade_compra_detalhe TO authenticated;
