-- Migration 20260630_010 — Parte 1
-- Remove o trigger legado trg_reserva_estoque de projetos.
--
-- Esse trigger disparava quando projetos.status mudava para 'Proposta Sinal',
-- reservando estoque via estoque_itens(local='Reservado'). Com a nova lógica
-- (reserva na aprovação do orçamento, dentro de aprovar_orcamento_financeiro),
-- o evento correto é a aprovação comercial, não a mudança de status do projeto.
-- Manter os dois geraria dupla reserva.
--
-- SPEC-005 já havia identificado esse trigger como pendência de revisão futura.
-- A função trigger_reserva_estoque() também é removida pois não é referenciada
-- por nenhum outro trigger após esta migration.

DROP TRIGGER IF EXISTS trg_reserva_estoque ON public.projetos;
DROP FUNCTION IF EXISTS public.trigger_reserva_estoque();
