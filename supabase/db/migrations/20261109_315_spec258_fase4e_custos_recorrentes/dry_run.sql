-- SPEC-258 Fase 4e: dry-run (ROLLBACK). So ASCII.
\set ON_ERROR_STOP on
BEGIN;
CREATE TEMP TABLE antes_cnt AS SELECT (SELECT count(*) FROM financeiro_titulos) AS tit, (SELECT count(*) FROM financeiro_parcelas) AS par, (SELECT count(*) FROM financeiro_baixas) AS bx,
       (SELECT count(*) FROM v_financeiro_realizado_novo) AS rea, (SELECT count(*) FROM custos_recorrentes) AS cad;
\ir up.sql
SELECT u.id AS adm FROM usuarios u WHERE u.role = 'admin' ORDER BY u.id LIMIT 1 \gset
SELECT set_config('request.jwt.claims', json_build_object('sub', :'adm', 'role', 'authenticated', 'email', 'filippo@lucenera.com.br')::text, true) \gset

\echo '--- 1) cadastro carregado do historico'
SELECT count(*) AS custos, round(sum(valor)) AS valor_mensal, count(*) FILTER (WHERE empresa_id IS NULL OR plano_contas_id IS NULL) AS incompletos, count(*) FILTER (WHERE origem <> 'historico') AS outros FROM custos_recorrentes;
SELECT pc.nome AS plano, count(*) AS n, round(sum(cr.valor)) AS mensal FROM custos_recorrentes cr JOIN plano_de_contas pc ON pc.id = cr.plano_contas_id GROUP BY 1 ORDER BY 3 DESC;
SELECT count(*) AS consorcio_ou_emprestimo FROM custos_recorrentes cr JOIN plano_de_contas pc ON pc.id = cr.plano_contas_id WHERE pc.nome ILIKE 'CONS_RCIO' OR pc.nome ILIKE 'EMPR_STIMO';

\echo '--- 2) previsoes geradas pela carga (6 meses a frente): por mes, nenhuma vencida, uma parcela por titulo'
SELECT to_char(p.vencimento, 'YYYY-MM') AS mes, count(*) AS previstas, round(sum(p.valor)) AS valor FROM financeiro_titulos t JOIN financeiro_parcelas p ON p.titulo_id = t.id
 WHERE t.origem_tipo = 'custo_recorrente' AND t.cancelado_em IS NULL GROUP BY 1 ORDER BY 1;
SELECT count(*) AS vencidas_geradas FROM financeiro_titulos t JOIN financeiro_parcelas p ON p.titulo_id = t.id WHERE t.origem_tipo = 'custo_recorrente' AND p.vencimento < current_date;
SELECT (SELECT count(*) FROM financeiro_titulos) - (SELECT tit FROM antes_cnt) AS titulos_novos, (SELECT count(*) FROM financeiro_parcelas) - (SELECT par FROM antes_cnt) AS parcelas_novas;

\echo '--- 3) quem NAO gerou em algum mes por ja ter conta real (contratos parcelados etc.)'
SELECT count(*) AS custos_sem_previsao_em_algum_mes FROM custos_recorrentes cr
 WHERE (SELECT count(*) FROM financeiro_titulos t WHERE t.custo_recorrente_id = cr.id AND t.cancelado_em IS NULL) < 6;

\echo '--- 4) idempotente: rodar de novo nao cria nada'
SELECT financeiro_recorrentes_gerar_interno(6);

\echo '--- 5) Dashboard/Fluxo: a view nova ganha as previsoes (marcadas como previsao)'
SELECT (SELECT count(*) FROM v_financeiro_realizado_novo) - (SELECT rea FROM antes_cnt) AS linhas_novas_na_view,
       (SELECT count(*) FROM v_financeiro_realizado_novo v WHERE v.previsao IS TRUE) AS com_flag_previsao;
SELECT count(*) AS na_view_tipo_despesa_status_aberto FROM v_financeiro_realizado_novo v WHERE v.status_pago = 0 AND v.id IN (SELECT p.id FROM financeiro_parcelas p JOIN financeiro_titulos t ON t.id = p.titulo_id WHERE t.origem_tipo = 'custo_recorrente');

\echo '--- 6) mudar valor e dia do cadastro: a previsao acompanha'
SELECT cr.id AS cr1, cr.valor AS v_ant FROM custos_recorrentes cr ORDER BY cr.valor DESC LIMIT 1 \gset
UPDATE custos_recorrentes SET valor = valor + 100, dia_vencimento = 27 WHERE id = :'cr1';
SELECT financeiro_recorrentes_gerar_interno(6);
SELECT count(*) AS previstas_com_valor_novo, min(p.valor) = :'v_ant'::numeric + 100 AS valor_ok, max(extract(day FROM p.vencimento)) AS dia_max
  FROM financeiro_titulos t JOIN financeiro_parcelas p ON p.titulo_id = t.id WHERE t.custo_recorrente_id = :'cr1' AND t.cancelado_em IS NULL;

