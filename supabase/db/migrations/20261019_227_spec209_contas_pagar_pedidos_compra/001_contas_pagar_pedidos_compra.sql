-- SPEC-209 F: pedido de compra APROVADO entra no fluxo de caixa como Contas a Pagar.
-- Uma linha por parcela, no mesmo formato de v_financeiro_realizado (Dashboard Financeiro: Fluxo Futuro,
-- Contas a Pagar, Visão geral), em aberto (status_pago = 0) e com o vencimento da parcela.
-- Regras:
--   - entra: pedido 'aprovado' ou 'parcialmente_recebido' (Concluído parcialmente);
--   - não entra: 'aguardando_aprovar' (o fornecedor ainda não confirmou), 'recebido' (Concluído: a nota
--     já foi lançada e a duplicata vem do Connect para o Contas a Pagar — contar aqui seria em dobro),
--     'cancelado', parcela paga/cancelada, e os PC-LEGADO-* (cópia dos pedidos do Connect; a duplicata
--     deles já está no Contas a Pagar do Connect);
--   - Concluído parcialmente: só a parte que ainda não chegou (parcela × valor que falta / valor do pedido).
-- Mesma trava de acesso de v_financeiro_realizado (sistema dashboard-financeiro).
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

COMMENT ON VIEW public.vw_contas_pagar_pedidos_compra IS
  'SPEC-209 F: parcelas de pedidos de compra aprovados como Contas a Pagar (formato de v_financeiro_realizado).';

REVOKE ALL ON public.vw_contas_pagar_pedidos_compra FROM PUBLIC, anon;
GRANT SELECT ON public.vw_contas_pagar_pedidos_compra TO authenticated, service_role;

-- Aprovar já gera as parcelas pela condição de pagamento (se ainda não existem): sem parcela o pedido
-- aprovado não teria como aparecer no Contas a Pagar. Sem condição, aprova e devolve parcelas = 0
-- (a tela avisa para lançar as parcelas no pedido).
CREATE OR REPLACE FUNCTION public.aprovar_pedido_compra(p_pedido_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_status   text;
  v_numero   text;
  v_cond     text;
  v_parcelas integer;
BEGIN
  IF NOT hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar') THEN
    RAISE EXCEPTION 'Sem permissao para aprovar pedido de compra.' USING ERRCODE = '42501';
  END IF;

  SELECT status, numero, condicoes_pagamento INTO v_status, v_numero, v_cond
    FROM public.pedidos_compra WHERE id = p_pedido_id FOR UPDATE;
  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Pedido de compra % nao encontrado.', p_pedido_id USING ERRCODE = 'P0001';
  END IF;
  IF v_status <> 'aguardando_aprovar' THEN
    RAISE EXCEPTION 'So pedido em "Aguardando aprovar" pode ser aprovado (pedido % esta em %).', v_numero, v_status
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.pedidos_compra
     SET status = 'aprovado', aprovado_por = auth.uid(), aprovado_em = now(), atualizado_em = now()
   WHERE id = p_pedido_id;

  SELECT count(*) INTO v_parcelas FROM public.pedido_compra_parcelas
   WHERE pedido_id = p_pedido_id AND status <> 'cancelado';
  IF v_parcelas = 0 AND NULLIF(trim(coalesce(v_cond, '')), '') IS NOT NULL THEN
    BEGIN
      v_parcelas := (public.gerar_parcelas_pedido_compra(p_pedido_id)->>'parcelas_criadas')::integer;
    EXCEPTION WHEN OTHERS THEN
      v_parcelas := 0;
    END;
  END IF;

  RETURN jsonb_build_object('pedido_id', p_pedido_id, 'numero', v_numero, 'status', 'aprovado',
                            'parcelas', v_parcelas);
END;
$function$;

COMMIT;
