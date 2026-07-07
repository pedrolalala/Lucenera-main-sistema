-- Migration 20260704_018 — Parte 3
-- RPCs: cliente_aprovar_orcamento e cliente_recusar_orcamento
-- Ambas validam token, mudam status e invalidam o token após uso.
-- Também inclui: adm_aprovar_pelo_cliente (aprovação manual sem token — casos presenciais).

-- ─────────────────────────────────────────────────────────────────────────────
-- cliente_aprovar_orcamento
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.cliente_aprovar_orcamento(
    p_orcamento_id uuid,
    p_token        text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_orcamento public.orcamentos%ROWTYPE;
    v_numero    text;
BEGIN
    SELECT * INTO v_orcamento
    FROM public.orcamentos
    WHERE id = p_orcamento_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Orçamento não encontrado.'
            USING ERRCODE = 'P0001';
    END IF;

    v_numero := coalesce(v_orcamento.numero, left(p_orcamento_id::text, 8));

    -- Valida token
    IF v_orcamento.token_aprovacao_cliente IS NULL
       OR v_orcamento.token_aprovacao_cliente <> p_token THEN
        RAISE EXCEPTION
            'Token inválido ou expirado para o orçamento %.',
            v_numero
            USING ERRCODE = 'P0001';
    END IF;

    -- Valida status
    IF v_orcamento.status <> 'enviado_cliente' THEN
        RAISE EXCEPTION
            'Orçamento % não está aguardando aprovação do cliente. Status atual: %.',
            v_numero, v_orcamento.status
            USING ERRCODE = 'P0002';
    END IF;

    UPDATE public.orcamentos
    SET status                   = 'aprovado_cliente',
        aprovado_cliente_em      = now(),
        token_aprovacao_cliente  = NULL   -- token de uso único: invalida após uso
    WHERE id = p_orcamento_id;

    INSERT INTO public.historico_status_orcamentos (
        orcamento_id, status_anterior, status_novo, usuario, observacao
    ) VALUES (
        p_orcamento_id,
        'enviado_cliente',
        'aprovado_cliente',
        'cliente',
        'Orçamento aprovado pelo cliente via link'
    );

    RETURN jsonb_build_object(
        'orcamento_id', p_orcamento_id,
        'numero',        v_numero,
        'status',        'aprovado_cliente',
        'aprovado_em',   now()
    );
END;
$$;

COMMENT ON FUNCTION public.cliente_aprovar_orcamento(uuid, text) IS
'Aprovação do cliente via token (link enviado por e-mail/WhatsApp).
Token é de uso único — invalidado após aprovação. Registra em historico_status_orcamentos.';


-- ─────────────────────────────────────────────────────────────────────────────
-- cliente_recusar_orcamento
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.cliente_recusar_orcamento(
    p_orcamento_id uuid,
    p_token        text,
    p_motivo       text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_orcamento public.orcamentos%ROWTYPE;
    v_numero    text;
BEGIN
    SELECT * INTO v_orcamento
    FROM public.orcamentos
    WHERE id = p_orcamento_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Orçamento não encontrado.'
            USING ERRCODE = 'P0001';
    END IF;

    v_numero := coalesce(v_orcamento.numero, left(p_orcamento_id::text, 8));

    IF v_orcamento.token_aprovacao_cliente IS NULL
       OR v_orcamento.token_aprovacao_cliente <> p_token THEN
        RAISE EXCEPTION
            'Token inválido ou expirado para o orçamento %.',
            v_numero
            USING ERRCODE = 'P0001';
    END IF;

    IF v_orcamento.status <> 'enviado_cliente' THEN
        RAISE EXCEPTION
            'Orçamento % não está aguardando aprovação do cliente. Status atual: %.',
            v_numero, v_orcamento.status
            USING ERRCODE = 'P0002';
    END IF;

    UPDATE public.orcamentos
    SET status                  = 'recusado_cliente',
        recusado_cliente_em     = now(),
        motivo_recusa_cliente   = p_motivo,
        token_aprovacao_cliente = NULL
    WHERE id = p_orcamento_id;

    INSERT INTO public.historico_status_orcamentos (
        orcamento_id, status_anterior, status_novo, usuario, observacao
    ) VALUES (
        p_orcamento_id,
        'enviado_cliente',
        'recusado_cliente',
        'cliente',
        coalesce(p_motivo, 'Orçamento recusado pelo cliente via link')
    );

    RETURN jsonb_build_object(
        'orcamento_id', p_orcamento_id,
        'numero',        v_numero,
        'status',        'recusado_cliente',
        'motivo',        p_motivo,
        'recusado_em',   now()
    );
END;
$$;

COMMENT ON FUNCTION public.cliente_recusar_orcamento(uuid, text, text) IS
'Recusa do cliente via token (link enviado por e-mail/WhatsApp).
Registra motivo e invalida o token. Permite reenvio posterior via enviar_orcamento_para_cliente.';


-- ─────────────────────────────────────────────────────────────────────────────
-- adm_aprovar_pelo_cliente
-- Aprovação manual pela ADM para casos presenciais/verbais (sem token)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.adm_aprovar_pelo_cliente(
    p_orcamento_id uuid,
    p_observacao   text DEFAULT 'Aprovação registrada manualmente pela administração'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_orcamento public.orcamentos%ROWTYPE;
    v_numero    text;
BEGIN
    SELECT * INTO v_orcamento
    FROM public.orcamentos
    WHERE id = p_orcamento_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Orçamento não encontrado.'
            USING ERRCODE = 'P0001';
    END IF;

    v_numero := coalesce(v_orcamento.numero, left(p_orcamento_id::text, 8));

    IF v_orcamento.status NOT IN ('aguardando_aprovacao', 'enviado_cliente', 'recusado_cliente') THEN
        RAISE EXCEPTION
            'Não é possível registrar aprovação do cliente para orçamento % com status %.',
            v_numero, v_orcamento.status
            USING ERRCODE = 'P0002';
    END IF;

    UPDATE public.orcamentos
    SET status                  = 'aprovado_cliente',
        aprovado_cliente_em     = now(),
        token_aprovacao_cliente = NULL
    WHERE id = p_orcamento_id;

    INSERT INTO public.historico_status_orcamentos (
        orcamento_id, status_anterior, status_novo, usuario, observacao
    ) VALUES (
        p_orcamento_id,
        v_orcamento.status,
        'aprovado_cliente',
        auth.uid()::text,
        p_observacao
    );

    RETURN jsonb_build_object(
        'orcamento_id', p_orcamento_id,
        'numero',        v_numero,
        'status',        'aprovado_cliente',
        'aprovado_em',   now(),
        'manual',        true
    );
END;
$$;

COMMENT ON FUNCTION public.adm_aprovar_pelo_cliente(uuid, text) IS
'Registra aprovação do cliente manualmente (casos presenciais/verbais, sem token).
Permitido apenas pela ADM (SECURITY DEFINER). Registra em historico_status_orcamentos.';
