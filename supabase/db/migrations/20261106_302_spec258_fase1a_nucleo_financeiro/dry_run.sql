-- SPEC-258 Fase 1A: dry-run (termina em ROLLBACK). Uso: psql "$SUPABASE_DB_URL" -X -f dry_run.sql (de dentro da pasta). Só literais ASCII.
\set ON_ERROR_STOP on
BEGIN;
\ir up.sql

-- dados de apoio (existentes) para os testes
SELECT (SELECT id FROM empresas LIMIT 1) AS emp, (SELECT id FROM plano_de_contas WHERE nivel = 3 LIMIT 1) AS plano,
       (SELECT id FROM contas_bancarias WHERE empresa_id IS NOT NULL LIMIT 1) AS conta, (SELECT id FROM contatos WHERE tipo = 'cliente' LIMIT 1) AS cli,
       (SELECT id FROM funcionarios LIMIT 1) AS func, (SELECT id FROM pedidos_compra LIMIT 1) AS ped \gset
SELECT id AS orc1 FROM orcamentos WHERE natureza_operacao = 'venda' ORDER BY id LIMIT 1 \gset
SELECT id AS orc2 FROM orcamentos WHERE natureza_operacao = 'venda' ORDER BY id OFFSET 1 LIMIT 1 \gset

\echo '--- 1) titulos: o que PASSA'
INSERT INTO financeiro_titulos (natureza, origem_tipo, orcamento_id, especie, empresa_id, plano_contas_id, contato_id) VALUES ('receber', 'orcamento', :'orc1', 'venda', :'emp', :'plano', :'cli');
INSERT INTO financeiro_titulos (natureza, origem_tipo, especie, empresa_id, legado_cod_duplicata, contato_id) VALUES ('pagar', 'legado_connect', 'despesa', :'emp', 123456, :'cli');
INSERT INTO financeiro_titulos (natureza, origem_tipo, pedido_compra_id, especie, empresa_id, plano_contas_id) VALUES ('pagar', 'pedido_compra', :'ped', 'compra', :'emp', :'plano');
SELECT count(*) AS titulos_ok FROM financeiro_titulos;

