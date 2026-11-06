-- SPEC-253 C: dry-run da migration 293 (termina em ROLLBACK).
-- Uso: psql "$SUPABASE_DB_URL" -X -f dry_run.sql   (de dentro desta pasta)
\set ON_ERROR_STOP on
BEGIN;
\ir up.sql

SELECT id AS ped, numero, data_prevista_entrega AS antes FROM pedidos_compra WHERE status='aprovado' AND data_prevista_entrega IS NOT NULL ORDER BY numero LIMIT 1 \gset

\echo '--- 1) quem tem permissao (compradora) atualiza'
SELECT set_config('request.jwt.claims', '{"sub":"78c716d7-9ca2-4449-8ac6-50c1905d21ef","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT public.atualizar_previsao_pedido_compra(:'ped'::uuid, (:'antes'::date + 10), 'fornecedor avisou atraso (teste)');
RESET ROLE;
SELECT numero, data_prevista_entrega AS depois, status, right(observacao, 90) AS obs FROM pedidos_compra WHERE id=:'ped'::uuid;

\echo '--- 2) sem motivo: recusa'
SET LOCAL ROLE authenticated;
DO $$ BEGIN PERFORM public.atualizar_previsao_pedido_compra((SELECT id FROM pedidos_compra WHERE status='aprovado' LIMIT 1), current_date, ' ');
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'ok recusou: %', SQLERRM; END $$;
RESET ROLE;

\echo '--- 3) pedido cancelado: recusa'
SET LOCAL ROLE authenticated;
DO $$ BEGIN PERFORM public.atualizar_previsao_pedido_compra((SELECT id FROM pedidos_compra WHERE status='cancelado' LIMIT 1), current_date, 'x');
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'ok recusou: %', SQLERRM; END $$;
RESET ROLE;

\echo '--- 4) projetista sem permissao de compras: recusa'
SELECT set_config('request.jwt.claims', '{"sub":"438d37e0-ae72-4226-83c7-15d501a49dd4","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN PERFORM public.atualizar_previsao_pedido_compra((SELECT id FROM pedidos_compra WHERE status='aprovado' LIMIT 1), current_date, 'x');
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'ok recusou: %', SQLERRM; END $$;
RESET ROLE;

\echo '--- 5) anon: sem execucao'
SET LOCAL ROLE anon;
DO $$ BEGIN PERFORM public.atualizar_previsao_pedido_compra(gen_random_uuid(), current_date, 'x');
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'ok anon barrado'; END $$;
RESET ROLE;
ROLLBACK;
