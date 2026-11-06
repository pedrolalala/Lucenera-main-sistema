-- SPEC-250: dry-run da migration 298 (ROLLBACK). Uso: psql "$SUPABASE_DB_URL" -X -f dry_run.sql (de dentro da pasta)
\set ON_ERROR_STOP on
BEGIN;
\ir up.sql

SELECT sum(quantidade) AS geral_total, sum(quantidade_reservada) AS reservado_total FROM estoque_itens \gset antes_
SELECT (SELECT count(*) FROM transacoes) AS fin, (SELECT count(*) FROM estoque_saldos_projeto_item) AS saldos, (SELECT sum(q_reserva) FROM estoque_saldos_projeto_item) AS q_res \gset antes_
SELECT quantidade AS g_antes FROM estoque_itens WHERE local = 'Estoque' AND produto_id = (SELECT id FROM produtos WHERE codigo_produto = 12757) \gset p_

-- Matheus
SELECT set_config('request.jwt.claims', '{"sub":"af3035fd-266b-4b3a-952b-cb8866096c49","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;

\echo '--- 1) modo teste (nao grava)'
SELECT jsonb_pretty(public.limpar_reserva_sem_venda_connect('[{"codigo":12757,"quantidade":1},{"codigo":9931,"quantidade":2}]'::jsonb));
RESET ROLE;
SELECT quantidade = :p_g_antes AS geral_igual_apos_teste FROM estoque_itens WHERE local = 'Estoque' AND produto_id = (SELECT id FROM produtos WHERE codigo_produto = 12757);

SET LOCAL ROLE authenticated;
\echo '--- 2) acima da reserva sem venda: recusa (9988 tem 83; pedir 84)'
SELECT public.limpar_reserva_sem_venda_connect('[{"codigo":9988,"quantidade":84}]'::jsonb) -> 'erros' AS erros;

\echo '--- 3) tudo ou nada: uma boa e uma ruim, aplicar falha e nada muda'
DO $$ BEGIN
  PERFORM public.limpar_reserva_sem_venda_connect('[{"codigo":12757,"quantidade":1},{"codigo":9988,"quantidade":84}]'::jsonb, true, 'teste');
  RAISE EXCEPTION 'aplicou indevidamente';
EXCEPTION WHEN SQLSTATE 'P0001' THEN RAISE NOTICE 'ok recusou: %', left(SQLERRM, 60); END $$;

\echo '--- 4) sem motivo: recusa'
DO $$ BEGIN
  PERFORM public.limpar_reserva_sem_venda_connect('[{"codigo":12757,"quantidade":1}]'::jsonb, true, '  ');
  RAISE EXCEPTION 'aplicou indevidamente';
EXCEPTION WHEN SQLSTATE 'P0001' THEN RAISE NOTICE 'ok recusou: %', SQLERRM; END $$;

\echo '--- 5) aplicar de verdade (12757: 1, 9931: 2, 10614: 4)'
SELECT (public.limpar_reserva_sem_venda_connect('[{"codigo":12757,"quantidade":1},{"codigo":9931,"quantidade":2},{"codigo":10614,"quantidade":4}]'::jsonb, true, 'teste dry-run: listas de entrega de 05/11 baixadas na Connect') ->> 'aplicado') AS aplicado;
RESET ROLE;

SELECT p.codigo_produto AS codigo, e.quantidade AS geral, e.quantidade_reservada AS reservado, e.quantidade - e.quantidade_reservada AS disponivel
FROM estoque_itens e JOIN produtos p ON p.id = e.produto_id WHERE e.local = 'Estoque' AND p.codigo_produto IN (12757, 9931, 10614) ORDER BY 1;
SELECT count(*) AS movimentos_registrados FROM movimentacoes_peca WHERE origem = 'Reserva sem venda (herança Connect)';
SELECT (SELECT sum(quantidade) FROM estoque_itens) = :antes_geral_total - 7 AS geral_caiu_so_7,
       (SELECT sum(quantidade_reservada) FROM estoque_itens) = :antes_reservado_total - 7 AS reservado_caiu_so_7,
       (SELECT count(*) FROM transacoes) = :antes_fin AS financeiro_igual,
       (SELECT count(*) FROM estoque_saldos_projeto_item) = :antes_saldos AS saldos_iguais,
       (SELECT sum(q_reserva) FROM estoque_saldos_projeto_item) = :antes_q_res AS reservas_por_cliente_iguais;

\echo '--- 6) projetista (Marina): recusa'
SELECT set_config('request.jwt.claims', '{"sub":"438d37e0-ae72-4226-83c7-15d501a49dd4","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN PERFORM public.limpar_reserva_sem_venda_connect('[{"codigo":12757,"quantidade":1}]'::jsonb);
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'ok barrada: %', SQLERRM; END $$;
RESET ROLE;

\echo '--- 7) anon sem execucao'
SET LOCAL ROLE anon;
DO $$ BEGIN PERFORM public.limpar_reserva_sem_venda_connect('[{"codigo":12757,"quantidade":1}]'::jsonb);
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'ok anon barrado'; END $$;
RESET ROLE;
ROLLBACK;
