-- Migration 20261001_174 (SPEC-174, item N2b)
--
-- Acrescenta `previsao_entrega` (orcamentos.previsao_entrega, SPEC-167) como
-- ULTIMA coluna de vw_necessidade_compra_detalhe, para a tela Necessidade de
-- Compra (Compras) mostrar, por venda, até quando o Vinícius pode segurar a
-- compra antes de decidir fornecedor/volume.
--
-- Base: definição REAL mais recente aplicada em produção, confirmada em
-- CHANGELOG.md ("SPEC-103 parte 2", Skip 40326 v0.0.63) e no arquivo
-- supabase/db/migrations/20260815_114_spec103_empresa_origem_necessidade_compra/
-- 001_empresa_origem_vw_necessidade_compra_detalhe.sql -- supabase/db/current/
-- não tem esta view (pendência crônica de reextração já registrada em
-- supabase/db/domains/estoque_compras.md). Nenhuma migration posterior a
-- 2026-08-15 altera esta view (conferido em supabase/db/migrations/).
--
-- orcamentos (alias o) já está LEFT JOIN'd na view desde a SPEC-103 parte 2
-- -- só falta expor a coluna nova. Todas as colunas existentes mantidas na
-- mesma ordem (CREATE OR REPLACE VIEW só permite acrescentar coluna no fim).
-- Granularidade inalterada: 1 linha por projeto_item_id (decisão de
-- 08/06/2026, reafirmada na SPEC-039) -- a data é da venda (orcamentos), não
-- do produto, então repete por linha quando o mesmo orçamento tem mais de
-- um L do produto, o que é esperado.
--
-- Nenhuma view depende de vw_necessidade_compra_detalhe (conferido: nenhum
-- FROM/JOIN a ela em supabase/db/migrations/).
--
-- Rollback: coluna extra é inofensiva para os consumidores atuais
-- (NecessidadeCompraDetalhe.tsx faz SELECT *); remover exigiria DROP VIEW +
-- CREATE (Postgres não remove coluna via CREATE OR REPLACE), normalmente
-- não necessário.

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
    emp.nome AS empresa_nome,
    -- SPEC-174 N2b: previsão de entrega da venda de origem (SPEC-167).
    o.previsao_entrega
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
'SPEC-039/103/174. Detalhe por projeto_item da necessidade de compra de um
produto (déficit reserva > estoque). SPEC-103 (parte 2, 2026-08-15)
adicionou empresa_id/empresa_nome. SPEC-174 N2b (2026-10-01) adicionou
previsao_entrega (orcamentos.previsao_entrega, SPEC-167) para mostrar até
quando a compra pode ser segurada por venda, sem mudar a granularidade de
1 linha por projeto_item_id. SECURITY INVOKER.';

GRANT SELECT ON public.vw_necessidade_compra_detalhe TO authenticated;
