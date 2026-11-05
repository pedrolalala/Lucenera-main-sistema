-- SPEC-243 FASE 2 (RASCUNHO, NÃO APLICADA) — "matar" a herança da Connect: só Matheus e administração.
--
-- Reunião de 04/11: peça reservada/em entrega futura da Connect que já saiu ou que não sai mais precisa ser baixada, com OBSERVAÇÃO e LOG, e o
-- estoque tem que acompanhar. A conta é a MESMA da SPEC-232 (venda do sistema): ao entregar, o saldo sai da Reserva, o Estoque Geral físico baixa e o
-- reservado é liberado na mesma medida; ao cancelar, o saldo sai e só o reservado é liberado (a peça volta a ficar disponível).
-- Em TODAS as ações vale o invariante da SPEC-232: variação do `quantidade_reservada` = variação de (Reserva + Entrega Futura + Separação), então a
-- "Reserva sem venda (herança Connect)" de OUTROS clientes nunca muda.
--
--   Ação                           Saldo do item                     Estoque Geral (quantidade)   Reservado (quantidade_reservada)
--   entregue_baixa_estoque         Reserva −q, Entregue +q           −q  (a peça saiu e a Connect ainda a contava)   −q
--   entregue_estoque_ja_ajustado   Reserva −q, Entregue +q           0   (o físico já foi corrigido, ex.: contagem)  −q   <- o "check não mexe no estoque"
--   nao_sera_entregue              Reserva ou E.Futura −q, Devolvida +q   0  (a peça está no estoque: volta a ficar disponível)   −q
--   mantida_confirmada / observacao  nenhuma                         0                             0   (só registra e tira da fila)
--
-- Entrega Futura não tem peça física: só `nao_sera_entregue` ou `mantida_confirmada`.
-- NÃO cria crédito, NÃO gera financeiro, NÃO é devolução (é só baixar a herança). Reimportar as planilhas (remover_connect_lote) passa a ser recusado
-- nos orçamentos tratados (já recusava quando há Entregue/Devolvida): por isso a fase 2 só deve ser usada DEPOIS da importação final da Connect (07/11).
BEGIN;

-- Os nomes de ação do rascunho da 264 viram os definitivos (a tabela está vazia).
ALTER TABLE public.connect_reserva_tratamento DROP CONSTRAINT IF EXISTS connect_reserva_tratamento_acao_check;
ALTER TABLE public.connect_reserva_tratamento
  ADD CONSTRAINT connect_reserva_tratamento_acao_check CHECK (acao IN
    ('mantida_confirmada', 'entregue_baixa_estoque', 'entregue_estoque_ja_ajustado', 'nao_sera_entregue', 'observacao'));
