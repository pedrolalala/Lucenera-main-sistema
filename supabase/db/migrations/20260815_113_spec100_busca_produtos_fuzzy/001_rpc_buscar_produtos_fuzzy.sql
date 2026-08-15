-- Migration 20260815_113 (SPEC-100)
-- RPC buscar_produtos_fuzzy: busca de peças "estilo Google" no orçamento.
--
-- Problema (reunião Vinícius 14/08/2026): a busca livre do ProductSearchModal
-- já cobria nome/sku/referencia/codigo_produto (.or() do PostgREST), mas
-- marca e categoria eram só filtros <Select> separados — nunca entravam no
-- texto livre, porque marca_nome/categoria_nome vêm de JOIN e o .or() do
-- supabase-js só filtra colunas da própria tabela.
--
-- Solução escolhida (Opção B da SPEC-100, confirmada com o usuário): RPC
-- fuzzy única, mesmo padrão de buscar_fornecedores_fuzzy (SPEC-030/034) —
-- usa word_similarity(unaccent(lower(...))) para marca/categoria (tolera
-- erro de digitação e casa termo curto contra nome longo), mantendo o ilike
-- de substring exata em nome/sku/referencia/codigo_produto que já existia
-- (não regride nenhum caso que já funcionava).
--
-- Sem índice trgm dedicado: produtos tem ~4.7k linhas hoje (2026-08-15) —
-- sequential scan é sub-ms nesse volume. Revisitar se a tabela crescer muito.
--
-- SECURITY INVOKER: só leitura, respeita as policies de SELECT já abertas
-- (authenticated) em produtos/marcas/categorias_produto.

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
    v_numeric int;
BEGIN
    IF v_termo IS NOT NULL AND v_termo ~ '^\d+$' THEN
        v_numeric := v_termo::int;
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
            CASE WHEN v_termo IS NULL THEN 1.0 ELSE GREATEST(
                CASE WHEN p.nome ilike '%' || v_termo || '%' THEN 1.0 ELSE 0 END,
                CASE WHEN p.sku ilike '%' || v_termo || '%' THEN 1.0 ELSE 0 END,
                CASE WHEN p.referencia ilike '%' || v_termo || '%' THEN 1.0 ELSE 0 END,
                CASE WHEN v_numeric IS NOT NULL AND p.codigo_produto = v_numeric THEN 1.0 ELSE 0 END,
                word_similarity(public.immutable_unaccent(lower(v_termo)), public.immutable_unaccent(lower(p.nome))),
                word_similarity(public.immutable_unaccent(lower(v_termo)), public.immutable_unaccent(lower(coalesce(m.nome, '')))),
                word_similarity(public.immutable_unaccent(lower(v_termo)), public.immutable_unaccent(lower(coalesce(c.nome, ''))))
            ) END AS relevancia
        FROM public.produtos p
        LEFT JOIN public.marcas m ON m.id = p.marca_id
        LEFT JOIN public.categorias_produto c ON c.id = p.categoria_id
        WHERE p.ativo = true
          AND (p_marca_id IS NULL OR p.marca_id = p_marca_id)
          AND (p_categoria_id IS NULL OR p.categoria_id = p_categoria_id)
          AND (p_produto_ids IS NULL OR p.id = ANY(p_produto_ids))
          AND (
            v_termo IS NULL
            OR p.nome ilike '%' || v_termo || '%'
            OR p.sku ilike '%' || v_termo || '%'
            OR p.referencia ilike '%' || v_termo || '%'
            OR (v_numeric IS NOT NULL AND p.codigo_produto = v_numeric)
            OR word_similarity(public.immutable_unaccent(lower(v_termo)), public.immutable_unaccent(lower(p.nome))) > 0.3
            OR word_similarity(public.immutable_unaccent(lower(v_termo)), public.immutable_unaccent(lower(coalesce(m.nome, '')))) > 0.3
            OR word_similarity(public.immutable_unaccent(lower(v_termo)), public.immutable_unaccent(lower(coalesce(c.nome, '')))) > 0.3
          )
    ) sub
    ORDER BY sub.relevancia DESC, sub.nome
    OFFSET p_offset
    LIMIT p_limit;
END;
$$;

COMMENT ON FUNCTION public.buscar_produtos_fuzzy(text, uuid, uuid, uuid[], int, int) IS
'SPEC-100. Busca "estilo Google" de peças no orçamento: um termo livre casa
contra nome, sku, referencia, codigo_produto (substring/exato) e contra
marca/categoria via word_similarity(unaccent(lower(...))) > 0.3 (tolera erro
de digitacao, mesmo padrao de buscar_fornecedores_fuzzy da SPEC-030/034).
p_marca_id/p_categoria_id/p_produto_ids replicam os filtros <Select> e o
filtro de fornecedor (resolvido client-side) ja existentes no
ProductSearchModal. Ordena por relevancia desc, depois nome. SECURITY
INVOKER.';

GRANT EXECUTE ON FUNCTION public.buscar_produtos_fuzzy(text, uuid, uuid, uuid[], int, int) TO authenticated;
