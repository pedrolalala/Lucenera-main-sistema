-- SPEC-248 item 3: dry-run da migration 301 (ROLLBACK). Uso: psql "$SUPABASE_DB_URL" -X -f dry_run.sql (de dentro da pasta)
\set ON_ERROR_STOP on
BEGIN;

-- Filippo (admin) enxerga o financeiro; usado como usuário do teste
SELECT u.id AS adm FROM usuarios u WHERE u.role = 'admin' ORDER BY u.id LIMIT 1 \gset
SELECT set_config('request.jwt.claims', json_build_object('sub', :'adm', 'role', 'authenticated')::text, true);

SET LOCAL ROLE authenticated;
SELECT count(*) AS linhas_antes, sum(vl_parcela) AS soma_antes FROM v_financeiro_realizado \gset v_
RESET ROLE;
SELECT count(*) AS colunas_antes FROM information_schema.columns WHERE table_name = 'v_financeiro_realizado' \gset v_

\ir up.sql

\echo '--- 1) a view ganhou 1 coluna (previsao) no fim e nada mudou nas linhas/valores'
SELECT count(*) - :v_colunas_antes AS colunas_novas, (array_agg(column_name ORDER BY ordinal_position))[count(*)] AS ultima_coluna
  FROM information_schema.columns WHERE table_name = 'v_financeiro_realizado';
SET LOCAL ROLE authenticated;
SELECT count(*) = :v_linhas_antes AS mesmas_linhas, sum(vl_parcela) = :v_soma_antes AS mesma_soma, count(*) FILTER (WHERE previsao) AS ja_previsao FROM v_financeiro_realizado;
RESET ROLE;

\echo '--- 2) marcar 3 parcelas em aberto como previsao'
SELECT array_agg(id) AS ids FROM (SELECT id FROM transacoes WHERE status_pago = 0 AND tipo = 'despesa' ORDER BY dt_vencimento DESC LIMIT 3) x \gset
SET LOCAL ROLE authenticated;
SELECT public.definir_previsao_transacoes(:'ids'::uuid[], true, 'teste');
SELECT count(*) AS previsao_na_view FROM v_financeiro_realizado WHERE previsao;
RESET ROLE;

\echo '--- 3) paga uma delas: deixa de aparecer como previsao na view, mesmo com a marca ligada'
UPDATE transacoes SET status_pago = 1, dt_pagamento = current_date, vl_pago = vl_parcela WHERE id = (:'ids'::uuid[])[1];
SET LOCAL ROLE authenticated;
SELECT count(*) AS previsao_na_view_depois_de_pagar FROM v_financeiro_realizado WHERE previsao;
RESET ROLE;

\echo '--- 4) firmar a conta (desmarcar): volta a ser conta firme'
SET LOCAL ROLE authenticated;
SELECT public.definir_previsao_transacoes(ARRAY[(:'ids'::uuid[])[2]], false);
SELECT count(*) AS previsao_na_view_depois_de_firmar FROM v_financeiro_realizado WHERE previsao;
\echo '--- 5) parcela PAGA nao pode ser marcada como previsao (recusa)'
DO $$ BEGIN
  PERFORM public.definir_previsao_transacoes(ARRAY[(SELECT id FROM public.transacoes WHERE status_pago = 1 LIMIT 1)], true);
  RAISE EXCEPTION 'marcou parcela paga';
EXCEPTION WHEN SQLSTATE 'P0001' THEN RAISE NOTICE 'ok recusou: %', SQLERRM; END $$;
RESET ROLE;

\echo '--- 6) usuario sem acesso ao financeiro (Antonio, auxiliar de estoque): recusa'
SELECT set_config('request.jwt.claims', '{"sub":"ea9ae91b-324d-4b57-acd6-0904979ea38f","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  PERFORM public.definir_previsao_transacoes(ARRAY[gen_random_uuid()], true);
  RAISE EXCEPTION 'passou indevidamente';
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'ok barrado: %', SQLERRM; END $$;
RESET ROLE;

\echo '--- 7) anon sem execucao'
SET LOCAL ROLE anon;
DO $$ BEGIN PERFORM public.definir_previsao_transacoes(ARRAY[gen_random_uuid()], true); RAISE EXCEPTION 'anon executou';
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'ok anon barrado'; END $$;
RESET ROLE;
ROLLBACK;
