-- SPEC-161 Prioridade 12 — Controle de Garantia: bug confirmado —
-- produto_nome_resolvido nunca resolve o nome do produto cadastrado.
--
-- Causa raiz: em listarItens() (services/garantia.ts), o mapeamento fazia
-- produto_nome_resolvido = produto_descricao_livre sempre, nunca buscando
-- o nome real via produto_id.
--
-- Por que não um simples `.select('*, produtos(nome)')` (join direto)? A
-- RLS real de `produtos` (spec069_produtos_select) exige um papel do Hub
-- ('cadastro'/'orcamentos'/'necessidade-de-compra') que o Controle de
-- Garantia não tem — confirmado (ver 20260922_158_garantia/
-- 002_garantia_buscar_produtos.sql, que documentou o mesmo problema pra
-- busca de produto). Um embed direto de `produtos(nome)` a partir de
-- garantia_itens ficaria em branco pra qualquer usuário sem esse papel do
-- Hub — o mesmo bug, só que disfarçado. Por isso: função SECURITY DEFINER
-- de resolução em lote (mesmo padrão já usado em
-- garantia_buscar_produtos/garantia_resolver_data_venda), devolvendo só
-- id + nome, nunca preço.

BEGIN;

CREATE OR REPLACE FUNCTION public.garantia_resolver_nomes_produtos(p_produto_ids uuid[])
RETURNS TABLE(id uuid, nome text)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
    SELECT p.id, p.nome
    FROM produtos p
    WHERE p.id = ANY (p_produto_ids);
$$;

COMMENT ON FUNCTION public.garantia_resolver_nomes_produtos(uuid[]) IS
  'SPEC-161 Prioridade 12: resolve em lote o nome real de produtos cadastrados (produto_id) pro Controle de Garantia. SECURITY DEFINER pra contornar a RLS de produtos (restrita a papéis do Hub que o Garantia não tem) — devolve só id + nome, nunca preço de custo/venda.';

GRANT EXECUTE ON FUNCTION public.garantia_resolver_nomes_produtos(uuid[]) TO authenticated;

COMMIT;
