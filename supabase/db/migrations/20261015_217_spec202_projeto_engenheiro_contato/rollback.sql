BEGIN;
ALTER TABLE public.projetos DROP COLUMN IF EXISTS engenheiro_id;
COMMIT;
