-- Migration 20260710_032 - SPEC-021
-- RPC criar_pedido_compra_de_necessidade: operacao atomica acionada pelo botao
-- "Registrar Compra" na tela de Necessidade de Compra.
-- Cria solicitacoes_compra (status pedido_gerado) + pedidos_compra (status enviado)
-- + pedido_compra_itens em uma unica transacao.

CREATE OR REPLACE FUNCTION public.criar_pedido_compra_de_necessidade(
    p_produto_id             uuid,
    p_fornecedor_id          uuid,
    p_quantidade             numeric,
    p_custo_unitario         numeric,
    p_numero                 text,
    p_data_prevista_entrega  date    DEFAULT NULL,
    p_condicoes_pagamento    text    DEFAULT NULL,
    p_observacao             text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_solicitacao_id  uuid;
    v_pedido_id       uuid;
    v_pedido_item_id  uuid;
BEGIN
    -- Validacoes
    IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
        RAISE EXCEPTION 'Quantidade deve ser maior que zero.' USING ERRCODE = 'P0001';
    END IF;

    IF p_custo_unitario IS NULL OR p_custo_unitario <= 0 THEN
        RAISE EXCEPTION 'Custo unitario deve ser maior que zero.' USING ERRCODE = 'P0001';
    END IF;

    IF p_numero IS NULL OR trim(p_numero) = '' THEN
        RAISE EXCEPTION 'Numero/referencia do pedido e obrigatorio.' USING ERRCODE = 'P0001';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.produtos WHERE id = p_produto_id) THEN
        RAISE EXCEPTION 'Produto % nao encontrado.', p_produto_id USING ERRCODE = 'P0001';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.contatos WHERE id = p_fornecedor_id) THEN
        RAISE EXCEPTION 'Fornecedor % nao encontrado em contatos.', p_fornecedor_id USING ERRCODE = 'P0001';
    END IF;

    -- 1. Cria solicitacao de compra ja como pedido_gerado
    INSERT INTO public.solicitacoes_compra (
        produto_id, quantidade, status, prioridade, observacao, solicitado_por
    ) VALUES (
        p_produto_id, p_quantidade, 'pedido_gerado', 'normal', p_observacao, auth.uid()
    )
    RETURNING id INTO v_solicitacao_id;

    -- 2. Cria pedido de compra com status enviado
    INSERT INTO public.pedidos_compra (
        numero, fornecedor_id, status, data_emissao,
        data_prevista_entrega, condicoes_pagamento,
        valor_total, observacao, aprovado_por, aprovado_em, criado_por
    ) VALUES (
        trim(p_numero), p_fornecedor_id, 'enviado', CURRENT_DATE,
        p_data_prevista_entrega, p_condicoes_pagamento,
        p_quantidade * p_custo_unitario, p_observacao,
        auth.uid(), now(), auth.uid()
    )
    RETURNING id INTO v_pedido_id;

    -- 3. Cria item do pedido vinculado a solicitacao
    INSERT INTO public.pedido_compra_itens (
        pedido_id, solicitacao_id, produto_id,
        quantidade, qtd_recebida, custo_unitario
    ) VALUES (
        v_pedido_id, v_solicitacao_id, p_produto_id,
        p_quantidade, 0, p_custo_unitario
    )
    RETURNING id INTO v_pedido_item_id;

    RETURN jsonb_build_object(
        'pedido_id',      v_pedido_id,
        'solicitacao_id', v_solicitacao_id,
        'pedido_item_id', v_pedido_item_id,
        'numero',         trim(p_numero),
        'status',         'enviado'
    );
END;
$$;

COMMENT ON FUNCTION public.criar_pedido_compra_de_necessidade(uuid, uuid, numeric, numeric, text, date, text, text) IS
'SPEC-021. Botao "Registrar Compra" na tela de Necessidade de Compra. Cria atomicamente: solicitacoes_compra (pedido_gerado) + pedidos_compra (enviado) + pedido_compra_itens. Nao altera saldos de estoque — isso ocorre apenas no recebimento (SPEC-020 registrar_recebimento_compra).';

GRANT EXECUTE ON FUNCTION public.criar_pedido_compra_de_necessidade(uuid, uuid, numeric, numeric, text, date, text, text) TO authenticated;
