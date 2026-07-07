-- Migration 20260707_025 - SPEC-012
-- Entrega Futura e Necessidade de Compra
--
-- Duas views de leitura sobre estoque_saldos_projeto_item (SPEC-010, ja aplicada
-- e com policy de leitura desde 20260707_024). Sem tabela nova, sem RPC.
--
-- Correcao de nome de coluna em relacao ao desenho original da SPEC-012:
-- produtos usa `codigo_produto`, nao `codigo` (confirmado em 01_schema_full.sql,
-- mesmo padrao ja usado pela view vw_estoque_saldos_projeto_item da SPEC-010).

CREATE OR REPLACE VIEW public.vw_entrega_futura_projeto_item
WITH (security_invoker = true)
AS
SELECT
    esp.projeto_item_id,
    pi.produto_id,
    p.nome AS produto,
    p.codigo_produto AS produto_codigo,
    pi.projeto_id,
    pr.codigo AS projeto_codigo,
    pi.orcamento_id,
    o.numero AS orcamento_numero,
    coalesce(o.cliente_id, pr.cliente_id, pr.client_id) AS cliente_id,
    c.nome AS cliente,
    pi.quantidade AS q_venda,
    esp.q_entrega_futura,
    esp.q_reserva,
    esp.q_transferida_saida,
    esp.atualizado_em
FROM public.estoque_saldos_projeto_item esp
JOIN public.projeto_itens pi ON pi.id = esp.projeto_item_id
LEFT JOIN public.produtos p ON p.id = pi.produto_id
LEFT JOIN public.projetos pr ON pr.id = pi.projeto_id
LEFT JOIN public.orcamentos o ON o.id = pi.orcamento_id
LEFT JOIN public.contatos c ON c.id = coalesce(o.cliente_id, pr.cliente_id, pr.client_id)
WHERE esp.status_operacional = 'ativo'
  AND esp.q_entrega_futura > 0
ORDER BY p.nome, esp.atualizado_em;

COMMENT ON VIEW public.vw_entrega_futura_projeto_item IS
'SPEC-012. Saldo operacional detalhado por projeto_item_id sem cobertura fisica (q_entrega_futura > 0). SECURITY INVOKER.';

CREATE OR REPLACE VIEW public.vw_necessidade_compra
WITH (security_invoker = true)
AS
SELECT
    pi.produto_id,
    p.nome AS produto,
    p.codigo_produto AS produto_codigo,
    coalesce(ei.quantidade, 0) AS qtd_fisica,
    sum(esp.q_reserva + esp.q_entrega_futura + esp.q_ag_separar + esp.q_separado) AS qtd_comprometida,
    sum(esp.q_entrega_futura) AS necessidade_compra,
    coalesce(ei.quantidade, 0)
      - sum(esp.q_reserva + esp.q_entrega_futura + esp.q_ag_separar + esp.q_separado) AS qtd_disponivel,
    count(DISTINCT pi.projeto_id) FILTER (WHERE esp.q_entrega_futura > 0) AS projetos_com_entrega_futura
FROM public.estoque_saldos_projeto_item esp
JOIN public.projeto_itens pi ON pi.id = esp.projeto_item_id
LEFT JOIN public.produtos p ON p.id = pi.produto_id
LEFT JOIN public.estoque_itens ei
       ON ei.produto_id = pi.produto_id
      AND ei.local = 'Estoque'::public.estoque_local
WHERE esp.status_operacional = 'ativo'
  AND pi.produto_id IS NOT NULL
GROUP BY pi.produto_id, p.nome, p.codigo_produto, ei.quantidade
HAVING sum(esp.q_entrega_futura) > 0
ORDER BY necessidade_compra DESC, p.nome;

COMMENT ON VIEW public.vw_necessidade_compra IS
'SPEC-012. Deficit agregado por produto (soma de q_entrega_futura), sem vinculo fixo a cliente/projeto. SECURITY INVOKER.';

GRANT SELECT ON TABLE public.vw_entrega_futura_projeto_item TO authenticated;
GRANT SELECT ON TABLE public.vw_necessidade_compra TO authenticated;
