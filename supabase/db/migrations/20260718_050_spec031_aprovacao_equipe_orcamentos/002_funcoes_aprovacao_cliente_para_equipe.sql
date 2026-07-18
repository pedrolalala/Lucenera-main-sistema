-- Migration 20260718_050 — Parte 2 (SPEC-031)
-- As 5 funcoes abaixo, ate agora, levavam a aprovacao do cliente direto para
-- a fila financeira ('Aprovação Financeira'). Com a etapa nova da SPEC-031,
-- elas passam a levar para 'Aprovação da Equipe' — a equipe (apos visita a
-- obra) decide se avanca para o financeiro (equipe_aprovar_orcamento, ver
-- 003) ou devolve ao cliente para nova aprovacao (equipe_devolver_orcamento_cliente,
-- ver 003), caso precise trocar peca/cor.
--
-- requer_revisao_financeira passa a ser setado em equipe_aprovar_orcamento
-- (quem de fato coloca o orcamento na fila financeira), nao mais aqui — por
-- isso as 5 funcoes abaixo agora setam requer_revisao_financeira = false ao
-- entrar em 'Aprovação da Equipe' (era true antes, quando aprovacao do
-- cliente = entrada direta na fila financeira).
--
-- Os guards de entrada (exigir status = 'enviado_cliente' ou equivalente, e
-- a checagem de token/role) NAO mudam — só o destino da transição de saída.
-- aprovado_cliente_em/aprovado_cliente_origem/token_aprovacao_cliente=NULL
-- continuam sendo setados igual, pois continuam sendo fatos sobre a
-- aprovação do CLIENTE, que já aconteceu nesse ponto.

