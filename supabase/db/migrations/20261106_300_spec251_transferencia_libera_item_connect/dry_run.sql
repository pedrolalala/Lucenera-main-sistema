-- SPEC-251: dry-run da migration 300 (ROLLBACK). Uso: psql "$SUPABASE_DB_URL" -X -f dry_run.sql (de dentro da pasta)
\set ON_ERROR_STOP on
BEGIN;

-- destino: item de venda da Connect só com Entrega Futura (não liberado hoje); origem: reserva do sistema da mesma peça
SELECT d.projeto_item_id AS destino, o.projeto_item_id AS origem
FROM vw_estoque_saldos_projeto_item d
JOIN vw_estoque_saldos_projeto_item o ON o.produto_id = d.produto_id AND o.projeto_item_id <> d.projeto_item_id
WHERE d.origem = 'connect' AND d.q_entrega_futura > 0 AND d.q_reserva = 0 AND o.q_reserva > 0 AND o.origem = 'sistema'
  AND NOT connect_item_liberado(d.projeto_item_id) LIMIT 1 \gset
SELECT count(*) AS liberados_antes FROM vw_estoque_saldos_projeto_item v WHERE v.origem = 'connect' AND connect_item_liberado(v.projeto_item_id) \gset

\ir up.sql

\echo '--- 1) antes da transferencia o destino continua nao liberado'
SELECT connect_item_liberado(:'destino') AS destino_liberado;

\echo '--- 2) Marina transfere 1 un. para o item da Connect'
SELECT set_config('request.jwt.claims', '{"sub":"438d37e0-ae72-4226-83c7-15d501a49dd4","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT public.trocar_reserva_projetista(:'origem'::uuid, :'destino'::uuid, 1, 'teste SPEC-251 (rollback)') ->> 'status' AS status;
RESET ROLE;

\echo '--- 3) agora o destino esta liberado e so ele (nenhum outro item mudou)'
SELECT connect_item_liberado(:'destino') AS destino_liberado;
SELECT (SELECT count(*) FROM vw_estoque_saldos_projeto_item v WHERE v.origem = 'connect' AND connect_item_liberado(v.projeto_item_id)) - :liberados_antes AS itens_novos_liberados;

\echo '--- 4) Marina separa a unidade recebida: a trava da SPEC-244 deixa passar'
SELECT set_config('request.jwt.claims', '{"sub":"438d37e0-ae72-4226-83c7-15d501a49dd4","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT public.registrar_separacao_setor(:'destino'::uuid, 1, NULL, 'teste SPEC-251 (rollback)') IS NOT NULL AS separou;
RESET ROLE;
SELECT q_reserva, q_ag_separar FROM estoque_saldos_projeto_item WHERE projeto_item_id = :'destino';

\echo '--- 5) item da Connect que NAO recebeu transferencia e tem Reserva com data continua recusado'
SELECT s.projeto_item_id AS bloqueado FROM vw_estoque_saldos_projeto_item s
 WHERE s.origem = 'connect' AND s.q_reserva > 0 AND NOT connect_item_liberado(s.projeto_item_id) LIMIT 1 \gset
SELECT set_config('t.bloqueado', :'bloqueado', false) \gset
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  PERFORM public.registrar_separacao_setor(current_setting('t.bloqueado')::uuid, 1, NULL, 'x');
  RAISE EXCEPTION 'separou item bloqueado';
EXCEPTION WHEN SQLSTATE 'P0001' THEN RAISE NOTICE 'ok recusou: %', left(SQLERRM, 80); END $$;
RESET ROLE;
ROLLBACK;
