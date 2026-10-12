-- Rollback da migration 204 (SPEC-193 C1): só remove a view nova.
DROP VIEW IF EXISTS public.vw_consulta_estoque;
