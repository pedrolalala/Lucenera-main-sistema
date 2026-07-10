-- Migration 20260710_031 - SPEC-020 Parte 6
-- RPC registrar_recebimento_compra: operacao atomica de recebimento de material.
-- Aumenta estoque_itens.quantidade (saldo fisico) e atualiza status do pedido.

CREATE OR REPLACE FUNCTION public.registrar_recebimento_compra(
    p_pedido_id      uuid,
    p_numero_nota    text,
    p_data           date,
    p_itens          jsonb   -- array de {pedido_item_id, quantidade_recebida, divergencia?}
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_recebimento_id   uuid;
    v_item             jsonb;
    v_pedido_item_id   uuid;
    v_produto_id       uuid;
    v_qtd              numeric(10,3);
    v_divergencia      text;
    v_total_itens      integer;
    v_itens_completos  integer;
    v_novo_status      text;
    v_processados      jsonb[] := '{}';
BEGIN
    -- Valida pedido
    IF NOT EXISTS (
        SELECT 1 FROM public.pedidos_compra
        WHERE id = p_pedido_id AND status NOT IN ('recebido', 'cancelado')
    ) THEN
        RAISE EXCEPTION 'Pedido % nao encontrado ou ja encerrado.', p_pedido_id USING ERRCODE = 'P0001';
    END IF;

    -- Cria registro de recebimento
    INSERT INTO public.recebimentos_compra (pedido_id, numero_nota, data_recebimento, recebido_por)
    VALUES (p_pedido_id, p_numero_nota, COALESCE(p_data, CURRENT_DATE), auth.uid())
    RETURNING id INTO v_recebimento_id;

    -- Processa cada item
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_itens)
    LOOP
        v_pedido_item_id := (v_item->>'pedido_item_id')::uuid;
        v_qtd            := (v_item->>'quantidade_recebida')::numeric;
        v_divergencia    := v_item->>'divergencia';

        IF v_qtd IS NULL OR v_qtd <= 0 THEN
            RAISE EXCEPTION 'quantidade_recebida deve ser maior que zero para pedido_item_id %.', v_pedido_item_id USING ERRCODE = 'P0001';
        END IF;

        -- Busca produto_id e valida que o item pertence ao pedido
        SELECT produto_id INTO v_produto_id
        FROM public.pedido_compra_itens
        WHERE id = v_pedido_item_id AND pedido_id = p_pedido_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'pedido_item_id % nao pertence ao pedido %.', v_pedido_item_id, p_pedido_id USING ERRCODE = 'P0001';
        END IF;

        -- Registra item de recebimento
        INSERT INTO public.recebimento_itens (recebimento_id, pedido_item_id, produto_id, quantidade_recebida, divergencia)
        VALUES (v_recebimento_id, v_pedido_item_id, v_produto_id, v_qtd, v_divergencia);

        -- Atualiza qtd_recebida no item do pedido
        UPDATE public.pedido_compra_itens
        SET qtd_recebida = qtd_recebida + v_qtd
        WHERE id = v_pedido_item_id;

        -- Aumenta saldo fisico em estoque_itens
        UPDATE public.estoque_itens
        SET quantidade = quantidade + v_qtd
        WHERE produto_id = v_produto_id
          AND local = 'Estoque'::public.estoque_local;

        -- Se nao existe linha em estoque_itens para esse produto, cria
        IF NOT FOUND THEN
            INSERT INTO public.estoque_itens (produto_id, local, quantidade, quantidade_reservada)
            VALUES (v_produto_id, 'Estoque'::public.estoque_local, v_qtd, 0)
            ON CONFLICT (produto_id, local) DO UPDATE
            SET quantidade = public.estoque_itens.quantidade + v_qtd;
        END IF;

        v_processados := v_processados || jsonb_build_object(
            'pedido_item_id', v_pedido_item_id,
            'produto_id', v_produto_id,
            'quantidade_recebida', v_qtd
        );
    END LOOP;

    -- Recalcula status do pedido
    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE qtd_recebida >= quantidade)
    INTO v_total_itens, v_itens_completos
    FROM public.pedido_compra_itens
    WHERE pedido_id = p_pedido_id;

    v_novo_status := CASE
        WHEN v_itens_completos = v_total_itens THEN 'recebido'
        WHEN v_itens_completos > 0             THEN 'parcialmente_recebido'
        ELSE 'enviado'
    END;

    UPDATE public.pedidos_compra
    SET status = v_novo_status, atualizado_em = now()
    WHERE id = p_pedido_id;

    RETURN jsonb_build_object(
        'recebimento_id', v_recebimento_id,
        'pedido_status',  v_novo_status,
        'itens',          to_jsonb(v_processados)
    );
END;
$$;

COMMENT ON FUNCTION public.registrar_recebimento_compra(uuid, text, date, jsonb) IS
'SPEC-020 / SPEC-EST-12. Recebe material contra pedido_compra: insere recebimentos_compra + recebimento_itens, incrementa estoque_itens.quantidade (saldo fisico) e atualiza status do pedido. Nao re-reserva automaticamente; Debora faz isso via re_reservar_projeto_item.';

GRANT EXECUTE ON FUNCTION public.registrar_recebimento_compra(uuid, text, date, jsonb) TO authenticated;
