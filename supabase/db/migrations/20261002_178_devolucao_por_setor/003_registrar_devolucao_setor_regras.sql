-- SPEC-178 (R1-R4, 02/10/2026): devolução por setor da venda de origem.
--
-- Setores: reserva, entrega_futura, em_separacao (a separar + separado) e
-- entregue. O limite de cada linha é o saldo daquele setor; a soma dos setores
-- é sempre (vendido - já devolvido), garantido pelo trigger
-- fn_validar_saldo_projeto_item.
--
-- Efeito no estoque (R4): a aprovação da venda soma a quantidade inteira em
-- estoque_itens.quantidade_reservada (reserva e entrega futura) e nada libera
-- essa reserva na separação/entrega. Por isso, em QUALQUER setor, devolver n
-- libera n de quantidade_reservada:
--   * reserva / em separação / entregue: material físico — o disponível do
--     produto sobe n (decisão do usuário: entregue volta ao estoque já na
--     aprovação da devolução, sem etapa de coleta);
--   * entrega futura: devolução virtual — o disponível negativo (necessidade
--     de compra) diminui n, sem entrada física.
-- Observação: estoque_itens(local='Estoque') é sobrescrito pelo sync do
-- Connect (fn_sync_estoque_itens_from_produtos), como já acontece com a
-- reserva feita na aprovação da venda.
--
-- Mudanças em relação à versão SPEC-054:
--   * novo setor em_separacao (decisão do usuário), que tira a quantidade da
--     fila de separação (separacao_itens.quantidade_estornada);
--   * entregue passa a baixar q_entregue e liberar a reserva, com status
--     'registrada' (antes ficava 'aguardando_coleta' sem nenhum fluxo de
--     entrada, e somar q_devolvida sem baixar q_entregue estourava o trigger
--     de validação quando todo o vendido já estava entregue).

