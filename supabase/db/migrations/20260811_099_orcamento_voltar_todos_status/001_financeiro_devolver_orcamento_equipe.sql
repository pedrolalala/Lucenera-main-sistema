-- Migration 20260811_099 — Parte 1
-- Pedido do usuário: poder "voltar" em qualquer status do funil de
-- orçamentos, não só enviado_cliente/rascunho (já existia) e
-- 'Aprovação da Equipe' -> enviado_cliente (equipe_devolver_orcamento_cliente,
-- SPEC-031, já existia). Faltava 'Aprovação Financeira' -> 'Aprovação da
-- Equipe' — degrau seguro, é só um flip de status, nenhum side-effect ainda
-- foi criado nesse ponto do funil (projeto_itens/parcelas/boletos só nascem
-- na aprovação financeira em si, ver aprovar_orcamento_financeiro).
--
-- Permissão: mesma exigida para aprovar financeiramente (hub_pode_executar
-- 'orcamentos'/'aprovar', ou admin/gerente, ou service_role) — quem pode
-- aprovar financeiramente também pode devolver.

CREATE OR REPLACE FUNCTION public.financeiro_devolver_orcamento_equipe(
  p_orcamento_id uuid,
  p_motivo text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_orcamento public.orcamentos%ROWTYPE;
  v_status_anterior text;
  v_numero text;
  v_user_role text;
BEGIN
  IF p_motivo IS NULL OR btrim(p_motivo) = '' THEN
    RAISE EXCEPTION 'Informe o motivo antes de devolver o orçamento para a equipe.' USING ERRCODE = 'P0001';
  END IF;

  SELECT u.role INTO v_user_role FROM public.usuarios u WHERE u.id = auth.uid();

  IF NOT (
    COALESCE(auth.role(), '') = 'service_role'
    OR v_user_role IN ('admin', 'gerente')
    OR public.hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'aprovar')
  ) THEN
    RAISE EXCEPTION 'Permissão negada para devolver orçamento para a equipe.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_orcamento FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento não encontrado.' USING ERRCODE = 'P0001';
  END IF;

  v_status_anterior := v_orcamento.status;
  v_numero := COALESCE(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.status <> 'Aprovação Financeira' THEN
    RAISE EXCEPTION 'Orçamento % não está em Aprovação Financeira. Status atual: %', v_numero, v_status_anterior
      USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.orcamentos
  SET status = 'Aprovação da Equipe',
      requer_revisao_financeira = false
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (p_orcamento_id, v_status_anterior, 'Aprovação da Equipe', auth.uid()::text, p_motivo);

  RETURN jsonb_build_object('orcamento_id', p_orcamento_id, 'numero', v_numero, 'status', 'Aprovação da Equipe');
END;
$function$;

COMMENT ON FUNCTION public.financeiro_devolver_orcamento_equipe(uuid, text) IS
'Devolve um orçamento de Aprovação Financeira para Aprovação da Equipe.
Flip de status simples — nenhum projeto_itens/parcela/boleto foi criado
ainda nesse ponto do funil, então não há nada a desfazer. p_motivo é
obrigatório e fica registrado em historico_status_orcamentos.observacao.';

GRANT EXECUTE ON FUNCTION public.financeiro_devolver_orcamento_equipe(uuid, text) TO authenticated;
