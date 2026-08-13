-- SPEC-090: estorno de uma separação parcial já registrada, com observação
-- obrigatória, log de autor/hora e aviso ao logístico (via observações da
-- entrega, sem construir um sistema de notificação novo — decisão do
-- usuário: badge/aviso simples, não notificação completa).
--
-- "Editar" (SPEC-086 item original) foi simplificado, com aprovação do
-- usuário, pra reaproveitar este mesmo mecanismo: estornar e separar de
-- novo com a quantidade certa, em vez de uma terceira RPC de edição.

ALTER TABLE public.separacoes
  ADD COLUMN alterado_apos_registro boolean NOT NULL DEFAULT false,
  ADD COLUMN alterado_em timestamptz,
  ADD COLUMN alterado_por uuid REFERENCES public.usuarios(id);

CREATE OR REPLACE FUNCTION public.estornar_separacao_parcial(
  p_separacao_id uuid,
  p_observacao text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_status text;
  v_item record;
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
    SELECT projeto_item_id, quantidade
    FROM public.separacao_itens
    WHERE separacao_id = p_separacao_id
  LOOP
    UPDATE public.estoque_saldos_projeto_item
    SET q_reserva = q_reserva + v_item.quantidade,
        q_ag_separar = GREATEST(q_ag_separar - v_item.quantidade, 0),
        atualizado_em = now()
    WHERE projeto_item_id = v_item.projeto_item_id;

    INSERT INTO public.estoque_movimentos_projeto_item
      (projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por)
    VALUES
      (v_item.projeto_item_id, 'cancelamento', v_item.quantidade, 'separacao_parcial',
       p_separacao_id, p_observacao, auth.uid());
  END LOOP;

  UPDATE public.separacoes
  SET status = 'Cancelado',
      observacoes = trim(both E'\n' from coalesce(observacoes || E'\n', '') || 'Estornado: ' || p_observacao),
      alterado_apos_registro = true,
      alterado_em = now(),
      alterado_por = auth.uid()
  WHERE id = p_separacao_id;

  -- Aviso ao logístico: se já existir uma entrega vinculada (a separação
  -- tinha completado a venda via SPEC-089), anota o estorno nas
  -- observações dela — visível na tela de Logística sem precisar de
  -- infraestrutura de notificação nova.
  UPDATE public.entregas
  SET observacoes = trim(both E'\n' from coalesce(observacoes || E'\n', '') ||
    '⚠ Separação de origem estornada em ' || to_char(now(), 'DD/MM/YYYY HH24:MI') ||
    ' — revisar antes de entregar. Motivo: ' || p_observacao)
  WHERE separacao_id = p_separacao_id
    AND status <> 'Cancelado';

  RETURN jsonb_build_object('separacao_id', p_separacao_id, 'status', 'Cancelado');
END;
$function$;
