-- Migration 20260715_043 — Parte 1
-- SPEC-026: adiciona dias_em_aberto (aging) à vw_necessidade_compra_detalhe
-- (SPEC-022), a partir de projeto_itens.created_at — a data em que o item
-- entrou no projeto na aprovação do orçamento.
--
-- Reunião 13-07: "o número de dias de pedido deve aparecer o mais antigo,
-- 13 dias [...] pessoas devem ver que tem um pedido daquilo há 13 dias".

CREATE OR REPLACE VIEW public.vw_necessidade_compra_detalhe
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
    d.produto_id,
    p.codigo_produto                                        AS produto_codigo,
    p.nome                                                  AS produto,

    d.qtd_estoque,
    d.qtd_reservada,
    GREATEST(0, d.qtd_reservada - d.qtd_estoque)           AS deficit_total,

    pi.id                                                   AS projeto_item_id,
    pr.codigo                                               AS projeto_codigo,
    pr.nome                                                 AS projeto_nome,
    o.numero                                                AS orcamento_numero,

    COALESCE(o.cliente_id, pr.cliente_id, pr.client_id)    AS cliente_id,
    c.nome                                                  AS cliente,

    pi.quantidade                                           AS qtd_vendida,
    esp.q_reserva,
    esp.q_entrega_futura,

    -- SPEC-026: aging desde que o item entrou no projeto (aprovação do orçamento)
    pi.created_at                                           AS aberto_desde,
    (CURRENT_DATE - pi.created_at::date)                    AS dias_em_aberto

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

ORDER BY dias_em_aberto DESC, deficit_total DESC, p.nome, pr.codigo;

COMMENT ON VIEW public.vw_necessidade_compra_detalhe IS
'SPEC-022 + SPEC-026. Uma linha por (produto_id, projeto_item_id) para produtos em deficit.
Exibe projeto, cliente, quantidades e dias em aberto (aging desde a aprovação do
orçamento) para o modulo de Compras. SECURITY INVOKER — respeita RLS das tabelas base.';

GRANT SELECT ON public.vw_necessidade_compra_detalhe TO authenticated;
