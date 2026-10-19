-- Desfaz a 227: apaga a view e volta aprovar_pedido_compra como na 226.
BEGIN;
DROP VIEW IF EXISTS public.vw_contas_pagar_pedidos_compra;

CREATE OR REPLACE FUNCTION public.aprovar_pedido_compra(p_pedido_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_status text;
  v_numero text;
BEGIN
  IF NOT hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar') THEN
    RAISE EXCEPTION 'Sem permissao para aprovar pedido de compra.' USING ERRCODE = '42501';
  END IF;

  SELECT status, numero INTO v_status, v_numero FROM public.pedidos_compra WHERE id = p_pedido_id FOR UPDATE;
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

  RETURN jsonb_build_object('pedido_id', p_pedido_id, 'numero', v_numero, 'status', 'aprovado');
END;
$function$;

COMMIT;
