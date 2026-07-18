-- Migration 20260718_050 — Parte 3 (SPEC-031)
-- Duas RPCs novas para a etapa "Aprovação da Equipe":
--   equipe_aprovar_orcamento: Aprovação da Equipe -> Aprovação Financeira
--   equipe_devolver_orcamento_cliente: Aprovação da Equipe -> enviado_cliente
--     (equipe alterou peça/cor na visita à obra, cliente precisa aprovar de
--     novo — gera token novo, análogo ao reset que já existe em
--     handle_orcamento_workflow() para edição pós-aprovação financeira)
--
-- Permissão: admin/gerente sempre podem (consistente com o restante do
-- fluxo de aprovação); qualquer outro usuário precisa da permissão do módulo
-- "aprovacao_equipe" no sistema "orcamentos" via hub_pode_executar (SPEC-006),
-- ação 'editar' (ver 001 desta pasta — não existe ação 'aprovar' no CHECK
-- constraint do Hub hoje).

CREATE OR REPLACE FUNCTION public.equipe_aprovar_orcamento(
  p_orcamento_id uuid,
  p_observacao text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_orcamento public.orcamentos%ROWTYPE;
  v_status_anterior text;
  v_numero text;
  v_user_role text;
BEGIN
  SELECT u.role INTO v_user_role FROM public.usuarios u WHERE u.id = auth.uid();

  IF NOT (
    v_user_role IN ('admin', 'gerente')
    OR public.hub_pode_executar(auth.uid(), 'orcamentos', 'aprovacao_equipe', 'editar')
  ) THEN
    RAISE EXCEPTION 'Permissão negada para aprovar como equipe.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_orcamento FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento não encontrado.' USING ERRCODE = 'P0001';
  END IF;

  v_status_anterior := v_orcamento.status;
  v_numero := COALESCE(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.status <> 'Aprovação da Equipe' THEN
    RAISE EXCEPTION 'Orçamento % não está em Aprovação da Equipe. Status atual: %', v_numero, v_status_anterior
      USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.orcamentos
  SET status = 'Aprovação Financeira',
      requer_revisao_financeira = true
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (p_orcamento_id, v_status_anterior, 'Aprovação Financeira', auth.uid()::text,
          COALESCE(p_observacao, 'Aprovado pela equipe após visita à obra — encaminhado para revisão financeira'));

  RETURN jsonb_build_object('orcamento_id', p_orcamento_id, 'numero', v_numero, 'status', 'Aprovação Financeira');
END;
$function$;

COMMENT ON FUNCTION public.equipe_aprovar_orcamento(uuid, text) IS
'SPEC-031. Transição Aprovação da Equipe -> Aprovação Financeira, disparada
pela equipe depois da visita à obra confirmando peças/cores. Seta
requer_revisao_financeira = true (deixou de ser setado na aprovação do
cliente — ver migration 002 desta pasta).';

GRANT EXECUTE ON FUNCTION public.equipe_aprovar_orcamento(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.equipe_devolver_orcamento_cliente(
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
    RAISE EXCEPTION 'Informe o motivo da alteração antes de devolver ao cliente.' USING ERRCODE = 'P0001';
  END IF;

  SELECT u.role INTO v_user_role FROM public.usuarios u WHERE u.id = auth.uid();

  IF NOT (
    v_user_role IN ('admin', 'gerente')
    OR public.hub_pode_executar(auth.uid(), 'orcamentos', 'aprovacao_equipe', 'editar')
  ) THEN
    RAISE EXCEPTION 'Permissão negada para devolver orçamento ao cliente.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_orcamento FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento não encontrado.' USING ERRCODE = 'P0001';
  END IF;

  v_status_anterior := v_orcamento.status;
  v_numero := COALESCE(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.status <> 'Aprovação da Equipe' THEN
    RAISE EXCEPTION 'Orçamento % não está em Aprovação da Equipe. Status atual: %', v_numero, v_status_anterior
      USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.orcamentos
  SET status = 'enviado_cliente',
      token_aprovacao_cliente = public.gen_token_hex(),
      enviado_cliente_em = now(),
      enviado_cliente_por = auth.uid(),
      aprovado_cliente_em = NULL,
      aprovado_cliente_origem = NULL,
      requer_revisao_financeira = false
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (p_orcamento_id, v_status_anterior, 'enviado_cliente', auth.uid()::text, p_motivo);

  RETURN jsonb_build_object('orcamento_id', p_orcamento_id, 'numero', v_numero, 'status', 'enviado_cliente');
END;
$function$;

COMMENT ON FUNCTION public.equipe_devolver_orcamento_cliente(uuid, text) IS
'SPEC-031. Transição Aprovação da Equipe -> enviado_cliente, para quando a
equipe altera peça/cor na visita à obra e o cliente precisa aprovar a versão
revisada de novo. Gera token_aprovacao_cliente novo (invalida o link
anterior), limpa aprovado_cliente_em/aprovado_cliente_origem. p_motivo é
obrigatório e fica registrado em historico_status_orcamentos.observacao.';

GRANT EXECUTE ON FUNCTION public.equipe_devolver_orcamento_cliente(uuid, text) TO authenticated;
