-- Desfaz a 228: volta a view da 227 (concluído sai; parcial proporcional).
BEGIN;

CREATE OR REPLACE VIEW public.vw_contas_pagar_pedidos_compra AS
WITH aberto AS (
  SELECT i.pedido_id,
         CASE WHEN sum(i.quantidade * i.custo_unitario) > 0
              THEN sum(greatest(i.quantidade - i.qtd_recebida, 0) * i.custo_unitario)
                   / sum(i.quantidade * i.custo_unitario)
              ELSE 1 END AS fator
    FROM public.pedido_compra_itens i
   GROUP BY i.pedido_id
), parcelas AS (
  SELECT x.*, count(*) OVER (PARTITION BY x.pedido_id) AS total_parcelas
    FROM public.pedido_compra_parcelas x
)
SELECT
  ('pc:' || x.id::text)                                        AS id,
  'despesa'::text                                              AS tipo,
  format('Pedido de compra %s — %s (parcela %s/%s)', p.numero, coalesce(c.nome, 'fornecedor'),
         x.numero_parcela, x.total_parcelas)                   AS descricao,
  'PEDIDOS DE COMPRA'::text                                    AS desc_sub_grupo,
  'DESPESAS'::text                                             AS desc_grupo,
  'despesa_operacional'::text                                  AS natureza,
  0                                                            AS status_pago,
  NULL::date                                                   AS dt_pagamento,
  x.data_vencimento                                            AS dt_vencimento,
  p.data_emissao                                               AS dt_emissao,
  0::numeric                                                   AS vl_pago,
  round(x.valor * coalesce(a.fator, 1), 2)                     AS vl_parcela,
  0::numeric                                                   AS vl_desconto,
  p.empresa_id,
  NULL::integer                                                AS cod_duplicata,
  'variavel'::text                                             AS tipo_custo,
  p.perfil,
  -- SPEC-209 F: de onde veio a linha (as do Connect não têm estas colunas)
  'pedido_compra'::text                                        AS origem,
  p.id                                                         AS pedido_compra_id,
  p.numero                                                     AS pedido_numero,
  p.status                                                     AS pedido_status
FROM parcelas x
JOIN public.pedidos_compra p ON p.id = x.pedido_id
LEFT JOIN public.contatos c ON c.id = p.fornecedor_id
LEFT JOIN aberto a ON a.pedido_id = p.id
WHERE p.status IN ('aprovado', 'parcialmente_recebido')
  AND p.numero NOT LIKE 'PC-LEGADO-%'
  AND x.status IN ('pendente', 'atrasado')
  AND x.data_vencimento IS NOT NULL
  AND round(x.valor * coalesce(a.fator, 1), 2) > 0
  AND (SELECT public.pode_acessar_sistema('dashboard-financeiro'::text));

COMMIT;
