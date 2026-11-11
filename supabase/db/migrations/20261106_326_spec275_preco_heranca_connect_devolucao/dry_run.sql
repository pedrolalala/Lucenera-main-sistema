-- SPEC-275: roda up.sql dentro de transação, mostra o resultado e DESFAZ (ROLLBACK).
BEGIN;
\i up.sql
SELECT count(*) FILTER (WHERE coalesce(pi.preco_unitario,0) = 0) AS ainda_zerados, count(*) AS total_connect
  FROM public.projeto_itens pi JOIN public.orcamentos o ON o.id = pi.orcamento_id AND o.origem = 'connect';
SELECT o.numero_venda, sum(pi.subtotal) AS soma_itens FROM public.projeto_itens pi JOIN public.orcamentos o ON o.id = pi.orcamento_id
 WHERE o.numero_venda IN ('CNX-4640','CNX-4865') GROUP BY 1;
ROLLBACK;
