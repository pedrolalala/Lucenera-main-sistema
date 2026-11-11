BEGIN;
ALTER TABLE public.produtos ALTER COLUMN codigo_produto SET DEFAULT nextval('produtos_codigo_produto_seq'::regclass);
UPDATE public.produtos SET codigo_produto = 1547271 WHERE codigo_produto = 13798 AND referencia = '4349';
UPDATE public.produtos SET codigo_produto = 1547276 WHERE codigo_produto = 13799 AND referencia = 'P883';
DROP FUNCTION IF EXISTS public.proximo_codigo_produto();
COMMIT;
