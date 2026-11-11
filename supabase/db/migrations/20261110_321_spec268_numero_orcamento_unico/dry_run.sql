-- SPEC-268: ensaio com ROLLBACK. Uso: psql "$SUPABASE_DB_URL" -X -f dry_run.sql (de dentro da pasta)
\set ON_ERROR_STOP on
BEGIN;
SELECT max(numero) AS maximo_real FROM orcamentos WHERE numero ~ '^ORC-\d+$' \gset antes_

\echo '--- antes da correção: projetista (Marina) insere sem número'
SELECT set_config('request.jwt.claims', '{"sub":"438d37e0-ae72-4226-83c7-15d501a49dd4","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
INSERT INTO orcamentos (empresa_id, digitado_por) SELECT id, '438d37e0-ae72-4226-83c7-15d501a49dd4' FROM empresas WHERE nome = 'MANOELLA' LIMIT 1 RETURNING numero;
RESET ROLE;

\ir up.sql

\echo '--- depois da correção: mesma inserção deve dar maximo_real + 1'
SELECT set_config('request.jwt.claims', '{"sub":"438d37e0-ae72-4226-83c7-15d501a49dd4","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
INSERT INTO orcamentos (empresa_id, digitado_por) SELECT id, '438d37e0-ae72-4226-83c7-15d501a49dd4' FROM empresas WHERE nome = 'MANOELLA' LIMIT 1 RETURNING numero;
RESET ROLE;
SELECT :'antes_maximo_real' AS maximo_real_antes;

\echo '--- número informado à mão continua respeitado'
INSERT INTO orcamentos (empresa_id, numero) SELECT id, 'ORC-TESTE-1' FROM empresas WHERE nome = 'MANOELLA' LIMIT 1 RETURNING numero;
\echo '--- anon sem execucao'
SET LOCAL ROLE anon;
DO $$ BEGIN PERFORM public.set_orcamento_numero(); EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'ok anon barrado'; WHEN OTHERS THEN RAISE NOTICE 'ok (recusou por outro motivo: %)', SQLERRM; END $$;
RESET ROLE;
ROLLBACK;
