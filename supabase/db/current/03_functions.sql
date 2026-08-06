-- Function: _lucenera_parse_prazo_pagamento
CREATE OR REPLACE FUNCTION public._lucenera_parse_prazo_pagamento(p_condicoes_pagamento text, p_prazo_pagamento_dias integer[])
 RETURNS integer[]
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  v_text text := lower(coalesce(p_condicoes_pagamento, ''));
  v_nums integer[];
  v_count integer;
  v_interval integer;
  v_len integer;
BEGIN
  IF p_prazo_pagamento_dias IS NOT NULL
     AND array_length(p_prazo_pagamento_dias, 1) > 0 THEN
    RETURN p_prazo_pagamento_dias;
  END IF;

  SELECT array_agg((matches.match)[1]::integer)
    INTO v_nums
  FROM regexp_matches(v_text, '([0-9]+)', 'g') AS matches(match);

  v_len := coalesce(array_length(v_nums, 1), 0);

  IF v_len = 0 THEN
    RETURN ARRAY[]::integer[];
  END IF;

  IF v_text ~ '^\s*[0-9]+\s*x\s*[0-9]+'
     AND v_len = 2
     AND v_nums[1] > 1
     AND v_nums[2] > 0 THEN
    v_count := v_nums[1];
    v_interval := v_nums[2];

    SELECT array_agg(i * v_interval ORDER BY i)
      INTO v_nums
    FROM generate_series(1, v_count) AS i;

    RETURN v_nums;
  END IF;

  IF v_text ~ '^\s*[0-9]+\s*x' THEN
    v_count := v_nums[1];

    IF v_len - 1 = v_count THEN
      RETURN v_nums[2:v_len];
    END IF;

    IF v_len > 1 THEN
      RETURN v_nums[2:v_len];
    END IF;

    RETURN ARRAY[]::integer[];
  END IF;

  IF v_len = 1 AND v_text ~ '[0-9]+\s*parcel' THEN
    RETURN ARRAY[]::integer[];
  END IF;

  RETURN v_nums;
END;
$function$

;
-- Function: adm_aprovar_pelo_cliente
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
$function$

