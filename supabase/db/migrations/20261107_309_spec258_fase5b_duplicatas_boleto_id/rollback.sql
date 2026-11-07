-- SPEC-258 Fase 5b: volta a view para a versão da migration 308 (sem boleto_id) e remove o índice.
-- ATENÇÃO: as telas que lerem boleto_id quebram; reverter as telas antes.
DROP VIEW IF EXISTS public.vw_financeiro_duplicatas;
-- recria a versão 308: rodar o up.sql da migration 20261107_308_spec258_fase5a_duplicatas_e_baixa_em_lote (só a parte CREATE VIEW + GRANT/REVOKE).
DROP INDEX IF EXISTS public.financeiro_legado_ids_novo_idx;
