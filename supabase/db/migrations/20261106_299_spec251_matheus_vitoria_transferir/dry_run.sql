-- SPEC-251: dry-run da migration 299 (ROLLBACK). Uso: psql "$SUPABASE_DB_URL" -X -f dry_run.sql (de dentro da pasta)
\set ON_ERROR_STOP on
BEGIN;

\echo '--- ANTES da migration: Matheus, Vitoria, Marina e uma pessoa sem permissao'
CREATE TEMP TABLE quem (nome text, uid uuid);
INSERT INTO quem VALUES
  ('Matheus', 'af3035fd-266b-4b3a-952b-cb8866096c49'),
  ('Vitoria', 'd875ff50-2220-48af-9ed7-0a670ec877c3'),
  ('Marina (projetista)', '438d37e0-ae72-4226-83c7-15d501a49dd4');
INSERT INTO quem SELECT 'Debora (assistente, sem permissao)', usuario_id FROM funcionarios WHERE nm_connect = 'DEBORA';
INSERT INTO quem VALUES ('Antonio (aux. estoque, sem permissao)', 'ea9ae91b-324d-4b57-acd6-0904979ea38f');
GRANT SELECT ON quem TO authenticated;

CREATE OR REPLACE FUNCTION pg_temp.quem_pode() RETURNS TABLE(nome text, pode boolean) LANGUAGE plpgsql AS $$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM quem LOOP
    PERFORM set_config('request.jwt.claims', json_build_object('sub', r.uid, 'role', 'authenticated')::text, true);
    nome := r.nome; pode := public.pode_trocar_reserva(); RETURN NEXT;
  END LOOP;
END $$;
SELECT * FROM pg_temp.quem_pode();

\ir up.sql

\echo '--- DEPOIS da migration'
SELECT * FROM pg_temp.quem_pode();
SELECT m.chave, count(e.*) AS excecoes_concedidas FROM modulos m LEFT JOIN usuario_permissao_excecoes e ON e.modulo_id = m.id
 WHERE m.chave = 'transferir_reserva' GROUP BY m.chave;

\echo '--- Vitoria faz uma transferencia de verdade (venda do sistema para venda da Connect), como no teste da SPEC-251'
SELECT d.projeto_item_id AS destino, o.projeto_item_id AS origem, d.produto_id AS prod
FROM vw_estoque_saldos_projeto_item d
JOIN vw_estoque_saldos_projeto_item o ON o.produto_id = d.produto_id AND o.projeto_item_id <> d.projeto_item_id
WHERE d.origem = 'connect' AND d.q_entrega_futura > 0 AND o.q_reserva > 0 AND o.origem = 'sistema' LIMIT 1 \gset
SELECT (SELECT q_reserva FROM estoque_saldos_projeto_item WHERE projeto_item_id = :'destino') AS d_res_antes,
       (SELECT estoque_total FROM produtos WHERE id = :'prod') AS geral_antes \gset a_
SELECT set_config('request.jwt.claims', '{"sub":"d875ff50-2220-48af-9ed7-0a670ec877c3","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT public.trocar_reserva_projetista(:'origem'::uuid, :'destino'::uuid, 1, 'teste SPEC-251 (rollback)') ->> 'status' AS status;
RESET ROLE;
SELECT set_config('t.origem', :'origem', false), set_config('t.destino', :'destino', false) \gset
SELECT (SELECT q_reserva FROM estoque_saldos_projeto_item WHERE projeto_item_id = :'destino') - :a_d_res_antes AS reserva_do_destino_subiu,
       (SELECT estoque_total FROM produtos WHERE id = :'prod') = :a_geral_antes AS estoque_geral_igual;

\echo '--- pessoa sem permissao (Antonio, auxiliar de estoque) continua barrada, na MESMA transferencia que a Vitoria fez'
SELECT set_config('request.jwt.claims', '{"sub":"ea9ae91b-324d-4b57-acd6-0904979ea38f","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  PERFORM public.trocar_reserva_projetista(current_setting('t.origem')::uuid, current_setting('t.destino')::uuid, 1, 'x');
  RAISE EXCEPTION 'passou indevidamente';
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'ok barrado: %', left(SQLERRM, 80); END $$;
RESET ROLE;

\echo '--- anon sem execucao do pode_trocar_reserva'
SET LOCAL ROLE anon;
DO $$ BEGIN PERFORM public.pode_trocar_reserva(); RAISE EXCEPTION 'anon executou';
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'ok anon barrado'; END $$;
RESET ROLE;
ROLLBACK;
