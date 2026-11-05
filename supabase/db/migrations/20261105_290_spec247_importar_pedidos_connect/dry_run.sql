-- SPEC-247: dry-run da migration 290. Tudo dentro de uma transacao que termina em ROLLBACK (nada fica gravado).
-- Uso: psql "$SUPABASE_DB_URL" -X -f dry_run.sql   (rodar de dentro desta pasta, por causa do \ir)
\set ON_ERROR_STOP on
BEGIN;
\ir up.sql

-- usuario com permissao de criar pedido (quem criou o 1993 CONNECT)
SELECT set_config('request.jwt.claims', '{"sub":"78c716d7-9ca2-4449-8ac6-50c1905d21ef","role":"authenticated"}', true);
SELECT set_config('request.jwt.claim.sub', '78c716d7-9ca2-4449-8ac6-50c1905d21ef', true);

\echo '--- contagens antes'
SELECT (SELECT count(*) FROM pedidos_compra) pedidos, (SELECT count(*) FROM pedido_compra_itens) itens,
       (SELECT count(*) FROM pedido_compra_parcelas) parcelas, (SELECT count(*) FROM transacoes) transacoes;

\echo '--- 1) previa (p_aplicar=false): esperado 99001 e 99003 novos (99003 = Stella, duplicado), 1993 e 1733 ja existem, 99002 sem fornecedor'
SET LOCAL ROLE authenticated;
SELECT jsonb_pretty(public.importar_pedidos_connect_cabecalho($j$[
  {"codigo_pedido":99001,"nm_fornecedor":"iluminar","emissao_pedido":"2026-11-05","vl_nota":100.5},
  {"codigo_pedido":99001,"nm_fornecedor":"ILUMINAR","emissao_pedido":"2026-11-05","vl_nota":100.5},
  {"codigo_pedido":1993,"nm_fornecedor":"ILUMINAR","emissao_pedido":"2026-11-05","vl_nota":66},
  {"codigo_pedido":1733,"nm_fornecedor":"GOLDEN ART INDUSTRIA E COMERCIO LTDA","emissao_pedido":"2026-07-23","vl_nota":9585.4},
  {"codigo_pedido":99002,"nm_fornecedor":"FORNECEDOR QUE NAO EXISTE XYZ","emissao_pedido":"2026-11-05","vl_nota":10},
  {"codigo_pedido":99003,"nm_fornecedor":"Stella Importação e Exportação de Luminárias Ltda","emissao_pedido":"2026-11-04","vl_nota":20}
]$j$::jsonb, false));
RESET ROLE;
SELECT count(*) AS "pedidos CONNECT 9900x apos a previa (esperado 0)" FROM pedidos_compra WHERE numero LIKE '9900_ CONNECT';

\echo '--- 2) gravando (p_aplicar=true): esperado inseridos = 2'
SET LOCAL ROLE authenticated;
SELECT public.importar_pedidos_connect_cabecalho($j$[
  {"codigo_pedido":99001,"nm_fornecedor":"iluminar","emissao_pedido":"2026-11-05","vl_nota":100.5},
  {"codigo_pedido":99003,"nm_fornecedor":"Stella Importação e Exportação de Luminárias Ltda","emissao_pedido":"2026-11-04","vl_nota":20}
]$j$::jsonb, true) ->> 'inseridos' AS inseridos;
RESET ROLE;
SELECT numero, status, valor_total, data_emissao, criado_por IS NOT NULL AS tem_criado_por, aprovado_por IS NOT NULL AS tem_aprovado_por, observacao
  FROM pedidos_compra WHERE numero LIKE '9900_ CONNECT' ORDER BY numero;

\echo '--- 3) rodar de novo: esperado inseridos = 0 (idempotente)'
SET LOCAL ROLE authenticated;
SELECT public.importar_pedidos_connect_cabecalho($j$[{"codigo_pedido":99001,"nm_fornecedor":"ILUMINAR","emissao_pedido":"2026-11-05","vl_nota":100.5}]$j$::jsonb, true) ->> 'inseridos' AS inseridos;
RESET ROLE;

\echo '--- 4) contagens depois: itens, parcelas e transacoes iguais; so pedidos +2'
SELECT (SELECT count(*) FROM pedidos_compra) pedidos, (SELECT count(*) FROM pedido_compra_itens) itens,
       (SELECT count(*) FROM pedido_compra_parcelas) parcelas, (SELECT count(*) FROM transacoes) transacoes;

\echo '--- 5) usuario SEM permissao: esperado erro 42501'
SELECT set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  PERFORM public.importar_pedidos_connect_cabecalho('[{"codigo_pedido":99009,"nm_fornecedor":"ILUMINAR","emissao_pedido":"2026-11-05","vl_nota":1}]'::jsonb, true);
  RAISE NOTICE 'FALHA: usuario sem permissao conseguiu executar';
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'OK: bloqueado (42501) - %', SQLERRM; END $$;
RESET ROLE;

\echo '--- 6) anon: esperado permission denied'
SET LOCAL ROLE anon;
DO $$ BEGIN
  PERFORM public.importar_pedidos_connect_cabecalho('[]'::jsonb, false);
  RAISE NOTICE 'FALHA: anon conseguiu executar';
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'OK: anon bloqueado - %', SQLERRM; END $$;
RESET ROLE;

\echo '--- 7) planilha invalida (valor negativo): esperado erro de linha invalida'
SELECT set_config('request.jwt.claims', '{"sub":"78c716d7-9ca2-4449-8ac6-50c1905d21ef","role":"authenticated"}', true);
SELECT set_config('request.jwt.claim.sub', '78c716d7-9ca2-4449-8ac6-50c1905d21ef', true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  PERFORM public.importar_pedidos_connect_cabecalho('[{"codigo_pedido":99010,"nm_fornecedor":"ILUMINAR","emissao_pedido":"2026-11-05","vl_nota":-5}]'::jsonb, true);
  RAISE NOTICE 'FALHA: aceitou valor negativo';
EXCEPTION WHEN raise_exception THEN RAISE NOTICE 'OK: recusou - %', SQLERRM; END $$;
RESET ROLE;

ROLLBACK;
\echo 'DRY-RUN terminado: ROLLBACK, nada foi gravado.'
