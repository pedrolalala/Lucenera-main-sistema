-- Migration 20260928_171 - SPEC-171
--
-- Catálogo Ubiqua passa a mostrar o estoque ATUAL de public.produtos (atualizado
-- pelo import do Connect) em vez de revenda_ubiqua.disponivel, que é uma cópia
-- parada de 03/06/2026 sem sincronização.
--
-- Representantes do Ubiqua não têm papel no Hub e a RLS de produtos
-- (spec069_produtos_select) os bloqueia. Esta função SECURITY DEFINER devolve só
-- referência + estoque disponível das peças que estão no catálogo Ubiqua — não
-- expõe preço, custo nem nenhum outro produto.
--
-- Cruzamento: produtos.referencia = revenda_ubiqua.referencia (trim/maiúsculas),
-- mesma chave da SPEC-137. Em 28/09: 77 de 87 linhas casam, nenhuma com mais de
-- um produto; as 10 sem par não têm estoque.
--
-- Não altera produtos nem revenda_ubiqua (SPEC-137: produtos é a fonte de
-- verdade de estoque; aqui só lemos).
--
-- Rollback: DROP FUNCTION public.ubiqua_estoque_atual();

CREATE OR REPLACE FUNCTION public.ubiqua_estoque_atual()
RETURNS TABLE (referencia text, disponivel integer)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT r.referencia,
         GREATEST(0, FLOOR(COALESCE(p.estoque_disponivel, 0)))::integer
    FROM public.revenda_ubiqua r
    JOIN public.produtos p
      ON upper(trim(p.referencia)) = upper(trim(r.referencia));
$$;

COMMENT ON FUNCTION public.ubiqua_estoque_atual() IS
  'SPEC-171: estoque disponível atual (produtos) das peças do Catálogo Ubiqua, por referência.';

REVOKE ALL ON FUNCTION public.ubiqua_estoque_atual() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ubiqua_estoque_atual() TO authenticated;

NOTIFY pgrst, 'reload schema';
