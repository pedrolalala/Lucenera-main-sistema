-- SPEC-224 (pedido do usuário 23/10): na Movimentação de Peças, com a busca vazia já aparecem todas as peças com
-- estoque positivo em algum setor (hoje ~1.920). Com termo, continua a busca (até 40). Volta também "outros":
-- Garantia + Casa Cor + Defeito + Amostra / Emprestado, para a peça que só tem saldo fora do Estoque/Showroom.
-- Muda o tipo de retorno: DROP + CREATE (não dá para CREATE OR REPLACE). Sem BEGIN/COMMIT.

DROP FUNCTION IF EXISTS public.movimentacao_buscar_pecas(text);

CREATE FUNCTION public.movimentacao_buscar_pecas(p_termo text)
 RETURNS TABLE (id uuid, codigo_produto integer, referencia text, nome text, marca text,
                estoque_geral numeric, showroom integer, outros numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_termos text[] := array_remove(regexp_split_to_array(lower(btrim(coalesce(p_termo, ''))), '\s+'), '');
  v_vazio  boolean;
BEGIN
  IF NOT public._mov_pode() THEN
    RAISE EXCEPTION 'Sem permissao.' USING ERRCODE = '42501';
  END IF;
  v_vazio := coalesce(array_length(v_termos, 1), 0) = 0;
  RETURN QUERY
  WITH saldos AS (
    SELECT ei.produto_id,
           sum(ei.quantidade) FILTER (WHERE ei.local = 'Estoque') AS geral,
           sum(ei.quantidade) FILTER (WHERE ei.local IN ('Estoque Garantia', 'Estoque Casa Cor', 'Estoque Defeito',
                                                        'Amostra / Emprestado')) AS outros
      FROM public.estoque_itens ei
     GROUP BY ei.produto_id
  )
  SELECT p.id, p.codigo_produto, p.referencia, p.nome, m.nome,
         coalesce(s.geral, 0), coalesce(p.estoque_showroom, 0), coalesce(s.outros, 0)
    FROM public.produtos p
    LEFT JOIN public.marcas m ON m.id = p.marca_id
    LEFT JOIN saldos s ON s.produto_id = p.id
   WHERE coalesce(p.ativo, true)
     AND (CASE WHEN v_vazio
               THEN coalesce(s.geral, 0) > 0 OR coalesce(p.estoque_showroom, 0) > 0 OR coalesce(s.outros, 0) > 0
               ELSE NOT EXISTS (
                 SELECT 1 FROM unnest(v_termos) t
                  WHERE NOT (coalesce(p.codigo_produto::text, '') LIKE '%' || t || '%'
                             OR lower(coalesce(p.referencia, '')) LIKE '%' || t || '%'
                             OR lower(coalesce(p.nome, '')) LIKE '%' || t || '%'
                             OR lower(coalesce(m.nome, '')) LIKE '%' || t || '%'))
          END)
   ORDER BY (NOT v_vazio AND p.codigo_produto::text = v_termos[1]) DESC, p.codigo_produto
   LIMIT CASE WHEN v_vazio THEN 10000 ELSE 40 END;
END;
$function$;

REVOKE ALL ON FUNCTION public.movimentacao_buscar_pecas(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.movimentacao_buscar_pecas(text) TO authenticated;
