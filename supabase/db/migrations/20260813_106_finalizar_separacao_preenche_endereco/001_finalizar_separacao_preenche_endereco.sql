-- SPEC-089 (correção, achada em teste ao vivo 2026-08-13): a entrega criada
-- automaticamente por finalizar_separacao_parcial_pronta() nunca recebia
-- endereço, porque `separacoes.endereco_entrega` não é preenchido em
-- nenhum lugar do fluxo novo de Separação Parcial (SPEC-072) — ao contrário
-- do fluxo antigo de Logística, onde o próprio usuário digitava esse campo
-- direto em `separacoes` antes de marcar como Pronto. O trigger
-- trg_separacao_pronta copia esse campo (NULL) pra `entregas`, e a tela de
-- Logística (SeparacaoCardDetails.tsx) mostra "N/A" pro entregador — a
-- automação criava a entrega, mas sem informação suficiente pra entregar.
--
-- Fix: no momento de marcar como Pronto, se `endereco_entrega`/`telefone`
-- ainda estiverem vazios, preenche a partir do cadastro do cliente
-- (contatos.endereco_entrega, fallback pro endereço principal se o cliente
-- não tiver endereço de entrega cadastrado à parte). Usa COALESCE — nunca
-- sobrescreve um valor já existente (ex.: caso um dia a UI passe a coletar
-- isso direto, ou um registro antigo já tenha sido preenchido manualmente).

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
  v_cliente_id uuid;
  v_endereco text;
  v_telefone text;
BEGIN
  IF p_data_entrega IS NULL THEN
    RAISE EXCEPTION 'Informe a data de entrega.' USING ERRCODE = 'P0001';
  END IF;

  SELECT numero_venda, cliente_id INTO v_numero_venda, v_cliente_id
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

  IF v_cliente_id IS NOT NULL THEN
    SELECT
      NULLIF(trim(both ', ' from
        concat_ws(', ',
          NULLIF(trim(concat_ws(' ', COALESCE(c.endereco_entrega, c.endereco), c.numero_entrega)), ''),
          NULLIF(c.bairro_entrega, ''),
          NULLIF(c.cidade_entrega, ''),
          NULLIF(c.estado_entrega, '')
        )
      ), ''),
      NULLIF(COALESCE(c.celular, c.telefone), '')
    INTO v_endereco, v_telefone
    FROM public.contatos c
    WHERE c.id = v_cliente_id;
  END IF;

  UPDATE public.separacoes
  SET status = 'Pronto',
      data_entrega = p_data_entrega,
      endereco_entrega = COALESCE(endereco_entrega, v_endereco),
      telefone = COALESCE(telefone, v_telefone)
  WHERE id = p_separacao_id;

  RETURN jsonb_build_object('separacao_id', p_separacao_id, 'status', 'Pronto', 'data_entrega', p_data_entrega);
END;
$function$;
