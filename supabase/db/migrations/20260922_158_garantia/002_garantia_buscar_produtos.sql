-- SPEC-156 Módulo 2 — achado ao implementar o frontend: `produtos` tem RLS
-- restrita a quem tem papel 'cadastro'/'orcamentos'/'necessidade-de-compra'
-- no Hub (spec069_produtos_select) — ninguém do Garantia teria nenhum
-- desses papéis, então a busca de produto pra abrir um garantia_itens
-- ficaria sempre vazia. Mesma solução já usada pra notas_fiscais: função
-- SECURITY DEFINER que devolve só o necessário pra um dropdown de busca
-- (nome/sku/referência), nunca preço de custo/venda.

CREATE OR REPLACE FUNCTION public.garantia_buscar_produtos(p_search text)
RETURNS TABLE(id uuid, nome text, sku text, referencia text)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
    SELECT p.id, p.nome, p.sku, p.referencia
    FROM produtos p
    WHERE p.ativo = true
      AND (
        p_search IS NULL OR p_search = '' OR
        p.nome ILIKE '%' || p_search || '%' OR
        p.sku ILIKE '%' || p_search || '%' OR
        p.referencia ILIKE '%' || p_search || '%'
      )
    ORDER BY p.nome
    LIMIT 30;
$$;

COMMENT ON FUNCTION public.garantia_buscar_produtos(text) IS
  'SPEC-156 Módulo 2: busca produtos por nome/sku/referência pro dropdown do Controle de Garantia. SECURITY DEFINER pra contornar a RLS de produtos (restrita a papéis do Hub que o Garantia não tem) — devolve só campos de identificação, nunca preço de custo/venda.';

GRANT EXECUTE ON FUNCTION public.garantia_buscar_produtos(text) TO authenticated;
