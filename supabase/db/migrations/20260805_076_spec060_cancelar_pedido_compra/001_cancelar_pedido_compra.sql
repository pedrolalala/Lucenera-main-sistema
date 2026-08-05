-- Migration 20260805_076 - SPEC-060
--
-- Hoje nao existe nenhuma forma de cancelar um pedido de compra: a tabela
-- pedidos_compra so tem policy de SELECT para authenticated, todo
-- INSERT/alteracao passa por RPC SECURITY DEFINER (criar_pedido_compra_lote/
-- criar_pedido_compra_de_necessidade). Isso cria a RPC de cancelamento.
--
-- Efeito automatico ja existente: vw_necessidade_compra_pedidos_abertos e
-- vw_necessidade_compra_pedido_detalhe (SPEC-039) ja filtram por
-- status NOT IN ('recebido', 'cancelado') -- marcar o pedido como cancelado
-- ja e suficiente para ele sumir de "pedidos em aberto" e a coluna
-- "Pendente" de vw_necessidade_compra voltar a refletir o deficit real.
-- Nenhuma view precisa ser alterada por esta migration.

ALTER TABLE public.pedidos_compra
  ADD COLUMN IF NOT EXISTS cancelado_em timestamptz,
  ADD COLUMN IF NOT EXISTS cancelado_por uuid REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS motivo_cancelamento text;

CREATE OR REPLACE FUNCTION public.cancelar_pedido_compra(
  p_pedido_id uuid,
  p_motivo text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_status text;
  v_numero text;
BEGIN
  SELECT status, numero INTO v_status, v_numero
  FROM public.pedidos_compra
  WHERE id = p_pedido_id
  FOR UPDATE;

  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Pedido de compra % nao encontrado.', p_pedido_id USING ERRCODE = 'P0001';
  END IF;

  IF v_status = 'cancelado' THEN
    RAISE EXCEPTION 'Pedido % ja esta cancelado.', v_numero USING ERRCODE = 'P0001';
  END IF;

  IF v_status IN ('recebido', 'parcialmente_recebido') THEN
    RAISE EXCEPTION 'Pedido % ja tem recebimento registrado e nao pode ser cancelado (use a tela de Devolucao).', v_numero
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.pedidos_compra
  SET status = 'cancelado',
      cancelado_em = now(),
      cancelado_por = auth.uid(),
      motivo_cancelamento = p_motivo
  WHERE id = p_pedido_id;

  -- Pedido cancelado nao deve permanecer como conta a pagar em aberto.
  -- Parcelas ja pagas ficam intocadas (registro financeiro real).
  UPDATE public.pedido_compra_parcelas
  SET status = 'cancelado'
  WHERE pedido_id = p_pedido_id
    AND status <> 'pago';

  RETURN jsonb_build_object(
    'pedido_id', p_pedido_id,
    'numero',    v_numero,
    'status',    'cancelado'
  );
END;
$function$;

COMMENT ON FUNCTION public.cancelar_pedido_compra IS
'SPEC-060. Cancela um pedido_compra (status -> cancelado), bloqueado para
pedidos ja recebido/parcialmente_recebido/cancelado. Cancela junto as
parcelas nao pagas. Sem checagem de papel, mesmo padrao de
criar_pedido_compra_lote/criar_pedido_compra_de_necessidade.';
