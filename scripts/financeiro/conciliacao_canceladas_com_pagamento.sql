-- SPEC-258: CONCILIACAO das parcelas CANCELADAS COM PAGAMENTO (somente leitura). Resultado de 06/11/2026 nos comentarios (C1..C8).
-- Uso: export PGCLIENTENCODING=UTF8; psql "$SUPABASE_DB_URL" -X -A -F' | ' -f scripts/financeiro/conciliacao_canceladas_com_pagamento.sql
-- C1 807 (R$ 2,87 mi): copia cancelada de parcela com o MESMO codigo ativa (728 gemea paga: a Connect bate com a gemea em 726; 79 gemea aberta)
-- C4 57 (R$ 226 mil): substituida por parcela paga com o mesmo valor | C6 12 (R$ 11 mil): a Connect tambem cancelou | C7 617 (R$ 1,96 mi): parcela removida mas o total pago por duplicata e IGUAL no banco e na Connect
-- C8 1.527 (R$ 4,29 mi): duplicata inteira AUSENTE da Connect e nao contada em outro lugar => precisa de conferencia do Financeiro
\set ON_ERROR_STOP on
CREATE TEMP TABLE cand AS
SELECT t.id, t.tipo::text AS tipo, n.cod_duplicata, n.cod_pessoa, n.contato_id, t.cod_itens_duplicata, t.num_parc, t.vl_parcela, t.vl_pago,
       t.dt_pagamento::date AS dt_pgto, t.tipo_pagamento, t.negociacao_id
FROM transacoes t JOIN negociacoes n ON n.id = t.negociacao_id WHERE t.status_pago = 2 AND t.vl_pago > 0;

CREATE TEMP TABLE cls AS
SELECT c.*,
  EXISTS (SELECT 1 FROM transacoes o WHERE o.id <> c.id AND o.cod_itens_duplicata = c.cod_itens_duplicata AND o.tipo::text = c.tipo AND o.status_pago <> 2) AS g1,
  EXISTS (SELECT 1 FROM transacoes o JOIN negociacoes x ON x.id = o.negociacao_id WHERE o.id <> c.id AND x.cod_duplicata = c.cod_duplicata AND o.tipo::text = c.tipo AND o.status_pago = 1 AND abs(o.vl_pago - c.vl_pago) <= 0.01 AND o.dt_pagamento::date = c.dt_pgto) AS g2,
  EXISTS (SELECT 1 FROM transacoes o JOIN negociacoes x ON x.id = o.negociacao_id WHERE o.id <> c.id AND x.cod_duplicata = c.cod_duplicata AND o.tipo::text = c.tipo AND o.status_pago = 1 AND o.num_parc = c.num_parc AND abs(o.vl_parcela - c.vl_parcela) <= 0.01) AS g3,
  EXISTS (SELECT 1 FROM connect_contas_espelho e WHERE e.cod_duplicata = c.cod_duplicata AND e.tipo = c.tipo) AS dup_no_esp,
  (SELECT e.pago FROM connect_contas_espelho e WHERE e.cod_itens_duplicata = c.cod_itens_duplicata AND e.tipo = c.tipo) AS pago_esp,
  EXISTS (SELECT 1 FROM connect_contas_espelho e WHERE e.cod_duplicata = c.cod_duplicata AND e.tipo = c.tipo AND e.pago = 1 AND abs(coalesce(e.vl_pago, 0) - c.vl_pago) <= 0.01 AND e.cod_itens_duplicata <> c.cod_itens_duplicata) AS g4
FROM cand c;
ALTER TABLE cls ADD COLUMN classe text;
UPDATE cls SET classe = CASE WHEN g1 THEN 'C1' WHEN g2 THEN 'C2' WHEN g3 THEN 'C3' WHEN g4 THEN 'C4' WHEN pago_esp = 1 THEN 'C5' WHEN pago_esp IS NOT NULL THEN 'C6' WHEN dup_no_esp THEN 'C7' ELSE 'C8' END;
\echo '=== A. C1: como esta a GEMEA ativa (mesmo codigo de parcela)?'
SELECT c.tipo, CASE WHEN o.status_pago = 1 AND abs(o.vl_pago - c.vl_pago) <= 0.01 THEN '1 gemea PAGA com o mesmo valor (duplicidade pura)'
                    WHEN o.status_pago = 1 THEN '2 gemea paga com valor DIFERENTE'
                    ELSE '3 gemea ABERTA' END AS situacao_gemea, count(*) AS parcelas, round(sum(c.vl_pago)) AS valor_pago_da_cancelada
FROM cls c JOIN LATERAL (SELECT o.* FROM transacoes o WHERE o.id <> c.id AND o.cod_itens_duplicata = c.cod_itens_duplicata AND o.tipo::text = c.tipo AND o.status_pago <> 2 ORDER BY (o.status_pago = 1) DESC LIMIT 1) o ON true
WHERE c.classe = 'C1' GROUP BY 1, 2 ORDER BY 1, 2;

\echo '=== B. C4/C7/C8: o MESMO pagamento (mesma pessoa, valor e data) ja esta contado em OUTRA parcela ativa e paga?'
CREATE TEMP TABLE dobro AS
SELECT c.id, EXISTS (SELECT 1 FROM transacoes o JOIN negociacoes x ON x.id = o.negociacao_id
                      WHERE o.id <> c.id AND o.tipo::text = c.tipo AND o.status_pago = 1 AND abs(o.vl_pago - c.vl_pago) <= 0.01
                        AND o.dt_pagamento::date = c.dt_pgto AND (x.cod_pessoa = c.cod_pessoa OR x.contato_id = c.contato_id)) AS ja_contado
