-- SPEC-258 Fase 4c-2: dry-run do motor de RT (ROLLBACK). So ASCII.
\set ON_ERROR_STOP on
BEGIN;
SELECT count(*) AS linhas_antes, round(sum(vl_parcela), 2) AS soma_antes FROM v_financeiro_realizado_novo \gset
\ir up.sql
SELECT u.id AS adm FROM usuarios u WHERE u.role = 'admin' ORDER BY u.id LIMIT 1 \gset
SELECT set_config('request.jwt.claims', json_build_object('sub', :'adm', 'role', 'authenticated', 'email', 'filippo@lucenera.com.br')::text, true) \gset

\echo '--- 0) montagem: uma venda de teste (ORC com luminaria), 3 parcelas de 10.000, arquitetos: 1 normal + 1 NR'
SELECT '335af013-1b48-4e60-97d8-81a563649eac'::uuid AS orc \gset
SELECT '0767a003-4948-4cea-ae9f-24d3bd6d2217'::uuid AS arq1, 'b5e09594-9912-49ed-89ad-152c22432848'::uuid AS arq2, '47f42658-0fb4-4325-9f71-43d164c99f20'::uuid AS arqnr, '2c5482af-bc27-4bdb-9d6b-2645a647b12c'::uuid AS arq3 \gset
SELECT 'fafdc30c-173e-494d-81f5-194a45a1a68c'::uuid AS conta \gset
INSERT INTO financeiro_titulos (natureza, origem_tipo, origem_seq, orcamento_id, especie, empresa_id, contato_id, plano_contas_id, projeto_id, documento, descricao)
SELECT 'receber', 'orcamento', 99, t.orcamento_id, 'venda', t.empresa_id, t.contato_id, t.plano_contas_id, t.projeto_id, 'NF-TESTE', 'venda de teste do motor de RT'
  FROM financeiro_titulos t WHERE t.orcamento_id = :'orc' AND t.origem_seq = 1 LIMIT 1;
SELECT id AS tv FROM financeiro_titulos WHERE orcamento_id = :'orc' AND origem_seq = 99 \gset
INSERT INTO financeiro_parcelas (titulo_id, numero, vencimento, valor, situacao, confirmada_em) VALUES
  (:'tv', 1, current_date, 10000, 'firme', now()), (:'tv', 2, current_date + 30, 10000, 'firme', now()), (:'tv', 3, current_date + 60, 10000, 'firme', now());
SELECT id AS p1 FROM financeiro_parcelas WHERE titulo_id = :'tv' AND numero = 1 \gset
SELECT id AS p2 FROM financeiro_parcelas WHERE titulo_id = :'tv' AND numero = 2 \gset
SELECT id AS p3 FROM financeiro_parcelas WHERE titulo_id = :'tv' AND numero = 3 \gset
INSERT INTO orcamento_arquitetos (orcamento_id, arquiteto_id, percentual) VALUES (:'orc', :'arq1', 100), (:'orc', :'arqnr', 100);
SELECT round(financeiro_rt_fracao_categoria(:'orc', (SELECT id FROM categorias_produto WHERE nome = 'LUMINARIA')) * 100, 2) AS pct_luminaria_da_venda;

\echo '--- 1) recebimento de 10.000 -> arquiteto normal + NR dividem: ele recebe a METADE (esperado = 10000 x fracao x 10% / 2) e o NR nao gera nada'
SELECT financeiro_baixar(:'p1', 'recebimento', 10000, current_date, :'conta') IS NOT NULL AS recebeu;
SELECT b.id AS bx1 FROM financeiro_baixas b WHERE b.parcela_id = :'p1' AND b.tipo = 'recebimento' \gset
SELECT c.nome, p.numero, p.valor AS rt, round(10000 * financeiro_rt_fracao_categoria(:'orc', (SELECT id FROM categorias_produto WHERE nome = 'LUMINARIA')) * 0.10 / 2, 2) AS esperado,
       p.vencimento, p.situacao, p.observacao
  FROM financeiro_parcelas p JOIN financeiro_titulos t ON t.id = p.titulo_id JOIN contatos c ON c.id = t.contato_id WHERE t.titulo_base_id = :'tv' ORDER BY c.nome, p.numero;
SELECT count(*) AS titulos_rt_para_nr FROM financeiro_titulos WHERE titulo_base_id = :'tv' AND contato_id = :'arqnr';

\echo '--- 2) segundo arquiteto (12% so dele) entra na venda: divide por 3 (arq1, NR, arq2): a parte do NR nao e paga'
INSERT INTO orcamento_arquitetos (orcamento_id, arquiteto_id, percentual) VALUES (:'orc', :'arq2', 100);
SELECT financeiro_definir_rt(:'arq2', 12, 'liquido', 'proporcional_recebido', NULL, false, 'teste 12%') IS NOT NULL AS regra12;
SELECT financeiro_baixar(:'p2', 'recebimento', 10000, current_date, :'conta') IS NOT NULL AS recebeu2;
SELECT b.id AS bx2 FROM financeiro_baixas b WHERE b.parcela_id = :'p2' AND b.tipo = 'recebimento' \gset
SELECT c.nome, p.numero, p.valor AS rt,
       round(10000 * financeiro_rt_fracao_categoria(:'orc', (SELECT id FROM categorias_produto WHERE nome = 'LUMINARIA')) * (CASE WHEN c.id = :'arq2' THEN 0.12 ELSE 0.10 END) / 3, 2) AS esperado_dividido_por_3
  FROM financeiro_parcelas p JOIN financeiro_titulos t ON t.id = p.titulo_id JOIN contatos c ON c.id = t.contato_id WHERE t.titulo_base_id = :'tv' AND p.baixa_origem_id = :'bx2' ORDER BY c.nome;