CREATE OR REPLACE FUNCTION public.registrar_devolucao_projeto_item_setor(
  p_projeto_item_id uuid,
  p_setor_origem text,
  p_quantidade numeric,
  p_motivo text DEFAULT NULL::text
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_saldo        public.estoque_saldos_projeto_item%ROWTYPE;
    v_produto_id   uuid;
    v_saldo_setor  numeric(10,3);
    v_de_ag        numeric(10,3) := 0;
    v_de_sep       numeric(10,3) := 0;
    v_restante     numeric(10,3);
    v_sep_item     record;
    v_consumir     numeric(10,3);
    v_devolucao_id uuid;
BEGIN
    IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
        RAISE EXCEPTION 'Quantidade deve ser maior que zero.' USING ERRCODE = 'P0001';
    END IF;

    IF p_setor_origem NOT IN ('entrega_futura', 'reserva', 'em_separacao', 'entregue') THEN
        RAISE EXCEPTION 'Setor de origem inválido: %. Use reserva, entrega_futura, em_separacao ou entregue.', p_setor_origem
            USING ERRCODE = 'P0001';
    END IF;

    SELECT produto_id INTO v_produto_id FROM public.projeto_itens WHERE id = p_projeto_item_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Item de projeto % nao encontrado.', p_projeto_item_id USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_saldo
    FROM public.estoque_saldos_projeto_item
    WHERE projeto_item_id = p_projeto_item_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Item de projeto % nao possui saldo operacional (estoque_saldos_projeto_item).', p_projeto_item_id USING ERRCODE = 'P0001';
    END IF;

    v_saldo_setor := CASE p_setor_origem
        WHEN 'entrega_futura' THEN v_saldo.q_entrega_futura
        WHEN 'reserva' THEN v_saldo.q_reserva
        WHEN 'em_separacao' THEN v_saldo.q_ag_separar + v_saldo.q_separado
        WHEN 'entregue' THEN v_saldo.q_entregue
    END;

    IF p_quantidade > v_saldo_setor THEN
        RAISE EXCEPTION 'Quantidade de devolucao (%) excede o saldo do setor % (%).',
            p_quantidade, p_setor_origem, v_saldo_setor USING ERRCODE = 'P0001';
    END IF;

    IF p_setor_origem = 'em_separacao' THEN
        v_de_ag := LEAST(p_quantidade, v_saldo.q_ag_separar);
        v_de_sep := p_quantidade - v_de_ag;
    END IF;

    UPDATE public.estoque_saldos_projeto_item
    SET q_entrega_futura = q_entrega_futura - CASE WHEN p_setor_origem = 'entrega_futura' THEN p_quantidade ELSE 0 END,
        q_reserva        = q_reserva        - CASE WHEN p_setor_origem = 'reserva' THEN p_quantidade ELSE 0 END,
        q_ag_separar     = q_ag_separar     - v_de_ag,
        q_separado       = q_separado       - v_de_sep,
        q_entregue       = q_entregue       - CASE WHEN p_setor_origem = 'entregue' THEN p_quantidade ELSE 0 END,
        q_devolvida      = q_devolvida + p_quantidade,
        atualizado_em = now()
    WHERE projeto_item_id = p_projeto_item_id;

    -- Em separação: tira a quantidade da fila de separação (mesmo campo do
    -- estorno), primeiro do que ainda está "a separar", depois do "separado".
    IF p_setor_origem = 'em_separacao' THEN
        v_restante := p_quantidade;
        FOR v_sep_item IN
            SELECT si.id, si.separacao_id, si.quantidade - si.quantidade_estornada AS aberto
            FROM public.separacao_itens si
            JOIN public.separacoes s ON s.id = si.separacao_id
            WHERE si.projeto_item_id = p_projeto_item_id
              AND NOT si.entregue
              AND si.quantidade_estornada < si.quantidade
              AND s.status IS DISTINCT FROM 'Cancelado'
            ORDER BY si.separado, si.id
            FOR UPDATE OF si
        LOOP
            EXIT WHEN v_restante <= 0;
            v_consumir := LEAST(v_restante, v_sep_item.aberto);
            UPDATE public.separacao_itens
            SET quantidade_estornada = quantidade_estornada + v_consumir
            WHERE id = v_sep_item.id;
            v_restante := v_restante - v_consumir;

            IF NOT EXISTS (
                SELECT 1 FROM public.separacao_itens
                WHERE separacao_id = v_sep_item.separacao_id
                  AND quantidade_estornada < quantidade
            ) THEN
                UPDATE public.separacoes
                SET status = 'Cancelado',
                    observacoes = trim(both E'\n' from coalesce(observacoes || E'\n', '') ||
                        'Itens devolvidos: ' || coalesce(p_motivo, 'devolução')),
                    alterado_apos_registro = true,
                    alterado_em = now(),
                    alterado_por = auth.uid()
                WHERE id = v_sep_item.separacao_id;
            END IF;
        END LOOP;
    END IF;

    -- R4: libera a reserva do produto em qualquer setor (ver cabeçalho).
    IF v_produto_id IS NOT NULL THEN
        UPDATE public.estoque_itens
        SET quantidade_reservada = GREATEST(quantidade_reservada - p_quantidade, 0),
            atualizado_em = now()
        WHERE produto_id = v_produto_id
          AND local = 'Estoque'::public.estoque_local;
    END IF;

    INSERT INTO public.devolucoes_estoque (
        projeto_item_id, quantidade, qtd_de_entrega_futura, qtd_de_reserva, qtd_de_entregue,
        status, motivo, solicitado_por
    ) VALUES (
        p_projeto_item_id, p_quantidade,
        CASE WHEN p_setor_origem = 'entrega_futura' THEN p_quantidade ELSE 0 END,
        -- em separação é material físico reservado: registra junto da reserva
        CASE WHEN p_setor_origem IN ('reserva', 'em_separacao') THEN p_quantidade ELSE 0 END,
        CASE WHEN p_setor_origem = 'entregue' THEN p_quantidade ELSE 0 END,
        'registrada', p_motivo, auth.uid()
    )
    RETURNING id INTO v_devolucao_id;

    INSERT INTO public.estoque_movimentos_projeto_item
        (projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por)
    VALUES
        (p_projeto_item_id, 'devolucao', p_quantidade, 'devolucao_estoque', v_devolucao_id,
         concat_ws(' — ', 'Setor: ' || p_setor_origem, p_motivo), auth.uid());

    RETURN jsonb_build_object(
        'devolucao_id', v_devolucao_id,
        'status', 'registrada',
        'setor_origem', p_setor_origem,
        'quantidade', p_quantidade
    );
END;
$function$;
