-- SPEC-051 — Fase explícita de Rascunho antes do envio ao cliente
--
-- Com a remoção da auto-transição em `handle_orcamento_workflow()` e em
-- `handle_orcamento_item_workflow()` (migrations 001 e 002 deste grupo),
-- `enviar_orcamento_para_cliente` passa a ser o único ponto de entrada
-- para `enviado_cliente`. Hoje ela só valida o status anterior, sem
-- validar completude — decisão do usuário (P-1, SPEC-051): adicionar
-- guard de campos obrigatórios e de existência de itens antes do UPDATE,
-- para não deixar passar um rascunho incompleto.

CREATE OR REPLACE FUNCTION public.enviar_orcamento_para_cliente(p_orcamento_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_orcamento  public.orcamentos%ROWTYPE;
    v_numero     text;
    v_status_ant text;
    v_token      text;
    v_has_items  boolean := false;
    v_faltando   text[] := ARRAY[]::text[];
    v_msg        text;
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

    IF v_status_ant NOT IN ('aguardando_aprovacao', 'recusado_cliente', 'rascunho') THEN
        RAISE EXCEPTION
            'Orçamento % não pode ser enviado ao cliente: status atual é %. '
            'Permitido apenas em: aguardando_aprovacao, recusado_cliente.',
            v_numero, v_status_ant
            USING ERRCODE = 'P0002';
    END IF;

    -- SPEC-051: validação de completude antes de aceitar o envio.
    IF v_orcamento.empresa_id IS NULL THEN
        v_faltando := array_append(v_faltando, 'Empresa');
    END IF;
    IF v_orcamento.projeto_id IS NULL THEN
        v_faltando := array_append(v_faltando, 'Projeto');
    END IF;
    IF v_orcamento.cliente_id IS NULL THEN
        v_faltando := array_append(v_faltando, 'Cliente');
    END IF;
    IF v_orcamento.forma_pagamento IS NULL THEN
        v_faltando := array_append(v_faltando, 'Forma de Pagamento');
    END IF;

    SELECT EXISTS(
        SELECT 1 FROM public.orcamento_itens WHERE orcamento_id = p_orcamento_id
    ) INTO v_has_items;

    IF array_length(v_faltando, 1) > 0 OR NOT v_has_items THEN
        v_msg := 'Não é possível enviar ao cliente: ';
        IF array_length(v_faltando, 1) > 0 THEN
            v_msg := v_msg || 'preencha ' || array_to_string(v_faltando, ', ') || '.';
        END IF;
        IF NOT v_has_items THEN
            IF array_length(v_faltando, 1) > 0 THEN
                v_msg := v_msg || ' ';
            END IF;
            v_msg := v_msg || 'Adicione pelo menos um item.';
        END IF;
        RAISE EXCEPTION '%', v_msg
            USING ERRCODE = 'P0003';
    END IF;

    v_token := gen_random_uuid()::text;

    UPDATE public.orcamentos
    SET status                  = 'enviado_cliente',
        enviado_cliente_em      = now(),
        enviado_cliente_por     = auth.uid(),
        token_aprovacao_cliente = v_token,
        recusado_cliente_em     = NULL,
        motivo_recusa_cliente   = NULL
    WHERE id = p_orcamento_id;

    INSERT INTO public.historico_status_orcamentos (
        orcamento_id, status_anterior, status_novo, usuario, observacao
    ) VALUES (
        p_orcamento_id, v_status_ant, 'enviado_cliente',
        auth.uid()::text, 'Orçamento enviado ao cliente para aprovação'
    );

    RETURN jsonb_build_object(
        'orcamento_id', p_orcamento_id,
        'numero',        v_numero,
        'status',        'enviado_cliente',
        'token',         v_token,
        'enviado_em',    now()
    );
END;
$function$
;

COMMENT ON FUNCTION public.enviar_orcamento_para_cliente(uuid) IS
  'SPEC-051 (27/07/2026): adicionada validação de completude (empresa, projeto, cliente, forma de pagamento, ao menos 1 item) antes de aceitar o envio ao cliente, já que agora é o único ponto de entrada para enviado_cliente.';
