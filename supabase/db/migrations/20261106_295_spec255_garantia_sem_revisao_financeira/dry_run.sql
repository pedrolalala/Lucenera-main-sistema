-- SPEC-255: dry-run da migration 295 (termina em ROLLBACK). Uso: psql "$SUPABASE_DB_URL" -X -f dry_run.sql (de dentro da pasta)
\set ON_ERROR_STOP on
BEGIN;
\ir up.sql

-- admin para aprovar (Vinicius)
SELECT u.id AS adm FROM usuarios u WHERE u.role = 'admin' ORDER BY u.id LIMIT 1 \gset
SELECT set_config('request.jwt.claims', json_build_object('sub', :'adm', 'role', 'authenticated')::text, true);

-- 1) cópia do orçamento de garantia (ORC-0005) voltando para Aprovação da Equipe, sem itens de projeto
CREATE TEMP TABLE o AS SELECT * FROM orcamentos WHERE natureza_operacao = 'outros' AND subgrupo = 'GARANTIA' LIMIT 1;
UPDATE o SET id = gen_random_uuid(), numero = 'ORC-TESTE-255', status = 'Aprovação da Equipe', numero_venda = NULL;
SELECT id AS g_id FROM o \gset
INSERT INTO orcamentos SELECT * FROM o;
INSERT INTO orcamento_itens
  SELECT (jsonb_populate_record(NULL::orcamento_itens, to_jsonb(i) || jsonb_build_object('id', gen_random_uuid(), 'orcamento_id', :'g_id'))).*
  FROM orcamento_itens i WHERE i.orcamento_id = (SELECT id FROM orcamentos WHERE natureza_operacao='outros' AND subgrupo='GARANTIA' AND numero <> 'ORC-TESTE-255' LIMIT 1);
SELECT count(*) AS itens_da_copia FROM orcamento_itens WHERE orcamento_id = :'g_id';

\echo '--- 2) equipe aprova a GARANTIA: deve concluir na hora (Orçamento Aprovado), sem fila do financeiro'
SET LOCAL ROLE authenticated;
SELECT public.equipe_aprovar_orcamento(:'g_id'::uuid, 'teste SPEC-255');
RESET ROLE;
SELECT numero, status, requer_revisao_financeira, numero_venda FROM orcamentos WHERE id = :'g_id';
SELECT status_anterior, status_novo FROM historico_status_orcamentos WHERE orcamento_id = :'g_id' ORDER BY 1;
SELECT (SELECT count(*) FROM boletos WHERE orcamento_id = :'g_id') boletos, (SELECT count(*) FROM projeto_itens WHERE orcamento_id = :'g_id') itens_projeto;

\echo '--- 3) VENDA comum continua indo para a Aprovação Financeira'
SELECT id AS v_id FROM orcamentos WHERE natureza_operacao = 'venda' AND origem = 'sistema' LIMIT 1 \gset
UPDATE orcamentos SET status = 'Aprovação da Equipe' WHERE id = :'v_id';
SET LOCAL ROLE authenticated;
SELECT public.equipe_aprovar_orcamento(:'v_id'::uuid, 'teste SPEC-255 venda');
RESET ROLE;
SELECT status, requer_revisao_financeira FROM orcamentos WHERE id = :'v_id';
ROLLBACK;
