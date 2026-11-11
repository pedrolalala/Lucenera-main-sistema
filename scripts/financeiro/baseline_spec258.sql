-- SPEC-258: LINHA DE BASE do financeiro (SOMENTE LEITURA). Reexecutar antes de qualquer migration e depois de cada fase para comparar.
-- Uso (de dentro da raiz do repositório central, com o .env carregado, sem imprimir segredos):
--   export PGCLIENTENCODING=UTF8; psql "$SUPABASE_DB_URL" -X -A -F' | ' -f scripts/financeiro/baseline_spec258.sql
-- Valores medidos em 06/11/2026 estão nos comentários "(06/11: ...)" para comparação.
-- Só literais ASCII (o psql no Windows quebra com acento em linha de comando/literal).
\set ON_ERROR_STOP on

\echo '=== 0. MARCO (ultima carga da planilha da Connect) ==='
SELECT encerrado_em FROM connect_financeiro_encerrado;                                   -- (06/11: 2026-11-05 19:01:57+00)

\echo '=== 1. OS LUGARES ONDE HA DINHEIRO (linhas) ==='
SELECT 'negociacoes' AS tabela, count(*) AS linhas FROM negociacoes                       -- 14.028
UNION ALL SELECT 'transacoes', count(*) FROM transacoes                                   -- 23.338
UNION ALL SELECT 'projeto_parcelas', count(*) FROM projeto_parcelas                       -- 387
UNION ALL SELECT 'boletos', count(*) FROM boletos                                         -- 4
UNION ALL SELECT 'pedido_compra_parcelas', count(*) FROM pedido_compra_parcelas           -- 70
UNION ALL SELECT 'nota_fiscal_compra_parcelas', count(*) FROM nota_fiscal_compra_parcelas -- 3
UNION ALL SELECT 'custos_recorrentes_lancamentos', count(*) FROM custos_recorrentes_lancamentos -- 0
UNION ALL SELECT 'folha_pagamento', count(*) FROM folha_pagamento                         -- 771
UNION ALL SELECT 'vendas (legado)', count(*) FROM vendas                                  -- 263
UNION ALL SELECT 'pedido_compra (legado)', count(*) FROM pedido_compra                    -- 247
UNION ALL SELECT 'staging_pedido_compra', count(*) FROM staging_pedido_compra             -- 435
UNION ALL SELECT 'remessas', count(*) FROM remessas                                       -- 0
UNION ALL SELECT 'retornos_processados', count(*) FROM retornos_processados               -- 2
UNION ALL SELECT 'projeto_sinal', count(*) FROM projeto_sinal                             -- 0
UNION ALL SELECT 'pagamentos_antecipados', count(*) FROM pagamentos_antecipados           -- 0
UNION ALL SELECT 'connect_contas_espelho', count(*) FROM connect_contas_espelho           -- 19.372
UNION ALL SELECT 'stg_duplicatas_vigentes', count(*) FROM stg_duplicatas_vigentes         -- 10.403
UNION ALL SELECT 'notas_fiscais_connect_duplicatas', count(*) FROM notas_fiscais_connect_duplicatas -- 809
UNION ALL SELECT 'financeiro_posicao_diaria', count(*) FROM financeiro_posicao_diaria;    -- 18.667

\echo '=== 2. NUCLEO: transacoes por tipo e situacao (status_pago 0=aberta 1=paga 2=cancelada) ==='
SELECT tipo, status_pago, count(*) AS parcelas, round(sum(vl_parcela)) AS soma_vl_parcela, round(sum(vl_pago)) AS soma_vl_pago
FROM transacoes GROUP BY tipo, status_pago ORDER BY tipo, status_pago;
-- (06/11) receita: 0=459 (R$ 2.851.488) | 1=4.592 (R$ 35.673.337) | 2=3.602 (R$ 12.375.420)
-- (06/11) despesa: 0=1.238 (R$ 4.082.025) | 1=12.376 (R$ 33.949.316) | 2=1.071 (R$ 10.295.822)

\echo '=== 3. VIEW DO FLUXO (a prova de que nada mudou na migracao) ==='
SELECT count(*) AS linhas, sum(vl_parcela) AS soma_vl_parcela FROM v_financeiro_realizado;  -- (06/11: 18.316 linhas | 75.203.769,77)

\echo '=== 4. HISTORICO DE PAGAMENTOS ==='
SELECT count(*) AS pagamentos, min(dt_pagamento) AS primeiro, max(dt_pagamento) AS ultimo FROM transacoes WHERE status_pago = 1;
-- (06/11: 16.968 | 2024-08-16 | 2026-12-19 [data futura: defeito])

\echo '=== 5. VINCULOS QUE FALTAM HOJE ==='
SELECT 'negociacoes sem plano de contas' AS problema, count(*) AS qtd FROM negociacoes WHERE plano_contas_id IS NULL        -- 245
UNION ALL SELECT 'negociacoes sem projeto', count(*) FROM negociacoes WHERE projeto_id IS NULL                              -- 10.566
UNION ALL SELECT 'negociacoes sem orcamento', count(*) FROM negociacoes WHERE orcamento_id IS NULL                          -- 14.027
UNION ALL SELECT 'negociacoes sem pessoa', count(*) FROM negociacoes WHERE contato_id IS NULL AND funcionario_id IS NULL     -- 1
UNION ALL SELECT 'transacoes sem conta bancaria', count(*) FROM transacoes WHERE conta_id IS NULL                           -- 1.923
UNION ALL SELECT 'transacoes PAGAS sem conta bancaria', count(*) FROM transacoes WHERE status_pago = 1 AND conta_id IS NULL -- 982
UNION ALL SELECT 'transacoes com categoria_id (campo morto)', count(categoria_id) FROM transacoes                           -- 0
UNION ALL SELECT 'boletos sem parcela_id', count(*) FROM boletos WHERE parcela_id IS NULL                                   -- 4
UNION ALL SELECT 'projeto_parcelas sem transacao_id', count(*) FROM projeto_parcelas WHERE transacao_id IS NULL             -- 387
UNION ALL SELECT 'projeto_parcelas sem orcamento_id', count(*) FROM projeto_parcelas WHERE orcamento_id IS NULL             -- 387
UNION ALL SELECT 'cod_itens_duplicata repetidos (nao canceladas)', count(*) FROM (SELECT cod_itens_duplicata FROM transacoes WHERE status_pago <> 2 AND cod_itens_duplicata IS NOT NULL GROUP BY 1 HAVING count(*) > 1) x; -- 2.768