;
-- Function: admin_update_user_password
CREATE OR REPLACE FUNCTION public.admin_update_user_password(p_user_id uuid, p_new_password text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_caller_role public.usuario_role;
BEGIN
  SELECT role INTO v_caller_role FROM public.usuarios WHERE id = auth.uid();
  
  IF v_caller_role != 'admin' THEN
    RAISE EXCEPTION 'Apenas administradores podem alterar senhas.';
  END IF;

  UPDATE auth.users 
  SET encrypted_password = extensions.crypt(p_new_password, extensions.gen_salt('bf'::text)),
      updated_at = NOW() 
  WHERE id = p_user_id;
END;
$function$

;
-- Function: admin_update_user_role
CREATE OR REPLACE FUNCTION public.admin_update_user_role(p_user_id uuid, p_role text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_caller_role public.usuario_role;
BEGIN
  SELECT role INTO v_caller_role FROM public.usuarios WHERE id = auth.uid();
  
  IF v_caller_role != 'admin' THEN
    RAISE EXCEPTION 'Apenas administradores podem alterar perfis.';
  END IF;

  UPDATE public.usuarios 
  SET role = p_role::public.usuario_role, 
      updated_at = NOW() 
  WHERE id = p_user_id;
END;
$function$

;
-- Function: admin_update_user_status
CREATE OR REPLACE FUNCTION public.admin_update_user_status(p_user_id uuid, p_ativo boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_caller_role public.usuario_role;
BEGIN
  SELECT role INTO v_caller_role FROM public.usuarios WHERE id = auth.uid();
  
  IF v_caller_role != 'admin' THEN
    RAISE EXCEPTION 'Apenas administradores podem alterar status.';
  END IF;

  UPDATE public.usuarios 
  SET ativo = p_ativo, 
      updated_at = NOW() 
  WHERE id = p_user_id;
END;
$function$

;
-- Function: aprovar_orcamento_cliente
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
$function$

;
-- Function: aprovar_orcamento_cliente_manual
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
$function$

;
-- Function: aprovar_orcamento_cliente_publico
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
$function$

;
-- Function: aprovar_orcamento_financeiro
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
$function$

;
-- Function: aprovar_orcamento_financeiro_base_spec001
CREATE OR REPLACE FUNCTION public.aprovar_orcamento_financeiro_base_spec001(p_orcamento_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_orcamento        public.orcamentos%ROWTYPE;
  v_cliente_nome     text;
  v_status_anterior  text;
  v_prazos           integer[];
  v_qtd_parcelas     integer;
  v_i                integer;
  v_valor_total      numeric;
  v_valor_base       numeric;
  v_valor_parcela    numeric;
  v_valor_acumulado  numeric  := 0;
  v_data_base        date     := current_date;
  v_itens_existentes    integer := 0;
  v_parcelas_existentes integer := 0;
  v_boletos_existentes  integer := 0;
  v_itens_criados    integer := 0;
  v_parcelas_criadas integer := 0;
  v_boletos_criados  integer := 0;
  v_reservas_criadas integer := 0;
  v_saldos_criados   integer := 0;
  v_numero_orcamento text;
  v_item                     record;
  v_estoque_fisico           numeric(10,2);
  v_estoque_reservado_atual  numeric(10,2);
  v_disponivel_fisico        numeric(10,3);
  v_q_reserva                numeric(10,3);
  v_q_entrega_futura         numeric(10,3);
BEGIN
  -- 1. Carregar e travar o orçamento
  SELECT *
    INTO v_orcamento
  FROM public.orcamentos
  WHERE id = p_orcamento_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento % não encontrado.', p_orcamento_id
      USING ERRCODE = 'P0001';
  END IF;

  v_status_anterior  := v_orcamento.status;
  v_numero_orcamento := coalesce(v_orcamento.numero, left(p_orcamento_id::text, 8));

  -- 2. Validações obrigatórias
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

  IF coalesce(v_orcamento.valor_total, 0) <= 0 THEN
    RAISE EXCEPTION 'Orçamento % possui valor total inválido.', v_numero_orcamento
      USING ERRCODE = 'P0001';
  END IF;

  IF v_orcamento.forma_pagamento IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui forma de pagamento estruturada.', v_numero_orcamento
      USING ERRCODE = 'P0001';
  END IF;

  IF v_orcamento.frete_tipo IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui frete estruturado. Edite o orçamento e informe "Com Frete" ou "Sem Frete".', v_numero_orcamento
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
      AND (
        coalesce(oi.quantidade, 0)     <= 0
        OR coalesce(oi.preco_unitario, 0) <= 0
      )
  ) THEN
    RAISE EXCEPTION 'Orçamento % possui item sem quantidade ou preço válido.', v_numero_orcamento
      USING ERRCODE = 'P0001';
  END IF;

  -- 3. Interpretar prazos de pagamento
  v_prazos       := public._lucenera_parse_prazo_pagamento(
    v_orcamento.condicoes_pagamento,
    v_orcamento.prazo_pagamento_dias
  );
  v_qtd_parcelas := coalesce(array_length(v_prazos, 1), 0);

  IF v_qtd_parcelas = 0 THEN
    RAISE EXCEPTION 'Orçamento % não possui prazo de pagamento interpretável. Edite o orçamento e informe o "Prazo para Início da Cobrança (dias)".', v_numero_orcamento
      USING ERRCODE = 'P0001';
  END IF;

  -- 4. Resolver nome do cliente
  SELECT nome
    INTO v_cliente_nome
  FROM public.contatos
  WHERE id = v_orcamento.cliente_id;

  -- 5. Idempotência: verificar se já foi processado
  SELECT count(*) INTO v_itens_existentes
  FROM public.projeto_itens
  WHERE orcamento_id = p_orcamento_id;

  SELECT count(*) INTO v_parcelas_existentes
  FROM public.projeto_parcelas
  WHERE orcamento_id = p_orcamento_id;

  SELECT count(*) INTO v_boletos_existentes
  FROM public.boletos
  WHERE orcamento_id = p_orcamento_id;

  IF v_itens_existentes > 0
     OR v_parcelas_existentes > 0
     OR v_boletos_existentes  > 0 THEN

    IF v_itens_existentes > 0
       AND v_parcelas_existentes = v_qtd_parcelas
       AND v_boletos_existentes  = v_qtd_parcelas THEN

      UPDATE public.orcamentos
      SET status = 'aprovado'
      WHERE id = p_orcamento_id;

      RETURN jsonb_build_object(
        'orcamento_id',              p_orcamento_id,
        'status',                    'aprovado',
        'projeto_id',                v_orcamento.projeto_id,
        'projeto_itens_criados',     0,
        'parcelas_criadas',          0,
        'boletos_criados',           0,
        'reservas_estoque_aplicadas', 0,
        'saldos_operacionais_criados', 0,
        'nota_fiscal_status',        'pendente_api',
        'ja_processado',             true
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

  -- 6. Marcar como aprovado e registrar histórico
  UPDATE public.orcamentos
  SET status = 'aprovado'
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (
    orcamento_id,
    status_anterior,
    status_novo,
    usuario,
    observacao
  )
  VALUES (
    p_orcamento_id,
    v_status_anterior,
    'aprovado',
    auth.uid()::text,
    'Aprovação integrada por aprovar_orcamento_financeiro'
  );

  -- 7. Criar projeto_itens (snapshot dos itens aprovados) e, para cada item
  --    com produto, reservar estoque físico e criar o saldo operacional
  --    (SPEC-010), item por item, com lock por produto/local.
  --    subtotal é coluna GENERATED ALWAYS — não inserir valor explícito.
  FOR v_item IN
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
      coalesce(oi.descricao, oi.custom_id, p.nome, 'Item do Orçamento'),
      coalesce(oi.quantidade, 0),
      coalesce(oi.preco_unitario, 0),
      coalesce(oi.desconto, 0),
      true,
      p_orcamento_id
    FROM public.orcamento_itens oi
    LEFT JOIN public.produtos p ON p.id = oi.produto_id
    WHERE oi.orcamento_id = p_orcamento_id
    RETURNING id, produto_id, quantidade
  LOOP
    v_itens_criados := v_itens_criados + 1;

    CONTINUE WHEN v_item.produto_id IS NULL OR coalesce(v_item.quantidade, 0) <= 0;

    -- 8. Garantir a linha de estoque_itens do produto e travá-la (FOR UPDATE)
    --    antes de calcular cobertura física disponível. O lock por linha
    --    evita corrida quando o mesmo produto aparece em mais de um item do
    --    mesmo orçamento ou em aprovações concorrentes.
    INSERT INTO public.estoque_itens (produto_id, local, quantidade, quantidade_reservada, atualizado_em)
    VALUES (v_item.produto_id, 'Estoque'::public.estoque_local, 0, 0, NOW())
    ON CONFLICT (produto_id, local) DO NOTHING;

    SELECT quantidade, quantidade_reservada
      INTO v_estoque_fisico, v_estoque_reservado_atual
    FROM public.estoque_itens
    WHERE produto_id = v_item.produto_id
      AND local = 'Estoque'::public.estoque_local
    FOR UPDATE;

    v_disponivel_fisico := GREATEST(0, coalesce(v_estoque_fisico, 0) - coalesce(v_estoque_reservado_atual, 0));
    v_q_reserva          := LEAST(v_item.quantidade, v_disponivel_fisico);
    v_q_entrega_futura   := GREATEST(0, v_item.quantidade - v_q_reserva);

    UPDATE public.estoque_itens
    SET quantidade_reservada = quantidade_reservada + v_item.quantidade,
        atualizado_em        = NOW()
    WHERE produto_id = v_item.produto_id
      AND local = 'Estoque'::public.estoque_local;

    v_reservas_criadas := v_reservas_criadas + 1;

    -- 8b. Criar o saldo operacional do item (SPEC-010).
    INSERT INTO public.estoque_saldos_projeto_item (
      projeto_item_id, q_reserva, q_entrega_futura
    )
    VALUES (v_item.id, v_q_reserva, v_q_entrega_futura)
    ON CONFLICT (projeto_item_id) DO NOTHING;

    v_saldos_criados := v_saldos_criados + 1;

    INSERT INTO public.estoque_movimentos_projeto_item (
      projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por
    )
    VALUES (
      v_item.id,
      'aprovacao_orcamento',
      v_item.quantidade,
      'aprovar_orcamento_financeiro',
      p_orcamento_id,
      format('Reserva %s / entrega futura %s na aprovação do orçamento %s',
             v_q_reserva, v_q_entrega_futura, v_numero_orcamento),
      auth.uid()
    );
  END LOOP;

  -- 9. Criar parcelas financeiras (uma por prazo)
  v_valor_total     := coalesce(v_orcamento.valor_total, 0);
  v_valor_base      := round(v_valor_total / v_qtd_parcelas, 2);
  v_valor_acumulado := 0;

  FOR v_i IN 1..v_qtd_parcelas LOOP
    IF v_i = v_qtd_parcelas THEN
      v_valor_parcela := v_valor_total - v_valor_acumulado;
    ELSE
      v_valor_parcela   := v_valor_base;
      v_valor_acumulado := v_valor_acumulado + v_valor_parcela;
    END IF;

    INSERT INTO public.projeto_parcelas (
      projeto_id,
      numero_parcela,
      valor,
      data_fechamento,
      data_vencimento,
      status,
      forma_pagamento,
      orcamento_id,
      descricao
    )
    VALUES (
      v_orcamento.projeto_id,
      v_i,
      v_valor_parcela,
      current_date,
      v_data_base + v_prazos[v_i],
      'pendente',
      v_orcamento.forma_pagamento,
      p_orcamento_id,
      'Parcela gerada pelo orçamento ' || v_numero_orcamento
    );

    v_parcelas_criadas := v_parcelas_criadas + 1;
  END LOOP;

  -- 10. Criar boletos (um por parcela, nosso_numero único por orçamento+parcela)
  INSERT INTO public.boletos (
    nosso_numero,
    numero_documento,
    parcela_id,
    orcamento_id,
    empresa_id,
    valor,
    vencimento,
    nome_pagador,
    status,
    tipo,
    venda,
    num_parcela,
    total_parcelas,
    emissao
  )
  SELECT
    'ORC-' || regexp_replace(v_numero_orcamento, '[^a-zA-Z0-9]', '', 'g')
            || '-P' || pp.numero_parcela,
    v_numero_orcamento || '-P' || pp.numero_parcela,
    pp.id,
    p_orcamento_id,
    v_orcamento.empresa_id,
    pp.valor,
    pp.data_vencimento,
    coalesce(v_cliente_nome, 'Cliente do orçamento'),
    'pendente_registro',
    'Nota Fiscal',
    NULL,
    pp.numero_parcela,
    v_qtd_parcelas,
    current_date
  FROM public.projeto_parcelas pp
  WHERE pp.orcamento_id = p_orcamento_id
  ON CONFLICT (nosso_numero) DO NOTHING;

  GET DIAGNOSTICS v_boletos_criados = ROW_COUNT;

  -- 11. Retornar resultado
  RETURN jsonb_build_object(
    'orcamento_id',              p_orcamento_id,
    'status',                    'aprovado',
    'projeto_id',                v_orcamento.projeto_id,
    'projeto_itens_criados',     v_itens_criados,
    'parcelas_criadas',          v_parcelas_criadas,
    'boletos_criados',           v_boletos_criados,
    'reservas_estoque_aplicadas', v_reservas_criadas,
    'saldos_operacionais_criados', v_saldos_criados,
    'nota_fiscal_status',        'pendente_api',
    'ja_processado',             false
  );
END;
$function$

;
-- Function: aprovar_projeto_financeiro
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
$function$

;
-- Function: aprovar_transferencia_estoque
CREATE OR REPLACE FUNCTION public.aprovar_transferencia_estoque(p_transferencia_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_transf     public.transferencias_estoque%ROWTYPE;
    v_origem     public.estoque_saldos_projeto_item%ROWTYPE;
    v_destino    public.estoque_saldos_projeto_item%ROWTYPE;
    v_role       public.usuario_role;
    v_reduzir_ef numeric(10,3);
BEGIN
    SELECT role INTO v_role FROM public.usuarios WHERE id = auth.uid();
    IF v_role IS NULL OR v_role NOT IN ('admin', 'gerente') THEN
        RAISE EXCEPTION 'Apenas admin ou gerente pode aprovar transferencia de estoque.' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_transf FROM public.transferencias_estoque WHERE id = p_transferencia_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transferencia % nao encontrada.', p_transferencia_id USING ERRCODE = 'P0001';
    END IF;

    IF v_transf.status <> 'solicitada' THEN
        RAISE EXCEPTION 'Transferencia % nao esta mais solicitada (status atual: %).', p_transferencia_id, v_transf.status USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_origem
    FROM public.estoque_saldos_projeto_item
    WHERE projeto_item_id = v_transf.origem_projeto_item_id
    FOR UPDATE;

    SELECT * INTO v_destino
    FROM public.estoque_saldos_projeto_item
    WHERE projeto_item_id = v_transf.destino_projeto_item_id
    FOR UPDATE;

    IF v_origem.q_reserva < v_transf.quantidade THEN
        RAISE EXCEPTION 'Origem nao tem mais q_reserva suficiente (era % no momento da solicitacao).', v_transf.quantidade USING ERRCODE = 'P0001';
    END IF;

    v_reduzir_ef := LEAST(v_transf.quantidade, v_destino.q_entrega_futura);

    UPDATE public.estoque_saldos_projeto_item
    SET q_reserva = q_reserva - v_transf.quantidade,
        q_entrega_futura = q_entrega_futura + v_transf.quantidade,
        q_transferida_saida = q_transferida_saida + v_transf.quantidade,
        atualizado_em = now()
    WHERE projeto_item_id = v_transf.origem_projeto_item_id;

    UPDATE public.estoque_saldos_projeto_item
    SET q_entrega_futura = q_entrega_futura - v_reduzir_ef,
        q_reserva = q_reserva + v_transf.quantidade,
        atualizado_em = now()
    WHERE projeto_item_id = v_transf.destino_projeto_item_id;

    INSERT INTO public.estoque_movimentos_projeto_item
        (projeto_item_id, projeto_item_destino_id, tipo, quantidade, origem, referencia_id, criado_por)
    VALUES
        (v_transf.origem_projeto_item_id, v_transf.destino_projeto_item_id, 'transferencia_saida', v_transf.quantidade, 'transferencia_estoque', v_transf.id, auth.uid());

    INSERT INTO public.estoque_movimentos_projeto_item
        (projeto_item_id, projeto_item_destino_id, tipo, quantidade, origem, referencia_id, criado_por)
    VALUES
        (v_transf.destino_projeto_item_id, v_transf.origem_projeto_item_id, 'transferencia_entrada', v_transf.quantidade, 'transferencia_estoque', v_transf.id, auth.uid());

    UPDATE public.transferencias_estoque
    SET status = 'aprovada', aprovado_por = auth.uid(), aprovado_em = now()
    WHERE id = p_transferencia_id;

    RETURN jsonb_build_object('transferencia_id', p_transferencia_id, 'status', 'aprovada');
END;
$function$

;
-- Function: can_user_approve_quotes
CREATE OR REPLACE FUNCTION public.can_user_approve_quotes()
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.usuarios
    WHERE id = auth.uid() AND coalesce(can_approve_quotes, false) = true
  );
END;
$function$

;
-- Function: cancelar_orcamento
CREATE OR REPLACE FUNCTION public.cancelar_orcamento(p_orcamento_id uuid, p_motivo text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_orcamento           public.orcamentos%ROWTYPE;
    v_status_anterior     text;
    v_numero_orcamento    text;
    v_reservas_revertidas integer := 0;
    v_parcelas_canceladas integer := 0;
    v_boletos_cancelados  integer := 0;
    v_itens_invalidados   integer := 0;
    v_saldos_cancelados   integer := 0;
BEGIN
    -- 1. Carregar e travar o orçamento
    SELECT * INTO v_orcamento
    FROM public.orcamentos
    WHERE id = p_orcamento_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Orçamento % não encontrado.', p_orcamento_id
            USING ERRCODE = 'P0001';
    END IF;

    v_status_anterior  := v_orcamento.status;
    v_numero_orcamento := coalesce(v_orcamento.numero, left(p_orcamento_id::text, 8));

    -- 2. Idempotência: já cancelado
    IF v_status_anterior = 'cancelado' THEN
        RETURN jsonb_build_object(
            'orcamento_id',          p_orcamento_id,
            'numero',                v_numero_orcamento,
            'status',                'cancelado',
            'reservas_revertidas',   0,
            'parcelas_canceladas',   0,
            'boletos_cancelados',    0,
            'itens_invalidados',     0,
            'saldos_cancelados',     0,
            'ja_cancelado',          true
        );
    END IF;

    -- 3. Se estava aprovado → desfazer todos os efeitos da aprovação
    IF v_status_anterior = 'aprovado' THEN

        -- 3a. Reverter reservas de estoque físico (estoque_itens), pelo saldo
        --     aberto real do item (SPEC-010: q_reserva + q_entrega_futura +
        --     q_ag_separar + q_separado) — não mais pela quantidade original
        --     do orçamento, para não reverter em dobro um item que já tenha
        --     sido parcialmente entregue/transferido antes do cancelamento.
        UPDATE public.estoque_itens ei
        SET quantidade_reservada = GREATEST(0, ei.quantidade_reservada - aberto.qtd_aberta),
            atualizado_em        = NOW()
        FROM (
            SELECT pi.produto_id,
                   SUM(esp.q_reserva + esp.q_entrega_futura + esp.q_ag_separar + esp.q_separado) AS qtd_aberta
            FROM public.projeto_itens pi
            JOIN public.estoque_saldos_projeto_item esp ON esp.projeto_item_id = pi.id
            WHERE pi.orcamento_id = p_orcamento_id
              AND esp.status_operacional = 'ativo'
            GROUP BY pi.produto_id
        ) aberto
        WHERE ei.produto_id = aberto.produto_id
          AND ei.local      = 'Estoque'::public.estoque_local
          AND aberto.qtd_aberta > 0;

        GET DIAGNOSTICS v_reservas_revertidas = ROW_COUNT;

        -- 3b. Cancelar parcelas financeiras
        UPDATE public.projeto_parcelas
        SET status = 'cancelada'::public.parcela_status
        WHERE orcamento_id = p_orcamento_id
          AND status = 'pendente'::public.parcela_status;

        GET DIAGNOSTICS v_parcelas_canceladas = ROW_COUNT;

        -- 3c. Cancelar boletos
        UPDATE public.boletos
        SET status = 'cancelado'
        WHERE orcamento_id = p_orcamento_id
          AND status IN ('pendente_registro', 'Pendente', 'pendente');

        GET DIAGNOSTICS v_boletos_cancelados = ROW_COUNT;

        -- 3d. Invalidar projeto_itens (preservar histórico, apenas desmarca validado)
        UPDATE public.projeto_itens
        SET validado = false
        WHERE orcamento_id = p_orcamento_id
          AND validado = true;

        GET DIAGNOSTICS v_itens_invalidados = ROW_COUNT;

        -- 3e. Encerrar o saldo operacional do item (SPEC-010): zera as
        --     posições abertas, preserva q_entregue/q_devolvida para
        --     auditoria, e registra o movimento de cancelamento com a
        --     quantidade que estava aberta antes de zerar.
        WITH antes AS (
            SELECT esp.projeto_item_id,
                   (esp.q_reserva + esp.q_entrega_futura + esp.q_ag_separar + esp.q_separado) AS qtd_aberta
            FROM public.estoque_saldos_projeto_item esp
            JOIN public.projeto_itens pi ON pi.id = esp.projeto_item_id
            WHERE pi.orcamento_id = p_orcamento_id
              AND esp.status_operacional = 'ativo'
        ),
        cancelados AS (
            UPDATE public.estoque_saldos_projeto_item esp
            SET status_operacional = 'cancelado',
                q_reserva           = 0,
                q_entrega_futura    = 0,
                q_ag_separar        = 0,
                q_separado          = 0
            FROM public.projeto_itens pi
            WHERE pi.id = esp.projeto_item_id
              AND pi.orcamento_id = p_orcamento_id
              AND esp.status_operacional = 'ativo'
            RETURNING esp.projeto_item_id
        )
        INSERT INTO public.estoque_movimentos_projeto_item (
            projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por
        )
        SELECT
            c.projeto_item_id,
            'cancelamento',
            antes.qtd_aberta,
            'cancelar_orcamento',
            p_orcamento_id,
            coalesce(p_motivo, 'Cancelamento do orçamento ' || v_numero_orcamento),
            auth.uid()
        FROM cancelados c
        JOIN antes ON antes.projeto_item_id = c.projeto_item_id
        WHERE antes.qtd_aberta > 0;

        GET DIAGNOSTICS v_saldos_cancelados = ROW_COUNT;

    END IF;

    -- 4. Atualizar status do orçamento
    UPDATE public.orcamentos
    SET status = 'cancelado'
    WHERE id = p_orcamento_id;

    -- 5. Registrar histórico
    INSERT INTO public.historico_status_orcamentos (
        orcamento_id,
        status_anterior,
        status_novo,
        usuario,
        observacao
    ) VALUES (
        p_orcamento_id,
        v_status_anterior,
        'cancelado',
        auth.uid()::text,
        coalesce(p_motivo, 'Cancelamento via RPC cancelar_orcamento')
    );

    RETURN jsonb_build_object(
        'orcamento_id',        p_orcamento_id,
        'numero',              v_numero_orcamento,
        'status',              'cancelado',
        'status_anterior',     v_status_anterior,
        'reservas_revertidas', v_reservas_revertidas,
        'parcelas_canceladas', v_parcelas_canceladas,
        'boletos_cancelados',  v_boletos_cancelados,
        'itens_invalidados',   v_itens_invalidados,
        'saldos_cancelados',   v_saldos_cancelados,
        'ja_cancelado',        false
    );
END;
$function$

;
-- Function: cancelar_transferencia_estoque
CREATE OR REPLACE FUNCTION public.cancelar_transferencia_estoque(p_transferencia_id uuid, p_motivo text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_transf public.transferencias_estoque%ROWTYPE;
BEGIN
    SELECT * INTO v_transf FROM public.transferencias_estoque WHERE id = p_transferencia_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transferencia % nao encontrada.', p_transferencia_id USING ERRCODE = 'P0001';
    END IF;

    IF v_transf.status <> 'solicitada' THEN
        RAISE EXCEPTION 'Só é possível cancelar transferencia com status solicitada (atual: %). Transferencia aprovada exige nova transferencia no sentido contrario.', v_transf.status USING ERRCODE = 'P0001';
    END IF;

    UPDATE public.transferencias_estoque
    SET status = 'cancelada', cancelado_em = now(), motivo_cancelamento = p_motivo
    WHERE id = p_transferencia_id;

    RETURN jsonb_build_object('transferencia_id', p_transferencia_id, 'status', 'cancelada');
END;
$function$

;
-- Function: cliente_aprovar_orcamento
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
$function$

;
-- Function: cliente_recusar_orcamento
CREATE OR REPLACE FUNCTION public.cliente_recusar_orcamento(p_orcamento_id uuid, p_token text, p_motivo text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_orcamento public.orcamentos%ROWTYPE;
    v_numero    text;
BEGIN
    SELECT * INTO v_orcamento
    FROM public.orcamentos
    WHERE id = p_orcamento_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Orçamento não encontrado.' USING ERRCODE = 'P0001';
    END IF;

    v_numero := coalesce(v_orcamento.numero, left(p_orcamento_id::text, 8));

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
    SET status                  = 'recusado_cliente',
        recusado_cliente_em     = now(),
        motivo_recusa_cliente   = p_motivo,
        token_aprovacao_cliente = NULL
    WHERE id = p_orcamento_id;

    INSERT INTO public.historico_status_orcamentos (
        orcamento_id, status_anterior, status_novo, usuario, observacao
    ) VALUES (
        p_orcamento_id, 'enviado_cliente', 'recusado_cliente',
        'cliente', coalesce(p_motivo, 'Orçamento recusado pelo cliente via link')
    );

    RETURN jsonb_build_object(
        'orcamento_id', p_orcamento_id,
        'numero',        v_numero,
        'status',        'recusado_cliente',
        'motivo',        p_motivo,
        'recusado_em',   now()
    );
END;
$function$

;
-- Function: criar_produto_orcamento
CREATE OR REPLACE FUNCTION public.criar_produto_orcamento(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user_role text;
  v_codigo integer;
  v_nome text;
  v_sku text;
  v_marca_id uuid;
  v_categoria_id uuid;
  v_fornecedor_id uuid;
  v_produto public.produtos%ROWTYPE;
BEGIN
  IF p_payload IS NULL THEN
    RAISE EXCEPTION 'Payload do produto é obrigatório.' USING ERRCODE = 'P0001';
  END IF;

  IF COALESCE(auth.role(), '') <> 'service_role' THEN
    SELECT u.role::text INTO v_user_role
    FROM public.usuarios u
    WHERE u.id = auth.uid()
      AND COALESCE(u.ativo, true) = true;

    IF v_user_role IS NULL THEN
      RAISE EXCEPTION 'Usuário não autenticado ou sem cadastro operacional.'
        USING ERRCODE = 'P0001';
    END IF;

    IF v_user_role NOT IN ('admin', 'gerente', 'operador') THEN
      RAISE EXCEPTION 'Permissão negada para criar produto. Role atual: %', v_user_role
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  IF COALESCE(p_payload->>'codigo_produto', '') !~ '^[0-9]+$' THEN
    RAISE EXCEPTION 'Código do produto é obrigatório e deve ser numérico.'
      USING ERRCODE = 'P0001';
  END IF;

  v_codigo := (p_payload->>'codigo_produto')::integer;
  v_nome := NULLIF(btrim(COALESCE(p_payload->>'nome', '')), '');
  v_sku := NULLIF(btrim(COALESCE(p_payload->>'sku', '')), '');
  v_marca_id := NULLIF(p_payload->>'marca_id', '')::uuid;
  v_categoria_id := NULLIF(p_payload->>'categoria_id', '')::uuid;
  v_fornecedor_id := NULLIF(NULLIF(p_payload->>'fornecedor_principal_id', ''), 'none')::uuid;

  IF v_nome IS NULL THEN
    RAISE EXCEPTION 'Nome do produto é obrigatório.' USING ERRCODE = 'P0001';
  END IF;

  IF v_marca_id IS NULL THEN
    RAISE EXCEPTION 'Marca do produto é obrigatória.' USING ERRCODE = 'P0001';
  END IF;

  IF v_categoria_id IS NULL THEN
    RAISE EXCEPTION 'Categoria do produto é obrigatória.' USING ERRCODE = 'P0001';
  END IF;

  IF EXISTS (SELECT 1 FROM public.produtos WHERE codigo_produto = v_codigo) THEN
    RAISE EXCEPTION 'Código do produto % já está em uso.', v_codigo
      USING ERRCODE = '23505';
  END IF;

  IF v_sku IS NOT NULL AND EXISTS (SELECT 1 FROM public.produtos WHERE sku = v_sku) THEN
    RAISE EXCEPTION 'SKU % já está em uso.', v_sku
      USING ERRCODE = '23505';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.marcas WHERE id = v_marca_id) THEN
    RAISE EXCEPTION 'Marca informada não existe.' USING ERRCODE = 'P0001';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.categorias_produto WHERE id = v_categoria_id) THEN
    RAISE EXCEPTION 'Categoria informada não existe.' USING ERRCODE = 'P0001';
  END IF;

  IF v_fornecedor_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.contatos WHERE id = v_fornecedor_id) THEN
    RAISE EXCEPTION 'Fornecedor informado não existe.' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.produtos (
    codigo_produto,
    nome,
    sku,
    referencia,
    marca_id,
    categoria_id,
    fornecedor_principal_id,
    unidade,
    preco_custo,
    preco_venda,
    valor_venda,
    descricao_tecnica,
    ncm,
    tipo_fiscal,
    cst,
    cest,
    porc_frete,
    porc_despesas,
    porc_bdi,
    porc_st,
    porc_desconto,
    icms_entrada,
    ipi_entrada,
    margem_lucro,
    custo_total,
    mascara_produto,
    status_comercial,
    ativo
  ) VALUES (
    v_codigo,
    v_nome,
    v_sku,
    NULLIF(btrim(COALESCE(p_payload->>'referencia', '')), ''),
    v_marca_id,
    v_categoria_id,
    v_fornecedor_id,
    COALESCE(NULLIF(btrim(COALESCE(p_payload->>'unidade', '')), ''), 'UN'),
    COALESCE(NULLIF(p_payload->>'preco_custo', '')::numeric, 0),
    COALESCE(NULLIF(p_payload->>'preco_venda', '')::numeric, 0),
    COALESCE(NULLIF(p_payload->>'valor_venda', '')::numeric, NULLIF(p_payload->>'preco_venda', '')::numeric, 0),
    NULLIF(btrim(COALESCE(p_payload->>'descricao_tecnica', '')), ''),
    NULLIF(btrim(COALESCE(p_payload->>'ncm', '')), ''),
    NULLIF(btrim(COALESCE(p_payload->>'tipo_fiscal', '')), ''),
    NULLIF(btrim(COALESCE(p_payload->>'cst', '')), ''),
    NULLIF(btrim(COALESCE(p_payload->>'cest', '')), ''),
    COALESCE(NULLIF(p_payload->>'porc_frete', '')::numeric, 0),
    COALESCE(NULLIF(p_payload->>'porc_despesas', '')::numeric, 0),
    COALESCE(NULLIF(p_payload->>'porc_bdi', '')::numeric, 0),
    COALESCE(NULLIF(p_payload->>'porc_st', '')::numeric, 0),
    COALESCE(NULLIF(p_payload->>'porc_desconto', '')::numeric, 0),
    COALESCE(NULLIF(p_payload->>'icms_entrada', '')::numeric, 0),
    COALESCE(NULLIF(p_payload->>'ipi_entrada', '')::numeric, 0),
    COALESCE(NULLIF(p_payload->>'margem_lucro', '')::numeric, NULLIF(p_payload->>'percentual_lucro', '')::numeric, 150),
    COALESCE(NULLIF(p_payload->>'custo_total', '')::numeric, 0),
    NULLIF(btrim(COALESCE(p_payload->>'mascara_produto', '')), ''),
    COALESCE(NULLIF(btrim(COALESCE(p_payload->>'status_comercial', '')), ''), 'Normal'),
    true
  )
  RETURNING * INTO v_produto;

  IF COALESCE(v_produto.valor_venda, 0) = 0 AND COALESCE(v_produto.preco_venda, 0) > 0 THEN
    UPDATE public.produtos
    SET valor_venda = v_produto.preco_venda
    WHERE id = v_produto.id
    RETURNING * INTO v_produto;
  END IF;

  RETURN to_jsonb(v_produto) || jsonb_build_object('source', 'produtos');
END;
$function$

;
-- Function: criar_usuario
CREATE OR REPLACE FUNCTION public.criar_usuario(p_email text, p_password text, p_nome text, p_role usuario_role DEFAULT 'viewer'::usuario_role)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_caller_role public.usuario_role;
  v_new_id      UUID;
BEGIN
  SELECT role INTO v_caller_role FROM public.usuarios WHERE id = auth.uid();
  IF v_caller_role != 'admin' THEN
    RAISE EXCEPTION 'Apenas administradores podem criar usuários.';
  END IF;
  IF EXISTS (SELECT 1 FROM auth.users WHERE email = p_email) THEN
    RAISE EXCEPTION 'E-mail % já cadastrado.', p_email;
  END IF;

  v_new_id := gen_random_uuid();
  INSERT INTO auth.users (
    id, instance_id, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
    is_super_admin, role, aud,
    confirmation_token, recovery_token, email_change_token_new,
    email_change, email_change_token_current, phone, phone_change, phone_change_token, reauthentication_token
  ) VALUES (
    v_new_id, '00000000-0000-0000-0000-000000000000', p_email,
    extensions.crypt(p_password, extensions.gen_salt('bf'::text)), NOW(), NOW(), NOW(),
    '{"provider":"email","providers":["email"]}',
    json_build_object('nome', p_nome),
    false, 'authenticated', 'authenticated',
    '', '', '', '', '', NULL, '', '', ''
  );

  INSERT INTO public.usuarios (id, email, nome, role)
  VALUES (v_new_id, p_email, p_nome, p_role)
  ON CONFLICT (id) DO UPDATE SET nome = p_nome, role = p_role;

  RETURN v_new_id;
END;
$function$

;
-- Function: current_user_funcionario_id
CREATE OR REPLACE FUNCTION public.current_user_funcionario_id()
 RETURNS uuid
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT id FROM public.funcionarios
  WHERE usuario_id = auth.uid()
  LIMIT 1;
$function$

;
-- Function: current_user_is_funcionario
CREATE OR REPLACE FUNCTION public.current_user_is_funcionario()
 RETURNS boolean
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.funcionarios
    WHERE usuario_id = auth.uid()
  );
$function$

;
-- Function: enviar_orcamento_para_cliente
-- SPEC-051 (27/07/2026): adicionada validação de completude (empresa,
-- projeto, cliente, forma de pagamento, ao menos 1 item) antes de aceitar o
-- envio — esta RPC passou a ser o único ponto de entrada para
-- enviado_cliente após a remoção da auto-promoção automática.
CREATE OR REPLACE FUNCTION public.enviar_orcamento_para_cliente(p_orcamento_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_orcamento  public.orcamentos%ROWTYPE;
    v_numero     text;
    v_status_ant text;
    v_token      text;
    v_has_items  boolean := false;
    v_faltando   text[] := ARRAY[]::text[];
    v_msg        text;
BEGIN
    SELECT * INTO v_orcamento
    FROM public.orcamentos
    WHERE id = p_orcamento_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Orçamento % não encontrado.', p_orcamento_id
            USING ERRCODE = 'P0001';
    END IF;

    v_numero     := coalesce(v_orcamento.numero, left(p_orcamento_id::text, 8));
    v_status_ant := v_orcamento.status;

    IF v_status_ant NOT IN ('aguardando_aprovacao', 'recusado_cliente', 'rascunho') THEN
        RAISE EXCEPTION
            'Orçamento % não pode ser enviado ao cliente: status atual é %. '
            'Permitido apenas em: aguardando_aprovacao, recusado_cliente.',
            v_numero, v_status_ant
            USING ERRCODE = 'P0002';
    END IF;

    IF v_orcamento.empresa_id IS NULL THEN
        v_faltando := array_append(v_faltando, 'Empresa');
    END IF;
    IF v_orcamento.projeto_id IS NULL THEN
        v_faltando := array_append(v_faltando, 'Projeto');
    END IF;
    IF v_orcamento.cliente_id IS NULL THEN
        v_faltando := array_append(v_faltando, 'Cliente');
    END IF;
    IF v_orcamento.forma_pagamento IS NULL THEN
        v_faltando := array_append(v_faltando, 'Forma de Pagamento');
    END IF;

    SELECT EXISTS(
        SELECT 1 FROM public.orcamento_itens WHERE orcamento_id = p_orcamento_id
    ) INTO v_has_items;

    IF array_length(v_faltando, 1) > 0 OR NOT v_has_items THEN
        v_msg := 'Não é possível enviar ao cliente: ';
        IF array_length(v_faltando, 1) > 0 THEN
            v_msg := v_msg || 'preencha ' || array_to_string(v_faltando, ', ') || '.';
        END IF;
        IF NOT v_has_items THEN
            IF array_length(v_faltando, 1) > 0 THEN
                v_msg := v_msg || ' ';
            END IF;
            v_msg := v_msg || 'Adicione pelo menos um item.';
        END IF;
        RAISE EXCEPTION '%', v_msg
            USING ERRCODE = 'P0003';
    END IF;

    v_token := gen_random_uuid()::text;

    UPDATE public.orcamentos
    SET status                  = 'enviado_cliente',
        enviado_cliente_em      = now(),
        enviado_cliente_por     = auth.uid(),
        token_aprovacao_cliente = v_token,
        recusado_cliente_em     = NULL,
        motivo_recusa_cliente   = NULL
    WHERE id = p_orcamento_id;

    INSERT INTO public.historico_status_orcamentos (
        orcamento_id, status_anterior, status_novo, usuario, observacao
    ) VALUES (
        p_orcamento_id, v_status_ant, 'enviado_cliente',
        auth.uid()::text, 'Orçamento enviado ao cliente para aprovação'
    );

    RETURN jsonb_build_object(
        'orcamento_id', p_orcamento_id,
        'numero',        v_numero,
        'status',        'enviado_cliente',
        'token',         v_token,
        'enviado_em',    now()
    );
END;
$function$

;
-- Function: finalizar_validacao_financeira
CREATE OR REPLACE FUNCTION public.finalizar_validacao_financeira(p_project_id uuid, p_project_data jsonb, p_orcamentos jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RAISE EXCEPTION 'finalizar_validacao_financeira foi descontinuada. Edite o orçamento e depois chame aprovar_orcamento_financeiro(p_orcamento_id).'
    USING ERRCODE = 'P0002';
END;
$function$

;
-- Function: fn_atualiza_updated_at
CREATE OR REPLACE FUNCTION public.fn_atualiza_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$function$

;
-- Function: fn_atualizar_preco_venda
CREATE OR REPLACE FUNCTION public.fn_atualizar_preco_venda()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_valor_liquido    NUMERIC;
    v_valor_st         NUMERIC;
    v_valor_ipi        NUMERIC;
    v_valor_despesas   NUMERIC;
    v_bdi_total        NUMERIC;
    v_custo_total      NUMERIC;
BEGIN
    -- 1. Valor Líquido = preço de custo menos desconto percentual
    v_valor_liquido := NEW.preco_custo - (NEW.preco_custo * (COALESCE(NEW.porc_desconto, 0) / 100));

    -- 2. Valor ST sobre Valor Líquido
    v_valor_st := v_valor_liquido * (COALESCE(NEW.icms_entrada, 0) / 100);

    -- 3. Valor IPI sobre Valor Líquido
    v_valor_ipi := v_valor_liquido * (COALESCE(NEW.ipi_entrada, 0) / 100);

    -- 4. Valor Despesas sobre Valor Líquido (porc_frete é propositalmente ignorado)
    v_valor_despesas := v_valor_liquido * (COALESCE(NEW.porc_despesas, 0) / 100);

    -- 5. BDI Total
    v_bdi_total := v_valor_st + v_valor_ipi + v_valor_despesas;

    -- 6. Custo Total
    v_custo_total := v_valor_liquido + v_bdi_total;

    -- 7. Preço de Venda com margem de 150% (multiplica por 2.5)
    NEW.preco_venda := v_custo_total * 2.5;

    RETURN NEW;
END;
$function$

;
-- Function: fn_auditoria_permissoes
CREATE OR REPLACE FUNCTION public.fn_auditoria_permissoes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO public.auditoria_permissoes (autor_id, entidade, entidade_id, antes, depois)
  VALUES (
    auth.uid(),
    TG_TABLE_NAME,
    CASE WHEN TG_OP = 'DELETE' THEN (to_jsonb(OLD)->>'id')::uuid ELSE (to_jsonb(NEW)->>'id')::uuid END,
    CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) ELSE NULL END,
    CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) ELSE NULL END
  );
  RETURN COALESCE(NEW, OLD);
END;
$function$

;
-- Function: fn_auditoria_usuario_papeis
CREATE OR REPLACE FUNCTION public.fn_auditoria_usuario_papeis()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO public.auditoria_permissoes (autor_id, entidade, entidade_id, antes, depois)
  VALUES (
    auth.uid(),
    'usuario_papeis',
    CASE WHEN TG_OP = 'DELETE' THEN OLD.usuario_id ELSE NEW.usuario_id END,
    CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) ELSE NULL END,
    CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) ELSE NULL END
  );
  RETURN COALESCE(NEW, OLD);
END;
$function$

;
-- Function: fn_auto_numero_orcamento
CREATE OR REPLACE FUNCTION public.fn_auto_numero_orcamento()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF NEW.numero_orcamento IS NULL OR NEW.numero_orcamento = '' THEN
        NEW.numero_orcamento := fn_gerar_numero_orcamento();
    END IF;
    RETURN NEW;
END;
$function$

;
-- Function: fn_gerar_numero_orcamento
CREATE OR REPLACE FUNCTION public.fn_gerar_numero_orcamento()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
    ano_atual TEXT;
    sequencial INTEGER;
    numero TEXT;
BEGIN
    ano_atual := EXTRACT(YEAR FROM CURRENT_DATE)::TEXT;
    
    -- Busca o próximo número sequencial do ano
    SELECT COALESCE(MAX(CAST(SPLIT_PART(numero_orcamento, '-', 3) AS INTEGER)), 0) + 1
    INTO sequencial
    FROM orcamentos_revenda_ubiqua
    WHERE numero_orcamento LIKE 'ORC-' || ano_atual || '-%';
    
    numero := 'ORC-' || ano_atual || '-' || LPAD(sequencial::TEXT, 6, '0');
    
    RETURN numero;
END;
$function$

;
-- Function: fn_log_auditoria
CREATE OR REPLACE FUNCTION public.fn_log_auditoria()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO public.logs_auditoria (tabela, operacao, registro_id, dados_novos)
        VALUES (TG_TABLE_NAME, 'INSERT', NEW.id, to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO public.logs_auditoria (tabela, operacao, registro_id, dados_anteriores, dados_novos)
        VALUES (TG_TABLE_NAME, 'UPDATE', NEW.id, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO public.logs_auditoria (tabela, operacao, registro_id, dados_anteriores)
        VALUES (TG_TABLE_NAME, 'DELETE', OLD.id, to_jsonb(OLD));
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$function$

;
-- Function: fn_sync_equipe_por_responsavel
CREATE OR REPLACE FUNCTION public.fn_sync_equipe_por_responsavel()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
  v_equipe_id uuid;
BEGIN
  IF NEW.responsavel_nome IS NULL THEN
    NEW.equipe_id                  := NULL;
    NEW.equipe_responsavel_obra_id := NULL;
    RETURN NEW;
  END IF;

  SELECT id
    INTO v_equipe_id
  FROM public.equipes_projetos
  WHERE lower(trim(equipes)) = lower(trim(NEW.responsavel_nome))
  LIMIT 1;

  NEW.equipe_id                  := v_equipe_id;
  NEW.equipe_responsavel_obra_id := v_equipe_id;

  RETURN NEW;
END;
$function$

;
-- Function: fn_update_orcamento_timestamp
CREATE OR REPLACE FUNCTION public.fn_update_orcamento_timestamp()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$function$

;
-- Function: fn_validar_saldo_projeto_item
CREATE OR REPLACE FUNCTION public.fn_validar_saldo_projeto_item()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_quantidade_venda numeric(10,2);
  v_soma             numeric(10,3);
BEGIN
  SELECT quantidade INTO v_quantidade_venda
  FROM public.projeto_itens
  WHERE id = NEW.projeto_item_id;

  v_soma := NEW.q_reserva + NEW.q_entrega_futura + NEW.q_ag_separar
          + NEW.q_separado + NEW.q_entregue + NEW.q_devolvida;

  IF v_soma > coalesce(v_quantidade_venda, 0) THEN
    RAISE EXCEPTION
      'Saldo do item de projeto % excede a quantidade vendida (% > %).',
      NEW.projeto_item_id, v_soma, v_quantidade_venda
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$function$

;
-- Function: gen_token_hex
CREATE OR REPLACE FUNCTION public.gen_token_hex()
 RETURNS text
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT md5(gen_random_uuid()::text) || md5(gen_random_uuid()::text);
$function$

;
-- Function: generate_product_slug
CREATE OR REPLACE FUNCTION public.generate_product_slug(nome text, preco numeric)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  base_slug text;
  price_str text;
BEGIN
  -- Use unaccent to remove accents and lower to lowercase
  base_slug := lower(public.unaccent(trim(COALESCE(nome, 'Sem nome'))));
  
  -- Replace non-alphanumeric with dash
  base_slug := regexp_replace(base_slug, '[^a-z0-9]+', '-', 'g');
  
  -- Remove leading and trailing dashes
  base_slug := trim(both '-' from base_slug);
  
  -- Format price (e.g. 199.90 -> 199-90)
  price_str := replace(to_char(COALESCE(preco, 0), 'FM999999990.00'), '.', '-');
  
  RETURN base_slug || '-' || price_str;
END;
$function$

;
-- Function: get_dashboard_crm_by_closing
CREATE OR REPLACE FUNCTION public.get_dashboard_crm_by_closing(data_inicial date, data_final date)
 RETURNS SETOF projetos
 LANGUAGE sql
 STABLE
AS $function$
SELECT * FROM public.projetos p
WHERE EXISTS (
  SELECT 1 FROM public.projeto_parcelas pp
  WHERE pp.projeto_id = p.id
    AND pp.data_fechamento BETWEEN data_inicial AND data_final
);
$function$

;
-- Function: get_dashboard_kpi
CREATE OR REPLACE FUNCTION public.get_dashboard_kpi(p_date_now date)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_total_balance NUMERIC;
  v_month_income NUMERIC;
  v_month_expense NUMERIC;
  v_last_month_income NUMERIC;
  v_last_month_expense NUMERIC;
  v_start_month DATE;
  v_end_month DATE;
  v_start_last_month DATE;
  v_end_last_month DATE;
BEGIN
  v_start_month := date_trunc('month', p_date_now);
  v_end_month := (date_trunc('month', p_date_now) + interval '1 month' - interval '1 day')::date;
  v_start_last_month := date_trunc('month', p_date_now - interval '1 month');
  v_end_last_month := (date_trunc('month', p_date_now) - interval '1 day')::date;

  -- Calculate Total Balance
  SELECT COALESCE(SUM(saldo), 0)
  INTO v_total_balance
  FROM public.contas_bancarias;

  IF v_total_balance = 0 THEN
    SELECT COALESCE(SUM(CASE WHEN tipo = 'receita' THEN valor WHEN tipo = 'despesa' THEN -valor ELSE 0 END), 0)
    INTO v_total_balance
    FROM public.transacoes
    WHERE status_pago = 1 OR dt_pagamento IS NOT NULL;
  END IF;

  -- Calculate Month Income
  SELECT COALESCE(SUM(valor), 0)
  INTO v_month_income
  FROM public.transacoes
  WHERE tipo = 'receita' 
    AND (COALESCE(dt_pagamento, data_transacao) >= v_start_month AND COALESCE(dt_pagamento, data_transacao) <= v_end_month)
    AND (status_pago = 1 OR dt_pagamento IS NOT NULL);

  -- Calculate Month Expense
  SELECT COALESCE(SUM(valor), 0)
  INTO v_month_expense
  FROM public.transacoes
  WHERE tipo = 'despesa' 
    AND (COALESCE(dt_pagamento, data_transacao) >= v_start_month AND COALESCE(dt_pagamento, data_transacao) <= v_end_month)
    AND (status_pago = 1 OR dt_pagamento IS NOT NULL);

  -- Calculate Last Month Income
  SELECT COALESCE(SUM(valor), 0)
  INTO v_last_month_income
  FROM public.transacoes
  WHERE tipo = 'receita' 
    AND (COALESCE(dt_pagamento, data_transacao) >= v_start_last_month AND COALESCE(dt_pagamento, data_transacao) <= v_end_last_month)
    AND (status_pago = 1 OR dt_pagamento IS NOT NULL);

  -- Calculate Last Month Expense
  SELECT COALESCE(SUM(valor), 0)
  INTO v_last_month_expense
  FROM public.transacoes
  WHERE tipo = 'despesa' 
    AND (COALESCE(dt_pagamento, data_transacao) >= v_start_last_month AND COALESCE(dt_pagamento, data_transacao) <= v_end_last_month)
    AND (status_pago = 1 OR dt_pagamento IS NOT NULL);

  RETURN json_build_object(
    'totalBalance', v_total_balance,
    'monthIncome', v_month_income,
    'monthExpense', v_month_expense,
    'lastMonthIncome', v_last_month_income,
    'lastMonthExpense', v_last_month_expense
  );
END;
$function$

;
-- Function: get_dashboard_stats
CREATE OR REPLACE FUNCTION public.get_dashboard_stats()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_active_projects integer;
  v_completed_this_month integer;
  v_total_value numeric;
  v_clients_count integer;
  v_architects_count integer;
  v_engineers_count integer;
BEGIN
  -- Active projects count
  SELECT COUNT(*) INTO v_active_projects
  FROM public.projetos
  WHERE status::text NOT IN ('Finalizado', 'Obra Finalizada', 'Arquivado', 'Não Fechou')
     OR status IS NULL;
  
  -- Completed this month count
  SELECT COUNT(*) INTO v_completed_this_month
  FROM public.projetos
  WHERE status::text IN ('Finalizado', 'Obra Finalizada')
    AND updated_at >= date_trunc('month', CURRENT_DATE);

  -- Total Value: Sum of valor_total from vw_financeiro_projetos
  SELECT COALESCE(SUM(valor_total), 0) INTO v_total_value
  FROM public.vw_financeiro_projetos
  WHERE status::text NOT IN ('Arquivado', 'Não Fechou') OR status IS NULL;

  -- Contatos counts
  SELECT COUNT(*) INTO v_clients_count FROM public.contatos WHERE tipo = 'cliente';
  SELECT COUNT(*) INTO v_architects_count FROM public.contatos WHERE tipo = 'arquiteto';
  SELECT COUNT(*) INTO v_engineers_count FROM public.contatos WHERE tipo = 'engenheiro';

  RETURN json_build_object(
    'activeProjects', COALESCE(v_active_projects, 0),
    'completedThisMonth', COALESCE(v_completed_this_month, 0),
    'totalValue', COALESCE(v_total_value, 0),
    'clientsCount', COALESCE(v_clients_count, 0),
    'architectsCount', COALESCE(v_architects_count, 0),
    'engineersCount', COALESCE(v_engineers_count, 0)
  );
END;
$function$

;
-- Function: get_faltas_injustificadas
CREATE OR REPLACE FUNCTION public.get_faltas_injustificadas(p_funcionario_id uuid, p_inicio date, p_fim date)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
    RETURN (
        SELECT count(*)::integer
        FROM public.controle_falta
        WHERE funcionario_id = p_funcionario_id
          AND data BETWEEN p_inicio AND p_fim
          AND status = 'ausente'
          AND (justificativa IS NULL OR justificativa = '')
    );
END;
$function$

;
-- Function: get_latest_transaction_id
CREATE OR REPLACE FUNCTION public.get_latest_transaction_id()
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- Deterministic sort order matching the service layer
  RETURN (SELECT id FROM public.transactions ORDER BY created_at DESC, id DESC LIMIT 1);
END;
$function$

;
-- Function: get_my_funcionario_id
CREATE OR REPLACE FUNCTION public.get_my_funcionario_id()
 RETURNS uuid
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT id FROM public.funcionarios WHERE usuario_id = auth.uid();
$function$

;
-- Function: get_next_sku
CREATE OR REPLACE FUNCTION public.get_next_sku(prefix text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  highest_num integer := 0;
  next_sku text;
  rec record;
  num_str text;
  parsed_num integer;
BEGIN
  FOR rec IN
    SELECT sku FROM public.produtos WHERE sku LIKE prefix || '%' AND sku IS NOT NULL
  LOOP
    num_str := regexp_replace(substring(rec.sku from length(prefix) + 1), '[^0-9]', '', 'g');
    IF num_str <> '' THEN
      BEGIN
        parsed_num := CAST(num_str AS integer);
        IF parsed_num > highest_num THEN
          highest_num := parsed_num;
        END IF;
      EXCEPTION WHEN OTHERS THEN
        -- Ignore cast errors
      END;
    END IF;
  END LOOP;

  next_sku := prefix || lpad((highest_num + 1)::text, 2, '0');
  
  RETURN next_sku;
END;
$function$

;
-- Function: get_user_role
CREATE OR REPLACE FUNCTION public.get_user_role()
 RETURNS text
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT role::text FROM public.usuarios WHERE id = auth.uid();
$function$

;
-- Function: get_vendedores
CREATE OR REPLACE FUNCTION public.get_vendedores()
 RETURNS TABLE(id uuid, email character varying, name text)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  RETURN QUERY SELECT u.id, u.email, (u.raw_user_meta_data->>'name')::TEXT as name FROM auth.users u;
END;
$function$

;
-- Function: handle_contato_tipo
CREATE OR REPLACE FUNCTION public.handle_contato_tipo()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.tipo IS NOT NULL THEN
    INSERT INTO public.contato_tipos (contato_id, tipo)
    VALUES (NEW.id, NEW.tipo)
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$function$

;
-- Function: handle_new_auth_user
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO public.usuarios (id, email, nome, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'nome', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    'viewer'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$function$

;
-- Function: handle_new_user
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_nome text;
BEGIN
    v_nome := COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1));

    -- Insert into usuarios (permissions table)
    INSERT INTO public.usuarios (id, email, nome, role)
    VALUES (NEW.id, NEW.email, v_nome, 'viewer')
    ON CONFLICT (id) DO NOTHING;

    -- Try to link an existing funcionario by email
    UPDATE public.funcionarios
    SET usuario_id = NEW.id
    WHERE email = NEW.email AND usuario_id IS NULL;

    -- If not linked, create a new funcionario record
    IF NOT EXISTS (SELECT 1 FROM public.funcionarios WHERE usuario_id = NEW.id) THEN
        INSERT INTO public.funcionarios (usuario_id, nome, email, status)
        VALUES (NEW.id, v_nome, NEW.email, 'Ativo');
    END IF;

    RETURN NEW;
END;
$function$

;
-- Function: handle_orcamento_workflow
-- SPEC-051 (27/07/2026): handle_orcamento_item_workflow() foi removida por
-- completo (existia só para promover rascunho -> enviado_cliente sozinha ao
-- inserir o primeiro item). handle_orcamento_workflow() perdeu o bloco
-- final de auto-promoção — a transição rascunho -> enviado_cliente agora só
-- acontece via RPC public.enviar_orcamento_para_cliente(p_orcamento_id).
CREATE OR REPLACE FUNCTION public.handle_orcamento_workflow()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_old_status text;
BEGIN
  v_old_status := COALESCE(OLD.status, '');

  -- Auto-generate token when status is enviado_cliente and no token exists
  IF (NEW.status = 'enviado_cliente' AND NEW.token_aprovacao_cliente IS NULL) THEN
    NEW.token_aprovacao_cliente := public.gen_token_hex();
    IF NEW.enviado_cliente_em IS NULL THEN
      NEW.enviado_cliente_em := now();
    END IF;
    IF NEW.enviado_cliente_por IS NULL THEN
      NEW.enviado_cliente_por := auth.uid();
    END IF;
  END IF;

  -- When customer approves (transition to Aprovação Financeira from enviado_cliente),
  -- set financial review flag and approval timestamp
  IF (NEW.status = 'Aprovação Financeira' AND v_old_status = 'enviado_cliente') THEN
    NEW.requer_revisao_financeira := true;
    IF NEW.aprovado_cliente_em IS NULL THEN
      NEW.aprovado_cliente_em := now();
    END IF;
  END IF;

  RETURN NEW;
END;
$function$

;
-- Function: handle_updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$ BEGIN NEW.updated_at = now(); RETURN NEW; END; $function$

;
-- Function: hub_pode_executar
CREATE OR REPLACE FUNCTION public.hub_pode_executar(p_usuario_id uuid, p_system_slug text, p_modulo_chave text, p_acao text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_excecao text;
BEGIN
  -- 1. Excecao individual tem precedencia. modulo_id NULL na excecao = vale
  -- para o sistema inteiro; caso contrario precisa bater com o modulo pedido.
  SELECT e.tipo INTO v_excecao
  FROM usuario_permissao_excecoes e
  JOIN systems s ON s.id = e.system_id AND s.slug = p_system_slug
  LEFT JOIN modulos m ON m.id = e.modulo_id
  WHERE e.usuario_id = p_usuario_id
    AND e.acao = p_acao
    AND (e.valido_até IS NULL OR e.valido_até > now())
    AND (e.modulo_id IS NULL OR m.chave = p_modulo_chave)
  ORDER BY e.criado_em DESC
  LIMIT 1;

  IF v_excecao = 'negar' THEN RETURN false; END IF;
  IF v_excecao = 'conceder' THEN RETURN true; END IF;

  -- 2. Papel do usuario (sistema inteiro OU modulo especifico; acao NULL = todas)
  RETURN EXISTS (
    SELECT 1
    FROM usuario_papeis up
    JOIN papel_permissoes pp ON pp.papel_id = up.papel_id
    JOIN systems s ON s.id = pp.system_id AND s.slug = p_system_slug
    LEFT JOIN modulos m ON m.id = pp.modulo_id
    WHERE up.usuario_id = p_usuario_id
      AND (pp.acao IS NULL OR pp.acao = p_acao)
      AND (pp.modulo_id IS NULL OR m.chave = p_modulo_chave)
  );
END;
$function$

;
-- Function: hub_sistemas_permitidos
CREATE OR REPLACE FUNCTION public.hub_sistemas_permitidos(p_usuario_id uuid)
 RETURNS SETOF systems
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT DISTINCT s.*
  FROM systems s
  JOIN papel_permissoes pp ON pp.system_id = s.id
  JOIN usuario_papeis up ON up.papel_id = pp.papel_id AND up.usuario_id = p_usuario_id
  WHERE (pp.acao = 'visualizar' OR pp.acao IS NULL)
    AND s.visivel_no_hub = true
$function$

;
-- Function: is_admin
CREATE OR REPLACE FUNCTION public.is_admin()
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_role public.usuario_role;
BEGIN
  SELECT role INTO v_role FROM public.usuarios WHERE id = auth.uid();
  RETURN v_role = 'admin'::public.usuario_role;
END;
$function$

;
-- Function: is_ubiqua_admin
CREATE OR REPLACE FUNCTION public.is_ubiqua_admin()
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.usuarios_ubiqua
    WHERE id = auth.uid() AND nivel_acesso = 'admin'
  );
END;
$function$

;
-- Function: limpar_staging_processados
CREATE OR REPLACE FUNCTION public.limpar_staging_processados()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    total_deletado INTEGER := 0;
BEGIN
    -- Deleta registros processados há mais de 30 dias
    DELETE FROM staging_conta_pagar 
    WHERE processado = TRUE 
    AND importado_em < NOW() - INTERVAL '30 days';
    
    GET DIAGNOSTICS total_deletado = ROW_COUNT;
    
    DELETE FROM staging_conta_receber 
    WHERE processado = TRUE 
    AND importado_em < NOW() - INTERVAL '30 days';
    
    DELETE FROM staging_produtos 
    WHERE processado = TRUE 
    AND importado_em < NOW() - INTERVAL '30 days';
    
    DELETE FROM staging_pedido_compra 
    WHERE processado = TRUE 
    AND importado_em < NOW() - INTERVAL '30 days';
    
    RETURN total_deletado;
END;
$function$

;
-- Function: link_my_funcionario_record
CREATE OR REPLACE FUNCTION public.link_my_funcionario_record()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_user_email text;
    v_func_id uuid;
BEGIN
    -- Identify the current authenticated user's email
    v_user_email := auth.jwt() ->> 'email';

    IF v_user_email IS NULL THEN
        RETURN;
    END IF;

    -- Search funcionarios by email and link if usuario_id is null
    UPDATE public.funcionarios
    SET usuario_id = auth.uid()
    WHERE email = v_user_email AND usuario_id IS NULL
    RETURNING id INTO v_func_id;

    -- If already linked, nothing more to do
    IF v_func_id IS NOT NULL THEN
        RETURN;
    END IF;

    -- Check if the user is already linked (email match but usuario_id already set)
    SELECT id INTO v_func_id
    FROM public.funcionarios
    WHERE usuario_id = auth.uid()
    LIMIT 1;

    -- If still not found, try funcionarios_detalhes (which has an email column)
    IF v_func_id IS NULL THEN
        SELECT funcionario_id INTO v_func_id
        FROM public.funcionarios_detalhes
        WHERE email = v_user_email
        LIMIT 1;

        IF v_func_id IS NOT NULL THEN
            -- Attempt to link in the funcionarios table by id
            UPDATE public.funcionarios
            SET usuario_id = auth.uid()
            WHERE id = v_func_id AND usuario_id IS NULL;
        END IF;
    END IF;
END;
$function$

;
-- Function: log_can_approve_quotes_change
CREATE OR REPLACE FUNCTION public.log_can_approve_quotes_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.can_approve_quotes IS DISTINCT FROM OLD.can_approve_quotes THEN
    INSERT INTO public.logs_auditoria (
      tabela, operacao, registro_id, usuario_id,
      dados_anteriores, dados_novos, observacao
    )
    VALUES (
      'usuarios',
      'UPDATE',
      NEW.id,
      auth.uid(),
      jsonb_build_object(
        'can_approve_quotes', OLD.can_approve_quotes,
        'nome', OLD.nome,
        'email', OLD.email
      ),
      jsonb_build_object(
        'can_approve_quotes', NEW.can_approve_quotes,
        'nome', NEW.nome,
        'email', NEW.email
      ),
      CASE
        WHEN NEW.can_approve_quotes THEN 'Permissao de aprovacao de orcamento concedida'
        ELSE 'Permissao de aprovacao de orcamento revogada'
      END
    );
  END IF;
  RETURN NEW;
END;
$function$

;
-- Function: normalize_orcamento_status
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
$function$

;
-- Function: processar_retorno_bancario
CREATE OR REPLACE FUNCTION public.processar_retorno_bancario(p_nome_arquivo text, p_hash text, p_conta text, p_registros jsonb, p_forcar boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_arquivo_id     uuid;
  v_reg            jsonb;
  v_boleto         public.boletos%ROWTYPE;
  v_transacao_id   uuid;
  v_aplicados      integer := 0;
  v_divergentes    integer := 0;
  v_nao_encontrados integer := 0;
BEGIN
  IF p_registros IS NULL OR jsonb_typeof(p_registros) <> 'array' THEN
    RAISE EXCEPTION 'p_registros deve ser um array JSON.' USING ERRCODE = 'P0001';
  END IF;

  IF NOT p_forcar AND EXISTS (SELECT 1 FROM public.retorno_bancario_arquivos WHERE hash_conteudo = p_hash) THEN
    RAISE EXCEPTION 'Arquivo % já foi processado anteriormente (hash %). Use a opção de forçar reprocessamento se isso for intencional.', p_nome_arquivo, p_hash
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.retorno_bancario_arquivos (nome_arquivo, hash_conteudo, conta, processado_por, forcado, total_registros)
  VALUES (p_nome_arquivo, p_hash, p_conta, auth.uid(), p_forcar, jsonb_array_length(p_registros))
  RETURNING id INTO v_arquivo_id;

  FOR v_reg IN SELECT * FROM jsonb_array_elements(p_registros)
  LOOP
    SELECT * INTO v_boleto FROM public.boletos WHERE nosso_numero = v_reg->>'nosso_numero' LIMIT 1;

    IF NOT FOUND THEN
      INSERT INTO public.retorno_bancario_registros
        (arquivo_id, nosso_numero, valor_recebido, data_pagamento, ocorrencia_codigo, status_aplicacao)
      VALUES
        (v_arquivo_id, v_reg->>'nosso_numero', (v_reg->>'valor_recebido')::numeric, (v_reg->>'data_pagamento')::date, v_reg->>'ocorrencia_codigo', 'nao_encontrado');
      v_nao_encontrados := v_nao_encontrados + 1;
      CONTINUE;
    END IF;

    IF coalesce((v_reg->>'valor_recebido')::numeric, 0) <> coalesce(v_boleto.valor, 0) THEN
      INSERT INTO public.retorno_bancario_registros
        (arquivo_id, nosso_numero, boleto_id, parcela_id, valor_esperado, valor_recebido, data_pagamento, ocorrencia_codigo, status_aplicacao, motivo_divergencia)
      VALUES
        (v_arquivo_id, v_reg->>'nosso_numero', v_boleto.id, v_boleto.parcela_id, v_boleto.valor, (v_reg->>'valor_recebido')::numeric, (v_reg->>'data_pagamento')::date, v_reg->>'ocorrencia_codigo', 'divergente', 'Valor recebido difere do valor esperado do boleto.');
      v_divergentes := v_divergentes + 1;
      CONTINUE;
    END IF;

    UPDATE public.boletos
    SET status = 'pago',
        valor_pago = (v_reg->>'valor_recebido')::numeric,
        data_pagamento = (v_reg->>'data_pagamento')::date
    WHERE id = v_boleto.id;

    IF v_boleto.parcela_id IS NOT NULL THEN
      UPDATE public.projeto_parcelas
      SET status = 'paga'::public.parcela_status,
          valor_pago = (v_reg->>'valor_recebido')::numeric,
          data_pagamento = (v_reg->>'data_pagamento')::date
      WHERE id = v_boleto.parcela_id;
    END IF;

    INSERT INTO public.transacoes (parcela_id, tipo, descricao, valor, data_transacao, vl_pago, dt_pagamento, status_pago, created_by)
    VALUES (
      v_boleto.parcela_id,
      'receita'::public.transacao_tipo,
      'Recebimento boleto ' || v_boleto.nosso_numero,
      v_boleto.valor,
      (v_reg->>'data_pagamento')::date,
      (v_reg->>'valor_recebido')::numeric,
      (v_reg->>'data_pagamento')::date,
      1,
      auth.uid()
    )
    RETURNING id INTO v_transacao_id;

    IF v_boleto.parcela_id IS NOT NULL THEN
      UPDATE public.projeto_parcelas
      SET transacao_id = v_transacao_id
      WHERE id = v_boleto.parcela_id;
    END IF;

    INSERT INTO public.retorno_bancario_registros
      (arquivo_id, nosso_numero, boleto_id, parcela_id, transacao_id, valor_esperado, valor_recebido, data_pagamento, ocorrencia_codigo, status_aplicacao)
    VALUES
      (v_arquivo_id, v_reg->>'nosso_numero', v_boleto.id, v_boleto.parcela_id, v_transacao_id, v_boleto.valor, (v_reg->>'valor_recebido')::numeric, (v_reg->>'data_pagamento')::date, v_reg->>'ocorrencia_codigo', 'aplicado');
    v_aplicados := v_aplicados + 1;
  END LOOP;

  UPDATE public.retorno_bancario_arquivos
  SET total_aplicados = v_aplicados, total_divergentes = v_divergentes, total_nao_encontrados = v_nao_encontrados
  WHERE id = v_arquivo_id;

  RETURN jsonb_build_object(
    'arquivo_id', v_arquivo_id,
    'aplicados', v_aplicados,
    'divergentes', v_divergentes,
    'nao_encontrados', v_nao_encontrados
  );
END;
$function$

;
-- Function: propagate_contato_nome
CREATE OR REPLACE FUNCTION public.propagate_contato_nome()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  IF OLD.nome IS NOT DISTINCT FROM NEW.nome THEN
    RETURN NEW;
  END IF;

  UPDATE public.separacoes
  SET cliente    = NEW.nome,
      updated_at = NOW()
  WHERE cliente_id = NEW.id;

  RETURN NEW;
END;
$function$

;
-- Function: propagate_projeto_codigo
CREATE OR REPLACE FUNCTION public.propagate_projeto_codigo()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  IF OLD.codigo IS NOT DISTINCT FROM NEW.codigo THEN
    RETURN NEW;
  END IF;

  UPDATE separacoes
  SET codigo_obra = NEW.codigo,
      updated_at  = NOW()
  WHERE projeto_id = NEW.id;

  RETURN NEW;
END;
$function$

;
-- Function: propagate_usuario_nome
CREATE OR REPLACE FUNCTION public.propagate_usuario_nome()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  IF OLD.nome IS NOT DISTINCT FROM NEW.nome THEN
    RETURN NEW;
  END IF;

  UPDATE public.projetos
  SET responsavel_nome = NEW.nome,
      updated_at       = NOW()
  WHERE responsavel_id = NEW.id;

  RETURN NEW;
END;
$function$

;
-- Function: registrar_devolucao_projeto_item
CREATE OR REPLACE FUNCTION public.registrar_devolucao_projeto_item(p_projeto_item_id uuid, p_quantidade numeric, p_motivo text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_saldo             public.estoque_saldos_projeto_item%ROWTYPE;
    v_produto_id        uuid;
    v_de_entrega_futura numeric(10,3);
    v_de_reserva        numeric(10,3);
    v_de_entregue       numeric(10,3);
    v_restante          numeric(10,3);
    v_status            text;
    v_devolucao_id      uuid;
BEGIN
    IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
        RAISE EXCEPTION 'Quantidade deve ser maior que zero.' USING ERRCODE = 'P0001';
    END IF;

    SELECT produto_id INTO v_produto_id FROM public.projeto_itens WHERE id = p_projeto_item_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Item de projeto % nao encontrado.', p_projeto_item_id USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_saldo
    FROM public.estoque_saldos_projeto_item
    WHERE projeto_item_id = p_projeto_item_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Item de projeto % nao possui saldo operacional (estoque_saldos_projeto_item).', p_projeto_item_id USING ERRCODE = 'P0001';
    END IF;

    IF p_quantidade > (v_saldo.q_entrega_futura + v_saldo.q_reserva + v_saldo.q_entregue) THEN
        RAISE EXCEPTION 'Quantidade de devolucao (%) excede o total disponivel para devolver (entrega futura + reserva + entregue = %).',
            p_quantidade, (v_saldo.q_entrega_futura + v_saldo.q_reserva + v_saldo.q_entregue) USING ERRCODE = 'P0001';
    END IF;

    v_de_entrega_futura := LEAST(p_quantidade, v_saldo.q_entrega_futura);
    v_restante := p_quantidade - v_de_entrega_futura;
    v_de_reserva := LEAST(v_restante, v_saldo.q_reserva);
    v_restante := v_restante - v_de_reserva;
    v_de_entregue := LEAST(v_restante, v_saldo.q_entregue);

    UPDATE public.estoque_saldos_projeto_item
    SET q_entrega_futura = q_entrega_futura - v_de_entrega_futura,
        q_reserva = q_reserva - v_de_reserva,
        q_entregue = q_entregue - v_de_entregue,
        q_devolvida = q_devolvida + p_quantidade,
        atualizado_em = now()
    WHERE projeto_item_id = p_projeto_item_id;

    -- RN-08: estoque_itens.quantidade_reservada so eh reduzido pela parte que
    -- estava em saldo aberto (entrega futura ou reserva); devolucao de entregue
    -- depende de coleta/entrada fisica, tratada em fluxo logistico proprio.
    IF (v_de_entrega_futura + v_de_reserva) > 0 AND v_produto_id IS NOT NULL THEN
        UPDATE public.estoque_itens
        SET quantidade_reservada = GREATEST(quantidade_reservada - (v_de_entrega_futura + v_de_reserva), 0)
        WHERE produto_id = v_produto_id
          AND local = 'Estoque'::public.estoque_local;
    END IF;

    v_status := CASE WHEN v_de_entregue > 0 THEN 'aguardando_coleta' ELSE 'registrada' END;

    INSERT INTO public.devolucoes_estoque (
        projeto_item_id, quantidade, qtd_de_entrega_futura, qtd_de_reserva, qtd_de_entregue,
        status, motivo, solicitado_por
    ) VALUES (
        p_projeto_item_id, p_quantidade, v_de_entrega_futura, v_de_reserva, v_de_entregue,
        v_status, p_motivo, auth.uid()
    )
    RETURNING id INTO v_devolucao_id;

    INSERT INTO public.estoque_movimentos_projeto_item
        (projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por)
    VALUES
        (p_projeto_item_id, 'devolucao', p_quantidade, 'devolucao_estoque', v_devolucao_id, p_motivo, auth.uid());

    RETURN jsonb_build_object(
        'devolucao_id', v_devolucao_id,
        'status', v_status,
        'de_entrega_futura', v_de_entrega_futura,
        'de_reserva', v_de_reserva,
        'de_entregue', v_de_entregue
    );
END;
$function$

;
-- Function: replace_orcamento_itens
CREATE OR REPLACE FUNCTION public.replace_orcamento_itens(p_orcamento_id uuid, p_items jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  inserted_count integer;
BEGIN
  DELETE FROM public.orcamento_itens WHERE orcamento_id = p_orcamento_id;

  INSERT INTO public.orcamento_itens (
    orcamento_id,
    produto_id,
    descricao,
    quantidade,
    preco_unitario,
    desconto,
    custom_id,
    ordem,
    sub_ordem,
    item_pai_id,
    peca_nova
  )
  SELECT
    p_orcamento_id,
    CASE
      WHEN item->>'produto_id' IS NULL OR item->>'produto_id' = '' THEN NULL
      ELSE (item->>'produto_id')::uuid
    END,
    NULLIF(item->>'descricao', ''),
    (item->>'quantidade')::numeric,
    (item->>'preco_unitario')::numeric,
    (item->>'desconto')::numeric,
    NULLIF(item->>'custom_id', ''),
    CASE
      WHEN item->>'ordem' IS NULL OR item->>'ordem' = '' THEN NULL
      ELSE (item->>'ordem')::integer
    END,
    CASE
      WHEN item->>'sub_ordem' IS NULL OR item->>'sub_ordem' = '' THEN NULL
      ELSE (item->>'sub_ordem')::integer
    END,
    CASE
      WHEN item->>'item_pai_id' IS NULL OR item->>'item_pai_id' = '' THEN NULL
      ELSE (item->>'item_pai_id')::uuid
    END,
    COALESCE((item->>'peca_nova')::boolean, false)
  FROM jsonb_array_elements(p_items) AS item
  WHERE (item->>'produto_id' IS NOT NULL AND item->>'produto_id' != '')
     OR NULLIF(item->>'descricao', '') IS NOT NULL;

  GET DIAGNOSTICS inserted_count = ROW_COUNT;
  RETURN inserted_count;
END;
$function$

;
-- Function: set_orcamento_numero
CREATE OR REPLACE FUNCTION public.set_orcamento_numero()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_max_num INTEGER;
BEGIN
  IF NEW.numero IS NULL OR NEW.numero = '' THEN
    SELECT COALESCE(MAX(CAST(SUBSTRING(numero FROM 5) AS INTEGER)), 0)
    INTO v_max_num
    FROM public.orcamentos
    WHERE numero LIKE 'ORC-%' AND numero ~ '^ORC-\d+$';

    NEW.numero := 'ORC-' || LPAD((v_max_num + 1)::text, 4, '0');
  END IF;
  RETURN NEW;
END;
$function$

;
-- Function: set_projeto_itens_descricao
CREATE OR REPLACE FUNCTION public.set_projeto_itens_descricao()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.descricao IS NULL OR trim(NEW.descricao) = '' THEN
    IF NEW.produto_id IS NOT NULL THEN
      NEW.descricao := (SELECT nome FROM public.produtos WHERE id = NEW.produto_id);
    END IF;
    
    IF NEW.descricao IS NULL OR trim(NEW.descricao) = '' THEN
      NEW.descricao := 'Item sem descrição';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$

;
-- Function: set_updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$

;
-- Function: solicitar_transferencia_estoque
CREATE OR REPLACE FUNCTION public.solicitar_transferencia_estoque(p_origem_projeto_item_id uuid, p_destino_projeto_item_id uuid, p_quantidade numeric, p_motivo text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_origem_produto  uuid;
    v_destino_produto uuid;
    v_origem_saldo    public.estoque_saldos_projeto_item%ROWTYPE;
    v_transferencia_id uuid;
BEGIN
    IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
        RAISE EXCEPTION 'Quantidade deve ser maior que zero.' USING ERRCODE = 'P0001';
    END IF;

    IF p_origem_projeto_item_id = p_destino_projeto_item_id THEN
        RAISE EXCEPTION 'Origem e destino nao podem ser o mesmo item de projeto.' USING ERRCODE = 'P0001';
    END IF;

    SELECT produto_id INTO v_origem_produto FROM public.projeto_itens WHERE id = p_origem_projeto_item_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Item de projeto de origem % nao encontrado.', p_origem_projeto_item_id USING ERRCODE = 'P0001';
    END IF;

    SELECT produto_id INTO v_destino_produto FROM public.projeto_itens WHERE id = p_destino_projeto_item_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Item de projeto de destino % nao encontrado.', p_destino_projeto_item_id USING ERRCODE = 'P0001';
    END IF;

    IF v_origem_produto IS DISTINCT FROM v_destino_produto THEN
        RAISE EXCEPTION 'Origem e destino precisam ser do mesmo produto.' USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_origem_saldo
    FROM public.estoque_saldos_projeto_item
    WHERE projeto_item_id = p_origem_projeto_item_id;

    IF NOT FOUND OR v_origem_saldo.q_reserva < p_quantidade THEN
        RAISE EXCEPTION 'Origem nao tem q_reserva suficiente para a transferencia solicitada.' USING ERRCODE = 'P0001';
    END IF;

    INSERT INTO public.transferencias_estoque (
        origem_projeto_item_id, destino_projeto_item_id, quantidade, motivo, solicitado_por
    ) VALUES (
        p_origem_projeto_item_id, p_destino_projeto_item_id, p_quantidade, p_motivo, auth.uid()
    )
    RETURNING id INTO v_transferencia_id;

    RETURN jsonb_build_object('transferencia_id', v_transferencia_id, 'status', 'solicitada');
END;
$function$

;
-- Function: stats_datacenter
CREATE OR REPLACE FUNCTION public.stats_datacenter()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN json_build_object(
    'projetos',    (SELECT COUNT(*) FROM projetos WHERE arquivado = false),
    'contatos',    (SELECT COUNT(*) FROM contatos WHERE ativo = true),
    'funcionarios',(SELECT COUNT(*) FROM funcionarios WHERE status = 'Ativo'),
    'separacoes',  (SELECT COUNT(*) FROM separacoes WHERE status NOT IN ('Cancelado','Enviado')),
    'marcas',      (SELECT COUNT(*) FROM marcas WHERE ativo = true),
    'ultima_sync', (SELECT MAX(created_at) FROM sync_history WHERE status = 'sucesso')
  );
END;
$function$

;
-- Function: sync_contact_type_on_budget
CREATE OR REPLACE FUNCTION public.sync_contact_type_on_budget()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.cliente_id IS NOT NULL THEN
    -- Update the tipo column on contatos to 'cliente'
    UPDATE public.contatos
    SET tipo = 'cliente'
    WHERE id = NEW.cliente_id
      AND tipo IS DISTINCT FROM 'cliente'::public.contato_tipo;

    -- Also ensure the contato_tipos junction table has the 'cliente' entry
    INSERT INTO public.contato_tipos (contato_id, tipo)
    VALUES (NEW.cliente_id, 'cliente')
    ON CONFLICT (contato_id, tipo) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$function$

;
-- Function: sync_projeto_valor_total
CREATE OR REPLACE FUNCTION public.sync_projeto_valor_total()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  UPDATE projetos
  SET valor_total = (
    SELECT COALESCE(SUM(subtotal), 0)
    FROM projeto_itens
    WHERE projeto_id = NEW.projeto_id
  )
  WHERE id = NEW.projeto_id;
  RETURN NEW;
END;
$function$

;
-- Function: sync_responsavel_nome
CREATE OR REPLACE FUNCTION public.sync_responsavel_nome()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.responsavel_id IS NOT NULL THEN
    SELECT nome INTO NEW.responsavel_nome
    FROM public.usuarios WHERE id = NEW.responsavel_id;
  END IF;
  RETURN NEW;
END;
$function$

;
-- Function: sync_separacao_cliente
CREATE OR REPLACE FUNCTION public.sync_separacao_cliente()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.cliente_id IS NOT NULL THEN
    SELECT nome INTO NEW.cliente
    FROM public.contatos
    WHERE id = NEW.cliente_id;
  END IF;
  RETURN NEW;
END;
$function$

;
-- Function: sync_separacao_codigo_obra
CREATE OR REPLACE FUNCTION public.sync_separacao_codigo_obra()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.projeto_id IS NOT NULL THEN
    SELECT codigo INTO NEW.codigo_obra
    FROM public.projetos
    WHERE id = NEW.projeto_id;
  END IF;
  RETURN NEW;
END;
$function$

;
-- Function: track_reagendamento
CREATE OR REPLACE FUNCTION public.track_reagendamento()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  IF OLD.data_entrega IS NULL AND NEW.data_entrega IS NOT NULL THEN
    NEW.data_entrega_original = NEW.data_entrega;
  END IF;
  IF OLD.data_entrega IS NOT NULL
     AND NEW.data_entrega IS NOT NULL
     AND OLD.data_entrega <> NEW.data_entrega THEN
    NEW.reagendamentos = OLD.reagendamentos + 1;
  END IF;
  RETURN NEW;
END;
$function$

;
-- Function: trg_estoque_saldos_projeto_item_atualizado_em
CREATE OR REPLACE FUNCTION public.trg_estoque_saldos_projeto_item_atualizado_em()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.atualizado_em := now();
  RETURN NEW;
END;
$function$

;
-- Function: trigger_fechar_projeto
CREATE OR REPLACE FUNCTION public.trigger_fechar_projeto()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_sinal RECORD;
  v_item_entrega_futura RECORD;
BEGIN
  IF NEW.status = 'Entrega materiais'::public.projeto_status
     AND OLD.status <> 'Entrega materiais'::public.projeto_status THEN

    SELECT pi.id AS projeto_item_id,
           pi.descricao,
           esp.q_entrega_futura
      INTO v_item_entrega_futura
    FROM estoque_saldos_projeto_item esp
    JOIN projeto_itens pi ON pi.id = esp.projeto_item_id
    WHERE pi.projeto_id = NEW.id
      AND esp.status_operacional = 'ativo'
      AND esp.q_entrega_futura > 0
    LIMIT 1;

    IF FOUND THEN
      RAISE EXCEPTION
        'Projeto % possui item % com entrega futura pendente (%). Receba/reserve o material antes de entregar.',
        NEW.codigo,
        coalesce(v_item_entrega_futura.descricao, v_item_entrega_futura.projeto_item_id::text),
        v_item_entrega_futura.q_entrega_futura
        USING ERRCODE = 'P0001';
    END IF;

    -- 3a. Baixar estoque fisico (local='Estoque') pelo saldo coberto aberto
    --     real do item. q_entrega_futura nao entra aqui; ela e bloqueada acima.
    WITH aberto_por_produto AS (
      SELECT pi.produto_id,
             SUM(esp.q_reserva + esp.q_ag_separar + esp.q_separado) AS qtd_coberta
      FROM estoque_saldos_projeto_item esp
      JOIN projeto_itens pi ON pi.id = esp.projeto_item_id
      WHERE pi.projeto_id = NEW.id
        AND pi.produto_id IS NOT NULL
        AND esp.status_operacional = 'ativo'
      GROUP BY pi.produto_id
    )
    UPDATE estoque_itens ei
    SET quantidade    = GREATEST(0, ei.quantidade - aberto.qtd_coberta),
        atualizado_em = NOW()
    FROM aberto_por_produto aberto
    WHERE aberto.produto_id = ei.produto_id
      AND ei.local = 'Estoque'::public.estoque_local;

    -- 3b. Zerar reserva usando o saldo aberto coberto real, nao a quantidade
    --     original do item.
    WITH aberto_por_produto AS (
      SELECT pi.produto_id,
             SUM(esp.q_reserva + esp.q_ag_separar + esp.q_separado) AS qtd_coberta
      FROM estoque_saldos_projeto_item esp
      JOIN projeto_itens pi ON pi.id = esp.projeto_item_id
      WHERE pi.projeto_id = NEW.id
        AND pi.produto_id IS NOT NULL
        AND esp.status_operacional = 'ativo'
      GROUP BY pi.produto_id
    )
    UPDATE estoque_itens ei
    SET quantidade_reservada = GREATEST(0, ei.quantidade_reservada - aberto.qtd_coberta),
        atualizado_em        = NOW()
    FROM aberto_por_produto aberto
    WHERE aberto.produto_id = ei.produto_id
      AND ei.local = 'Estoque'::public.estoque_local;

    -- 3b-legado. Compatibilidade com reservas antigas em local='Reservado'.
    WITH aberto_por_produto AS (
      SELECT pi.produto_id,
             SUM(esp.q_reserva + esp.q_ag_separar + esp.q_separado) AS qtd_coberta
      FROM estoque_saldos_projeto_item esp
      JOIN projeto_itens pi ON pi.id = esp.projeto_item_id
      WHERE pi.projeto_id = NEW.id
        AND pi.produto_id IS NOT NULL
        AND esp.status_operacional = 'ativo'
      GROUP BY pi.produto_id
    )
    UPDATE estoque_itens ei
    SET quantidade    = GREATEST(0, ei.quantidade - aberto.qtd_coberta),
        atualizado_em = NOW()
    FROM aberto_por_produto aberto
    WHERE aberto.produto_id = ei.produto_id
      AND ei.local = 'Reservado'::public.estoque_local;

    -- 3b-saldo. Mover para q_entregue somente o saldo coberto aberto.
    WITH antes AS (
      SELECT esp.projeto_item_id,
             (esp.q_reserva + esp.q_ag_separar + esp.q_separado) AS qtd_coberta
      FROM estoque_saldos_projeto_item esp
      JOIN projeto_itens pi ON pi.id = esp.projeto_item_id
      WHERE pi.projeto_id = NEW.id
        AND esp.status_operacional = 'ativo'
    ),
    entregues AS (
      UPDATE estoque_saldos_projeto_item esp
      SET q_entregue       = esp.q_entregue + antes.qtd_coberta,
          q_reserva        = 0,
          q_ag_separar     = 0,
          q_separado       = 0
      FROM antes
      WHERE antes.projeto_item_id = esp.projeto_item_id
        AND antes.qtd_coberta > 0
      RETURNING esp.projeto_item_id
    )
    INSERT INTO estoque_movimentos_projeto_item (
      projeto_item_id, tipo, quantidade, origem, observacao
    )
    SELECT e.projeto_item_id, 'entregue', antes.qtd_coberta, 'trigger_fechar_projeto',
           'Entrega registrada no fechamento do projeto ' || NEW.codigo
    FROM entregues e
    JOIN antes ON antes.projeto_item_id = e.projeto_item_id;

    -- 3c. Marcar sinal como 'creditado'.
    UPDATE projeto_sinal
    SET status     = 'creditado'::public.sinal_status,
        updated_at = NOW()
    WHERE projeto_id = NEW.id
      AND status = 'recebido'::public.sinal_status;

    -- 3d. Criar separacao automaticamente com os itens validados.
    IF NOT EXISTS (
      SELECT 1 FROM separacoes
      WHERE projeto_id = NEW.id
        AND status NOT IN ('Cancelado'::public.separacao_status)
    ) THEN
      WITH nova_sep AS (
        INSERT INTO separacoes (
          projeto_id, responsavel_id, status,
          codigo_obra, cliente, observacoes
        )
        SELECT
          NEW.id,
          NEW.created_by,
          'Pendente'::public.separacao_status,
          NEW.codigo,
          (SELECT nome FROM contatos WHERE id = NEW.cliente_id),
          'Separação gerada automaticamente no fechamento do projeto'
        RETURNING id
      )
      INSERT INTO separacao_itens (separacao_id, produto_id, descricao, quantidade, unidade)
      SELECT
        nova_sep.id,
        pi.produto_id,
        pi.descricao,
        pi.quantidade,
        NULL
      FROM projeto_itens pi, nova_sep
      WHERE pi.projeto_id = NEW.id
        AND pi.validado = true;
    END IF;

  END IF;

  RETURN NEW;
END;
$function$

;
-- Function: trigger_proteger_fechamento
CREATE OR REPLACE FUNCTION public.trigger_proteger_fechamento()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
  itens_nao_validados INTEGER;
  status_fechamento public.projeto_status[] := ARRAY[
    'Projeto executivo'::public.projeto_status,
    'Entrega materiais'::public.projeto_status,
    'Ajustes finais'::public.projeto_status,
    'Finalizado'::public.projeto_status
  ];
BEGIN
  -- Só verifica quando está indo para um status de execução/fechamento
  IF NEW.status = ANY(status_fechamento)
     AND (OLD.status IS NULL OR OLD.status <> NEW.status) THEN

    SELECT COUNT(*) INTO itens_nao_validados
    FROM projeto_itens
    WHERE projeto_id = NEW.id
      AND validado = false;

    IF itens_nao_validados > 0 THEN
      RAISE EXCEPTION
        'Não é possível avançar o projeto para "%". Existem % item(ns) não validado(s). Valide todos os itens antes de fechar.',
        NEW.status, itens_nao_validados;
    END IF;

    -- Também verifica se existe pelo menos 1 item no projeto
    IF NOT EXISTS (SELECT 1 FROM projeto_itens WHERE projeto_id = NEW.id) THEN
      RAISE EXCEPTION
        'Não é possível fechar o projeto sem nenhum item cadastrado.';
    END IF;

  END IF;

  RETURN NEW;
END;
$function$

;
-- Function: trigger_proteger_parcelas
CREATE OR REPLACE FUNCTION public.trigger_proteger_parcelas()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
  v_status public.projeto_status;
BEGIN
  IF NEW.orcamento_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  SELECT status INTO v_status FROM projetos WHERE id = NEW.projeto_id;

  IF v_status NOT IN ('Ajustes finais'::public.projeto_status, 'Finalizado'::public.projeto_status) THEN
    RAISE EXCEPTION
      'Parcelas só podem ser criadas após o projeto estar em "Ajustes finais" ou "Finalizado". Status atual: %',
      v_status;
  END IF;

  RETURN NEW;
END;
$function$

;
-- Function: trigger_separacao_pronta
CREATE OR REPLACE FUNCTION public.trigger_separacao_pronta()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.status = 'Pronto'::public.separacao_status AND OLD.status <> 'Pronto'::public.separacao_status THEN
    IF NEW.data_entrega IS NULL THEN
      RAISE EXCEPTION 'Defina a data de entrega antes de marcar a separação como Pronto.';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM public.entregas
      WHERE separacao_id = NEW.id
        AND status <> 'Cancelado'::public.entrega_status
    ) THEN
      INSERT INTO public.entregas (
        separacao_id,
        projeto_id,
        entregador_id,
        endereco_entrega,
        contato_destino,
        data_prevista,
        status
      ) VALUES (
        NEW.id,
        NEW.projeto_id,
        NEW.responsavel_id,
        NEW.endereco_entrega,
        NEW.cliente,
        NEW.data_entrega,
        'Pendente'::public.entrega_status
      );
    ELSE
      UPDATE public.entregas
      SET data_prevista = NEW.data_entrega,
          updated_at    = NOW()
      WHERE separacao_id = NEW.id
        AND status = 'Pendente'::public.entrega_status;
    END IF;
  END IF;

  IF NEW.status = 'Pronto'::public.separacao_status
     AND OLD.data_entrega IS DISTINCT FROM NEW.data_entrega
     AND NEW.data_entrega IS NOT NULL THEN

    UPDATE public.entregas
    SET data_prevista = NEW.data_entrega,
        updated_at    = NOW()
    WHERE separacao_id = NEW.id
      AND status = 'Pendente'::public.entrega_status;

  END IF;

  RETURN NEW;
END;
$function$

;
-- Function: trigger_update_revenda_ubiqua_slug
CREATE OR REPLACE FUNCTION public.trigger_update_revenda_ubiqua_slug()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.slug := public.generate_product_slug(COALESCE(NEW.desc_produto, NEW.descricao), NEW.valor_revenda);
  RETURN NEW;
END;
$function$

;
-- Function: unaccent
CREATE OR REPLACE FUNCTION public.unaccent(regdictionary, text)
 RETURNS text
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/unaccent', $function$unaccent_dict$function$

;
-- Function: unaccent
CREATE OR REPLACE FUNCTION public.unaccent(text)
 RETURNS text
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/unaccent', $function$unaccent_dict$function$

;
-- Function: unaccent_init
CREATE OR REPLACE FUNCTION public.unaccent_init(internal)
 RETURNS internal
 LANGUAGE c
 PARALLEL SAFE
AS '$libdir/unaccent', $function$unaccent_init$function$

;
-- Function: unaccent_lexize
CREATE OR REPLACE FUNCTION public.unaccent_lexize(internal, internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 PARALLEL SAFE
AS '$libdir/unaccent', $function$unaccent_lexize$function$

;
-- Function: update_revenda_ubiqua_ordem
CREATE OR REPLACE FUNCTION public.update_revenda_ubiqua_ordem(payload jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  item jsonb;
  v_caller_role public.usuario_role;
BEGIN
  SELECT role INTO v_caller_role FROM public.usuarios WHERE id = auth.uid();
  
  IF v_caller_role NOT IN ('admin', 'gerente') THEN
    RAISE EXCEPTION 'Apenas administradores e gerentes podem reordenar o catálogo.';
  END IF;

  FOR item IN SELECT * FROM jsonb_array_elements(payload)
  LOOP
    UPDATE public.revenda_ubiqua
    SET ordem = (item->>'ordem')::integer
    WHERE id = (item->>'id')::integer;
  END LOOP;
END;
$function$

;
-- Function: update_revenda_ubiqua_updated_at
CREATE OR REPLACE FUNCTION public.update_revenda_ubiqua_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$function$

;
-- Function: update_updated_at_column
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$function$

;
-- Function: voltar_orcamento_rascunho
-- SPEC-070 (06/08/2026): transição enviado_cliente|recusado_cliente ->
-- rascunho, restrita a admin/gerente, motivo obrigatório, invalida
-- token_aprovacao_cliente. Redigida a partir da migration
-- 20260806_082_spec070_voltar_orcamento_rascunho/001_...sql — ainda NÃO
-- aplicada no Supabase real (ver supabase/db/domains/orcamentos.md).
-- NOTA: este bloco reflete apenas a função nova desta SPEC. A
-- reextração completa do snapshot do domínio Orçamentos (pendência
-- crônica desde a SPEC-031, ver supabase/db/domains/orcamentos.md)
-- continua em aberto — não foi feita nesta sessão porque exigiria
-- consulta direta ao Supabase real, fora do escopo permitido ao agente
-- implementador sem autorização explícita para leitura ad-hoc do banco.
CREATE OR REPLACE FUNCTION public.voltar_orcamento_rascunho(p_orcamento_id uuid, p_motivo text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_orcamento public.orcamentos%ROWTYPE;
  v_status_anterior text;
  v_numero text;
  v_user_role text;
BEGIN
  IF p_motivo IS NULL OR btrim(p_motivo) = '' THEN
    RAISE EXCEPTION 'Informe o motivo antes de voltar o orçamento para rascunho.' USING ERRCODE = 'P0001';
  END IF;

  SELECT u.role INTO v_user_role FROM public.usuarios u WHERE u.id = auth.uid();

  IF v_user_role NOT IN ('admin', 'gerente') THEN
    RAISE EXCEPTION 'Apenas admin ou gerente podem voltar um orçamento para rascunho.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_orcamento FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento não encontrado.' USING ERRCODE = 'P0001';
  END IF;

  v_status_anterior := v_orcamento.status;
  v_numero := COALESCE(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.status NOT IN ('enviado_cliente', 'recusado_cliente') THEN
    RAISE EXCEPTION 'Orçamento % não pode voltar para rascunho a partir do status atual: %', v_numero, v_status_anterior
      USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.orcamentos
  SET status = 'rascunho',
      token_aprovacao_cliente = NULL
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (p_orcamento_id, v_status_anterior, 'rascunho', auth.uid()::text, p_motivo);

  RETURN jsonb_build_object('orcamento_id', p_orcamento_id, 'numero', v_numero, 'status', 'rascunho');
END;
$function$

;
