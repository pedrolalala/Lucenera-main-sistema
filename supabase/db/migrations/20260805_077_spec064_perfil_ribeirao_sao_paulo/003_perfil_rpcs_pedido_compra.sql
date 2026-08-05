-- Migration 20260805_077 - SPEC-064 (complemento)
--
-- criar_pedido_compra_lote/criar_pedido_compra_de_necessidade ganham
-- p_perfil opcional (rotulo Ribeirao/Sao Paulo, so visualizacao, manual,
-- sem heranca automatica). Mesma mecanica ja documentada na SPEC-057:
-- CREATE OR REPLACE adicionando parametro no final nao substitui a funcao,
-- cria uma segunda sobrecarga ambigua -- precisa DROP FUNCTION explicito
-- da assinatura antiga antes de recriar.

DROP FUNCTION IF EXISTS public.criar_pedido_compra_lote(
  uuid, jsonb, text, date, text, text, uuid
);

CREATE OR REPLACE FUNCTION public.criar_pedido_compra_lote(
  p_fornecedor_id uuid,
  p_itens jsonb,
  p_numero text DEFAULT NULL::text,
  p_data_prevista_entrega date DEFAULT NULL::date,
  p_condicoes_pagamento text DEFAULT NULL::text,
  p_observacao text DEFAULT NULL::text,
  p_empresa_id uuid DEFAULT NULL::uuid,
  p_perfil text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_pedido_id       uuid;
    v_numero_final    text;
    v_valor_total     numeric(12,2) := 0;
    v_item            jsonb;
    v_produto_id      uuid;
    v_quantidade      numeric;
    v_custo_unitario  numeric;
    v_custo_liquido   numeric;
    v_valor_icms      numeric;
    v_valor_ipi       numeric;
    v_valor_st        numeric;
    v_solicitacao_id  uuid;
    v_pedido_item_id  uuid;
    v_itens_criados   jsonb := '[]'::jsonb;
    v_qtd_itens       integer := 0;
    v_empresa_id      uuid;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.contatos WHERE id = p_fornecedor_id) THEN
        RAISE EXCEPTION 'Fornecedor % nao encontrado em contatos.', p_fornecedor_id USING ERRCODE = 'P0001';
    END IF;

    IF p_itens IS NULL OR jsonb_typeof(p_itens) <> 'array' OR jsonb_array_length(p_itens) = 0 THEN
        RAISE EXCEPTION 'Pedido em lote precisa de ao menos 1 item.' USING ERRCODE = 'P0001';
    END IF;

    IF p_empresa_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM public.empresas WHERE id = p_empresa_id) THEN
            RAISE EXCEPTION 'Empresa % nao encontrada.', p_empresa_id USING ERRCODE = 'P0001';
        END IF;
        v_empresa_id := p_empresa_id;
    ELSE
        SELECT empresa_id INTO v_empresa_id FROM public.usuarios WHERE id = auth.uid();
    END IF;

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

    INSERT INTO public.pedidos_compra (
        numero, fornecedor_id, status, data_emissao,
        data_prevista_entrega, condicoes_pagamento,
        valor_total, observacao, aprovado_por, aprovado_em, criado_por,
        empresa_id, perfil
    ) VALUES (
        NULLIF(trim(p_numero), ''), p_fornecedor_id, 'enviado', CURRENT_DATE,
        p_data_prevista_entrega, p_condicoes_pagamento,
        v_valor_total, p_observacao,
        auth.uid(), now(), auth.uid(),
        v_empresa_id, p_perfil
    )
    RETURNING id, numero INTO v_pedido_id, v_numero_final;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_itens)
    LOOP
        v_produto_id     := (v_item->>'produto_id')::uuid;
        v_quantidade     := (v_item->>'quantidade')::numeric;
        v_custo_unitario := (v_item->>'custo_unitario')::numeric;
        v_custo_liquido  := NULLIF(v_item->>'custo_liquido', '')::numeric;
        v_valor_icms     := NULLIF(v_item->>'valor_icms', '')::numeric;
        v_valor_ipi      := NULLIF(v_item->>'valor_ipi', '')::numeric;
        v_valor_st       := NULLIF(v_item->>'valor_st', '')::numeric;

        INSERT INTO public.solicitacoes_compra (
            produto_id, quantidade, status, prioridade, observacao, solicitado_por
        ) VALUES (
            v_produto_id, v_quantidade, 'pedido_gerado', 'normal', p_observacao, auth.uid()
        )
        RETURNING id INTO v_solicitacao_id;

        INSERT INTO public.pedido_compra_itens (
            pedido_id, solicitacao_id, produto_id,
            quantidade, qtd_recebida, custo_unitario,
            custo_liquido, valor_icms, valor_ipi, valor_st
        ) VALUES (
            v_pedido_id, v_solicitacao_id, v_produto_id,
            v_quantidade, 0, v_custo_unitario,
            v_custo_liquido, v_valor_icms, v_valor_ipi, v_valor_st
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
        'numero',      v_numero_final,
        'status',      'enviado',
        'valor_total', v_valor_total,
        'qtd_itens',   v_qtd_itens,
        'itens',       v_itens_criados
    );
