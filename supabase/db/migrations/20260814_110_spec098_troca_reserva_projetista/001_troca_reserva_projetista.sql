-- SPEC-098 — Troca de peça em Reserva entre projetos (Projetistas/Gerente/Admin)
--
-- Reaproveita o mecanismo já existente da SPEC-011 (transferencias_estoque,
-- solicitar_transferencia_estoque, aprovar_transferencia_estoque), que nunca
-- teve frontend. Duas mudanças:
--
-- 1) aprovar_transferencia_estoque: guard estendido. Hoje só libera
--    role IN ('admin','gerente'). Passa a liberar também quem tem
--    funcionarios.cargo = 'Projetista'. Sem checagem de equipe entre os
--    projetos (decisão do usuário — substitui a ideia inicial de comparar
--    funcionarios_financeiro.equipes_id/projetos.equipe_id).
--
-- 2) trocar_reserva_projetista: RPC nova que só orquestra
--    solicitar_transferencia_estoque + aprovar_transferencia_estoque numa
--    chamada só, pra troca ser imediata (sem etapa manual de aprovação).

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

CREATE OR REPLACE FUNCTION public.trocar_reserva_projetista(
    p_origem_projeto_item_id uuid,
    p_destino_projeto_item_id uuid,
    p_quantidade numeric,
    p_motivo text DEFAULT NULL
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_transferencia_id uuid;
    v_solicitar        jsonb;
BEGIN
    v_solicitar := public.solicitar_transferencia_estoque(
        p_origem_projeto_item_id, p_destino_projeto_item_id, p_quantidade, p_motivo
    );
    v_transferencia_id := (v_solicitar->>'transferencia_id')::uuid;

    RETURN public.aprovar_transferencia_estoque(v_transferencia_id);
END;
$function$;

COMMENT ON FUNCTION public.trocar_reserva_projetista IS 'SPEC-098. Troca imediata de peça em Reserva entre dois projetos, para Projetista/gerente/admin — orquestra solicitar_transferencia_estoque + aprovar_transferencia_estoque (SPEC-011) numa chamada só.';

-- Espelha exatamente o guard de aprovar_transferencia_estoque, pra frontend
-- decidir se mostra o botão "Trocar" sem duplicar a regra em SQL client-side
-- (RLS de usuarios/funcionarios não é garantia de leitura própria em todo
-- contexto, e duplicar a regra em dois lugares arrisca ela divergir).
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

COMMENT ON FUNCTION public.pode_trocar_reserva IS 'SPEC-098. true se o usuário logado pode usar trocar_reserva_projetista (Projetista/gerente/admin) — usado pelo frontend pra decidir se mostra a ação Trocar.';
