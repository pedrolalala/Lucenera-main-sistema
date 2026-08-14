-- Fix pós-SPEC-099, achado no teste ao vivo do usuário:
--
-- 1) O link Ag.Separar→Separado→Entregue da SPEC-099 foi conectado em
--    separacoes.status='Pronto' e entregas.status='Entregue' — mas
--    NENHUMA tela do Logística (SeparacaoPage/CalendarioPage) lê a
--    tabela `entregas`, e as duas só listam
--    status IN ('material_solicitado','Em separação','separado').
--    'Pronto' nunca aparecia pro Matheus. Corrigido em paralelo no
--    frontend do Logística (adicionar 'Pronto' aos filtros).
--
--    O fluxo real do Matheus finaliza uma entrega direto em
--    separacoes.status='finalizado' (useSeparacoes.ts, finalizarEntrega)
--    — nunca toca a tabela `entregas`. Por isso o trigger
--    sync_entregue_ao_finalizar_entrega (baseado em entregas.status)
--    nunca dispararia na prática. Este arquivo adiciona o trigger
--    equivalente em cima de separacoes.status='finalizado', que é o
--    ponto real onde o Matheus confirma a entrega física.
--
-- 2) Usuário reportou que Estornar bloqueava mesmo sendo admin
--    ("administrador deveria poder fazer isso"). Ajustado:
--    admin/gerente podem estornar mesmo depois de já fisicamente
--    separado (retirando de q_separado em vez de q_ag_separar) — mas
--    nunca depois de já entregue (isso exigiria devolução física real).

ALTER TABLE public.separacao_itens
  ADD COLUMN IF NOT EXISTS entregue boolean DEFAULT false NOT NULL;

CREATE OR REPLACE FUNCTION public.sync_entregue_ao_finalizar_separacao()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_item record;
BEGIN
    IF NEW.status = 'finalizado' AND (OLD.status IS DISTINCT FROM NEW.status) THEN
        FOR v_item IN
            SELECT id, projeto_item_id, quantidade, separado
            FROM public.separacao_itens
            WHERE separacao_id = NEW.id
              AND projeto_item_id IS NOT NULL
              AND NOT entregue
        LOOP
            -- Defensivo: se por algum motivo o item nunca passou por
            -- 'Pronto' (não foi marcado separado), ainda assim move o
            -- que sobrar em q_ag_separar direto pra q_entregue.
            IF v_item.separado THEN
                UPDATE public.estoque_saldos_projeto_item
                SET q_separado = GREATEST(q_separado - v_item.quantidade, 0),
                    q_entregue = q_entregue + v_item.quantidade,
                    atualizado_em = now()
                WHERE projeto_item_id = v_item.projeto_item_id;
            ELSE
                UPDATE public.estoque_saldos_projeto_item
                SET q_ag_separar = GREATEST(q_ag_separar - v_item.quantidade, 0),
                    q_entregue = q_entregue + v_item.quantidade,
                    atualizado_em = now()
                WHERE projeto_item_id = v_item.projeto_item_id;
            END IF;

            UPDATE public.separacao_itens SET entregue = true WHERE id = v_item.id;

            INSERT INTO public.estoque_movimentos_projeto_item
                (projeto_item_id, tipo, quantidade, origem, referencia_id, criado_por)
            VALUES
                (v_item.projeto_item_id, 'entregue', v_item.quantidade, 'separacao_parcial', NEW.id, auth.uid());
        END LOOP;
    END IF;
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_sync_entregue_ao_finalizar_separacao ON public.separacoes;
CREATE TRIGGER trg_sync_entregue_ao_finalizar_separacao
    AFTER UPDATE OF status ON public.separacoes
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_entregue_ao_finalizar_separacao();

COMMENT ON FUNCTION public.sync_entregue_ao_finalizar_separacao IS 'Fix pos-SPEC-099. Quando o Matheus finaliza uma entrega (separacoes.status=finalizado, fluxo real de Logistica), move q_separado/q_ag_separar para q_entregue.';

