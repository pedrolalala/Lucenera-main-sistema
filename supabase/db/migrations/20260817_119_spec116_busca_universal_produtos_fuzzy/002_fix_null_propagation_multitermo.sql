-- Migration 20260817_119 (SPEC-116, piloto 1 — fix)
-- Bug achado testando ao vivo: buscar "led plafon" trazia produtos sem
-- nenhum "led" em campo algum. Causa raiz — lógica de 3 valores do SQL:
-- `p.sku ilike '%led%'` retorna NULL (não false) quando p.sku IS NULL, e o
-- mesmo para referencia/descricao_tecnica. No OR-chain de 001, uma condição
-- NULL faz a expressão inteira virar NULL em vez de false; e
-- `WHERE NOT (<expressão NULL>)` também é NULL, que o Postgres trata como
-- "não verdadeiro" — ou seja, o termo era silenciosamente ignorado pelo
-- NOT EXISTS em vez de reprovar o produto. Como boa parte de produtos tem
-- sku/referencia/descricao_tecnica NULL (confirmado: ~40 produtos sem SKU
-- só nesta amostra, mais os que nunca tiveram descricao_tecnica
-- preenchida), isso afetava buscas multi-termo com bastante frequência.
--
-- Fix: envolver toda coluna nullable usada em ilike com coalesce(...,'')
-- no bloco de filtro multi-termo, igual já era feito no cálculo de
-- relevancia (que usava coalesce só no word_similarity, nunca no ilike).

CREATE OR REPLACE FUNCTION public.buscar_produtos_fuzzy(
    p_termo         text DEFAULT NULL,
    p_marca_id      uuid DEFAULT NULL,
    p_categoria_id  uuid DEFAULT NULL,
    p_produto_ids   uuid[] DEFAULT NULL,
    p_offset        int DEFAULT 0,
    p_limit         int DEFAULT 100
) RETURNS TABLE (
    id             uuid,
    nome           text,
    sku            text,
    referencia     text,
    codigo_produto integer,
    preco_venda    numeric,
    valor_venda    numeric,
    marca_nome     text,
    categoria_nome text
)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
DECLARE
    v_termo   text := nullif(trim(p_termo), '');
    v_termos  text[];
BEGIN
    IF v_termo IS NOT NULL THEN
        v_termos := regexp_split_to_array(v_termo, '\s+');
    END IF;

    RETURN QUERY
    SELECT sub.id, sub.nome, sub.sku, sub.referencia, sub.codigo_produto,
           sub.preco_venda, sub.valor_venda, sub.marca_nome, sub.categoria_nome
    FROM (
        SELECT DISTINCT
            p.id, p.nome, p.sku, p.referencia, p.codigo_produto,
            p.preco_venda, p.valor_venda,
            m.nome AS marca_nome,
            c.nome AS categoria_nome,
            COALESCE((
                SELECT avg(
                    GREATEST(
                        CASE WHEN p.nome ilike '%' || t.termo || '%' THEN 1.0 ELSE 0 END,
                        CASE WHEN p.sku ilike '%' || t.termo || '%' THEN 1.0 ELSE 0 END,
                        CASE WHEN p.referencia ilike '%' || t.termo || '%' THEN 1.0 ELSE 0 END,
                        CASE WHEN p.descricao_tecnica ilike '%' || t.termo || '%' THEN 1.0 ELSE 0 END,
                        CASE WHEN t.termo ~ '^\d+$' AND p.codigo_produto = t.termo::int THEN 1.0 ELSE 0 END,
                        word_similarity(public.immutable_unaccent(lower(t.termo)), public.immutable_unaccent(lower(p.nome))),
                        word_similarity(public.immutable_unaccent(lower(t.termo)), public.immutable_unaccent(lower(coalesce(m.nome, '')))),
                        word_similarity(public.immutable_unaccent(lower(t.termo)), public.immutable_unaccent(lower(coalesce(c.nome, '')))),
                        word_similarity(public.immutable_unaccent(lower(t.termo)), public.immutable_unaccent(lower(coalesce(p.descricao_tecnica, ''))))
                    )
                )
                FROM unnest(v_termos) AS t(termo)
            ), 1.0) AS relevancia
        FROM public.produtos p
        LEFT JOIN public.marcas m ON m.id = p.marca_id
        LEFT JOIN public.categorias_produto c ON c.id = p.categoria_id
        WHERE p.ativo = true
          AND (p_marca_id IS NULL OR p.marca_id = p_marca_id)
          AND (p_categoria_id IS NULL OR p.categoria_id = p_categoria_id)
          AND (p_produto_ids IS NULL OR p.id = ANY(p_produto_ids))
          AND (
            v_termos IS NULL
            OR NOT EXISTS (
                SELECT 1 FROM unnest(v_termos) AS t(termo)
                WHERE NOT (
                    coalesce(p.nome, '') ilike '%' || t.termo || '%'
                    OR coalesce(p.sku, '') ilike '%' || t.termo || '%'
                    OR coalesce(p.referencia, '') ilike '%' || t.termo || '%'
                    OR coalesce(p.descricao_tecnica, '') ilike '%' || t.termo || '%'
                    OR (t.termo ~ '^\d+$' AND p.codigo_produto = t.termo::int)
                    OR word_similarity(public.immutable_unaccent(lower(t.termo)), public.immutable_unaccent(lower(coalesce(p.nome, '')))) > 0.3
                    OR word_similarity(public.immutable_unaccent(lower(t.termo)), public.immutable_unaccent(lower(coalesce(m.nome, '')))) > 0.3
                    OR word_similarity(public.immutable_unaccent(lower(t.termo)), public.immutable_unaccent(lower(coalesce(c.nome, '')))) > 0.3
                    OR word_similarity(public.immutable_unaccent(lower(t.termo)), public.immutable_unaccent(lower(coalesce(p.descricao_tecnica, '')))) > 0.3
                )
            )
          )
    ) sub
    ORDER BY sub.relevancia DESC, sub.nome
    OFFSET p_offset
    LIMIT p_limit;
END;
$$;

COMMENT ON FUNCTION public.buscar_produtos_fuzzy(text, uuid, uuid, uuid[], int, int) IS
'SPEC-100 + SPEC-116 (com fix de NULL da migration 002). Busca "estilo
Google" de pecas: o termo livre e quebrado em palavras por espaco; cada
palavra precisa casar (substring/exato/word_similarity(unaccent(lower(...)))
> 0.3) em pelo menos um campo (nome, sku, referencia, codigo_produto,
descricao_tecnica, marca ou categoria) para a linha entrar no resultado —
nao precisa ser o mesmo campo para cada palavra. Colunas nullable (sku,
referencia, descricao_tecnica) sao protegidas com coalesce(coluna, '')
antes do ilike, para nao deixar a logica de 3 valores do SQL silenciar um
termo quando a coluna e NULL. p_marca_id/p_categoria_id/p_produto_ids
replicam os filtros <Select> ja existentes. Ordena por relevancia media dos
termos desc, depois nome. SECURITY INVOKER.';

GRANT EXECUTE ON FUNCTION public.buscar_produtos_fuzzy(text, uuid, uuid, uuid[], int, int) TO authenticated;
