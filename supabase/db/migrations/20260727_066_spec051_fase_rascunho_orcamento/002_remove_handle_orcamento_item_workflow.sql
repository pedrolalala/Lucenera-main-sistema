-- SPEC-051 — Fase explícita de Rascunho antes do envio ao cliente
--
-- `handle_orcamento_item_workflow()` (trigger `trg_orcamento_item_workflow`,
-- AFTER INSERT ON orcamento_itens) existia só para promover automaticamente
-- o orçamento pai para `enviado_cliente` assim que o primeiro item era
-- inserido — na prática era o gatilho mais direto do problema, porque no
-- fluxo de criação (`useBudgetStore.ts:addBudget`) o orçamento nasce em
-- `rascunho` e os itens são inseridos logo em seguida, num segundo INSERT.
--
-- Confirmado (SPEC-051, leitura direta do Supabase real em 2026-07-27):
-- a função não tem nenhuma outra responsabilidade. Removida por completo.

DROP TRIGGER IF EXISTS trg_orcamento_item_workflow ON public.orcamento_itens;
DROP FUNCTION IF EXISTS public.handle_orcamento_item_workflow();
