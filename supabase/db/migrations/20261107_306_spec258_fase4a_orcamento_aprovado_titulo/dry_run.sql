-- SPEC-258 Fase 4a: dry-run (ROLLBACK). Simula aprovacao de orcamento, recebimento, desfazer e cancelamento no funil ANTIGO e confere o modelo NOVO. So ASCII.
\set ON_ERROR_STOP on
BEGIN;
\ir up.sql
SELECT id AS orc1 FROM orcamentos WHERE numero = 'ORC-0001' AND status LIKE 'Aprova%Financeira' \gset
SELECT id AS orc3 FROM orcamentos WHERE numero = 'ORC-0003' AND status LIKE 'Aprova%Financeira' \gset

\echo '--- 0) backfill do que ja existia (2 transacoes nativas canceladas de 05/11)'
SELECT (SELECT count(*) FROM financeiro_titulos WHERE origem_tipo = 'orcamento') titulos_orcamento, (SELECT count(*) FROM financeiro_ponte_falhas) falhas;

\echo '--- 1) aprovar ORC-0001 (2 parcelas, boleto) e ORC-0003 (1 parcela, pix) pela funcao ANTIGA'
SELECT set_config('request.jwt.claims', '{"role":"service_role"}', true) \gset
SELECT (aprovar_orcamento_financeiro(:'orc1')->>'parcelas_criadas') AS parcelas_orc1;
SELECT (aprovar_orcamento_financeiro(:'orc3')->>'parcelas_criadas') AS parcelas_orc3;
SELECT o.numero, count(DISTINCT pp.id) parcelas_projeto, count(DISTINCT t.id) transacoes, count(DISTINCT p.id) parcelas_novas, round(sum(DISTINCT pp.valor), 2) valor_projeto
FROM orcamentos o JOIN projeto_parcelas pp ON pp.orcamento_id = o.id LEFT JOIN transacoes t ON t.id = pp.transacao_id
LEFT JOIN financeiro_legado_ids l ON l.tabela_antiga = 'transacoes' AND l.id_antigo = t.id LEFT JOIN financeiro_parcelas p ON p.id = l.id_novo
WHERE o.id IN (:'orc1', :'orc3') GROUP BY 1 ORDER BY 1;
SELECT o.numero, ti.natureza, ti.origem_tipo, ti.especie, (ti.plano_contas_id IS NOT NULL) plano, count(p.id) parcelas, round(sum(p.valor), 2) valor, count(*) FILTER (WHERE p.situacao = 'firme') firmes
FROM orcamentos o JOIN financeiro_titulos ti ON ti.orcamento_id = o.id AND ti.origem_tipo = 'orcamento' JOIN financeiro_parcelas p ON p.titulo_id = ti.id
WHERE o.id IN (:'orc1', :'orc3') GROUP BY 1, 2, 3, 4, 5 ORDER BY 1;
SELECT count(*) AS falhas_do_espelho FROM financeiro_ponte_falhas;

\echo '--- 2) recebimento (retorno bancario atualiza projeto_parcelas.status = paga)'
SELECT pp.id AS pp1 FROM projeto_parcelas pp WHERE pp.orcamento_id = :'orc1' AND pp.numero_parcela = 1 \gset
SELECT pp.id AS pp2 FROM projeto_parcelas pp WHERE pp.orcamento_id = :'orc1' AND pp.numero_parcela = 2 \gset
SELECT pp.id AS pp3 FROM projeto_parcelas pp WHERE pp.orcamento_id = :'orc3' AND pp.numero_parcela = 1 \gset
UPDATE projeto_parcelas SET status = 'paga', valor_pago = valor, data_pagamento = current_date WHERE id = :'pp1';
UPDATE projeto_parcelas SET status = 'paga', valor_pago = valor - 10, data_pagamento = current_date WHERE id = :'pp3';
SELECT b.tipo, b.valor, b.juros, b.origem_baixa, (b.conta_bancaria_id IS NOT NULL) tem_conta FROM financeiro_baixas b JOIN financeiro_parcelas p ON p.id = b.parcela_id
JOIN financeiro_titulos ti ON ti.id = p.titulo_id WHERE ti.orcamento_id IN (:'orc1', :'orc3') ORDER BY b.criado_em, b.tipo;
SELECT p.numero, p.valor, p.valor_liquidado FROM financeiro_parcelas p JOIN financeiro_titulos ti ON ti.id = p.titulo_id WHERE ti.orcamento_id IN (:'orc1', :'orc3') ORDER BY ti.orcamento_id, p.numero;

