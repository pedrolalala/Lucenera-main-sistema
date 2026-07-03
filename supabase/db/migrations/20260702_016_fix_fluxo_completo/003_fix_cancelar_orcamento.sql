-- Migration 20260702_016 — Parte 3
-- Atualiza cancelar_orcamento para cancelar também parcelas, boletos e
-- invalidar projeto_itens quando o orçamento aprovado for cancelado.
--
-- Problema original:
--   A função criada na migration 015 revertia o estoque mas deixava órfãos:
--   - projeto_parcelas continuavam com status='pendente' → apareciam como dívida ativa
--   - boletos continuavam com status='pendente_registro' → entravam nos KPIs financeiros
--   - projeto_itens permaneciam com validado=true → podiam disparar entrega indevida
--   - Re-aprovação após cancelamento ficava bloqueada pela verificação de idempotência
--
-- Solução:
--   Ao cancelar orcamento aprovado: reverter estoque + cancelar parcelas + cancelar boletos
--   + invalidar projeto_itens (sem deletar — preserva histórico de auditoria).

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
    v_orcamento           public.orcamentos%ROWTYPE;
    v_status_anterior     text;
    v_numero_orcamento    text;
    v_reservas_revertidas integer := 0;
    v_parcelas_canceladas integer := 0;
    v_boletos_cancelados  integer := 0;
    v_itens_invalidados   integer := 0;
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

    -- 2. Idempotência: já cancelado
    IF v_status_anterior = 'cancelado' THEN
        RETURN jsonb_build_object(
            'orcamento_id',          p_orcamento_id,
            'numero',                v_numero_orcamento,
            'status',                'cancelado',
            'reservas_revertidas',   0,
            'parcelas_canceladas',   0,
            'boletos_cancelados',    0,
            'itens_invalidados',     0,
            'ja_cancelado',          true
        );
    END IF;

    -- 3. Se estava aprovado → desfazer todos os efeitos da aprovação

    IF v_status_anterior = 'aprovado' THEN

        -- 3a. Reverter reservas de estoque
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

        -- 3b. Cancelar parcelas financeiras
        UPDATE public.projeto_parcelas
        SET status = 'cancelada'::public.parcela_status
        WHERE orcamento_id = p_orcamento_id
          AND status = 'pendente'::public.parcela_status;

        GET DIAGNOSTICS v_parcelas_canceladas = ROW_COUNT;

        -- 3c. Cancelar boletos
        UPDATE public.boletos
        SET status = 'cancelado'
        WHERE orcamento_id = p_orcamento_id
          AND status IN ('pendente_registro', 'Pendente', 'pendente');

        GET DIAGNOSTICS v_boletos_cancelados = ROW_COUNT;

        -- 3d. Invalidar projeto_itens (preservar histórico, apenas desmarca validado)
        UPDATE public.projeto_itens
        SET validado = false
        WHERE orcamento_id = p_orcamento_id
          AND validado = true;

        GET DIAGNOSTICS v_itens_invalidados = ROW_COUNT;

    END IF;

    -- 4. Atualizar status do orçamento
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
        'parcelas_canceladas', v_parcelas_canceladas,
        'boletos_cancelados',  v_boletos_cancelados,
        'itens_invalidados',   v_itens_invalidados,
        'ja_cancelado',        false
    );
END;
$$;

COMMENT ON FUNCTION public.cancelar_orcamento(uuid, text) IS
'Cancela um orçamento. Se aprovado: reverte quantidade_reservada em estoque_itens,
cancela projeto_parcelas, cancela boletos, invalida projeto_itens.
Todos os artefatos são mantidos para auditoria (soft-cancel). Registra em historico_status_orcamentos.';
