-- Migration 20260827_125 (SPEC-122) -- fix
-- Bug achado testando ao vivo logo apos aplicar 001: "lampada led" (sem
-- acento) achava 126 produtos, mas "lâmpada" (com acento, forma correta
-- em portugues) achava 0 -- regressao de acento-insensibilidade que a
-- SPEC-116 ja garantia (unaccent+lower no word_similarity).
--
-- Causa: 001 trocou o criterio de ELIMINACAO pra `ilike` literal puro
-- (sem unaccent), pra cortar o fallback de similaridade. Isso resolveu o
-- problema de "elimina por palavra" mas quebrou a comparacao de acento,
-- porque `ilike` compara caractere a caractere ('â' != 'a').
--
-- Fix: envolve os dois lados (coluna e termo) com
-- immutable_unaccent(lower(...)) antes do ilike -- continua sendo
-- comparacao de SUBSTRING LITERAL (nao similaridade/score), so que
-- normalizada por acento e caixa. Mantem a garantia de eliminacao da 001
-- e devolve a garantia de acento da SPEC-116, sem reintroduzir o
-- word_similarity na eliminacao.

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
            -- Ranking (inalterado desde 20260819_120): so afeta ORDER BY.
            COALESCE((
                SELECT avg(
                    GREATEST(
                        CASE WHEN t.termo ~ '^\d+$' AND p.codigo_produto = t.termo::int THEN 5.0 ELSE 0 END,
                        CASE WHEN p.referencia ilike '%' || t.termo || '%' THEN 4.0 ELSE 0 END,
                        CASE WHEN p.sku ilike '%' || t.termo || '%' THEN 4.0 ELSE 0 END,
                        CASE WHEN coalesce(m.nome, '') ilike '%' || t.termo || '%'
                                  OR word_similarity(public.immutable_unaccent(lower(t.termo)), public.immutable_unaccent(lower(coalesce(m.nome, '')))) > 0.3
                             THEN 3.0 ELSE 0 END,
                        CASE WHEN p.nome ilike '%' || t.termo || '%'
                                  OR word_similarity(public.immutable_unaccent(lower(t.termo)), public.immutable_unaccent(lower(p.nome))) > 0.3
                             THEN 2.0 ELSE 0 END,
                        CASE WHEN p.descricao_tecnica ilike '%' || t.termo || '%'
                                  OR coalesce(c.nome, '') ilike '%' || t.termo || '%'
                                  OR word_similarity(public.immutable_unaccent(lower(t.termo)), public.immutable_unaccent(lower(coalesce(c.nome, '')))) > 0.3
                                  OR word_similarity(public.immutable_unaccent(lower(t.termo)), public.immutable_unaccent(lower(coalesce(p.descricao_tecnica, '')))) > 0.3
                             THEN 1.0 ELSE 0 END
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
                -- ELIMINACAO: substring literal, mas normalizada por
                -- acento/caixa (immutable_unaccent+lower nos dois lados) --
                -- continua sem fallback de similaridade/score.
                SELECT 1 FROM unnest(v_termos) AS t(termo)
                WHERE NOT (
                    public.immutable_unaccent(lower(coalesce(p.nome, ''))) ilike '%' || public.immutable_unaccent(lower(t.termo)) || '%'
                    OR public.immutable_unaccent(lower(coalesce(p.sku, ''))) ilike '%' || public.immutable_unaccent(lower(t.termo)) || '%'
                    OR public.immutable_unaccent(lower(coalesce(p.referencia, ''))) ilike '%' || public.immutable_unaccent(lower(t.termo)) || '%'
                    OR public.immutable_unaccent(lower(coalesce(p.descricao_tecnica, ''))) ilike '%' || public.immutable_unaccent(lower(t.termo)) || '%'
                    OR public.immutable_unaccent(lower(coalesce(m.nome, ''))) ilike '%' || public.immutable_unaccent(lower(t.termo)) || '%'
                    OR public.immutable_unaccent(lower(coalesce(c.nome, ''))) ilike '%' || public.immutable_unaccent(lower(t.termo)) || '%'
                    OR (t.termo ~ '^\d+$' AND p.codigo_produto = t.termo::int)
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
'SPEC-100 + SPEC-116 + prioridade de ranking (2026-08-19) + SPEC-122
(2026-08-27, busca eliminatoria, fix de acento). Busca de pecas: o termo
livre e quebrado em palavras por espaco; cada palavra precisa aparecer
LITERALMENTE (substring, normalizada por acento/caixa via
immutable_unaccent+lower, sem fallback de similaridade) em nome/sku/
referencia/descricao_tecnica/marca/categoria, ou ser o codigo exato, para
a linha entrar no resultado. Ranking (so ORDER BY, nao afeta inclusao)
prioriza Codigo > Referencia/SKU > Marca > Descricao (nome) > categoria/
descricao_tecnica, com word_similarity ainda usada ali pra desempate.
Preco e estoque nunca entram na busca. p_marca_id/p_categoria_id/
p_produto_ids replicam os filtros <Select> ja existentes. SECURITY
INVOKER.';

GRANT EXECUTE ON FUNCTION public.buscar_produtos_fuzzy(text, uuid, uuid, uuid[], int, int) TO authenticated;
