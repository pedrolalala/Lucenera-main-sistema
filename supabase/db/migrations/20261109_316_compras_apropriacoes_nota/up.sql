-- Entrada de NF (Compras): lista das apropriacoes permitidas (REVENDA, INDUSTRIALIZACAO, GARANTIA).
-- plano_de_contas so e legivel para quem acessa o Financeiro; a funcao devolve apenas essas 3 contas. Sem mudar RLS.
CREATE OR REPLACE FUNCTION public.compras_apropriacoes_nota()
RETURNS TABLE (id uuid, codigo_connect integer, nome text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS
$f$
  SELECT p.id, p.codigo_connect::integer, p.nome
    FROM public.plano_de_contas p
   WHERE p.codigo_connect IN (2050001, 2050010, 2050003)
     AND ((SELECT public.pode_acessar_sistema('necessidade-de-compra')) OR (SELECT public.pode_acessar_sistema('financeiro')))
   ORDER BY CASE p.codigo_connect WHEN 2050001 THEN 1 WHEN 2050010 THEN 2 ELSE 3 END
$f$;
REVOKE ALL ON FUNCTION public.compras_apropriacoes_nota() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.compras_apropriacoes_nota() TO authenticated;
