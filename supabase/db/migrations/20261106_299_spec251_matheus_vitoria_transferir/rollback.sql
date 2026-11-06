-- SPEC-251: volta pode_trocar_reserva() e aprovar_transferencia_estoque() à regra de antes (admin, gerente e Projetista) e tira o módulo e as exceções.
CREATE OR REPLACE FUNCTION public.pode_trocar_reserva()
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_role public.usuario_role;
BEGIN
    SELECT role INTO v_role FROM public.usuarios WHERE id = auth.uid();
    IF v_role IN ('admin', 'gerente') THEN
        RETURN true;
    END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.funcionarios
        WHERE usuario_id = auth.uid() AND btrim(cargo) = 'Projetista'
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.aprovar_transferencia_estoque(p_transferencia_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_transf     public.transferencias_estoque%ROWTYPE;
    v_origem     public.estoque_saldos_projeto_item%ROWTYPE;
    v_destino    public.estoque_saldos_projeto_item%ROWTYPE;
    v_role       public.usuario_role;
    v_reduzir_ef numeric(10,3);
BEGIN
    SELECT role INTO v_role FROM public.usuarios WHERE id = auth.uid();

    IF v_role IS NULL OR v_role NOT IN ('admin', 'gerente') THEN
        -- btrim: dado real tem "Projetista " com espaço sobrando (Marina/Thairine).
        IF NOT EXISTS (
            SELECT 1 FROM public.funcionarios
            WHERE usuario_id = auth.uid() AND btrim(cargo) = 'Projetista'
        ) THEN
            RAISE EXCEPTION 'Apenas Projetista, gerente ou admin pode aprovar transferencia de estoque.' USING ERRCODE = '42501';
        END IF;
    END IF;

    SELECT * INTO v_transf FROM public.transferencias_estoque WHERE id = p_transferencia_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transferencia % nao encontrada.', p_transferencia_id USING ERRCODE = 'P0001';
    END IF;

    IF v_transf.status <> 'solicitada' THEN
        RAISE EXCEPTION 'Transferencia % nao esta mais solicitada (status atual: %).', p_transferencia_id, v_transf.status USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_origem
    FROM public.estoque_saldos_projeto_item
    WHERE projeto_item_id = v_transf.origem_projeto_item_id
    FOR UPDATE;

    SELECT * INTO v_destino
    FROM public.estoque_saldos_projeto_item
    WHERE projeto_item_id = v_transf.destino_projeto_item_id
    FOR UPDATE;

    IF v_origem.q_reserva < v_transf.quantidade THEN
        RAISE EXCEPTION 'Origem nao tem mais q_reserva suficiente (era % no momento da solicitacao).', v_transf.quantidade USING ERRCODE = 'P0001';
    END IF;

    v_reduzir_ef := LEAST(v_transf.quantidade, v_destino.q_entrega_futura);

    UPDATE public.estoque_saldos_projeto_item
    SET q_reserva = q_reserva - v_transf.quantidade,
        q_entrega_futura = q_entrega_futura + v_transf.quantidade,
        q_transferida_saida = q_transferida_saida + v_transf.quantidade,
        atualizado_em = now()
    WHERE projeto_item_id = v_transf.origem_projeto_item_id;

    UPDATE public.estoque_saldos_projeto_item
    SET q_entrega_futura = q_entrega_futura - v_reduzir_ef,
        q_reserva = q_reserva + v_transf.quantidade,
        atualizado_em = now()
    WHERE projeto_item_id = v_transf.destino_projeto_item_id;

    INSERT INTO public.estoque_movimentos_projeto_item
        (projeto_item_id, projeto_item_destino_id, tipo, quantidade, origem, referencia_id, criado_por)
    VALUES
        (v_transf.origem_projeto_item_id, v_transf.destino_projeto_item_id, 'transferencia_saida', v_transf.quantidade, 'transferencia_estoque', v_transf.id, auth.uid());

    INSERT INTO public.estoque_movimentos_projeto_item
        (projeto_item_id, projeto_item_destino_id, tipo, quantidade, origem, referencia_id, criado_por)
    VALUES
        (v_transf.destino_projeto_item_id, v_transf.origem_projeto_item_id, 'transferencia_entrada', v_transf.quantidade, 'transferencia_estoque', v_transf.id, auth.uid());

    UPDATE public.transferencias_estoque
    SET status = 'aprovada', aprovado_por = auth.uid(), aprovado_em = now()
    WHERE id = p_transferencia_id;

    RETURN jsonb_build_object('transferencia_id', p_transferencia_id, 'status', 'aprovada');
END;
$function$;

DELETE FROM public.usuario_permissao_excecoes
 WHERE modulo_id IN (SELECT m.id FROM public.modulos m JOIN public.systems s ON s.id = m.system_id
                      WHERE s.slug = 'separacao-parcial' AND m.chave = 'transferir_reserva');
DELETE FROM public.modulos
 WHERE chave = 'transferir_reserva' AND system_id = (SELECT id FROM public.systems WHERE slug = 'separacao-parcial');
