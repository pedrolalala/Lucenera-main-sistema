-- Migration 20260715_044 — Parte 1
-- SPEC-026: adiciona dias_em_aberto à vw_entrega_futura_projeto_item — esta é
-- a view REAL usada pelo frontend (src/services/necessidade-compra.ts,
-- getEntregaFuturaPorProduto), diferente da vw_necessidade_compra_detalhe
-- documentada na SPEC-022 (que existe no banco mas não é consultada pelo
-- app hoje — divergência encontrada durante a implementação da SPEC-026).

CREATE OR REPLACE VIEW public.vw_entrega_futura_projeto_item AS
SELECT
    esp.projeto_item_id,
    pi.produto_id,
    p.nome AS produto,
    p.codigo_produto AS produto_codigo,
    pi.projeto_id,
    pr.codigo AS projeto_codigo,
    pi.orcamento_id,
    o.numero AS orcamento_numero,
    COALESCE(o.cliente_id, pr.cliente_id, pr.client_id) AS cliente_id,
    c.nome AS cliente,
    pi.quantidade AS q_venda,
    esp.q_entrega_futura,
    esp.q_reserva,
    esp.q_transferida_saida,
    esp.atualizado_em,
    pi.created_at AS aberto_desde,
    (CURRENT_DATE - pi.created_at::date) AS dias_em_aberto
FROM estoque_saldos_projeto_item esp
JOIN projeto_itens pi ON pi.id = esp.projeto_item_id
LEFT JOIN produtos p ON p.id = pi.produto_id
LEFT JOIN projetos pr ON pr.id = pi.projeto_id
LEFT JOIN orcamentos o ON o.id = pi.orcamento_id
LEFT JOIN contatos c ON c.id = COALESCE(o.cliente_id, pr.cliente_id, pr.client_id)
WHERE esp.status_operacional = 'ativo'::text AND esp.q_entrega_futura > 0::numeric
ORDER BY pi.created_at, p.nome;

COMMENT ON VIEW public.vw_entrega_futura_projeto_item IS
'Entrega futura por item de projeto (sem cobertura física). Inclui
dias_em_aberto (aging desde a aprovação do orçamento) — SPEC-026,
reunião 13-07-2026.';

GRANT SELECT ON public.vw_entrega_futura_projeto_item TO authenticated;
