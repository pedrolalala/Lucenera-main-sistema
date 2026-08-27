-- Migration 20260827_125 (SPEC-122)
-- Achado na reuniao Mariane+Pedro 27/08/2026: buscar N termos deveria
-- ELIMINAR produtos que nao contem alguma das palavras, nao so ranquear
-- por semelhanca. Medido direto no banco antes desta migration: os termos
-- "KPF12", "dicroica geo10 6w" e "lampada led" retornavam 4356-4384
-- produtos (de 4726 ativos totais) -- ou seja, o filtro multi-termo nao
-- eliminava quase nada na pratica.
--
-- Causa raiz: o bloco de ELIMINACAO (WHERE ... NOT EXISTS (... WHERE NOT
-- (...))) aceitava um termo como "encontrado" em um campo via
-- word_similarity(...) > 0.3, alem do ilike/codigo exato. Esse limiar e
-- permissivo demais (trigram de string curta bate com quase qualquer
-- coisa) e deixava produtos SEM a palavra digitada sobreviverem ao
-- filtro daquele termo.
--
-- Fix: tira a clausula word_similarity > 0.3 do bloco de ELIMINACAO.
-- Cada termo agora so "passa" se aparecer literalmente (ilike, ja com
-- coalesce pra coluna nula, corrigido na SPEC-116) em nome/sku/
-- referencia/descricao_tecnica/marca/categoria, ou for o codigo exato.
--
-- O calculo de `relevancia` (usado so no ORDER BY, migration 20260819_120
-- SPEC de prioridade Codigo>Referencia>Marca>Descricao) NAO muda -- ali
-- word_similarity continua valendo, so pra ordenar, nunca pra decidir se
-- o produto entra no resultado.
--
-- Assinatura da funcao nao muda -- nenhum consumidor (ProductSearchModal
-- em Orcamentos, getProdutosEstoqueFiltradoBatched em Cadastro) precisa
-- de alteracao.

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
            -- Ranking (2026-08-19, SPEC de prioridade): Codigo > Referencia/
            -- SKU > Marca > Descricao (nome) > categoria/descricao_tecnica.
            -- Continua usando word_similarity aqui -- so afeta ORDEM, nunca
            -- decide inclusao/exclusao (isso e feito no WHERE abaixo).
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
                -- ELIMINACAO: cada termo precisa aparecer literalmente
                -- (ilike/codigo exato) em algum campo -- SEM fallback de
                -- semelhanca. E aqui que a SPEC-122 corta o word_similarity
                -- que existia antes desta migration.
                SELECT 1 FROM unnest(v_termos) AS t(termo)
                WHERE NOT (
                    coalesce(p.nome, '') ilike '%' || t.termo || '%'
                    OR coalesce(p.sku, '') ilike '%' || t.termo || '%'
                    OR coalesce(p.referencia, '') ilike '%' || t.termo || '%'
                    OR coalesce(p.descricao_tecnica, '') ilike '%' || t.termo || '%'
                    OR coalesce(m.nome, '') ilike '%' || t.termo || '%'
                    OR coalesce(c.nome, '') ilike '%' || t.termo || '%'
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
(2026-08-27, busca eliminatoria). Busca de pecas: o termo livre e quebrado
em palavras por espaco; cada palavra precisa aparecer LITERALMENTE
(ilike substring, coalesce contra NULL) em nome/sku/referencia/
descricao_tecnica/marca/categoria, ou ser o codigo exato, para a linha
entrar no resultado -- nao precisa ser o mesmo campo pra cada palavra, mas
toda palavra elimina quem nao a contem (sem fallback por semelhanca).
Ranking (so ORDER BY, nao afeta inclusao) prioriza Codigo > Referencia/SKU
> Marca > Descricao (nome) > categoria/descricao_tecnica, com
word_similarity ainda usada ali para desempate por semelhanca. Preco e
estoque nunca entram na busca. p_marca_id/p_categoria_id/p_produto_ids
replicam os filtros <Select> ja existentes. SECURITY INVOKER.';

GRANT EXECUTE ON FUNCTION public.buscar_produtos_fuzzy(text, uuid, uuid, uuid[], int, int) TO authenticated;
