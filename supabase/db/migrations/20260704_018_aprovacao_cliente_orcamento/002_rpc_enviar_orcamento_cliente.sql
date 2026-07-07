-- Migration 20260704_018 — Parte 2
-- RPC: enviar_orcamento_para_cliente
-- Muda status para 'enviado_cliente', gera token único e registra histórico.
-- Pode ser chamada novamente após recusa para reenviar com novo token.

CREATE OR REPLACE FUNCTION public.enviar_orcamento_para_cliente(
    p_orcamento_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_orcamento      public.orcamentos%ROWTYPE;
    v_numero         text;
    v_status_ant     text;
    v_token          text;
BEGIN
    SELECT * INTO v_orcamento
    FROM public.orcamentos
    WHERE id = p_orcamento_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Orçamento % não encontrado.', p_orcamento_id
            USING ERRCODE = 'P0001';
    END IF;

    v_numero     := coalesce(v_orcamento.numero, left(p_orcamento_id::text, 8));
    v_status_ant := v_orcamento.status;

    -- Só permite envio nos status de rascunho ou após recusa do cliente
    IF v_status_ant NOT IN ('aguardando_aprovacao', 'recusado_cliente', 'rascunho') THEN
        RAISE EXCEPTION
            'Orçamento % não pode ser enviado ao cliente: status atual é %. '
            'Permitido apenas em: aguardando_aprovacao, recusado_cliente.',
            v_numero, v_status_ant
            USING ERRCODE = 'P0002';
    END IF;

    -- Gera token único de uso único
    v_token := gen_random_uuid()::text;

    UPDATE public.orcamentos
    SET status                   = 'enviado_cliente',
        enviado_cliente_em       = now(),
        enviado_cliente_por      = auth.uid(),
        token_aprovacao_cliente  = v_token,
        -- Limpa dados de recusa anterior ao reenviar
        recusado_cliente_em      = NULL,
        motivo_recusa_cliente    = NULL
    WHERE id = p_orcamento_id;

    INSERT INTO public.historico_status_orcamentos (
        orcamento_id, status_anterior, status_novo, usuario, observacao
    ) VALUES (
        p_orcamento_id,
        v_status_ant,
        'enviado_cliente',
        auth.uid()::text,
        'Orçamento enviado ao cliente para aprovação'
    );

    RETURN jsonb_build_object(
        'orcamento_id', p_orcamento_id,
        'numero',        v_numero,
        'status',        'enviado_cliente',
        'token',         v_token,
        'enviado_em',    now()
    );
END;
$$;

COMMENT ON FUNCTION public.enviar_orcamento_para_cliente(uuid) IS
'Envia orçamento para aprovação do cliente. Gera token único para o link de aprovação.
Permitido em: aguardando_aprovacao, recusado_cliente. Registra em historico_status_orcamentos.';