ALTER TABLE public.connect_reserva_tratamento
  ADD COLUMN IF NOT EXISTS projeto_item_id uuid REFERENCES public.projeto_itens (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS setor text CHECK (setor IS NULL OR setor IN ('reserva', 'entrega_futura'));

CREATE OR REPLACE FUNCTION public.tratar_heranca_connect(
  p_projeto_item_id uuid, p_acao text, p_setor text, p_quantidade numeric, p_observacao text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
DECLARE
  v_item   record;
  v_saldo  record;
  v_chave  text;
  v_q      numeric := 0;
  v_disp   numeric;
  v_baixa  boolean := false;
  v_mov    text;
  v_tid    uuid;
BEGIN
  IF NOT public.pode_tratar_heranca_connect() THEN
    RAISE EXCEPTION 'Só o Matheus ou um administrador pode tratar a herança da Connect.' USING ERRCODE = '42501';
  END IF;
  IF p_acao NOT IN ('mantida_confirmada', 'entregue_baixa_estoque', 'entregue_estoque_ja_ajustado', 'nao_sera_entregue', 'observacao') THEN
    RAISE EXCEPTION 'Ação inválida: %', p_acao USING ERRCODE = 'P0001';
  END IF;
  IF p_setor IS NULL OR p_setor NOT IN ('reserva', 'entrega_futura') THEN
    RAISE EXCEPTION 'Informe o setor: reserva ou entrega_futura.' USING ERRCODE = 'P0001';
  END IF;
  IF p_observacao IS NULL OR length(btrim(p_observacao)) = 0 THEN
    RAISE EXCEPTION 'A observação é obrigatória (registra por que a peça foi baixada).' USING ERRCODE = 'P0001';
  END IF;

  -- só item de orçamento da Connect
  SELECT pi.id, pi.produto_id, pi.orcamento_id, pi.quantidade, o.origem, o.numero AS orc_numero
    INTO v_item
    FROM public.projeto_itens pi JOIN public.orcamentos o ON o.id = pi.orcamento_id
   WHERE pi.id = p_projeto_item_id;
  IF NOT FOUND OR v_item.origem IS DISTINCT FROM 'connect' THEN
    RAISE EXCEPTION 'Este item não é herança da Connect.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_saldo FROM public.estoque_saldos_projeto_item WHERE projeto_item_id = p_projeto_item_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Item sem saldo.' USING ERRCODE = 'P0001';
  END IF;

  -- chave da linha da planilha (sobrevive à reimportação)
  SELECT r.chave INTO v_chave FROM public.connect_reserva_ambiente r
   WHERE r.projeto_item_id = p_projeto_item_id AND r.tipo = p_setor LIMIT 1;

  IF p_acao IN ('mantida_confirmada', 'observacao') THEN
    v_q := 0;
  ELSE
    v_q := coalesce(p_quantidade, 0);
    IF v_q <= 0 THEN
      RAISE EXCEPTION 'Informe a quantidade.' USING ERRCODE = 'P0001';
    END IF;
    IF p_setor = 'entrega_futura' AND p_acao <> 'nao_sera_entregue' THEN
      RAISE EXCEPTION 'Entrega Futura não tem peça física: só dá para marcar "não será entregue" ou manter.' USING ERRCODE = 'P0001';
    END IF;
    v_disp := CASE WHEN p_setor = 'reserva' THEN v_saldo.q_reserva ELSE v_saldo.q_entrega_futura END;
    IF v_q > v_disp THEN
      RAISE EXCEPTION 'Quantidade maior que o saldo em % deste item.', p_setor USING ERRCODE = 'P0001';
    END IF;

    IF p_acao LIKE 'entregue_%' THEN
      v_baixa := (p_acao = 'entregue_baixa_estoque');
      UPDATE public.estoque_saldos_projeto_item
         SET q_reserva = q_reserva - v_q, q_entregue = q_entregue + v_q, atualizado_em = now()
       WHERE projeto_item_id = p_projeto_item_id;
      v_mov := 'entregue';
    ELSE
      IF p_setor = 'reserva' THEN
        UPDATE public.estoque_saldos_projeto_item
           SET q_reserva = q_reserva - v_q, q_devolvida = q_devolvida + v_q, atualizado_em = now()
         WHERE projeto_item_id = p_projeto_item_id;
      ELSE
        UPDATE public.estoque_saldos_projeto_item
           SET q_entrega_futura = q_entrega_futura - v_q, q_devolvida = q_devolvida + v_q, atualizado_em = now()
         WHERE projeto_item_id = p_projeto_item_id;
      END IF;
      v_mov := 'cancelamento';
    END IF;

    -- Estoque: o reservado sempre é liberado (invariante SPEC-232); o físico só baixa quando a peça realmente saiu e a Connect ainda a contava.
    UPDATE public.estoque_itens
       SET quantidade_reservada = GREATEST(quantidade_reservada - v_q, 0),
           quantidade = CASE WHEN v_baixa THEN GREATEST(quantidade - v_q, 0) ELSE quantidade END,
           atualizado_em = now()
     WHERE produto_id = v_item.produto_id AND local = 'Estoque'::public.estoque_local;

    INSERT INTO public.estoque_movimentos_projeto_item (projeto_item_id, tipo, quantidade, origem, observacao, criado_por)
    VALUES (p_projeto_item_id, v_mov, v_q, 'tratar_heranca_connect', left(p_observacao, 500), auth.uid());
  END IF;

  INSERT INTO public.connect_reserva_tratamento (chave, acao, mexe_estoque, quantidade, observacao, projeto_item_id, setor)
  VALUES (coalesce(v_chave, 'sem_chave:' || p_projeto_item_id::text), p_acao, v_baixa, nullif(v_q, 0), btrim(p_observacao), p_projeto_item_id, p_setor)
  RETURNING id INTO v_tid;

  RETURN jsonb_build_object('tratamento_id', v_tid, 'orcamento', v_item.orc_numero, 'acao', p_acao, 'setor', p_setor, 'quantidade', v_q, 'baixou_estoque_fisico', v_baixa);
END
$fn$;

REVOKE ALL ON FUNCTION public.tratar_heranca_connect(uuid, text, text, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tratar_heranca_connect(uuid, text, text, numeric, text) TO authenticated;

COMMIT;
