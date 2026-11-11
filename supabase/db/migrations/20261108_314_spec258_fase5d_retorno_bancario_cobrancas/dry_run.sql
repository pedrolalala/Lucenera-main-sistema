-- SPEC-258 Fase 5d: dry-run (ROLLBACK). So ASCII.
\set ON_ERROR_STOP on
BEGIN;
CREATE TEMP TABLE antes_cnt AS SELECT (SELECT count(*) FROM financeiro_cobrancas) AS cob, (SELECT count(*) FROM financeiro_baixas) AS bx, (SELECT count(*) FROM financeiro_pendencias) AS pend;
\ir up.sql
SELECT u.id AS adm FROM usuarios u WHERE u.role = 'admin' ORDER BY u.id LIMIT 1 \gset
SELECT set_config('request.jwt.claims', json_build_object('sub', :'adm', 'role', 'authenticated', 'email', 'filippo@lucenera.com.br')::text, true) \gset

\echo '--- 1) aprovar a venda ORC-0003 cria os boletos a receber; cada um ganha a cobranca espelhada'
SELECT id AS orc3 FROM orcamentos WHERE numero = 'ORC-0003' AND status LIKE 'Aprova%Financeira' \gset
SELECT set_config('request.jwt.claims', '{"role":"service_role"}', true) \gset
SELECT (aprovar_orcamento_financeiro(:'orc3')->>'boletos_criados') AS boletos_criados;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT set_config('request.jwt.claims', json_build_object('sub', :'adm', 'role', 'authenticated', 'email', 'filippo@lucenera.com.br')::text, true) \gset
SELECT count(*) AS boletos, count(*) FILTER (WHERE EXISTS (SELECT 1 FROM financeiro_legado_ids l WHERE l.tabela_antiga = 'boletos' AND l.id_antigo = b.id)) AS com_cobranca FROM boletos b WHERE b.orcamento_id = :'orc3';
SELECT c.sentido, c.meio, c.status_banco, c.valor, (b.valor = c.valor) AS valor_igual, (b.vencimento = c.vencimento) AS venc_igual, (c.nosso_numero = coalesce(b.nosso_numero_banco, b.nosso_numero)) AS nn_igual
  FROM boletos b JOIN financeiro_legado_ids l ON l.tabela_antiga = 'boletos' AND l.id_antigo = b.id JOIN financeiro_cobrancas c ON c.id = l.id_novo WHERE b.orcamento_id = :'orc3' ORDER BY b.num_parcela;
SELECT b.nosso_numero AS nn1, b.valor AS v1, b.parcela_id AS pp1 FROM boletos b WHERE b.orcamento_id = :'orc3' ORDER BY b.num_parcela LIMIT 1 \gset
-- a venda tem 1 parcela: cria a parcela 2 e o boleto 2 (como a aprovacao faria) para testar o caminho divergente e o manual
INSERT INTO projeto_parcelas (projeto_id, numero_parcela, valor, data_fechamento, data_vencimento, status, forma_pagamento, orcamento_id, descricao)
SELECT projeto_id, 2, valor, data_fechamento, data_vencimento + 30, 'pendente', forma_pagamento, orcamento_id, descricao FROM projeto_parcelas WHERE id = :'pp1' RETURNING id AS pp2 \gset
INSERT INTO boletos (nosso_numero, numero_documento, parcela_id, orcamento_id, empresa_id, valor, vencimento, nome_pagador, status, tipo, num_parcela, total_parcelas, emissao)
SELECT nosso_numero || '-B', numero_documento || '-2', :'pp2', orcamento_id, empresa_id, valor, vencimento + 30, nome_pagador, 'pendente_registro', tipo, 2, 2, emissao FROM boletos WHERE nosso_numero = :'nn1';
SET CONSTRAINTS ALL IMMEDIATE;
SELECT b.nosso_numero AS nn2, b.valor AS v2 FROM boletos b WHERE b.parcela_id = :'pp2' \gset
SELECT l.id_novo AS par1 FROM projeto_parcelas pp JOIN financeiro_legado_ids l ON l.tabela_antiga = 'transacoes' AND l.id_antigo = pp.transacao_id WHERE pp.id = :'pp1' \gset
SELECT l.id_novo AS par2 FROM projeto_parcelas pp JOIN financeiro_legado_ids l ON l.tabela_antiga = 'transacoes' AND l.id_antigo = pp.transacao_id WHERE pp.id = :'pp2' \gset
SELECT t.empresa_id AS emp FROM financeiro_parcelas p JOIN financeiro_titulos t ON t.id = p.titulo_id WHERE p.id = :'par1' \gset
SELECT id AS conta_brad FROM contas_bancarias WHERE empresa_id = :'emp' AND banco ILIKE 'bradesco%' ORDER BY nome LIMIT 1 \gset
SELECT :'v1'::numeric AS valor_parcela1, :'v2'::numeric AS valor_parcela2, (:'conta_brad' <> '') AS achou_bradesco_da_empresa;

\echo '--- 2) retorno ocorrencia 02 (entrada confirmada): cobranca vira registrado'
SELECT processar_retorno_bancario('t1.ret', 'hash-dry-1', 'BRAD', jsonb_build_array(jsonb_build_object('nosso_numero', :'nn1', 'valor_recebido', 0, 'data_pagamento', current_date::text, 'ocorrencia_codigo', '02')));
SELECT c.status_banco FROM financeiro_legado_ids l JOIN financeiro_cobrancas c ON c.id = l.id_novo WHERE l.tabela_antiga = 'boletos' AND l.id_antigo = (SELECT id FROM boletos WHERE nosso_numero = :'nn1');

