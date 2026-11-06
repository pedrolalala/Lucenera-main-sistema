-- SPEC-254: dry-run da migration 294 (termina em ROLLBACK). Uso: psql "$SUPABASE_DB_URL" -X -f dry_run.sql (de dentro da pasta)
\set ON_ERROR_STOP on
BEGIN;
\ir up.sql

-- Marina (projetista, equipe restrita): descobre a equipe dela
SELECT set_config('request.jwt.claims', '{"sub":"438d37e0-ae72-4226-83c7-15d501a49dd4","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT public.orcamentos_equipe_restrita() AS eq_marina \gset
RESET ROLE;
\echo '--- equipe da Marina:' :eq_marina

SELECT id AS orc_minha FROM orcamentos WHERE equipe_id = :'eq_marina'::uuid LIMIT 1 \gset
SELECT id AS orc_outra FROM orcamentos WHERE equipe_id IS DISTINCT FROM :'eq_marina'::uuid LIMIT 1 \gset
SELECT set_config('t.outra', :'orc_outra', false) \gset
\echo '--- orcamento da equipe dela:' :orc_minha ' | de outra equipe:' :orc_outra

-- um anexo de OUTRA equipe, criado pelo dono, para testar que a Marina não o enxerga
INSERT INTO orcamento_anexos (orcamento_id, nome_arquivo, caminho, criado_por)
VALUES (:'orc_outra'::uuid, 'outra.pdf', :'orc_outra' || '/outra.pdf', '78c716d7-9ca2-4449-8ac6-50c1905d21ef');

SET LOCAL ROLE authenticated;
\echo '--- 1) Marina anexa no orcamento da equipe dela: deve passar'
INSERT INTO orcamento_anexos (orcamento_id, nome_arquivo, caminho, tipo_mime, tamanho_bytes)
VALUES (:'orc_minha'::uuid, 'pix.pdf', :'orc_minha' || '/pix.pdf', 'application/pdf', 1000);
\echo '--- 2) Marina anexa no orcamento de OUTRA equipe: deve ser barrada'
DO $$ BEGIN
  INSERT INTO orcamento_anexos (orcamento_id, nome_arquivo, caminho) VALUES (current_setting('t.outra')::uuid, 'x.pdf', current_setting('t.outra') || '/x.pdf');
  RAISE EXCEPTION 'passou indevidamente';
EXCEPTION WHEN insufficient_privilege OR check_violation THEN RAISE NOTICE 'ok barrado'; END $$;
\echo '--- 3) Marina enxerga so os anexos da equipe dela'
SELECT count(*) AS vistos_da_outra_equipe FROM orcamento_anexos WHERE orcamento_id = :'orc_outra'::uuid;
SELECT count(*) AS vistos_da_minha FROM orcamento_anexos WHERE orcamento_id = :'orc_minha'::uuid;
\echo '--- 4) storage: caminho do orcamento dela passa; da outra equipe, nao'
SELECT public.orcamento_anexo_pode_acessar(:'orc_minha' || '/a.pdf', true) AS minha_escreve,
       public.orcamento_anexo_pode_acessar(:'orc_outra' || '/a.pdf', true) AS outra_escreve,
       public.orcamento_anexo_pode_acessar(:'orc_outra' || '/a.pdf', false) AS outra_le,
       public.orcamento_anexo_pode_acessar('nao-e-uuid/a.pdf', false) AS caminho_invalido;
RESET ROLE;

\echo '--- 5) anon barrado'
SET LOCAL ROLE anon;
DO $$ BEGIN PERFORM 1 FROM orcamento_anexos LIMIT 1; RAISE EXCEPTION 'anon leu'; EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'ok anon barrado'; END $$;
RESET ROLE;

\echo '--- 6) bucket privado'
SELECT id, public, file_size_limit FROM storage.buckets WHERE id='orcamento-anexos';
ROLLBACK;
