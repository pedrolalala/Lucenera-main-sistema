-- Migration 20260716_049 — Parte 5 (SPEC-030 Parte 2)
-- RPC auxiliar buscar_fornecedores_fuzzy: supabase-js nao expõe um operador
-- nativo para similarity() do pg_trgm em .from(...).select(...), entao a
-- busca fuzzy de getFornecedores() (services/pedido-compra.ts) precisa
-- passar por uma RPC. Mantem o mesmo filtro ja corrigido na SPEC-030 Parte 1
-- (contato_tipos.tipo = 'fornecedor', contatos.ativo = true) e usa o
-- threshold inicial de similarity() = 0.3 definido na SPEC (nao validado
-- ainda com nomes reais de fornecedores — ver Pendencias).
--
-- Sem termo de busca (p_termo nulo/vazio): mantém o comportamento anterior
-- do ilike puro (lista todos os fornecedores ativos, ordenados por nome,
-- limit 50), para não quebrar a abertura inicial do modal de fornecedor.
--
-- SECURITY INVOKER: é só leitura e respeita as policies de SELECT já abertas
-- (authenticated) em contatos/contato_tipos — não precisa de SECURITY DEFINER.

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
        SELECT DISTINCT c.id, c.nome
        FROM public.contatos c
        JOIN public.contato_tipos ct
            ON ct.contato_id = c.id
           AND ct.tipo = 'fornecedor'
        WHERE c.ativo = true
          AND similarity(unaccent(lower(c.nome)), unaccent(lower(trim(p_termo)))) > 0.3
        ORDER BY similarity(unaccent(lower(c.nome)), unaccent(lower(trim(p_termo)))) DESC, c.nome
        LIMIT 50;
    END IF;
END;
$$;

COMMENT ON FUNCTION public.buscar_fornecedores_fuzzy(text) IS
'SPEC-030 Parte 2. Busca fornecedores (contato_tipos.tipo = fornecedor, ativo)
tolerante a erro de digitacao/acento via similarity(unaccent(lower(nome)), ...)
> 0.3 (pg_trgm + unaccent). Sem p_termo, mantem o comportamento anterior
(lista completa ordenada por nome). Usada por getFornecedores()
(services/pedido-compra.ts) via supabase.rpc(), pois supabase-js nao expõe
similarity() diretamente em .from().select(). SECURITY INVOKER.';

GRANT EXECUTE ON FUNCTION public.buscar_fornecedores_fuzzy(text) TO authenticated;
