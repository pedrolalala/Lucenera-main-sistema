BEGIN;
ALTER TABLE public.compras_config DROP COLUMN IF EXISTS assinatura_email;
COMMIT;
