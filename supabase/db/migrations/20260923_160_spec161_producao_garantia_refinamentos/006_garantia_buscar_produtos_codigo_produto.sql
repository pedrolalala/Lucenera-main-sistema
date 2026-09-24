-- SPEC-161 Prioridade 13 — Controle de Garantia: busca de produto mostra
-- "código interno" (produtos.codigo_produto, integer, sequence da
-- SPEC-053).
--
-- ATENÇÃO (bug de Postgres documentado no projeto): CREATE OR REPLACE
-- FUNCTION não consegue mudar o tipo de retorno de uma função existente
-- (isso inclui adicionar uma coluna em RETURNS TABLE(...)) — dá erro
-- "cannot change return type of existing function". A função já existe em
-- produção com RETURNS TABLE(id uuid, nome text, sku text, referencia
-- text) (migration 20260922_158_garantia/002_garantia_buscar_produtos.sql)
-- — por isso o DROP FUNCTION explícito abaixo, antes do CREATE OR REPLACE
-- com a nova assinatura.

BEGIN;

DROP FUNCTION public.garantia_buscar_produtos(text);

CREATE OR REPLACE FUNCTION public.garantia_buscar_produtos(p_search text)
RETURNS TABLE(id uuid, nome text, sku text, referencia text, codigo_produto integer)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
    SELECT p.id, p.nome, p.sku, p.referencia, p.codigo_produto
    FROM produtos p
    WHERE p.ativo = true
      AND (
        p_search IS NULL OR p_search = '' OR
        p.nome ILIKE '%' || p_search || '%' OR
        p.sku ILIKE '%' || p_search || '%' OR
        p.referencia ILIKE '%' || p_search || '%' OR
        p.codigo_produto::text ILIKE '%' || p_search || '%'
      )
    ORDER BY p.nome
    LIMIT 30;
$$;

COMMENT ON FUNCTION public.garantia_buscar_produtos(text) IS
  'SPEC-156/161: busca produtos por nome/sku/referência/código interno pro dropdown do Controle de Garantia. SECURITY DEFINER pra contornar a RLS de produtos (restrita a papéis do Hub que o Garantia não tem) — devolve só campos de identificação (incl. codigo_produto), nunca preço de custo/venda.';

GRANT EXECUTE ON FUNCTION public.garantia_buscar_produtos(text) TO authenticated;

COMMIT;
