-- SPEC-155 (P3, item modal "Gerar Compra por Item de Orçamento"): dois campos
-- pedidos pelo relatório do Vinícius que não existiam em nenhuma tabela do
-- módulo de compras (confirmado via information_schema antes de escrever
-- esta migration): desconto negociado na compra e local de entrega.
--
-- Decisão de implementação: `desconto_percentual` (não valor absoluto) —
-- mesmo padrão já usado em produtos.percentual_desconto_compra (SPEC-038
-- Item 5), reaproveitado aqui pro pedido inteiro em vez de por produto.
-- Aplicado sobre `valor_total` só quando informado (default NULL/0 preserva
-- o comportamento de todo pedido já existente e de qualquer chamada futura
-- que não passe o parâmetro).
--
-- RASCUNHO -- NÃO aplicar sem execução manual do usuário.

BEGIN;

ALTER TABLE public.pedidos_compra
  ADD COLUMN IF NOT EXISTS desconto_percentual numeric(5,2),
  ADD COLUMN IF NOT EXISTS local_entrega text;

ALTER TABLE public.pedidos_compra
  DROP CONSTRAINT IF EXISTS pedidos_compra_desconto_percentual_check;
ALTER TABLE public.pedidos_compra
  ADD CONSTRAINT pedidos_compra_desconto_percentual_check
  CHECK (desconto_percentual IS NULL OR (desconto_percentual >= 0 AND desconto_percentual <= 100));

COMMENT ON COLUMN public.pedidos_compra.desconto_percentual IS
  'SPEC-155. Desconto negociado no pedido (%), aplicado sobre valor_total no momento da criação (criar_pedido_compra_lote). NULL/0 = sem desconto, comportamento igual a antes desta migration.';
COMMENT ON COLUMN public.pedidos_compra.local_entrega IS
  'SPEC-155. Local de entrega informado no pedido (texto livre) -- nullable, preenchimento opcional.';

CREATE OR REPLACE FUNCTION public.criar_pedido_compra_lote(
  p_fornecedor_id uuid,
  p_itens jsonb,
  p_numero text DEFAULT NULL::text,
  p_data_prevista_entrega date DEFAULT NULL::date,
  p_condicoes_pagamento text DEFAULT NULL::text,
  p_observacao text DEFAULT NULL::text,
  p_empresa_id uuid DEFAULT NULL::uuid,
  p_perfil text DEFAULT NULL::text,
  p_desconto_percentual numeric DEFAULT NULL::numeric,
  p_local_entrega text DEFAULT NULL::text
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
    IF NOT hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'criar') THEN
        RAISE EXCEPTION 'Sem permissao para criar pedido de compra.' USING ERRCODE = '42501';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.contatos WHERE id = p_fornecedor_id) THEN
        RAISE EXCEPTION 'Fornecedor % nao encontrado em contatos.', p_fornecedor_id USING ERRCODE = 'P0001';
    END IF;

    IF p_itens IS NULL OR jsonb_typeof(p_itens) <> 'array' OR jsonb_array_length(p_itens) = 0 THEN
        RAISE EXCEPTION 'Pedido em lote precisa de ao menos 1 item.' USING ERRCODE = 'P0001';
    END IF;

    IF p_desconto_percentual IS NOT NULL AND (p_desconto_percentual < 0 OR p_desconto_percentual > 100) THEN
        RAISE EXCEPTION 'Desconto precisa estar entre 0 e 100 (recebido %).', p_desconto_percentual USING ERRCODE = 'P0001';
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

    -- SPEC-155: desconto negociado reduz o valor_total do pedido (não altera
    -- custo_unitario gravado por item -- o desconto é do PEDIDO, não do
    -- produto; item.custo_unitario continua sendo o preço de fato negociado
    -- por unidade, auditável separadamente).
    IF p_desconto_percentual IS NOT NULL AND p_desconto_percentual > 0 THEN
        v_valor_total := round(v_valor_total * (1 - p_desconto_percentual / 100), 2);
    END IF;

    INSERT INTO public.pedidos_compra (
        numero, fornecedor_id, status, data_emissao,
        data_prevista_entrega, condicoes_pagamento,
        valor_total, observacao, aprovado_por, aprovado_em, criado_por,
        empresa_id, perfil, desconto_percentual, local_entrega
    ) VALUES (
        NULLIF(trim(p_numero), ''), p_fornecedor_id, 'enviado', CURRENT_DATE,
        p_data_prevista_entrega, p_condicoes_pagamento,
        v_valor_total, p_observacao,
        auth.uid(), now(), auth.uid(),
        v_empresa_id, p_perfil, p_desconto_percentual, NULLIF(trim(p_local_entrega), '')
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

GRANT EXECUTE ON FUNCTION public.criar_pedido_compra_lote(uuid, jsonb, text, date, text, text, uuid, text, numeric, text) TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;
