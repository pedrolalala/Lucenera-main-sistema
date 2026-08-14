-- SPEC-099 — Estorno granular de separação + link real Ag.Separar→Separado→Entregue
--
-- Parte 1: estorno granular (peça + quantidade específica, com "reverter
-- tudo" continuando disponível como orquestração da RPC granular).
--
-- Parte 2: liga os campos q_separado/q_entregue de estoque_saldos_projeto_item
-- (existem desde a SPEC-010, nunca escritos) aos pontos reais que a
-- Separação Parcial/Logística novas já usam: separacoes.status = 'Pronto' e
-- entregas.status = 'Entregue'. Não mexe nos 424 registros antigos do
-- fluxo legado de Logística (nunca tiveram separacao_itens vinculado,
-- decisão explícita do usuário de não tentar backfill).

-- ============================================================
-- PARTE 1 — Estorno granular
-- ============================================================

ALTER TABLE public.separacao_itens
  ADD COLUMN IF NOT EXISTS quantidade_estornada numeric(10,2) DEFAULT 0 NOT NULL;

ALTER TABLE public.separacao_itens
  ADD CONSTRAINT separacao_itens_quantidade_estornada_check
  CHECK (quantidade_estornada >= 0 AND quantidade_estornada <= quantidade);

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
    IF v_item.separado THEN
        RAISE EXCEPTION 'Essa peça já foi fisicamente separada — não é possível estornar para Reserva por aqui. Use o fluxo de devolução.' USING ERRCODE = 'P0001';
    END IF;

    SELECT status INTO v_separacao_status FROM public.separacoes WHERE id = v_item.separacao_id;
    IF v_separacao_status = 'Cancelado' THEN
        RAISE EXCEPTION 'Essa separação já foi estornada.' USING ERRCODE = 'P0001';
    END IF;

    v_restante := v_item.quantidade - v_item.quantidade_estornada;
    IF p_quantidade > v_restante THEN
        RAISE EXCEPTION 'Quantidade de estorno (%) maior que o restante ainda não estornado (%).', p_quantidade, v_restante USING ERRCODE = 'P0001';
    END IF;

    UPDATE public.estoque_saldos_projeto_item
    SET q_reserva = q_reserva + p_quantidade,
        q_ag_separar = GREATEST(q_ag_separar - p_quantidade, 0),
        atualizado_em = now()
    WHERE projeto_item_id = v_item.projeto_item_id;

    INSERT INTO public.estoque_movimentos_projeto_item
        (projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por)
    VALUES
        (v_item.projeto_item_id, 'cancelamento', p_quantidade, 'separacao_parcial',
         v_item.separacao_id, p_observacao, auth.uid());

    UPDATE public.separacao_itens
    SET quantidade_estornada = quantidade_estornada + p_quantidade
    WHERE id = p_separacao_item_id;

    -- Se todos os itens da separação já foram totalmente estornados, a
    -- separação inteira vira Cancelado e dispara o mesmo aviso ao Matheus
    -- que a SPEC-090 já fazia — senão, fica Pendente com o que restou.
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

CREATE OR REPLACE FUNCTION public.estornar_separacao_parcial(p_separacao_id uuid, p_observacao text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_status  text;
    v_item    record;
    v_ultimo  jsonb;
BEGIN
    IF p_observacao IS NULL OR btrim(p_observacao) = '' THEN
        RAISE EXCEPTION 'Informe o motivo do estorno.' USING ERRCODE = 'P0001';
    END IF;

    SELECT status INTO v_status FROM public.separacoes WHERE id = p_separacao_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Separação % não encontrada.', p_separacao_id USING ERRCODE = 'P0001';
    END IF;
    IF v_status = 'Cancelado' THEN
        RAISE EXCEPTION 'Essa separação já foi estornada.' USING ERRCODE = 'P0001';
    END IF;

    FOR v_item IN
        SELECT id, (quantidade - quantidade_estornada) AS restante
        FROM public.separacao_itens
        WHERE separacao_id = p_separacao_id
          AND quantidade_estornada < quantidade
    LOOP
        v_ultimo := public.estornar_item_separacao(v_item.id, v_item.restante, p_observacao);
    END LOOP;

    RETURN jsonb_build_object('separacao_id', p_separacao_id, 'status', 'Cancelado', 'ultimo_item', v_ultimo);
END;
$function$;

COMMENT ON FUNCTION public.estornar_item_separacao IS 'SPEC-099. Reverte só uma peça + quantidade específica de uma separação para Reserva (em vez da separação inteira).';
COMMENT ON FUNCTION public.estornar_separacao_parcial IS 'SPEC-099 (refatorada). "Reverter tudo": orquestra estornar_item_separacao para cada item ainda não totalmente estornado.';

-- ============================================================
-- PARTE 2 — Link Ag.Separar → Separado → Entregue
-- ============================================================

CREATE OR REPLACE FUNCTION public.sync_separado_ao_ficar_pronto()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_item record;
BEGIN
    IF NEW.status = 'Pronto' AND (OLD.status IS DISTINCT FROM NEW.status) THEN
        FOR v_item IN
            SELECT id, projeto_item_id, quantidade
            FROM public.separacao_itens
            WHERE separacao_id = NEW.id
              AND projeto_item_id IS NOT NULL
              AND NOT separado
        LOOP
            UPDATE public.estoque_saldos_projeto_item
            SET q_ag_separar = GREATEST(q_ag_separar - v_item.quantidade, 0),
                q_separado = q_separado + v_item.quantidade,
                atualizado_em = now()
            WHERE projeto_item_id = v_item.projeto_item_id;

            UPDATE public.separacao_itens SET separado = true WHERE id = v_item.id;

            INSERT INTO public.estoque_movimentos_projeto_item
                (projeto_item_id, tipo, quantidade, origem, referencia_id, criado_por)
            VALUES
                (v_item.projeto_item_id, 'separado', v_item.quantidade, 'separacao_parcial', NEW.id, auth.uid());
        END LOOP;
    END IF;
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_sync_separado_ao_ficar_pronto ON public.separacoes;
CREATE TRIGGER trg_sync_separado_ao_ficar_pronto
    AFTER UPDATE OF status ON public.separacoes
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_separado_ao_ficar_pronto();

CREATE OR REPLACE FUNCTION public.sync_entregue_ao_finalizar_entrega()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_item record;
BEGIN
    IF NEW.status = 'Entregue' AND (OLD.status IS DISTINCT FROM NEW.status) AND NEW.separacao_id IS NOT NULL THEN
        FOR v_item IN
            SELECT projeto_item_id, quantidade
            FROM public.separacao_itens
            WHERE separacao_id = NEW.separacao_id
              AND projeto_item_id IS NOT NULL
        LOOP
            UPDATE public.estoque_saldos_projeto_item
            SET q_separado = GREATEST(q_separado - v_item.quantidade, 0),
                q_entregue = q_entregue + v_item.quantidade,
                atualizado_em = now()
            WHERE projeto_item_id = v_item.projeto_item_id;

            INSERT INTO public.estoque_movimentos_projeto_item
                (projeto_item_id, tipo, quantidade, origem, referencia_id, criado_por)
            VALUES
                (v_item.projeto_item_id, 'entregue', v_item.quantidade, 'entrega', NEW.id, auth.uid());
        END LOOP;
    END IF;
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_sync_entregue_ao_finalizar_entrega ON public.entregas;
CREATE TRIGGER trg_sync_entregue_ao_finalizar_entrega
    AFTER UPDATE OF status ON public.entregas
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_entregue_ao_finalizar_entrega();

COMMENT ON FUNCTION public.sync_separado_ao_ficar_pronto IS 'SPEC-099. Quando uma separação vira Pronto, move a quantidade dos seus itens de q_ag_separar para q_separado.';
COMMENT ON FUNCTION public.sync_entregue_ao_finalizar_entrega IS 'SPEC-099. Quando uma entrega vira Entregue, move a quantidade dos itens da separação vinculada de q_separado para q_entregue.';
