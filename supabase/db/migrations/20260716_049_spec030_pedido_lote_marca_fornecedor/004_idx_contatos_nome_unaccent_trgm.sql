-- Migration 20260716_049 — Parte 4 (SPEC-030 Parte 2)
-- Indice fuzzy para busca de fornecedor tolerante a erro de digitacao/acento.
-- Extensoes pg_trgm e unaccent ja habilitadas no banco (evidencia: indice
-- idx_contatos_nome_trgm e uso de unaccent() em fn_sync_equipe_por_responsavel())
-- — nao precisa CREATE EXTENSION.
--
-- gin_trgm_ops e qualificado com o schema "extensions" para bater com o
-- padrao ja usado em idx_contatos_nome_trgm (db/current/01_schema_full.sql,
-- linha ~9042: "USING gin (nome extensions.gin_trgm_ops)"), evidencia de que
-- pg_trgm foi instalada nesse schema neste banco.
--
-- BUG encontrado ao aplicar no Supabase real (2026-07-17): a versao original
-- desta migration usava `unaccent(lower(nome))` direto na expressao do
-- indice e falhava com "functions in index expression must be marked
-- IMMUTABLE" — a funcao public.unaccent(text) instalada pela extensao e
-- STABLE (provolatile = 's'), nao IMMUTABLE, porque em teoria depende do
-- dicionario de unaccent passado. Corrigido criando um wrapper IMMUTABLE que
-- fixa o dicionario em 'public.unaccent' (o unico instalado neste banco),
-- tornando o resultado deterministico para uso em indice. O mesmo wrapper
-- deve ser usado em 005_rpc_buscar_fornecedores_fuzzy.sql para o indice ser
-- de fato utilizado pelo planner (expressao tem que bater).

CREATE OR REPLACE FUNCTION public.immutable_unaccent(text)
    RETURNS text
    LANGUAGE sql
    IMMUTABLE
    PARALLEL SAFE
    STRICT
AS $$
    SELECT public.unaccent('public.unaccent'::regdictionary, $1)
$$;

COMMENT ON FUNCTION public.immutable_unaccent(text) IS
'SPEC-030 Parte 2. Wrapper IMMUTABLE sobre public.unaccent(regdictionary, text)
(que e apenas STABLE), fixando o dicionario "public.unaccent" — necessario
porque indices de expressao no Postgres exigem funcoes IMMUTABLE. Usado pelo
indice idx_contatos_nome_unaccent_trgm e pela RPC buscar_fornecedores_fuzzy.';

CREATE INDEX IF NOT EXISTS idx_contatos_nome_unaccent_trgm
    ON public.contatos
    USING gin (public.immutable_unaccent(lower(nome)) extensions.gin_trgm_ops);

COMMENT ON INDEX public.idx_contatos_nome_unaccent_trgm IS
'SPEC-030 Parte 2. Suporte a busca fuzzy de fornecedor (similarity sobre
immutable_unaccent(lower(nome))) em buscar_fornecedores_fuzzy() — ver 005
desta pasta.';
