-- SPEC-253: dry-run da migration 292 (termina em ROLLBACK; nada fica gravado).
-- Uso: psql "$SUPABASE_DB_URL" -X -f dry_run.sql   (de dentro desta pasta, por causa do \ir)
\set ON_ERROR_STOP on
BEGIN;
\ir up.sql

\echo '--- linhas da view (como dono)'
SELECT count(*) linhas, count(data_prevista_entrega) com_data, count(DISTINCT produto_id) pecas FROM public.vw_previsao_chegada_produto;

\echo '--- anon NAO enxerga'
SET LOCAL ROLE anon;
DO $$ BEGIN PERFORM 1 FROM public.vw_previsao_chegada_produto LIMIT 1; RAISE EXCEPTION 'anon conseguiu ler'; EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'ok: anon barrado'; END $$;
RESET ROLE;

\echo '--- authenticated enxerga'
SELECT set_config('request.jwt.claims', '{"sub":"438d37e0-ae72-4226-83c7-15d501a49dd4","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT count(*) linhas FROM public.vw_previsao_chegada_produto;
RESET ROLE;

\echo '--- amostra'
SELECT pedido_numero, pedido_status, data_prevista_entrega, qtd_pendente, projeto_id IS NOT NULL AS tem_projeto
FROM public.vw_previsao_chegada_produto ORDER BY data_prevista_entrega NULLS LAST LIMIT 6;
ROLLBACK;
