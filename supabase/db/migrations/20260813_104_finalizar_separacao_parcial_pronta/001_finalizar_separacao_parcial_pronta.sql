-- SPEC-089: integração automática entre Separação Parcial e Logística.
--
-- Achado: já existe um trigger (trg_separacao_pronta, AFTER UPDATE OF
-- status, data_entrega ON separacoes) que cria/atualiza automaticamente
-- uma linha em `entregas` quando `separacoes.status` vira 'Pronto' com
-- `data_entrega` preenchida. O fluxo de Separação Parcial (SPEC-072) nunca
-- muda esse status — só grava em estoque_saldos_projeto_item via
-- registrar_separacao_setor — então a automação existente nunca disparava
-- pra esse fluxo.
--
-- Fix (Estratégia A, aprovada pelo usuário): quando a última ação de
-- "Separar" de uma venda deixa TODOS os itens dessa venda com q_reserva=0
-- (nada mais a separar) e o usuário informou uma data de entrega, marca a
-- separação recém-criada como 'Pronto' + data_entrega — reaproveita o
-- trigger já existente, sem duplicar lógica de criação de `entregas`.
--
-- Validação é feita aqui no servidor (não confia no client) — reconfere
-- o saldo real da venda antes de mudar o status.

CREATE OR REPLACE FUNCTION public.finalizar_separacao_parcial_pronta(
  p_separacao_id uuid,
  p_data_entrega date
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_numero_venda text;
  v_pendentes integer;
BEGIN
  IF p_data_entrega IS NULL THEN
    RAISE EXCEPTION 'Informe a data de entrega.' USING ERRCODE = 'P0001';
  END IF;

  SELECT numero_venda INTO v_numero_venda
  FROM public.separacoes
  WHERE id = p_separacao_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Separação % não encontrada.', p_separacao_id USING ERRCODE = 'P0001';
  END IF;

  SELECT count(*) INTO v_pendentes
  FROM public.vw_estoque_saldos_projeto_item
  WHERE orcamento_numero = v_numero_venda
    AND status_operacional = 'ativo'
    AND q_reserva > 0;

  IF v_pendentes > 0 THEN
    RAISE EXCEPTION 'Ainda há % item(ns) com saldo em reserva nesta venda — não é possível marcar como Pronto.', v_pendentes
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.separacoes
  SET status = 'Pronto', data_entrega = p_data_entrega
  WHERE id = p_separacao_id;

  RETURN jsonb_build_object('separacao_id', p_separacao_id, 'status', 'Pronto', 'data_entrega', p_data_entrega);
END;
$function$;
