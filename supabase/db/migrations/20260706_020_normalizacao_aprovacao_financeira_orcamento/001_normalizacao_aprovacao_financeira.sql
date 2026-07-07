-- SPEC-016 - Normalizacao da aprovacao financeira de orcamentos.
-- Contrato oficial: enviado_cliente -> Aprovacao Financeira -> Orcamento Aprovado.
-- A aprovacao financeira passa a ser exclusivamente por orcamento_id.

CREATE OR REPLACE FUNCTION public.normalize_orcamento_status()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.status = 'aprovado_financeiro' THEN
    NEW.status := 'Orçamento Aprovado';
  ELSIF NEW.status = 'aprovado_cliente' THEN
    NEW.status := 'Aprovação Financeira';
    NEW.requer_revisao_financeira := true;
    NEW.aprovado_cliente_em := COALESCE(NEW.aprovado_cliente_em, now());
  END IF;

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.adm_aprovar_pelo_cliente(
  p_orcamento_id uuid,
  p_observacao text DEFAULT 'Aprovação registrada manualmente pela administração'::text
)
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
  SET status = 'Aprovação Financeira',
      aprovado_cliente_em = now(),
      requer_revisao_financeira = true,
      token_aprovacao_cliente = NULL
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (
    orcamento_id, status_anterior, status_novo, usuario, observacao
  ) VALUES (
    p_orcamento_id, v_orcamento.status, 'Aprovação Financeira',
    auth.uid()::text, p_observacao
  );

  RETURN jsonb_build_object(
    'orcamento_id', p_orcamento_id,
    'numero', v_numero,
    'status', 'Aprovação Financeira',
    'aprovado_em', now(),
    'manual', true
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.cliente_aprovar_orcamento(
  p_orcamento_id uuid,
  p_token text
)
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
  SET status = 'Aprovação Financeira',
      aprovado_cliente_em = now(),
      requer_revisao_financeira = true,
      token_aprovacao_cliente = NULL
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (
    orcamento_id, status_anterior, status_novo, usuario, observacao
  ) VALUES (
    p_orcamento_id, 'enviado_cliente', 'Aprovação Financeira',
    'cliente', 'Orçamento aprovado pelo cliente via link'
  );

  RETURN jsonb_build_object(
    'orcamento_id', p_orcamento_id,
    'numero', v_numero,
    'status', 'Aprovação Financeira',
    'aprovado_em', now()
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
  SELECT u.role::text INTO v_user_role
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
  v_numero_orcamento := COALESCE(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.status NOT IN ('enviado_cliente', 'recusado_cliente', 'aguardando_cliente', 'aguardando_aprovacao', 'rascunho') THEN
    RAISE EXCEPTION 'Orçamento % não pode ser aprovado no status atual: %', v_numero_orcamento, v_status_anterior
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.orcamentos
  SET status = 'Aprovação Financeira',
      aprovado_cliente_em = now(),
      requer_revisao_financeira = true,
      token_aprovacao_cliente = NULL
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (
    p_orcamento_id,
    v_status_anterior,
    'Aprovação Financeira',
    auth.uid()::text,
    'Aprovação do cliente finalizada; orçamento enviado para aprovação financeira'
  );

  RETURN jsonb_build_object(
    'orcamento_id', p_orcamento_id,
    'status_anterior', v_status_anterior,
    'status_novo', 'Aprovação Financeira',
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
BEGIN
  SELECT u.role::text INTO v_user_role
  FROM public.usuarios u
  WHERE u.id = auth.uid();

  IF v_user_role IS NULL THEN
    RAISE EXCEPTION 'Usuário não encontrado ou não autenticado.' USING ERRCODE = 'P0001';
  END IF;

  IF v_user_role NOT IN ('admin', 'gerente', 'operador') THEN
    RAISE EXCEPTION 'Permissão negada.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_orcamento
  FROM public.orcamentos
  WHERE id = p_orcamento_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento não encontrado.' USING ERRCODE = 'P0001';
  END IF;

  v_status_anterior := v_orcamento.status;
  v_numero_orcamento := COALESCE(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.status NOT IN ('enviado_cliente', 'recusado_cliente', 'aguardando_cliente', 'aguardando_aprovacao', 'rascunho') THEN
    RAISE EXCEPTION 'Orçamento % não pode ser aprovado manualmente no status atual: %', v_numero_orcamento, v_status_anterior
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.orcamentos
  SET status = 'Aprovação Financeira',
      aprovado_cliente_em = now(),
      requer_revisao_financeira = true,
      token_aprovacao_cliente = NULL
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (
    p_orcamento_id,
    v_status_anterior,
    'Aprovação Financeira',
    auth.uid()::text,
    'Aprovação manual do cliente pelo administrador'
  );

  RETURN jsonb_build_object(
    'orcamento_id', p_orcamento_id,
    'status', 'Aprovação Financeira',
    'sucesso', true
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.aprovar_orcamento_cliente_publico(
  p_orcamento_id uuid,
  p_token text
)
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
  SELECT * INTO v_orcamento
  FROM public.orcamentos
  WHERE id = p_orcamento_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento não encontrado.' USING ERRCODE = 'P0001';
  END IF;

  v_status_anterior := v_orcamento.status;
  v_numero_orcamento := COALESCE(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.token_aprovacao_cliente IS NULL OR v_orcamento.token_aprovacao_cliente <> p_token THEN
    RAISE EXCEPTION 'Token inválido ou expirado.' USING ERRCODE = 'P0001';
  END IF;

  IF v_orcamento.status <> 'enviado_cliente' THEN
    RAISE EXCEPTION 'Orçamento % não está aguardando aprovação do cliente. Status atual: %', v_numero_orcamento, v_status_anterior
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.orcamentos
  SET status = 'Aprovação Financeira',
      aprovado_cliente_em = now(),
      requer_revisao_financeira = true,
      token_aprovacao_cliente = NULL
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (
    p_orcamento_id,
    v_status_anterior,
    'Aprovação Financeira',
    NULL,
    'Orçamento aprovado pelo cliente via link público'
  );

  RETURN jsonb_build_object(
    'orcamento_id', p_orcamento_id,
    'status', 'Aprovação Financeira',
    'sucesso', true
  );
END;
$function$;

CREATE OR REPLACE VIEW public.vw_orcamentos_aprovacao_financeira_auditoria AS
SELECT
  o.id AS orcamento_id,
  o.numero,
  o.status,
  o.projeto_id,
  o.cliente_id,
  o.valor_total,
  o.requer_revisao_financeira,
  o.aprovado_cliente_em,
  COUNT(DISTINCT pi.id) AS projeto_itens_por_orcamento,
  COUNT(DISTINCT pp.id) AS parcelas_por_orcamento,
  COUNT(DISTINCT b.id) AS boletos_por_orcamento,
  CASE
    WHEN o.status = 'Aprovação Financeira' THEN 'fila_financeira'
    WHEN o.status = 'Orçamento Aprovado' THEN 'aprovado_final'
    WHEN o.status IN ('aprovado_cliente', 'aprovado', 'aprovado_financeiro') THEN 'legado_revisar'
    ELSE 'fora_fluxo_financeiro'
  END AS classificacao_fluxo
FROM public.orcamentos o
LEFT JOIN public.projeto_itens pi ON pi.orcamento_id = o.id
LEFT JOIN public.projeto_parcelas pp ON pp.orcamento_id = o.id
LEFT JOIN public.boletos b ON b.orcamento_id = o.id
GROUP BY
  o.id,
  o.numero,
  o.status,
  o.projeto_id,
  o.cliente_id,
  o.valor_total,
  o.requer_revisao_financeira,
  o.aprovado_cliente_em;

CREATE OR REPLACE FUNCTION public.aprovar_orcamento_financeiro(p_orcamento_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_orcamento public.orcamentos%ROWTYPE;
  v_cliente_nome text;
  v_status_anterior text;
  v_prazos integer[];
  v_qtd_parcelas integer;
  v_i integer;
  v_valor_total numeric;
  v_valor_base numeric;
  v_valor_parcela numeric;
  v_valor_acumulado numeric := 0;
  v_data_base date := current_date;
  v_itens_existentes integer := 0;
  v_parcelas_existentes integer := 0;
  v_boletos_existentes integer := 0;
  v_itens_criados integer := 0;
  v_parcelas_criadas integer := 0;
  v_boletos_criados integer := 0;
  v_numero_orcamento text;
  v_user_role text;
  v_reservas_aplicadas integer := 0;
BEGIN
  IF COALESCE(auth.role(), '') <> 'service_role' THEN
    SELECT u.role::text INTO v_user_role
    FROM public.usuarios u
    WHERE u.id = auth.uid()
      AND COALESCE(u.ativo, true) = true;

    IF v_user_role IS NULL THEN
      RAISE EXCEPTION 'Usuário não autenticado ou sem cadastro operacional.'
        USING ERRCODE = 'P0001';
    END IF;

    IF v_user_role NOT IN ('admin', 'gerente') THEN
      RAISE EXCEPTION 'Permissão negada. Apenas admin ou gerente podem aprovar financeiramente. Role atual: %', v_user_role
        USING ERRCODE = 'P0001';
    END IF;
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
  v_numero_orcamento := COALESCE(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.status <> 'Aprovação Financeira' THEN
    RAISE EXCEPTION 'Orçamento % não pode ter aprovação financeira no status atual: %. Status exigido: Aprovação Financeira.',
      v_numero_orcamento, v_status_anterior
      USING ERRCODE = 'P0002';
  END IF;

  IF v_orcamento.projeto_id IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui projeto vinculado.', v_numero_orcamento
      USING ERRCODE = 'P0001';
  END IF;

  IF v_orcamento.empresa_id IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui empresa vinculada.', v_numero_orcamento
      USING ERRCODE = 'P0001';
  END IF;

  IF v_orcamento.cliente_id IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui cliente vinculado.', v_numero_orcamento
      USING ERRCODE = 'P0001';
  END IF;

  IF COALESCE(v_orcamento.valor_total, 0) <= 0 THEN
    RAISE EXCEPTION 'Orçamento % possui valor total inválido.', v_numero_orcamento
      USING ERRCODE = 'P0001';
  END IF;

  IF v_orcamento.forma_pagamento IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui forma de pagamento estruturada.', v_numero_orcamento
      USING ERRCODE = 'P0001';
  END IF;

  IF v_orcamento.frete_tipo IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui frete estruturado. Edite o orçamento e informe "Com Frete" ou "Sem Frete".',
      v_numero_orcamento
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.orcamento_itens oi
    WHERE oi.orcamento_id = p_orcamento_id
  ) THEN
    RAISE EXCEPTION 'Orçamento % não possui itens.', v_numero_orcamento
      USING ERRCODE = 'P0001';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.orcamento_itens oi
    WHERE oi.orcamento_id = p_orcamento_id
      AND (COALESCE(oi.quantidade, 0) <= 0 OR COALESCE(oi.preco_unitario, 0) <= 0)
  ) THEN
    RAISE EXCEPTION 'Orçamento % possui item sem quantidade ou preço válido.', v_numero_orcamento
      USING ERRCODE = 'P0001';
  END IF;

  v_prazos := public._lucenera_parse_prazo_pagamento(
    v_orcamento.condicoes_pagamento,
    v_orcamento.prazo_pagamento_dias
  );
  v_qtd_parcelas := COALESCE(array_length(v_prazos, 1), 0);

  IF v_qtd_parcelas = 0 THEN
    RAISE EXCEPTION 'Orçamento % não possui prazo de pagamento interpretável. Edite o orçamento e informe o "Prazo para Início da Cobrança (dias)".',
      v_numero_orcamento
      USING ERRCODE = 'P0001';
  END IF;

  SELECT COALESCE(nome, nome_empresa, razao_social, 'Cliente')
  INTO v_cliente_nome
  FROM public.contatos
  WHERE id = v_orcamento.cliente_id;

  SELECT COUNT(*) INTO v_itens_existentes
  FROM public.projeto_itens
  WHERE orcamento_id = p_orcamento_id;

  SELECT COUNT(*) INTO v_parcelas_existentes
  FROM public.projeto_parcelas
  WHERE orcamento_id = p_orcamento_id;

  SELECT COUNT(*) INTO v_boletos_existentes
  FROM public.boletos
  WHERE orcamento_id = p_orcamento_id;

  IF v_itens_existentes > 0 OR v_parcelas_existentes > 0 OR v_boletos_existentes > 0 THEN
    IF v_itens_existentes > 0
       AND v_parcelas_existentes = v_qtd_parcelas
       AND v_boletos_existentes = v_qtd_parcelas THEN
      UPDATE public.orcamentos
      SET status = 'Orçamento Aprovado',
          requer_revisao_financeira = false,
          token_aprovacao_cliente = NULL
      WHERE id = p_orcamento_id;

      INSERT INTO public.historico_status_orcamentos (
        orcamento_id, status_anterior, status_novo, usuario, observacao
      ) VALUES (
        p_orcamento_id,
        v_status_anterior,
        'Orçamento Aprovado',
        auth.uid()::text,
        'Aprovação financeira confirmada; artefatos já existiam por orcamento_id'
      );

      RETURN jsonb_build_object(
        'orcamento_id', p_orcamento_id,
        'status', 'Orçamento Aprovado',
        'projeto_id', v_orcamento.projeto_id,
        'projeto_itens_criados', 0,
        'parcelas_criadas', 0,
        'boletos_criados', 0,
        'reservas_estoque_aplicadas', 0,
        'nota_fiscal_status', 'pendente_api',
        'ja_processado', true
      );
    END IF;

    RAISE EXCEPTION
      'Orçamento % possui processamento parcial inconsistente: itens %, parcelas %, boletos %.',
      v_numero_orcamento,
      v_itens_existentes,
      v_parcelas_existentes,
      v_boletos_existentes
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.projeto_itens (
    projeto_id,
    produto_id,
    descricao,
    quantidade,
    preco_unitario,
    desconto,
    validado,
    orcamento_id
  )
  SELECT
    v_orcamento.projeto_id,
    oi.produto_id,
    COALESCE(oi.descricao, p.nome, 'Item sem descrição'),
    COALESCE(oi.quantidade, 1),
    COALESCE(oi.preco_unitario, 0),
    COALESCE(oi.desconto, 0),
    true,
    p_orcamento_id
  FROM public.orcamento_itens oi
  LEFT JOIN public.produtos p ON p.id = oi.produto_id
  WHERE oi.orcamento_id = p_orcamento_id;
  GET DIAGNOSTICS v_itens_criados = ROW_COUNT;

  v_valor_total := v_orcamento.valor_total;
  v_valor_base := round(v_valor_total / v_qtd_parcelas, 2);
  v_valor_acumulado := 0;

  IF v_orcamento.data_base_vencimento = 'emissao' THEN
    v_data_base := COALESCE(v_orcamento.data_emissao, current_date)::date;
  ELSE
    v_data_base := current_date;
  END IF;

  FOR v_i IN 1..v_qtd_parcelas LOOP
    v_valor_parcela := CASE
      WHEN v_i < v_qtd_parcelas THEN v_valor_base
      ELSE v_valor_total - v_valor_acumulado
    END;

    INSERT INTO public.projeto_parcelas (
      projeto_id,
      orcamento_id,
      numero_parcela,
      valor,
      data_vencimento,
      status,
      forma_pagamento,
      descricao
    ) VALUES (
      v_orcamento.projeto_id,
      p_orcamento_id,
      v_i,
      v_valor_parcela,
      v_data_base + v_prazos[v_i],
      'pendente'::public.parcela_status,
      v_orcamento.forma_pagamento,
      'Parcela ' || v_i || '/' || v_qtd_parcelas || ' - ' || COALESCE(v_numero_orcamento, 'Orçamento')
    );

    v_valor_acumulado := v_valor_acumulado + v_valor_parcela;
    v_parcelas_criadas := v_parcelas_criadas + 1;
  END LOOP;

  INSERT INTO public.boletos (
    orcamento_id,
    empresa_id,
    parcela_id,
    valor,
    vencimento,
    nome_pagador,
    numero_documento,
    status,
    tipo,
    nosso_numero,
    num_parcela,
    total_parcelas
  )
  SELECT
    p_orcamento_id,
    v_orcamento.empresa_id,
    pp.id,
    pp.valor,
    pp.data_vencimento,
    v_cliente_nome,
    v_numero_orcamento || '-P' || pp.numero_parcela,
    'pendente_registro',
    'Nota Fiscal',
    v_numero_orcamento || '-P' || pp.numero_parcela,
    pp.numero_parcela,
    v_qtd_parcelas
  FROM public.projeto_parcelas pp
  WHERE pp.orcamento_id = p_orcamento_id;
  GET DIAGNOSTICS v_boletos_criados = ROW_COUNT;

  INSERT INTO public.estoque_itens (
    produto_id,
    local,
    quantidade,
    quantidade_reservada,
    atualizado_em
  )
  SELECT
    oi.produto_id,
    'Estoque'::public.estoque_local,
    0,
    SUM(COALESCE(oi.quantidade, 0)),
    now()
  FROM public.orcamento_itens oi
  WHERE oi.orcamento_id = p_orcamento_id
    AND oi.produto_id IS NOT NULL
    AND COALESCE(oi.quantidade, 0) > 0
  GROUP BY oi.produto_id
  ON CONFLICT (produto_id, local) DO UPDATE
    SET quantidade_reservada = public.estoque_itens.quantidade_reservada + EXCLUDED.quantidade_reservada,
        atualizado_em = now();
  GET DIAGNOSTICS v_reservas_aplicadas = ROW_COUNT;

  UPDATE public.orcamentos
  SET status = 'Orçamento Aprovado',
      requer_revisao_financeira = false,
      token_aprovacao_cliente = NULL
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (
    orcamento_id,
    status_anterior,
    status_novo,
    usuario,
    observacao
  ) VALUES (
    p_orcamento_id,
    v_status_anterior,
    'Orçamento Aprovado',
    auth.uid()::text,
    'Aprovação financeira por orcamento_id'
  );

  RETURN jsonb_build_object(
    'orcamento_id', p_orcamento_id,
    'status', 'Orçamento Aprovado',
    'projeto_id', v_orcamento.projeto_id,
    'projeto_itens_criados', v_itens_criados,
    'parcelas_criadas', v_parcelas_criadas,
    'boletos_criados', v_boletos_criados,
    'reservas_estoque_aplicadas', v_reservas_aplicadas,
    'nota_fiscal_status', 'pendente_api',
    'ja_processado', false
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.aprovar_orcamento_financeiro_base_spec001(p_orcamento_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  RETURN public.aprovar_orcamento_financeiro(p_orcamento_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.aprovar_projeto_financeiro(p_project_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  RAISE EXCEPTION 'aprovar_projeto_financeiro foi descontinuada. Use aprovar_orcamento_financeiro(p_orcamento_id) para aprovar apenas um orçamento.'
    USING ERRCODE = 'P0002';
END;
$function$;

CREATE OR REPLACE FUNCTION public.finalizar_validacao_financeira(
  p_project_id uuid,
  p_project_data jsonb,
  p_orcamentos jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  RAISE EXCEPTION 'finalizar_validacao_financeira foi descontinuada. Edite o orçamento e depois chame aprovar_orcamento_financeiro(p_orcamento_id).'
    USING ERRCODE = 'P0002';
END;
$function$;

CREATE OR REPLACE FUNCTION public.cancelar_orcamento(
  p_orcamento_id uuid,
  p_motivo text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_orcamento public.orcamentos%ROWTYPE;
  v_status_anterior text;
  v_numero_orcamento text;
  v_reservas_revertidas integer := 0;
  v_parcelas_canceladas integer := 0;
  v_boletos_cancelados integer := 0;
  v_itens_invalidados integer := 0;
BEGIN
  SELECT * INTO v_orcamento
  FROM public.orcamentos
  WHERE id = p_orcamento_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento % não encontrado.', p_orcamento_id
      USING ERRCODE = 'P0001';
  END IF;

  v_status_anterior := v_orcamento.status;
  v_numero_orcamento := COALESCE(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_status_anterior = 'cancelado' THEN
    RETURN jsonb_build_object(
      'orcamento_id', p_orcamento_id,
      'numero', v_numero_orcamento,
      'status', 'cancelado',
      'ja_cancelado', true,
      'reservas_revertidas', 0,
      'parcelas_canceladas', 0,
      'boletos_cancelados', 0,
      'itens_invalidados', 0
    );
  END IF;

  IF v_status_anterior IN ('aprovado', 'aprovado_financeiro', 'Orçamento Aprovado') THEN
    UPDATE public.estoque_itens ei
    SET quantidade_reservada = GREATEST(0, ei.quantidade_reservada - oi.quantidade),
        atualizado_em = now()
    FROM (
      SELECT produto_id, SUM(COALESCE(quantidade, 0)) AS quantidade
      FROM public.orcamento_itens
      WHERE orcamento_id = p_orcamento_id
        AND produto_id IS NOT NULL
        AND COALESCE(quantidade, 0) > 0
      GROUP BY produto_id
    ) oi
    WHERE ei.produto_id = oi.produto_id
      AND ei.local = 'Estoque'::public.estoque_local;
    GET DIAGNOSTICS v_reservas_revertidas = ROW_COUNT;

    UPDATE public.projeto_parcelas
    SET status = 'cancelada'::public.parcela_status
    WHERE orcamento_id = p_orcamento_id
      AND status = 'pendente'::public.parcela_status;
    GET DIAGNOSTICS v_parcelas_canceladas = ROW_COUNT;

    UPDATE public.boletos
    SET status = 'cancelado'
    WHERE orcamento_id = p_orcamento_id
      AND status IN ('pendente_registro', 'Pendente', 'pendente');
    GET DIAGNOSTICS v_boletos_cancelados = ROW_COUNT;

    UPDATE public.projeto_itens
    SET validado = false
    WHERE orcamento_id = p_orcamento_id
      AND validado = true;
    GET DIAGNOSTICS v_itens_invalidados = ROW_COUNT;
  END IF;

  UPDATE public.orcamentos
  SET status = 'cancelado',
      requer_revisao_financeira = false,
      token_aprovacao_cliente = NULL
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (
    orcamento_id, status_anterior, status_novo, usuario, observacao
  ) VALUES (
    p_orcamento_id,
    v_status_anterior,
    'cancelado',
    auth.uid()::text,
    COALESCE(p_motivo, 'Cancelamento via RPC cancelar_orcamento')
  );

  RETURN jsonb_build_object(
    'orcamento_id', p_orcamento_id,
    'numero', v_numero_orcamento,
    'status', 'cancelado',
    'status_anterior', v_status_anterior,
    'reservas_revertidas', v_reservas_revertidas,
    'parcelas_canceladas', v_parcelas_canceladas,
    'boletos_cancelados', v_boletos_cancelados,
    'itens_invalidados', v_itens_invalidados,
    'ja_cancelado', false
  );
END;
$function$;

INSERT INTO public.historico_status_orcamentos (
  orcamento_id,
  status_anterior,
  status_novo,
  usuario,
  observacao
)
SELECT
  o.id,
  o.status,
  'Orçamento Aprovado',
  'migration:20260706_020',
  'Normalização de status legado aprovado_financeiro'
FROM public.orcamentos o
WHERE o.status = 'aprovado_financeiro';

UPDATE public.orcamentos
SET status = 'Orçamento Aprovado',
    requer_revisao_financeira = false,
    token_aprovacao_cliente = NULL
WHERE status = 'aprovado_financeiro';

INSERT INTO public.historico_status_orcamentos (
  orcamento_id,
  status_anterior,
  status_novo,
  usuario,
  observacao
)
SELECT
  o.id,
  o.status,
  'Aprovação Financeira',
  'migration:20260706_020',
  'Normalização de status legado aprovado_cliente sem artefatos financeiros'
FROM public.orcamentos o
WHERE o.status = 'aprovado_cliente'
  AND NOT EXISTS (SELECT 1 FROM public.projeto_itens pi WHERE pi.orcamento_id = o.id)
  AND NOT EXISTS (SELECT 1 FROM public.projeto_parcelas pp WHERE pp.orcamento_id = o.id)
  AND NOT EXISTS (SELECT 1 FROM public.boletos b WHERE b.orcamento_id = o.id);

UPDATE public.orcamentos o
SET status = 'Aprovação Financeira',
    requer_revisao_financeira = true,
    aprovado_cliente_em = COALESCE(o.aprovado_cliente_em, now())
WHERE o.status = 'aprovado_cliente'
  AND NOT EXISTS (SELECT 1 FROM public.projeto_itens pi WHERE pi.orcamento_id = o.id)
  AND NOT EXISTS (SELECT 1 FROM public.projeto_parcelas pp WHERE pp.orcamento_id = o.id)
  AND NOT EXISTS (SELECT 1 FROM public.boletos b WHERE b.orcamento_id = o.id);

COMMENT ON FUNCTION public.aprovar_orcamento_financeiro(uuid) IS
'SPEC-016: aprovacao financeira transacional por orcamento_id. Aceita apenas status Aprovação Financeira e finaliza em Orçamento Aprovado.';

COMMENT ON FUNCTION public.aprovar_orcamento_financeiro_base_spec001(uuid) IS
'Wrapper legado da SPEC-001. O contrato oficial esta em aprovar_orcamento_financeiro(uuid).';

COMMENT ON FUNCTION public.aprovar_projeto_financeiro(uuid) IS
'Descontinuada pela SPEC-016 para evitar aprovacao financeira por project_id.';

COMMENT ON FUNCTION public.finalizar_validacao_financeira(uuid, jsonb, jsonb) IS
'Descontinuada pela SPEC-016: edicao financeira nao aprova projeto/orcamentos em lote.';

COMMENT ON FUNCTION public.cancelar_orcamento(uuid, text) IS
'Cancela orçamento e reverte efeitos de status finais legado/aprovado e Orçamento Aprovado.';

COMMENT ON VIEW public.vw_orcamentos_aprovacao_financeira_auditoria IS
'Auditoria da SPEC-016 para classificar orcamentos por status e artefatos financeiros gerados por orcamento_id.';
