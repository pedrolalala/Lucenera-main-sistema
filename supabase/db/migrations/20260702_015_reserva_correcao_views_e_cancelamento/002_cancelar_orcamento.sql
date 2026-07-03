-- Migration 20260702_015 — Parte 2
-- Adiciona função cancelar_orcamento(orcamento_id, motivo).
--
-- Comportamento:
--   1. Se status = 'aprovado':  decrementa quantidade_reservada em estoque_itens
--      para cada produto do orçamento (GREATEST(0, reservado - qtd) para não ir negativo).
--   2. Atualiza orcamentos.status = 'cancelado'.
--   3. Registra em historico_status_orcamentos.
--   4. Retorna jsonb com resumo.
--
-- Idempotência:
--   Chamar duas vezes para o mesmo orçamento já cancelado retorna ja_cancelado=true
--   sem alterar nada no estoque.
--
-- Status 'aguardando_aprovacao' também pode ser cancelado (não há estoque a reverter).

CREATE OR REPLACE FUNCTION public.cancelar_orcamento(
    p_orcamento_id uuid,
    p_motivo       text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_orcamento          public.orcamentos%ROWTYPE;
    v_status_anterior    text;
    v_numero_orcamento   text;
    v_reservas_revertidas integer := 0;
BEGIN
    -- 1. Carregar e travar o orçamento
    SELECT * INTO v_orcamento
    FROM public.orcamentos
    WHERE id = p_orcamento_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Orçamento % não encontrado.', p_orcamento_id
            USING ERRCODE = 'P0001';
    END IF;

    v_status_anterior  := v_orcamento.status;
    v_numero_orcamento := coalesce(v_orcamento.numero, left(p_orcamento_id::text, 8));

    -- 2. Idempotência: já está cancelado
    IF v_status_anterior = 'cancelado' THEN
        RETURN jsonb_build_object(
            'orcamento_id',          p_orcamento_id,
            'numero',                v_numero_orcamento,
            'status',                'cancelado',
            'reservas_revertidas',   0,
            'ja_cancelado',          true
        );
    END IF;

    -- 3. Se aprovado → reverter reservas de estoque
    IF v_status_anterior = 'aprovado' THEN
        UPDATE public.estoque_itens ei
        SET quantidade_reservada = GREATEST(0, ei.quantidade_reservada - oi.quantidade),
            atualizado_em        = NOW()
        FROM public.orcamento_itens oi
        WHERE oi.orcamento_id  = p_orcamento_id
          AND oi.produto_id    IS NOT NULL
          AND coalesce(oi.quantidade, 0) > 0
          AND ei.produto_id    = oi.produto_id
          AND ei.local         = 'Estoque'::public.estoque_local;

        GET DIAGNOSTICS v_reservas_revertidas = ROW_COUNT;
    END IF;

    -- 4. Atualizar status
    UPDATE public.orcamentos
    SET status = 'cancelado'
    WHERE id = p_orcamento_id;

    -- 5. Registrar histórico
    INSERT INTO public.historico_status_orcamentos (
        orcamento_id,
        status_anterior,
        status_novo,
        usuario,
        observacao
    ) VALUES (
        p_orcamento_id,
        v_status_anterior,
        'cancelado',
        auth.uid()::text,
        coalesce(p_motivo, 'Cancelamento via RPC cancelar_orcamento')
    );

    RETURN jsonb_build_object(
        'orcamento_id',        p_orcamento_id,
        'numero',              v_numero_orcamento,
        'status',              'cancelado',
        'status_anterior',     v_status_anterior,
        'reservas_revertidas', v_reservas_revertidas,
        'ja_cancelado',        false
    );
END;
$$;

COMMENT ON FUNCTION public.cancelar_orcamento(uuid, text) IS
'Cancela um orçamento. Se estava aprovado, reverte as reservas de estoque (decrementa
quantidade_reservada em estoque_itens). Registra em historico_status_orcamentos.';
