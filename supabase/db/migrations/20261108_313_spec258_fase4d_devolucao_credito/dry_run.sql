-- SPEC-258 Fase 4d: dry-run (ROLLBACK). So ASCII.
\set ON_ERROR_STOP on
BEGIN;
CREATE TEMP TABLE antes_cnt AS SELECT (SELECT count(*) FROM financeiro_titulos) AS tit, (SELECT count(*) FROM financeiro_parcelas) AS par, (SELECT count(*) FROM v_financeiro_realizado_novo) AS rea;
\ir up.sql
SELECT u.id AS adm FROM usuarios u WHERE u.role = 'admin' ORDER BY u.id LIMIT 1 \gset
SELECT set_config('request.jwt.claims', json_build_object('sub', :'adm', 'role', 'authenticated', 'email', 'filippo@lucenera.com.br')::text, true) \gset

\echo '--- 0) um orcamento de devolucao existente (rascunho) serve de cobaia dentro da transacao'
SELECT o.id AS dev, o.projeto_id AS proj, o.empresa_id AS emp FROM orcamentos o WHERE o.natureza_operacao = 'devolucao' AND o.empresa_id IS NOT NULL ORDER BY o.created_at LIMIT 1 \gset
SELECT (enum_range(NULL::pagamento_forma))[1]::text AS forma1 \gset
SELECT :'forma1' AS forma_usada;

\echo '--- 1) duas parcelas de projeto NEGATIVAS (como a aprovacao de devolucao cria)'
INSERT INTO projeto_parcelas (projeto_id, numero_parcela, valor, data_fechamento, data_vencimento, status, forma_pagamento, orcamento_id, descricao)
VALUES (:'proj', 1, -100, current_date, current_date + 10, 'pendente', :'forma1'::pagamento_forma, :'dev', 'Credito de devolucao (teste)'),
       (:'proj', 2, -50, current_date, current_date + 40, 'pendente', :'forma1'::pagamento_forma, :'dev', 'Credito de devolucao (teste)');
SELECT t.especie, t.natureza, t.origem_tipo, t.perfil, (t.plano_contas_id IS NOT NULL) AS tem_plano, (t.contato_id IS NOT NULL) AS tem_pessoa,
       (SELECT count(*) FROM financeiro_parcelas p WHERE p.titulo_id = t.id) AS parcelas,
       (SELECT sum(p.valor) FROM financeiro_parcelas p WHERE p.titulo_id = t.id) AS soma, (SELECT string_agg(DISTINCT p.situacao::text, ',') FROM financeiro_parcelas p WHERE p.titulo_id = t.id) AS situacoes
  FROM financeiro_titulos t WHERE t.orcamento_id = :'dev' AND t.origem_tipo = 'devolucao';
SELECT count(*) AS falhas_abertas FROM financeiro_ponte_falhas WHERE resolvida_em IS NULL;

\echo '--- 2) integridade: o teste novo da devolucao em 0 e os antigos tambem'
SELECT * FROM vw_financeiro_ponte_integridade;

\echo '--- 3) o Dashboard (view nova) enxerga o credito: receita, em aberto, valor negativo'
SELECT tipo, status_pago, vl_parcela, desc_grupo FROM v_financeiro_realizado_novo WHERE vl_parcela < 0 ORDER BY vl_parcela;
SELECT status, valor, num_parcela, tipo_operacao FROM vw_financeiro_duplicatas WHERE valor < 0 ORDER BY valor;

\echo '--- 4) mudar valor e vencimento da parcela 2 e cancelar a 1: espelho acompanha'
UPDATE projeto_parcelas SET valor = -70, data_vencimento = current_date + 45 WHERE orcamento_id = :'dev' AND numero_parcela = 2;
UPDATE projeto_parcelas SET status = 'cancelada' WHERE orcamento_id = :'dev' AND numero_parcela = 1;
SELECT p.numero, p.valor, p.situacao, p.vencimento - current_date AS dias FROM financeiro_parcelas p JOIN financeiro_titulos t ON t.id = p.titulo_id WHERE t.orcamento_id = :'dev' ORDER BY p.numero;

\echo '--- 5) permuta e parcela POSITIVA nao geram credito'
INSERT INTO projeto_parcelas (projeto_id, numero_parcela, valor, data_fechamento, data_vencimento, status, forma_pagamento, orcamento_id, descricao)
VALUES (:'proj', 3, -10, current_date, current_date + 5, 'paga', 'permuta', :'dev', 'permuta (teste)');
SELECT count(*) AS parcelas_do_titulo_depois_da_permuta FROM financeiro_parcelas p JOIN financeiro_titulos t ON t.id = p.titulo_id WHERE t.orcamento_id = :'dev';
SELECT (SELECT count(*) FROM financeiro_titulos) - (SELECT tit FROM antes_cnt) AS titulos_novos_total;

\echo '--- 6) desfazer a aprovacao (apagar as parcelas de projeto): cancela parcela e titulo'
DELETE FROM projeto_parcelas WHERE orcamento_id = :'dev';
SELECT p.numero, p.situacao FROM financeiro_parcelas p JOIN financeiro_titulos t ON t.id = p.titulo_id WHERE t.orcamento_id = :'dev' ORDER BY p.numero;
SELECT (cancelado_em IS NOT NULL) AS titulo_cancelado, motivo_cancelamento FROM financeiro_titulos WHERE orcamento_id = :'dev' AND origem_tipo = 'devolucao';

\echo '--- 7) venda comum nao e afetada; integridade final'
SELECT * FROM vw_financeiro_novo_integridade WHERE violacoes > 0 AND teste NOT LIKE 'pendencias abertas%';
SELECT * FROM vw_financeiro_ponte_integridade WHERE violacoes > 0;
SELECT count(*) AS falhas_abertas_final FROM financeiro_ponte_falhas WHERE resolvida_em IS NULL;

\echo '--- 8) permissoes: as funcoes novas nao sao chamaveis por anon/authenticated'
SELECT has_function_privilege('anon', 'public.financeiro_ponte_devolucao(uuid)', 'EXECUTE') AS anon_exec, has_function_privilege('authenticated', 'public.financeiro_ponte_devolucao(uuid)', 'EXECUTE') AS auth_exec;
ROLLBACK;
