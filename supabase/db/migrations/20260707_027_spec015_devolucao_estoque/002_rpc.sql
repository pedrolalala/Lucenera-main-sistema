-- Migration 20260707_027 - SPEC-015 Parte 2
-- RPC registrar_devolucao_projeto_item: aplica a hierarquia
-- q_entrega_futura -> q_reserva -> q_entregue, dividindo automaticamente
-- quando a quantidade atravessa mais de uma situacao.

CREATE OR REPLACE FUNCTION public.registrar_devolucao_projeto_item(
    p_projeto_item_id uuid,
    p_quantidade      numeric,
    p_motivo          text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_saldo             public.estoque_saldos_projeto_item%ROWTYPE;
    v_produto_id        uuid;
    v_de_entrega_futura numeric(10,3);
    v_de_reserva        numeric(10,3);
    v_de_entregue       numeric(10,3);
    v_restante          numeric(10,3);
    v_status            text;
    v_devolucao_id      uuid;
BEGIN
    IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
        RAISE EXCEPTION 'Quantidade deve ser maior que zero.' USING ERRCODE = 'P0001';
    END IF;

    SELECT produto_id INTO v_produto_id FROM public.projeto_itens WHERE id = p_projeto_item_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Item de projeto % nao encontrado.', p_projeto_item_id USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_saldo
    FROM public.estoque_saldos_projeto_item
    WHERE projeto_item_id = p_projeto_item_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Item de projeto % nao possui saldo operacional (estoque_saldos_projeto_item).', p_projeto_item_id USING ERRCODE = 'P0001';
    END IF;

    IF p_quantidade > (v_saldo.q_entrega_futura + v_saldo.q_reserva + v_saldo.q_entregue) THEN
        RAISE EXCEPTION 'Quantidade de devolucao (%) excede o total disponivel para devolver (entrega futura + reserva + entregue = %).',
            p_quantidade, (v_saldo.q_entrega_futura + v_saldo.q_reserva + v_saldo.q_entregue) USING ERRCODE = 'P0001';
    END IF;

    v_de_entrega_futura := LEAST(p_quantidade, v_saldo.q_entrega_futura);
    v_restante := p_quantidade - v_de_entrega_futura;
    v_de_reserva := LEAST(v_restante, v_saldo.q_reserva);
    v_restante := v_restante - v_de_reserva;
    v_de_entregue := LEAST(v_restante, v_saldo.q_entregue);

    UPDATE public.estoque_saldos_projeto_item
    SET q_entrega_futura = q_entrega_futura - v_de_entrega_futura,
        q_reserva = q_reserva - v_de_reserva,
        q_entregue = q_entregue - v_de_entregue,
        q_devolvida = q_devolvida + p_quantidade,
        atualizado_em = now()
    WHERE projeto_item_id = p_projeto_item_id;

    -- RN-08: estoque_itens.quantidade_reservada so eh reduzido pela parte que
    -- estava em saldo aberto (entrega futura ou reserva); devolucao de entregue
    -- depende de coleta/entrada fisica, tratada em fluxo logistico proprio.
    IF (v_de_entrega_futura + v_de_reserva) > 0 AND v_produto_id IS NOT NULL THEN
        UPDATE public.estoque_itens
        SET quantidade_reservada = GREATEST(quantidade_reservada - (v_de_entrega_futura + v_de_reserva), 0)
        WHERE produto_id = v_produto_id
          AND local = 'Estoque'::public.estoque_local;
    END IF;

    v_status := CASE WHEN v_de_entregue > 0 THEN 'aguardando_coleta' ELSE 'registrada' END;

    INSERT INTO public.devolucoes_estoque (
        projeto_item_id, quantidade, qtd_de_entrega_futura, qtd_de_reserva, qtd_de_entregue,
        status, motivo, solicitado_por
    ) VALUES (
        p_projeto_item_id, p_quantidade, v_de_entrega_futura, v_de_reserva, v_de_entregue,
        v_status, p_motivo, auth.uid()
    )
    RETURNING id INTO v_devolucao_id;

    INSERT INTO public.estoque_movimentos_projeto_item
        (projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por)
    VALUES
        (p_projeto_item_id, 'devolucao', p_quantidade, 'devolucao_estoque', v_devolucao_id, p_motivo, auth.uid());

    RETURN jsonb_build_object(
        'devolucao_id', v_devolucao_id,
        'status', v_status,
        'de_entrega_futura', v_de_entrega_futura,
        'de_reserva', v_de_reserva,
        'de_entregue', v_de_entregue
    );
END;
$$;

COMMENT ON FUNCTION public.registrar_devolucao_projeto_item(uuid, numeric, text) IS
'SPEC-015. Devolucao por projeto_item_id, reduzindo saldos na ordem q_entrega_futura -> q_reserva -> q_entregue. Nao altera projeto_itens.quantidade (Q. Venda). Devolucao que toca q_entregue fica aguardando_coleta.';

GRANT EXECUTE ON FUNCTION public.registrar_devolucao_projeto_item(uuid, numeric, text) TO authenticated;
