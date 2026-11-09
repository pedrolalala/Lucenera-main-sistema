-- SPEC-267: ensaio com ROLLBACK. Uso: psql "$SUPABASE_DB_URL" -X -f dry_run.sql (de dentro da pasta)
\set ON_ERROR_STOP on
BEGIN;
\ir up.sql

SELECT sum(quantidade) AS geral, sum(quantidade_reservada) AS reservado FROM estoque_itens \gset antes_
SELECT (SELECT count(*) FROM transacoes) AS fin, (SELECT sum(q_reserva) FROM estoque_saldos_projeto_item) AS q_res,
       (SELECT sum(q_ag_separar) FROM estoque_saldos_projeto_item) AS q_ag \gset antes_

\echo '--- antes: 4907/4908 liberados?'
SELECT r.cod_venda_connect, r.produto_codigo, public.connect_item_liberado(r.projeto_item_id) AS liberado
  FROM connect_reserva_ambiente r WHERE r.tipo = 'reserva' AND r.cod_venda_connect IN (4907, 4908) ORDER BY 1, 2;

-- Matheus
SELECT set_config('request.jwt.claims', '{"sub":"af3035fd-266b-4b3a-952b-cb8866096c49","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
\echo '--- 1) modo teste (nao grava)'
SELECT jsonb_pretty(public.liberar_vendas_connect(ARRAY[4907, 4908], NULL));
\echo '--- 2) sem motivo: recusa'
DO $$ BEGIN PERFORM public.liberar_vendas_connect(ARRAY[4907, 4908], '  ', true); RAISE EXCEPTION 'aplicou indevidamente';
EXCEPTION WHEN SQLSTATE 'P0001' THEN RAISE NOTICE 'ok recusou: %', SQLERRM; END $$;
\echo '--- 3) aplicar'
SELECT public.liberar_vendas_connect(ARRAY[4907, 4908], 'Entrega das vendas 4907/4908: equipe de projetos precisa pedir a separacao', true) ->> 'aplicado';
RESET ROLE;

\echo '--- depois: devem ser 4 x true'
SELECT r.cod_venda_connect, r.produto_codigo, public.connect_item_liberado(r.projeto_item_id) AS liberado
  FROM connect_reserva_ambiente r WHERE r.tipo = 'reserva' AND r.cod_venda_connect IN (4907, 4908) ORDER BY 1, 2;
SELECT (SELECT sum(quantidade) FROM estoque_itens) = :antes_geral AS geral_igual,
       (SELECT sum(quantidade_reservada) FROM estoque_itens) = :antes_reservado AS reservado_igual,
       (SELECT count(*) FROM transacoes) = :antes_fin AS financeiro_igual,
       (SELECT sum(q_reserva) FROM estoque_saldos_projeto_item) = :antes_q_res AS reserva_igual,
       (SELECT sum(q_ag_separar) FROM estoque_saldos_projeto_item) = :antes_q_ag AS ag_separar_igual;

\echo '--- 4) projetista (Marina): recusa'
SELECT set_config('request.jwt.claims', '{"sub":"438d37e0-ae72-4226-83c7-15d501a49dd4","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN PERFORM public.liberar_vendas_connect(ARRAY[4907], 'x', true);
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'ok barrada: %', SQLERRM; END $$;
RESET ROLE;
\echo '--- 5) anon sem execucao'
SET LOCAL ROLE anon;
DO $$ BEGIN PERFORM public.liberar_vendas_connect(ARRAY[4907], 'x', true);
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'ok anon barrado'; END $$;
RESET ROLE;
ROLLBACK;
