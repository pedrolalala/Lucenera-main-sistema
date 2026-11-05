-- SPEC-247 fase 2: dry-run da migration 291. Tudo numa transacao que termina em ROLLBACK (nada fica gravado).
-- Uso: psql "$SUPABASE_DB_URL" -X -f dry_run.sql   (rodar de dentro desta pasta, por causa do \ir)
\set ON_ERROR_STOP on
BEGIN;
\ir up.sql

SELECT set_config('request.jwt.claims', '{"sub":"78c716d7-9ca2-4449-8ac6-50c1905d21ef","role":"authenticated"}', true) \gset
SELECT set_config('request.jwt.claim.sub', '78c716d7-9ca2-4449-8ac6-50c1905d21ef', true) \gset

\echo '--- contagens antes'
SELECT (SELECT count(*) FROM pedidos_compra) pedidos, (SELECT count(*) FROM pedido_compra_itens) itens,
       (SELECT count(*) FROM pedido_compra_parcelas) parcelas, (SELECT count(*) FROM transacoes) transacoes;

SET LOCAL ROLE authenticated;

\echo '--- 1) previa de pedido NOVO (1743, Stella, FOCO): esperado acao=criar, aplicado=false, nada gravado'
SELECT jsonb_pretty(public.importar_pedido_connect_pdf($j${
  "numero":1743,"fornecedor":"STELLA IMPORTACAO E EXPORTACAO DE LUMINARIAS LTDA","empresa":"FOCO ILUMINACAO",
  "emissao":"2026-07-23","entrega":"2026-07-31","pagamento":"BOLETO 10X","total":5568.95,
  "itens":[{"codigo_produto":9801,"referencia":"STH8541-27","quantidade":200,"valor_unitario":27.42},
           {"codigo_produto":10941,"referencia":"STL21700BR/30","quantidade":1,"valor_unitario":84.95}]}$j$::jsonb, false));
RESET ROLE;
SELECT count(*) AS "pedido 1743 CONNECT apos a previa (esperado 0)" FROM pedidos_compra WHERE numero = '1743 CONNECT';

\echo '--- 2) gravando o 1743: esperado itens_inseridos=2, pedido aprovado, valor 5568.95, empresa FOCO'
SET LOCAL ROLE authenticated;
SELECT r ->> 'acao' AS acao, r ->> 'itens_inseridos' AS itens_inseridos, r ->> 'aplicado' AS aplicado
  FROM (SELECT public.importar_pedido_connect_pdf($j${
  "numero":1743,"fornecedor":"STELLA IMPORTACAO E EXPORTACAO DE LUMINARIAS LTDA","empresa":"FOCO ILUMINACAO",
  "emissao":"2026-07-23","entrega":"2026-07-31","pagamento":"BOLETO 10X","total":5568.95,
  "itens":[{"codigo_produto":9801,"referencia":"STH8541-27","quantidade":200,"valor_unitario":27.42},
           {"codigo_produto":10941,"referencia":"STL21700BR/30","quantidade":1,"valor_unitario":84.95}]}$j$::jsonb, true) r) x;
RESET ROLE;
SELECT p.numero, p.status, p.valor_total, p.data_prevista_entrega, p.condicoes_pagamento, e.nome AS empresa,
       (SELECT count(*) FROM pedido_compra_itens i WHERE i.pedido_id = p.id) AS itens
  FROM pedidos_compra p LEFT JOIN empresas e ON e.id = p.empresa_id WHERE p.numero = '1743 CONNECT';

\echo '--- 3) de novo o mesmo: esperado acao=ja_tem_itens, bloqueado=true, 0 inseridos'
SET LOCAL ROLE authenticated;
SELECT r ->> 'acao' AS acao, r ->> 'bloqueado' AS bloqueado, r ->> 'itens_inseridos' AS itens_inseridos
  FROM (SELECT public.importar_pedido_connect_pdf($j${"numero":1743,"fornecedor":"STELLA IMPORTACAO E EXPORTACAO DE LUMINARIAS LTDA",
  "emissao":"2026-07-23","total":84.95,"itens":[{"codigo_produto":10941,"quantidade":1,"valor_unitario":84.95}]}$j$::jsonb, true) r) x;
RESET ROLE;

\echo '--- 4) completar pedido da planilha SEM itens (1733 CONNECT): esperado acao=completar, 1 item, valor do pedido NAO muda'
SELECT valor_total AS valor_antes FROM pedidos_compra WHERE numero = '1733 CONNECT' \gset
SET LOCAL ROLE authenticated;
SELECT r ->> 'acao' AS acao, r ->> 'itens_inseridos' AS itens_inseridos, jsonb_pretty(r -> 'avisos') AS avisos
  FROM (SELECT public.importar_pedido_connect_pdf($j${"numero":1733,"fornecedor":"GOLDEN ART INDUSTRIA E COMERCIO LTDA","empresa":"FOCO ILUMINACAO",
  "emissao":"2026-07-23","entrega":"2026-08-10","pagamento":"BOLETO 03X","total":1025.29,
  "itens":[{"codigo_produto":10316,"referencia":"4022-01","quantidade":4.1,"valor_unitario":250.07}]}$j$::jsonb, true) r) x;
