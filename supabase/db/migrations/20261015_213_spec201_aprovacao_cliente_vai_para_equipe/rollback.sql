-- SPEC-201 A: volta às definições de 15/10 (cliente aprovado → Aprovação Financeira)
begin;

-- Só funciona se nenhum orçamento estiver em 'Aprovação da Equipe' (mover antes).
ALTER TABLE public.orcamentos DROP CONSTRAINT orcamentos_status_check;
ALTER TABLE public.orcamentos ADD CONSTRAINT orcamentos_status_check
  CHECK (status = ANY (ARRAY[
    'rascunho'::text, 'aguardando_aprovacao'::text, 'enviado_cliente'::text, 'recusado_cliente'::text,
    'expirado'::text, 'cancelado'::text, 'Aprovação Financeira'::text, 'Orçamento Aprovado'::text,
    'aprovado_cliente'::text, 'aprovado'::text, 'aprovado_financeiro'::text,
    'pendente_aprovacao_financeira'::text
  ]));

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

  IF NOT (
    v_user_role IN ('admin', 'gerente', 'operador')
    OR public.hub_pode_executar(auth.uid(), 'orcamentos', 'aprovacao_cliente', 'editar')
  ) THEN
    RAISE EXCEPTION 'Permissão negada. Peça ao administrador o acesso "Aprovação do Cliente" no Hub. Role atual: %', v_user_role
      USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_orcamento
  FROM public.orcamentos
  WHERE id = p_orcamento_id
  FOR UPDATE;

  IF NOT FOUND OR NOT public.orcamento_da_minha_equipe(v_orcamento.equipe_id, v_orcamento.digitado_por) THEN
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
  SET status = 'Aprovação Financeira',
      aprovado_cliente_em = now(),
      aprovado_cliente_origem = 'manual',
      requer_revisao_financeira = true,
      token_aprovacao_cliente = null
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (p_orcamento_id, v_status_anterior, 'Aprovação Financeira', auth.uid()::text, 'Aprovação do cliente finalizada — aguardando aprovação financeira');

  RETURN jsonb_build_object(
    'orcamento_id', p_orcamento_id,
    'status_anterior', v_status_anterior,
    'status_novo', 'Aprovação Financeira',
    'sucesso', true
  );
END;
$function$
;

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
  IF NOT (
    v_user_role IN ('admin', 'gerente', 'operador')
    OR public.hub_pode_executar(auth.uid(), 'orcamentos', 'aprovacao_cliente', 'editar')
  ) THEN
    RAISE EXCEPTION 'Permissão negada. Peça ao administrador o acesso "Aprovação do Cliente" no Hub.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_orcamento FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND OR NOT public.orcamento_da_minha_equipe(v_orcamento.equipe_id, v_orcamento.digitado_por) THEN
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
  SET status = 'Aprovação Financeira',
      aprovado_cliente_em = now(),
      aprovado_cliente_origem = 'manual',
      requer_revisao_financeira = true,
      token_aprovacao_cliente = null
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (p_orcamento_id, v_status_anterior, 'Aprovação Financeira', auth.uid()::text, 'Aprovação manual do cliente — aguardando aprovação financeira');

  RETURN jsonb_build_object(
    'orcamento_id', p_orcamento_id,
    'status', 'Aprovação Financeira',
    'sucesso', true
  );
END;
$function$
;

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
  SET status = 'Aprovação Financeira',
      aprovado_cliente_em = now(),
      aprovado_cliente_origem = 'token',
      requer_revisao_financeira = true,
      token_aprovacao_cliente = null
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (p_orcamento_id, v_status_anterior, 'Aprovação Financeira', null, 'Orçamento aprovado pelo cliente via link público — aguardando aprovação financeira');

  RETURN jsonb_build_object(
    'orcamento_id', p_orcamento_id,
    'status', 'Aprovação Financeira',
    'sucesso', true
  );
END;
$function$
;

commit;
