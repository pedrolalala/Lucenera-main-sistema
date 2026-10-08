-- Rollback da 20261008_193
DROP TABLE IF EXISTS public.erros_tela;
NOTIFY pgrst, 'reload schema';
