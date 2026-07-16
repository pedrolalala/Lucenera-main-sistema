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

CREATE INDEX IF NOT EXISTS idx_contatos_nome_unaccent_trgm
    ON public.contatos
    USING gin (unaccent(lower(nome)) extensions.gin_trgm_ops);

COMMENT ON INDEX public.idx_contatos_nome_unaccent_trgm IS
'SPEC-030 Parte 2. Suporte a busca fuzzy de fornecedor (similarity sobre
unaccent(lower(nome))) em buscar_fornecedores_fuzzy() — ver 005 desta pasta.';
