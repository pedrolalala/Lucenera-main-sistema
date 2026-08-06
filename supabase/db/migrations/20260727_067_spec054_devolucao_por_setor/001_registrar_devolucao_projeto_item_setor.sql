-- SPEC-054 — Interface de Devolução de Estoque (linhas manuais por setor de origem)
--
-- Cria a RPC `registrar_devolucao_projeto_item_setor`, que recebe o setor de
-- origem explicitamente por chamada ('entrega_futura' | 'reserva' |
-- 'entregue'), em vez de fazer o rateio em cascata automático que
-- `registrar_devolucao_projeto_item` (SPEC-015) já faz. Decisão do usuário
-- (2026-07-27): a tela de devolução exige lançamento manual de uma linha por
-- setor, replicando o processo descrito por Vinicius na reunião de
-- 27/07/2026.
--
-- A função original `registrar_devolucao_projeto_item` (rateio automático)
-- permanece intocada — nenhum frontend em nenhum dos 8 sistemas a consome
-- hoje, mas é mantida por segurança, sem custo em deixá-la.
--
-- Texto copiado literalmente da seção "Desenho da nova RPC" da SPEC-054
-- (`03-Projeto/Planos de Ação/SPECs/SPEC-054_Interface_Devolucao_Estoque.md`),
-- já confirmado contra o texto real do banco em 2026-07-27 via
-- `pg_get_functiondef`/`information_schema.columns`.

CREATE OR REPLACE FUNCTION public.registrar_devolucao_projeto_item_setor(
  p_projeto_item_id uuid,
  p_setor_origem text, -- 'entrega_futura' | 'reserva' | 'entregue'
  p_quantidade numeric,
  p_motivo text DEFAULT NULL
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
    v_status       text;
    v_devolucao_id uuid;
BEGIN
    IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
        RAISE EXCEPTION 'Quantidade deve ser maior que zero.' USING ERRCODE = 'P0001';
    END IF;

    IF p_setor_origem NOT IN ('entrega_futura', 'reserva', 'entregue') THEN
        RAISE EXCEPTION 'Setor de origem inválido: %. Use entrega_futura, reserva ou entregue.', p_setor_origem
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
        WHEN 'entregue' THEN v_saldo.q_entregue
    END;

    IF p_quantidade > v_saldo_setor THEN
        RAISE EXCEPTION 'Quantidade de devolucao (%) excede o saldo do setor % (%).',
            p_quantidade, p_setor_origem, v_saldo_setor USING ERRCODE = 'P0001';
    END IF;

    -- q_entregue nunca decrementa (histórico), mesmo quando o setor de origem é 'entregue'.
    UPDATE public.estoque_saldos_projeto_item
    SET q_entrega_futura = q_entrega_futura - CASE WHEN p_setor_origem = 'entrega_futura' THEN p_quantidade ELSE 0 END,
        q_reserva = q_reserva - CASE WHEN p_setor_origem = 'reserva' THEN p_quantidade ELSE 0 END,
        q_devolvida = q_devolvida + p_quantidade,
        atualizado_em = now()
    WHERE projeto_item_id = p_projeto_item_id;

    -- Mesma regra RN-08 da função original: quantidade_reservada só é liberada
    -- pela parte que veio de entrega_futura ou reserva.
    IF p_setor_origem IN ('entrega_futura', 'reserva') AND v_produto_id IS NOT NULL THEN
        UPDATE public.estoque_itens
        SET quantidade_reservada = GREATEST(quantidade_reservada - p_quantidade, 0)
        WHERE produto_id = v_produto_id
          AND local = 'Estoque'::public.estoque_local;
    END IF;

    v_status := CASE WHEN p_setor_origem = 'entregue' THEN 'aguardando_coleta' ELSE 'registrada' END;

    INSERT INTO public.devolucoes_estoque (
        projeto_item_id, quantidade, qtd_de_entrega_futura, qtd_de_reserva, qtd_de_entregue,
        status, motivo, solicitado_por
    ) VALUES (
        p_projeto_item_id, p_quantidade,
        CASE WHEN p_setor_origem = 'entrega_futura' THEN p_quantidade ELSE 0 END,
        CASE WHEN p_setor_origem = 'reserva' THEN p_quantidade ELSE 0 END,
        CASE WHEN p_setor_origem = 'entregue' THEN p_quantidade ELSE 0 END,
        v_status, p_motivo, auth.uid()
    )
    RETURNING id INTO v_devolucao_id;

    INSERT INTO public.estoque_movimentos_projeto_item
        (projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por)
    VALUES
        (p_projeto_item_id, 'devolucao', p_quantidade, 'devolucao_estoque', v_devolucao_id, p_motivo, auth.uid());

    RETURN jsonb_build_object(
        'devolucao_id', v_devolucao_id,
        'status', v_status,
        'setor_origem', p_setor_origem,
        'quantidade', p_quantidade
    );
END;
$function$;

COMMENT ON FUNCTION public.registrar_devolucao_projeto_item_setor(uuid, text, numeric, text) IS
  'SPEC-054 — Registra devolução de estoque com setor de origem explícito por chamada (entrega_futura | reserva | entregue), para lançamento manual de uma linha por setor na UI (compras-lucenera-3o23t98ee). Complementa, sem substituir, registrar_devolucao_projeto_item (SPEC-015, rateio automático em cascata), que permanece intocada.';

-- Achado da revisão (2026-07-27): faltava o GRANT — sem ele, a chamada via
-- supabase.rpc(...) como usuário authenticated falharia com "permission
-- denied for function". Mesmo padrão já usado por registrar_devolucao_projeto_item
-- (SPEC-015, migration 20260707_027) e por toda a família de RPCs deste domínio.
GRANT EXECUTE ON FUNCTION public.registrar_devolucao_projeto_item_setor(uuid, text, numeric, text) TO authenticated;
