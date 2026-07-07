-- Migration 20260707_026 - SPEC-011 Parte 2
-- RPCs de transferencia de reserva entre projeto_item_id.

CREATE OR REPLACE FUNCTION public.solicitar_transferencia_estoque(
    p_origem_projeto_item_id  uuid,
    p_destino_projeto_item_id uuid,
    p_quantidade              numeric,
    p_motivo                  text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_origem_produto  uuid;
    v_destino_produto uuid;
    v_origem_saldo    public.estoque_saldos_projeto_item%ROWTYPE;
    v_transferencia_id uuid;
BEGIN
    IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
        RAISE EXCEPTION 'Quantidade deve ser maior que zero.' USING ERRCODE = 'P0001';
    END IF;

    IF p_origem_projeto_item_id = p_destino_projeto_item_id THEN
        RAISE EXCEPTION 'Origem e destino nao podem ser o mesmo item de projeto.' USING ERRCODE = 'P0001';
    END IF;

    SELECT produto_id INTO v_origem_produto FROM public.projeto_itens WHERE id = p_origem_projeto_item_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Item de projeto de origem % nao encontrado.', p_origem_projeto_item_id USING ERRCODE = 'P0001';
    END IF;

    SELECT produto_id INTO v_destino_produto FROM public.projeto_itens WHERE id = p_destino_projeto_item_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Item de projeto de destino % nao encontrado.', p_destino_projeto_item_id USING ERRCODE = 'P0001';
    END IF;

    IF v_origem_produto IS DISTINCT FROM v_destino_produto THEN
        RAISE EXCEPTION 'Origem e destino precisam ser do mesmo produto.' USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_origem_saldo
    FROM public.estoque_saldos_projeto_item
    WHERE projeto_item_id = p_origem_projeto_item_id;

    IF NOT FOUND OR v_origem_saldo.q_reserva < p_quantidade THEN
        RAISE EXCEPTION 'Origem nao tem q_reserva suficiente para a transferencia solicitada.' USING ERRCODE = 'P0001';
    END IF;

    INSERT INTO public.transferencias_estoque (
        origem_projeto_item_id, destino_projeto_item_id, quantidade, motivo, solicitado_por
    ) VALUES (
        p_origem_projeto_item_id, p_destino_projeto_item_id, p_quantidade, p_motivo, auth.uid()
    )
    RETURNING id INTO v_transferencia_id;

    RETURN jsonb_build_object('transferencia_id', v_transferencia_id, 'status', 'solicitada');
END;
$$;

COMMENT ON FUNCTION public.solicitar_transferencia_estoque(uuid, uuid, numeric, text) IS
'SPEC-011. Registra solicitacao de transferencia de q_reserva entre dois projeto_item_id do mesmo produto. Nao altera saldo ainda.';

CREATE OR REPLACE FUNCTION public.aprovar_transferencia_estoque(
    p_transferencia_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_transf     public.transferencias_estoque%ROWTYPE;
    v_origem     public.estoque_saldos_projeto_item%ROWTYPE;
    v_destino    public.estoque_saldos_projeto_item%ROWTYPE;
    v_role       public.usuario_role;
    v_reduzir_ef numeric(10,3);
BEGIN
    SELECT role INTO v_role FROM public.usuarios WHERE id = auth.uid();
    IF v_role IS NULL OR v_role NOT IN ('admin', 'gerente') THEN
        RAISE EXCEPTION 'Apenas admin ou gerente pode aprovar transferencia de estoque.' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_transf FROM public.transferencias_estoque WHERE id = p_transferencia_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transferencia % nao encontrada.', p_transferencia_id USING ERRCODE = 'P0001';
    END IF;

    IF v_transf.status <> 'solicitada' THEN
        RAISE EXCEPTION 'Transferencia % nao esta mais solicitada (status atual: %).', p_transferencia_id, v_transf.status USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_origem
    FROM public.estoque_saldos_projeto_item
    WHERE projeto_item_id = v_transf.origem_projeto_item_id
    FOR UPDATE;

    SELECT * INTO v_destino
    FROM public.estoque_saldos_projeto_item
    WHERE projeto_item_id = v_transf.destino_projeto_item_id
    FOR UPDATE;

    IF v_origem.q_reserva < v_transf.quantidade THEN
        RAISE EXCEPTION 'Origem nao tem mais q_reserva suficiente (era % no momento da solicitacao).', v_transf.quantidade USING ERRCODE = 'P0001';
    END IF;

    v_reduzir_ef := LEAST(v_transf.quantidade, v_destino.q_entrega_futura);

    UPDATE public.estoque_saldos_projeto_item
    SET q_reserva = q_reserva - v_transf.quantidade,
        q_entrega_futura = q_entrega_futura + v_transf.quantidade,
        q_transferida_saida = q_transferida_saida + v_transf.quantidade,
        atualizado_em = now()
    WHERE projeto_item_id = v_transf.origem_projeto_item_id;

    UPDATE public.estoque_saldos_projeto_item
    SET q_entrega_futura = q_entrega_futura - v_reduzir_ef,
        q_reserva = q_reserva + v_transf.quantidade,
        atualizado_em = now()
    WHERE projeto_item_id = v_transf.destino_projeto_item_id;

    INSERT INTO public.estoque_movimentos_projeto_item
        (projeto_item_id, projeto_item_destino_id, tipo, quantidade, origem, referencia_id, criado_por)
    VALUES
        (v_transf.origem_projeto_item_id, v_transf.destino_projeto_item_id, 'transferencia_saida', v_transf.quantidade, 'transferencia_estoque', v_transf.id, auth.uid());

    INSERT INTO public.estoque_movimentos_projeto_item
        (projeto_item_id, projeto_item_destino_id, tipo, quantidade, origem, referencia_id, criado_por)
    VALUES
        (v_transf.destino_projeto_item_id, v_transf.origem_projeto_item_id, 'transferencia_entrada', v_transf.quantidade, 'transferencia_estoque', v_transf.id, auth.uid());

    UPDATE public.transferencias_estoque
    SET status = 'aprovada', aprovado_por = auth.uid(), aprovado_em = now()
    WHERE id = p_transferencia_id;

    RETURN jsonb_build_object('transferencia_id', p_transferencia_id, 'status', 'aprovada');
END;
$$;

COMMENT ON FUNCTION public.aprovar_transferencia_estoque(uuid) IS
'SPEC-011. Aprova transferencia: origem perde q_reserva e ganha q_entrega_futura; destino ganha q_reserva e perde q_entrega_futura ate o limite disponivel. Restrito a admin/gerente.';

CREATE OR REPLACE FUNCTION public.cancelar_transferencia_estoque(
    p_transferencia_id uuid,
    p_motivo           text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_transf public.transferencias_estoque%ROWTYPE;
BEGIN
    SELECT * INTO v_transf FROM public.transferencias_estoque WHERE id = p_transferencia_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transferencia % nao encontrada.', p_transferencia_id USING ERRCODE = 'P0001';
    END IF;

    IF v_transf.status <> 'solicitada' THEN
        RAISE EXCEPTION 'Só é possível cancelar transferencia com status solicitada (atual: %). Transferencia aprovada exige nova transferencia no sentido contrario.', v_transf.status USING ERRCODE = 'P0001';
    END IF;

    UPDATE public.transferencias_estoque
    SET status = 'cancelada', cancelado_em = now(), motivo_cancelamento = p_motivo
    WHERE id = p_transferencia_id;

    RETURN jsonb_build_object('transferencia_id', p_transferencia_id, 'status', 'cancelada');
END;
$$;

COMMENT ON FUNCTION public.cancelar_transferencia_estoque(uuid, text) IS
'SPEC-011. Cancela transferencia ainda nao aprovada. Nao reverte saldo, pois transferencia solicitada nao altera saldo.';

GRANT EXECUTE ON FUNCTION public.solicitar_transferencia_estoque(uuid, uuid, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.aprovar_transferencia_estoque(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancelar_transferencia_estoque(uuid, text) TO authenticated;