END;
$function$;

DROP FUNCTION IF EXISTS public.criar_pedido_compra_de_necessidade(
  uuid, uuid, numeric, numeric, text, date, text, text, numeric, numeric, numeric, numeric, uuid
);

CREATE OR REPLACE FUNCTION public.criar_pedido_compra_de_necessidade(
  p_produto_id uuid,
  p_fornecedor_id uuid,
  p_quantidade numeric,
  p_custo_unitario numeric,
  p_numero text DEFAULT NULL::text,
  p_data_prevista_entrega date DEFAULT NULL::date,
  p_condicoes_pagamento text DEFAULT NULL::text,
  p_observacao text DEFAULT NULL::text,
  p_custo_liquido numeric DEFAULT NULL::numeric,
  p_valor_icms numeric DEFAULT NULL::numeric,
  p_valor_ipi numeric DEFAULT NULL::numeric,
  p_valor_st numeric DEFAULT NULL::numeric,
  p_empresa_id uuid DEFAULT NULL::uuid,
  p_perfil text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_solicitacao_id  uuid;
    v_pedido_id       uuid;
    v_pedido_item_id  uuid;
    v_numero_final    text;
    v_empresa_id      uuid;
BEGIN
    IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
        RAISE EXCEPTION 'Quantidade deve ser maior que zero.' USING ERRCODE = 'P0001';
    END IF;

    IF p_custo_unitario IS NULL OR p_custo_unitario <= 0 THEN
        RAISE EXCEPTION 'Custo unitario deve ser maior que zero.' USING ERRCODE = 'P0001';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.produtos WHERE id = p_produto_id) THEN
        RAISE EXCEPTION 'Produto % nao encontrado.', p_produto_id USING ERRCODE = 'P0001';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.contatos WHERE id = p_fornecedor_id) THEN
        RAISE EXCEPTION 'Fornecedor % nao encontrado em contatos.', p_fornecedor_id USING ERRCODE = 'P0001';
    END IF;

    IF p_empresa_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM public.empresas WHERE id = p_empresa_id) THEN
            RAISE EXCEPTION 'Empresa % nao encontrada.', p_empresa_id USING ERRCODE = 'P0001';
        END IF;
        v_empresa_id := p_empresa_id;
    ELSE
        SELECT empresa_id INTO v_empresa_id FROM public.usuarios WHERE id = auth.uid();
    END IF;

    INSERT INTO public.solicitacoes_compra (
        produto_id, quantidade, status, prioridade, observacao, solicitado_por
    ) VALUES (
        p_produto_id, p_quantidade, 'pedido_gerado', 'normal', p_observacao, auth.uid()
    )
    RETURNING id INTO v_solicitacao_id;

    INSERT INTO public.pedidos_compra (
        numero, fornecedor_id, status, data_emissao,
        data_prevista_entrega, condicoes_pagamento,
        valor_total, observacao, aprovado_por, aprovado_em, criado_por,
        empresa_id, perfil
    ) VALUES (
        NULLIF(trim(p_numero), ''), p_fornecedor_id, 'enviado', CURRENT_DATE,
        p_data_prevista_entrega, p_condicoes_pagamento,
        p_quantidade * p_custo_unitario, p_observacao,
        auth.uid(), now(), auth.uid(),
        v_empresa_id, p_perfil
    )
    RETURNING id, numero INTO v_pedido_id, v_numero_final;

    INSERT INTO public.pedido_compra_itens (
        pedido_id, solicitacao_id, produto_id,
        quantidade, qtd_recebida, custo_unitario,
        custo_liquido, valor_icms, valor_ipi, valor_st
    ) VALUES (
        v_pedido_id, v_solicitacao_id, p_produto_id,
        p_quantidade, 0, p_custo_unitario,
        p_custo_liquido, p_valor_icms, p_valor_ipi, p_valor_st
    )
    RETURNING id INTO v_pedido_item_id;

    RETURN jsonb_build_object(
        'pedido_id',      v_pedido_id,
        'solicitacao_id', v_solicitacao_id,
        'pedido_item_id', v_pedido_item_id,
        'numero',         v_numero_final,
        'status',         'enviado'
    );
END;
$function$;
