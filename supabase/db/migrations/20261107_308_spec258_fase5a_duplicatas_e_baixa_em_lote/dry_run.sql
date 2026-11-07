-- SPEC-258 Fase 5a: dry-run (ROLLBACK). So ASCII.
\set ON_ERROR_STOP on
BEGIN;
\ir up.sql
SELECT u.id AS adm FROM usuarios u WHERE u.role = 'admin' ORDER BY u.id LIMIT 1 \gset
SELECT set_config('request.jwt.claims', json_build_object('sub', :'adm', 'role', 'authenticated', 'email', 'filippo@lucenera.com.br')::text, true) \gset
CREATE OR REPLACE FUNCTION pg_temp.tenta(rotulo text, comando text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  BEGIN EXECUTE comando; RAISE NOTICE 'FALHA: % foi ACEITO e nao devia', rotulo;
  EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'ok recusou: % (%)', rotulo, left(SQLERRM, 70); END;
END $$;

\echo '--- 1) a view nova tem as mesmas contagens do legado (por tipo e situacao)'
SELECT d.tipo_operacao, d.status, count(*) AS na_view_nova,
       (SELECT count(*) FROM transacoes t JOIN financeiro_legado_ids l ON l.tabela_antiga = 'transacoes' AND l.id_antigo = t.id
         WHERE (CASE WHEN t.tipo::text = 'despesa' THEN 'CP' ELSE 'CR' END) = d.tipo_operacao
           AND (CASE t.status_pago WHEN 1 THEN 'Pago' WHEN 2 THEN 'Cancelado' ELSE 'Pendente' END) = d.status) AS no_legado
FROM vw_financeiro_duplicatas d GROUP BY 1, 2 ORDER BY 1, 2;

\echo '--- 2) campos que a tela mostra: diferencas contra a transacao antiga (deve ser 0 em tudo)'
SELECT count(*) FILTER (WHERE d.vencimento IS DISTINCT FROM t.dt_vencimento) vencimento,
       count(*) FILTER (WHERE round(d.valor,2) IS DISTINCT FROM round(coalesce(t.vl_parcela,0),2)) valor,
       count(*) FILTER (WHERE d.numero_documento IS DISTINCT FROM coalesce(n.cod_duplicata::text, '')) numero_documento,
       count(*) FILTER (WHERE d.nome_pagador IS DISTINCT FROM coalesce(nullif(n.nome_pessoa, ''), nullif(n.razao_pessoa, ''), c.nome, CASE WHEN n.cod_pessoa IS NOT NULL THEN 'Pessoa ' || n.cod_pessoa END, '')) nome_pagador,
       count(*) FILTER (WHERE d.venda IS DISTINCT FROM coalesce(n.cod_venda::text, '')) venda,
       count(*) FILTER (WHERE d.fatura IS DISTINCT FROM coalesce(n.num_nota::text, '')) fatura,
       count(*) FILTER (WHERE d.status = 'Pago' AND round(d.valor_pago,2) IS DISTINCT FROM round(coalesce(t.vl_pago,0),2)) valor_pago_dif,
       count(*) FILTER (WHERE d.empresa_id IS DISTINCT FROM n.empresa_id) empresa
FROM vw_financeiro_duplicatas d JOIN financeiro_legado_ids l ON l.tabela_antiga = 'transacoes' AND l.id_novo = d.parcela_id
JOIN transacoes t ON t.id = l.id_antigo JOIN negociacoes n ON n.id = t.negociacao_id LEFT JOIN contatos c ON c.id = n.contato_id;

\echo '--- 3) baixa em lote (como Filippo): 2 receitas + 1 despesa abertas do legado'
SELECT d.parcela_id AS r1 FROM vw_financeiro_duplicatas d WHERE d.tipo_operacao = 'CR' AND d.status = 'Pendente' AND d.valor > 100 ORDER BY d.vencimento, d.parcela_id LIMIT 1 \gset
SELECT d.parcela_id AS r2 FROM vw_financeiro_duplicatas d WHERE d.tipo_operacao = 'CR' AND d.status = 'Pendente' AND d.valor > 100 AND d.parcela_id <> :'r1' ORDER BY d.vencimento, d.parcela_id LIMIT 1 \gset
SELECT d.parcela_id AS d1 FROM vw_financeiro_duplicatas d WHERE d.tipo_operacao = 'CP' AND d.status = 'Pendente' AND d.valor > 100 ORDER BY d.vencimento, d.parcela_id LIMIT 1 \gset
SELECT c.id AS conta FROM contas_bancarias c WHERE c.empresa_id IS NOT NULL ORDER BY c.id LIMIT 1 \gset
SELECT c.id AS conta_outra FROM contas_bancarias c WHERE c.empresa_id IS NOT NULL AND c.empresa_id <> (SELECT empresa_id FROM vw_financeiro_duplicatas WHERE parcela_id = :'d1') ORDER BY c.id LIMIT 1 \gset
SELECT parcela_id, tipo_operacao, valor, saldo, status FROM vw_financeiro_duplicatas WHERE parcela_id IN (:'r1', :'r2', :'d1') ORDER BY tipo_operacao, parcela_id;
SELECT financeiro_baixar_lote(ARRAY[:'r1', :'r2']::uuid[], current_date, 'PIX', :'conta', 10, 5, NULL, 'teste lote') AS resultado;
SELECT parcela_id, status, valor, valor_pago, juros_multa, desconto, forma_pagamento, saldo FROM vw_financeiro_duplicatas WHERE parcela_id IN (:'r1', :'r2') ORDER BY parcela_id;
SELECT b.tipo, b.valor, b.juros, b.desconto, b.origem_baixa, (b.empresa_pagadora_id IS NOT NULL) outra_empresa FROM financeiro_baixas b WHERE b.parcela_id IN (:'r1', :'r2') ORDER BY b.parcela_id, b.tipo;
SELECT financeiro_baixar_lote(ARRAY[:'d1']::uuid[], current_date, 'Transferencia', :'conta_outra') AS resultado_conta_de_outra_empresa;
SELECT b.tipo, (b.empresa_pagadora_id IS NOT NULL) AS registrou_empresa_pagadora FROM financeiro_baixas b WHERE b.parcela_id = :'d1';

\echo '--- 4) o que o banco RECUSA'
SELECT pg_temp.tenta('parcela ja quitada', format($q$SELECT financeiro_baixar_lote(ARRAY[%L]::uuid[], current_date, 'PIX', %L)$q$, :'r1', :'conta'));
SELECT pg_temp.tenta('sem conta bancaria', format($q$SELECT financeiro_baixar_lote(ARRAY[%L]::uuid[], current_date, 'PIX', NULL)$q$, :'r1'));
SELECT pg_temp.tenta('lista vazia', $q$SELECT financeiro_baixar_lote(ARRAY[]::uuid[], current_date, 'PIX', NULL)$q$);
SELECT pg_temp.tenta('juros negativo', format($q$SELECT financeiro_baixar_lote(ARRAY[%L]::uuid[], current_date, 'PIX', %L, -1)$q$, :'r1', :'conta'));
SELECT pg_temp.tenta('parcela inexistente', format($q$SELECT financeiro_baixar_lote(ARRAY[gen_random_uuid()]::uuid[], current_date, 'PIX', %L)$q$, :'conta'));
SELECT d.parcela_id AS cancelada FROM vw_financeiro_duplicatas d WHERE d.status = 'Cancelado' LIMIT 1 \gset
SELECT pg_temp.tenta('parcela cancelada', format($q$SELECT financeiro_baixar_lote(ARRAY[%L]::uuid[], current_date, 'PIX', %L)$q$, :'cancelada', :'conta'));
SELECT d.parcela_id AS prevista FROM vw_financeiro_duplicatas d WHERE d.status = 'Previsto' LIMIT 1 \gset
SELECT pg_temp.tenta('parcela so prevista', format($q$SELECT financeiro_baixar_lote(ARRAY[%L]::uuid[], current_date, 'PIX', %L)$q$, :'prevista', :'conta'));

\echo '--- 5) estorno de uma baixa do lote devolve a parcela para pendente'
SELECT b.id AS bx FROM financeiro_baixas b WHERE b.parcela_id = :'r1' AND b.tipo = 'recebimento' \gset
SELECT b2.id AS bx2 FROM financeiro_baixas b2 WHERE b2.parcela_id = :'r1' AND b2.tipo = 'abatimento' \gset
SELECT financeiro_estornar(:'bx', 'teste') IS NOT NULL AS estornou_dinheiro, financeiro_estornar(:'bx2', 'teste') IS NOT NULL AS estornou_abatimento;
SELECT status, valor_pago, saldo FROM vw_financeiro_duplicatas WHERE parcela_id = :'r1';

\echo '--- 6) seguranca'
SELECT set_config('app.r2', :'r2', true) AS _a, set_config('app.conta', :'conta', true) AS _b \gset
SELECT set_config('request.jwt.claims', '{"sub":"ea9ae91b-324d-4b57-acd6-0904979ea38f","role":"authenticated"}', true) \gset
SET LOCAL ROLE authenticated;
SELECT count(*) AS aux_estoque_ve_duplicatas FROM vw_financeiro_duplicatas;
DO $$ BEGIN PERFORM financeiro_baixar_lote(ARRAY[current_setting('app.r2')::uuid], current_date, 'PIX', current_setting('app.conta')::uuid); RAISE NOTICE 'FALHA: aux estoque baixou';
  EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'ok recusou: aux estoque na baixa (%)', left(SQLERRM, 50); END $$;
RESET ROLE;
SET LOCAL ROLE anon;
DO $$ BEGIN PERFORM financeiro_baixar_lote(ARRAY[gen_random_uuid()], current_date, 'PIX', gen_random_uuid()); RAISE NOTICE 'FALHA: anon baixou';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'ok anon barrado'; END $$;
RESET ROLE;
SELECT set_config('request.jwt.claims', json_build_object('sub', :'adm', 'role', 'authenticated', 'email', 'filippo@lucenera.com.br')::text, true) \gset
SELECT teste, violacoes FROM vw_financeiro_novo_integridade WHERE violacoes > 0 AND teste NOT LIKE 'pendencias%';
SELECT set_config('request.jwt.claims', '', true) \gset
SELECT (SELECT count(*) FROM v_financeiro_realizado) AS linhas_view_antiga, (SELECT round(sum(vl_parcela), 2) FROM v_financeiro_realizado) AS soma_view_antiga;
ROLLBACK;
