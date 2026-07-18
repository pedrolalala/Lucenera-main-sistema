-- Migration 20260718_051 — Parte 1 (SPEC-034)
-- Corrige buscar_fornecedores_fuzzy para usar word_similarity() em vez de
-- similarity() — pendência aberta desde a SPEC-030 Parte 2 e reafirmada na
-- SPEC-033: similarity() compara a STRING INTEIRA, então um termo curto
-- digitado (ex. "Stella") não bate contra um nome de fornecedor longo (ex.
-- "STELLA IMPORTACAO E EXPORTACAO DE LUMINARIAS LTDA"). word_similarity()
-- compara o termo contra a melhor substring de tamanho semelhante dentro do
-- texto mais longo — validado empiricamente na análise da SPEC-034 (109
-- marcas x fornecedores ativos).
--
-- O índice idx_contatos_nome_unaccent_trgm (GIN, gin_trgm_ops sobre
-- immutable_unaccent(lower(nome))) continua servindo de suporte — índices
-- GIN trgm dão suporte tanto a similarity quanto a word_similarity.
--
-- Threshold mantido em 0.3 (mesmo valor da versão anterior) como ponto de
-- partida — não validado ainda com buscas reais usando word_similarity(),
-- que tende a gerar scores mais altos para correspondências genuínas de
-- termo curto. Ver Pendências da SPEC-034 para ajuste empírico pós-deploy.

CREATE OR REPLACE FUNCTION public.buscar_fornecedores_fuzzy(
    p_termo  text DEFAULT NULL
) RETURNS TABLE (
    id    uuid,
    nome  text
)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
BEGIN
    IF p_termo IS NULL OR trim(p_termo) = '' THEN
        RETURN QUERY
        SELECT DISTINCT c.id, c.nome
        FROM public.contatos c
        JOIN public.contato_tipos ct
            ON ct.contato_id = c.id
           AND ct.tipo = 'fornecedor'
        WHERE c.ativo = true
        ORDER BY c.nome
        LIMIT 50;
    ELSE
        RETURN QUERY
        SELECT sub.id, sub.nome
        FROM (
            SELECT DISTINCT
                c.id,
                c.nome,
                word_similarity(
                    public.immutable_unaccent(lower(trim(p_termo))),
                    public.immutable_unaccent(lower(c.nome))
                ) AS sim
            FROM public.contatos c
            JOIN public.contato_tipos ct
                ON ct.contato_id = c.id
               AND ct.tipo = 'fornecedor'
            WHERE c.ativo = true
              AND word_similarity(
                    public.immutable_unaccent(lower(trim(p_termo))),
                    public.immutable_unaccent(lower(c.nome))
                  ) > 0.3
        ) sub
        ORDER BY sub.sim DESC, sub.nome
        LIMIT 50;
    END IF;
END;
$$;

COMMENT ON FUNCTION public.buscar_fornecedores_fuzzy(text) IS
'SPEC-034 (corrige pendência da SPEC-030 Parte 2 / SPEC-033). Busca
fornecedores (contato_tipos.tipo = fornecedor, ativo) tolerante a erro de
digitação/acento via word_similarity(unaccent(lower(termo)),
unaccent(lower(nome))) > 0.3 — compara o termo contra a melhor substring do
nome, ao contrário de similarity() (string inteira), que falhava para termos
curtos contra nomes de fornecedor longos. Sem p_termo, mantém o comportamento
anterior (lista completa ordenada por nome). Usada por getFornecedores()
(services/pedido-compra.ts) e pela edição manual/sugestão em Marcas.tsx via
supabase.rpc(). SECURITY INVOKER.';