RESET ROLE;
SELECT numero, valor_total, :'valor_antes'::numeric AS valor_antes, data_prevista_entrega, condicoes_pagamento,
       (SELECT count(*) FROM pedido_compra_itens i WHERE i.pedido_id = pedidos_compra.id) AS itens
  FROM pedidos_compra WHERE numero = '1733 CONNECT';

\echo '--- 5) peca nao cadastrada (99999): esperado bloqueado=true, pecas_nao_cadastradas=[99999], NADA gravado'
SET LOCAL ROLE authenticated;
SELECT r ->> 'bloqueado' AS bloqueado, r ->> 'aplicado' AS aplicado, r -> 'pecas_nao_cadastradas' AS faltam
  FROM (SELECT public.importar_pedido_connect_pdf($j${"numero":99001,"fornecedor":"ILUMINAR","emissao":"2026-11-05","total":20,
  "itens":[{"codigo_produto":10316,"quantidade":1,"valor_unitario":10},{"codigo_produto":99999,"referencia":"XX","quantidade":1,"valor_unitario":10}]}$j$::jsonb, true) r) x;
RESET ROLE;
SELECT count(*) AS "pedido 99001 CONNECT (esperado 0)" FROM pedidos_compra WHERE numero = '99001 CONNECT';

\echo '--- 6) fornecedor sem cadastro: esperado acao=sem_fornecedor, bloqueado=true'
SET LOCAL ROLE authenticated;
SELECT r ->> 'acao' AS acao, r ->> 'bloqueado' AS bloqueado
  FROM (SELECT public.importar_pedido_connect_pdf($j${"numero":99002,"fornecedor":"FORNECEDOR QUE NAO EXISTE XYZ","emissao":"2026-11-05","total":10,
  "itens":[{"codigo_produto":10316,"quantidade":1,"valor_unitario":10}]}$j$::jsonb, true) r) x;

\echo '--- 7) pedido que ja tem itens (1993 CONNECT): esperado acao=ja_tem_itens'
SELECT r ->> 'acao' AS acao, r ->> 'bloqueado' AS bloqueado
  FROM (SELECT public.importar_pedido_connect_pdf($j${"numero":1993,"fornecedor":"X","emissao":"2026-11-05","total":10,
  "itens":[{"codigo_produto":10316,"quantidade":1,"valor_unitario":10}]}$j$::jsonb, true) r) x;

\echo '--- 8) soma dos itens diferente do total: esperado aviso (nao bloqueia)'
SELECT r -> 'avisos' AS avisos FROM (SELECT public.importar_pedido_connect_pdf($j${"numero":99003,"fornecedor":"ILUMINAR","emissao":"2026-11-05","total":999,
  "itens":[{"codigo_produto":10316,"quantidade":1,"valor_unitario":10}]}$j$::jsonb, false) r) x;
RESET ROLE;

\echo '--- 9) contagens depois: parcelas e transacoes iguais; itens +3 (2 do 1743 + 1 do 1733); pedidos +1'
SELECT (SELECT count(*) FROM pedidos_compra) pedidos, (SELECT count(*) FROM pedido_compra_itens) itens,
       (SELECT count(*) FROM pedido_compra_parcelas) parcelas, (SELECT count(*) FROM transacoes) transacoes;

\echo '--- 10) usuario SEM permissao: esperado 42501'
SELECT set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}', true) \gset
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true) \gset
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  PERFORM public.importar_pedido_connect_pdf('{"numero":1,"fornecedor":"X","emissao":"2026-11-05","itens":[{"codigo_produto":1,"quantidade":1,"valor_unitario":1}]}'::jsonb, true);
  RAISE NOTICE 'FALHA: usuario sem permissao conseguiu executar';
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'OK: bloqueado (42501) - %', SQLERRM; END $$;
RESET ROLE;

\echo '--- 11) anon: esperado permission denied'
SET LOCAL ROLE anon;
DO $$ BEGIN
  PERFORM public.importar_pedido_connect_pdf('{}'::jsonb, false);
  RAISE NOTICE 'FALHA: anon conseguiu executar';
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'OK: anon bloqueado - %', SQLERRM; END $$;
RESET ROLE;

ROLLBACK;
\echo 'DRY-RUN terminado: ROLLBACK, nada foi gravado.'
