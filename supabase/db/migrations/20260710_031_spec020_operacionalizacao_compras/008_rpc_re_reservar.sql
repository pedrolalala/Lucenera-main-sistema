-- Migration 20260710_031 - SPEC-020 Parte 8
-- RPC re_reservar_projeto_item: Debora re-reserva quando o material chega.
-- Move q_entrega_futura -> q_reserva em estoque_saldos_projeto_item
-- e incrementa estoque_itens.quantidade_reservada.

CREATE OR REPLACE FUNCTION public.re_reservar_projeto_item(
    p_projeto_item_id uuid,
    p_quantidade      numeric
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_saldo       public.estoque_saldos_projeto_item%ROWTYPE;
    v_produto_id  uuid;
    v_disponivel  numeric(10,3);
BEGIN
    IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
        RAISE EXCEPTION 'Quantidade deve ser maior que zero.' USING ERRCODE = 'P0001';
    END IF;

    SELECT produto_id INTO v_produto_id
    FROM public.projeto_itens
    WHERE id = p_projeto_item_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Item de projeto % nao encontrado.', p_projeto_item_id USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_saldo
    FROM public.estoque_saldos_projeto_item
    WHERE projeto_item_id = p_projeto_item_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Item de projeto % nao possui saldo operacional.', p_projeto_item_id USING ERRCODE = 'P0001';
    END IF;

    IF p_quantidade > v_saldo.q_entrega_futura THEN
        RAISE EXCEPTION 'Quantidade requisitada (%) excede q_entrega_futura disponivel (%) para o item %.', p_quantidade, v_saldo.q_entrega_futura, p_projeto_item_id USING ERRCODE = 'P0001';
    END IF;

    -- Verifica estoque fisico disponivel
    SELECT GREATEST(COALESCE(quantidade, 0) - COALESCE(quantidade_reservada, 0), 0)
    INTO v_disponivel
    FROM public.estoque_itens
    WHERE produto_id = v_produto_id AND local = 'Estoque'::public.estoque_local;

    IF COALESCE(v_disponivel, 0) < p_quantidade THEN
        RAISE EXCEPTION 'Estoque disponivel (%) insuficiente para re-reservar % unidades do produto %.', COALESCE(v_disponivel, 0), p_quantidade, v_produto_id USING ERRCODE = 'P0001';
    END IF;

    -- Move q_entrega_futura -> q_reserva
    UPDATE public.estoque_saldos_projeto_item
    SET q_entrega_futura = q_entrega_futura - p_quantidade,
        q_reserva        = q_reserva        + p_quantidade,
        atualizado_em    = now()
    WHERE projeto_item_id = p_projeto_item_id;

    -- Debita do disponivel aumentando quantidade_reservada
    UPDATE public.estoque_itens
    SET quantidade_reservada = quantidade_reservada + p_quantidade
    WHERE produto_id = v_produto_id AND local = 'Estoque'::public.estoque_local;

    -- Registra movimento
    INSERT INTO public.estoque_movimentos_projeto_item
        (projeto_item_id, tipo, quantidade, origem, observacao, criado_por)
    VALUES
        (p_projeto_item_id, 're_reserva', p_quantidade, 're_reserva', null, auth.uid());

    RETURN jsonb_build_object(
        'projeto_item_id',    p_projeto_item_id,
        'quantidade',         p_quantidade,
        'q_entrega_futura',   v_saldo.q_entrega_futura - p_quantidade,
        'q_reserva',          v_saldo.q_reserva + p_quantidade
    );
END;
$$;

COMMENT ON FUNCTION public.re_reservar_projeto_item(uuid, numeric) IS
'SPEC-020. Debora re-reserva material apos recebimento: move q_entrega_futura -> q_reserva em estoque_saldos_projeto_item e incrementa estoque_itens.quantidade_reservada. Valida que ha estoque disponivel antes de mover.';

GRANT EXECUTE ON FUNCTION public.re_reservar_projeto_item(uuid, numeric) TO authenticated;
