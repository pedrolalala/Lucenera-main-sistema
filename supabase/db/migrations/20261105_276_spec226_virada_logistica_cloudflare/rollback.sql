-- Rollback da 276: o card da Logística volta a abrir o Lovable.
BEGIN;
UPDATE public.systems SET link = 'https://lucenera.lovable.app/separacao' WHERE slug = 'logistica';
COMMIT;
