-- Migration 20260706_022 — Parte 3
-- SPEC-010: views de leitura do saldo operacional por item de projeto.
--
-- Nenhuma delas duplica produto_id/projeto_id/orcamento_id/cliente_id na
-- tabela de saldo vivo — todas resolvem essas dimensões via JOIN a partir de
-- projeto_itens, conforme decisão da SPEC-010.

-- Detalhada, uma linha por projeto_item_id: usada por CRM (SPEC-014),
-- Estoque e Logística para ver produto/projeto/orçamento/cliente do item.
CREATE OR REPLACE VIEW public.vw_estoque_saldos_projeto_item
WITH (security_invoker = true)
AS
SELECT
    esp.projeto_item_id,
    pi.projeto_id,
    pi.orcamento_id,
    pi.produto_id,
    coalesce(o.cliente_id, pr.cliente_id, pr.client_id) AS cliente_id,
    p.nome AS produto,
    p.codigo_produto AS produto_codigo,
    pr.codigo AS projeto_codigo,
    o.numero AS orcamento_numero,
    pi.quantidade AS q_venda,
    esp.q_reserva,
    esp.q_entrega_futura,
    esp.q_ag_separar,
    esp.q_separado,
    esp.q_entregue,
    esp.q_devolvida,
    esp.q_transferida_saida,
    esp.status_operacional,
    esp.atualizado_em
FROM public.estoque_saldos_projeto_item esp
JOIN public.projeto_itens pi ON pi.id = esp.projeto_item_id
LEFT JOIN public.projetos pr ON pr.id = pi.projeto_id
LEFT JOIN public.orcamentos o ON o.id = pi.orcamento_id
LEFT JOIN public.produtos p ON p.id = pi.produto_id;

COMMENT ON VIEW public.vw_estoque_saldos_projeto_item IS
'SPEC-010. Saldo operacional detalhado por item de projeto, com produto/projeto/orçamento/cliente resolvidos por relacionamento. SECURITY INVOKER para respeitar RLS das tabelas base.';

-- Abre um produto e mostra quais projetos/clientes compõem reserva, entrega
-- futura e separação daquele produto. Parte da view detalhada acima.
CREATE OR REPLACE VIEW public.vw_estoque_por_produto_projeto
WITH (security_invoker = true)
AS
SELECT *
FROM public.vw_estoque_saldos_projeto_item
WHERE status_operacional = 'ativo';

COMMENT ON VIEW public.vw_estoque_por_produto_projeto IS
'SPEC-010. Mesma leitura de vw_estoque_saldos_projeto_item, filtrada aos saldos ativos, para uso ao abrir um produto por produto_id. SECURITY INVOKER para respeitar RLS das tabelas base.';

-- Resumo agregado por produto: total físico, comprometido e disponível.
CREATE OR REPLACE VIEW public.vw_estoque_resumo
WITH (security_invoker = true)
AS
SELECT
    ei.produto_id,
    p.nome AS produto,
    p.codigo_produto AS produto_codigo,
    ei.quantidade AS qtd_total,
    coalesce(comprometido.qtd_comprometida, 0) AS qtd_comprometida,
    ei.quantidade - coalesce(comprometido.qtd_comprometida, 0) AS qtd_disponivel,
    coalesce(comprometido.qtd_entrega_futura, 0) AS qtd_entrega_futura
FROM public.estoque_itens ei
JOIN public.produtos p ON p.id = ei.produto_id
LEFT JOIN (
    SELECT
        pi.produto_id,
        SUM(esp.q_reserva + esp.q_entrega_futura + esp.q_ag_separar + esp.q_separado) AS qtd_comprometida,
        SUM(esp.q_entrega_futura) AS qtd_entrega_futura
    FROM public.estoque_saldos_projeto_item esp
    JOIN public.projeto_itens pi ON pi.id = esp.projeto_item_id
    WHERE esp.status_operacional = 'ativo'
    GROUP BY pi.produto_id
) comprometido ON comprometido.produto_id = ei.produto_id
WHERE ei.local = 'Estoque'::public.estoque_local;

COMMENT ON VIEW public.vw_estoque_resumo IS
'SPEC-010. Resumo por produto: total físico (estoque_itens.quantidade, local=Estoque), comprometido (soma dos saldos abertos por projeto_item_id) e disponível. SECURITY INVOKER para respeitar RLS das tabelas base.';

-- Enquanto a policy de negócio da SPEC-010 não for definida, nenhum papel de
-- API deve ler as tabelas ou views de saldo por item. As RPCs SECURITY DEFINER
-- continuam podendo gravar via owner/service role.
REVOKE ALL ON TABLE public.estoque_saldos_projeto_item FROM anon, authenticated;
REVOKE ALL ON TABLE public.estoque_movimentos_projeto_item FROM anon, authenticated;
REVOKE ALL ON TABLE public.vw_estoque_saldos_projeto_item FROM anon, authenticated;
REVOKE ALL ON TABLE public.vw_estoque_por_produto_projeto FROM anon, authenticated;
REVOKE ALL ON TABLE public.vw_estoque_resumo FROM anon, authenticated;
