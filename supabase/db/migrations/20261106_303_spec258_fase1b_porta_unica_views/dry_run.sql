-- SPEC-258 Fase 1B: dry-run (termina em ROLLBACK). Roda DENTRO da pasta; exige a 302 ja aplicada. So ASCII.
\set ON_ERROR_STOP on
BEGIN;
\ir up.sql
SELECT (SELECT id FROM empresas LIMIT 1) AS emp, (SELECT id FROM plano_de_contas WHERE nivel = 3 LIMIT 1) AS plano,
       (SELECT id FROM contas_bancarias WHERE empresa_id IS NOT NULL LIMIT 1) AS conta, (SELECT id FROM contatos WHERE tipo = 'cliente' LIMIT 1) AS cli,
       (SELECT id FROM funcionarios LIMIT 1) AS func \gset
SELECT id AS orc1 FROM orcamentos WHERE natureza_operacao = 'venda' ORDER BY id LIMIT 1 \gset
SELECT id AS orc2 FROM orcamentos WHERE natureza_operacao = 'venda' ORDER BY id OFFSET 1 LIMIT 1 \gset
CREATE OR REPLACE FUNCTION pg_temp.tenta(rotulo text, comando text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  BEGIN EXECUTE comando; RAISE NOTICE 'FALHA: % foi ACEITO e nao devia', rotulo;
  EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'ok recusou: % (%)', rotulo, left(SQLERRM, 80); END;
END $$;

\echo '--- 1) criar titulo pela porta unica (chamada interna, sem usuario)'
SELECT financeiro_criar_titulo(jsonb_build_object('natureza','receber','origem_tipo','orcamento','orcamento_id',:'orc1','especie','venda','empresa_id',:'emp','plano_contas_id',:'plano','contato_id',:'cli'),
  '[{"vencimento":"2026-12-10","valor":1000,"situacao":"prevista"},{"vencimento":"2027-01-10","valor":500,"situacao":"firme"}]'::jsonb) AS t1 \gset
SELECT numero, situacao, valor, (confirmada_em IS NOT NULL) AS confirmada FROM financeiro_parcelas WHERE titulo_id = :'t1' ORDER BY numero;
SELECT pg_temp.tenta('titulo sem parcelas', format($q$SELECT financeiro_criar_titulo(jsonb_build_object('natureza','receber','origem_tipo','orcamento','orcamento_id',%L,'especie','venda','empresa_id',%L,'plano_contas_id',%L),'[]'::jsonb)$q$, :'orc2', :'emp', :'plano'));
SELECT pg_temp.tenta('parcela de valor zero', format($q$SELECT financeiro_criar_titulo(jsonb_build_object('natureza','receber','origem_tipo','orcamento','orcamento_id',%L,'especie','venda','empresa_id',%L,'plano_contas_id',%L),'[{"vencimento":"2026-12-10","valor":0}]'::jsonb)$q$, :'orc2', :'emp', :'plano'));
SELECT pg_temp.tenta('origem legado_connect pela porta', format($q$SELECT financeiro_criar_titulo(jsonb_build_object('natureza','receber','origem_tipo','legado_connect','especie','venda','empresa_id',%L),'[{"vencimento":"2026-12-10","valor":10}]'::jsonb)$q$, :'emp'));

\echo '--- 2) confirmar previsao e baixar'
SELECT financeiro_confirmar_parcelas(:'t1') AS parcelas_confirmadas;
SELECT id AS p1 FROM financeiro_parcelas WHERE titulo_id = :'t1' AND numero = 1 \gset
SELECT id AS p2 FROM financeiro_parcelas WHERE titulo_id = :'t1' AND numero = 2 \gset
SELECT pg_temp.tenta('pagamento em titulo a receber', format($q$SELECT financeiro_baixar(%L,'pagamento',100,current_date,%L)$q$, :'p1', :'conta'));
SELECT pg_temp.tenta('baixa maior que o saldo', format($q$SELECT financeiro_baixar(%L,'recebimento',1000.01,current_date,%L)$q$, :'p1', :'conta'));
SELECT financeiro_baixar(:'p1', 'recebimento', 400, current_date, :'conta', 'pix') AS b1 \gset
SELECT valor_liquidado AS liquidado_depois_de_400, valor - valor_liquidado AS saldo FROM financeiro_parcelas WHERE id = :'p1';
SELECT financeiro_baixar(:'p1', 'baixa_interna', 600, current_date, NULL, NULL, 'acordo interno') AS b2 \gset
SELECT valor_liquidado AS liquidado_quitada FROM financeiro_parcelas WHERE id = :'p1';
SELECT pg_temp.tenta('baixa em parcela ja quitada', format($q$SELECT financeiro_baixar(%L,'recebimento',1,current_date,%L)$q$, :'p1', :'conta'));

\echo '--- 3) estornar'
SELECT pg_temp.tenta('estorno sem motivo', format($q$SELECT financeiro_estornar(%L,'')$q$, :'b1'));
SELECT financeiro_estornar(:'b1', 'lancado na conta errada') AS est \gset
SELECT valor_liquidado AS liquidado_depois_do_estorno FROM financeiro_parcelas WHERE id = :'p1';
SELECT pg_temp.tenta('estornar duas vezes', format($q$SELECT financeiro_estornar(%L,'de novo')$q$, :'b1'));

\echo '--- 4) substituir previsao e cancelar'
SELECT financeiro_criar_titulo(jsonb_build_object('natureza','pagar','origem_tipo','manual','especie','despesa','empresa_id',:'emp','plano_contas_id',:'plano','contato_id',:'cli'),
  '[{"vencimento":"2026-12-20","valor":300,"situacao":"prevista"}]'::jsonb) AS t2 \gset
SELECT financeiro_substituir_previsao(:'t2', '[{"vencimento":"2027-01-05","valor":150},{"vencimento":"2027-02-05","valor":150}]'::jsonb) AS novas;
SELECT numero, situacao, valor FROM financeiro_parcelas WHERE titulo_id = :'t2' ORDER BY numero;
SELECT pg_temp.tenta('cancelar sem motivo', format($q$SELECT financeiro_cancelar_titulo(%L,'')$q$, :'t2'));
SELECT pg_temp.tenta('cancelar titulo com baixa', format($q$SELECT financeiro_cancelar_titulo(%L,'teste')$q$, :'t1'));
SELECT financeiro_cancelar_titulo(:'t2', 'duplicado');
SELECT situacao, count(*) FROM financeiro_parcelas WHERE titulo_id = :'t2' GROUP BY 1 ORDER BY 1;

\echo '--- 5) pendencias'
SELECT financeiro_abrir_pendencia('teste', 'conferir', :'t1') AS pen \gset
SELECT pg_temp.tenta('aceitar sem motivo', format($q$SELECT financeiro_aceitar_pendencia(%L,'')$q$, :'pen'));
SELECT financeiro_resolver_pendencia(:'pen');
SELECT status FROM financeiro_pendencias WHERE id = :'pen';

\echo '--- 6) views e integridade (como admin)'
SELECT u.id AS adm FROM usuarios u WHERE u.role = 'admin' ORDER BY u.id LIMIT 1 \gset
SELECT set_config('request.jwt.claims', json_build_object('sub', :'adm', 'role', 'authenticated')::text, true);
SELECT count(*) AS a_receber_abertas FROM vw_contas_a_receber WHERE status IN ('a_vencer','parcial','vencida');
SELECT count(*) AS a_pagar_abertas FROM vw_contas_a_pagar;
SELECT tipo, data, valor, valor_com_sinal FROM vw_historico_baixas ORDER BY criado_em;
SELECT natureza, situacao_fluxo, grupo, valor FROM vw_fluxo_caixa ORDER BY 1, 2, 3;
SELECT teste, violacoes FROM vw_financeiro_novo_integridade ORDER BY violacoes DESC, teste;

\echo '--- 7) seguranca'
SELECT set_config('app.p2', :'p2', true);
SELECT set_config('request.jwt.claims', '{"sub":"ea9ae91b-324d-4b57-acd6-0904979ea38f","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT count(*) AS aux_estoque_ve_parcelas FROM vw_financeiro_parcelas;
SELECT count(*) AS aux_estoque_ve_integridade FROM vw_financeiro_novo_integridade;
DO $$ BEGIN PERFORM financeiro_baixar(current_setting('app.p2')::uuid, 'baixa_interna', 1, current_date, NULL, NULL, 'teste'); RAISE NOTICE 'FALHA: aux estoque executou';
  EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'ok recusou: aux estoque chamando porta unica (%)', left(SQLERRM, 60); END $$;
RESET ROLE;
SET LOCAL ROLE anon;
DO $$ BEGIN PERFORM financeiro_criar_titulo('{}'::jsonb, '[]'::jsonb); RAISE NOTICE 'FALHA: anon executou';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'ok anon barrado'; END $$;
RESET ROLE;

\echo '--- 8) nada existente mudou'
SELECT set_config('request.jwt.claims', '', true);
SELECT (SELECT count(*) FROM v_financeiro_realizado) AS linhas_view, (SELECT round(sum(vl_parcela), 2) FROM v_financeiro_realizado) AS soma_view;
ROLLBACK;
