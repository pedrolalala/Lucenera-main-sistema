-- Function: public._lucenera_parse_prazo_pagamento(p_condicoes_pagamento text, p_prazo_pagamento_dias integer[])
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

-- Function: public.admin_update_user_password(p_user_id uuid, p_new_password text)
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

-- Function: public.admin_update_user_role(p_user_id uuid, p_role text)
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

-- Function: public.admin_update_user_status(p_user_id uuid, p_ativo boolean)
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

-- Function: public.aprovar_orcamento_financeiro(p_orcamento_id uuid)
CREATE OR REPLACE FUNCTION public.aprovar_orcamento_financeiro(p_orcamento_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  v_result := public.aprovar_orcamento_financeiro_base_spec001(p_orcamento_id);

  RETURN coalesce(v_result, '{}'::jsonb)
    || jsonb_build_object('financeiro_usa_orcamento_id', true);
END;
$function$
;

-- Function: public.aprovar_orcamento_financeiro_base_spec001(p_orcamento_id uuid)
CREATE OR REPLACE FUNCTION public.aprovar_orcamento_financeiro_base_spec001(p_orcamento_id uuid)
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
BEGIN
  SELECT *
    INTO v_orcamento
  FROM public.orcamentos
  WHERE id = p_orcamento_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento % não encontrado.', p_orcamento_id
      USING ERRCODE = 'P0001';
  END IF;

  v_status_anterior := v_orcamento.status;
  v_numero_orcamento := coalesce(v_orcamento.numero, left(p_orcamento_id::text, 8));

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
        coalesce(oi.quantidade, 0) <= 0
        OR coalesce(oi.preco_unitario, 0) <= 0
      )
  ) THEN
    RAISE EXCEPTION 'Orçamento % possui item sem quantidade ou preço válido.', v_numero_orcamento
      USING ERRCODE = 'P0001';
  END IF;

  v_prazos := public._lucenera_parse_prazo_pagamento(
    v_orcamento.condicoes_pagamento,
    v_orcamento.prazo_pagamento_dias
  );
  v_qtd_parcelas := coalesce(array_length(v_prazos, 1), 0);

  IF v_qtd_parcelas = 0 THEN
    RAISE EXCEPTION 'Orçamento % não possui prazo de pagamento interpretável. Edite o orçamento e informe o "Prazo para Início da Cobrança (dias)".', v_numero_orcamento
      USING ERRCODE = 'P0001';
  END IF;

  SELECT nome
    INTO v_cliente_nome
  FROM public.contatos
  WHERE id = v_orcamento.cliente_id;

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
     OR v_boletos_existentes > 0 THEN
    IF v_itens_existentes > 0
       AND v_parcelas_existentes = v_qtd_parcelas
       AND v_boletos_existentes = v_qtd_parcelas THEN
      UPDATE public.orcamentos
      SET status = 'aprovado'
      WHERE id = p_orcamento_id;

      RETURN jsonb_build_object(
        'orcamento_id', p_orcamento_id,
        'status', 'aprovado',
        'projeto_id', v_orcamento.projeto_id,
        'projeto_itens_criados', 0,
        'parcelas_criadas', 0,
        'boletos_criados', 0,
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

  -- subtotal é coluna GENERATED ALWAYS (round(quantidade*preco_unitario*
  -- (1-desconto/100),2)) — não inserir valor explícito, deixar o Postgres
  -- calcular.
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
  WHERE oi.orcamento_id = p_orcamento_id;

  GET DIAGNOSTICS v_itens_criados = ROW_COUNT;

  v_valor_total := coalesce(v_orcamento.valor_total, 0);
  v_valor_base := round(v_valor_total / v_qtd_parcelas, 2);

  FOR v_i IN 1..v_qtd_parcelas LOOP
    IF v_i = v_qtd_parcelas THEN
      v_valor_parcela := v_valor_total - v_valor_acumulado;
    ELSE
      v_valor_parcela := v_valor_base;
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
    'ORC-' || regexp_replace(v_numero_orcamento, '[^a-zA-Z0-9]', '', 'g') || '-P' || pp.numero_parcela,
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

  RETURN jsonb_build_object(
    'orcamento_id', p_orcamento_id,
    'status', 'aprovado',
    'projeto_id', v_orcamento.projeto_id,
    'projeto_itens_criados', v_itens_criados,
    'parcelas_criadas', v_parcelas_criadas,
    'boletos_criados', v_boletos_criados,
    'nota_fiscal_status', 'pendente_api',
    'ja_processado', false
  );
END;
$function$
;

-- Function: public.criar_usuario(p_email text, p_password text, p_nome text, p_role usuario_role)
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

-- Function: public.fn_atualiza_updated_at()
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

-- Function: public.fn_atualizar_preco_venda()
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

-- Function: public.fn_auto_numero_orcamento()
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

-- Function: public.fn_gerar_numero_orcamento()
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

-- Function: public.fn_log_auditoria()
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

-- Function: public.fn_update_orcamento_timestamp()
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

-- Function: public.generate_product_slug(nome text, preco numeric)
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

-- REMOVIDO (migration 016): gerenciar_fluxo_projeto() — código legado com esquema obsoleto.
-- Referenciava colunas item_id/orcamento_item_id inexistentes em projeto_itens e
-- disparava em projetos.status='Aprovado' que não existe no enum projeto_status.
-- Substituído pelo RPC aprovar_orcamento_financeiro_base_spec001.

-- Function: public.get_dashboard_crm_by_closing(data_inicial date, data_final date)
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

-- Function: public.get_dashboard_kpi(p_date_now date)
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

-- Function: public.get_dashboard_stats()
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

-- Function: public.get_faltas_injustificadas(p_funcionario_id uuid, p_inicio date, p_fim date)
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

-- Function: public.get_latest_transaction_id()
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

-- Function: public.get_next_sku(prefix text)
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

-- Function: public.get_user_role()
CREATE OR REPLACE FUNCTION public.get_user_role()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN (SELECT role FROM public.profiles WHERE id = auth.uid());
END;
$function$
;

-- Function: public.get_vendedores()
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

-- Function: public.handle_contato_tipo()
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

-- Function: public.handle_new_auth_user()
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

-- Function: public.handle_new_user()
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  INSERT INTO public.profiles (id, full_name, role)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'full_name',
    'visitante'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$function$
;

-- Function: public.handle_updated_at()
CREATE OR REPLACE FUNCTION public.handle_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$ BEGIN NEW.updated_at = now(); RETURN NEW; END; $function$
;

-- Function: public.is_admin()
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

-- Function: public.is_ubiqua_admin()
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

-- Function: public.limpar_staging_processados()
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

-- Function: public.propagate_contato_nome()
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

-- Function: public.propagate_projeto_codigo()
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

-- Function: public.propagate_usuario_nome()
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

-- Function: public.set_orcamento_numero()
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

-- Function: public.set_projeto_itens_descricao()
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

-- Function: public.set_updated_at()
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

-- Function: public.stats_datacenter()
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

-- Function: public.sync_projeto_valor_total()
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

-- Function: public.sync_responsavel_nome()
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

-- Function: public.sync_separacao_cliente()
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

-- Function: public.sync_separacao_codigo_obra()
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

-- Function: public.track_reagendamento()
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

-- Function: public.trigger_fechar_projeto()
-- Atualizado migration 016: passo 3b agora zera quantidade_reservada (novo sistema)
-- além de manter compatibilidade com local='Reservado' legado.
CREATE OR REPLACE FUNCTION public.trigger_fechar_projeto()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_sinal RECORD;
BEGIN
  IF NEW.status = 'Entrega materiais'::public.projeto_status AND OLD.status <> 'Entrega materiais'::public.projeto_status THEN

    -- 3a. Baixar estoque físico (local='Estoque') por produto
    UPDATE estoque_itens ei
    SET quantidade    = GREATEST(0, ei.quantidade - pi.quantidade),
        atualizado_em = NOW()
    FROM projeto_itens pi
    WHERE pi.projeto_id = NEW.id
      AND pi.produto_id = ei.produto_id
      AND ei.local = 'Estoque'::public.estoque_local;

    -- 3b. Zerar reserva — novo sistema (quantidade_reservada na linha Estoque)
    UPDATE estoque_itens ei
    SET quantidade_reservada = GREATEST(0, ei.quantidade_reservada - pi.quantidade),
        atualizado_em        = NOW()
    FROM projeto_itens pi
    WHERE pi.projeto_id = NEW.id
      AND pi.produto_id = ei.produto_id
      AND ei.local = 'Estoque'::public.estoque_local;

    -- 3b-legado. Compatibilidade com reservas antigas em local='Reservado'
    UPDATE estoque_itens ei
    SET quantidade    = GREATEST(0, ei.quantidade - pi.quantidade),
        atualizado_em = NOW()
    FROM projeto_itens pi
    WHERE pi.projeto_id = NEW.id
      AND pi.produto_id = ei.produto_id
      AND ei.local = 'Reservado'::public.estoque_local;

    -- 3c. Marcar sinal como 'creditado' (cliente comprou)
    UPDATE projeto_sinal
    SET status     = 'creditado'::public.sinal_status,
        updated_at = NOW()
    WHERE projeto_id = NEW.id
      AND status = 'recebido'::public.sinal_status;

    -- 3d. Criar separação automaticamente com os itens validados
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

-- Function: public.trigger_proteger_fechamento()
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

-- Function: public.trigger_proteger_parcelas()
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

-- REMOVIDO (migration 016): trigger_reserva_estoque() — sistema legado de reserva.
-- Criava linhas local='Reservado' em estoque_itens ao mudar projetos.status → 'Proposta Sinal'.
-- O novo sistema (migration 010) usa quantidade_reservada na linha local='Estoque'.

-- Function: public.trigger_separacao_pronta()
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

-- Function: public.trigger_update_revenda_ubiqua_slug()
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

-- Function: public.unaccent(regdictionary, text)
CREATE OR REPLACE FUNCTION public.unaccent(regdictionary, text)
 RETURNS text
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/unaccent', $function$unaccent_dict$function$
;

-- Function: public.unaccent(text)
CREATE OR REPLACE FUNCTION public.unaccent(text)
 RETURNS text
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/unaccent', $function$unaccent_dict$function$
;

-- Function: public.unaccent_init(internal)
CREATE OR REPLACE FUNCTION public.unaccent_init(internal)
 RETURNS internal
 LANGUAGE c
 PARALLEL SAFE
AS '$libdir/unaccent', $function$unaccent_init$function$
;

-- Function: public.unaccent_lexize(internal, internal, internal, internal)
CREATE OR REPLACE FUNCTION public.unaccent_lexize(internal, internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 PARALLEL SAFE
AS '$libdir/unaccent', $function$unaccent_lexize$function$
;

-- Function: public.update_revenda_ubiqua_ordem(payload jsonb)
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

-- Function: public.update_revenda_ubiqua_updated_at()
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

-- Function: public.update_updated_at_column()
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

-- ─── cancelar_orcamento ────────────────────────────────────────────────────────
-- Atualizado migration 016: cancela também projeto_parcelas, boletos e invalida projeto_itens.
CREATE OR REPLACE FUNCTION public.cancelar_orcamento(
    p_orcamento_id uuid,
    p_motivo       text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_orcamento           public.orcamentos%ROWTYPE;
    v_status_anterior     text;
    v_numero_orcamento    text;
    v_reservas_revertidas integer := 0;
    v_parcelas_canceladas integer := 0;
    v_boletos_cancelados  integer := 0;
    v_itens_invalidados   integer := 0;
BEGIN
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

    IF v_status_anterior = 'cancelado' THEN
        RETURN jsonb_build_object(
            'orcamento_id',        p_orcamento_id,
            'numero',              v_numero_orcamento,
            'status',              'cancelado',
            'reservas_revertidas', 0,
            'parcelas_canceladas', 0,
            'boletos_cancelados',  0,
            'itens_invalidados',   0,
            'ja_cancelado',        true
        );
    END IF;

    IF v_status_anterior = 'aprovado' THEN

        -- 3a. Reverter reservas de estoque
        UPDATE public.estoque_itens ei
        SET quantidade_reservada = GREATEST(0, ei.quantidade_reservada - oi.quantidade),
            atualizado_em        = NOW()
        FROM public.orcamento_itens oi
        WHERE oi.orcamento_id  = p_orcamento_id
          AND oi.produto_id    IS NOT NULL
          AND coalesce(oi.quantidade, 0) > 0
          AND ei.produto_id    = oi.produto_id
          AND ei.local         = 'Estoque'::public.estoque_local;

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

        -- 3d. Invalidar projeto_itens (soft — preserva histórico de auditoria)
        UPDATE public.projeto_itens
        SET validado = false
        WHERE orcamento_id = p_orcamento_id
          AND validado = true;

        GET DIAGNOSTICS v_itens_invalidados = ROW_COUNT;

    END IF;

    UPDATE public.orcamentos
    SET status = 'cancelado'
    WHERE id = p_orcamento_id;

    INSERT INTO public.historico_status_orcamentos (
        orcamento_id, status_anterior, status_novo, usuario, observacao
    ) VALUES (
        p_orcamento_id, v_status_anterior, 'cancelado',
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
        'ja_cancelado',        false
    );
END;
$$;

