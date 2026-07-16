-- Migration 20260716_049 — Parte 3 (SPEC-030 Parte 2)
-- RPC criar_pedido_compra_lote: generalizacao de
-- criar_pedido_compra_de_necessidade (20260710_032) para N itens de um unico
-- fornecedor numa unica chamada. Acionada pelo botao "Fechar pedido em lote"
-- em NecessidadeCompra.tsx (modal ModalPedidoLote.tsx).
--
-- Modelo do lote (decisao da SPEC-030 Parte 2): 1 pedido = 1 fornecedor fixo.
-- p_itens e um array jsonb, cada elemento com o formato:
--   { "produto_id": "<uuid>", "quantidade": <numeric>, "custo_unitario": <numeric> }
-- (jsonb escolhido em vez de tipo composto por ser o formato mais simples de
-- serializar a partir de supabase-js/.rpc(), sem exigir um tipo novo no schema.)
--
-- Cria, numa unica transacao (funcao plpgsql = uma unica transacao da chamada;
-- qualquer RAISE EXCEPTION reverte tudo, sem necessidade de savepoint manual):
--   1 pedidos_compra (fornecedor_id = p_fornecedor_id, status = 'enviado',
--     mesmo status inicial que a RPC singular ja usa)
--   N solicitacoes_compra (status = 'pedido_gerado')
--   N pedido_compra_itens
--
-- Nao altera saldos de estoque — isso ocorre apenas no recebimento (SPEC-020
-- registrar_recebimento_compra), igual a RPC singular.

CREATE OR REPLACE FUNCTION public.criar_pedido_compra_lote(
    p_fornecedor_id          uuid,
    p_itens                  jsonb,
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
    v_pedido_id       uuid;
    v_valor_total     numeric(12,2) := 0;
    v_item            jsonb;
    v_produto_id      uuid;
    v_quantidade      numeric;
    v_custo_unitario  numeric;
    v_solicitacao_id  uuid;
    v_pedido_item_id  uuid;
    v_itens_criados   jsonb := '[]'::jsonb;
    v_qtd_itens       integer := 0;
BEGIN
    -- Validacoes de cabecalho
    IF p_numero IS NULL OR trim(p_numero) = '' THEN
        RAISE EXCEPTION 'Numero/referencia do pedido e obrigatorio.' USING ERRCODE = 'P0001';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.contatos WHERE id = p_fornecedor_id) THEN
        RAISE EXCEPTION 'Fornecedor % nao encontrado em contatos.', p_fornecedor_id USING ERRCODE = 'P0001';
    END IF;

    IF p_itens IS NULL OR jsonb_typeof(p_itens) <> 'array' OR jsonb_array_length(p_itens) = 0 THEN
        RAISE EXCEPTION 'Pedido em lote precisa de ao menos 1 item.' USING ERRCODE = 'P0001';
    END IF;

    -- Valida cada item e soma o valor total ANTES de criar qualquer registro
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_itens)
    LOOP
        v_produto_id     := NULLIF(v_item->>'produto_id', '')::uuid;
        v_quantidade     := NULLIF(v_item->>'quantidade', '')::numeric;
        v_custo_unitario := NULLIF(v_item->>'custo_unitario', '')::numeric;

        IF v_produto_id IS NULL THEN
            RAISE EXCEPTION 'Item de lote sem produto_id valido.' USING ERRCODE = 'P0001';
        END IF;

        IF v_quantidade IS NULL OR v_quantidade <= 0 THEN
            RAISE EXCEPTION 'Quantidade deve ser maior que zero (produto %).', v_produto_id USING ERRCODE = 'P0001';
        END IF;

        IF v_custo_unitario IS NULL OR v_custo_unitario <= 0 THEN
            RAISE EXCEPTION 'Custo unitario deve ser maior que zero (produto %).', v_produto_id USING ERRCODE = 'P0001';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.produtos WHERE id = v_produto_id) THEN
            RAISE EXCEPTION 'Produto % nao encontrado.', v_produto_id USING ERRCODE = 'P0001';
        END IF;

        v_valor_total := v_valor_total + (v_quantidade * v_custo_unitario);
        v_qtd_itens := v_qtd_itens + 1;
    END LOOP;

    -- 1. Cria pedido de compra unico (1 fornecedor fixo) com status enviado
    INSERT INTO public.pedidos_compra (
        numero, fornecedor_id, status, data_emissao,
        data_prevista_entrega, condicoes_pagamento,
        valor_total, observacao, aprovado_por, aprovado_em, criado_por
    ) VALUES (
        trim(p_numero), p_fornecedor_id, 'enviado', CURRENT_DATE,
        p_data_prevista_entrega, p_condicoes_pagamento,
        v_valor_total, p_observacao,
        auth.uid(), now(), auth.uid()
    )
    RETURNING id INTO v_pedido_id;

    -- 2. Para cada item: cria solicitacao_compra (ja como pedido_gerado) +
    --    pedido_compra_itens vinculado a solicitacao e ao pedido unico.
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_itens)
    LOOP
        v_produto_id     := (v_item->>'produto_id')::uuid;
        v_quantidade     := (v_item->>'quantidade')::numeric;
        v_custo_unitario := (v_item->>'custo_unitario')::numeric;

        INSERT INTO public.solicitacoes_compra (
            produto_id, quantidade, status, prioridade, observacao, solicitado_por
        ) VALUES (
            v_produto_id, v_quantidade, 'pedido_gerado', 'normal', p_observacao, auth.uid()
        )
        RETURNING id INTO v_solicitacao_id;

        INSERT INTO public.pedido_compra_itens (
            pedido_id, solicitacao_id, produto_id,
            quantidade, qtd_recebida, custo_unitario
        ) VALUES (
            v_pedido_id, v_solicitacao_id, v_produto_id,
            v_quantidade, 0, v_custo_unitario
        )
        RETURNING id INTO v_pedido_item_id;

        v_itens_criados := v_itens_criados || jsonb_build_object(
            'produto_id',      v_produto_id,
            'solicitacao_id',  v_solicitacao_id,
            'pedido_item_id',  v_pedido_item_id,
            'quantidade',      v_quantidade,
            'custo_unitario',  v_custo_unitario
        );
    END LOOP;

    RETURN jsonb_build_object(
        'pedido_id',   v_pedido_id,
        'numero',      trim(p_numero),
        'status',      'enviado',
        'valor_total', v_valor_total,
        'qtd_itens',   v_qtd_itens,
        'itens',       v_itens_criados
    );
END;
$$;

COMMENT ON FUNCTION public.criar_pedido_compra_lote(uuid, jsonb, text, date, text, text) IS
'SPEC-030 Parte 2. Botao "Fechar pedido em lote" na tela de Necessidade de
Compra, filtrada por marca. Generalizacao de criar_pedido_compra_de_necessidade
(SPEC-021, migration 20260710_032) para N itens de 1 unico fornecedor numa
unica transacao: 1 pedidos_compra (enviado) + N solicitacoes_compra
(pedido_gerado) + N pedido_compra_itens. p_itens: array jsonb de
{produto_id, quantidade, custo_unitario}. Nao altera saldos de estoque.';

GRANT EXECUTE ON FUNCTION public.criar_pedido_compra_lote(uuid, jsonb, text, date, text, text) TO authenticated;
