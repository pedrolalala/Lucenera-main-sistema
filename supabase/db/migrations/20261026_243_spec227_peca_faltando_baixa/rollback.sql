BEGIN;

DROP FUNCTION IF EXISTS public.movimentar_peca_venda(uuid, text, numeric, text, boolean);

CREATE OR REPLACE FUNCTION public.movimentar_peca_venda(p_projeto_item_id uuid, p_acao text, p_quantidade numeric, p_motivo text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_motivo   text := NULLIF(btrim(coalesce(p_motivo, '')), '');
  v_q        numeric := round(coalesce(p_quantidade, 0), 3);
  v_produto  uuid;
  v_saldo    public.estoque_saldos_projeto_item%ROWTYPE;
  v_origem   text;
  v_destino  text;
  v_o_antes  numeric;
  v_d_antes  numeric;
  v_livre    numeric;
  v_resta    numeric;
  v_sep      record;
  v_parte    numeric;
  v_numero   bigint;
BEGIN
  IF NOT public._mov_pode() THEN
    RAISE EXCEPTION 'Sem permissao para movimentar pecas.' USING ERRCODE = '42501';
  END IF;
  IF v_motivo IS NULL THEN
    RAISE EXCEPTION 'Informe o motivo da movimentacao.' USING ERRCODE = 'P0001';
  END IF;
  IF v_q <= 0 THEN
    RAISE EXCEPTION 'A quantidade precisa ser maior que zero.' USING ERRCODE = 'P0001';
  END IF;

  SELECT produto_id INTO v_produto FROM public.projeto_itens WHERE id = p_projeto_item_id;
  SELECT * INTO v_saldo FROM public.estoque_saldos_projeto_item WHERE projeto_item_id = p_projeto_item_id FOR UPDATE;
  IF v_produto IS NULL OR v_saldo.projeto_item_id IS NULL THEN
    RAISE EXCEPTION 'Item de venda (L) nao encontrado.' USING ERRCODE = 'P0001';
  END IF;
  PERFORM 1 FROM public.estoque_itens WHERE produto_id = v_produto AND local = 'Estoque' FOR UPDATE;

  IF p_acao = 'reserva_para_entrega_futura' THEN
    v_origem := 'Reserva'; v_destino := 'Entrega Futura';
    v_o_antes := v_saldo.q_reserva; v_d_antes := v_saldo.q_entrega_futura;
    IF v_q > v_saldo.q_reserva THEN
      RAISE EXCEPTION 'O L tem % em reserva (pedido: %).', v_saldo.q_reserva, v_q USING ERRCODE = 'P0001';
    END IF;
    UPDATE public.estoque_saldos_projeto_item
       SET q_reserva = q_reserva - v_q, q_entrega_futura = q_entrega_futura + v_q, atualizado_em = now()
     WHERE projeto_item_id = p_projeto_item_id;
    INSERT INTO public.estoque_movimentos_projeto_item (projeto_item_id, tipo, quantidade, origem, observacao, criado_por)
    VALUES (p_projeto_item_id, 'alocacao_entrega_futura', v_q, 'movimentacao_pecas',
            'Reserva -> Entrega Futura: ' || v_motivo, auth.uid());

  ELSIF p_acao = 'entrega_futura_para_reserva' THEN
    v_origem := 'Entrega Futura'; v_destino := 'Reserva';
    v_o_antes := v_saldo.q_entrega_futura; v_d_antes := v_saldo.q_reserva;
    IF v_q > v_saldo.q_entrega_futura THEN
      RAISE EXCEPTION 'O L tem % em entrega futura (pedido: %).', v_saldo.q_entrega_futura, v_q USING ERRCODE = 'P0001';
    END IF;
    -- peça física livre no Estoque Geral (sem reserva/separação de ninguém)
    v_livre := public._mov_livre_estoque_geral(v_produto);
    IF coalesce(v_livre, 0) < v_q THEN
      RAISE EXCEPTION 'So % peca(s) livres no Estoque Geral para reservar.', greatest(coalesce(v_livre, 0), 0)
        USING ERRCODE = 'P0001';
    END IF;
    UPDATE public.estoque_saldos_projeto_item
       SET q_entrega_futura = q_entrega_futura - v_q, q_reserva = q_reserva + v_q, atualizado_em = now()
     WHERE projeto_item_id = p_projeto_item_id;
    INSERT INTO public.estoque_movimentos_projeto_item (projeto_item_id, tipo, quantidade, origem, observacao, criado_por)
    VALUES (p_projeto_item_id, 'alocacao_reserva', v_q, 'movimentacao_pecas',
            'Entrega Futura -> Reserva: ' || v_motivo, auth.uid());

  ELSIF p_acao = 'separacao_para_reserva' THEN
    v_origem := 'Separação'; v_destino := 'Reserva';
    v_o_antes := v_saldo.q_ag_separar + v_saldo.q_separado; v_d_antes := v_saldo.q_reserva;
    IF v_q > v_o_antes THEN
      RAISE EXCEPTION 'O L tem % em separacao (pedido: %).', v_o_antes, v_q USING ERRCODE = 'P0001';
    END IF;
    -- usa o estorno da Separação Parcial (mesmas regras: peça já separada só admin/gerente; entregue não volta)
    v_resta := v_q;
    FOR v_sep IN
      SELECT id, quantidade - quantidade_estornada AS restante FROM public.separacao_itens
       WHERE projeto_item_id = p_projeto_item_id AND NOT entregue AND quantidade > quantidade_estornada
       ORDER BY created_at DESC
    LOOP
      EXIT WHEN v_resta <= 0;
      v_parte := least(v_resta, v_sep.restante);
      PERFORM public.estornar_item_separacao(v_sep.id, v_parte, 'Movimentação de Peças: ' || v_motivo);
      v_resta := v_resta - v_parte;
    END LOOP;
    IF v_resta > 0 THEN
      RAISE EXCEPTION 'Nao ha separacao em aberto suficiente para este L (faltou %).', v_resta USING ERRCODE = 'P0001';
    END IF;

  ELSE
    RAISE EXCEPTION 'Acao invalida: use reserva_para_entrega_futura, entrega_futura_para_reserva ou separacao_para_reserva.'
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.movimentacoes_peca
    (produto_id, quantidade, tipo, origem, destino, projeto_item_id, motivo, saldo_origem_antes, saldo_origem_depois,
     saldo_destino_antes, saldo_destino_depois, criado_por)
  VALUES (v_produto, v_q, 'venda', v_origem, v_destino, p_projeto_item_id, v_motivo, v_o_antes, v_o_antes - v_q,
          v_d_antes, v_d_antes + v_q, auth.uid())
  RETURNING numero INTO v_numero;

  RETURN jsonb_build_object('numero', v_numero, 'origem', v_origem, 'destino', v_destino, 'quantidade', v_q);
END;
$function$;

REVOKE ALL ON FUNCTION public.movimentar_peca_venda(uuid, text, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.movimentar_peca_venda(uuid, text, numeric, text) TO authenticated;

COMMIT;
