-- SPEC-258 Fase 4b: dry-run (ROLLBACK). Os gatilhos sao adiados para o fim da transacao: "SET CONSTRAINTS ALL IMMEDIATE" os dispara aqui. So ASCII.
\set ON_ERROR_STOP on
BEGIN;
\ir up.sql
SELECT u.id AS adm FROM usuarios u WHERE u.role = 'admin' ORDER BY u.id LIMIT 1 \gset
SELECT (SELECT id FROM contas_bancarias WHERE empresa_id IS NOT NULL LIMIT 1) AS conta \gset

\echo '--- 1) carga do que ja existia'
SELECT origem_tipo, count(*) titulos, count(*) FILTER (WHERE cancelado_em IS NOT NULL) cancelados FROM financeiro_titulos WHERE origem_tipo IN ('pedido_compra', 'nota_fiscal_compra') GROUP BY 1 ORDER BY 1;
SELECT p.situacao, count(*), round(sum(p.valor), 2) FROM financeiro_parcelas p JOIN financeiro_titulos t ON t.id = p.titulo_id WHERE t.origem_tipo IN ('pedido_compra', 'nota_fiscal_compra') GROUP BY 1 ORDER BY 1;
SELECT count(*) AS falhas FROM financeiro_ponte_falhas WHERE origem <> 'transacoes';
SELECT set_config('request.jwt.claims', json_build_object('sub', :'adm', 'role', 'authenticated', 'email', 'filippo@lucenera.com.br')::text, true) \gset
SELECT teste, violacoes FROM vw_financeiro_ponte_pagar_integridade ORDER BY violacoes DESC, teste;
SELECT set_config('request.jwt.claims', '', true) \gset

\echo '--- 2) cenario NOTA: pedido aprovado com 2+ parcelas; nota entra, e paga, desfaz, cancela'
SELECT p.id AS ped, p.fornecedor_id AS forn, p.empresa_id AS emp FROM pedidos_compra p WHERE p.status = 'aprovado' AND p.numero NOT LIKE 'PC-LEGADO-%' AND p.empresa_id IS NOT NULL
  AND (SELECT count(*) FROM pedido_compra_parcelas x WHERE x.pedido_id = p.id AND x.status = 'pendente') >= 2 ORDER BY p.numero LIMIT 1 \gset
SELECT round(sum(p.valor), 2) AS previsao_antes FROM financeiro_parcelas p JOIN financeiro_titulos t ON t.id = p.titulo_id WHERE t.pedido_compra_id = :'ped' AND p.situacao = 'prevista';
SELECT round(valor / 2, 2) AS meia FROM pedido_compra_parcelas WHERE pedido_id = :'ped' AND status = 'pendente' ORDER BY numero_parcela LIMIT 1 \gset
INSERT INTO notas_fiscais_compra (pedido_compra_id, numero_nf, data_emissao, valor, fornecedor_id, empresa_id) VALUES (:'ped', 'TESTE-4B-1', current_date, :'meia', :'forn', :'emp') RETURNING id AS nota \gset
INSERT INTO nota_fiscal_compra_parcelas (nota_id, numero_parcela, data_vencimento, valor) VALUES (:'nota', 1, current_date + 20, :'meia');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SELECT t.especie, count(p.id) parcelas, round(sum(p.valor), 2) valor, bool_and(p.situacao = 'firme') todas_firmes FROM financeiro_titulos t JOIN financeiro_parcelas p ON p.titulo_id = t.id WHERE t.nota_fiscal_compra_id = :'nota' GROUP BY 1;
SELECT round(sum(p.valor), 2) AS previsao_depois_da_nota FROM financeiro_parcelas p JOIN financeiro_titulos t ON t.id = p.titulo_id WHERE t.pedido_compra_id = :'ped' AND p.situacao = 'prevista';
SELECT count(*) AS boletos_cp_da_nota FROM boletos WHERE conta_grupo_id = :'nota' AND tipo_operacao = 'CP';
UPDATE boletos SET status = 'Pago', valor_pago = :'meia', data_pagamento = current_date, conta_bancaria_id = :'conta' WHERE conta_grupo_id = :'nota' AND tipo_operacao = 'CP';
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SELECT b.tipo, b.valor, b.origem_baixa, p.valor_liquidado FROM financeiro_baixas b JOIN financeiro_parcelas p ON p.id = b.parcela_id JOIN financeiro_titulos t ON t.id = p.titulo_id WHERE t.nota_fiscal_compra_id = :'nota';
\echo '    cancelar a nota PAGA deve ser recusado pelo espelho (vira falha visivel, a nota antiga cancela)'
UPDATE notas_fiscais_compra SET cancelada_em = now() WHERE id = :'nota';
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SELECT count(*) AS falhas_visiveis, max(erro) AS erro FROM financeiro_ponte_falhas WHERE origem = 'notas_fiscais_compra' AND transacao_id = :'nota';
UPDATE notas_fiscais_compra SET cancelada_em = NULL WHERE id = :'nota';
UPDATE boletos SET status = 'Pendente', valor_pago = NULL, data_pagamento = NULL WHERE conta_grupo_id = :'nota' AND tipo_operacao = 'CP';
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SELECT b.tipo, b.valor, p.valor_liquidado FROM financeiro_baixas b JOIN financeiro_parcelas p ON p.id = b.parcela_id JOIN financeiro_titulos t ON t.id = p.titulo_id WHERE t.nota_fiscal_compra_id = :'nota' ORDER BY b.criado_em, b.tipo;
UPDATE notas_fiscais_compra SET cancelada_em = now() WHERE id = :'nota';
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SELECT (t.cancelado_em IS NOT NULL) titulo_cancelado, (SELECT round(sum(p.valor), 2) FROM financeiro_parcelas p JOIN financeiro_titulos x ON x.id = p.titulo_id WHERE x.pedido_compra_id = :'ped' AND p.situacao = 'prevista') AS previsao_restaurada
FROM financeiro_titulos t WHERE t.nota_fiscal_compra_id = :'nota';