\echo '--- 2) titulos: o que o banco RECUSA (cada linha deve dizer ok recusou)'
CREATE OR REPLACE FUNCTION pg_temp.tenta(rotulo text, comando text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    EXECUTE comando;
    RAISE NOTICE 'FALHA: % foi ACEITO e nao devia', rotulo;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'ok recusou: % (%)', rotulo, left(SQLERRM, 70);
  END;
END $$;
SELECT pg_temp.tenta('titulo nativo SEM plano de contas', format($q$INSERT INTO financeiro_titulos (natureza, origem_tipo, orcamento_id, especie, empresa_id) VALUES ('receber','orcamento',%L,'venda',%L)$q$, :'orc2', :'emp'));
SELECT pg_temp.tenta('origem orcamento sem orcamento_id', format($q$INSERT INTO financeiro_titulos (natureza, origem_tipo, especie, empresa_id, plano_contas_id) VALUES ('receber','orcamento','venda',%L,%L)$q$, :'emp', :'plano'));
SELECT pg_temp.tenta('DUAS origens ao mesmo tempo', format($q$INSERT INTO financeiro_titulos (natureza, origem_tipo, orcamento_id, pedido_compra_id, especie, empresa_id, plano_contas_id) VALUES ('receber','orcamento',%L,%L,'venda',%L,%L)$q$, :'orc2', :'ped', :'emp', :'plano'));
SELECT pg_temp.tenta('orcamento gerando conta A PAGAR', format($q$INSERT INTO financeiro_titulos (natureza, origem_tipo, orcamento_id, especie, empresa_id, plano_contas_id) VALUES ('pagar','orcamento',%L,'venda',%L,%L)$q$, :'orc2', :'emp', :'plano'));
SELECT pg_temp.tenta('mesmo orcamento gerando 2 vezes', format($q$INSERT INTO financeiro_titulos (natureza, origem_tipo, orcamento_id, especie, empresa_id, plano_contas_id) VALUES ('receber','orcamento',%L,'venda',%L,%L)$q$, :'orc1', :'emp', :'plano'));
SELECT pg_temp.tenta('duplicata da Connect repetida (empresa+numero+natureza)', format($q$INSERT INTO financeiro_titulos (natureza, origem_tipo, especie, empresa_id, legado_cod_duplicata) VALUES ('pagar','legado_connect','despesa',%L,123456)$q$, :'emp'));
SELECT pg_temp.tenta('origem manual com numero da Connect', format($q$INSERT INTO financeiro_titulos (natureza, origem_tipo, especie, empresa_id, plano_contas_id, legado_cod_duplicata) VALUES ('pagar','manual','despesa',%L,%L,1)$q$, :'emp', :'plano'));
SELECT pg_temp.tenta('salario sem funcionario', format($q$INSERT INTO financeiro_titulos (natureza, origem_tipo, especie, empresa_id, plano_contas_id) VALUES ('pagar','manual','salario',%L,%L)$q$, :'emp', :'plano'));
SELECT pg_temp.tenta('pessoa E funcionario no mesmo titulo', format($q$INSERT INTO financeiro_titulos (natureza, origem_tipo, especie, empresa_id, plano_contas_id, contato_id, funcionario_id) VALUES ('pagar','manual','despesa',%L,%L,%L,%L)$q$, :'emp', :'plano', :'cli', :'func'));

\echo '--- 3) parcelas e baixas'
SELECT id AS t_orc FROM financeiro_titulos WHERE orcamento_id = :'orc1' \gset
INSERT INTO financeiro_parcelas (titulo_id, numero, vencimento, valor, situacao) VALUES (:'t_orc', 1, current_date + 30, 1000.00, 'prevista');
INSERT INTO financeiro_parcelas (titulo_id, numero, vencimento, valor, situacao, confirmada_em) VALUES (:'t_orc', 2, current_date + 60, 500.00, 'firme', now());
SELECT id AS p_prev FROM financeiro_parcelas WHERE titulo_id = :'t_orc' AND numero = 1 \gset
SELECT id AS p_firme FROM financeiro_parcelas WHERE titulo_id = :'t_orc' AND numero = 2 \gset
SELECT pg_temp.tenta('parcela repetida (mesmo titulo e numero)', format($q$INSERT INTO financeiro_parcelas (titulo_id, numero, vencimento, valor, situacao, confirmada_em) VALUES (%L,2,current_date,1,'firme',now())$q$, :'t_orc'));
SELECT pg_temp.tenta('parcela firme sem confirmacao', format($q$INSERT INTO financeiro_parcelas (titulo_id, numero, vencimento, valor, situacao) VALUES (%L,3,current_date,1,'firme')$q$, :'t_orc'));
SELECT pg_temp.tenta('BAIXA em parcela so prevista', format($q$INSERT INTO financeiro_baixas (parcela_id, tipo, data, valor, origem_baixa, conta_bancaria_id) VALUES (%L,'recebimento',current_date,10,'manual',%L)$q$, :'p_prev', :'conta'));
SELECT pg_temp.tenta('recebimento SEM conta bancaria', format($q$INSERT INTO financeiro_baixas (parcela_id, tipo, data, valor, origem_baixa) VALUES (%L,'recebimento',current_date,10,'manual')$q$, :'p_firme'));
SELECT pg_temp.tenta('baixa interna SEM motivo', format($q$INSERT INTO financeiro_baixas (parcela_id, tipo, data, valor, origem_baixa) VALUES (%L,'baixa_interna',current_date,10,'manual')$q$, :'p_firme'));
SELECT pg_temp.tenta('recebimento de valor ZERO', format($q$INSERT INTO financeiro_baixas (parcela_id, tipo, data, valor, origem_baixa, conta_bancaria_id) VALUES (%L,'recebimento',current_date,0,'manual',%L)$q$, :'p_firme', :'conta'));
SELECT pg_temp.tenta('estorno sem apontar a baixa', format($q$INSERT INTO financeiro_baixas (parcela_id, tipo, data, valor, origem_baixa, motivo, conta_bancaria_id) VALUES (%L,'estorno',current_date,10,'manual','x',%L)$q$, :'p_firme', :'conta'));

INSERT INTO financeiro_baixas (parcela_id, tipo, data, valor, origem_baixa, conta_bancaria_id, forma) VALUES (:'p_firme', 'recebimento', current_date, 200.00, 'manual', :'conta', 'Pix');
SELECT valor_liquidado AS liquidado_depois_de_200 FROM financeiro_parcelas WHERE id = :'p_firme';
INSERT INTO financeiro_baixas (parcela_id, tipo, data, valor, origem_baixa, motivo) VALUES (:'p_firme', 'baixa_interna', current_date, 300.00, 'manual', 'processo interno sem movimento de caixa');
SELECT valor_liquidado AS liquidado_depois_da_baixa_interna_de_300, valor AS valor_da_parcela FROM financeiro_parcelas WHERE id = :'p_firme';
SELECT sum(valor) FILTER (WHERE movimenta_caixa) AS entrou_no_caixa, sum(valor) AS quitado_total FROM financeiro_baixas WHERE parcela_id = :'p_firme';
SELECT id AS b200 FROM financeiro_baixas WHERE parcela_id = :'p_firme' AND tipo = 'recebimento' \gset
INSERT INTO financeiro_baixas (parcela_id, tipo, data, valor, origem_baixa, motivo, estorno_de, conta_bancaria_id) VALUES (:'p_firme', 'estorno', current_date, 200.00, 'manual', 'lancado errado', :'b200', :'conta');
SELECT valor_liquidado AS liquidado_depois_do_estorno FROM financeiro_parcelas WHERE id = :'p_firme';
SELECT pg_temp.tenta('EDITAR uma baixa', format($q$UPDATE financeiro_baixas SET valor = 1 WHERE id = %L$q$, :'b200'));
SELECT pg_temp.tenta('APAGAR uma baixa', format($q$DELETE FROM financeiro_baixas WHERE id = %L$q$, :'b200'));
SELECT pg_temp.tenta('digitar o valor liquidado a mao', format($q$UPDATE financeiro_parcelas SET valor_liquidado = 999 WHERE id = %L$q$, :'p_firme'));
SELECT pg_temp.tenta('mudar o valor de parcela com baixa', format($q$UPDATE financeiro_parcelas SET valor = 1 WHERE id = %L$q$, :'p_firme'));
SELECT pg_temp.tenta('mudar o numero da Connect (imutavel)', format($q$UPDATE financeiro_titulos SET legado_cod_duplicata = 1 WHERE legado_cod_duplicata = 123456$q$));

\echo '--- 4) historico permanente registrou tudo?'
SELECT tabela, count(*) FROM financeiro_eventos GROUP BY tabela ORDER BY tabela;

\echo '--- 5) seguranca: SEM gravacao direta, sem acesso para quem nao e do financeiro'
SELECT set_config('request.jwt.claims', '{"sub":"ea9ae91b-324d-4b57-acd6-0904979ea38f","role":"authenticated"}', true);   -- auxiliar de estoque
SET LOCAL ROLE authenticated;
SELECT count(*) AS titulos_vistos_pelo_aux_estoque FROM financeiro_titulos;
SELECT count(*) AS baixas_vistas_pelo_aux_estoque FROM financeiro_baixas;
DO $$ BEGIN INSERT INTO financeiro_titulos (natureza, origem_tipo, especie, empresa_id, legado_cod_duplicata) VALUES ('pagar','legado_connect','despesa',gen_random_uuid(),9);
  RAISE NOTICE 'FALHA: gravacao direta aceita'; EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'ok recusou: gravacao direta por usuario logado'; END $$;
RESET ROLE;
-- admin (Vinicius) enxerga
SELECT u.id AS adm FROM usuarios u WHERE u.role = 'admin' ORDER BY u.id LIMIT 1 \gset
SELECT set_config('request.jwt.claims', json_build_object('sub', :'adm', 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;
SELECT count(*) AS titulos_vistos_pelo_admin FROM financeiro_titulos;
RESET ROLE;
SET LOCAL ROLE anon;
DO $$ BEGIN PERFORM 1 FROM financeiro_titulos LIMIT 1; RAISE NOTICE 'FALHA: anon leu';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'ok anon barrado'; END $$;
RESET ROLE;

\echo '--- 6) nada existente mudou (claims limpos: a view restringe distribuicao de lucro por usuario)'
SELECT set_config('request.jwt.claims', '', true);
SELECT (SELECT count(*) FROM v_financeiro_realizado) AS linhas_view, (SELECT round(sum(vl_parcela), 2) FROM v_financeiro_realizado) AS soma_view;
ROLLBACK;
