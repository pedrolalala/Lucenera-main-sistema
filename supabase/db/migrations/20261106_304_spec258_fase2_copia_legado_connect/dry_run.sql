-- SPEC-258 Fase 2: dry-run (termina em ROLLBACK). Roda DENTRO da pasta. So ASCII.
\set ON_ERROR_STOP on
BEGIN;
\timing on
\ir up.sql
\timing off

\echo '--- 1) contagens (esperado: parcelas 19372 = 18316 ativas + 1056 canceladas)'
SELECT (SELECT count(*) FROM financeiro_titulos) titulos, (SELECT count(*) FROM financeiro_parcelas) parcelas,
       (SELECT count(*) FROM financeiro_parcelas WHERE situacao <> 'cancelada') parcelas_ativas, (SELECT count(*) FROM financeiro_parcelas WHERE situacao = 'cancelada') parcelas_canceladas,
       (SELECT count(*) FROM financeiro_baixas) baixas, (SELECT count(*) FROM financeiro_titulos WHERE cancelado_em IS NOT NULL) titulos_cancelados;
SELECT tipo, count(*), round(sum(valor), 2) valor, round(sum(juros), 2) juros FROM financeiro_baixas GROUP BY 1 ORDER BY 1;

\echo '--- 2) PROVA contra o baseline (linhas / soma das parcelas)'
SELECT (SELECT count(*) FROM v_financeiro_realizado) AS view_linhas, (SELECT round(sum(vl_parcela), 2) FROM v_financeiro_realizado) AS view_soma,
       (SELECT count(*) FROM financeiro_parcelas WHERE situacao <> 'cancelada') AS novo_linhas, (SELECT round(sum(valor), 2) FROM financeiro_parcelas WHERE situacao <> 'cancelada') AS novo_soma;

\echo '--- 3) PROVA do realizado: dinheiro (valor+juros) das baixas = soma vl_pago das pagas da view; diferenca deve ser 0'
SELECT (SELECT round(sum(vl_pago), 2) FROM v_financeiro_realizado WHERE status_pago = 1) AS view_pago,
       (SELECT round(sum(valor + juros), 2) FROM financeiro_baixas WHERE movimenta_caixa) AS novo_pago_caixa,
       (SELECT count(*) FROM v_financeiro_realizado WHERE status_pago = 1 AND vl_pago > 0) AS view_pagas_com_valor,
       (SELECT count(*) FROM financeiro_baixas WHERE movimenta_caixa) AS novo_baixas_caixa;

\echo '--- 4) PROVA por natureza x mes x empresa: diferencas (deve ser 0 linhas)'
WITH v AS (
  SELECT n.empresa_id, CASE WHEN r.tipo::text = 'receita' THEN 'receber' ELSE 'pagar' END AS natureza,
         date_trunc('month', coalesce(r.dt_pagamento, r.dt_vencimento))::date AS mes, round(sum(r.vl_pago), 2) AS valor
  FROM v_financeiro_realizado r JOIN transacoes t ON t.id = r.id JOIN negociacoes n ON n.id = t.negociacao_id
  WHERE r.status_pago = 1 AND r.vl_pago > 0 GROUP BY 1, 2, 3),
nv AS (
  SELECT ti.empresa_id, ti.natureza::text AS natureza, date_trunc('month', b.data)::date AS mes, round(sum(b.valor + b.juros), 2) AS valor
  FROM financeiro_baixas b JOIN financeiro_parcelas p ON p.id = b.parcela_id JOIN financeiro_titulos ti ON ti.id = p.titulo_id
  WHERE b.movimenta_caixa GROUP BY 1, 2, 3)
SELECT count(*) AS grupos_diferentes FROM v FULL JOIN nv USING (empresa_id, natureza, mes) WHERE v.valor IS DISTINCT FROM nv.valor;

\echo '--- 5) PROVA por situacao: pagas, abertas e quitadas batem com a view'
SELECT (SELECT count(*) FROM v_financeiro_realizado WHERE status_pago = 1) AS view_pagas, (SELECT count(*) FROM financeiro_parcelas WHERE situacao = 'firme' AND valor_liquidado >= valor AND legado_cod_itens_duplicata IS NOT NULL) AS novo_quitadas,
       (SELECT count(*) FROM v_financeiro_realizado WHERE status_pago = 0) AS view_abertas, (SELECT count(*) FROM financeiro_parcelas WHERE situacao = 'firme' AND valor_liquidado < valor) AS novo_abertas,
       (SELECT count(*) FROM financeiro_parcelas WHERE situacao = 'firme' AND valor_liquidado = 0 AND valor = 0) AS parcelas_valor_zero_sem_baixa;

\echo '--- 6) PROVA ids: cada parcela tem seu codigo da Connect, e cada transacao migrada tem de-para'
SELECT (SELECT count(*) FROM financeiro_parcelas WHERE legado_cod_itens_duplicata IS NULL) AS parcela_sem_codigo,
       (SELECT count(*) FROM financeiro_legado_ids WHERE tabela_antiga = 'transacoes') AS depara_transacoes,
       (SELECT count(*) FROM financeiro_legado_ids WHERE tabela_antiga = 'negociacoes') AS depara_negociacoes,
       (SELECT count(*) FROM financeiro_parcelas p WHERE p.legado_cod_itens_duplicata NOT IN (SELECT cod_itens_duplicata FROM connect_contas_espelho)) AS parcela_fora_do_espelho;

\echo '--- 7) PROVA contra a Connect: situacao do espelho x do banco novo (deve ser tudo coerente)'
SELECT e.pago AS espelho_pago, p.situacao, (p.valor_liquidado >= p.valor) AS quitada, count(*)
FROM financeiro_parcelas p JOIN financeiro_titulos t ON t.id = p.titulo_id
JOIN connect_contas_espelho e ON e.cod_itens_duplicata = p.legado_cod_itens_duplicata AND e.tipo = CASE t.natureza WHEN 'receber' THEN 'receita' ELSE 'despesa' END
GROUP BY 1, 2, 3 ORDER BY 1, 2, 3;

\echo '--- 8) pendencias abertas'
SELECT tipo, count(*) FROM financeiro_pendencias GROUP BY 1 ORDER BY 1;

\echo '--- 9) integridade (como admin): todas as regras com 0 violacoes'
SELECT u.id AS adm FROM usuarios u WHERE u.role = 'admin' ORDER BY u.id LIMIT 1 \gset
SELECT set_config('request.jwt.claims', json_build_object('sub', :'adm', 'role', 'authenticated')::text, true) \gset
SELECT teste, violacoes FROM vw_financeiro_novo_integridade WHERE violacoes > 0 ORDER BY violacoes DESC;
SELECT count(*) AS regras_verificadas FROM vw_financeiro_novo_integridade;
SELECT status, count(*) FROM vw_contas_a_receber GROUP BY 1 ORDER BY 1;
SELECT count(*) AS fluxo_linhas FROM vw_fluxo_caixa;
SELECT set_config('request.jwt.claims', '', true) \gset

\echo '--- 10) nada antigo mudou'
SELECT (SELECT count(*) FROM v_financeiro_realizado) AS linhas_view, (SELECT round(sum(vl_parcela), 2) FROM v_financeiro_realizado) AS soma_view,
       (SELECT count(*) FROM transacoes) AS transacoes, (SELECT count(*) FROM negociacoes) AS negociacoes;
ROLLBACK;