\echo '--- 3) idempotencia: reprocessar a mesma baixa nao duplica'
SELECT financeiro_rt_processar_baixa(:'bx1') AS gerou_de_novo, (SELECT count(*) FROM financeiro_parcelas WHERE baixa_origem_id = :'bx1') AS parcelas_da_baixa1;

\echo '--- 4) estorno do recebimento 2 (RT ainda nao pago): as 2 parcelas de RT ficam canceladas'
SELECT financeiro_estornar(:'bx2', 'teste estorno') IS NOT NULL AS estornou;
SELECT p.situacao, count(*) FROM financeiro_parcelas p WHERE p.baixa_origem_id = :'bx2' GROUP BY 1;

\echo '--- 5) RT da baixa 1 ja PAGO e depois o recebimento e estornado: nasce parcela NEGATIVA'
SELECT p.id AS prt1 FROM financeiro_parcelas p WHERE p.baixa_origem_id = :'bx1' AND p.valor > 0 \gset
SELECT financeiro_baixar(:'prt1', 'pagamento', (SELECT valor FROM financeiro_parcelas WHERE id = :'prt1'), current_date, :'conta') IS NOT NULL AS pagou_rt;
SELECT financeiro_estornar(:'bx1', 'teste estorno com RT pago') IS NOT NULL AS estornou1;
SELECT p.numero, p.valor, p.situacao, p.observacao FROM financeiro_parcelas p JOIN financeiro_titulos t ON t.id = p.titulo_id WHERE t.titulo_base_id = :'tv' AND t.contato_id = :'arq1' ORDER BY p.numero;

\echo '--- 6) arquiteto marcado como inativo no RT nao recebe mais'
SELECT financeiro_rt_definir_ativo(:'arq1', false, 'teste inativo');
SELECT financeiro_baixar(:'p3', 'recebimento', 10000, current_date, :'conta') IS NOT NULL AS recebeu3;
SELECT c.nome, p.valor FROM financeiro_parcelas p JOIN financeiro_titulos t ON t.id = p.titulo_id JOIN contatos c ON c.id = t.contato_id
 WHERE t.titulo_base_id = :'tv' AND p.baixa_origem_id = (SELECT id FROM financeiro_baixas WHERE parcela_id = :'p3' AND tipo = 'recebimento');
SELECT recebe_rt, eh_nr FROM vw_financeiro_rt_arquitetos WHERE contato_id IN (:'arq1', :'arqnr') ORDER BY eh_nr;

\echo '--- 7) RT manual (arquiteto sem vinculo no projeto)'
SELECT financeiro_rt_lancar_manual(:'orc', :'arq3', 150.50, current_date + 20, 'RT combinado fora do vinculo') IS NOT NULL AS lancou_manual;
SELECT t.origem_tipo, t.especie, p.valor, p.situacao FROM financeiro_titulos t JOIN financeiro_parcelas p ON p.titulo_id = t.id WHERE t.contato_id = :'arq3' AND t.especie = 'rt_arquiteto';

\echo '--- 8) relatorio (liquidez) e previsto por venda'
SELECT arquiteto, parcela_numero, parcelas_total, valor_recebido, comissao, pagar_em, situacao FROM vw_financeiro_rt_relatorio WHERE titulo_venda_id = :'tv' ORDER BY arquiteto, pagar_em;
SELECT arquiteto, percentual, pct_luminaria, valor_venda, rt_previsto_total, rt_gerado FROM vw_financeiro_rt_previsto_venda WHERE titulo_venda_id = :'tv' ORDER BY arquiteto;

\echo '--- 9) integridade (tudo 0) e modelo novo coerente'
SELECT * FROM vw_financeiro_ponte_rt_integridade;
SELECT teste, violacoes FROM vw_financeiro_novo_integridade WHERE coalesce(violacoes, 0) <> 0;
SELECT * FROM vw_financeiro_ponte_integridade WHERE violacoes <> 0;

\echo '--- 10) seguranca: usuario sem financeiro e anon'
SELECT set_config('request.jwt.claims', '{"sub":"ea9ae91b-324d-4b57-acd6-0904979ea38f","role":"authenticated"}', true) \gset
SET LOCAL ROLE authenticated;
SELECT count(*) AS aux_ve_relatorio FROM vw_financeiro_rt_relatorio;
SELECT count(*) AS aux_ve_previsto FROM vw_financeiro_rt_previsto_venda;
DO $$ BEGIN PERFORM financeiro_rt_lancar_manual('335af013-1b48-4e60-97d8-81a563649eac', '2c5482af-bc27-4bdb-9d6b-2645a647b12c', 10, current_date); RAISE NOTICE 'FALHA: aux lancou RT';
  EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'ok aux barrado: %', SQLERRM; END $$;
DO $$ BEGIN PERFORM financeiro_rt_processar_baixa(gen_random_uuid()); RAISE NOTICE 'FALHA: motor chamavel por usuario';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'ok motor interno barrado'; END $$;
RESET ROLE;
SET LOCAL ROLE anon;
DO $$ BEGIN PERFORM 1 FROM vw_financeiro_rt_relatorio LIMIT 1; RAISE NOTICE 'FALHA: anon leu relatorio';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'ok anon barrado'; END $$;
RESET ROLE;

SELECT set_config('request.jwt.claims', '', true) \gset
\echo '--- 11) o que ja existia nao mudou (view nova do realizado: linhas e soma sem contar a venda de teste)'
SELECT (SELECT count(*) FROM v_financeiro_realizado_novo) - :linhas_antes AS linhas_a_mais_so_do_teste;
ROLLBACK;
