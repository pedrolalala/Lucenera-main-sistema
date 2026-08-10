-- SPEC-072: Separação Parcial por Setor de Estoque
--
-- Opção A do desenho (a única aplicada aqui): separação só pode sair de
-- q_reserva, seguindo a regra explícita da gravação com o Vinicius
-- ("se o produto não está em reserva, ele não pode ser solicitado uma
-- entrega, uma separação"). Não implementa setor selecionável
-- (Entrega Futura/Entregue) — ver Pendência P-4 da SPEC, ainda em aberto.
--
-- projeto_item_id é nullable de propósito: linhas legadas de
-- separacao_itens (criadas antes desta migration) não têm como ser
-- retroativamente amarradas a uma venda específica.
ALTER TABLE public.separacao_itens
  ADD COLUMN projeto_item_id uuid REFERENCES public.projeto_itens(id) ON DELETE SET NULL;

CREATE INDEX idx_separacao_itens_projeto_item ON public.separacao_itens(projeto_item_id);

CREATE OR REPLACE FUNCTION public.registrar_separacao_setor(
  p_projeto_item_id uuid,
  p_quantidade numeric,
  p_separacao_id uuid DEFAULT NULL,
  p_motivo text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_saldo    public.estoque_saldos_projeto_item%ROWTYPE;
BEGIN
    IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
        RAISE EXCEPTION 'Quantidade deve ser maior que zero.' USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_saldo
    FROM public.estoque_saldos_projeto_item
    WHERE projeto_item_id = p_projeto_item_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Item de projeto % nao possui saldo operacional (estoque_saldos_projeto_item).', p_projeto_item_id USING ERRCODE = 'P0001';
    END IF;

    IF p_quantidade > v_saldo.q_reserva THEN
        RAISE EXCEPTION 'Quantidade de separacao (%) excede o saldo em reserva (%). Separacao so pode sair da reserva.',
            p_quantidade, v_saldo.q_reserva USING ERRCODE = 'P0001';
    END IF;

    UPDATE public.estoque_saldos_projeto_item
    SET q_reserva = q_reserva - p_quantidade,
        q_ag_separar = q_ag_separar + p_quantidade,
        atualizado_em = now()
    WHERE projeto_item_id = p_projeto_item_id;

    INSERT INTO public.estoque_movimentos_projeto_item
        (projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por)
    VALUES
        (p_projeto_item_id, 'solicitacao_separacao', p_quantidade, 'separacao_parcial', p_separacao_id, p_motivo, auth.uid());

    RETURN jsonb_build_object(
        'projeto_item_id', p_projeto_item_id,
        'quantidade', p_quantidade,
        'q_reserva_restante', v_saldo.q_reserva - p_quantidade,
        'q_ag_separar_novo', v_saldo.q_ag_separar + p_quantidade
    );
END;
$function$;
