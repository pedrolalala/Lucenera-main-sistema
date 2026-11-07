-- SPEC-258 Fase 5c: dry-run (ROLLBACK). So ASCII.
\set ON_ERROR_STOP on
BEGIN;
SELECT u.id AS adm FROM usuarios u WHERE u.role = 'admin' ORDER BY u.id LIMIT 1 \gset
SELECT set_config('request.jwt.claims', json_build_object('sub', :'adm', 'role', 'authenticated', 'email', 'filippo@lucenera.com.br')::text, true) \gset

\echo '--- 0) ANTES: snapshot do desconto por parcela (view atual, 309)'
CREATE TEMP TABLE antes AS SELECT parcela_id, desconto, status, valor_pago FROM vw_financeiro_duplicatas;
SELECT count(*) AS linhas_antes, count(*) FILTER (WHERE desconto > 0) AS com_desconto_antes FROM antes;

\ir up.sql
SELECT set_config('request.jwt.claims', json_build_object('sub', :'adm', 'role', 'authenticated', 'email', 'filippo@lucenera.com.br')::text, true) \gset

\echo '--- 1) mesmas linhas; so o desconto pode mudar; colunas de dinheiro intactas'
SELECT count(*) AS linhas_depois, (SELECT count(*) FROM antes) AS linhas_antes FROM vw_financeiro_duplicatas;
SELECT count(*) AS mudou_status_ou_valor_pago FROM vw_financeiro_duplicatas d JOIN antes a USING (parcela_id) WHERE d.status IS DISTINCT FROM a.status OR d.valor_pago IS DISTINCT FROM a.valor_pago;
SELECT count(*) AS desconto_mudou FROM vw_financeiro_duplicatas d JOIN antes a USING (parcela_id) WHERE d.desconto IS DISTINCT FROM a.desconto;
\echo '    (esperado: desconto_mudou = 0 no legado, porque ja tem p.desconto = abatimento; nenhuma soma em dobro)'
SELECT count(*) AS legado_com_desconto_dobrado FROM vw_financeiro_duplicatas d JOIN antes a USING (parcela_id) WHERE a.desconto > 0 AND d.desconto > a.desconto;

\echo '--- 2) baixa nativa com desconto 1: a view passa a mostrar desconto 1; estorno volta a 0'
SELECT p.id AS parc, cb.id AS conta, t.empresa_id AS emp
  FROM financeiro_parcelas p JOIN financeiro_titulos t ON t.id = p.titulo_id
  JOIN contas_bancarias cb ON cb.empresa_id = t.empresa_id
 WHERE t.natureza = 'receber' AND p.situacao = 'firme' AND p.valor_liquidado = 0 AND p.desconto = 0 AND p.valor > 10 AND NOT EXISTS (SELECT 1 FROM financeiro_baixas x WHERE x.parcela_id = p.id)
 ORDER BY p.valor LIMIT 1 \gset
SELECT financeiro_baixar_lote(ARRAY[:'parc']::uuid[], current_date, 'PIX', :'conta', 2, 1, NULL, 'dry-run 5c');
SELECT desconto AS desconto_apos_baixa, valor_pago, status FROM vw_financeiro_duplicatas WHERE parcela_id = :'parc';
SELECT b.id AS baixa_abat FROM financeiro_baixas b WHERE b.parcela_id = :'parc' AND b.tipo = 'abatimento' \gset
SELECT b.id AS baixa_rec FROM financeiro_baixas b WHERE b.parcela_id = :'parc' AND b.tipo = 'recebimento' \gset
SELECT financeiro_estornar(:'baixa_rec', 'dry-run 5c'); SELECT financeiro_estornar(:'baixa_abat', 'dry-run 5c');
SELECT desconto AS desconto_apos_estorno, valor_pago, status FROM vw_financeiro_duplicatas WHERE parcela_id = :'parc';

\echo '--- 3) seguranca: anon sem acesso'
SELECT has_table_privilege('anon', 'public.vw_financeiro_duplicatas', 'SELECT') AS anon_le;
ROLLBACK;
