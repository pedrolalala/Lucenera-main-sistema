-- SPEC-277: o código interno da peça segue a Connect (último + 1), não mais a sequência 1547xxx.
-- 1) renumera as 2 peças criadas pelo sistema (nada as referencia: conferido em showroom_*, notas_fiscais_connect_itens)
-- 2) novo DEFAULT: maior código "da Connect" (< 1.000.000; os de teste 1547xxx ficam de fora) + 1.
BEGIN;

UPDATE public.produtos SET codigo_produto = 13798 WHERE codigo_produto = 1547271 AND referencia = '4349';
UPDATE public.produtos SET codigo_produto = 13799 WHERE codigo_produto = 1547276 AND referencia = 'P883';

CREATE OR REPLACE FUNCTION public.proximo_codigo_produto()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE v integer;
BEGIN
  -- trava até o fim da transação: duas peças criadas juntas não pegam o mesmo número
  PERFORM pg_advisory_xact_lock(727727);
  SELECT COALESCE(MAX(codigo_produto), 0) + 1 INTO v FROM public.produtos WHERE codigo_produto < 1000000;
  RETURN v;
END $$;

REVOKE ALL ON FUNCTION public.proximo_codigo_produto() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.proximo_codigo_produto() TO authenticated, service_role;

ALTER TABLE public.produtos ALTER COLUMN codigo_produto SET DEFAULT public.proximo_codigo_produto();
COMMIT;