\echo '=== 6. PESSOA COM TIPO INCOMPATIVEL ==='
SELECT n.tipo AS tipo_duplicata, coalesce(c.tipo::text, '(sem tipo)') AS tipo_contato, count(*) AS qtd
FROM negociacoes n JOIN contatos c ON c.id = n.contato_id GROUP BY 1, 2 ORDER BY 1, 3 DESC;
-- (06/11) receita: cliente 5.650 | arquiteto 72 | fornecedor 11 -- despesa: fornecedor 5.084 | cliente 1.723 | arquiteto 987

\echo '=== 7. DADOS COM DEFEITO ==='
SELECT 'pagas com data de pagamento no futuro' AS defeito, count(*) AS qtd FROM transacoes WHERE status_pago = 1 AND dt_pagamento > current_date  -- 1
UNION ALL SELECT 'vencimento com ano absurdo (<2015 ou >2035)', count(*) FROM transacoes WHERE dt_vencimento < '2015-01-01' OR dt_vencimento > '2035-12-31' -- 22
UNION ALL SELECT 'pagas sem data de pagamento', count(*) FROM transacoes WHERE status_pago = 1 AND dt_pagamento IS NULL;                                  -- 5

\echo '=== 8. RT HISTORICO (plano de contas RT, despesa) ==='
SELECT count(*) AS titulos, count(*) FILTER (WHERE cod_venda = 0) AS cod_venda_zero, count(*) FILTER (WHERE cod_venda IS NULL) AS cod_venda_nulo,
       count(projeto_id) AS com_projeto, count(orcamento_id) AS com_orcamento
FROM negociacoes WHERE tipo = 'despesa' AND plano_contas_id IN (SELECT id FROM plano_de_contas WHERE nome = 'RT');
-- (06/11) 1.168 titulos | 956 cod_venda=0 | 212 nulo | 0 projeto | 0 orcamento  => RT NUNCA foi ligado a venda
SELECT round(sum(t.vl_parcela)) AS valor_rt_nao_cancelado
FROM negociacoes n JOIN transacoes t ON t.negociacao_id = n.id AND t.status_pago <> 2
WHERE n.tipo = 'despesa' AND n.plano_contas_id IN (SELECT id FROM plano_de_contas WHERE nome = 'RT');  -- (06/11) R$ 1.814.829 (762 titulos a contato arquiteto = R$ 1.376.536)

\echo '=== 8B. RT por tipo de contato e RT lancado como receita ==='
SELECT coalesce(c.tipo::text, '(sem)') AS tipo_contato, count(DISTINCT n.id) AS titulos, round(sum(t.vl_parcela)) AS valor
FROM negociacoes n LEFT JOIN contatos c ON c.id = n.contato_id JOIN transacoes t ON t.negociacao_id = n.id AND t.status_pago <> 2
WHERE n.tipo = 'despesa' AND n.plano_contas_id IN (SELECT id FROM plano_de_contas WHERE nome = 'RT') GROUP BY 1 ORDER BY 3 DESC;
-- (06/11) arquiteto 762 (R$ 1.376.536) | fornecedor 93 (R$ 304.636) | cliente 78 (R$ 126.761) | sem tipo 3 (R$ 6.895)
SELECT count(DISTINCT n.id) AS titulos_rt_em_receita, round(sum(t.vl_parcela)) AS valor
FROM negociacoes n JOIN transacoes t ON t.negociacao_id = n.id AND t.status_pago <> 2
WHERE n.tipo = 'receita' AND n.plano_contas_id IN (SELECT id FROM plano_de_contas WHERE nome = 'RT'); -- (06/11) 20 titulos | R$ 106.624

\echo '=== 9. ARQUITETOS, COMISSAO E FOLHA ==='
SELECT 'projeto_arquitetos (vinculos)' AS item, count(*) AS qtd, count(DISTINCT arquiteto_id) AS distintos, min(percentual) AS pmin, max(percentual) AS pmax FROM projeto_arquitetos; -- 2.276 | 633 | 100 | 100
SELECT 'funcionarios_financeiro com comissao %' AS item, count(*) FILTER (WHERE comissao_percentual > 0) AS qtd, max(comissao_percentual) AS maximo FROM funcionarios_financeiro; -- 13 | 5,5
SELECT 'folha_pagamento' AS item, count(*) AS linhas, count(DISTINCT (ano, mes)) AS meses, round(sum(salario_liquido)) AS soma_liquido, round(sum(comissao)) AS soma_comissao FROM folha_pagamento; -- 771 | 49 | 6.181.898 | 0

\echo '=== 10. CONTAS BANCARIAS ==='
SELECT count(*) AS contas FROM contas_bancarias;                                          -- 4