\echo '--- 3) desfazer recebimento da parcela 1 do ORC-0001 e cancelar a parcela 2'
UPDATE projeto_parcelas SET status = 'pendente', valor_pago = NULL, data_pagamento = NULL WHERE id = :'pp1';
UPDATE projeto_parcelas SET status = 'cancelada' WHERE id = :'pp2';
SELECT p.numero, p.situacao, p.valor_liquidado FROM financeiro_parcelas p JOIN financeiro_titulos ti ON ti.id = p.titulo_id WHERE ti.orcamento_id = :'orc1' ORDER BY p.numero;
SELECT b.tipo, b.valor FROM financeiro_baixas b JOIN financeiro_parcelas p ON p.id = b.parcela_id JOIN financeiro_titulos ti ON ti.id = p.titulo_id WHERE ti.orcamento_id = :'orc1' ORDER BY b.criado_em, b.tipo;

\echo '--- 4) integridade: ponte e modelo (como Filippo)'
SELECT u.id AS adm FROM usuarios u WHERE u.role = 'admin' ORDER BY u.id LIMIT 1 \gset
SELECT set_config('request.jwt.claims', json_build_object('sub', :'adm', 'role', 'authenticated', 'email', 'filippo@lucenera.com.br')::text, true) \gset
SELECT teste, violacoes FROM vw_financeiro_ponte_integridade ORDER BY violacoes DESC, teste;
SELECT teste, violacoes FROM vw_financeiro_novo_integridade WHERE violacoes > 0 AND teste NOT LIKE 'pendencias%';

\echo '--- 5) view antiga x view nova (agora com linhas nativas): diferencas = 0'
SELECT (SELECT count(*) FROM v_financeiro_realizado) AS antiga, (SELECT count(*) FROM v_financeiro_realizado_novo) AS nova;
CREATE TEMP TABLE o AS SELECT * FROM v_financeiro_realizado;
CREATE TEMP TABLE n AS SELECT * FROM v_financeiro_realizado_novo;
SELECT (SELECT count(*) FROM o WHERE id NOT IN (SELECT id FROM n)) so_na_antiga, (SELECT count(*) FROM n WHERE id NOT IN (SELECT id FROM o)) so_na_nova,
       count(*) FILTER (WHERE o.status_pago IS DISTINCT FROM n.status_pago) status, count(*) FILTER (WHERE round(coalesce(o.vl_pago,0),2) IS DISTINCT FROM round(coalesce(n.vl_pago,0),2)) vl_pago,
       count(*) FILTER (WHERE round(o.vl_parcela,2) IS DISTINCT FROM round(n.vl_parcela,2)) vl_parcela, count(*) FILTER (WHERE o.dt_vencimento IS DISTINCT FROM n.dt_vencimento) venc,
       count(*) FILTER (WHERE o.empresa_id IS DISTINCT FROM n.empresa_id) empresa, count(*) FILTER (WHERE o.desc_sub_grupo IS DISTINCT FROM n.desc_sub_grupo) sub_grupo
FROM o JOIN n USING (id);

\echo '--- 6) seguranca da tabela de falhas'
SELECT set_config('request.jwt.claims', '{"sub":"ea9ae91b-324d-4b57-acd6-0904979ea38f","role":"authenticated"}', true) \gset
SET LOCAL ROLE authenticated;
SELECT count(*) AS aux_estoque_ve_falhas FROM financeiro_ponte_falhas;
SELECT count(*) AS aux_estoque_ve_integridade FROM vw_financeiro_ponte_integridade;
RESET ROLE;
ROLLBACK;
