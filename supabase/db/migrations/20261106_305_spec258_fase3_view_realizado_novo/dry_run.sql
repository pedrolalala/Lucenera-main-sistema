-- SPEC-258 Fase 3 passo 1: dry-run (ROLLBACK). Compara a view NOVA com a ANTIGA, coluna a coluna. So ASCII.
\set ON_ERROR_STOP on
BEGIN;
\ir up.sql
SELECT u.id AS adm FROM usuarios u WHERE u.role = 'admin' ORDER BY u.id LIMIT 1 \gset
SELECT set_config('request.jwt.claims', json_build_object('sub', :'adm', 'role', 'authenticated', 'email', 'filippo@lucenera.com.br')::text, true) \gset

\echo '--- 1) linhas'
SELECT (SELECT count(*) FROM v_financeiro_realizado) AS antiga, (SELECT count(*) FROM v_financeiro_realizado_novo) AS nova;
CREATE TEMP TABLE o AS SELECT * FROM v_financeiro_realizado;
CREATE TEMP TABLE n AS SELECT * FROM v_financeiro_realizado_novo;
\echo '--- 2) ids que existem so de um lado (deve ser 0 e 0)'
SELECT (SELECT count(*) FROM o WHERE id NOT IN (SELECT id FROM n)) AS so_na_antiga, (SELECT count(*) FROM n WHERE id NOT IN (SELECT id FROM o)) AS so_na_nova;
\echo '--- 3) diferencas por coluna (deve ser 0 em todas)'
SELECT count(*) FILTER (WHERE o.tipo IS DISTINCT FROM n.tipo) tipo, count(*) FILTER (WHERE o.descricao IS DISTINCT FROM n.descricao) descricao,
       count(*) FILTER (WHERE o.desc_sub_grupo IS DISTINCT FROM n.desc_sub_grupo) sub_grupo, count(*) FILTER (WHERE o.desc_grupo IS DISTINCT FROM n.desc_grupo) grupo,
       count(*) FILTER (WHERE o.natureza IS DISTINCT FROM n.natureza) natureza, count(*) FILTER (WHERE o.status_pago IS DISTINCT FROM n.status_pago) status_pago,
       count(*) FILTER (WHERE o.dt_pagamento IS DISTINCT FROM n.dt_pagamento) dt_pagamento, count(*) FILTER (WHERE o.dt_vencimento IS DISTINCT FROM n.dt_vencimento) dt_venc,
       count(*) FILTER (WHERE o.dt_emissao IS DISTINCT FROM n.dt_emissao) dt_emissao, count(*) FILTER (WHERE round(coalesce(o.vl_pago,0),2) IS DISTINCT FROM round(coalesce(n.vl_pago,0),2)) vl_pago,
       count(*) FILTER (WHERE round(o.vl_parcela,2) IS DISTINCT FROM round(n.vl_parcela,2)) vl_parcela, count(*) FILTER (WHERE round(coalesce(o.vl_desconto,0),2) IS DISTINCT FROM round(coalesce(n.vl_desconto,0),2)) vl_desconto,
       count(*) FILTER (WHERE o.empresa_id IS DISTINCT FROM n.empresa_id) empresa, count(*) FILTER (WHERE o.cod_duplicata IS DISTINCT FROM n.cod_duplicata) cod_dup,
       count(*) FILTER (WHERE o.tipo_custo IS DISTINCT FROM n.tipo_custo) tipo_custo, count(*) FILTER (WHERE o.perfil IS DISTINCT FROM n.perfil) perfil,
       count(*) FILTER (WHERE o.previsao IS DISTINCT FROM n.previsao) previsao
FROM o JOIN n USING (id);
\echo '--- 4) exemplos das diferencas de data de pagamento / desconto (ate 5)'
SELECT o.id, o.status_pago, o.dt_pagamento AS dt_antiga, n.dt_pagamento AS dt_nova, o.vl_desconto AS desc_antigo, n.vl_desconto AS desc_novo
FROM o JOIN n USING (id) WHERE o.dt_pagamento IS DISTINCT FROM n.dt_pagamento OR round(coalesce(o.vl_desconto,0),2) IS DISTINCT FROM round(coalesce(n.vl_desconto,0),2) LIMIT 5;
\echo '--- 5) seguranca: sem permissao no dashboard-financeiro a view nova nao devolve nada'
SELECT set_config('request.jwt.claims', '{"sub":"ea9ae91b-324d-4b57-acd6-0904979ea38f","role":"authenticated"}', true) \gset
SET LOCAL ROLE authenticated;
SELECT count(*) AS aux_estoque_ve FROM v_financeiro_realizado_novo;
RESET ROLE;
SET LOCAL ROLE anon;
DO $$ BEGIN PERFORM 1 FROM v_financeiro_realizado_novo LIMIT 1; RAISE NOTICE 'FALHA: anon leu';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'ok anon barrado'; END $$;
RESET ROLE;
ROLLBACK;
