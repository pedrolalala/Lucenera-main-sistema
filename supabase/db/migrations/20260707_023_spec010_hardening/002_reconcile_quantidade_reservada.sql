-- Migration 20260707_023 - Parte 2
-- SPEC-010 hardening: reconcilia estoque_itens.quantidade_reservada com a
-- soma dos saldos abertos por projeto_item_id.
--
-- Guard rail: em 2026-07-07, a verificacao no Supabase real encontrou
-- exatamente quatro produtos divergentes. Se o conjunto mudar antes da
-- aplicacao, esta migration falha para forcar nova revisao manual.

DO $$
DECLARE
  v_unexpected_count integer;
BEGIN
  CREATE TEMP TABLE tmp_spec010_expected_reconciliation (
    codigo_produto integer PRIMARY KEY
  ) ON COMMIT DROP;

  INSERT INTO tmp_spec010_expected_reconciliation (codigo_produto)
  VALUES
    (13578),
    (9543),
    (5322),
    (9022);

  WITH open_saldos AS (
    SELECT
      pi.produto_id,
      SUM(esp.q_reserva + esp.q_entrega_futura + esp.q_ag_separar + esp.q_separado) AS qtd_aberta
    FROM public.estoque_saldos_projeto_item esp
    JOIN public.projeto_itens pi ON pi.id = esp.projeto_item_id
    WHERE esp.status_operacional = 'ativo'
    GROUP BY pi.produto_id
  ),
  recon AS (
    SELECT
      coalesce(os.produto_id, ei.produto_id) AS produto_id,
      coalesce(os.qtd_aberta, 0) AS qtd_aberta,
      coalesce(ei.quantidade_reservada, 0) AS quantidade_reservada
    FROM open_saldos os
    FULL JOIN public.estoque_itens ei
      ON ei.produto_id = os.produto_id
     AND ei.local = 'Estoque'::public.estoque_local
  ),
  divergentes AS (
    SELECT p.codigo_produto
    FROM recon
    JOIN public.produtos p ON p.id = recon.produto_id
    WHERE abs(recon.qtd_aberta - recon.quantidade_reservada) > 0.001
  ),
  inesperados AS (
    SELECT codigo_produto FROM divergentes
    EXCEPT
    SELECT codigo_produto FROM tmp_spec010_expected_reconciliation
  ),
  ausentes AS (
    SELECT codigo_produto FROM tmp_spec010_expected_reconciliation
    EXCEPT
    SELECT codigo_produto FROM divergentes
  )
  SELECT count(*) INTO v_unexpected_count
  FROM (
    SELECT codigo_produto FROM inesperados
    UNION ALL
    SELECT codigo_produto FROM ausentes
  ) diff;

  IF v_unexpected_count > 0 THEN
    RAISE EXCEPTION
      'Conjunto de divergencias SPEC-010 mudou. Reexecute o relatorio antes de aplicar a reconciliacao.';
  END IF;
END;
$$;

-- Garante que exista linha agregada para qualquer produto com saldo aberto.
WITH open_saldos AS (
  SELECT
    pi.produto_id,
    SUM(esp.q_reserva + esp.q_entrega_futura + esp.q_ag_separar + esp.q_separado) AS qtd_aberta
  FROM public.estoque_saldos_projeto_item esp
  JOIN public.projeto_itens pi ON pi.id = esp.projeto_item_id
  WHERE esp.status_operacional = 'ativo'
  GROUP BY pi.produto_id
)
INSERT INTO public.estoque_itens (
  produto_id,
  local,
  quantidade,
  quantidade_reservada,
  atualizado_em
)
SELECT
  os.produto_id,
  'Estoque'::public.estoque_local,
  0,
  0,
  now()
FROM open_saldos os
WHERE NOT EXISTS (
  SELECT 1
  FROM public.estoque_itens ei
  WHERE ei.produto_id = os.produto_id
    AND ei.local = 'Estoque'::public.estoque_local
);

-- Alinha o agregado de compatibilidade com a regra da SPEC-010:
-- quantidade_reservada = soma dos saldos abertos ativos por produto.
WITH open_saldos AS (
  SELECT
    pi.produto_id,
    SUM(esp.q_reserva + esp.q_entrega_futura + esp.q_ag_separar + esp.q_separado) AS qtd_aberta
  FROM public.estoque_saldos_projeto_item esp
  JOIN public.projeto_itens pi ON pi.id = esp.projeto_item_id
  WHERE esp.status_operacional = 'ativo'
  GROUP BY pi.produto_id
),
recon AS (
  SELECT
    ei.produto_id,
    coalesce(os.qtd_aberta, 0) AS qtd_aberta,
    ei.quantidade_reservada
  FROM public.estoque_itens ei
  LEFT JOIN open_saldos os ON os.produto_id = ei.produto_id
  WHERE ei.local = 'Estoque'::public.estoque_local
)
UPDATE public.estoque_itens ei
SET quantidade_reservada = recon.qtd_aberta,
    atualizado_em = now()
FROM recon
WHERE ei.produto_id = recon.produto_id
  AND ei.local = 'Estoque'::public.estoque_local
  AND abs(recon.qtd_aberta - recon.quantidade_reservada) > 0.001;

-- Relatorio final esperado: zero linhas.
WITH open_saldos AS (
  SELECT
    pi.produto_id,
    SUM(esp.q_reserva + esp.q_entrega_futura + esp.q_ag_separar + esp.q_separado) AS qtd_aberta
  FROM public.estoque_saldos_projeto_item esp
  JOIN public.projeto_itens pi ON pi.id = esp.projeto_item_id
  WHERE esp.status_operacional = 'ativo'
  GROUP BY pi.produto_id
),
recon AS (
  SELECT
    coalesce(os.produto_id, ei.produto_id) AS produto_id,
    coalesce(os.qtd_aberta, 0) AS qtd_aberta,
    coalesce(ei.quantidade_reservada, 0) AS quantidade_reservada
  FROM open_saldos os
  FULL JOIN public.estoque_itens ei
    ON ei.produto_id = os.produto_id
   AND ei.local = 'Estoque'::public.estoque_local
)
SELECT
  p.codigo_produto,
  p.nome AS produto,
  recon.qtd_aberta,
  recon.quantidade_reservada,
  recon.qtd_aberta - recon.quantidade_reservada AS diferenca
FROM recon
JOIN public.produtos p ON p.id = recon.produto_id
WHERE abs(recon.qtd_aberta - recon.quantidade_reservada) > 0.001
ORDER BY abs(recon.qtd_aberta - recon.quantidade_reservada) DESC;
