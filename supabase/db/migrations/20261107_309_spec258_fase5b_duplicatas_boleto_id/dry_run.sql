-- SPEC-258 Fase 5b: dry-run (ROLLBACK). So ASCII.
\set ON_ERROR_STOP on
BEGIN;
\ir up.sql
SELECT u.id AS adm FROM usuarios u WHERE u.role = 'admin' ORDER BY u.id LIMIT 1 \gset
SELECT set_config('request.jwt.claims', json_build_object('sub', :'adm', 'role', 'authenticated', 'email', 'filippo@lucenera.com.br')::text, true) \gset

\echo '--- 1) desempenho e contagem (a view inteira)'
\timing on
SELECT count(*) AS linhas, count(*) FILTER (WHERE boleto_id IS NOT NULL) AS com_boleto FROM vw_financeiro_duplicatas;
\timing off

\echo '--- 2) venda aprovada gera boleto: a view aponta o boleto certo (e nao duplica)'
SELECT id AS orc3 FROM orcamentos WHERE numero = 'ORC-0003' AND status LIKE 'Aprova%Financeira' \gset
SELECT set_config('request.jwt.claims', '{"role":"service_role"}', true) \gset
SELECT (aprovar_orcamento_financeiro(:'orc3')->>'boletos_criados') AS boletos_criados;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT set_config('request.jwt.claims', json_build_object('sub', :'adm', 'role', 'authenticated', 'email', 'filippo@lucenera.com.br')::text, true) \gset
SELECT d.tipo_operacao, d.status, d.valor, (d.boleto_id IS NOT NULL) AS tem_boleto_na_view, (b.id = d.boleto_id) AS e_o_boleto_da_parcela
FROM vw_financeiro_duplicatas d JOIN financeiro_titulos t ON t.id = d.titulo_id LEFT JOIN boletos b ON b.id = d.boleto_id WHERE t.orcamento_id = :'orc3' AND d.status = 'Pendente';
SELECT count(*) AS boletos_do_orcamento FROM boletos WHERE orcamento_id = :'orc3';

\echo '--- 3) nota de entrada: boleto CP NFC-xxx aparece como boleto_id da parcela da nota'
SELECT p.id AS ped, p.fornecedor_id AS forn, p.empresa_id AS emp FROM pedidos_compra p WHERE p.status = 'aprovado' AND p.numero NOT LIKE 'PC-LEGADO-%' AND p.empresa_id IS NOT NULL ORDER BY p.numero LIMIT 1 \gset
SELECT set_config('request.jwt.claims', '{"role":"service_role"}', true) \gset
INSERT INTO notas_fiscais_compra (pedido_compra_id, numero_nf, data_emissao, valor, fornecedor_id, empresa_id) VALUES (:'ped', 'TESTE-5B-1', current_date, 100, :'forn', :'emp') RETURNING id AS nota \gset
INSERT INTO nota_fiscal_compra_parcelas (nota_id, numero_parcela, data_vencimento, valor) VALUES (:'nota', 1, current_date + 10, 100);
SET CONSTRAINTS ALL IMMEDIATE;
SELECT set_config('request.jwt.claims', json_build_object('sub', :'adm', 'role', 'authenticated', 'email', 'filippo@lucenera.com.br')::text, true) \gset
SELECT d.tipo_operacao, d.status, d.valor, (b.id = d.boleto_id) AS e_o_boleto_da_nota, d.tipo, d.fatura
FROM vw_financeiro_duplicatas d JOIN financeiro_titulos t ON t.id = d.titulo_id LEFT JOIN boletos b ON b.id = d.boleto_id WHERE t.nota_fiscal_compra_id = :'nota';

\echo '--- 4) legado nao tem boleto; nenhuma linha com boleto_id duplicado'
SELECT count(*) FILTER (WHERE origem_tipo = 'legado_connect' AND boleto_id IS NOT NULL) AS legado_com_boleto,
       (SELECT count(*) FROM (SELECT boleto_id FROM vw_financeiro_duplicatas WHERE boleto_id IS NOT NULL GROUP BY 1 HAVING count(*) > 1) x) AS boletos_em_duas_linhas
FROM vw_financeiro_duplicatas;

\echo '--- 5) seguranca e antigo intacto'
SELECT set_config('request.jwt.claims', '{"sub":"ea9ae91b-324d-4b57-acd6-0904979ea38f","role":"authenticated"}', true) \gset
SET LOCAL ROLE authenticated;
SELECT count(*) AS aux_estoque_ve FROM vw_financeiro_duplicatas;
RESET ROLE;
SET LOCAL ROLE anon;
DO $$ BEGIN PERFORM 1 FROM vw_financeiro_duplicatas LIMIT 1; RAISE NOTICE 'FALHA: anon leu';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'ok anon barrado'; END $$;
RESET ROLE;
SELECT set_config('request.jwt.claims', '', true) \gset
SELECT (SELECT count(*) FROM v_financeiro_realizado) AS linhas_view_antiga, (SELECT round(sum(vl_parcela), 2) FROM v_financeiro_realizado) AS soma_view_antiga;
ROLLBACK;
