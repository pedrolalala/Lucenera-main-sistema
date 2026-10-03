-- SPEC-180 (03/10/2026, pedido do usuário): etapa "Recebida" na devolução.
-- Só devolução de ENTREGUE (material que está com o cliente) passa por ela:
-- a aprovação baixa o saldo da venda (q_entregue -> q_devolvida) e grava a
-- devolução como 'aguardando_recebimento', SEM liberar a reserva do produto. Quando
-- a peça chega, alguém confirma na Separação Parcial (confirmar_recebimento_devolucao)
-- e só então o estoque disponível sobe. Reserva / Em separação / Entrega futura
-- continuam como na SPEC-179 ('registrada', efeito imediato).
-- Sem BEGIN/COMMIT no texto (aplicar com dry-run + rollback antes).

ALTER TABLE public.devolucoes_estoque
  ADD COLUMN IF NOT EXISTS recebido_em timestamptz,
  ADD COLUMN IF NOT EXISTS recebido_por uuid,
  ADD COLUMN IF NOT EXISTS observacao_recebimento text;

ALTER TABLE public.devolucoes_estoque DROP CONSTRAINT IF EXISTS devolucoes_estoque_status_check;
ALTER TABLE public.devolucoes_estoque
  ADD CONSTRAINT devolucoes_estoque_status_check
  CHECK (status = ANY (ARRAY['registrada', 'aguardando_coleta', 'coletada', 'cancelada', 'aguardando_recebimento', 'recebida']));

ALTER TABLE public.estoque_movimentos_projeto_item DROP CONSTRAINT IF EXISTS estoque_movimentos_projeto_item_tipo_check;
ALTER TABLE public.estoque_movimentos_projeto_item
  ADD CONSTRAINT estoque_movimentos_projeto_item_tipo_check
  CHECK (tipo = ANY (ARRAY['aprovacao_orcamento', 'alocacao_reserva', 'alocacao_entrega_futura', 'transferencia_saida',
    'transferencia_entrada', 'recebimento_para_reserva', 'solicitacao_separacao', 'separado', 'entregue', 'devolucao',
    'cancelamento', 'devolucao_recebida']));

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

    -- R4: libera a reserva do produto. ENTREGUE não libera aqui: a peça ainda
    -- está com o cliente; só volta ao estoque em confirmar_recebimento_devolucao
    -- (etapa "Recebida", decisão do usuário 03/10).
    IF v_produto_id IS NOT NULL AND p_setor_origem <> 'entregue' THEN
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
        CASE WHEN p_setor_origem = 'entregue' THEN 'aguardando_recebimento' ELSE 'registrada' END,
        p_motivo, auth.uid()
    )
    RETURNING id INTO v_devolucao_id;

    INSERT INTO public.estoque_movimentos_projeto_item
        (projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por)
    VALUES
        (p_projeto_item_id, 'devolucao', p_quantidade, 'devolucao_estoque', v_devolucao_id,
         concat_ws(' — ', 'Setor: ' || p_setor_origem, p_motivo), auth.uid());

    RETURN jsonb_build_object(
        'devolucao_id', v_devolucao_id,
        'status', CASE WHEN p_setor_origem = 'entregue' THEN 'aguardando_recebimento' ELSE 'registrada' END,
        'setor_origem', p_setor_origem,
        'quantidade', p_quantidade
    );
END;
$function$;

-- Confirma que a peça devolvida chegou fisicamente: libera a reserva do produto
-- (o disponível sobe) e marca a devolução como 'recebida'.
CREATE OR REPLACE FUNCTION public.confirmar_recebimento_devolucao(
  p_devolucao_id uuid,
  p_observacao text DEFAULT NULL
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_dev        public.devolucoes_estoque%ROWTYPE;
    v_produto_id uuid;
BEGIN
    IF auth.uid() IS NULL AND COALESCE(auth.role(), '') <> 'service_role' THEN
        RAISE EXCEPTION 'É preciso estar logado para confirmar o recebimento.' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_dev FROM public.devolucoes_estoque WHERE id = p_devolucao_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Devolução % não encontrada.', p_devolucao_id USING ERRCODE = 'P0001';
    END IF;
    IF v_dev.status <> 'aguardando_recebimento' THEN
        RAISE EXCEPTION 'Esta devolução não está aguardando recebimento (status atual: %).', v_dev.status USING ERRCODE = 'P0001';
    END IF;

    SELECT produto_id INTO v_produto_id FROM public.projeto_itens WHERE id = v_dev.projeto_item_id;

    IF v_produto_id IS NOT NULL AND v_dev.qtd_de_entregue > 0 THEN
        UPDATE public.estoque_itens
        SET quantidade_reservada = GREATEST(quantidade_reservada - v_dev.qtd_de_entregue, 0),
            atualizado_em = now()
        WHERE produto_id = v_produto_id
          AND local = 'Estoque'::public.estoque_local;
    END IF;

    UPDATE public.devolucoes_estoque
    SET status = 'recebida',
        recebido_em = now(),
        recebido_por = auth.uid(),
        observacao_recebimento = NULLIF(btrim(p_observacao), '')
    WHERE id = p_devolucao_id;

    INSERT INTO public.estoque_movimentos_projeto_item
        (projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por)
    VALUES
        (v_dev.projeto_item_id, 'devolucao_recebida', v_dev.quantidade, 'devolucao_estoque', v_dev.id,
         NULLIF(btrim(p_observacao), ''), auth.uid());

    RETURN jsonb_build_object('devolucao_id', p_devolucao_id, 'status', 'recebida', 'quantidade', v_dev.quantidade);
END;
$function$;

REVOKE ALL ON FUNCTION public.confirmar_recebimento_devolucao(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirmar_recebimento_devolucao(uuid, text) TO authenticated;

-- Lista para a Separação Parcial: devoluções aprovadas aguardando a peça voltar.
CREATE OR REPLACE VIEW public.vw_devolucoes_aguardando_recebimento
WITH (security_invoker = true) AS
SELECT
  d.id,
  d.criado_em,
  d.quantidade,
  d.motivo,
  pi.descricao       AS produto,
  pr.codigo_produto,
  pr.referencia,
  pi.l_fixo,
  o.numero_venda,
  o.numero           AS orcamento_venda,
  e.nome             AS empresa,
  c.nome             AS cliente,
  pj.codigo          AS projeto_codigo
FROM public.devolucoes_estoque d
JOIN public.projeto_itens pi ON pi.id = d.projeto_item_id
LEFT JOIN public.produtos pr ON pr.id = pi.produto_id
LEFT JOIN public.orcamentos o ON o.id = pi.orcamento_id
LEFT JOIN public.empresas e ON e.id = o.empresa_id
LEFT JOIN public.contatos c ON c.id = o.cliente_id
LEFT JOIN public.projetos pj ON pj.id = o.projeto_id
WHERE d.status = 'aguardando_recebimento';

GRANT SELECT ON public.vw_devolucoes_aguardando_recebimento TO authenticated;

NOTIFY pgrst, 'reload schema';
