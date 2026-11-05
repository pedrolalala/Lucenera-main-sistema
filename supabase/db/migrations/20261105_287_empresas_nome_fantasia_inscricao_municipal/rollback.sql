BEGIN;
ALTER TABLE public.empresas DROP COLUMN IF EXISTS nome_fantasia;
ALTER TABLE public.empresas DROP COLUMN IF EXISTS inscricao_municipal;
COMMIT;
