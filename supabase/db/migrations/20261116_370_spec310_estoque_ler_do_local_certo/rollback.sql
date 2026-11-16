-- SPEC-310: volta a funcao antiga e os valores antigos da coluna dos produtos
BEGIN;
UPDATE public.produtos p SET estoque_total = b.estoque_total, estoque_disponivel = b.estoque_disponivel
FROM backup._bkp_spec310_produtos_estoque_antigo b WHERE b.produto_id = p.id;
CREATE OR REPLACE FUNCTION public.ubiqua_estoque_atual()
RETURNS TABLE(referencia text, disponivel integer)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $$
  SELECT r.referencia, GREATEST(0, FLOOR(COALESCE(p.estoque_disponivel, 0)))::integer
    FROM public.revenda_ubiqua r JOIN public.produtos p ON upper(trim(p.referencia)) = upper(trim(r.referencia));
$$;
NOTIFY pgrst, 'reload schema';
COMMIT;
