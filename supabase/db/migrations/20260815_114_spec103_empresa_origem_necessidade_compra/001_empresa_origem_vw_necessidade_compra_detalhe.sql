-- Migration 20260815_114 (SPEC-103, parte 2)
-- Adiciona empresa de origem (orcamentos.empresa_id -> empresas.nome) à
-- view vw_necessidade_compra_detalhe, consumida por
-- NecessidadeCompraDetalhe.tsx (painel lateral "de onde vem a necessidade")
-- e pela seção "Itens de projeto que motivaram esta compra" dentro do
-- ModalRegistrarCompra.tsx.
--
-- Reunião Vinícius 14/08/2026: hoje a tela agrega tudo por produto sem
-- mostrar de qual empresa veio a venda que gerou a necessidade — decisão
-- é dar VISIBILIDADE (não regra automática de "comprar pela empresa que
-- vendeu mais"), pra quem monta o pedido decidir manualmente quando quiser
-- comprar por uma empresa diferente da que originou a venda.
--
-- orcamentos ja estava LEFT JOIN'd na view (alias o); so adiciona o campo
-- e um LEFT JOIN novo com empresas. orcamentos.empresa_id e NOT NULL, mas
-- o LEFT JOIN em orcamentos (pi.orcamento_id pode ser nulo) preserva o
-- mesmo padrao ja usado pelas outras colunas vindas de o/pr/c.

CREATE OR REPLACE VIEW public.vw_necessidade_compra_detalhe
WITH (security_invoker = true)
AS
WITH deficit AS (
    SELECT estoque_itens.produto_id,
        sum(estoque_itens.quantidade) AS qtd_estoque,
        sum(estoque_itens.quantidade_reservada) AS qtd_reservada
    FROM public.estoque_itens
    GROUP BY estoque_itens.produto_id
    HAVING sum(estoque_itens.quantidade_reservada) > sum(estoque_itens.quantidade)
)
SELECT d.produto_id,
    p.codigo_produto AS produto_codigo,
    p.nome AS produto,
    d.qtd_estoque,
    d.qtd_reservada,
    GREATEST(0::numeric, d.qtd_reservada - d.qtd_estoque) AS deficit_total,
    pi.id AS projeto_item_id,
    pr.codigo AS projeto_codigo,
    pr.nome AS projeto_nome,
    o.numero AS orcamento_numero,
    COALESCE(o.cliente_id, pr.cliente_id) AS cliente_id,
    c.nome AS cliente,
    pi.quantidade AS qtd_vendida,
    esp.q_reserva,
    esp.q_entrega_futura,
    pi.created_at AS aberto_desde,
    CURRENT_DATE - pi.created_at::date AS dias_em_aberto,
    o.empresa_id,
    emp.nome AS empresa_nome
FROM deficit d
JOIN public.produtos p ON p.id = d.produto_id AND p.ativo = true
JOIN public.projeto_itens pi ON pi.produto_id = d.produto_id
JOIN public.estoque_saldos_projeto_item esp
    ON esp.projeto_item_id = pi.id
   AND esp.status_operacional = 'ativo'::text
   AND (esp.q_reserva > 0::numeric OR esp.q_entrega_futura > 0::numeric)
LEFT JOIN public.projetos pr ON pr.id = pi.projeto_id
LEFT JOIN public.orcamentos o ON o.id = pi.orcamento_id
LEFT JOIN public.contatos c ON c.id = COALESCE(o.cliente_id, pr.cliente_id)
LEFT JOIN public.empresas emp ON emp.id = o.empresa_id
ORDER BY (CURRENT_DATE - pi.created_at::date) DESC,
         (GREATEST(0::numeric, d.qtd_reservada - d.qtd_estoque)) DESC,
         p.nome, pr.codigo;

COMMENT ON VIEW public.vw_necessidade_compra_detalhe IS
'SPEC-039/103. Detalhe por projeto_item da necessidade de compra de um
produto (déficit reserva > estoque). SPEC-103 (parte 2, 2026-08-15)
adicionou empresa_id/empresa_nome (orcamentos.empresa_id -> empresas.nome)
para dar visibilidade de qual empresa originou a venda, sem aplicar
nenhuma regra automática de qual empresa deve comprar — só informativo.
SECURITY INVOKER.';

GRANT SELECT ON public.vw_necessidade_compra_detalhe TO authenticated;