-- Estorno: admin/gerente podem reverter mesmo já fisicamente separado.
CREATE OR REPLACE FUNCTION public.estornar_item_separacao(
    p_separacao_item_id uuid,
    p_quantidade numeric,
    p_observacao text
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_item              public.separacao_itens%ROWTYPE;
    v_separacao_status  text;
    v_restante          numeric(10,2);
    v_todos_estornados  boolean;
    v_registrado_por    text;
    v_role              public.usuario_role;
BEGIN
    IF p_observacao IS NULL OR btrim(p_observacao) = '' THEN
        RAISE EXCEPTION 'Informe o motivo do estorno.' USING ERRCODE = 'P0001';
    END IF;
    IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
        RAISE EXCEPTION 'Quantidade deve ser maior que zero.' USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_item FROM public.separacao_itens WHERE id = p_separacao_item_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Item de separação % não encontrado.', p_separacao_item_id USING ERRCODE = 'P0001';
    END IF;
    IF v_item.projeto_item_id IS NULL THEN
        RAISE EXCEPTION 'Item de separação % não tem vínculo com projeto_itens — não é possível estornar estoque.', p_separacao_item_id USING ERRCODE = 'P0001';
    END IF;
    IF v_item.entregue THEN
        RAISE EXCEPTION 'Essa peça já foi entregue — não é possível estornar para Reserva por aqui. Use o fluxo de devolução.' USING ERRCODE = 'P0001';
    END IF;

    SELECT role INTO v_role FROM public.usuarios WHERE id = auth.uid();
    IF v_item.separado AND v_role NOT IN ('admin', 'gerente') THEN
        RAISE EXCEPTION 'Essa peça já foi fisicamente separada — apenas admin ou gerente pode estornar nesse estágio.' USING ERRCODE = '42501';
    END IF;

    SELECT status INTO v_separacao_status FROM public.separacoes WHERE id = v_item.separacao_id;
    IF v_separacao_status = 'Cancelado' THEN
        RAISE EXCEPTION 'Essa separação já foi estornada.' USING ERRCODE = 'P0001';
    END IF;

    v_restante := v_item.quantidade - v_item.quantidade_estornada;
    IF p_quantidade > v_restante THEN
        RAISE EXCEPTION 'Quantidade de estorno (%) maior que o restante ainda não estornado (%).', p_quantidade, v_restante USING ERRCODE = 'P0001';
    END IF;

    IF v_item.separado THEN
        UPDATE public.estoque_saldos_projeto_item
        SET q_reserva = q_reserva + p_quantidade,
            q_separado = GREATEST(q_separado - p_quantidade, 0),
            atualizado_em = now()
        WHERE projeto_item_id = v_item.projeto_item_id;
    ELSE
        UPDATE public.estoque_saldos_projeto_item
        SET q_reserva = q_reserva + p_quantidade,
            q_ag_separar = GREATEST(q_ag_separar - p_quantidade, 0),
            atualizado_em = now()
        WHERE projeto_item_id = v_item.projeto_item_id;
    END IF;

    INSERT INTO public.estoque_movimentos_projeto_item
        (projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por)
    VALUES
        (v_item.projeto_item_id, 'cancelamento', p_quantidade, 'separacao_parcial',
         v_item.separacao_id, p_observacao, auth.uid());

    UPDATE public.separacao_itens
    SET quantidade_estornada = quantidade_estornada + p_quantidade
    WHERE id = p_separacao_item_id;

    SELECT NOT EXISTS (
        SELECT 1 FROM public.separacao_itens
        WHERE separacao_id = v_item.separacao_id
          AND quantidade_estornada < quantidade
    ) INTO v_todos_estornados;

    IF v_todos_estornados THEN
        UPDATE public.separacoes
        SET status = 'Cancelado',
            observacoes = trim(both E'\n' from coalesce(observacoes || E'\n', '') || 'Estornado: ' || p_observacao),
            alterado_apos_registro = true,
            alterado_em = now(),
            alterado_por = auth.uid()
        WHERE id = v_item.separacao_id;

        UPDATE public.entregas
        SET observacoes = trim(both E'\n' from coalesce(observacoes || E'\n', '') ||
            '⚠ Separação de origem estornada em ' || to_char(now(), 'DD/MM/YYYY HH24:MI') ||
            ' — revisar antes de entregar. Motivo: ' || p_observacao)
        WHERE separacao_id = v_item.separacao_id
          AND status <> 'Cancelado';

        SELECT nome INTO v_registrado_por FROM public.usuarios WHERE id = auth.uid();

        INSERT INTO public.entregas_pendentes (
            separacao_id, codigo_obra, cliente, endereco, responsavel, telefone,
            tipo_problema, descricao_problema, registrado_por, registrado_por_user_id
        )
        SELECT
            s.id,
            coalesce(s.codigo_obra, s.numero_venda, 'Sem código'),
            coalesce(s.cliente, 'Cliente não identificado'),
            s.endereco_entrega,
            s.responsavel_recebimento,
            s.telefone,
            'separacao_estornada',
            'Separação (venda ' || coalesce(s.numero_venda, '?') || ') foi estornada. Motivo: ' || p_observacao,
            coalesce(v_registrado_por, 'Sistema'),
            auth.uid()
        FROM public.separacoes s
        WHERE s.id = v_item.separacao_id;
    END IF;

    RETURN jsonb_build_object(
        'separacao_item_id', p_separacao_item_id,
        'quantidade_estornada', p_quantidade,
        'separacao_cancelada', v_todos_estornados
    );
END;
$function$;

COMMENT ON FUNCTION public.estornar_item_separacao IS 'SPEC-099 + fix. Reverte peça+quantidade de uma separação para Reserva. Admin/gerente podem reverter mesmo já fisicamente separado (q_separado); bloqueado se já entregue.';
