BEGIN;
ALTER TABLE public.projetos DROP COLUMN IF EXISTS eletricista_id;
COMMIT;
