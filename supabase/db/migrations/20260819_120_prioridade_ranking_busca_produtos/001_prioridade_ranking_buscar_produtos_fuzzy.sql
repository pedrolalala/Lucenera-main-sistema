-- Migration 20260819_120
-- Pedido do usuario: a ordem dos resultados de public.buscar_produtos_fuzzy
-- (usada em Cadastro > Pecas.tsx e no ProductSearchModal de Orcamentos)
-- deve seguir a prioridade Codigo > Referencia > Marca > Descricao — hoje
-- todo campo que bate (nome/sku/referencia/marca/categoria/descricao_tecnica)
-- contribui igualmente pra relevancia media, sem hierarquia nenhuma.
--
-- Nao muda QUAIS produtos aparecem (o WHERE/NOT EXISTS que decide se uma
-- linha entra no resultado continua igual) — so muda a pontuacao usada no
-- ORDER BY. SKU fica no mesmo nivel de Referencia (a propria UI mostra
-- "p.referencia || p.sku" na mesma coluna). Categoria e descricao_tecnica
-- (nao pedidos pelo usuario) ficam no nivel mais baixo, so como
-- desempate — continuam entrando na busca, so nao tem prioridade.
--
-- Preco/estoque nunca entraram na busca (nem antes desta migration) — o
-- pedido de "sem filtrar por preco ou estoque" ja estava atendido.
--
-- Assinatura da funcao nao muda.

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
                        -- Tier 5: Codigo (match exato do numero)
                        CASE WHEN t.termo ~ '^\d+$' AND p.codigo_produto = t.termo::int THEN 5.0 ELSE 0 END,
                        -- Tier 4: Referencia / SKU (mesma coluna na UI)
                        CASE WHEN p.referencia ilike '%' || t.termo || '%' THEN 4.0 ELSE 0 END,
                        CASE WHEN p.sku ilike '%' || t.termo || '%' THEN 4.0 ELSE 0 END,
                        -- Tier 3: Marca
                        CASE WHEN coalesce(m.nome, '') ilike '%' || t.termo || '%'
                                  OR word_similarity(public.immutable_unaccent(lower(t.termo)), public.immutable_unaccent(lower(coalesce(m.nome, '')))) > 0.3
                             THEN 3.0 ELSE 0 END,
                        -- Tier 2: Descricao (nome do produto)
                        CASE WHEN p.nome ilike '%' || t.termo || '%'
                                  OR word_similarity(public.immutable_unaccent(lower(t.termo)), public.immutable_unaccent(lower(p.nome))) > 0.3
                             THEN 2.0 ELSE 0 END,
                        -- Tier 1: campos que continuam na busca mas sem prioridade pedida (categoria, descricao tecnica)
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
'SPEC-100 + SPEC-116 + prioridade de ranking (2026-08-19). Busca "estilo
Google" de pecas: o termo livre e quebrado em palavras por espaco; cada
palavra precisa casar (substring/exato/word_similarity(unaccent(lower(...)))
> 0.3) em pelo menos um campo (nome, sku, referencia, codigo_produto,
descricao_tecnica, marca ou categoria) para a linha entrar no resultado —
nao precisa ser o mesmo campo para cada palavra. Ranking prioriza, nessa
ordem: Codigo > Referencia/SKU > Marca > Descricao (nome) > categoria/
descricao_tecnica (desempate). Preco e estoque nunca entram na busca.
p_marca_id/p_categoria_id/p_produto_ids replicam os filtros <Select> ja
existentes. SECURITY INVOKER.';

GRANT EXECUTE ON FUNCTION public.buscar_produtos_fuzzy(text, uuid, uuid, uuid[], int, int) TO authenticated;