\echo '--- 3) retorno liquidacao (06) da parcela 1 com R$ 2,50 de juros: baixa nasce como retorno_bancario, ligada a cobranca e a conta Bradesco da empresa'
SELECT processar_retorno_bancario('t2.ret', 'hash-dry-2', 'BRAD', jsonb_build_array(jsonb_build_object('nosso_numero', :'nn1', 'valor_recebido', (:'v1'::numeric + 2.5), 'data_pagamento', current_date::text, 'ocorrencia_codigo', '06')));
SELECT bx.tipo, bx.valor = :'v1'::numeric AS valor_ok, bx.juros, bx.origem_baixa, (bx.cobranca_id IS NOT NULL) AS tem_cobranca, (bx.conta_bancaria_id = :'conta_brad'::uuid) AS conta_bradesco_empresa, bx.movimenta_caixa
  FROM financeiro_baixas bx WHERE bx.parcela_id = :'par1' ORDER BY bx.criado_em;
SELECT (bx.cobranca_id = l.id_novo) AS baixa_ligada_a_cobranca_do_boleto
  FROM financeiro_baixas bx JOIN financeiro_legado_ids l ON l.tabela_antiga = 'boletos' AND l.id_antigo = (SELECT id FROM boletos WHERE nosso_numero = :'nn1') WHERE bx.parcela_id = :'par1' AND bx.tipo = 'recebimento';
SELECT c.status_banco AS cobranca_apos_pagamento FROM financeiro_legado_ids l JOIN financeiro_cobrancas c ON c.id = l.id_novo WHERE l.tabela_antiga = 'boletos' AND l.id_antigo = (SELECT id FROM boletos WHERE nosso_numero = :'nn1');
SELECT status, valor_pago, juros_multa FROM vw_financeiro_duplicatas WHERE parcela_id = :'par1';
SELECT count(*) AS pendencias_novas FROM financeiro_pendencias WHERE tipo = 'baixa_sem_conta_bancaria' AND baixa_id IN (SELECT id FROM financeiro_baixas WHERE parcela_id = :'par1');

\echo '--- 4) retorno com valor MENOR que o boleto: divergente, sem baixa (como antes)'
SELECT processar_retorno_bancario('t3.ret', 'hash-dry-3', 'BRAD', jsonb_build_array(jsonb_build_object('nosso_numero', :'nn2', 'valor_recebido', (:'v2'::numeric - 1), 'data_pagamento', current_date::text, 'ocorrencia_codigo', '06')));
SELECT status_aplicacao, motivo_divergencia FROM retorno_bancario_registros WHERE nosso_numero = :'nn2';
SELECT count(*) AS baixas_parcela2 FROM financeiro_baixas WHERE parcela_id = :'par2';

\echo '--- 5) reprocessar o mesmo arquivo (forcado): ja processado, sem baixa em dobro'
SELECT processar_retorno_bancario('t2.ret', 'hash-dry-2', 'BRAD', jsonb_build_array(jsonb_build_object('nosso_numero', :'nn1', 'valor_recebido', (:'v1'::numeric + 2.5), 'data_pagamento', current_date::text, 'ocorrencia_codigo', '06')), true);
SELECT count(*) AS baixas_recebimento_parcela1 FROM financeiro_baixas WHERE parcela_id = :'par1' AND tipo = 'recebimento';

\echo '--- 6) baixa MANUAL (tela Executar) da parcela 2: origem manual, nao vira retorno_bancario, sem baixa em dobro'
SELECT financeiro_baixar_lote(ARRAY[:'par2']::uuid[], current_date, 'Boleto', :'conta_brad'::uuid, 0, 0, NULL, 'dry-run 5d');
UPDATE boletos SET status = 'Pago', valor_pago = :'v2'::numeric, data_pagamento = current_date WHERE nosso_numero = :'nn2';
SELECT tipo, origem_baixa, (cobranca_id IS NOT NULL) AS tem_cobranca FROM financeiro_baixas WHERE parcela_id = :'par2' ORDER BY criado_em;
SELECT c.status_banco FROM financeiro_legado_ids l JOIN financeiro_cobrancas c ON c.id = l.id_novo WHERE l.tabela_antiga = 'boletos' AND l.id_antigo = (SELECT id FROM boletos WHERE nosso_numero = :'nn2');

\echo '--- 7) integridade (ponte e modelo novo) sem violacao; falhas do espelho 0'
SELECT * FROM vw_financeiro_ponte_integridade;
SELECT * FROM vw_financeiro_novo_integridade WHERE violacoes > 0 AND teste NOT LIKE 'pendencias abertas%';
SELECT count(*) AS falhas_abertas FROM financeiro_ponte_falhas WHERE resolvida_em IS NULL;

\echo '--- 8) permissoes'
SELECT has_function_privilege('anon', 'public.financeiro_ponte_cobranca(uuid)', 'EXECUTE') AS anon_exec, has_function_privilege('authenticated', 'public.financeiro_ponte_cobranca(uuid)', 'EXECUTE') AS auth_exec,
       has_table_privilege('anon', 'public.financeiro_cobrancas', 'SELECT') AS anon_le_cobrancas;
ROLLBACK;
