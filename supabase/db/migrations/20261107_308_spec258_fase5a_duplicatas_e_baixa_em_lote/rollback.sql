-- SPEC-258 Fase 5a: remove a função de baixa em lote e a view de duplicatas (não toca em nenhuma tabela).
-- Baixas já feitas por ela permanecem (histórico financeiro não se apaga); só ficam sem a tela para repetir.
DROP FUNCTION IF EXISTS public.financeiro_baixar_lote(uuid[], date, text, uuid, numeric, numeric, text, text);
DROP VIEW IF EXISTS public.vw_financeiro_duplicatas;