\echo '--- 7) parcela CONFIRMADA (firme) nao e alterada por mudanca de cadastro'
SELECT p.id AS par_firme, t.id AS tit_firme FROM financeiro_titulos t JOIN financeiro_parcelas p ON p.titulo_id = t.id WHERE t.custo_recorrente_id = :'cr1' AND t.cancelado_em IS NULL ORDER BY p.vencimento LIMIT 1 \gset
SELECT financeiro_confirmar_parcelas(:'tit_firme');
UPDATE custos_recorrentes SET valor = :'v_ant'::numeric + 200 WHERE id = :'cr1';
SELECT financeiro_recorrentes_gerar_interno(6);
SELECT p.valor = :'v_ant'::numeric + 100 AS firme_manteve_valor, p.situacao FROM financeiro_parcelas p WHERE p.id = :'par_firme';
SELECT count(*) AS demais_previstas_com_200 FROM financeiro_titulos t JOIN financeiro_parcelas p ON p.titulo_id = t.id WHERE t.custo_recorrente_id = :'cr1' AND t.cancelado_em IS NULL AND p.situacao = 'prevista' AND p.valor = :'v_ant'::numeric + 200;

\echo '--- 8) conta REAL chega no mes: a previsao daquele mes e cancelada e nao volta'
SELECT cr.id AS cr2, cr.empresa_id AS emp2, cr.contato_id AS ct2, cr.plano_contas_id AS pl2 FROM custos_recorrentes cr WHERE cr.id <> :'cr1' ORDER BY cr.valor DESC LIMIT 1 \gset
SELECT p.vencimento AS venc2 FROM financeiro_titulos t JOIN financeiro_parcelas p ON p.titulo_id = t.id WHERE t.custo_recorrente_id = :'cr2' AND t.cancelado_em IS NULL ORDER BY p.vencimento LIMIT 1 \gset
SELECT financeiro_criar_titulo(jsonb_build_object('natureza', 'pagar', 'origem_tipo', 'manual', 'especie', 'despesa', 'empresa_id', :'emp2', 'contato_id', nullif(:'ct2', ''), 'plano_contas_id', :'pl2', 'descricao', 'teste conta real'),
       jsonb_build_array(jsonb_build_object('vencimento', :'venc2', 'valor', 123.45, 'situacao', 'firme'))) AS titulo_real;
SELECT financeiro_recorrentes_gerar_interno(6);
SELECT count(*) AS previsao_do_mes_ativa FROM financeiro_titulos t JOIN financeiro_parcelas p ON p.titulo_id = t.id
 WHERE t.custo_recorrente_id = :'cr2' AND t.cancelado_em IS NULL AND date_trunc('month', p.vencimento) = date_trunc('month', :'venc2'::date);
SELECT t.motivo_cancelamento FROM financeiro_titulos t JOIN financeiro_parcelas p ON p.titulo_id = t.id WHERE t.custo_recorrente_id = :'cr2' AND t.cancelado_em IS NOT NULL AND date_trunc('month', p.vencimento) = date_trunc('month', :'venc2'::date);
SELECT financeiro_recorrentes_gerar_interno(6);

\echo '--- 9) desativar um custo: previsoes futuras ainda previstas sao canceladas'
SELECT cr.id AS cr3 FROM custos_recorrentes cr WHERE cr.id NOT IN (:'cr1', :'cr2') ORDER BY cr.valor DESC LIMIT 1 \gset
UPDATE custos_recorrentes SET ativo = false WHERE id = :'cr3';
SELECT financeiro_recorrentes_gerar_interno(6);
SELECT count(*) AS previsoes_ativas_do_custo_inativo FROM financeiro_titulos WHERE custo_recorrente_id = :'cr3' AND cancelado_em IS NULL;

\echo '--- 10) integridade (recorrentes, modelo novo, ponte) e permissoes'
SELECT * FROM vw_financeiro_recorrentes_integridade;
SELECT * FROM vw_financeiro_novo_integridade WHERE violacoes > 0 AND teste NOT LIKE 'pendencias abertas%';
SELECT * FROM vw_financeiro_ponte_integridade WHERE violacoes > 0;
SELECT has_function_privilege('anon', 'public.financeiro_recorrentes_gerar_interno(integer)', 'EXECUTE') AS anon_interno,
       has_function_privilege('authenticated', 'public.financeiro_recorrentes_gerar_interno(integer)', 'EXECUTE') AS auth_interno,
       has_function_privilege('anon', 'public.financeiro_gerar_recorrentes(integer)', 'EXECUTE') AS anon_tela,
       has_function_privilege('authenticated', 'public.financeiro_gerar_recorrentes(integer)', 'EXECUTE') AS auth_tela;
SELECT jobname, schedule FROM cron.job WHERE jobname = 'financeiro_recorrentes_gerar';

ROLLBACK;