FROM cls c WHERE c.classe IN ('C4', 'C7', 'C8');
SELECT c.classe, c.tipo, count(*) AS parcelas, count(*) FILTER (WHERE d.ja_contado) AS ja_contado_em_outra, round(sum(c.vl_pago)) AS valor,
       round(sum(c.vl_pago) FILTER (WHERE d.ja_contado)) AS valor_ja_contado, round(sum(c.vl_pago) FILTER (WHERE NOT d.ja_contado)) AS valor_NAO_contado_em_outro_lugar
FROM cls c JOIN dobro d ON d.id = c.id GROUP BY 1, 2 ORDER BY 1, 2;

\echo '=== C. C7: total PAGO no espelho x total PAGO ativo no banco, por duplicata'
WITH d AS (SELECT DISTINCT cod_duplicata, tipo FROM cls WHERE classe = 'C7'),
esp AS (SELECT e.cod_duplicata, e.tipo, sum(CASE WHEN e.pago = 1 THEN e.vl_pago ELSE 0 END) pago_esp FROM connect_contas_espelho e JOIN d ON d.cod_duplicata = e.cod_duplicata AND d.tipo = e.tipo GROUP BY 1, 2),
bco AS (SELECT n.cod_duplicata, t.tipo::text tipo, sum(CASE WHEN t.status_pago = 1 THEN t.vl_pago ELSE 0 END) pago_bco FROM transacoes t JOIN negociacoes n ON n.id = t.negociacao_id JOIN d ON d.cod_duplicata = n.cod_duplicata AND d.tipo = t.tipo::text GROUP BY 1, 2)
SELECT d.tipo, count(*) AS duplicatas,
  count(*) FILTER (WHERE abs(coalesce(esp.pago_esp, 0) - coalesce(bco.pago_bco, 0)) <= 0.01) AS pago_igual_banco_e_connect,
  count(*) FILTER (WHERE coalesce(bco.pago_bco, 0) > coalesce(esp.pago_esp, 0) + 0.01) AS banco_MAIOR_que_connect,
  count(*) FILTER (WHERE coalesce(bco.pago_bco, 0) < coalesce(esp.pago_esp, 0) - 0.01) AS banco_MENOR_que_connect,
  round(sum(coalesce(bco.pago_bco, 0) - coalesce(esp.pago_esp, 0))) AS diferenca_banco_menos_connect
FROM d LEFT JOIN esp ON esp.cod_duplicata = d.cod_duplicata AND esp.tipo = d.tipo LEFT JOIN bco ON bco.cod_duplicata = d.cod_duplicata AND bco.tipo = d.tipo GROUP BY 1;

\echo '=== D. receita C7 e C8 por forma de pagamento'
SELECT classe, coalesce(nullif(tipo_pagamento, ''), '(vazio)') AS forma, count(*), round(sum(vl_pago)) FROM cls WHERE classe IN ('C7', 'C8') AND tipo = 'receita' GROUP BY 1, 2 ORDER BY 1, 3 DESC LIMIT 12;

\echo '=== F. C1 com gemea PAGA de valor diferente: quem bate com a Connect (espelho)? cancelada, gemea ou nenhuma'
SELECT count(*) AS parcelas,
  count(*) FILTER (WHERE abs(coalesce(e.vl_pago,0) - o.vl_pago) <= 0.01) AS espelho_igual_a_GEMEA_ativa,
  count(*) FILTER (WHERE abs(coalesce(e.vl_pago,0) - c.vl_pago) <= 0.01) AS espelho_igual_a_CANCELADA,
  count(*) FILTER (WHERE abs(coalesce(e.vl_pago,0) - o.vl_pago) > 0.01 AND abs(coalesce(e.vl_pago,0) - c.vl_pago) > 0.01) AS espelho_igual_a_nenhuma,
  round(sum(c.vl_pago)) AS soma_pago_cancelada, round(sum(o.vl_pago)) AS soma_pago_gemea, round(sum(e.vl_pago)) AS soma_pago_connect
FROM cls c JOIN LATERAL (SELECT o.* FROM transacoes o WHERE o.id <> c.id AND o.cod_itens_duplicata = c.cod_itens_duplicata AND o.tipo::text = c.tipo AND o.status_pago = 1 ORDER BY o.vl_pago DESC LIMIT 1) o ON true
LEFT JOIN connect_contas_espelho e ON e.cod_itens_duplicata = c.cod_itens_duplicata AND e.tipo = c.tipo
WHERE c.classe = 'C1';

\echo '=== G. C4: a parcela que a Connect mostra como paga (substituta) esta no banco? em que situacao?'
SELECT c.tipo, count(*) AS canceladas_c4,
  count(*) FILTER (WHERE s.cod_itens_duplicata IS NULL) AS substituta_ausente_do_banco,
  count(*) FILTER (WHERE t.status_pago = 1) AS substituta_paga_no_banco,
  count(*) FILTER (WHERE t.status_pago = 0) AS substituta_aberta_no_banco,
  count(*) FILTER (WHERE t.status_pago = 2) AS substituta_cancelada_no_banco,
  round(sum(c.vl_pago)) AS valor
FROM cls c
JOIN LATERAL (SELECT e.* FROM connect_contas_espelho e WHERE e.cod_duplicata = c.cod_duplicata AND e.tipo = c.tipo AND e.pago = 1 AND abs(coalesce(e.vl_pago,0) - c.vl_pago) <= 0.01 AND e.cod_itens_duplicata <> c.cod_itens_duplicata LIMIT 1) s ON true
LEFT JOIN transacoes t ON t.cod_itens_duplicata = s.cod_itens_duplicata AND t.tipo::text = c.tipo
WHERE c.classe = 'C4' GROUP BY 1;
