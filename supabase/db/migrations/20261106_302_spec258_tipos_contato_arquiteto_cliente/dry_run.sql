-- SPEC-258 correção 1: dry-run da migration 302 (termina em ROLLBACK, nada fica gravado).
-- Uso: psql "$SUPABASE_DB_URL" -X -f dry_run.sql (de dentro da pasta)
\set ON_ERROR_STOP on
BEGIN;
CREATE TEMP TABLE _antes ON COMMIT DROP AS
SELECT (SELECT md5(string_agg(t::text, '|' ORDER BY id)) FROM vw_financeiro_projetos t) AS fin,
       (SELECT md5(string_agg(t::text, '|' ORDER BY id)) FROM vw_projetos_pipeline t) AS pipe;

\ir up.sql

-- 1) views: com 1 tipo por contato o resultado tem de ser IDÊNTICO
SELECT (SELECT fin FROM _antes) = (SELECT md5(string_agg(t::text, '|' ORDER BY id)) FROM vw_financeiro_projetos t) AS fin_igual,
       (SELECT pipe FROM _antes) = (SELECT md5(string_agg(t::text, '|' ORDER BY id)) FROM vw_projetos_pipeline t) AS pipe_igual;

-- 2) gatilho: arquiteto que é cliente de um orçamento continua arquiteto e ganha 'cliente' em contato_tipos
UPDATE orcamentos o SET cliente_id = o.cliente_id
  FROM contatos c WHERE c.id = o.cliente_id AND c.tipo = 'arquiteto';
SELECT count(*) FILTER (WHERE c.tipo = 'arquiteto') AS continuam_arquiteto,
       count(*) FILTER (WHERE EXISTS (SELECT 1 FROM contato_tipos ct WHERE ct.contato_id = c.id AND ct.tipo_id = 1)) AS com_tipo_cliente
  FROM contatos c WHERE c.id IN (SELECT cliente_id FROM orcamentos) AND c.tipo_principal_id = 2;
ROLLBACK;
