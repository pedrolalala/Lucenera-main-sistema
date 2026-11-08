-- SPEC-258 Fase 4c (parte 1): dry-run (ROLLBACK). So ASCII.
\set ON_ERROR_STOP on
BEGIN;
\ir up.sql
SELECT u.id AS adm FROM usuarios u WHERE u.role = 'admin' ORDER BY u.id LIMIT 1 \gset
SELECT set_config('request.jwt.claims', json_build_object('sub', :'adm', 'role', 'authenticated', 'email', 'filippo@lucenera.com.br')::text, true) \gset
SET LOCAL ROLE authenticated;

\echo '--- 1) a view lista os arquitetos, ninguem com regra ainda'
SELECT count(*) AS arquitetos, count(*) FILTER (WHERE tem_regra) AS com_regra FROM vw_financeiro_rt_arquitetos;
SELECT contato_id AS arq1 FROM vw_financeiro_rt_arquitetos ORDER BY nome LIMIT 1 \gset
SELECT contato_id AS arq2 FROM vw_financeiro_rt_arquitetos ORDER BY nome DESC LIMIT 1 \gset

\echo '--- 2) definir RT de um arquiteto: 6,5% sobre o recebido'
SELECT financeiro_definir_rt(:'arq1', 6.5, 'recebido', 'proporcional_recebido', NULL, false, 'teste') IS NOT NULL AS gravou;
SELECT percentual, base_calculo, gatilho, exige_nota_fiscal, tem_regra FROM vw_financeiro_rt_arquitetos WHERE contato_id = :'arq1';

\echo '--- 3) trocar no mesmo dia edita no lugar (continua 1 regra ativa)'
SELECT financeiro_definir_rt(:'arq1', 7, 'liquido', 'venda_quitada', NULL, true, NULL) IS NOT NULL AS gravou;
SELECT percentual, base_calculo, gatilho, exige_nota_fiscal FROM vw_financeiro_rt_arquitetos WHERE contato_id = :'arq1';
SELECT count(*) AS ativas_do_arquiteto FROM financeiro_regras_repasse WHERE beneficiario_contato_id = :'arq1' AND ativo;

\echo '--- 4) regra antiga vira historico quando troca em outro dia'
RESET ROLE;
UPDATE financeiro_regras_repasse SET vigencia_inicio = current_date - 10 WHERE beneficiario_contato_id = :'arq1' AND ativo;
SET LOCAL ROLE authenticated;
SELECT financeiro_definir_rt(:'arq1', 8, 'recebido', 'proporcional_recebido', NULL, false, NULL) IS NOT NULL AS gravou;
RESET ROLE;
SELECT count(*) FILTER (WHERE ativo) AS ativas, count(*) FILTER (WHERE NOT ativo AND vigencia_fim IS NOT NULL) AS encerradas FROM financeiro_regras_repasse WHERE beneficiario_contato_id = :'arq1';
SET LOCAL ROLE authenticated;

\echo '--- 5) regra padrao (contato NULL) e lote'
SELECT financeiro_definir_rt(NULL, 5, 'recebido', 'proporcional_recebido', NULL, NULL, 'padrao') IS NOT NULL AS padrao_gravada;
SELECT financeiro_definir_rt_lote(json_build_array(json_build_object('contato_id', :'arq2', 'percentual', 6, 'exige_nf', true))::jsonb) AS gravadas_no_lote;
SELECT count(*) AS com_regra FROM vw_financeiro_rt_arquitetos WHERE tem_regra;

\echo '--- 6) remover (percentual NULL) deixa o arquiteto sem regra'
SELECT financeiro_definir_rt(:'arq2', NULL) IS NULL AS removida;
SELECT tem_regra FROM vw_financeiro_rt_arquitetos WHERE contato_id = :'arq2';

\echo '--- 7) recusas: percentual fora da faixa, contato que nao e arquiteto'
DO $$ BEGIN PERFORM financeiro_definir_rt((SELECT contato_id FROM vw_financeiro_rt_arquitetos LIMIT 1), 150); RAISE NOTICE 'ERRO: aceitou 150'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'recusou 150: %', SQLERRM; END $$;
DO $$ BEGIN PERFORM financeiro_definir_rt((SELECT id FROM contatos WHERE tipo = 'cliente' LIMIT 1), 5); RAISE NOTICE 'ERRO: aceitou cliente'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'recusou cliente: %', SQLERRM; END $$;

\echo '--- 8) gravacao direta continua proibida; auditoria registrou'
DO $$ BEGIN INSERT INTO financeiro_regras_repasse (tipo, escopo, percentual, base_calculo, gatilho) VALUES ('rt_arquiteto','padrao',1,'bruto','aprovacao'); RAISE NOTICE 'ERRO: gravou direto'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'gravacao direta barrada: %', SQLERRM; END $$;
RESET ROLE;
SELECT count(*) > 0 AS auditou FROM financeiro_eventos WHERE tabela = 'financeiro_regras_repasse';

\echo '--- 9) anon sem acesso'
SELECT has_table_privilege('anon', 'public.vw_financeiro_rt_arquitetos', 'SELECT') AS anon_le_view, has_function_privilege('anon', 'public.financeiro_definir_rt(uuid,numeric,text,text,integer,boolean,text)', 'EXECUTE') AS anon_executa;
ROLLBACK;