\echo '--- 3) cenario POP-UP: pedido vira recebido; pergunta; responde NAO e SIM'
SELECT t.pedido_compra_id AS peda FROM financeiro_titulos t JOIN pedidos_compra p ON p.id = t.pedido_compra_id WHERE t.origem_tipo = 'pedido_compra' AND p.status = 'aprovado' AND t.pedido_compra_id <> :'ped' AND EXISTS (SELECT 1 FROM financeiro_parcelas x WHERE x.titulo_id = t.id AND x.situacao = 'prevista') ORDER BY p.numero LIMIT 1 \gset
SELECT t.pedido_compra_id AS pedb FROM financeiro_titulos t JOIN pedidos_compra p ON p.id = t.pedido_compra_id WHERE t.origem_tipo = 'pedido_compra' AND p.status = 'aprovado' AND t.pedido_compra_id NOT IN (:'ped', :'peda') AND EXISTS (SELECT 1 FROM financeiro_parcelas x WHERE x.titulo_id = t.id AND x.situacao = 'prevista') ORDER BY p.numero LIMIT 1 \gset
SELECT set_config('app.pedb', :'pedb', true) AS _ \gset
UPDATE pedidos_compra SET status = 'recebido' WHERE id IN (:'peda', :'pedb');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SELECT (financeiro_pedido_pergunta(:'peda')->>'perguntar') AS pergunta_peda, jsonb_array_length(financeiro_pedido_pergunta(:'peda')->'parcelas_previstas') AS previstas_peda;
SELECT financeiro_responder_pedido_pago(:'peda', false) AS baixas_resposta_nao;
SELECT (financeiro_pedido_pergunta(:'peda')->>'perguntar') AS pergunta_peda_depois, jsonb_array_length(financeiro_pedido_pergunta(:'peda')->'parcelas_previstas') AS continuam_previstas;
SELECT round(sum(p.valor), 2) AS valor_previsto_pedb FROM financeiro_parcelas p JOIN financeiro_titulos t ON t.id = p.titulo_id WHERE t.pedido_compra_id = :'pedb' AND p.situacao = 'prevista';
SELECT financeiro_responder_pedido_pago(:'pedb', true, current_date, :'conta', 'teste') AS baixas_resposta_sim;
SELECT p.situacao, count(*), round(sum(p.valor_liquidado), 2) liquidado FROM financeiro_parcelas p JOIN financeiro_titulos t ON t.id = p.titulo_id WHERE t.pedido_compra_id = :'pedb' GROUP BY 1 ORDER BY 1;
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SELECT count(*) AS previstas_pedb_apos_recalculo FROM financeiro_parcelas p JOIN financeiro_titulos t ON t.id = p.titulo_id WHERE t.pedido_compra_id = :'pedb' AND p.situacao = 'prevista';
DO $$ BEGIN PERFORM financeiro_responder_pedido_pago(current_setting('app.pedb')::uuid, true, current_date); RAISE NOTICE 'FALHA: respondeu duas vezes';
  EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'ok recusou: responder duas vezes (%)', left(SQLERRM, 60); END $$;

\echo '--- 4) integridade e seguranca'
SELECT set_config('request.jwt.claims', json_build_object('sub', :'adm', 'role', 'authenticated', 'email', 'filippo@lucenera.com.br')::text, true) \gset
SELECT teste, violacoes FROM vw_financeiro_ponte_pagar_integridade WHERE violacoes > 0;
SELECT teste, violacoes FROM vw_financeiro_novo_integridade WHERE violacoes > 0 AND teste NOT LIKE 'pendencias%';
SELECT teste, violacoes FROM vw_financeiro_ponte_integridade WHERE violacoes > 0;
SELECT set_config('request.jwt.claims', '{"sub":"ea9ae91b-324d-4b57-acd6-0904979ea38f","role":"authenticated"}', true) \gset
SET LOCAL ROLE authenticated;
SELECT count(*) AS aux_estoque_ve_integridade FROM vw_financeiro_ponte_pagar_integridade;
DO $$ BEGIN PERFORM financeiro_pedido_pergunta(gen_random_uuid()); RAISE NOTICE 'FALHA: aux estoque perguntou';
  EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'ok recusou: aux estoque na pergunta (%)', left(SQLERRM, 40); END $$;
RESET ROLE;
SET LOCAL ROLE anon;
DO $$ BEGIN PERFORM financeiro_responder_pedido_pago(gen_random_uuid(), false); RAISE NOTICE 'FALHA: anon respondeu';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'ok anon barrado'; END $$;
RESET ROLE;
SELECT set_config('request.jwt.claims', '', true) \gset
SELECT (SELECT count(*) FROM v_financeiro_realizado) AS linhas_view_antiga, (SELECT round(sum(vl_parcela), 2) FROM v_financeiro_realizado) AS soma_view_antiga;
ROLLBACK;
