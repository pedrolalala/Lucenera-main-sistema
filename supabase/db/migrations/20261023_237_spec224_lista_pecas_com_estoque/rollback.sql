-- Rollback da migration 237: volta a busca da 236 (sem a lista com estoque e sem a coluna outros). Sem BEGIN/COMMIT.

DROP FUNCTION IF EXISTS public.movimentacao_buscar_pecas(text);

CREATE OR REPLACE FUNCTION public.movimentacao_buscar_pecas(p_termo text)
 RETURNS TABLE(id uuid, codigo_produto integer, referencia text, nome text, marca text, estoque_geral numeric, showroom integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_termos text[] := array_remove(regexp_split_to_array(lower(btrim(coalesce(p_termo, ''))), '\s+'), '');
BEGIN
  IF NOT public._mov_pode() THEN
    RAISE EXCEPTION 'Sem permissao.' USING ERRCODE = '42501';
  END IF;
  IF coalesce(array_length(v_termos, 1), 0) = 0 THEN
    RETURN;
  END IF;
  RETURN QUERY
  SELECT p.id, p.codigo_produto, p.referencia, p.nome, m.nome,
         coalesce((SELECT ei.quantidade FROM public.estoque_itens ei WHERE ei.produto_id = p.id AND ei.local = 'Estoque'), 0),
         coalesce(p.estoque_showroom, 0)
    FROM public.produtos p
    LEFT JOIN public.marcas m ON m.id = p.marca_id
   WHERE coalesce(p.ativo, true)
     AND NOT EXISTS (
       SELECT 1 FROM unnest(v_termos) t
        WHERE NOT (coalesce(p.codigo_produto::text, '') LIKE '%' || t || '%'
                   OR lower(coalesce(p.referencia, '')) LIKE '%' || t || '%'
                   OR lower(coalesce(p.nome, '')) LIKE '%' || t || '%'
                   OR lower(coalesce(m.nome, '')) LIKE '%' || t || '%'))
   ORDER BY (p.codigo_produto::text = v_termos[1]) DESC, p.codigo_produto
   LIMIT 40;
END;
$function$
;

REVOKE ALL ON FUNCTION public.movimentacao_buscar_pecas(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.movimentacao_buscar_pecas(text) TO authenticated;
