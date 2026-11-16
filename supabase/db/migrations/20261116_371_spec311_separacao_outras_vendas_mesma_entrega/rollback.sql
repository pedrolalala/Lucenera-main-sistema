BEGIN;
ALTER TABLE public.separacoes DROP COLUMN IF EXISTS outras_vendas;
COMMIT;
