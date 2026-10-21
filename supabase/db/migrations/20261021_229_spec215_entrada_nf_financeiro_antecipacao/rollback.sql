-- Desfaz a 229 (SPEC-215): volta a view da 228 e apaga tabelas, colunas, view e RPCs novas.
-- ATENÇÃO: apaga as parcelas de nota e os pagamentos antecipados lançados. As notas e as quantidades recebidas
-- ficam (notas_fiscais_compra / pedido_compra_itens não são apagadas).
BEGIN;

CREATE OR REPLACE VIEW public.vw_contas_pagar_pedidos_compra AS
WITH parcelas AS (
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
  x.valor::numeric                                             AS vl_parcela,
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
WHERE p.status IN ('aprovado', 'parcialmente_recebido', 'recebido')
  AND p.numero NOT LIKE 'PC-LEGADO-%'
  AND x.status IN ('pendente', 'atrasado')
  AND x.data_vencimento IS NOT NULL
  AND x.valor > 0
  AND (SELECT public.pode_acessar_sistema('dashboard-financeiro'::text));

COMMENT ON VIEW public.vw_contas_pagar_pedidos_compra IS
  'SPEC-209 F: parcelas de pedidos de compra aprovados como Contas a Pagar até a baixa do financeiro (formato de v_financeiro_realizado).';


DROP FUNCTION IF EXISTS public.registrar_entrada_nota_compra(uuid, jsonb, jsonb, jsonb, jsonb, uuid);
DROP FUNCTION IF EXISTS public.antecipacoes_para_entrada(uuid, uuid);
DROP FUNCTION IF EXISTS public.cancelar_pagamento_antecipado(uuid, text);
DROP FUNCTION IF EXISTS public.lancar_pagamento_antecipado(uuid, uuid, numeric, date, uuid, text);
DROP VIEW IF EXISTS public.vw_pagamentos_antecipados;
DROP TABLE IF EXISTS public.pagamento_antecipado_vinculos;
DROP TABLE IF EXISTS public.pagamentos_antecipados;
DROP TABLE IF EXISTS public.nota_fiscal_compra_parcelas;
DROP INDEX IF EXISTS public.idx_negociacoes_empresa_num_nota;
ALTER TABLE public.negociacoes DROP COLUMN IF EXISTS num_nota;
ALTER TABLE public.notas_fiscais_compra DROP COLUMN IF EXISTS valor_st;

COMMIT;
