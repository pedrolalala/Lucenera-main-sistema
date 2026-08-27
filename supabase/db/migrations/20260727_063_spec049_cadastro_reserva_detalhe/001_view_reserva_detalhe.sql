-- Migration 20260727_063 - SPEC-049
--
-- Card lateral de peca no Cadastro (cadastro-lucenera-b86fe, PecaDetailsPanel.tsx):
-- nova secao "Reservado por Cliente/Projeto" -- uma linha por (produto_id,
-- projeto_item_id) com reserva ativa, mostrando projeto, cliente e equipe
-- comercial responsavel.
--
-- Reaproveita vw_estoque_por_produto_projeto (SPEC-010), ja filtrada aos
-- saldos com status_operacional = 'ativo'. Nao recria estoque_reservas nem
-- qualquer tabela paralela por cliente -- cliente/projeto/equipe continuam
-- resolvidos por JOIN, nunca duplicados numa tabela de saldo (invariante da
-- SPEC-010).
--
-- Decisoes do usuario (2026-07-27, ver SPEC-049):
--   P-01: "equipe" = projetos.equipe_id (equipe comercial/vendas), NAO
--         equipe_responsavel_obra_id.
--   P-02: multiplas reservas da mesma peca aparecem como uma linha por
--         projeto/cliente, sem agregacao (sem GROUP BY adicional).
--
-- Colunas de origem verificadas contra supabase/db/current/01_schema_full.sql:
--   vw_estoque_por_produto_projeto (linhas 6919-6940), projetos.equipe_id ->
--   equipes_projetos.id, equipes_projetos.equipes (text), contatos.nome.

CREATE OR REPLACE VIEW public.vw_cadastro_produto_reserva_detalhe
WITH (security_invoker = true)
AS
SELECT
    v.projeto_item_id,
    v.projeto_id,
    v.projeto_codigo,
    v.orcamento_id,
    v.orcamento_numero,
    v.produto_id,
    v.produto_codigo,
    v.cliente_id,
    c.nome                       AS cliente_nome,
    pr.equipe_id,
    eq.equipes                   AS equipe_nome,
    v.q_venda,
    v.q_reserva,
    v.q_entrega_futura,
    v.status_operacional
FROM public.vw_estoque_por_produto_projeto v
LEFT JOIN public.projetos pr          ON pr.id = v.projeto_id
LEFT JOIN public.contatos c           ON c.id = v.cliente_id
LEFT JOIN public.equipes_projetos eq  ON eq.id = pr.equipe_id
WHERE v.q_reserva > 0 OR v.q_entrega_futura > 0;

COMMENT ON VIEW public.vw_cadastro_produto_reserva_detalhe IS
'SPEC-049. Uma linha por (produto_id, projeto_item_id) com reserva ativa.
Reaproveita vw_estoque_por_produto_projeto (SPEC-010), soma cliente (contatos)
e equipe (projetos.equipe_id -> equipes_projetos). Somente leitura, consumida
pelo painel lateral de peca do Cadastro. SECURITY INVOKER.';

GRANT SELECT ON public.vw_cadastro_produto_reserva_detalhe TO authenticated;
