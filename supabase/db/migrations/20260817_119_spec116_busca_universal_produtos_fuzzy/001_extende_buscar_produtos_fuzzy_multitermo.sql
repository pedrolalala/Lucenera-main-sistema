-- Migration 20260817_119 (SPEC-116, piloto 1 — Cadastro)
-- Estende public.buscar_produtos_fuzzy (SPEC-100) para busca universal:
--   1) inclui descricao_tecnica no casamento (nome/sku/referencia/marca/
--      categoria já cobertos; descricao_tecnica ficava de fora da RPC,
--      apesar de getProdutosEstoqueFiltradoBatched() do Cadastro já usá-la
--      no fallback client-side — ver SPEC-116).
--   2) suporta múltiplos termos em qualquer ordem (estilo Google): o termo
--      livre é quebrado em palavras por espaço e cada palavra precisa achar
--      correspondência em ALGUM campo (não necessariamente o mesmo campo)
--      para a linha entrar no resultado. Antes, "Lâmpada LED 10W" era
--      tratado como uma frase única contra cada coluna.
--
-- Assinatura da função não muda (ainda recebe p_termo como text único) —
-- quem já chama (ProductSearchModal, Orçamentos) não precisa de nenhuma
-- alteração, só passa a receber resultado mais abrangente.
--
-- Sem índice trgm dedicado, mesmo racional da migration original: produtos
-- tem ~4.7k linhas (2026-08-15), sequential scan é sub-ms nesse volume.
--
-- SECURITY INVOKER: só leitura, respeita as policies de SELECT já abertas.

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
                    p.nome ilike '%' || t.termo || '%'
                    OR p.sku ilike '%' || t.termo || '%'
                    OR p.referencia ilike '%' || t.termo || '%'
                    OR p.descricao_tecnica ilike '%' || t.termo || '%'
                    OR (t.termo ~ '^\d+$' AND p.codigo_produto = t.termo::int)
                    OR word_similarity(public.immutable_unaccent(lower(t.termo)), public.immutable_unaccent(lower(p.nome))) > 0.3
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
'SPEC-100 + SPEC-116. Busca "estilo Google" de peças: o termo livre e quebrado
em palavras por espaco; cada palavra precisa casar (substring/exato/
word_similarity(unaccent(lower(...))) > 0.3) em pelo menos um campo (nome,
sku, referencia, codigo_produto, descricao_tecnica, marca ou categoria) para
a linha entrar no resultado — nao precisa ser o mesmo campo para cada
palavra. p_marca_id/p_categoria_id/p_produto_ids replicam os filtros
<Select> ja existentes. Ordena por relevancia media dos termos desc, depois
nome. SECURITY INVOKER.';

GRANT EXECUTE ON FUNCTION public.buscar_produtos_fuzzy(text, uuid, uuid, uuid[], int, int) TO authenticated;