CREATE OR REPLACE FUNCTION public.aprovar_orcamento_cliente_publico(p_orcamento_id uuid, p_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_orcamento public.orcamentos%ROWTYPE;
  v_status_anterior text;
  v_numero_orcamento text;
BEGIN
  SELECT * INTO v_orcamento FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento não encontrado.' USING ERRCODE = 'P0001';
  END IF;

  v_status_anterior := v_orcamento.status;
  v_numero_orcamento := coalesce(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.token_aprovacao_cliente IS NULL OR v_orcamento.token_aprovacao_cliente != p_token THEN
    RAISE EXCEPTION 'Token inválido ou expirado.' USING ERRCODE = 'P0001';
  END IF;

  IF v_orcamento.status != 'enviado_cliente' THEN
    RAISE EXCEPTION 'Orçamento % não está aguardando aprovação do cliente. Status atual: %', v_numero_orcamento, v_status_anterior
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.orcamentos
  SET status = 'Aprovação da Equipe',
      aprovado_cliente_em = now(),
      aprovado_cliente_origem = 'token',
      requer_revisao_financeira = false,
      token_aprovacao_cliente = null
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (p_orcamento_id, v_status_anterior, 'Aprovação da Equipe', null, 'Orçamento aprovado pelo cliente via link público — aguardando decisão da equipe (visita à obra)');

  RETURN jsonb_build_object(
    'orcamento_id', p_orcamento_id,
    'status', 'Aprovação da Equipe',
    'sucesso', true
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.aprovar_orcamento_cliente_manual(p_orcamento_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_orcamento public.orcamentos%ROWTYPE;
  v_status_anterior text;
  v_numero_orcamento text;
  v_user_role text;
  v_prazos integer[];
BEGIN
  SELECT u.role INTO v_user_role FROM public.usuarios u WHERE u.id = auth.uid();
  IF v_user_role IS NULL THEN
    RAISE EXCEPTION 'Usuário não encontrado ou não autenticado.' USING ERRCODE = 'P0001';
  END IF;
  IF v_user_role NOT IN ('admin', 'gerente', 'operador') THEN
    RAISE EXCEPTION 'Permissão negada.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_orcamento FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento não encontrado.' USING ERRCODE = 'P0001';
  END IF;

  v_status_anterior := v_orcamento.status;
  v_numero_orcamento := coalesce(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.status NOT IN ('enviado_cliente', 'recusado_cliente', 'aguardando_cliente', 'rascunho') THEN
    RAISE EXCEPTION 'Orçamento % não pode ser aprovado manualmente no status atual: %', v_numero_orcamento, v_status_anterior
      USING ERRCODE = 'P0001';
  END IF;

  IF v_orcamento.frete_tipo IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui condição de frete definida.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;
  IF v_orcamento.forma_pagamento IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui forma de pagamento estruturada.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;
  IF coalesce(v_orcamento.valor_total, 0) <= 0 THEN
    RAISE EXCEPTION 'Orçamento % possui valor total inválido.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.orcamento_itens oi
    WHERE oi.orcamento_id = p_orcamento_id AND oi.produto_id IS NULL AND coalesce(oi.preco_unitario, 0) <= 0
  ) THEN
    RAISE EXCEPTION 'Orçamento % possui item especial sem preço definido.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;

  v_prazos := public._lucenera_parse_prazo_pagamento(v_orcamento.condicoes_pagamento, v_orcamento.prazo_pagamento_dias);
  IF coalesce(array_length(v_prazos, 1), 0) = 0 THEN
    RAISE EXCEPTION 'Orçamento % não possui prazo de pagamento interpretável.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.orcamentos
  SET status = 'Aprovação da Equipe',
      aprovado_cliente_em = now(),
      aprovado_cliente_origem = 'manual',
      requer_revisao_financeira = false,
      token_aprovacao_cliente = null
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (p_orcamento_id, v_status_anterior, 'Aprovação da Equipe', auth.uid()::text, 'Aprovação manual do cliente pelo administrador — aguardando decisão da equipe (visita à obra)');

  RETURN jsonb_build_object(
    'orcamento_id', p_orcamento_id,
    'status', 'Aprovação da Equipe',
    'sucesso', true
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.aprovar_orcamento_cliente(p_orcamento_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_orcamento public.orcamentos%ROWTYPE;
  v_status_anterior text;
  v_numero_orcamento text;
  v_user_role text;
BEGIN
  SELECT u.role INTO v_user_role
  FROM public.usuarios u
  WHERE u.id = auth.uid();

  IF v_user_role IS NULL THEN
    RAISE EXCEPTION 'Usuário não encontrado ou não autenticado.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_user_role NOT IN ('admin', 'gerente', 'operador') THEN
    RAISE EXCEPTION 'Permissão negada. Apenas admin, gerente ou operador podem aprovar orçamentos do cliente. Role atual: %', v_user_role
      USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_orcamento
  FROM public.orcamentos
  WHERE id = p_orcamento_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento % não encontrado.', p_orcamento_id
      USING ERRCODE = 'P0001';
  END IF;

  v_status_anterior := v_orcamento.status;
  v_numero_orcamento := coalesce(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.status NOT IN ('enviado_cliente', 'recusado_cliente', 'aguardando_cliente', 'rascunho') THEN
    RAISE EXCEPTION 'Orçamento % não pode ser aprovado no status atual: %', v_numero_orcamento, v_status_anterior
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.orcamentos
  SET status = 'Aprovação da Equipe',
      aprovado_cliente_em = now(),
      aprovado_cliente_origem = 'manual',
      requer_revisao_financeira = false,
      token_aprovacao_cliente = null
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (p_orcamento_id, v_status_anterior, 'Aprovação da Equipe', auth.uid()::text, 'Aprovação do cliente finalizada — aguardando decisão da equipe (visita à obra)');

  RETURN jsonb_build_object(
    'orcamento_id', p_orcamento_id,
    'status_anterior', v_status_anterior,
    'status_novo', 'Aprovação da Equipe',
    'sucesso', true
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.adm_aprovar_pelo_cliente(p_orcamento_id uuid, p_observacao text DEFAULT 'Aprovação registrada manualmente pela administração'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_orcamento public.orcamentos%ROWTYPE;
  v_numero text;
BEGIN
  SELECT * INTO v_orcamento
  FROM public.orcamentos
  WHERE id = p_orcamento_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento não encontrado.' USING ERRCODE = 'P0001';
  END IF;

  v_numero := COALESCE(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.status NOT IN ('aguardando_aprovacao', 'enviado_cliente', 'recusado_cliente') THEN
    RAISE EXCEPTION
      'Não é possível registrar aprovação do cliente para orçamento % com status %.',
      v_numero, v_orcamento.status
      USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.orcamentos
  SET status = 'Aprovação da Equipe',
      aprovado_cliente_em = now(),
      requer_revisao_financeira = false,
      token_aprovacao_cliente = NULL
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (
    orcamento_id, status_anterior, status_novo, usuario, observacao
  ) VALUES (
    p_orcamento_id, v_orcamento.status, 'Aprovação da Equipe',
    auth.uid()::text, p_observacao
  );

  RETURN jsonb_build_object(
    'orcamento_id', p_orcamento_id,
    'numero', v_numero,
    'status', 'Aprovação da Equipe',
    'aprovado_em', now(),
    'manual', true
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.cliente_aprovar_orcamento(p_orcamento_id uuid, p_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_orcamento public.orcamentos%ROWTYPE;
  v_numero text;
BEGIN
  SELECT * INTO v_orcamento
  FROM public.orcamentos
  WHERE id = p_orcamento_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento não encontrado.' USING ERRCODE = 'P0001';
  END IF;

  v_numero := COALESCE(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.token_aprovacao_cliente IS NULL
     OR v_orcamento.token_aprovacao_cliente <> p_token THEN
    RAISE EXCEPTION 'Token inválido ou expirado para o orçamento %.',
      v_numero USING ERRCODE = 'P0001';
  END IF;

  IF v_orcamento.status <> 'enviado_cliente' THEN
    RAISE EXCEPTION
      'Orçamento % não está aguardando aprovação do cliente. Status: %.',
      v_numero, v_orcamento.status USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.orcamentos
  SET status = 'Aprovação da Equipe',
      aprovado_cliente_em = now(),
      requer_revisao_financeira = false,
      token_aprovacao_cliente = NULL
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (
    orcamento_id, status_anterior, status_novo, usuario, observacao
  ) VALUES (
    p_orcamento_id, 'enviado_cliente', 'Aprovação da Equipe',
    'cliente', 'Orçamento aprovado pelo cliente via link — aguardando decisão da equipe (visita à obra)'
  );

  RETURN jsonb_build_object(
    'orcamento_id', p_orcamento_id,
    'numero', v_numero,
    'status', 'Aprovação da Equipe',
    'aprovado_em', now()
  );
END;
$function$;
