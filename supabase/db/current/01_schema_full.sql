--
-- PostgreSQL database dump
--

\restrict bEOEq0x0RgSEJMK4u2zA0jM9A12IpctkQStRH3JoNXs9TmjSS0absABRm0c70Uc

-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: conta_tipo; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.conta_tipo AS ENUM (
    'Corrente',
    'Poupança',
    'CDB',
    'Investimento',
    'Caixa'
);


--
-- Name: contato_tipo; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.contato_tipo AS ENUM (
    'cliente',
    'arquiteto',
    'engenheiro',
    'eletricista',
    'fornecedor',
    'outro'
);


--
-- Name: entrega_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.entrega_status AS ENUM (
    'Pendente',
    'Em rota',
    'Entregue',
    'Cancelado'
);


--
-- Name: estoque_local; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.estoque_local AS ENUM (
    'Estoque',
    'Showroom',
    'Em trânsito',
    'Reservado',
    'Estoque Geral',
    'Estoque Luce Nera',
    'Estoque Islight',
    'Estoque Foco',
    'Estoque Garantia',
    'Estoque Casa Cor',
    'Reserva',
    'Separação',
    'Entrega Futura',
    'Devolução',
    'Estoque Defeito',
    'Amostra / Emprestado',
    'Estoque Citel'
);


--
-- Name: frequencia_tipo; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.frequencia_tipo AS ENUM (
    'mensal',
    'trimestral',
    'semestral',
    'anual'
);


--
-- Name: funcao_separacao_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.funcao_separacao_type AS ENUM (
    'admin',
    'operador',
    'entregador',
    'user'
);


--
-- Name: lancamento_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.lancamento_status AS ENUM (
    'pendente',
    'pago',
    'cancelado'
);


--
-- Name: nivel_acesso_tipo; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.nivel_acesso_tipo AS ENUM (
    'revendedor',
    'interno',
    'admin'
);


--
-- Name: pagamento_forma; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.pagamento_forma AS ENUM (
    'pix',
    'cartao',
    'boleto',
    'transferencia',
    'cheque',
    'dinheiro'
);


--
-- Name: parcela_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.parcela_status AS ENUM (
    'pendente',
    'paga',
    'atrasada',
    'cancelada'
);


--
-- Name: projeto_nivel; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.projeto_nivel AS ENUM (
    '1',
    '2',
    '3',
    '4'
);


--
-- Name: projeto_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.projeto_status AS ENUM (
    'Estudo Inicial',
    'Proposta Sinal',
    'Elaboração Orçamento',
    'Informações necessárias',
    'Projeto executivo',
    'Entrega materiais',
    'Ajustes finais',
    'Finalizado',
    'Arquivado',
    'Não Fechou',
    'Venda Docusign',
    'Obra Finalizada',
    'Contrato de Projeto',
    'Ajustes Finais',
    'Emissão Projeto Executivo'
);


--
-- Name: separacao_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.separacao_status AS ENUM (
    'Rascunho',
    'Pendente',
    'Em separação',
    'Pronto',
    'Enviado',
    'Cancelado',
    'finalizado',
    'separado',
    'material_solicitado'
);


--
-- Name: sinal_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.sinal_status AS ENUM (
    'pendente',
    'recebido',
    'creditado',
    'receita_servico'
);


--
-- Name: solicitacao_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.solicitacao_status AS ENUM (
    'pendente',
    'aprovada',
    'rejeitada',
    'comprada',
    'cancelada'
);


--
-- Name: status_pagamento; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.status_pagamento AS ENUM (
    'Pendente',
    'Parcialmente Pago',
    'Pago',
    'Atrasado',
    'Cancelado'
);


--
-- Name: tipo_operacao; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.tipo_operacao AS ENUM (
    'CR',
    'CP'
);


--
-- Name: tipo_projeto; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.tipo_projeto AS ENUM (
    'Residential',
    'Corporativo',
    'Exposição Comercial',
    'Paisagismo'
);


--
-- Name: transacao_tipo; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.transacao_tipo AS ENUM (
    'receita',
    'despesa',
    'transferencia'
);


--
-- Name: usuario_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.usuario_role AS ENUM (
    'admin',
    'gerente',
    'operador',
    'funcionario',
    'viewer'
);


--
-- Name: _lucenera_parse_prazo_pagamento(text, integer[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public._lucenera_parse_prazo_pagamento(p_condicoes_pagamento text, p_prazo_pagamento_dias integer[]) RETURNS integer[]
    LANGUAGE plpgsql IMMUTABLE
    AS $$
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
$$;


--
-- Name: admin_update_user_password(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_update_user_password(p_user_id uuid, p_new_password text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
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
$$;


--
-- Name: admin_update_user_role(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_update_user_role(p_user_id uuid, p_role text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: admin_update_user_status(uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_update_user_status(p_user_id uuid, p_ativo boolean) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: aprovar_orcamento_financeiro(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aprovar_orcamento_financeiro(p_orcamento_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_result jsonb;
BEGIN
  v_result := public.aprovar_orcamento_financeiro_base_spec001(p_orcamento_id);

  RETURN coalesce(v_result, '{}'::jsonb)
    || jsonb_build_object('financeiro_usa_orcamento_id', true);
END;
$$;


--
-- Name: aprovar_orcamento_financeiro_base_spec001(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aprovar_orcamento_financeiro_base_spec001(p_orcamento_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: criar_usuario(text, text, text, public.usuario_role); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.criar_usuario(p_email text, p_password text, p_nome text, p_role public.usuario_role DEFAULT 'viewer'::public.usuario_role) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
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
$$;


--
-- Name: fn_atualiza_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_atualiza_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


--
-- Name: fn_atualizar_preco_venda(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_atualizar_preco_venda() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: fn_auto_numero_orcamento(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_auto_numero_orcamento() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.numero_orcamento IS NULL OR NEW.numero_orcamento = '' THEN
        NEW.numero_orcamento := fn_gerar_numero_orcamento();
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: fn_gerar_numero_orcamento(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_gerar_numero_orcamento() RETURNS text
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: fn_log_auditoria(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_log_auditoria() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


--
-- Name: fn_update_orcamento_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_update_orcamento_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: generate_product_slug(text, numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_product_slug(nome text, preco numeric) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
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
$$;


--
-- Name: gerenciar_fluxo_projeto(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.gerenciar_fluxo_projeto() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_item RECORD;
    v_estoque_disponivel NUMERIC;
    v_faltante NUMERIC;
    v_acao VARCHAR(20);
    v_usuario VARCHAR(100);
BEGIN
    -- Apenas processa quando o status efetivamente muda
    IF TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
        IF NEW.status = 'Aprovado' THEN
            v_acao := 'APROVACAO';
            v_usuario := NEW.aprovado_por;

            -- Percorre os itens do orçamento original
            FOR v_item IN
                SELECT oi.id, oi.item_id, oi.quantidade, oi.orcamento_id
                FROM orcamento_itens oi
                JOIN orcamentos o ON o.id = oi.orcamento_id
                WHERE o.projeto_id = NEW.id
            LOOP
                -- Insere o item em projeto_itens
                INSERT INTO projeto_itens (projeto_id, item_id, quantidade, orcamento_item_id)
                VALUES (NEW.id, v_item.item_id, v_item.quantidade, v_item.id);

                -- Calcula o estoque disponível (exemplo: quantidade atual - reservada)
                SELECT COALESCE(quantidade, 0) - COALESCE(quantidade_reservada, 0)
                INTO v_estoque_disponivel
                FROM estoque_itens
                WHERE id = v_item.item_id;

                IF v_estoque_disponivel >= v_item.quantidade THEN
                    -- Incrementa a quantidade reservada
                    UPDATE estoque_itens
                    SET quantidade_reservada = COALESCE(quantidade_reservada, 0) + v_item.quantidade
                    WHERE id = v_item.item_id;
                ELSE
                    -- Reserva o que é possível
                    IF v_estoque_disponivel > 0 THEN
                        UPDATE estoque_itens
                        SET quantidade_reservada = COALESCE(quantidade_reservada, 0) + v_estoque_disponivel
                        WHERE id = v_item.item_id;

                        v_faltante := v_item.quantidade - v_estoque_disponivel;
                    ELSE
                        v_faltante := v_item.quantidade;
                    END IF;

                    -- Insere solicitação de compra para o faltante
                    INSERT INTO solicitacoes_compra (projeto_id, item_id, quantidade, status, data_solicitacao)
                    VALUES (NEW.id, v_item.item_id, v_faltante, 'Pendente', NOW());
                END IF;
            END LOOP;

        ELSIF NEW.status = 'Estornado' THEN
            v_acao := 'ESTORNO';
            v_usuario := NEW.estornado_por;

            -- Percorre os itens do projeto
            FOR v_item IN
                SELECT id, item_id, quantidade
                FROM projeto_itens
                WHERE projeto_id = NEW.id
            LOOP
                -- Decrementa a quantidade reservada em estoque_itens
                UPDATE estoque_itens
                SET quantidade_reservada = GREATEST(COALESCE(quantidade_reservada, 0) - v_item.quantidade, 0)
                WHERE id = v_item.item_id;
            END LOOP;

            -- Cancela solicitações de compra pendentes do projeto
            UPDATE solicitacoes_compra
            SET status = 'Cancelado', data_cancelamento = NOW()
            WHERE projeto_id = NEW.id AND status = 'Pendente';
        END IF;

        -- Registra log da operação, se houver uma ação identificada
        IF v_acao IS NOT NULL THEN
            INSERT INTO logs_operacoes (projeto_id, acao, usuario, data_hora)
            VALUES (NEW.id, v_acao, v_usuario, NOW());
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: projetos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projetos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    codigo character varying(50) NOT NULL,
    nome text NOT NULL,
    nivel_estrategico public.projeto_nivel,
    status public.projeto_status DEFAULT 'Estudo Inicial'::public.projeto_status,
    cidade character varying(100),
    estado character varying(2),
    data_entrada date,
    arquivado boolean DEFAULT false,
    cliente_id uuid,
    arquiteto_id uuid,
    responsavel_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    historico jsonb DEFAULT '[]'::jsonb NOT NULL,
    responsavel_nome text,
    created_by uuid,
    responsavel_obra_id uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    client_id uuid,
    area_do_projeto jsonb,
    "Nome Arquiteto" text,
    codigo_legado integer,
    empresa_id uuid,
    valor_total numeric(15,2) DEFAULT 0 NOT NULL,
    CONSTRAINT check_area_projeto_estrutura CHECK (((area_do_projeto IS NULL) OR (jsonb_typeof(area_do_projeto) = 'object'::text))),
    CONSTRAINT check_tipo_projeto_valido CHECK (((area_do_projeto IS NULL) OR ((area_do_projeto ->> 'tipo'::text) IS NULL) OR ((area_do_projeto ->> 'tipo'::text) = ANY (ARRAY['Residential'::text, 'Corporativo'::text, 'Exposição Comercial'::text, 'Paisagismo'::text])))),
    CONSTRAINT chk_historico_is_array CHECK ((jsonb_typeof(historico) = 'array'::text))
);


--
-- Name: COLUMN projetos.historico; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.projetos.historico IS 'Array JSON. Cada entrada: {"campo":"status","valor_anterior":"...","valor_novo":"...","alterado_em":"ISO8601","alterado_por":"uuid","sistema_origem":"crm|sharepoint|rh"}';


--
-- Name: COLUMN projetos.client_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.projetos.client_id IS 'ID do cliente (FK para contatos onde tipo=cliente). Identifica o cliente responsável pelo projeto.';


--
-- Name: COLUMN projetos.area_do_projeto; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.projetos.area_do_projeto IS 'Dados estruturados sobre área e tipo do projeto em formato JSONB.
Estrutura sugerida:
{
  "metragem": 150.5,
  "unidade": "m2",
  "tipo": "Residential" | "Corporativo" | "Exposição Comercial" | "Paisagismo",
  "descricao": "Descrição adicional"
}';


--
-- Name: COLUMN projetos.empresa_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.projetos.empresa_id IS 'Empresa dona do projeto (LUCE NERA, ISLIGHT ou FOCO)';


--
-- Name: COLUMN projetos.valor_total; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.projetos.valor_total IS 'Valor total denormalizado do projeto, sincronizado por public.sync_projeto_valor_total() a partir de public.projeto_itens.';


--
-- Name: CONSTRAINT check_tipo_projeto_valido ON projetos; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON CONSTRAINT check_tipo_projeto_valido ON public.projetos IS 'Garante que o tipo de projeto no JSONB seja um dos 4 valores permitidos: Residential, Corporativo, Exposição Comercial ou Paisagismo';


--
-- Name: get_dashboard_crm_by_closing(date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_dashboard_crm_by_closing(data_inicial date, data_final date) RETURNS SETOF public.projetos
    LANGUAGE sql STABLE
    AS $$
SELECT * FROM public.projetos p
WHERE EXISTS (
  SELECT 1 FROM public.projeto_parcelas pp
  WHERE pp.projeto_id = p.id
    AND pp.data_fechamento BETWEEN data_inicial AND data_final
);
$$;


--
-- Name: FUNCTION get_dashboard_crm_by_closing(data_inicial date, data_final date); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_dashboard_crm_by_closing(data_inicial date, data_final date) IS 'Retorna projetos que possuem parcelas fechadas no intervalo de datas especificado, resolvendo o problema de filtragem por ano de fechamento.';


--
-- Name: get_dashboard_kpi(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_dashboard_kpi(p_date_now date) RETURNS json
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: get_dashboard_stats(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_dashboard_stats() RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: get_faltas_injustificadas(uuid, date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_faltas_injustificadas(p_funcionario_id uuid, p_inicio date, p_fim date) RETURNS integer
    LANGUAGE plpgsql STABLE
    AS $$
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
$$;


--
-- Name: get_latest_transaction_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_latest_transaction_id() RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  -- Deterministic sort order matching the service layer
  RETURN (SELECT id FROM public.transactions ORDER BY created_at DESC, id DESC LIMIT 1);
END;
$$;


--
-- Name: get_next_sku(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_next_sku(prefix text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


--
-- Name: get_user_role(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_user_role() RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN (SELECT role FROM public.profiles WHERE id = auth.uid());
END;
$$;


--
-- Name: get_vendedores(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_vendedores() RETURNS TABLE(id uuid, email character varying, name text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY SELECT u.id, u.email, (u.raw_user_meta_data->>'name')::TEXT as name FROM auth.users u;
END;
$$;


--
-- Name: handle_contato_tipo(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_contato_tipo() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.tipo IS NOT NULL THEN
    INSERT INTO public.contato_tipos (contato_id, tipo)
    VALUES (NEW.id, NEW.tipo)
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: handle_new_auth_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_new_auth_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


--
-- Name: handle_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;


--
-- Name: is_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_admin() RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_role public.usuario_role;
BEGIN
  SELECT role INTO v_role FROM public.usuarios WHERE id = auth.uid();
  RETURN v_role = 'admin'::public.usuario_role;
END;
$$;


--
-- Name: is_ubiqua_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_ubiqua_admin() RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.usuarios_ubiqua
    WHERE id = auth.uid() AND nivel_acesso = 'admin'
  );
END;
$$;


--
-- Name: limpar_staging_processados(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.limpar_staging_processados() RETURNS integer
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: FUNCTION limpar_staging_processados(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.limpar_staging_processados() IS 'Remove registros staging processados há mais de 30 dias';


--
-- Name: propagate_contato_nome(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.propagate_contato_nome() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: propagate_projeto_codigo(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.propagate_projeto_codigo() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: propagate_usuario_nome(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.propagate_usuario_nome() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: set_orcamento_numero(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_orcamento_numero() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
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
$_$;


--
-- Name: set_projeto_itens_descricao(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_projeto_itens_descricao() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


--
-- Name: stats_datacenter(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.stats_datacenter() RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: sync_projeto_valor_total(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_projeto_valor_total() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: sync_responsavel_nome(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_responsavel_nome() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
BEGIN
  IF NEW.responsavel_id IS NOT NULL THEN
    SELECT nome INTO NEW.responsavel_nome
    FROM public.usuarios WHERE id = NEW.responsavel_id;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: sync_separacao_cliente(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_separacao_cliente() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
BEGIN
  IF NEW.cliente_id IS NOT NULL THEN
    SELECT nome INTO NEW.cliente
    FROM public.contatos
    WHERE id = NEW.cliente_id;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: sync_separacao_codigo_obra(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_separacao_codigo_obra() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
BEGIN
  IF NEW.projeto_id IS NOT NULL THEN
    SELECT codigo INTO NEW.codigo_obra
    FROM public.projetos
    WHERE id = NEW.projeto_id;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: track_reagendamento(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.track_reagendamento() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: trigger_fechar_projeto(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_fechar_projeto() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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

    -- 3b. Zerar a reserva desse projeto
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
    --     (só cria se ainda não existe separação para esse projeto)
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
$$;


--
-- Name: trigger_proteger_fechamento(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_proteger_fechamento() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: trigger_proteger_parcelas(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_proteger_parcelas() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: trigger_reserva_estoque(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_reserva_estoque() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  -- Só age quando status MUDA para 'Proposta Sinal'
  IF NEW.status = 'Proposta Sinal'::public.projeto_status AND OLD.status <> 'Proposta Sinal'::public.projeto_status THEN

    -- Inserir ou somar na reserva de estoque para cada item do projeto
    INSERT INTO estoque_itens (produto_id, local, quantidade, atualizado_por, atualizado_em)
    SELECT
      pi.produto_id,
      'Reservado'::public.estoque_local,
      pi.quantidade,
      NEW.created_by,
      NOW()
    FROM projeto_itens pi
    WHERE pi.projeto_id = NEW.id
      AND pi.produto_id IS NOT NULL
    ON CONFLICT (produto_id, local)
    DO UPDATE SET
      quantidade    = estoque_itens.quantidade + EXCLUDED.quantidade,
      atualizado_em = NOW();

  END IF;

  -- Ao SAIR de 'Proposta Sinal' para trás (ex: cancelamento),
  -- liberar a reserva
  IF OLD.status = 'Proposta Sinal'::public.projeto_status
     AND NEW.status NOT IN ('Proposta Sinal'::public.projeto_status,'Elaboração Orçamento'::public.projeto_status,
                             'Informações necessárias'::public.projeto_status,'Projeto executivo'::public.projeto_status,
                             'Entrega materiais'::public.projeto_status,'Ajustes finais'::public.projeto_status,'Finalizado'::public.projeto_status) THEN

    UPDATE estoque_itens ei
    SET quantidade = GREATEST(0, ei.quantidade - pi.quantidade),
        atualizado_em = NOW()
    FROM projeto_itens pi
    WHERE pi.projeto_id = NEW.id
      AND pi.produto_id = ei.produto_id
      AND ei.local = 'Reservado'::public.estoque_local;

  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: trigger_separacao_pronta(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_separacao_pronta() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: trigger_update_revenda_ubiqua_slug(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_update_revenda_ubiqua_slug() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.slug := public.generate_product_slug(COALESCE(NEW.desc_produto, NEW.descricao), NEW.valor_revenda);
  RETURN NEW;
END;
$$;


--
-- Name: update_revenda_ubiqua_ordem(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_revenda_ubiqua_ordem(payload jsonb) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


--
-- Name: update_revenda_ubiqua_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_revenda_ubiqua_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: boletos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.boletos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nosso_numero text NOT NULL,
    nome_pagador text,
    valor numeric,
    vencimento date,
    data_pagamento date,
    valor_pago numeric,
    status text DEFAULT 'Pendente'::text NOT NULL,
    empresa_id uuid,
    numero_documento text,
    tipo text DEFAULT 'Normal'::text,
    parcela_id uuid,
    tipo_operacao text DEFAULT 'CR'::text,
    num_parcela integer DEFAULT 1,
    total_parcelas integer DEFAULT 1,
    venda text,
    fatura text,
    emissao date DEFAULT CURRENT_DATE,
    comprovante_url text,
    orcamento_id uuid
);


--
-- Name: categorias_financeiras; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categorias_financeiras (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nome text NOT NULL,
    tipo public.transacao_tipo NOT NULL,
    grupo text NOT NULL,
    icone text,
    ativo boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT categorias_financeiras_grupo_check CHECK ((grupo = ANY (ARRAY['fixo'::text, 'variavel'::text, 'investimento'::text, 'transferencia'::text])))
);


--
-- Name: categorias_produto; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categorias_produto (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    codigo_connect integer NOT NULL,
    nome text NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: contas_bancarias; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contas_bancarias (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nome text NOT NULL,
    tipo public.conta_tipo NOT NULL,
    saldo numeric(15,2) DEFAULT 0 NOT NULL,
    banco text,
    agencia character varying(10),
    conta character varying(20),
    status text DEFAULT 'Ativa'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    empresa_id uuid,
    codigo_connect integer,
    nome_connect text,
    CONSTRAINT contas_bancarias_status_check CHECK ((status = ANY (ARRAY['Ativa'::text, 'Encerrada'::text])))
);


--
-- Name: contato_origens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contato_origens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    contato_id uuid NOT NULL,
    origem text NOT NULL,
    codigo_legado integer NOT NULL,
    CONSTRAINT contato_origens_origem_check CHECK ((origem = ANY (ARRAY['CRM_CLIENTE'::text, 'CRM_ARQUITETO'::text, 'CONNECT_CR'::text, 'CONNECT_CP'::text, 'FORNECEDOR'::text])))
);


--
-- Name: contato_tipos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contato_tipos (
    contato_id uuid NOT NULL,
    tipo text NOT NULL,
    CONSTRAINT contato_tipos_tipo_check CHECK ((tipo = ANY (ARRAY['cliente'::text, 'arquiteto'::text, 'engenheiro'::text, 'fornecedor'::text, 'funcionario'::text, 'outro'::text])))
);


--
-- Name: contatos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contatos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    codigo_legado bigint,
    tipo public.contato_tipo NOT NULL,
    nome text NOT NULL,
    nome_empresa text,
    cpf_cnpj character varying(18),
    rg character varying(20),
    email character varying(255),
    email_financeiro character varying(255),
    telefone character varying(20),
    celular character varying(20),
    endereco text,
    bairro character varying(100),
    cep character varying(10),
    cidade character varying(100),
    estado character varying(2),
    data_nascimento date,
    observacoes text,
    ativo boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    created_by uuid,
    endereco_comercial text,
    bairro_comercial character varying(100),
    cep_comercial character varying(10),
    cidade_comercial character varying(100),
    estado_comercial character varying(2),
    especialidade text,
    updated_at timestamp with time zone,
    canonical_id uuid,
    tipo_pessoa character varying(10),
    cpf character varying(14),
    cnpj character varying(18),
    empresa_id uuid,
    nao_residente boolean DEFAULT false NOT NULL,
    razao_social text,
    inscricao_estadual text,
    inscricao_municipal text,
    limite_credito numeric,
    regime_apuracao text,
    email_alternativo text,
    vendedor_id uuid,
    numero text,
    cep_entrega text,
    endereco_entrega text,
    numero_entrega text,
    bairro_entrega text,
    cidade_entrega text,
    estado_entrega text,
    cep_cobranca text,
    endereco_cobranca text,
    numero_cobranca text,
    bairro_cobranca text,
    cidade_cobranca text,
    estado_cobranca text,
    vendedor_padrao_id uuid,
    status_comercial text DEFAULT 'Ativo'::text,
    CONSTRAINT contatos_tipo_pessoa_check CHECK (((tipo_pessoa)::text = ANY ((ARRAY['fisica'::character varying, 'juridica'::character varying])::text[])))
);


--
-- Name: contatos_revisao; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contatos_revisao (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    id_a uuid NOT NULL,
    id_b uuid NOT NULL,
    score numeric(5,4) NOT NULL,
    decisao text DEFAULT 'pendente'::text NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    revisado_em timestamp with time zone,
    CONSTRAINT contatos_revisao_check CHECK ((id_a < id_b)),
    CONSTRAINT contatos_revisao_decisao_check CHECK ((decisao = ANY (ARRAY['pendente'::text, 'merge'::text, 'manter'::text])))
);


--
-- Name: controle_falta; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.controle_falta (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    funcionario_id uuid NOT NULL,
    data date NOT NULL,
    hora_entrada time without time zone,
    hora_saida time without time zone,
    total_horas numeric(4,2),
    status text,
    justificativa text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT controle_ponto_status_check CHECK ((status = ANY (ARRAY['presente'::text, 'ausente'::text, 'atraso'::text, 'meio_periodo'::text, 'atestado'::text, 'licenca_maternidade'::text, 'falta_injustificada'::text, 'licenca_paternidade'::text, 'licenca_obito'::text, 'licenca_casamento'::text, 'licenca_militar'::text, 'licenca_medica'::text])))
);


--
-- Name: custos_recorrentes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.custos_recorrentes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    categoria_id uuid,
    conta_id uuid,
    descricao text NOT NULL,
    valor numeric(15,2) NOT NULL,
    dia_vencimento integer,
    frequencia public.frequencia_tipo DEFAULT 'mensal'::public.frequencia_tipo NOT NULL,
    data_inicio date NOT NULL,
    data_fim date,
    ativo boolean DEFAULT true NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT custos_recorrentes_dia_vencimento_check CHECK (((dia_vencimento >= 1) AND (dia_vencimento <= 31))),
    CONSTRAINT custos_recorrentes_valor_check CHECK ((valor > (0)::numeric))
);


--
-- Name: custos_recorrentes_lancamentos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.custos_recorrentes_lancamentos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    custo_id uuid NOT NULL,
    competencia date NOT NULL,
    data_vencimento date NOT NULL,
    data_pagamento date,
    valor_original numeric(15,2) NOT NULL,
    valor_pago numeric(15,2),
    juros numeric(15,2) DEFAULT 0 NOT NULL,
    multa numeric(15,2) DEFAULT 0 NOT NULL,
    desconto numeric(15,2) DEFAULT 0 NOT NULL,
    status public.lancamento_status DEFAULT 'pendente'::public.lancamento_status NOT NULL,
    transacao_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT custos_recorrentes_lancamentos_desconto_check CHECK ((desconto >= (0)::numeric)),
    CONSTRAINT custos_recorrentes_lancamentos_juros_check CHECK ((juros >= (0)::numeric)),
    CONSTRAINT custos_recorrentes_lancamentos_multa_check CHECK ((multa >= (0)::numeric)),
    CONSTRAINT custos_recorrentes_lancamentos_valor_pago_check CHECK ((valor_pago >= (0)::numeric))
);


--
-- Name: departamentos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.departamentos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nome text NOT NULL,
    descricao text,
    ativo boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: empresa_ubiqua; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.empresa_ubiqua (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nome_fantasia text NOT NULL,
    razao_social text,
    cnpj text NOT NULL,
    cidade text NOT NULL,
    estado text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: empresas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.empresas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    codigo integer NOT NULL,
    nome text NOT NULL,
    razao_social text,
    cnpj character varying(18),
    cidade text DEFAULT 'Ribeirão Preto'::text NOT NULL,
    estado character varying(2) DEFAULT 'SP'::character varying NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    inscricao_estadual text,
    logradouro text,
    numero text,
    complemento text,
    bairro text,
    cep text,
    cor_hex text,
    regime_tributario text
);


--
-- Name: COLUMN empresas.inscricao_estadual; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.empresas.inscricao_estadual IS 'Inscrição Estadual da empresa';


--
-- Name: COLUMN empresas.logradouro; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.empresas.logradouro IS 'Logradouro (rua, avenida, etc.)';


--
-- Name: COLUMN empresas.numero; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.empresas.numero IS 'Número do imóvel';


--
-- Name: COLUMN empresas.complemento; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.empresas.complemento IS 'Complemento do endereço (apt, bloco, etc.)';


--
-- Name: COLUMN empresas.bairro; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.empresas.bairro IS 'Bairro';


--
-- Name: COLUMN empresas.cep; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.empresas.cep IS 'CEP da empresa';


--
-- Name: COLUMN empresas.cor_hex; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.empresas.cor_hex IS 'Cor principal da empresa em formato HEX (ex: #FF0000)';


--
-- Name: COLUMN empresas.regime_tributario; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.empresas.regime_tributario IS 'Regime tributário da empresa (ex: Simples Nacional, Lucro Presumido, Lucro Real)';


--
-- Name: entregas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entregas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    separacao_id uuid,
    projeto_id uuid,
    entregador_id uuid,
    endereco_entrega text,
    contato_destino text,
    delivery_type text DEFAULT 'flexible'::text NOT NULL,
    scheduled_time time without time zone,
    data_prevista date,
    data_entrega date,
    status public.entrega_status DEFAULT 'Pendente'::public.entrega_status NOT NULL,
    comprovante_url text,
    avaliacao integer,
    observacoes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT entregas_avaliacao_check CHECK (((avaliacao >= 1) AND (avaliacao <= 5))),
    CONSTRAINT entregas_delivery_type_check CHECK ((delivery_type = ANY (ARRAY['scheduled'::text, 'flexible'::text])))
);


--
-- Name: entregas_finalizadas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entregas_finalizadas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    separacao_id text,
    cliente text,
    codigo_obra text,
    data_entrega_real timestamp with time zone,
    endereco text,
    recebido_por text,
    telefone text,
    material_tipo text,
    material_conteudo text,
    fotos_urls text,
    observacoes text,
    created_at timestamp with time zone DEFAULT now(),
    numero_pedido text,
    vendedor text,
    observacoes_internas text,
    gestora_equipe text,
    numero_entrega text,
    data_solicitacao timestamp with time zone
);


--
-- Name: estoque_itens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.estoque_itens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    produto_id uuid NOT NULL,
    local public.estoque_local DEFAULT 'Estoque'::public.estoque_local NOT NULL,
    quantidade numeric(10,2) DEFAULT 0 NOT NULL,
    atualizado_por uuid,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    quantidade_reservada numeric(10,2) DEFAULT 0 NOT NULL
);


--
-- Name: COLUMN estoque_itens.quantidade_reservada; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.estoque_itens.quantidade_reservada IS 'Quantidade comprometida com projetos aprovados, mas ainda presente fisicamente no local.';


--
-- Name: ferias; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ferias (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    funcionario_id uuid NOT NULL,
    data_inicio date NOT NULL,
    data_fim date NOT NULL,
    dias integer GENERATED ALWAYS AS (((data_fim - data_inicio) + 1)) STORED NOT NULL,
    status text DEFAULT 'Pendente'::text NOT NULL,
    aprovado_por uuid,
    observacoes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    periodo_aquisitivo_id uuid NOT NULL,
    CONSTRAINT ferias_status_check CHECK ((status = ANY (ARRAY['Pendente'::text, 'Aprovado'::text, 'Rejeitado'::text, 'Cancelado'::text])))
);


--
-- Name: folha_pagamento; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.folha_pagamento (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    funcionario_id uuid NOT NULL,
    mes integer NOT NULL,
    ano integer NOT NULL,
    salario_base numeric(12,2) NOT NULL,
    descontos numeric(12,2) DEFAULT 0 NOT NULL,
    adicionais numeric(12,2) DEFAULT 0 NOT NULL,
    salario_liquido numeric(12,2) NOT NULL,
    data_geracao timestamp with time zone DEFAULT now() NOT NULL,
    comissao numeric DEFAULT 0 NOT NULL,
    dias_trabalhados integer DEFAULT 0,
    dias_abonados integer DEFAULT 0,
    dias_falta integer DEFAULT 0,
    valor_vr_vt numeric DEFAULT 0,
    empresa_id uuid,
    CONSTRAINT folha_pagamento_mes_check CHECK (((mes >= 1) AND (mes <= 12)))
);


--
-- Name: fornecedores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fornecedores (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    empresa_id uuid,
    nome text NOT NULL,
    cnpj_cpf text,
    email text,
    telefone text,
    endereco text,
    cidade text,
    estado text,
    cep text,
    banco text,
    agencia text,
    conta text,
    chave_pix text,
    categoria text,
    status text DEFAULT 'ativo'::text,
    observacoes text,
    user_id uuid DEFAULT auth.uid()
);

ALTER TABLE ONLY public.fornecedores FORCE ROW LEVEL SECURITY;


--
-- Name: TABLE fornecedores; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.fornecedores IS 'Cadastro de fornecedores/pagadores do ERP Financeiro';


--
-- Name: funcionarios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.funcionarios (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    usuario_id uuid,
    departamento_id uuid,
    nome text NOT NULL,
    cargo text,
    data_admissao date,
    data_demissao date,
    status text DEFAULT 'Ativo'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    empresa text,
    tipo_contratacao text,
    data_elegibilidade_ferias date,
    empresa_id uuid,
    codigo_legado integer,
    nm_connect text,
    CONSTRAINT funcionarios_status_check CHECK ((status = ANY (ARRAY['Ativo'::text, 'Inativo'::text, 'Afastado'::text, 'Ferias'::text]))),
    CONSTRAINT funcionarios_tipo_contratacao_check CHECK ((tipo_contratacao = ANY (ARRAY['CLT'::text, 'PJ'::text])))
);


--
-- Name: funcionarios_beneficios_empresas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.funcionarios_beneficios_empresas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    funcionario_id uuid NOT NULL,
    empresa character varying(100) NOT NULL,
    valor_vt_dia numeric(10,2) DEFAULT 0
);


--
-- Name: funcionarios_detalhes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.funcionarios_detalhes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    funcionario_id uuid NOT NULL,
    cpf character varying(14),
    rg character varying(20),
    data_nascimento date,
    endereco text,
    telefone character varying(20),
    email character varying(255)
);


--
-- Name: funcionarios_financeiro; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.funcionarios_financeiro (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    funcionario_id uuid NOT NULL,
    salario_base numeric(12,2) DEFAULT 0 NOT NULL,
    salario_por_fora numeric(12,2) DEFAULT 0 NOT NULL,
    comissao_percentual numeric(5,2) DEFAULT 0,
    salario_liquido numeric(12,2) GENERATED ALWAYS AS ((salario_base + salario_por_fora)) STORED
);


--
-- Name: funcionarios_novo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.funcionarios_novo (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nome character varying(255) NOT NULL,
    cargo character varying(100),
    data_admissao date,
    ativo boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: historico_status_orcamento; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.historico_status_orcamento (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    orcamento_id uuid NOT NULL,
    status_anterior text,
    status_novo text NOT NULL,
    usuario text,
    observacao text,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: historico_status_orcamentos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.historico_status_orcamentos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    orcamento_id uuid NOT NULL,
    status_anterior text,
    status_novo text NOT NULL,
    usuario text,
    observacao text,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: informacoes_cliente_ubiqua; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.informacoes_cliente_ubiqua (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nome text NOT NULL,
    email text,
    telefone text,
    created_at timestamp with time zone DEFAULT now(),
    cpf_cnpj text NOT NULL
);


--
-- Name: itens_orcamento_ubiqua; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.itens_orcamento_ubiqua (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    orcamento_id uuid NOT NULL,
    produto_id integer NOT NULL,
    quantidade integer NOT NULL,
    valor_unitario numeric(12,2) NOT NULL,
    desconto_item numeric(12,2) DEFAULT 0,
    observacao_item text,
    referencia_snapshot text,
    descricao_snapshot text,
    marca_snapshot text,
    created_at timestamp with time zone DEFAULT now(),
    ordem integer DEFAULT 0,
    valor_total numeric GENERATED ALWAYS AS ((((quantidade)::numeric * valor_unitario) - COALESCE(desconto_item, (0)::numeric))) STORED,
    CONSTRAINT itens_orcamento_ubiqua_desconto_item_check CHECK ((desconto_item >= (0)::numeric)),
    CONSTRAINT itens_orcamento_ubiqua_quantidade_check CHECK ((quantidade > 0)),
    CONSTRAINT itens_orcamento_ubiqua_valor_unitario_check CHECK ((valor_unitario >= (0)::numeric))
);


--
-- Name: logs_auditoria; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.logs_auditoria (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    tabela text NOT NULL,
    operacao text NOT NULL,
    registro_id uuid,
    usuario_id uuid DEFAULT auth.uid(),
    dados_anteriores jsonb,
    dados_novos jsonb,
    ip text,
    observacao text
);

ALTER TABLE ONLY public.logs_auditoria FORCE ROW LEVEL SECURITY;


--
-- Name: TABLE logs_auditoria; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.logs_auditoria IS 'Log de auditoria das principais operações do ERP Financeiro';


--
-- Name: logs_operacoes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.logs_operacoes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    projeto_id uuid,
    usuario_id uuid,
    acao text NOT NULL,
    dados_anteriores jsonb,
    dados_novos jsonb,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: marcas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.marcas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nome text NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    codigo_legado integer
);


--
-- Name: negociacoes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.negociacoes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    empresa_id uuid NOT NULL,
    contato_id uuid,
    funcionario_id uuid,
    plano_contas_id uuid,
    projeto_id uuid,
    tipo public.transacao_tipo NOT NULL,
    cod_duplicata integer NOT NULL,
    cod_venda integer,
    total_parc smallint DEFAULT 1 NOT NULL,
    dev_troca boolean DEFAULT false NOT NULL,
    observacao text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    cod_pessoa integer
);


--
-- Name: notas_fiscais; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notas_fiscais (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    numero_nf text NOT NULL,
    serie text,
    data_emissao date,
    valor numeric,
    arquivo_url text,
    fornecedor text,
    arquiteto text,
    boleto_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    orcamento_id uuid
);


--
-- Name: orcamento_itens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orcamento_itens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    orcamento_id uuid NOT NULL,
    produto_id uuid,
    quantidade numeric(10,3) DEFAULT 1,
    preco_unitario numeric(12,2),
    desconto numeric(12,2) DEFAULT 0,
    item_pai_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    custom_id text,
    descricao text
);


--
-- Name: COLUMN orcamento_itens.item_pai_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.orcamento_itens.item_pai_id IS 'HIERARQUIA: Permite vincular um acessório (ex: Hood) a uma luminária principal, mantendo a organização do projeto.';


--
-- Name: orcamentos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orcamentos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    empresa_id uuid NOT NULL,
    cliente_id uuid,
    arquiteto_id uuid,
    vendedor_id uuid,
    status text DEFAULT 'aguardando_aprovacao'::text,
    data_emissao timestamp with time zone DEFAULT now(),
    validade date,
    valor_total numeric(12,2) DEFAULT 0,
    created_at timestamp with time zone DEFAULT now(),
    numero text,
    observacoes text,
    condicoes_pagamento text,
    desconto_global numeric DEFAULT 0,
    forma_pagamento public.pagamento_forma,
    informacoes_cliente_id uuid,
    projeto_id uuid,
    frete_tipo text,
    frete_valor numeric(12,2) DEFAULT 0,
    prazo_pagamento_dias integer[],
    data_base_vencimento text DEFAULT 'aprovacao'::text,
    prazo_inicio_cobranca_dias integer,
    CONSTRAINT orcamentos_frete_coerencia_check CHECK (((frete_tipo IS NULL) OR ((frete_tipo = 'sem_frete'::text) AND (COALESCE(frete_valor, (0)::numeric) = (0)::numeric)) OR ((frete_tipo = 'com_frete'::text) AND (frete_valor > (0)::numeric)))),
    CONSTRAINT orcamentos_frete_tipo_check CHECK (((frete_tipo IS NULL) OR (frete_tipo = ANY (ARRAY['com_frete'::text, 'sem_frete'::text])))),
    CONSTRAINT orcamentos_prazo_inicio_cobranca_dias_check CHECK (((prazo_inicio_cobranca_dias IS NULL) OR (prazo_inicio_cobranca_dias >= 0)))
);


--
-- Name: COLUMN orcamentos.empresa_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.orcamentos.empresa_id IS 'ÂNCORA: Define se a venda é Foco, Manoella ou Islight. Todo o fluxo financeiro e de estoque herdará este ID.';


--
-- Name: orcamentos_revenda_ubiqua; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orcamentos_revenda_ubiqua (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    cliente_id uuid NOT NULL,
    numero_orcamento text NOT NULL,
    status text DEFAULT 'rascunho'::text NOT NULL,
    data_validade date DEFAULT (CURRENT_DATE + '30 days'::interval) NOT NULL,
    desconto_percentual numeric(5,2) DEFAULT 0,
    valor_subtotal numeric(12,2) DEFAULT 0 NOT NULL,
    valor_desconto numeric(12,2) DEFAULT 0 NOT NULL,
    valor_total numeric(12,2) DEFAULT 0 NOT NULL,
    observacoes text,
    condicoes_pagamento text,
    prazo_entrega text,
    enviado_em timestamp with time zone,
    aprovado_em timestamp with time zone,
    aprovado_por text,
    rejeitado_em timestamp with time zone,
    motivo_rejeicao text,
    cancelado_em timestamp with time zone,
    motivo_cancelamento text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    created_by text,
    updated_by text,
    versao integer DEFAULT 1,
    CONSTRAINT orcamentos_revenda_ubiqua_desconto_percentual_check CHECK (((desconto_percentual >= (0)::numeric) AND (desconto_percentual <= (100)::numeric)))
);


--
-- Name: pedido_compra; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pedido_compra (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    codigo_pedido integer NOT NULL,
    cod_fornecedor integer NOT NULL,
    nome_fornecedor text NOT NULL,
    valor_nota numeric(15,2) DEFAULT 0 NOT NULL,
    valor_duplicata numeric(15,2) DEFAULT 0,
    numero_parcela integer,
    data_emissao date NOT NULL,
    data_vencimento date,
    status text DEFAULT 'Pendente'::text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: periodos_aquisitivos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.periodos_aquisitivos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    funcionario_id uuid NOT NULL,
    data_inicio date NOT NULL,
    data_fim date NOT NULL,
    data_limite_gozo date NOT NULL,
    status text DEFAULT 'Ativo'::text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT periodos_aquisitivos_status_check CHECK ((status = ANY (ARRAY['Ativo'::text, 'Concluído'::text, 'Vencido'::text])))
);


--
-- Name: plano_de_contas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plano_de_contas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    codigo_connect bigint NOT NULL,
    nome text NOT NULL,
    nivel smallint NOT NULL,
    parent_id uuid,
    tipo text,
    ativo boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: produtos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.produtos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    marca_id uuid,
    nome text NOT NULL,
    sku text,
    categoria text,
    preco_custo numeric(12,2),
    preco_venda numeric(12,2),
    ativo boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    codigo_produto integer,
    referencia text,
    estoque_total numeric(15,3) DEFAULT 0,
    estoque_showroom integer DEFAULT 0,
    estoque_disponivel numeric(15,3) DEFAULT 0,
    unidade text DEFAULT 'UN'::text,
    custo_total numeric(15,2) DEFAULT 0,
    percentual_lucro numeric(5,2) DEFAULT 0,
    valor_venda numeric(15,2) DEFAULT 0,
    codigo_legado integer,
    categoria_id uuid,
    fornecedor_principal_id uuid,
    descricao_tecnica text,
    icms_entrada numeric(5,2) DEFAULT 0,
    ipi_entrada numeric(5,2) DEFAULT 0,
    porc_frete numeric(5,2) DEFAULT 0,
    porc_despesas numeric(5,2) DEFAULT 0,
    vl_custo_indireto numeric(12,2),
    margem_lucro numeric(8,4),
    ncm character varying(10),
    tipo_fiscal text,
    cst text,
    cest text,
    porc_bdi numeric,
    status_comercial text,
    mascara_produto text,
    porc_st numeric DEFAULT 0,
    porc_desconto numeric DEFAULT 0
);


--
-- Name: projeto_itens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projeto_itens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    projeto_id uuid NOT NULL,
    produto_id uuid,
    descricao text NOT NULL,
    quantidade numeric(10,2) NOT NULL,
    preco_unitario numeric(15,2) NOT NULL,
    desconto numeric(5,2) DEFAULT 0 NOT NULL,
    subtotal numeric(15,2) GENERATED ALWAYS AS (round(((quantidade * preco_unitario) * ((1)::numeric - (desconto / 100.0))), 2)) STORED,
    validado boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    orcamento_id uuid,
    CONSTRAINT projeto_itens_desconto_check CHECK (((desconto >= (0)::numeric) AND (desconto <= (100)::numeric))),
    CONSTRAINT projeto_itens_preco_unitario_check CHECK ((preco_unitario >= (0)::numeric)),
    CONSTRAINT projeto_itens_quantidade_check CHECK ((quantidade > (0)::numeric))
);


--
-- Name: projeto_parcelas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projeto_parcelas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    projeto_id uuid NOT NULL,
    numero_parcela integer NOT NULL,
    valor numeric(15,2) NOT NULL,
    data_fechamento date,
    created_at timestamp with time zone DEFAULT now(),
    status public.parcela_status DEFAULT 'pendente'::public.parcela_status NOT NULL,
    data_vencimento date,
    data_pagamento date,
    valor_pago numeric(15,2),
    juros numeric(15,2) DEFAULT 0 NOT NULL,
    multa numeric(15,2) DEFAULT 0 NOT NULL,
    desconto numeric(15,2) DEFAULT 0 NOT NULL,
    forma_pagamento public.pagamento_forma,
    comprovante_url text,
    observacoes text,
    transacao_id uuid,
    descricao text,
    orcamento_id uuid,
    CONSTRAINT chk_parcela_valor_positivo CHECK ((valor > (0)::numeric)),
    CONSTRAINT projeto_parcelas_desconto_check CHECK ((desconto >= (0)::numeric)),
    CONSTRAINT projeto_parcelas_juros_check CHECK ((juros >= (0)::numeric)),
    CONSTRAINT projeto_parcelas_multa_check CHECK ((multa >= (0)::numeric)),
    CONSTRAINT projeto_parcelas_valor_check CHECK ((valor > (0)::numeric)),
    CONSTRAINT projeto_parcelas_valor_pago_check CHECK ((valor_pago >= (0)::numeric))
);


--
-- Name: COLUMN projeto_parcelas.data_fechamento; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.projeto_parcelas.data_fechamento IS 'Data em que a parcela foi gerada/registrada';


--
-- Name: COLUMN projeto_parcelas.data_vencimento; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.projeto_parcelas.data_vencimento IS 'Data prevista para pagamento';


--
-- Name: COLUMN projeto_parcelas.data_pagamento; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.projeto_parcelas.data_pagamento IS 'Data em que o pagamento foi efetivado';


--
-- Name: COLUMN projeto_parcelas.transacao_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.projeto_parcelas.transacao_id IS 'FK para transacoes. Vínculo ao lançamento bancário correspondente ao pagamento desta parcela.';


--
-- Name: projeto_parcelas_backup_migration; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projeto_parcelas_backup_migration (
    id uuid,
    projeto_id uuid,
    numero_parcela integer,
    valor numeric(15,2),
    data_fechamento date,
    created_at timestamp with time zone,
    status public.parcela_status,
    data_vencimento date,
    data_pagamento date,
    valor_pago numeric(15,2),
    juros numeric(15,2),
    multa numeric(15,2),
    desconto numeric(15,2),
    forma_pagamento public.pagamento_forma,
    comprovante_url text,
    observacoes text,
    transacao_id uuid,
    descricao text
);


--
-- Name: projeto_produtos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projeto_produtos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    projeto_id uuid,
    produto_id uuid,
    quantidade numeric(15,3) DEFAULT 1 NOT NULL,
    valor_unitario numeric(15,2),
    valor_total numeric(15,2),
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: projeto_sinal; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projeto_sinal (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    projeto_id uuid NOT NULL,
    valor numeric(15,2) NOT NULL,
    data_pagamento date,
    forma_pagamento public.pagamento_forma,
    status public.sinal_status DEFAULT 'pendente'::public.sinal_status NOT NULL,
    transacao_id uuid,
    comprovante_url text,
    observacoes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT projeto_sinal_valor_check CHECK ((valor > (0)::numeric))
);


--
-- Name: projetos_fechados; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projetos_fechados (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    cod text,
    valor_fechado numeric,
    data_fechamento date,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: quote_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quote_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    quote_id uuid NOT NULL,
    acao text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: quotes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quotes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    empresa text,
    valor_total numeric DEFAULT 0 NOT NULL,
    status text DEFAULT 'aberto'::text NOT NULL,
    observacoes text,
    items jsonb DEFAULT '[]'::jsonb NOT NULL,
    data_aprovacao timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: remessas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.remessas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    empresa_id uuid,
    fornecedor_id uuid,
    descricao text NOT NULL,
    valor numeric(15,2) DEFAULT 0 NOT NULL,
    vencimento date,
    status text DEFAULT 'pendente'::text,
    linha_digitavel text,
    codigo_barras text,
    nosso_numero text,
    arquivo_remessa text,
    arquivo_retorno text,
    data_pagamento date,
    valor_pago numeric(15,2) DEFAULT 0,
    observacoes text,
    user_id uuid DEFAULT auth.uid()
);

ALTER TABLE ONLY public.remessas FORCE ROW LEVEL SECURITY;


--
-- Name: TABLE remessas; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.remessas IS 'Registro de remessas de cobrança/títulos para pagamento';


--
-- Name: retornos_processados; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.retornos_processados (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nome_arquivo text NOT NULL,
    data_upload timestamp with time zone DEFAULT now() NOT NULL,
    empresa_id uuid,
    quantidade_liquidacoes integer,
    quantidade_confirmacoes integer,
    processado boolean DEFAULT true
);


--
-- Name: revenda_ubiqua; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.revenda_ubiqua (
    id integer NOT NULL,
    referencia text NOT NULL,
    descricao text,
    valor_revenda numeric(12,2),
    cod_produto integer,
    desc_produto text,
    cod_marca integer,
    desc_marca text,
    cod_fornecedor integer,
    nm_fornecedor text,
    itens_vendidos integer DEFAULT 0,
    estoque integer DEFAULT 0,
    disponivel integer DEFAULT 0,
    vl_custo_produto numeric(12,2),
    vl_custo_indireto numeric(12,2),
    vl_venda_produto numeric(12,2),
    vl_custo_total_tabela numeric(12,2),
    imagem_catalogo_url text,
    fonte_planilha1 boolean DEFAULT false,
    fonte_planilha2 boolean DEFAULT false,
    fonte_planilha3 boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    cor text,
    empresa_id uuid,
    ordem integer DEFAULT 0,
    slug text
);


--
-- Name: TABLE revenda_ubiqua; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.revenda_ubiqua IS 'Tabela consolidada de produtos Ubiqua para revenda, com dados de 3 planilhas Excel e imagens de catálogo';


--
-- Name: COLUMN revenda_ubiqua.referencia; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.revenda_ubiqua.referencia IS 'Código de referência do produto (chave de junção entre as 3 planilhas)';


--
-- Name: COLUMN revenda_ubiqua.imagem_catalogo_url; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.revenda_ubiqua.imagem_catalogo_url IS 'URL da imagem de catálogo armazenada no Supabase Storage';


--
-- Name: revenda_ubiqua_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.revenda_ubiqua_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: revenda_ubiqua_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.revenda_ubiqua_id_seq OWNED BY public.revenda_ubiqua.id;


--
-- Name: separacao_arquivos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.separacao_arquivos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    separacao_id uuid,
    nome_arquivo text,
    tipo_arquivo text,
    url_arquivo text,
    tamanho_bytes bigint,
    ordem integer,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: separacao_itens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.separacao_itens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    separacao_id uuid NOT NULL,
    descricao text NOT NULL,
    quantidade numeric(10,2) DEFAULT 1 NOT NULL,
    unidade character varying(20),
    observacoes text,
    separado boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    produto_id uuid
);


--
-- Name: separacoes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.separacoes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    projeto_id uuid,
    responsavel_id uuid,
    status public.separacao_status DEFAULT 'Pendente'::public.separacao_status NOT NULL,
    observacoes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    endereco_entrega text,
    delivery_type text DEFAULT 'flexible'::text,
    scheduled_time time without time zone,
    data_entrega date,
    cliente text,
    codigo_obra text,
    data_entrega_original date,
    reagendamentos integer DEFAULT 0 NOT NULL,
    cliente_id uuid,
    responsavel_recebimento text,
    telefone text,
    endereco text,
    material_tipo text,
    material_conteudo jsonb,
    solicitante text,
    order_in_route boolean DEFAULT false,
    observacoes_internas text,
    gestora_equipe text,
    separacoes_parciais jsonb,
    nivel_complexidade text,
    tipo_entrega text,
    transportadora_nome text,
    codigo_rastreamento text,
    numero_venda text,
    numero_entrega text,
    data_inicio_separacao timestamp with time zone,
    tipo_pedido text,
    garantia_detalhes text,
    inclui_garantia boolean DEFAULT false,
    garantia_peca text,
    garantia_motivo text,
    CONSTRAINT separacoes_delivery_type_check CHECK ((delivery_type = ANY (ARRAY['scheduled'::text, 'flexible'::text])))
);


--
-- Name: COLUMN separacoes.cliente; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.separacoes.cliente IS 'Cache do nome do cliente. Sincronizado via trg_sync_sep_cliente e propagate_contato_nome. Editável manualmente apenas quando cliente_id for NULL.';


--
-- Name: COLUMN separacoes.codigo_obra; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.separacoes.codigo_obra IS 'Cache do projetos.codigo. Sincronizado via trg_sync_sep_codigo_obra e propagate_projeto_codigo. Editável manualmente apenas quando projeto_id for NULL.';


--
-- Name: COLUMN separacoes.cliente_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.separacoes.cliente_id IS 'FK para contatos. Quando preenchido, o campo cliente (text) é mantido em sync por trigger. NULL = separação avulsa sem vínculo de cadastro.';


--
-- Name: separacoes_arquivos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.separacoes_arquivos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    cliente text,
    codigo_obra text,
    data_entrega timestamp with time zone,
    responsavel_recebimento text,
    telefone text,
    endereco text,
    status text,
    material_tipo text,
    material_conteudo text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    solicitante text,
    delivery_type text,
    scheduled_time text,
    order_in_route text,
    observacoes_internas text,
    gestora_equipe text,
    separacoes_parciais text,
    nivel_complexidade text,
    tipo_entrega text,
    transportadora_nome text,
    codigo_rastreamento text,
    numero_venda text,
    numero_entrega text,
    data_inicio_separacao timestamp with time zone,
    tipo_pedido text,
    garantia_detalhes text,
    inclui_garantia boolean DEFAULT false,
    garantia_peca text,
    garantia_motivo text
);


--
-- Name: solicitacoes_compra; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solicitacoes_compra (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    projeto_id uuid NOT NULL,
    produto_id uuid NOT NULL,
    quantidade_pedida numeric(10,2) NOT NULL,
    status text DEFAULT 'Pendente'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: staging_conta_pagar; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staging_conta_pagar (
    tipo_operacao text,
    cod_empresa integer,
    nm_empresa text,
    cod_duplicata integer,
    cod_venda numeric,
    num_nota text,
    cod_pessoa integer,
    nm_pessoa text,
    nm_funcionario text,
    razaosocial text,
    fantasia text,
    cpf_cnpj text,
    rgie text,
    logradouro text,
    numero text,
    complemento text,
    bairro text,
    cidade text,
    estado text,
    cep text,
    telefone text,
    celular text,
    email text,
    email_financeiro text,
    desc_apropriacao text,
    tipo_pagamento text,
    dt_emissao text,
    dt_vencimento text,
    dt_pagamento text,
    data_baixa text,
    dt_ultimo_pgto text,
    vl_duplicata numeric,
    vl_parcela numeric,
    vl_desconto numeric,
    vl_juros numeric,
    vl_pago numeric,
    pago integer,
    vl_frete numeric,
    vl_ipi numeric,
    vl_st numeric,
    num_parc integer,
    total_parc integer,
    lancamento integer,
    layout_boleto numeric,
    nosso_numero integer,
    observacao text,
    importado_em timestamp with time zone DEFAULT now(),
    processado boolean DEFAULT false,
    linha_excel integer
);


--
-- Name: TABLE staging_conta_pagar; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.staging_conta_pagar IS 'Staging: dados brutos do Excel ContaPagar (antes de transformação)';


--
-- Name: staging_conta_receber; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staging_conta_receber (
    tipo_operacao text,
    cod_empresa integer,
    nm_empresa text,
    cod_duplicata integer,
    cod_venda numeric,
    num_nota text,
    cod_pessoa integer,
    nm_pessoa text,
    nm_funcionario text,
    razaosocial text,
    fantasia text,
    cpf_cnpj text,
    rgie text,
    logradouro text,
    numero text,
    complemento text,
    bairro text,
    cidade text,
    estado text,
    cep text,
    telefone text,
    celular text,
    email text,
    email_financeiro text,
    desc_apropriacao text,
    tipo_pagamento text,
    dt_emissao text,
    dt_vencimento text,
    dt_pagamento text,
    data_baixa text,
    dt_ultimo_pgto text,
    vl_duplicata numeric,
    vl_parcela numeric,
    vl_desconto numeric,
    vl_juros numeric,
    vl_pago numeric,
    pago integer,
    vl_frete numeric,
    vl_ipi numeric,
    vl_st numeric,
    num_parc integer,
    total_parc integer,
    lancamento integer,
    layout_boleto numeric,
    nosso_numero integer,
    observacao text,
    importado_em timestamp with time zone DEFAULT now(),
    processado boolean DEFAULT false,
    linha_excel integer
);


--
-- Name: TABLE staging_conta_receber; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.staging_conta_receber IS 'Staging: dados brutos do Excel ContaReceber (antes de transformação)';


--
-- Name: staging_import_bruto; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staging_import_bruto (
    "COD" text,
    "CLIENTE" text,
    "PARCELA/COLUNA3" text,
    "DATA" text,
    "PROJETISTA" text,
    "VALOR FECHADO" text,
    "CAUSA PAGAMENTO" text,
    "FORMA PAGAMENTO" text,
    "DATA FECHAMENTO" text,
    "ARQUITETO" text,
    "LINHA ORIGINAL" text
);


--
-- Name: staging_pedido_compra; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staging_pedido_compra (
    codigo_pedido integer,
    cod_fornecedor integer,
    nm_fornecedor text,
    emissao_pedido text,
    vl_nota numeric,
    num_parc numeric,
    dt_vencimento text,
    vl_duplicata numeric,
    importado_em timestamp with time zone DEFAULT now(),
    processado boolean DEFAULT false,
    linha_excel integer
);


--
-- Name: TABLE staging_pedido_compra; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.staging_pedido_compra IS 'Staging: dados brutos do Excel PedidoCompra (antes de transformação)';


--
-- Name: staging_produtos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staging_produtos (
    codproduto integer,
    referencia text,
    descproduto text,
    codmarca numeric,
    descmarca text,
    codcategoria integer,
    desccategoria text,
    estoquetotal numeric,
    showroom integer,
    disponivel numeric,
    unidade text,
    custototal text,
    lucro numeric,
    valorvenda numeric,
    importado_em timestamp with time zone DEFAULT now(),
    processado boolean DEFAULT false,
    linha_excel integer
);


--
-- Name: TABLE staging_produtos; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.staging_produtos IS 'Staging: dados brutos do Excel Produtos (antes de transformação)';


--
-- Name: sync_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sync_history (
    id bigint NOT NULL,
    status text,
    mensagem text,
    created_at timestamp with time zone DEFAULT now(),
    registros_atualizados integer DEFAULT 0 NOT NULL,
    registros_inseridos integer DEFAULT 0 NOT NULL,
    registros_erro integer DEFAULT 0 NOT NULL,
    executado_por uuid,
    origem text,
    tipo text
);


--
-- Name: sync_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.sync_history ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.sync_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: systems; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.systems (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text NOT NULL,
    link text NOT NULL,
    icon_name text,
    display_order integer DEFAULT 0
);


--
-- Name: transacoes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transacoes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    conta_id uuid,
    projeto_id uuid,
    parcela_id uuid,
    tipo public.transacao_tipo NOT NULL,
    descricao text NOT NULL,
    valor numeric(15,2) NOT NULL,
    data_transacao date NOT NULL,
    comprovante_url text,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    categoria_id uuid,
    negociacao_id uuid,
    cod_itens_duplicata integer,
    num_parc smallint,
    dt_emissao date,
    dt_vencimento date,
    dt_pagamento date,
    vl_parcela numeric(12,2),
    vl_desconto numeric(12,2) DEFAULT 0,
    vl_juros numeric(12,2) DEFAULT 0,
    vl_pago numeric(12,2),
    vl_frete numeric(12,2) DEFAULT 0,
    vl_ipi numeric(12,2) DEFAULT 0,
    status_pago smallint DEFAULT 0,
    tipo_pagamento text,
    acordo integer,
    empresa_id uuid,
    funcionario_id uuid
);


--
-- Name: COLUMN transacoes.categoria_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transacoes.categoria_id IS 'Categoria financeira padronizada. Obrigatório para novos lançamentos. Use categorias_financeiras para listar opções.';


--
-- Name: COLUMN transacoes.empresa_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transacoes.empresa_id IS 'Define qual das 3 empresas (Foco, Manoella ou Islight) é a dona desta transação financeira.';


--
-- Name: COLUMN transacoes.funcionario_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transacoes.funcionario_id IS 'Funcionário relacionado à transação (usado principalmente para despesas de folha: salários, vale transporte, etc.)';


--
-- Name: user_roles_separacao; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_roles_separacao (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    nome_completo text NOT NULL,
    email text NOT NULL,
    funcao public.funcao_separacao_type,
    sistema text DEFAULT 'Separação e Entregas'::text,
    created_at timestamp with time zone DEFAULT now(),
    role text,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: user_system_access; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_system_access (
    user_id uuid NOT NULL,
    system_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: usuarios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usuarios (
    id uuid NOT NULL,
    email text NOT NULL,
    nome text NOT NULL,
    role public.usuario_role,
    ativo boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    avatar_url text,
    updated_at timestamp with time zone,
    onboarding_completado boolean DEFAULT false NOT NULL,
    empresa_id uuid,
    telefone text
);


--
-- Name: usuarios_ubiqua; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usuarios_ubiqua (
    id uuid NOT NULL,
    empresa_id uuid,
    nome text NOT NULL,
    email text NOT NULL,
    telefone text,
    onboarding_completado boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    nivel_acesso public.nivel_acesso_tipo DEFAULT 'revendedor'::public.nivel_acesso_tipo NOT NULL
);


--
-- Name: v_cash_flow_lucenera; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_cash_flow_lucenera AS
 SELECT dt_pagamento,
    dt_vencimento,
    (tipo)::text AS tipo,
        CASE
            WHEN (((descricao ~~* '%LUCRO%'::text) OR (descricao ~~* '%RETIRADA%'::text)) AND ((tipo)::text = 'despesa'::text)) THEN 'distribuicao_lucro'::text
            ELSE (tipo)::text
        END AS categoria_fluxo,
    vl_pago,
    descricao,
    status_pago
   FROM public.transacoes
  WHERE ((status_pago = 1) AND (dt_pagamento IS NOT NULL));


--
-- Name: vendas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vendas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    cod_venda integer,
    num_nota text,
    projeto_id uuid,
    cod_cliente integer,
    nome_cliente text NOT NULL,
    valor_total numeric(15,2) DEFAULT 0 NOT NULL,
    valor_pago numeric(15,2) DEFAULT 0,
    valor_pendente numeric(15,2) DEFAULT 0,
    total_parcelas integer DEFAULT 1,
    parcelas_pagas integer DEFAULT 0,
    data_emissao date,
    data_vencimento date,
    data_pagamento timestamp without time zone,
    status_pagamento public.status_pagamento DEFAULT 'Pendente'::public.status_pagamento,
    tipo_pagamento text,
    desc_apropriacao text,
    observacao text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: vendas_marca; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vendas_marca (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    marca_id uuid NOT NULL,
    mes integer NOT NULL,
    ano integer NOT NULL,
    valor_custo numeric(15,2) DEFAULT 0 NOT NULL,
    valor_venda numeric(15,2) DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_vendas_custo_positivo CHECK ((valor_custo >= (0)::numeric)),
    CONSTRAINT chk_vendas_venda_positivo CHECK ((valor_venda >= (0)::numeric)),
    CONSTRAINT vendas_marca_mes_check CHECK (((mes >= 1) AND (mes <= 12)))
);


--
-- Name: vw_catalogo_ubiqua; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_catalogo_ubiqua AS
 SELECT TRIM(BOTH FROM descricao) AS nome_exibicao,
    array_agg(DISTINCT TRIM(BOTH FROM cor) ORDER BY (TRIM(BOTH FROM cor))) AS cores_disponiveis,
    sum(disponivel) AS estoque_total,
    max(valor_revenda) AS valor_revenda,
    (array_agg(imagem_catalogo_url ORDER BY disponivel DESC))[1] AS imagem_principal,
    array_agg(json_build_object('cor', TRIM(BOTH FROM cor), 'disponivel', disponivel, 'referencia', referencia)) AS detalhes_por_cor
   FROM public.revenda_ubiqua
  WHERE (descricao IS NOT NULL)
  GROUP BY (TRIM(BOTH FROM descricao));


--
-- Name: vw_catalogo_unificado; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_catalogo_unificado AS
 SELECT TRIM(BOTH FROM regexp_replace(referencia, '-IS$'::text, ''::text, 'i'::text)) AS referencia_base,
    max(regexp_replace(descricao, '-\s*(ISLIGHT|MANOELLA)\s*$'::text, ''::text, 'i'::text)) AS nome_exibicao,
    sum(disponivel) AS estoque_total,
    array_agg(DISTINCT TRIM(BOTH FROM upper(COALESCE(cor, 'PADRÃO'::text)))) AS cores_disponiveis,
    max(imagem_catalogo_url) AS imagem_principal,
    min(valor_revenda) AS valor_minimo
   FROM public.revenda_ubiqua
  GROUP BY (TRIM(BOTH FROM regexp_replace(referencia, '-IS$'::text, ''::text, 'i'::text)));


--
-- Name: vw_conferencia_financeira; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_conferencia_financeira AS
 SELECT t.data_transacao,
    t.descricao,
    t.valor,
    e.nome AS nome_empresa,
    c.nome AS nome_fornecedor,
    t.status_pago,
    t.dt_vencimento
   FROM ((public.transacoes t
     LEFT JOIN public.empresas e ON ((t.empresa_id = e.id)))
     LEFT JOIN public.contatos c ON ((t.parcela_id = c.id)))
  ORDER BY t.data_transacao DESC;


--
-- Name: VIEW vw_conferencia_financeira; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.vw_conferencia_financeira IS 'Visão consolidada para conferência humana: associa IDs de transações aos nomes reais de empresas e fornecedores da Lucenera.';


--
-- Name: vw_controle_ferias_clt; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_controle_ferias_clt AS
 WITH resumo_periodos AS (
         SELECT pa.funcionario_id,
            f.nome AS funcionario_nome,
            (count(pa.id) * 30) AS direito_total_acumulado,
            COALESCE(( SELECT sum(fer.dias) AS sum
                   FROM public.ferias fer
                  WHERE ((fer.funcionario_id = pa.funcionario_id) AND (fer.status = 'Aprovado'::text))), (0)::bigint) AS total_gozado
           FROM (public.periodos_aquisitivos pa
             JOIN public.funcionarios f ON ((pa.funcionario_id = f.id)))
          GROUP BY pa.funcionario_id, f.nome
        )
 SELECT funcionario_id,
    funcionario_nome,
    direito_total_acumulado,
    total_gozado,
    (direito_total_acumulado - total_gozado) AS saldo_disponivel
   FROM resumo_periodos;


--
-- Name: vw_custos_pendentes_mes; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_custos_pendentes_mes WITH (security_invoker='on') AS
 SELECT cr.descricao,
    cf.nome AS categoria,
    crl.data_vencimento,
    crl.valor_original,
    crl.status,
    cb.nome AS conta
   FROM (((public.custos_recorrentes_lancamentos crl
     JOIN public.custos_recorrentes cr ON ((cr.id = crl.custo_id)))
     LEFT JOIN public.categorias_financeiras cf ON ((cf.id = cr.categoria_id)))
     LEFT JOIN public.contas_bancarias cb ON ((cb.id = cr.conta_id)))
  WHERE ((crl.status = 'pendente'::public.lancamento_status) AND (date_trunc('month'::text, (crl.data_vencimento)::timestamp with time zone) = date_trunc('month'::text, now())))
  ORDER BY crl.data_vencimento;


--
-- Name: vw_dashboard_crm_fechamento; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_dashboard_crm_fechamento AS
 SELECT date_trunc('month'::text, (p.data_entrada)::timestamp with time zone) AS mes,
    count(*) AS total_projetos,
    count(DISTINCT p.client_id) AS total_clientes,
    COALESCE(sum(v.valor_total), (0)::numeric) AS valor_total,
    count(*) FILTER (WHERE ((p.area_do_projeto ->> 'tipo'::text) = 'Residential'::text)) AS projetos_residenciais,
    count(*) FILTER (WHERE ((p.area_do_projeto ->> 'tipo'::text) = 'Corporativo'::text)) AS projetos_corporativos,
    count(*) FILTER (WHERE ((p.area_do_projeto ->> 'tipo'::text) = 'Exposição Comercial'::text)) AS projetos_comerciais,
    count(*) FILTER (WHERE ((p.area_do_projeto ->> 'tipo'::text) = 'Paisagismo'::text)) AS projetos_paisagismo
   FROM (public.projetos p
     LEFT JOIN LATERAL ( SELECT sum(vendas.valor_total) AS valor_total
           FROM public.vendas
          WHERE (vendas.projeto_id = p.id)) v ON (true))
  WHERE (p.data_entrada IS NOT NULL)
  GROUP BY (date_trunc('month'::text, (p.data_entrada)::timestamp with time zone))
  ORDER BY (date_trunc('month'::text, (p.data_entrada)::timestamp with time zone)) DESC;


--
-- Name: VIEW vw_dashboard_crm_fechamento; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.vw_dashboard_crm_fechamento IS 'Dashboard de fechamentos mensais com dados da nova estrutura';


--
-- Name: vw_detalhe_produto_estoque; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_detalhe_produto_estoque AS
 SELECT p.id AS produto_id,
    p.codigo_produto,
    p.nome,
    p.referencia,
    p.sku,
    p.unidade,
    p.preco_custo,
    p.porc_frete,
    p.porc_despesas,
    p.porc_bdi,
    p.valor_venda,
    p.ncm,
    p.cst,
    p.cest,
    p.status_comercial,
    p.ativo,
    ei.local AS setor,
    ei.quantidade AS qtd_atual,
    ei.quantidade_reservada AS qtd_reserva,
    (ei.quantidade - ei.quantidade_reservada) AS qtd_disponivel
   FROM (public.produtos p
     LEFT JOIN public.estoque_itens ei ON ((p.id = ei.produto_id)));


--
-- Name: vw_estoque_liquido; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_estoque_liquido WITH (security_invoker='on') AS
 SELECT p.id AS produto_id,
    p.nome AS produto,
    p.sku,
    m.nome AS marca,
    p.categoria,
    p.preco_custo,
    p.preco_venda,
    COALESCE(sum(ei.quantidade) FILTER (WHERE (ei.local = 'Estoque'::public.estoque_local)), (0)::numeric) AS qtd_fisico,
    COALESCE(sum(ei.quantidade) FILTER (WHERE (ei.local = 'Reservado'::public.estoque_local)), (0)::numeric) AS qtd_reservado,
    COALESCE(sum(ei.quantidade) FILTER (WHERE (ei.local = 'Showroom'::public.estoque_local)), (0)::numeric) AS qtd_showroom,
    COALESCE(sum(ei.quantidade) FILTER (WHERE (ei.local = 'Em trânsito'::public.estoque_local)), (0)::numeric) AS qtd_em_transito,
    GREATEST((0)::numeric, (COALESCE(sum(ei.quantidade) FILTER (WHERE (ei.local = 'Estoque'::public.estoque_local)), (0)::numeric) - COALESCE(sum(ei.quantidade) FILTER (WHERE (ei.local = 'Reservado'::public.estoque_local)), (0)::numeric))) AS qtd_disponivel,
        CASE
            WHEN ((COALESCE(sum(ei.quantidade) FILTER (WHERE (ei.local = 'Estoque'::public.estoque_local)), (0)::numeric) - COALESCE(sum(ei.quantidade) FILTER (WHERE (ei.local = 'Reservado'::public.estoque_local)), (0)::numeric)) <= (0)::numeric) THEN 'critico'::text
            WHEN ((COALESCE(sum(ei.quantidade) FILTER (WHERE (ei.local = 'Estoque'::public.estoque_local)), (0)::numeric) - COALESCE(sum(ei.quantidade) FILTER (WHERE (ei.local = 'Reservado'::public.estoque_local)), (0)::numeric)) <= (3)::numeric) THEN 'baixo'::text
            ELSE 'ok'::text
        END AS alerta_estoque,
    round((COALESCE(sum(ei.quantidade) FILTER (WHERE (ei.local = 'Estoque'::public.estoque_local)), (0)::numeric) * p.preco_venda), 2) AS valor_estoque_total,
    round((COALESCE(sum(ei.quantidade) FILTER (WHERE (ei.local = 'Reservado'::public.estoque_local)), (0)::numeric) * p.preco_venda), 2) AS valor_reservado_total
   FROM ((public.produtos p
     LEFT JOIN public.marcas m ON ((m.id = p.marca_id)))
     LEFT JOIN public.estoque_itens ei ON ((ei.produto_id = p.id)))
  WHERE (p.ativo = true)
  GROUP BY p.id, p.nome, p.sku, m.nome, p.categoria, p.preco_custo, p.preco_venda;


--
-- Name: vw_estoque_por_marca; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_estoque_por_marca WITH (security_invoker='on') AS
 SELECT m.nome AS marca,
    count(p.id) AS skus_total,
    sum(e.quantidade) FILTER (WHERE (e.local = 'Estoque'::public.estoque_local)) AS qtd_estoque,
    sum(e.quantidade) FILTER (WHERE (e.local = 'Showroom'::public.estoque_local)) AS qtd_showroom,
    sum((p.preco_venda * e.quantidade)) AS valor_disponivel_venda
   FROM ((public.marcas m
     LEFT JOIN public.produtos p ON ((p.marca_id = m.id)))
     LEFT JOIN public.estoque_itens e ON ((e.produto_id = p.id)))
  GROUP BY m.id, m.nome;


--
-- Name: vw_estoque_produtos; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_estoque_produtos AS
 SELECT p.codigo_legado AS codigo_produto,
    p.referencia,
    p.nome AS descricao,
    m.nome AS marca,
    cp.nome AS categoria,
    p.estoque_total,
    p.estoque_showroom,
    p.estoque_disponivel,
    p.valor_venda,
        CASE
            WHEN (p.estoque_disponivel <= (0)::numeric) THEN 'Sem Estoque'::text
            WHEN (p.estoque_disponivel <= (5)::numeric) THEN 'Estoque Baixo'::text
            ELSE 'OK'::text
        END AS status_estoque
   FROM ((public.produtos p
     LEFT JOIN public.marcas m ON ((m.id = p.marca_id)))
     LEFT JOIN public.categorias_produto cp ON ((cp.id = p.categoria_id)))
  WHERE (p.ativo = true)
  ORDER BY p.nome;


--
-- Name: vw_financeiro_projetos; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_financeiro_projetos AS
 SELECT p.id,
    p.codigo,
    p.nome,
    p.status,
    p.client_id,
    c.nome AS cliente_nome,
    v.valor_total,
    v.valor_recebido,
    v.valor_pendente,
    v.total_parcelas,
    v.parcelas_pagas,
    v.parcelas_pendentes
   FROM ((public.projetos p
     LEFT JOIN public.contatos c ON (((c.id = p.client_id) AND (c.tipo = 'cliente'::public.contato_tipo))))
     LEFT JOIN LATERAL ( SELECT sum(vendas.valor_total) AS valor_total,
            sum(
                CASE
                    WHEN (vendas.status_pagamento = 'Pago'::public.status_pagamento) THEN vendas.valor_total
                    ELSE (0)::numeric
                END) AS valor_recebido,
            sum(
                CASE
                    WHEN (vendas.status_pagamento <> 'Pago'::public.status_pagamento) THEN vendas.valor_total
                    ELSE (0)::numeric
                END) AS valor_pendente,
            count(*) AS total_parcelas,
            count(*) FILTER (WHERE (vendas.status_pagamento = 'Pago'::public.status_pagamento)) AS parcelas_pagas,
            count(*) FILTER (WHERE (vendas.status_pagamento <> 'Pago'::public.status_pagamento)) AS parcelas_pendentes
           FROM public.vendas
          WHERE (vendas.projeto_id = p.id)) v ON (true));


--
-- Name: VIEW vw_financeiro_projetos; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.vw_financeiro_projetos IS 'Visão financeira dos projetos com dados agregados da tabela vendas';


--
-- Name: vw_fluxo_caixa_projetado; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_fluxo_caixa_projetado WITH (security_invoker='on') AS
 SELECT date_trunc('month'::text, (data_vencimento)::timestamp with time zone) AS mes,
    sum(valor) FILTER (WHERE (status = 'pendente'::public.parcela_status)) AS a_receber,
    sum(valor) FILTER (WHERE (status = 'paga'::public.parcela_status)) AS recebido,
    sum(valor) FILTER (WHERE (status = 'atrasada'::public.parcela_status)) AS atrasado,
    count(*) FILTER (WHERE (status = 'pendente'::public.parcela_status)) AS qtd_pendente,
    count(*) FILTER (WHERE (status = 'atrasada'::public.parcela_status)) AS qtd_atrasado
   FROM public.projeto_parcelas
  WHERE (data_vencimento IS NOT NULL)
  GROUP BY (date_trunc('month'::text, (data_vencimento)::timestamp with time zone))
  ORDER BY (date_trunc('month'::text, (data_vencimento)::timestamp with time zone));


--
-- Name: vw_fornecedores_remessas; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_fornecedores_remessas AS
 SELECT f.id,
    f.nome,
    f.cnpj_cpf,
    f.status,
    e.id AS empresa_id,
    e.nome AS empresa_nome,
    count(r.id) AS total_remessas,
    COALESCE(sum(r.valor), (0)::numeric) AS total_valor_remessas,
    COALESCE(sum(
        CASE
            WHEN (r.status = 'pago'::text) THEN r.valor_pago
            ELSE (0)::numeric
        END), (0)::numeric) AS total_pago
   FROM ((public.fornecedores f
     LEFT JOIN public.empresas e ON ((e.id = f.empresa_id)))
     LEFT JOIN public.remessas r ON ((r.fornecedor_id = f.id)))
  GROUP BY f.id, f.nome, f.cnpj_cpf, f.status, e.id, e.nome;


--
-- Name: vw_fornecedores_resumo; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_fornecedores_resumo AS
 SELECT f.id,
    f.nome,
    f.cnpj_cpf,
    f.email,
    f.telefone,
    f.status,
    f.categoria,
    e.id AS empresa_id,
    e.nome AS empresa_nome,
    f.created_at,
    f.updated_at
   FROM (public.fornecedores f
     LEFT JOIN public.empresas e ON ((e.id = f.empresa_id)));


--
-- Name: vw_funcionarios_completo; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_funcionarios_completo AS
 SELECT f.id,
    f.nome,
    f.cargo,
    f.data_admissao,
    f.ativo,
    fd.cpf,
    fd.rg,
    fd.data_nascimento,
    fd.email,
    fd.telefone,
    fd.endereco,
    ff.salario_base,
    ff.salario_por_fora,
    ff.salario_liquido,
    ff.comissao_percentual,
    fb.empresa,
    fb.valor_vt_dia
   FROM (((public.funcionarios_novo f
     LEFT JOIN public.funcionarios_detalhes fd ON ((f.id = fd.funcionario_id)))
     LEFT JOIN public.funcionarios_financeiro ff ON ((f.id = ff.funcionario_id)))
     LEFT JOIN public.funcionarios_beneficios_empresas fb ON ((f.id = fb.funcionario_id)))
  ORDER BY f.id;


--
-- Name: vw_historico_faltas; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_historico_faltas AS
 SELECT f.id AS funcionario_id,
    f.nome AS funcionario_nome,
    cf.data AS data_falta,
    cf.status,
    cf.justificativa,
    pa.id AS periodo_id,
    pa.data_inicio,
    pa.data_fim
   FROM ((public.controle_falta cf
     JOIN public.funcionarios f ON ((cf.funcionario_id = f.id)))
     JOIN public.periodos_aquisitivos pa ON ((cf.funcionario_id = pa.funcionario_id)))
  WHERE ((cf.data >= pa.data_inicio) AND (cf.data <= pa.data_fim))
  ORDER BY cf.data DESC;


--
-- Name: vw_logs_auditoria_recentes; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_logs_auditoria_recentes AS
 SELECT id,
    created_at,
    tabela,
    operacao,
    registro_id,
    usuario_id,
    dados_anteriores,
    dados_novos,
    observacao
   FROM public.logs_auditoria
  ORDER BY created_at DESC
 LIMIT 1000;


--
-- Name: vw_produtos_estoque_detalhado; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_produtos_estoque_detalhado AS
 WITH estoque_calculado AS (
         SELECT estoque_itens.produto_id,
            sum(
                CASE
                    WHEN ((estoque_itens.local)::text ~~* 'estoque%'::text) THEN estoque_itens.quantidade
                    ELSE (0)::numeric
                END) AS qtd_geral,
            sum(
                CASE
                    WHEN ((estoque_itens.local)::text ~~* 'showroom%'::text) THEN estoque_itens.quantidade
                    ELSE (0)::numeric
                END) AS qtd_showroom,
            sum(
                CASE
                    WHEN ((estoque_itens.local)::text ~~* 'reserva%'::text) THEN estoque_itens.quantidade
                    ELSE (0)::numeric
                END) AS qtd_reserva,
            sum(
                CASE
                    WHEN (((estoque_itens.local)::text ~~* 'separacao%'::text) OR ((estoque_itens.local)::text ~~* 'separação%'::text)) THEN estoque_itens.quantidade
                    ELSE (0)::numeric
                END) AS qtd_separacao,
            sum(estoque_itens.quantidade) AS total_fisico
           FROM public.estoque_itens
          GROUP BY estoque_itens.produto_id
        )
 SELECT p.id,
    p.codigo_produto,
    p.nome,
    p.sku,
    p.preco_venda,
    COALESCE(ec.qtd_geral, (0)::numeric) AS estoque_geral,
    COALESCE(ec.qtd_reserva, (0)::numeric) AS reserva,
    COALESCE(ec.qtd_separacao, (0)::numeric) AS separacao,
    ((COALESCE(ec.qtd_geral, (0)::numeric) - COALESCE(ec.qtd_reserva, (0)::numeric)) - COALESCE(ec.qtd_separacao, (0)::numeric)) AS disponivel
   FROM (public.produtos p
     LEFT JOIN estoque_calculado ec ON ((p.id = ec.produto_id)));


--
-- Name: vw_produtos_estoque_por_local; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_produtos_estoque_por_local AS
 SELECT p.codigo_produto,
    p.nome,
    p.unidade,
    p.preco_venda,
    p.cst,
    p.cest,
    p.porc_bdi,
    p.status_comercial,
    p.mascara_produto,
    e.local AS setor,
    e.quantidade,
    e.quantidade_reservada
   FROM (public.produtos p
     JOIN public.estoque_itens e ON ((p.id = e.produto_id)));


--
-- Name: vw_projetos_dashboard; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_projetos_dashboard AS
 SELECT p.id,
    p.codigo,
    p.nome,
    p.status,
    p.nivel_estrategico,
    p.data_entrada,
    p.cidade,
    p.estado,
    p.arquivado,
    p.responsavel_id,
    p.responsavel_nome,
    u.email AS responsavel_email,
    p.cliente_id,
    c.nome AS cliente_nome,
    c.tipo AS cliente_tipo,
    p.arquiteto_id,
    a.nome AS arquiteto_nome,
    p.empresa_id,
    e.nome AS empresa_nome,
    e.codigo AS empresa_codigo,
    p.area_do_projeto,
    (p.area_do_projeto ->> 'tipo'::text) AS tipo_projeto,
    p.created_at,
    p.updated_at
   FROM ((((public.projetos p
     LEFT JOIN public.usuarios u ON ((p.responsavel_id = u.id)))
     LEFT JOIN public.contatos c ON ((p.cliente_id = c.id)))
     LEFT JOIN public.contatos a ON ((p.arquiteto_id = a.id)))
     LEFT JOIN public.empresas e ON ((p.empresa_id = e.id)))
  WHERE (p.arquivado = false)
  ORDER BY p.created_at DESC;


--
-- Name: VIEW vw_projetos_dashboard; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.vw_projetos_dashboard IS 'View consolidada de projetos para dashboard com todos os relacionamentos';


--
-- Name: vw_projetos_pipeline; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_projetos_pipeline AS
 SELECT p.id,
    p.codigo,
    p.nome,
    p.status,
    p.data_entrada,
    (p.area_do_projeto ->> 'tipo'::text) AS tipo_projeto,
    p.client_id,
    c.nome AS cliente_nome,
    COALESCE(v.valor_total, (0)::numeric) AS valor_total
   FROM ((public.projetos p
     LEFT JOIN public.contatos c ON (((c.id = p.client_id) AND (c.tipo = 'cliente'::public.contato_tipo))))
     LEFT JOIN LATERAL ( SELECT sum(vendas.valor_total) AS valor_total
           FROM public.vendas
          WHERE (vendas.projeto_id = p.id)) v ON (true))
  WHERE ((p.arquivado = false) OR (p.arquivado IS NULL));


--
-- Name: VIEW vw_projetos_pipeline; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.vw_projetos_pipeline IS 'Pipeline de projetos ativos com valores financeiros da tabela vendas';


--
-- Name: vw_projetos_por_responsavel; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_projetos_por_responsavel AS
 SELECT u.id AS usuario_id,
    u.nome AS responsavel,
    count(p.id) AS total_projetos,
    count(
        CASE
            WHEN (p.arquivado = false) THEN 1
            ELSE NULL::integer
        END) AS projetos_ativos,
    count(
        CASE
            WHEN (p.arquivado = true) THEN 1
            ELSE NULL::integer
        END) AS projetos_arquivados
   FROM (public.usuarios u
     LEFT JOIN public.projetos p ON ((u.id = p.responsavel_id)))
  GROUP BY u.id, u.nome
 HAVING (count(p.id) > 0)
  ORDER BY (count(p.id)) DESC;


--
-- Name: VIEW vw_projetos_por_responsavel; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.vw_projetos_por_responsavel IS 'Estatísticas de projetos por responsável';


--
-- Name: vw_projetos_por_status; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_projetos_por_status AS
 SELECT p.status,
    count(*) AS total_projetos,
    count(DISTINCT p.client_id) AS total_clientes,
    COALESCE(sum(v.valor_total), (0)::numeric) AS valor_total
   FROM (public.projetos p
     LEFT JOIN LATERAL ( SELECT sum(vendas.valor_total) AS valor_total
           FROM public.vendas
          WHERE (vendas.projeto_id = p.id)) v ON (true))
  WHERE ((p.arquivado = false) OR (p.arquivado IS NULL))
  GROUP BY p.status
  ORDER BY (count(*)) DESC;


--
-- Name: VIEW vw_projetos_por_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.vw_projetos_por_status IS 'Agregação de projetos por status com valores da tabela vendas';


--
-- Name: vw_projetos_resumo; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_projetos_resumo AS
 SELECT p.id,
    p.codigo,
    p.status,
    count(DISTINCT v.id) AS total_vendas,
    COALESCE(sum(v.valor_total), (0)::numeric) AS valor_total_vendas,
    COALESCE(sum(v.valor_pago), (0)::numeric) AS valor_pago,
    COALESCE((sum(v.valor_total) - sum(v.valor_pago)), (0)::numeric) AS valor_pendente
   FROM (public.projetos p
     LEFT JOIN public.vendas v ON ((v.projeto_id = p.id)))
  GROUP BY p.id, p.codigo, p.status;


--
-- Name: vw_projetos_sem_empresa; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_projetos_sem_empresa AS
 SELECT id,
    codigo,
    nome,
    status,
    responsavel_nome,
    data_entrada,
    created_at
   FROM public.projetos
  WHERE ((empresa_id IS NULL) AND (arquivado = false))
  ORDER BY created_at DESC;


--
-- Name: VIEW vw_projetos_sem_empresa; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.vw_projetos_sem_empresa IS 'Projetos sem empresa definida (precisam revisão manual)';


--
-- Name: vw_projetos_sem_responsavel; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_projetos_sem_responsavel AS
 SELECT id,
    codigo,
    nome,
    status,
    data_entrada,
    created_at,
    cliente_id,
    arquiteto_id
   FROM public.projetos
  WHERE ((responsavel_id IS NULL) AND (arquivado = false))
  ORDER BY created_at DESC;


--
-- Name: VIEW vw_projetos_sem_responsavel; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.vw_projetos_sem_responsavel IS 'Projetos ativos sem responsável definido';


--
-- Name: vw_projetos_status_enum; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_projetos_status_enum AS
 SELECT DISTINCT status,
    count(*) AS total
   FROM public.projetos
  GROUP BY status
  ORDER BY (count(*)) DESC;


--
-- Name: VIEW vw_projetos_status_enum; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.vw_projetos_status_enum IS 'Lista todos os valores possíveis do enum projeto_status com contagem';


--
-- Name: vw_remessas_completa; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_remessas_completa AS
 SELECT r.id,
    r.descricao,
    r.valor,
    r.vencimento,
    r.status,
    r.nosso_numero,
    r.linha_digitavel,
    r.data_pagamento,
    r.valor_pago,
    r.observacoes,
    f.id AS fornecedor_id,
    f.nome AS fornecedor_nome,
    f.cnpj_cpf AS fornecedor_cnpj_cpf,
    e.id AS empresa_id,
    e.nome AS empresa_nome,
    r.created_at,
    r.updated_at
   FROM ((public.remessas r
     LEFT JOIN public.fornecedores f ON ((f.id = r.fornecedor_id)))
     LEFT JOIN public.empresas e ON ((e.id = r.empresa_id)));


--
-- Name: vw_remessas_resumo_status; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_remessas_resumo_status AS
 SELECT e.id AS empresa_id,
    e.nome AS empresa_nome,
    r.status,
    count(*) AS quantidade,
    COALESCE(sum(r.valor), (0)::numeric) AS valor_total,
    COALESCE(sum(r.valor_pago), (0)::numeric) AS valor_pago_total
   FROM (public.remessas r
     LEFT JOIN public.empresas e ON ((e.id = r.empresa_id)))
  GROUP BY e.id, e.nome, r.status;


--
-- Name: vw_remessas_vencimento; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_remessas_vencimento AS
 SELECT r.id,
    r.created_at,
    r.updated_at,
    r.empresa_id,
    r.fornecedor_id,
    r.descricao,
    r.valor,
    r.vencimento,
    r.status,
    r.linha_digitavel,
    r.codigo_barras,
    r.nosso_numero,
    r.arquivo_remessa,
    r.arquivo_retorno,
    r.data_pagamento,
    r.valor_pago,
    r.observacoes,
    r.user_id,
    f.nome AS fornecedor_nome,
    e.nome AS empresa_nome,
        CASE
            WHEN (r.vencimento < CURRENT_DATE) THEN 'vencida'::text
            WHEN ((r.vencimento >= CURRENT_DATE) AND (r.vencimento <= (CURRENT_DATE + '7 days'::interval))) THEN 'a_vencer_7_dias'::text
            ELSE 'em_dia'::text
        END AS situacao_vencimento
   FROM ((public.remessas r
     LEFT JOIN public.fornecedores f ON ((f.id = r.fornecedor_id)))
     LEFT JOIN public.empresas e ON ((e.id = r.empresa_id)))
  WHERE (r.status <> ALL (ARRAY['pago'::text, 'cancelado'::text]));


--
-- Name: vw_separacoes_agenda; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_separacoes_agenda WITH (security_invoker='true') AS
 SELECT s.id AS separacao_id,
    s.status AS separacao_status,
    s.data_entrega,
    s.data_entrega_original,
    s.reagendamentos,
    s.codigo_obra,
    s.cliente,
    s.endereco_entrega,
    s.delivery_type,
    s.scheduled_time,
    s.observacoes,
    pr.id AS projeto_id,
    pr.codigo AS projeto_codigo,
    pr.nome AS projeto_nome,
    pr.status AS projeto_status,
    c.nome AS cliente_nome,
    e.id AS entrega_id,
    e.status AS entrega_status,
    e.entregador_id,
    u.nome AS entregador_nome,
    count(si.id) AS total_itens,
    count(si.id) FILTER (WHERE (si.separado = true)) AS itens_separados,
    (s.data_entrega - CURRENT_DATE) AS dias_ate_entrega,
        CASE
            WHEN ((s.data_entrega < CURRENT_DATE) AND (s.status <> ALL (ARRAY['Enviado'::public.separacao_status, 'Cancelado'::public.separacao_status]))) THEN 'atrasado'::text
            WHEN ((s.data_entrega = CURRENT_DATE) AND (s.status <> ALL (ARRAY['Enviado'::public.separacao_status, 'Cancelado'::public.separacao_status]))) THEN 'hoje'::text
            WHEN ((s.data_entrega >= (CURRENT_DATE + 1)) AND (s.data_entrega <= (CURRENT_DATE + 3)) AND (s.status <> ALL (ARRAY['Enviado'::public.separacao_status, 'Cancelado'::public.separacao_status]))) THEN 'urgente'::text
            ELSE 'normal'::text
        END AS urgencia,
    s.created_at,
    s.updated_at
   FROM (((((public.separacoes s
     LEFT JOIN public.projetos pr ON ((pr.id = s.projeto_id)))
     LEFT JOIN public.contatos c ON ((c.id = pr.cliente_id)))
     LEFT JOIN public.entregas e ON (((e.separacao_id = s.id) AND (e.status <> 'Cancelado'::public.entrega_status))))
     LEFT JOIN public.usuarios u ON ((u.id = e.entregador_id)))
     LEFT JOIN public.separacao_itens si ON ((si.separacao_id = s.id)))
  WHERE (s.status <> 'Cancelado'::public.separacao_status)
  GROUP BY s.id, s.status, s.data_entrega, s.data_entrega_original, s.reagendamentos, s.codigo_obra, s.cliente, s.endereco_entrega, s.delivery_type, s.scheduled_time, s.observacoes, s.created_at, s.updated_at, pr.id, pr.codigo, pr.nome, pr.status, c.nome, e.id, e.status, e.entregador_id, u.nome
  ORDER BY
        CASE
            WHEN ((s.data_entrega < CURRENT_DATE) AND (s.status <> ALL (ARRAY['Enviado'::public.separacao_status, 'Cancelado'::public.separacao_status]))) THEN 0
            ELSE 1
        END, s.data_entrega;


--
-- Name: vw_staging_resumo; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_staging_resumo AS
 SELECT 'conta_pagar'::text AS tabela,
    count(*) AS total,
    count(*) FILTER (WHERE (staging_conta_pagar.processado = true)) AS processados,
    count(*) FILTER (WHERE (staging_conta_pagar.processado = false)) AS pendentes,
    min(staging_conta_pagar.importado_em) AS primeira_importacao,
    max(staging_conta_pagar.importado_em) AS ultima_importacao
   FROM public.staging_conta_pagar
UNION ALL
 SELECT 'conta_receber'::text AS tabela,
    count(*) AS total,
    count(*) FILTER (WHERE (staging_conta_receber.processado = true)) AS processados,
    count(*) FILTER (WHERE (staging_conta_receber.processado = false)) AS pendentes,
    min(staging_conta_receber.importado_em) AS primeira_importacao,
    max(staging_conta_receber.importado_em) AS ultima_importacao
   FROM public.staging_conta_receber
UNION ALL
 SELECT 'produtos'::text AS tabela,
    count(*) AS total,
    count(*) FILTER (WHERE (staging_produtos.processado = true)) AS processados,
    count(*) FILTER (WHERE (staging_produtos.processado = false)) AS pendentes,
    min(staging_produtos.importado_em) AS primeira_importacao,
    max(staging_produtos.importado_em) AS ultima_importacao
   FROM public.staging_produtos
UNION ALL
 SELECT 'pedido_compra'::text AS tabela,
    count(*) AS total,
    count(*) FILTER (WHERE (staging_pedido_compra.processado = true)) AS processados,
    count(*) FILTER (WHERE (staging_pedido_compra.processado = false)) AS pendentes,
    min(staging_pedido_compra.importado_em) AS primeira_importacao,
    max(staging_pedido_compra.importado_em) AS ultima_importacao
   FROM public.staging_pedido_compra;


--
-- Name: VIEW vw_staging_resumo; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.vw_staging_resumo IS 'Resumo do status de importação das tabelas staging';


--
-- Name: vw_transacoes_completas; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_transacoes_completas AS
 SELECT t.id,
    t.negociacao_id,
    n.cod_duplicata,
    t.cod_itens_duplicata,
    t.tipo,
    n.dev_troca,
    t.num_parc,
    n.total_parc,
    t.dt_emissao,
    t.dt_vencimento,
    t.dt_pagamento,
    t.data_transacao,
    COALESCE(t.vl_parcela, t.valor) AS valor,
    t.vl_parcela,
    t.vl_desconto,
    t.vl_juros,
    t.vl_pago,
    t.vl_frete,
    t.vl_ipi,
    t.status_pago,
    t.tipo_pagamento,
    t.acordo,
    e.id AS empresa_id,
    e.nome AS empresa_nome,
    c.id AS contato_id,
    c.nome AS contato_nome,
    c.tipo AS contato_tipo,
    f.id AS funcionario_id,
    f.nome AS funcionario_nome,
    aprop.id AS plano_contas_id,
    aprop.nome AS plano_apropriacao,
    sg.nome AS plano_sub_grupo,
    gr.nome AS plano_grupo,
    cb.id AS conta_bancaria_id,
    cb.nome AS conta_bancaria_nome,
    pj.id AS projeto_id,
    pj.codigo AS projeto_codigo,
    pj.nome AS projeto_nome,
    n.cod_venda,
    pp.id AS parcela_crm_id,
    pp.numero_parcela AS parcela_crm_numero,
    t.descricao,
    t.comprovante_url,
    t.created_by
   FROM ((((((((((public.transacoes t
     LEFT JOIN public.negociacoes n ON ((n.id = t.negociacao_id)))
     LEFT JOIN public.empresas e ON ((e.id = n.empresa_id)))
     LEFT JOIN public.contatos c ON ((c.id = n.contato_id)))
     LEFT JOIN public.funcionarios f ON ((f.id = n.funcionario_id)))
     LEFT JOIN public.plano_de_contas aprop ON ((aprop.id = n.plano_contas_id)))
     LEFT JOIN public.plano_de_contas sg ON ((sg.id = aprop.parent_id)))
     LEFT JOIN public.plano_de_contas gr ON ((gr.id = sg.parent_id)))
     LEFT JOIN public.contas_bancarias cb ON ((cb.id = t.conta_id)))
     LEFT JOIN public.projetos pj ON ((pj.id = COALESCE(n.projeto_id, t.projeto_id))))
     LEFT JOIN public.projeto_parcelas pp ON ((pp.transacao_id = t.id)));


--
-- Name: vw_vendas_loja; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_vendas_loja WITH (security_invoker='on') AS
 SELECT p.id AS produto_id,
    p.nome AS produto,
    p.sku,
    m.nome AS marca,
    p.categoria,
    si.quantidade,
    p.preco_custo,
    p.preco_venda,
    round(((p.preco_venda - p.preco_custo) * si.quantidade), 2) AS margem_total,
    s.id AS separacao_id,
    s.created_at AS data_venda,
    s.cliente,
    s.observacoes
   FROM (((public.separacao_itens si
     JOIN public.produtos p ON ((p.id = si.produto_id)))
     JOIN public.separacoes s ON ((s.id = si.separacao_id)))
     LEFT JOIN public.marcas m ON ((m.id = p.marca_id)))
  WHERE ((si.produto_id IS NOT NULL) AND (s.projeto_id IS NULL));


--
-- Name: vw_vendas_por_projeto; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_vendas_por_projeto WITH (security_invoker='true') AS
 SELECT p.id AS produto_id,
    p.nome AS produto,
    p.sku,
    m.nome AS marca,
    p.categoria,
    si.quantidade,
    p.preco_custo,
    p.preco_venda,
    round(((p.preco_venda - p.preco_custo) * si.quantidade), 2) AS margem_total,
    s.id AS separacao_id,
    s.created_at AS data_separacao,
    pr.id AS projeto_id,
    pr.codigo AS projeto_codigo,
    pr.nome AS projeto_nome,
    pr.status AS projeto_status,
    cli.nome AS cliente,
    pr.cidade AS projeto_cidade,
    pr.estado AS projeto_estado
   FROM (((((public.separacao_itens si
     JOIN public.produtos p ON ((p.id = si.produto_id)))
     JOIN public.separacoes s ON ((s.id = si.separacao_id)))
     JOIN public.projetos pr ON ((pr.id = s.projeto_id)))
     LEFT JOIN public.marcas m ON ((m.id = p.marca_id)))
     LEFT JOIN public.contatos cli ON ((cli.id = pr.cliente_id)))
  WHERE ((si.produto_id IS NOT NULL) AND (s.projeto_id IS NOT NULL));


--
-- Name: vw_vendas_produtos; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_vendas_produtos WITH (security_invoker='on') AS
 SELECT 'projeto'::text AS origem,
    p.id AS produto_id,
    p.nome AS produto,
    p.sku,
    m.nome AS marca,
    p.categoria,
    si.quantidade,
    p.preco_custo,
    p.preco_venda,
    round(((p.preco_venda - p.preco_custo) * si.quantidade), 2) AS margem_total,
    s.created_at AS data_venda,
    pr.codigo AS projeto_codigo,
    pr.nome AS projeto_nome,
    COALESCE(cli.nome, s.cliente) AS cliente
   FROM (((((public.separacao_itens si
     JOIN public.produtos p ON ((p.id = si.produto_id)))
     JOIN public.separacoes s ON ((s.id = si.separacao_id)))
     JOIN public.projetos pr ON ((pr.id = s.projeto_id)))
     LEFT JOIN public.marcas m ON ((m.id = p.marca_id)))
     LEFT JOIN public.contatos cli ON ((cli.id = pr.cliente_id)))
  WHERE ((si.produto_id IS NOT NULL) AND (s.projeto_id IS NOT NULL))
UNION ALL
 SELECT 'loja'::text AS origem,
    p.id AS produto_id,
    p.nome AS produto,
    p.sku,
    m.nome AS marca,
    p.categoria,
    si.quantidade,
    p.preco_custo,
    p.preco_venda,
    round(((p.preco_venda - p.preco_custo) * si.quantidade), 2) AS margem_total,
    s.created_at AS data_venda,
    NULL::character varying AS projeto_codigo,
    NULL::text AS projeto_nome,
    s.cliente
   FROM (((public.separacao_itens si
     JOIN public.produtos p ON ((p.id = si.produto_id)))
     JOIN public.separacoes s ON ((s.id = si.separacao_id)))
     LEFT JOIN public.marcas m ON ((m.id = p.marca_id)))
  WHERE ((si.produto_id IS NOT NULL) AND (s.projeto_id IS NULL));


--
-- Name: revenda_ubiqua id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.revenda_ubiqua ALTER COLUMN id SET DEFAULT nextval('public.revenda_ubiqua_id_seq'::regclass);


--
-- Name: boletos boletos_nosso_numero_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.boletos
    ADD CONSTRAINT boletos_nosso_numero_key UNIQUE (nosso_numero);


--
-- Name: boletos boletos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.boletos
    ADD CONSTRAINT boletos_pkey PRIMARY KEY (id);


--
-- Name: categorias_financeiras categorias_financeiras_nome_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorias_financeiras
    ADD CONSTRAINT categorias_financeiras_nome_key UNIQUE (nome);


--
-- Name: categorias_financeiras categorias_financeiras_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorias_financeiras
    ADD CONSTRAINT categorias_financeiras_pkey PRIMARY KEY (id);


--
-- Name: categorias_produto categorias_produto_codigo_connect_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorias_produto
    ADD CONSTRAINT categorias_produto_codigo_connect_key UNIQUE (codigo_connect);


--
-- Name: categorias_produto categorias_produto_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorias_produto
    ADD CONSTRAINT categorias_produto_pkey PRIMARY KEY (id);


--
-- Name: contas_bancarias contas_bancarias_codigo_connect_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contas_bancarias
    ADD CONSTRAINT contas_bancarias_codigo_connect_key UNIQUE (codigo_connect);


--
-- Name: contas_bancarias contas_bancarias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contas_bancarias
    ADD CONSTRAINT contas_bancarias_pkey PRIMARY KEY (id);


--
-- Name: contato_origens contato_origens_origem_codigo_legado_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contato_origens
    ADD CONSTRAINT contato_origens_origem_codigo_legado_key UNIQUE (origem, codigo_legado);


--
-- Name: contato_origens contato_origens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contato_origens
    ADD CONSTRAINT contato_origens_pkey PRIMARY KEY (id);


--
-- Name: contato_tipos contato_tipos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contato_tipos
    ADD CONSTRAINT contato_tipos_pkey PRIMARY KEY (contato_id, tipo);


--
-- Name: contatos contatos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contatos
    ADD CONSTRAINT contatos_pkey PRIMARY KEY (id);


--
-- Name: contatos_revisao contatos_revisao_id_a_id_b_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contatos_revisao
    ADD CONSTRAINT contatos_revisao_id_a_id_b_key UNIQUE (id_a, id_b);


--
-- Name: contatos_revisao contatos_revisao_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contatos_revisao
    ADD CONSTRAINT contatos_revisao_pkey PRIMARY KEY (id);


--
-- Name: controle_falta controle_ponto_funcionario_id_data_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.controle_falta
    ADD CONSTRAINT controle_ponto_funcionario_id_data_key UNIQUE (funcionario_id, data);


--
-- Name: controle_falta controle_ponto_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.controle_falta
    ADD CONSTRAINT controle_ponto_pkey PRIMARY KEY (id);


--
-- Name: custos_recorrentes_lancamentos custos_recorrentes_lancamentos_custo_id_competencia_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custos_recorrentes_lancamentos
    ADD CONSTRAINT custos_recorrentes_lancamentos_custo_id_competencia_key UNIQUE (custo_id, competencia);


--
-- Name: custos_recorrentes_lancamentos custos_recorrentes_lancamentos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custos_recorrentes_lancamentos
    ADD CONSTRAINT custos_recorrentes_lancamentos_pkey PRIMARY KEY (id);


--
-- Name: custos_recorrentes custos_recorrentes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custos_recorrentes
    ADD CONSTRAINT custos_recorrentes_pkey PRIMARY KEY (id);


--
-- Name: departamentos departamentos_nome_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departamentos
    ADD CONSTRAINT departamentos_nome_key UNIQUE (nome);


--
-- Name: departamentos departamentos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departamentos
    ADD CONSTRAINT departamentos_pkey PRIMARY KEY (id);


--
-- Name: empresa_ubiqua empresa_ubiqua_cnpj_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.empresa_ubiqua
    ADD CONSTRAINT empresa_ubiqua_cnpj_key UNIQUE (cnpj);


--
-- Name: empresa_ubiqua empresa_ubiqua_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.empresa_ubiqua
    ADD CONSTRAINT empresa_ubiqua_pkey PRIMARY KEY (id);


--
-- Name: empresas empresas_cnpj_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.empresas
    ADD CONSTRAINT empresas_cnpj_key UNIQUE (cnpj);


--
-- Name: empresas empresas_codigo_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.empresas
    ADD CONSTRAINT empresas_codigo_key UNIQUE (codigo);


--
-- Name: empresas empresas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.empresas
    ADD CONSTRAINT empresas_pkey PRIMARY KEY (id);


--
-- Name: entregas_finalizadas entregas_finalizadas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entregas_finalizadas
    ADD CONSTRAINT entregas_finalizadas_pkey PRIMARY KEY (id);


--
-- Name: entregas entregas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entregas
    ADD CONSTRAINT entregas_pkey PRIMARY KEY (id);


--
-- Name: estoque_itens estoque_itens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estoque_itens
    ADD CONSTRAINT estoque_itens_pkey PRIMARY KEY (id);


--
-- Name: estoque_itens estoque_itens_produto_id_local_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estoque_itens
    ADD CONSTRAINT estoque_itens_produto_id_local_key UNIQUE (produto_id, local);


--
-- Name: ferias ferias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ferias
    ADD CONSTRAINT ferias_pkey PRIMARY KEY (id);


--
-- Name: folha_pagamento folha_pagamento_funcionario_id_mes_ano_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folha_pagamento
    ADD CONSTRAINT folha_pagamento_funcionario_id_mes_ano_key UNIQUE (funcionario_id, mes, ano);


--
-- Name: folha_pagamento folha_pagamento_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folha_pagamento
    ADD CONSTRAINT folha_pagamento_pkey PRIMARY KEY (id);


--
-- Name: fornecedores fornecedores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fornecedores
    ADD CONSTRAINT fornecedores_pkey PRIMARY KEY (id);


--
-- Name: funcionarios_beneficios_empresas funcionarios_beneficios_empresas_funcionario_id_empresa_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.funcionarios_beneficios_empresas
    ADD CONSTRAINT funcionarios_beneficios_empresas_funcionario_id_empresa_key UNIQUE (funcionario_id, empresa);


--
-- Name: funcionarios_beneficios_empresas funcionarios_beneficios_empresas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.funcionarios_beneficios_empresas
    ADD CONSTRAINT funcionarios_beneficios_empresas_pkey PRIMARY KEY (id);


--
-- Name: funcionarios funcionarios_codigo_legado_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.funcionarios
    ADD CONSTRAINT funcionarios_codigo_legado_key UNIQUE (codigo_legado);


--
-- Name: funcionarios_detalhes funcionarios_detalhes_funcionario_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.funcionarios_detalhes
    ADD CONSTRAINT funcionarios_detalhes_funcionario_id_key UNIQUE (funcionario_id);


--
-- Name: funcionarios_detalhes funcionarios_detalhes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.funcionarios_detalhes
    ADD CONSTRAINT funcionarios_detalhes_pkey PRIMARY KEY (id);


--
-- Name: funcionarios_financeiro funcionarios_financeiro_funcionario_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.funcionarios_financeiro
    ADD CONSTRAINT funcionarios_financeiro_funcionario_id_key UNIQUE (funcionario_id);


--
-- Name: funcionarios_financeiro funcionarios_financeiro_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.funcionarios_financeiro
    ADD CONSTRAINT funcionarios_financeiro_pkey PRIMARY KEY (id);


--
-- Name: funcionarios funcionarios_nm_connect_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.funcionarios
    ADD CONSTRAINT funcionarios_nm_connect_key UNIQUE (nm_connect);


--
-- Name: funcionarios_novo funcionarios_novo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.funcionarios_novo
    ADD CONSTRAINT funcionarios_novo_pkey PRIMARY KEY (id);


--
-- Name: funcionarios funcionarios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.funcionarios
    ADD CONSTRAINT funcionarios_pkey PRIMARY KEY (id);


--
-- Name: historico_status_orcamento historico_status_orcamento_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historico_status_orcamento
    ADD CONSTRAINT historico_status_orcamento_pkey PRIMARY KEY (id);


--
-- Name: historico_status_orcamentos historico_status_orcamentos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historico_status_orcamentos
    ADD CONSTRAINT historico_status_orcamentos_pkey PRIMARY KEY (id);


--
-- Name: informacoes_cliente_ubiqua informacoes_cliente_ubiqua_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.informacoes_cliente_ubiqua
    ADD CONSTRAINT informacoes_cliente_ubiqua_pkey PRIMARY KEY (id);


--
-- Name: itens_orcamento_ubiqua itens_orcamento_ubiqua_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.itens_orcamento_ubiqua
    ADD CONSTRAINT itens_orcamento_ubiqua_pkey PRIMARY KEY (id);


--
-- Name: logs_auditoria logs_auditoria_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.logs_auditoria
    ADD CONSTRAINT logs_auditoria_pkey PRIMARY KEY (id);


--
-- Name: logs_operacoes logs_operacoes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.logs_operacoes
    ADD CONSTRAINT logs_operacoes_pkey PRIMARY KEY (id);


--
-- Name: marcas marcas_codigo_legado_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.marcas
    ADD CONSTRAINT marcas_codigo_legado_key UNIQUE (codigo_legado);


--
-- Name: marcas marcas_nome_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.marcas
    ADD CONSTRAINT marcas_nome_key UNIQUE (nome);


--
-- Name: marcas marcas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.marcas
    ADD CONSTRAINT marcas_pkey PRIMARY KEY (id);


--
-- Name: negociacoes negociacoes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.negociacoes
    ADD CONSTRAINT negociacoes_pkey PRIMARY KEY (id);


--
-- Name: notas_fiscais notas_fiscais_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notas_fiscais
    ADD CONSTRAINT notas_fiscais_pkey PRIMARY KEY (id);


--
-- Name: orcamento_itens orcamento_itens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orcamento_itens
    ADD CONSTRAINT orcamento_itens_pkey PRIMARY KEY (id);


--
-- Name: orcamentos orcamentos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orcamentos
    ADD CONSTRAINT orcamentos_pkey PRIMARY KEY (id);


--
-- Name: orcamentos_revenda_ubiqua orcamentos_revenda_ubiqua_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orcamentos_revenda_ubiqua
    ADD CONSTRAINT orcamentos_revenda_ubiqua_pkey PRIMARY KEY (id);


--
-- Name: pedido_compra pedido_compra_codigo_pedido_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pedido_compra
    ADD CONSTRAINT pedido_compra_codigo_pedido_key UNIQUE (codigo_pedido);


--
-- Name: pedido_compra pedido_compra_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pedido_compra
    ADD CONSTRAINT pedido_compra_pkey PRIMARY KEY (id);


--
-- Name: periodos_aquisitivos periodos_aquisitivos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.periodos_aquisitivos
    ADD CONSTRAINT periodos_aquisitivos_pkey PRIMARY KEY (id);


--
-- Name: plano_de_contas plano_de_contas_codigo_connect_nivel_parent_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plano_de_contas
    ADD CONSTRAINT plano_de_contas_codigo_connect_nivel_parent_id_key UNIQUE (codigo_connect, nivel, parent_id);


--
-- Name: plano_de_contas plano_de_contas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plano_de_contas
    ADD CONSTRAINT plano_de_contas_pkey PRIMARY KEY (id);


--
-- Name: produtos produtos_codigo_legado_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.produtos
    ADD CONSTRAINT produtos_codigo_legado_key UNIQUE (codigo_legado);


--
-- Name: produtos produtos_codigo_produto_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.produtos
    ADD CONSTRAINT produtos_codigo_produto_key UNIQUE (codigo_produto);


--
-- Name: produtos produtos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.produtos
    ADD CONSTRAINT produtos_pkey PRIMARY KEY (id);


--
-- Name: produtos produtos_sku_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.produtos
    ADD CONSTRAINT produtos_sku_key UNIQUE (sku);


--
-- Name: projeto_itens projeto_itens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projeto_itens
    ADD CONSTRAINT projeto_itens_pkey PRIMARY KEY (id);


--
-- Name: projeto_parcelas projeto_parcelas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projeto_parcelas
    ADD CONSTRAINT projeto_parcelas_pkey PRIMARY KEY (id);


--
-- Name: projeto_produtos projeto_produtos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projeto_produtos
    ADD CONSTRAINT projeto_produtos_pkey PRIMARY KEY (id);


--
-- Name: projeto_produtos projeto_produtos_projeto_id_produto_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projeto_produtos
    ADD CONSTRAINT projeto_produtos_projeto_id_produto_id_key UNIQUE (projeto_id, produto_id);


--
-- Name: projeto_sinal projeto_sinal_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projeto_sinal
    ADD CONSTRAINT projeto_sinal_pkey PRIMARY KEY (id);


--
-- Name: projeto_sinal projeto_sinal_projeto_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projeto_sinal
    ADD CONSTRAINT projeto_sinal_projeto_id_key UNIQUE (projeto_id);


--
-- Name: projetos projetos_codigo_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projetos
    ADD CONSTRAINT projetos_codigo_key UNIQUE (codigo);


--
-- Name: projetos projetos_codigo_legado_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projetos
    ADD CONSTRAINT projetos_codigo_legado_key UNIQUE (codigo_legado);


--
-- Name: projetos_fechados projetos_fechados_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projetos_fechados
    ADD CONSTRAINT projetos_fechados_pkey PRIMARY KEY (id);


--
-- Name: projetos projetos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projetos
    ADD CONSTRAINT projetos_pkey PRIMARY KEY (id);


--
-- Name: quote_history quote_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_history
    ADD CONSTRAINT quote_history_pkey PRIMARY KEY (id);


--
-- Name: quotes quotes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotes
    ADD CONSTRAINT quotes_pkey PRIMARY KEY (id);


--
-- Name: remessas remessas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.remessas
    ADD CONSTRAINT remessas_pkey PRIMARY KEY (id);


--
-- Name: retornos_processados retornos_processados_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.retornos_processados
    ADD CONSTRAINT retornos_processados_pkey PRIMARY KEY (id);


--
-- Name: revenda_ubiqua revenda_ubiqua_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.revenda_ubiqua
    ADD CONSTRAINT revenda_ubiqua_pkey PRIMARY KEY (id);


--
-- Name: separacao_arquivos separacao_arquivos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.separacao_arquivos
    ADD CONSTRAINT separacao_arquivos_pkey PRIMARY KEY (id);


--
-- Name: separacao_itens separacao_itens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.separacao_itens
    ADD CONSTRAINT separacao_itens_pkey PRIMARY KEY (id);


--
-- Name: separacoes_arquivos separacoes_arquivos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.separacoes_arquivos
    ADD CONSTRAINT separacoes_arquivos_pkey PRIMARY KEY (id);


--
-- Name: separacoes separacoes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.separacoes
    ADD CONSTRAINT separacoes_pkey PRIMARY KEY (id);


--
-- Name: solicitacoes_compra solicitacoes_compra_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitacoes_compra
    ADD CONSTRAINT solicitacoes_compra_pkey PRIMARY KEY (id);


--
-- Name: sync_history sync_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sync_history
    ADD CONSTRAINT sync_history_pkey PRIMARY KEY (id);


--
-- Name: systems systems_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.systems
    ADD CONSTRAINT systems_pkey PRIMARY KEY (id);


--
-- Name: transacoes transacoes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transacoes
    ADD CONSTRAINT transacoes_pkey PRIMARY KEY (id);


--
-- Name: empresas unique_cnpj; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.empresas
    ADD CONSTRAINT unique_cnpj UNIQUE (cnpj);


--
-- Name: contatos uq_contatos_codigo_legado_tipo; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contatos
    ADD CONSTRAINT uq_contatos_codigo_legado_tipo UNIQUE (codigo_legado, tipo);


--
-- Name: contatos uq_contatos_cpf_cnpj; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contatos
    ADD CONSTRAINT uq_contatos_cpf_cnpj UNIQUE (cpf_cnpj);


--
-- Name: negociacoes uq_negociacoes_empresa_cod_dup_tipo; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.negociacoes
    ADD CONSTRAINT uq_negociacoes_empresa_cod_dup_tipo UNIQUE (empresa_id, cod_duplicata, tipo);


--
-- Name: transacoes uq_transacoes_connect; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transacoes
    ADD CONSTRAINT uq_transacoes_connect UNIQUE (negociacao_id, cod_itens_duplicata);


--
-- Name: user_roles_separacao user_roles_separacao_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles_separacao
    ADD CONSTRAINT user_roles_separacao_email_key UNIQUE (email);


--
-- Name: user_roles_separacao user_roles_separacao_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles_separacao
    ADD CONSTRAINT user_roles_separacao_pkey PRIMARY KEY (id);


--
-- Name: user_system_access user_system_access_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_system_access
    ADD CONSTRAINT user_system_access_pkey PRIMARY KEY (user_id, system_id);


--
-- Name: usuarios usuarios_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_email_key UNIQUE (email);


--
-- Name: usuarios usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id);


--
-- Name: usuarios_ubiqua usuarios_ubiqua_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios_ubiqua
    ADD CONSTRAINT usuarios_ubiqua_email_key UNIQUE (email);


--
-- Name: usuarios_ubiqua usuarios_ubiqua_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios_ubiqua
    ADD CONSTRAINT usuarios_ubiqua_pkey PRIMARY KEY (id);


--
-- Name: vendas vendas_cod_venda_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendas
    ADD CONSTRAINT vendas_cod_venda_key UNIQUE (cod_venda);


--
-- Name: vendas_marca vendas_marca_marca_id_mes_ano_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendas_marca
    ADD CONSTRAINT vendas_marca_marca_id_mes_ano_key UNIQUE (marca_id, mes, ano);


--
-- Name: vendas_marca vendas_marca_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendas_marca
    ADD CONSTRAINT vendas_marca_pkey PRIMARY KEY (id);


--
-- Name: vendas vendas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendas
    ADD CONSTRAINT vendas_pkey PRIMARY KEY (id);


--
-- Name: idx_boletos_orcamento_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_boletos_orcamento_id ON public.boletos USING btree (orcamento_id);


--
-- Name: idx_co_contato_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_co_contato_id ON public.contato_origens USING btree (contato_id);


--
-- Name: idx_co_origem_cod; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_co_origem_cod ON public.contato_origens USING btree (origem, codigo_legado);


--
-- Name: idx_contatos_canonical_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contatos_canonical_id ON public.contatos USING btree (canonical_id);


--
-- Name: idx_contatos_cidade_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contatos_cidade_estado ON public.contatos USING btree (cidade, estado);


--
-- Name: idx_contatos_cnpj; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contatos_cnpj ON public.contatos USING btree (cnpj) WHERE (cnpj IS NOT NULL);


--
-- Name: idx_contatos_cnpj_canonical; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_contatos_cnpj_canonical ON public.contatos USING btree (cnpj) WHERE ((canonical_id IS NULL) AND (cnpj IS NOT NULL));


--
-- Name: idx_contatos_codigo_legado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contatos_codigo_legado ON public.contatos USING btree (codigo_legado, tipo);


--
-- Name: idx_contatos_cpf; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contatos_cpf ON public.contatos USING btree (cpf) WHERE (cpf IS NOT NULL);


--
-- Name: idx_contatos_cpf_canonical; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_contatos_cpf_canonical ON public.contatos USING btree (cpf) WHERE ((canonical_id IS NULL) AND (cpf IS NOT NULL));


--
-- Name: idx_contatos_cpf_cnpj; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contatos_cpf_cnpj ON public.contatos USING btree (cpf_cnpj);


--
-- Name: idx_contatos_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contatos_created_by ON public.contatos USING btree (created_by);


--
-- Name: idx_contatos_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contatos_email ON public.contatos USING btree (email);


--
-- Name: idx_contatos_empresa_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contatos_empresa_id ON public.contatos USING btree (empresa_id);


--
-- Name: idx_contatos_nome; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contatos_nome ON public.contatos USING gin (to_tsvector('portuguese'::regconfig, nome));


--
-- Name: idx_contatos_nome_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contatos_nome_trgm ON public.contatos USING gin (nome extensions.gin_trgm_ops);


--
-- Name: idx_contatos_tipo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contatos_tipo ON public.contatos USING btree (tipo);


--
-- Name: idx_cr_decisao; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cr_decisao ON public.contatos_revisao USING btree (decisao) WHERE (decisao = 'pendente'::text);


--
-- Name: idx_cr_score; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cr_score ON public.contatos_revisao USING btree (score DESC);


--
-- Name: idx_ct_tipo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ct_tipo ON public.contato_tipos USING btree (tipo);


--
-- Name: idx_custos_rec_categoria; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_custos_rec_categoria ON public.custos_recorrentes USING btree (categoria_id);


--
-- Name: idx_custos_rec_conta; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_custos_rec_conta ON public.custos_recorrentes USING btree (conta_id);


--
-- Name: idx_custos_rec_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_custos_rec_created_by ON public.custos_recorrentes USING btree (created_by);


--
-- Name: idx_entregas_data; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_entregas_data ON public.entregas USING btree (data_prevista);


--
-- Name: idx_entregas_entregador; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_entregas_entregador ON public.entregas USING btree (entregador_id);


--
-- Name: idx_entregas_projeto; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_entregas_projeto ON public.entregas USING btree (projeto_id);


--
-- Name: idx_entregas_separacao; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_entregas_separacao ON public.entregas USING btree (separacao_id);


--
-- Name: idx_entregas_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_entregas_status ON public.entregas USING btree (status);


--
-- Name: idx_estoque_atualizado_por; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_estoque_atualizado_por ON public.estoque_itens USING btree (atualizado_por);


--
-- Name: idx_estoque_local; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_estoque_local ON public.estoque_itens USING btree (local);


--
-- Name: idx_estoque_produto; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_estoque_produto ON public.estoque_itens USING btree (produto_id);


--
-- Name: idx_ferias_aprovado_por; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ferias_aprovado_por ON public.ferias USING btree (aprovado_por);


--
-- Name: idx_ferias_funcionario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ferias_funcionario ON public.ferias USING btree (funcionario_id);


--
-- Name: idx_ferias_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ferias_status ON public.ferias USING btree (status);


--
-- Name: idx_folha_empresa_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_folha_empresa_id ON public.folha_pagamento USING btree (empresa_id);


--
-- Name: idx_folha_funcionario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_folha_funcionario ON public.folha_pagamento USING btree (funcionario_id);


--
-- Name: idx_folha_mes_ano; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_folha_mes_ano ON public.folha_pagamento USING btree (ano DESC, mes DESC);


--
-- Name: idx_fornecedores_cnpj; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fornecedores_cnpj ON public.fornecedores USING btree (cnpj_cpf);


--
-- Name: idx_fornecedores_empresa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fornecedores_empresa ON public.fornecedores USING btree (empresa_id);


--
-- Name: idx_fornecedores_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fornecedores_status ON public.fornecedores USING btree (status);


--
-- Name: idx_func_departamento; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_func_departamento ON public.funcionarios USING btree (departamento_id);


--
-- Name: idx_func_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_func_status ON public.funcionarios USING btree (status);


--
-- Name: idx_func_usuario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_func_usuario ON public.funcionarios USING btree (usuario_id);


--
-- Name: idx_funcionarios_ativo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_funcionarios_ativo ON public.funcionarios_novo USING btree (ativo);


--
-- Name: idx_funcionarios_beneficios_empresa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_funcionarios_beneficios_empresa ON public.funcionarios_beneficios_empresas USING btree (empresa);


--
-- Name: idx_funcionarios_beneficios_func_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_funcionarios_beneficios_func_id ON public.funcionarios_beneficios_empresas USING btree (funcionario_id);


--
-- Name: idx_funcionarios_codigo_legado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_funcionarios_codigo_legado ON public.funcionarios USING btree (codigo_legado);


--
-- Name: idx_funcionarios_detalhes_cpf; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_funcionarios_detalhes_cpf ON public.funcionarios_detalhes USING btree (cpf);


--
-- Name: idx_funcionarios_empresa_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_funcionarios_empresa_id ON public.funcionarios USING btree (empresa_id);


--
-- Name: idx_funcionarios_financeiro_func_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_funcionarios_financeiro_func_id ON public.funcionarios_financeiro USING btree (funcionario_id);


--
-- Name: idx_funcionarios_nm_connect; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_funcionarios_nm_connect ON public.funcionarios USING btree (nm_connect);


--
-- Name: idx_historico_data; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_historico_data ON public.historico_status_orcamento USING btree (created_at DESC);


--
-- Name: idx_historico_orcamento; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_historico_orcamento ON public.historico_status_orcamento USING btree (orcamento_id);


--
-- Name: idx_historico_status_orcamentos_data; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_historico_status_orcamentos_data ON public.historico_status_orcamentos USING btree (created_at DESC);


--
-- Name: idx_historico_status_orcamentos_orcamento; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_historico_status_orcamentos_orcamento ON public.historico_status_orcamentos USING btree (orcamento_id);


--
-- Name: idx_itens_orcamento; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_itens_orcamento ON public.itens_orcamento_ubiqua USING btree (orcamento_id);


--
-- Name: idx_itens_ordem; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_itens_ordem ON public.itens_orcamento_ubiqua USING btree (orcamento_id, ordem);


--
-- Name: idx_itens_produto; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_itens_produto ON public.itens_orcamento_ubiqua USING btree (produto_id);


--
-- Name: idx_lanc_competencia; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lanc_competencia ON public.custos_recorrentes_lancamentos USING btree (competencia DESC);


--
-- Name: idx_lanc_custo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lanc_custo ON public.custos_recorrentes_lancamentos USING btree (custo_id);


--
-- Name: idx_lanc_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lanc_status ON public.custos_recorrentes_lancamentos USING btree (status);


--
-- Name: idx_lanc_transacao; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lanc_transacao ON public.custos_recorrentes_lancamentos USING btree (transacao_id);


--
-- Name: idx_lanc_vencimento; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lanc_vencimento ON public.custos_recorrentes_lancamentos USING btree (data_vencimento);


--
-- Name: idx_logs_auditoria_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_logs_auditoria_created ON public.logs_auditoria USING btree (created_at DESC);


--
-- Name: idx_logs_auditoria_registro; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_logs_auditoria_registro ON public.logs_auditoria USING btree (registro_id);


--
-- Name: idx_logs_auditoria_tabela; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_logs_auditoria_tabela ON public.logs_auditoria USING btree (tabela);


--
-- Name: idx_logs_auditoria_usuario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_logs_auditoria_usuario ON public.logs_auditoria USING btree (usuario_id);


--
-- Name: idx_neg_cod_duplicata; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_neg_cod_duplicata ON public.negociacoes USING btree (cod_duplicata);


--
-- Name: idx_neg_cod_pessoa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_neg_cod_pessoa ON public.negociacoes USING btree (cod_pessoa);


--
-- Name: idx_neg_contato_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_neg_contato_id ON public.negociacoes USING btree (contato_id);


--
-- Name: idx_neg_dev_troca; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_neg_dev_troca ON public.negociacoes USING btree (dev_troca) WHERE (dev_troca = true);


--
-- Name: idx_neg_empresa_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_neg_empresa_id ON public.negociacoes USING btree (empresa_id);


--
-- Name: idx_neg_funcionario_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_neg_funcionario_id ON public.negociacoes USING btree (funcionario_id);


--
-- Name: idx_neg_plano_contas_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_neg_plano_contas_id ON public.negociacoes USING btree (plano_contas_id);


--
-- Name: idx_neg_projeto_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_neg_projeto_id ON public.negociacoes USING btree (projeto_id);


--
-- Name: idx_neg_tipo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_neg_tipo ON public.negociacoes USING btree (tipo);


--
-- Name: idx_notas_fiscais_orcamento_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notas_fiscais_orcamento_id ON public.notas_fiscais USING btree (orcamento_id);


--
-- Name: idx_orcamentos_cliente; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orcamentos_cliente ON public.orcamentos_revenda_ubiqua USING btree (cliente_id);


--
-- Name: idx_orcamentos_data_criacao; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orcamentos_data_criacao ON public.orcamentos_revenda_ubiqua USING btree (created_at DESC);


--
-- Name: idx_orcamentos_data_validade; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orcamentos_data_validade ON public.orcamentos_revenda_ubiqua USING btree (data_validade);


--
-- Name: idx_orcamentos_numero; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orcamentos_numero ON public.orcamentos_revenda_ubiqua USING btree (numero_orcamento);


--
-- Name: idx_orcamentos_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orcamentos_status ON public.orcamentos_revenda_ubiqua USING btree (status);


--
-- Name: idx_parcelas_projeto; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_parcelas_projeto ON public.projeto_parcelas USING btree (projeto_id);


--
-- Name: idx_parcelas_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_parcelas_status ON public.projeto_parcelas USING btree (status);


--
-- Name: idx_parcelas_transacao; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_parcelas_transacao ON public.projeto_parcelas USING btree (transacao_id);


--
-- Name: idx_parcelas_vencimento; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_parcelas_vencimento ON public.projeto_parcelas USING btree (data_vencimento);


--
-- Name: idx_pedido_compra_codigo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pedido_compra_codigo ON public.pedido_compra USING btree (codigo_pedido);


--
-- Name: idx_pedido_compra_data; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pedido_compra_data ON public.pedido_compra USING btree (data_emissao);


--
-- Name: idx_pedido_compra_fornecedor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pedido_compra_fornecedor ON public.pedido_compra USING btree (cod_fornecedor);


--
-- Name: idx_pi_produto; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pi_produto ON public.projeto_itens USING btree (produto_id);


--
-- Name: idx_pi_projeto; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pi_projeto ON public.projeto_itens USING btree (projeto_id);


--
-- Name: idx_pi_validado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pi_validado ON public.projeto_itens USING btree (projeto_id, validado);


--
-- Name: idx_plano_cod_nivel; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_plano_cod_nivel ON public.plano_de_contas USING btree (codigo_connect, nivel);


--
-- Name: idx_plano_nivel; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_plano_nivel ON public.plano_de_contas USING btree (nivel);


--
-- Name: idx_plano_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_plano_parent ON public.plano_de_contas USING btree (parent_id);


--
-- Name: idx_ponto_data; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ponto_data ON public.controle_falta USING btree (data DESC);


--
-- Name: idx_ponto_funcionario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ponto_funcionario ON public.controle_falta USING btree (funcionario_id);


--
-- Name: idx_prod_categoria; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_prod_categoria ON public.produtos USING btree (categoria);


--
-- Name: idx_prod_marca; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_prod_marca ON public.produtos USING btree (marca_id);


--
-- Name: idx_prod_sku; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_prod_sku ON public.produtos USING btree (sku);


--
-- Name: idx_produtos_ativo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_produtos_ativo ON public.produtos USING btree (ativo);


--
-- Name: idx_produtos_categoria_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_produtos_categoria_id ON public.produtos USING btree (categoria_id);


--
-- Name: idx_produtos_codigo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_produtos_codigo ON public.produtos USING btree (codigo_produto);


--
-- Name: idx_produtos_codigo_legado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_produtos_codigo_legado ON public.produtos USING btree (codigo_legado);


--
-- Name: idx_produtos_fornecedor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_produtos_fornecedor_id ON public.produtos USING btree (fornecedor_principal_id);


--
-- Name: idx_produtos_marca_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_produtos_marca_id ON public.produtos USING btree (marca_id);


--
-- Name: idx_produtos_ncm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_produtos_ncm ON public.produtos USING btree (ncm);


--
-- Name: idx_produtos_referencia; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_produtos_referencia ON public.produtos USING btree (referencia);


--
-- Name: idx_projeto_itens_orcamento_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projeto_itens_orcamento_id ON public.projeto_itens USING btree (orcamento_id);


--
-- Name: idx_projeto_parcelas_orcamento_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projeto_parcelas_orcamento_id ON public.projeto_parcelas USING btree (orcamento_id);


--
-- Name: idx_projeto_produtos_produto; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projeto_produtos_produto ON public.projeto_produtos USING btree (produto_id);


--
-- Name: idx_projeto_produtos_projeto; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projeto_produtos_projeto ON public.projeto_produtos USING btree (projeto_id);


--
-- Name: idx_projetos_area_do_projeto_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projetos_area_do_projeto_gin ON public.projetos USING gin (area_do_projeto);


--
-- Name: idx_projetos_arquiteto; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projetos_arquiteto ON public.projetos USING btree (arquiteto_id);


--
-- Name: idx_projetos_arquivado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projetos_arquivado ON public.projetos USING btree (arquivado);


--
-- Name: idx_projetos_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projetos_client_id ON public.projetos USING btree (client_id);


--
-- Name: idx_projetos_cliente_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projetos_cliente_id ON public.projetos USING btree (cliente_id);


--
-- Name: idx_projetos_codigo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projetos_codigo ON public.projetos USING btree (codigo);


--
-- Name: idx_projetos_codigo_legado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projetos_codigo_legado ON public.projetos USING btree (codigo_legado);


--
-- Name: idx_projetos_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projetos_created_by ON public.projetos USING btree (created_by);


--
-- Name: idx_projetos_data_entrada; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projetos_data_entrada ON public.projetos USING btree (data_entrada);


--
-- Name: idx_projetos_empresa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projetos_empresa ON public.projetos USING btree (empresa_id);


--
-- Name: idx_projetos_empresa_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projetos_empresa_status ON public.projetos USING btree (empresa_id, status);


--
-- Name: idx_projetos_nivel; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projetos_nivel ON public.projetos USING btree (nivel_estrategico);


--
-- Name: idx_projetos_nome; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projetos_nome ON public.projetos USING gin (to_tsvector('portuguese'::regconfig, nome));


--
-- Name: idx_projetos_resp_obra; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projetos_resp_obra ON public.projetos USING btree (responsavel_obra_id);


--
-- Name: idx_projetos_responsavel; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projetos_responsavel ON public.projetos USING btree (responsavel_id);


--
-- Name: idx_projetos_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projetos_status ON public.projetos USING btree (status);


--
-- Name: idx_projetos_tipo_projeto; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projetos_tipo_projeto ON public.projetos USING btree (((area_do_projeto ->> 'tipo'::text)));


--
-- Name: idx_remessas_empresa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_remessas_empresa ON public.remessas USING btree (empresa_id);


--
-- Name: idx_remessas_fornecedor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_remessas_fornecedor ON public.remessas USING btree (fornecedor_id);


--
-- Name: idx_remessas_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_remessas_status ON public.remessas USING btree (status);


--
-- Name: idx_remessas_vencimento; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_remessas_vencimento ON public.remessas USING btree (vencimento);


--
-- Name: idx_revenda_ubiqua_cod_marca; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_revenda_ubiqua_cod_marca ON public.revenda_ubiqua USING btree (cod_marca);


--
-- Name: idx_revenda_ubiqua_cod_produto; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_revenda_ubiqua_cod_produto ON public.revenda_ubiqua USING btree (cod_produto);


--
-- Name: idx_revenda_ubiqua_referencia; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_revenda_ubiqua_referencia ON public.revenda_ubiqua USING btree (referencia);


--
-- Name: idx_revenda_ubiqua_referencia_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_revenda_ubiqua_referencia_unique ON public.revenda_ubiqua USING btree (lower(TRIM(BOTH FROM referencia)));


--
-- Name: idx_revenda_ubiqua_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_revenda_ubiqua_slug ON public.revenda_ubiqua USING btree (slug);


--
-- Name: idx_sep_cliente_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sep_cliente_id ON public.separacoes USING btree (cliente_id);


--
-- Name: idx_sep_data_entrega; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sep_data_entrega ON public.separacoes USING btree (data_entrega);


--
-- Name: idx_sep_itens_produto; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sep_itens_produto ON public.separacao_itens USING btree (produto_id);


--
-- Name: idx_sep_itens_separacao; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sep_itens_separacao ON public.separacao_itens USING btree (separacao_id);


--
-- Name: idx_sep_projeto; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sep_projeto ON public.separacoes USING btree (projeto_id);


--
-- Name: idx_sep_responsavel; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sep_responsavel ON public.separacoes USING btree (responsavel_id);


--
-- Name: idx_sep_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sep_status ON public.separacoes USING btree (status);


--
-- Name: idx_sinal_projeto; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sinal_projeto ON public.projeto_sinal USING btree (projeto_id);


--
-- Name: idx_sinal_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sinal_status ON public.projeto_sinal USING btree (status);


--
-- Name: idx_sinal_transacao; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sinal_transacao ON public.projeto_sinal USING btree (transacao_id);


--
-- Name: idx_staging_cp_cod_venda; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_staging_cp_cod_venda ON public.staging_conta_pagar USING btree (cod_venda);


--
-- Name: idx_staging_cp_processado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_staging_cp_processado ON public.staging_conta_pagar USING btree (processado);


--
-- Name: idx_staging_cr_cod_venda; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_staging_cr_cod_venda ON public.staging_conta_receber USING btree (cod_venda);


--
-- Name: idx_staging_cr_processado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_staging_cr_processado ON public.staging_conta_receber USING btree (processado);


--
-- Name: idx_staging_pc_codigo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_staging_pc_codigo ON public.staging_pedido_compra USING btree (codigo_pedido);


--
-- Name: idx_staging_pc_processado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_staging_pc_processado ON public.staging_pedido_compra USING btree (processado);


--
-- Name: idx_staging_prod_codigo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_staging_prod_codigo ON public.staging_produtos USING btree (codproduto);


--
-- Name: idx_staging_prod_processado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_staging_prod_processado ON public.staging_produtos USING btree (processado);


--
-- Name: idx_sync_executado_por; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sync_executado_por ON public.sync_history USING btree (executado_por);


--
-- Name: idx_sync_history_data; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sync_history_data ON public.sync_history USING btree (created_at DESC);


--
-- Name: idx_tr_dt_vencimento; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tr_dt_vencimento ON public.transacoes USING btree (dt_vencimento);


--
-- Name: idx_tr_funcionario_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tr_funcionario_id ON public.transacoes USING btree (funcionario_id);


--
-- Name: idx_tr_negociacao_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tr_negociacao_id ON public.transacoes USING btree (negociacao_id);


--
-- Name: idx_tr_status_pago; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tr_status_pago ON public.transacoes USING btree (status_pago);


--
-- Name: idx_tr_tipo_pagamento; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tr_tipo_pagamento ON public.transacoes USING btree (tipo_pagamento);


--
-- Name: idx_trans_categoria_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_trans_categoria_id ON public.transacoes USING btree (categoria_id);


--
-- Name: idx_trans_conta; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_trans_conta ON public.transacoes USING btree (conta_id);


--
-- Name: idx_trans_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_trans_created_by ON public.transacoes USING btree (created_by);


--
-- Name: idx_trans_data; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_trans_data ON public.transacoes USING btree (data_transacao DESC);


--
-- Name: idx_trans_parcela; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_trans_parcela ON public.transacoes USING btree (parcela_id);


--
-- Name: idx_trans_projeto; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_trans_projeto ON public.transacoes USING btree (projeto_id);


--
-- Name: idx_trans_tipo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_trans_tipo ON public.transacoes USING btree (tipo);


--
-- Name: idx_transacoes_empresa_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transacoes_empresa_id ON public.transacoes USING btree (empresa_id);


--
-- Name: idx_usuarios_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_usuarios_email ON public.usuarios USING btree (email);


--
-- Name: idx_usuarios_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_usuarios_role ON public.usuarios USING btree (role);


--
-- Name: idx_vendas_cod_venda; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendas_cod_venda ON public.vendas USING btree (cod_venda);


--
-- Name: idx_vendas_data_emissao; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendas_data_emissao ON public.vendas USING btree (data_emissao);


--
-- Name: idx_vendas_projeto_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendas_projeto_id ON public.vendas USING btree (projeto_id);


--
-- Name: idx_vendas_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendas_status ON public.vendas USING btree (status_pagamento);


--
-- Name: produtos_sku_unique_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX produtos_sku_unique_idx ON public.produtos USING btree (sku) WHERE (sku IS NOT NULL);


--
-- Name: projeto_parcelas_orcamento_numero_uniq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX projeto_parcelas_orcamento_numero_uniq ON public.projeto_parcelas USING btree (orcamento_id, numero_parcela) WHERE (orcamento_id IS NOT NULL);


--
-- Name: projeto_parcelas_projeto_numero_legado_uniq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX projeto_parcelas_projeto_numero_legado_uniq ON public.projeto_parcelas USING btree (projeto_id, numero_parcela) WHERE (orcamento_id IS NULL);


--
-- Name: contas_bancarias contas_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER contas_updated_at BEFORE UPDATE ON public.contas_bancarias FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: contatos contatos_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER contatos_updated_at BEFORE UPDATE ON public.contatos FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: custos_recorrentes custos_rec_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER custos_rec_updated_at BEFORE UPDATE ON public.custos_recorrentes FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: entregas entregas_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER entregas_updated_at BEFORE UPDATE ON public.entregas FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: funcionarios funcionarios_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER funcionarios_updated_at BEFORE UPDATE ON public.funcionarios FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: contatos on_contato_created; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER on_contato_created AFTER INSERT OR UPDATE ON public.contatos FOR EACH ROW EXECUTE FUNCTION public.handle_contato_tipo();


--
-- Name: produtos produtos_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER produtos_updated_at BEFORE UPDATE ON public.produtos FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: projeto_itens projeto_itens_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER projeto_itens_updated_at BEFORE UPDATE ON public.projeto_itens FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: projeto_sinal projeto_sinal_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER projeto_sinal_updated_at BEFORE UPDATE ON public.projeto_sinal FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: projetos projetos_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER projetos_updated_at BEFORE UPDATE ON public.projetos FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: separacoes separacoes_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER separacoes_updated_at BEFORE UPDATE ON public.separacoes FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: produtos trg_atualizar_preco_venda; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_atualizar_preco_venda BEFORE INSERT OR UPDATE OF preco_custo, porc_desconto, icms_entrada, ipi_entrada, porc_despesas ON public.produtos FOR EACH ROW EXECUTE FUNCTION public.fn_atualizar_preco_venda();


--
-- Name: produtos trg_calculo_preco_venda; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_calculo_preco_venda BEFORE INSERT OR UPDATE ON public.produtos FOR EACH ROW EXECUTE FUNCTION public.fn_atualizar_preco_venda();


--
-- Name: projetos trg_fechar_projeto; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_fechar_projeto AFTER UPDATE OF status ON public.projetos FOR EACH ROW EXECUTE FUNCTION public.trigger_fechar_projeto();


--
-- Name: fornecedores trg_fornecedores_auditoria; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_fornecedores_auditoria AFTER INSERT OR DELETE OR UPDATE ON public.fornecedores FOR EACH ROW EXECUTE FUNCTION public.fn_log_auditoria();


--
-- Name: fornecedores trg_fornecedores_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_fornecedores_updated_at BEFORE UPDATE ON public.fornecedores FOR EACH ROW EXECUTE FUNCTION public.fn_atualiza_updated_at();


--
-- Name: projetos trg_gerenciar_fluxo_projeto; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_gerenciar_fluxo_projeto AFTER UPDATE ON public.projetos FOR EACH ROW EXECUTE FUNCTION public.gerenciar_fluxo_projeto();


--
-- Name: contatos trg_propagate_contato_nome; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_propagate_contato_nome AFTER UPDATE OF nome ON public.contatos FOR EACH ROW EXECUTE FUNCTION public.propagate_contato_nome();


--
-- Name: projetos trg_propagate_projeto_codigo; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_propagate_projeto_codigo AFTER UPDATE OF codigo ON public.projetos FOR EACH ROW EXECUTE FUNCTION public.propagate_projeto_codigo();


--
-- Name: usuarios trg_propagate_usuario_nome; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_propagate_usuario_nome AFTER UPDATE OF nome ON public.usuarios FOR EACH ROW EXECUTE FUNCTION public.propagate_usuario_nome();


--
-- Name: projetos trg_proteger_fechamento; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_proteger_fechamento BEFORE UPDATE OF status ON public.projetos FOR EACH ROW EXECUTE FUNCTION public.trigger_proteger_fechamento();


--
-- Name: projeto_parcelas trg_proteger_parcelas; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_proteger_parcelas BEFORE INSERT ON public.projeto_parcelas FOR EACH ROW EXECUTE FUNCTION public.trigger_proteger_parcelas();


--
-- Name: remessas trg_remessas_auditoria; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_remessas_auditoria AFTER INSERT OR DELETE OR UPDATE ON public.remessas FOR EACH ROW EXECUTE FUNCTION public.fn_log_auditoria();


--
-- Name: remessas trg_remessas_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_remessas_updated_at BEFORE UPDATE ON public.remessas FOR EACH ROW EXECUTE FUNCTION public.fn_atualiza_updated_at();


--
-- Name: projetos trg_reserva_estoque; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_reserva_estoque AFTER UPDATE OF status ON public.projetos FOR EACH ROW EXECUTE FUNCTION public.trigger_reserva_estoque();


--
-- Name: revenda_ubiqua trg_revenda_ubiqua_slug; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_revenda_ubiqua_slug BEFORE INSERT OR UPDATE OF desc_produto, descricao, valor_revenda ON public.revenda_ubiqua FOR EACH ROW EXECUTE FUNCTION public.trigger_update_revenda_ubiqua_slug();


--
-- Name: separacoes trg_separacao_pronta; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_separacao_pronta AFTER UPDATE OF status, data_entrega ON public.separacoes FOR EACH ROW EXECUTE FUNCTION public.trigger_separacao_pronta();


--
-- Name: projeto_itens trg_set_projeto_itens_descricao; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_projeto_itens_descricao BEFORE INSERT OR UPDATE ON public.projeto_itens FOR EACH ROW EXECUTE FUNCTION public.set_projeto_itens_descricao();


--
-- Name: projetos trg_sync_responsavel_nome; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_sync_responsavel_nome BEFORE INSERT OR UPDATE OF responsavel_id ON public.projetos FOR EACH ROW EXECUTE FUNCTION public.sync_responsavel_nome();


--
-- Name: separacoes trg_sync_sep_cliente; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_sync_sep_cliente BEFORE INSERT OR UPDATE OF cliente_id ON public.separacoes FOR EACH ROW EXECUTE FUNCTION public.sync_separacao_cliente();


--
-- Name: separacoes trg_sync_sep_codigo_obra; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_sync_sep_codigo_obra BEFORE INSERT OR UPDATE OF projeto_id ON public.separacoes FOR EACH ROW EXECUTE FUNCTION public.sync_separacao_codigo_obra();


--
-- Name: projeto_itens trg_sync_valor_total; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_sync_valor_total AFTER INSERT OR DELETE OR UPDATE ON public.projeto_itens FOR EACH ROW EXECUTE FUNCTION public.sync_projeto_valor_total();


--
-- Name: separacoes trg_track_reagendamento; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_track_reagendamento BEFORE UPDATE OF data_entrega ON public.separacoes FOR EACH ROW EXECUTE FUNCTION public.track_reagendamento();


--
-- Name: orcamentos_revenda_ubiqua trigger_auto_numero_orcamento; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_auto_numero_orcamento BEFORE INSERT ON public.orcamentos_revenda_ubiqua FOR EACH ROW EXECUTE FUNCTION public.fn_auto_numero_orcamento();


--
-- Name: orcamentos_revenda_ubiqua trigger_orcamento_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_orcamento_updated_at BEFORE UPDATE ON public.orcamentos_revenda_ubiqua FOR EACH ROW EXECUTE FUNCTION public.fn_update_orcamento_timestamp();


--
-- Name: revenda_ubiqua trigger_revenda_ubiqua_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_revenda_ubiqua_updated_at BEFORE UPDATE ON public.revenda_ubiqua FOR EACH ROW EXECUTE FUNCTION public.update_revenda_ubiqua_updated_at();


--
-- Name: orcamentos trigger_set_orcamento_numero; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_set_orcamento_numero BEFORE INSERT ON public.orcamentos FOR EACH ROW EXECUTE FUNCTION public.set_orcamento_numero();


--
-- Name: projeto_parcelas update_parcelas_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_parcelas_updated_at BEFORE UPDATE ON public.projeto_parcelas FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: produtos update_produtos_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_produtos_updated_at BEFORE UPDATE ON public.produtos FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: projetos update_projetos_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_projetos_updated_at BEFORE UPDATE ON public.projetos FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: vendas update_vendas_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_vendas_updated_at BEFORE UPDATE ON public.vendas FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: usuarios usuarios_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER usuarios_updated_at BEFORE UPDATE ON public.usuarios FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: boletos boletos_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.boletos
    ADD CONSTRAINT boletos_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id);


--
-- Name: boletos boletos_orcamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.boletos
    ADD CONSTRAINT boletos_orcamento_id_fkey FOREIGN KEY (orcamento_id) REFERENCES public.orcamentos(id) ON DELETE SET NULL;


--
-- Name: boletos boletos_parcela_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.boletos
    ADD CONSTRAINT boletos_parcela_id_fkey FOREIGN KEY (parcela_id) REFERENCES public.projeto_parcelas(id);


--
-- Name: contas_bancarias contas_bancarias_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contas_bancarias
    ADD CONSTRAINT contas_bancarias_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id);


--
-- Name: contato_origens contato_origens_contato_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contato_origens
    ADD CONSTRAINT contato_origens_contato_id_fkey FOREIGN KEY (contato_id) REFERENCES public.contatos(id) ON DELETE CASCADE;


--
-- Name: contato_tipos contato_tipos_contato_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contato_tipos
    ADD CONSTRAINT contato_tipos_contato_id_fkey FOREIGN KEY (contato_id) REFERENCES public.contatos(id) ON DELETE CASCADE;


--
-- Name: contatos contatos_canonical_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contatos
    ADD CONSTRAINT contatos_canonical_id_fkey FOREIGN KEY (canonical_id) REFERENCES public.contatos(id);


--
-- Name: contatos contatos_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contatos
    ADD CONSTRAINT contatos_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: contatos contatos_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contatos
    ADD CONSTRAINT contatos_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.contatos(id);


--
-- Name: contatos_revisao contatos_revisao_id_a_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contatos_revisao
    ADD CONSTRAINT contatos_revisao_id_a_fkey FOREIGN KEY (id_a) REFERENCES public.contatos(id);


--
-- Name: contatos_revisao contatos_revisao_id_b_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contatos_revisao
    ADD CONSTRAINT contatos_revisao_id_b_fkey FOREIGN KEY (id_b) REFERENCES public.contatos(id);


--
-- Name: contatos contatos_vendedor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contatos
    ADD CONSTRAINT contatos_vendedor_id_fkey FOREIGN KEY (vendedor_id) REFERENCES auth.users(id);


--
-- Name: contatos contatos_vendedor_padrao_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contatos
    ADD CONSTRAINT contatos_vendedor_padrao_id_fkey FOREIGN KEY (vendedor_padrao_id) REFERENCES auth.users(id);


--
-- Name: controle_falta controle_ponto_funcionario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.controle_falta
    ADD CONSTRAINT controle_ponto_funcionario_id_fkey FOREIGN KEY (funcionario_id) REFERENCES public.funcionarios(id) ON DELETE CASCADE;


--
-- Name: custos_recorrentes custos_recorrentes_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custos_recorrentes
    ADD CONSTRAINT custos_recorrentes_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorias_financeiras(id) ON DELETE SET NULL;


--
-- Name: custos_recorrentes custos_recorrentes_conta_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custos_recorrentes
    ADD CONSTRAINT custos_recorrentes_conta_id_fkey FOREIGN KEY (conta_id) REFERENCES public.contas_bancarias(id) ON DELETE SET NULL;


--
-- Name: custos_recorrentes custos_recorrentes_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custos_recorrentes
    ADD CONSTRAINT custos_recorrentes_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: custos_recorrentes_lancamentos custos_recorrentes_lancamentos_custo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custos_recorrentes_lancamentos
    ADD CONSTRAINT custos_recorrentes_lancamentos_custo_id_fkey FOREIGN KEY (custo_id) REFERENCES public.custos_recorrentes(id) ON DELETE CASCADE;


--
-- Name: custos_recorrentes_lancamentos custos_recorrentes_lancamentos_transacao_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custos_recorrentes_lancamentos
    ADD CONSTRAINT custos_recorrentes_lancamentos_transacao_id_fkey FOREIGN KEY (transacao_id) REFERENCES public.transacoes(id) ON DELETE SET NULL;


--
-- Name: entregas entregas_entregador_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entregas
    ADD CONSTRAINT entregas_entregador_id_fkey FOREIGN KEY (entregador_id) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: entregas entregas_projeto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entregas
    ADD CONSTRAINT entregas_projeto_id_fkey FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE SET NULL;


--
-- Name: entregas entregas_separacao_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entregas
    ADD CONSTRAINT entregas_separacao_id_fkey FOREIGN KEY (separacao_id) REFERENCES public.separacoes(id) ON DELETE SET NULL;


--
-- Name: estoque_itens estoque_itens_atualizado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estoque_itens
    ADD CONSTRAINT estoque_itens_atualizado_por_fkey FOREIGN KEY (atualizado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: estoque_itens estoque_itens_produto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estoque_itens
    ADD CONSTRAINT estoque_itens_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id) ON DELETE CASCADE;


--
-- Name: ferias ferias_aprovado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ferias
    ADD CONSTRAINT ferias_aprovado_por_fkey FOREIGN KEY (aprovado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: ferias ferias_funcionario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ferias
    ADD CONSTRAINT ferias_funcionario_id_fkey FOREIGN KEY (funcionario_id) REFERENCES public.funcionarios(id) ON DELETE CASCADE;


--
-- Name: ferias ferias_periodo_aquisitivo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ferias
    ADD CONSTRAINT ferias_periodo_aquisitivo_id_fkey FOREIGN KEY (periodo_aquisitivo_id) REFERENCES public.periodos_aquisitivos(id) ON DELETE SET NULL;


--
-- Name: revenda_ubiqua fk_empresa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.revenda_ubiqua
    ADD CONSTRAINT fk_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresas(id);


--
-- Name: folha_pagamento folha_pagamento_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folha_pagamento
    ADD CONSTRAINT folha_pagamento_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id);


--
-- Name: folha_pagamento folha_pagamento_funcionario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folha_pagamento
    ADD CONSTRAINT folha_pagamento_funcionario_id_fkey FOREIGN KEY (funcionario_id) REFERENCES public.funcionarios(id) ON DELETE CASCADE;


--
-- Name: fornecedores fornecedores_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fornecedores
    ADD CONSTRAINT fornecedores_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id) ON DELETE CASCADE;


--
-- Name: funcionarios_beneficios_empresas funcionarios_beneficios_empresas_funcionario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.funcionarios_beneficios_empresas
    ADD CONSTRAINT funcionarios_beneficios_empresas_funcionario_id_fkey FOREIGN KEY (funcionario_id) REFERENCES public.funcionarios_novo(id) ON DELETE CASCADE;


--
-- Name: funcionarios funcionarios_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.funcionarios
    ADD CONSTRAINT funcionarios_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id) ON DELETE SET NULL;


--
-- Name: funcionarios_detalhes funcionarios_detalhes_funcionario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.funcionarios_detalhes
    ADD CONSTRAINT funcionarios_detalhes_funcionario_id_fkey FOREIGN KEY (funcionario_id) REFERENCES public.funcionarios_novo(id) ON DELETE CASCADE;


--
-- Name: funcionarios funcionarios_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.funcionarios
    ADD CONSTRAINT funcionarios_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id);


--
-- Name: funcionarios_financeiro funcionarios_financeiro_funcionario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.funcionarios_financeiro
    ADD CONSTRAINT funcionarios_financeiro_funcionario_id_fkey FOREIGN KEY (funcionario_id) REFERENCES public.funcionarios_novo(id) ON DELETE CASCADE;


--
-- Name: funcionarios funcionarios_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.funcionarios
    ADD CONSTRAINT funcionarios_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: historico_status_orcamento historico_status_orcamento_orcamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historico_status_orcamento
    ADD CONSTRAINT historico_status_orcamento_orcamento_id_fkey FOREIGN KEY (orcamento_id) REFERENCES public.orcamentos_revenda_ubiqua(id) ON DELETE CASCADE;


--
-- Name: historico_status_orcamentos historico_status_orcamentos_orcamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historico_status_orcamentos
    ADD CONSTRAINT historico_status_orcamentos_orcamento_id_fkey FOREIGN KEY (orcamento_id) REFERENCES public.orcamentos(id) ON DELETE CASCADE;


--
-- Name: itens_orcamento_ubiqua itens_orcamento_ubiqua_orcamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.itens_orcamento_ubiqua
    ADD CONSTRAINT itens_orcamento_ubiqua_orcamento_id_fkey FOREIGN KEY (orcamento_id) REFERENCES public.orcamentos_revenda_ubiqua(id) ON DELETE CASCADE;


--
-- Name: itens_orcamento_ubiqua itens_orcamento_ubiqua_produto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.itens_orcamento_ubiqua
    ADD CONSTRAINT itens_orcamento_ubiqua_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.revenda_ubiqua(id) ON DELETE RESTRICT;


--
-- Name: logs_operacoes logs_operacoes_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.logs_operacoes
    ADD CONSTRAINT logs_operacoes_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES auth.users(id);


--
-- Name: negociacoes negociacoes_contato_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.negociacoes
    ADD CONSTRAINT negociacoes_contato_id_fkey FOREIGN KEY (contato_id) REFERENCES public.contatos(id);


--
-- Name: negociacoes negociacoes_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.negociacoes
    ADD CONSTRAINT negociacoes_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id);


--
-- Name: negociacoes negociacoes_funcionario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.negociacoes
    ADD CONSTRAINT negociacoes_funcionario_id_fkey FOREIGN KEY (funcionario_id) REFERENCES public.funcionarios(id);


--
-- Name: negociacoes negociacoes_plano_contas_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.negociacoes
    ADD CONSTRAINT negociacoes_plano_contas_id_fkey FOREIGN KEY (plano_contas_id) REFERENCES public.plano_de_contas(id);


--
-- Name: negociacoes negociacoes_projeto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.negociacoes
    ADD CONSTRAINT negociacoes_projeto_id_fkey FOREIGN KEY (projeto_id) REFERENCES public.projetos(id);


--
-- Name: notas_fiscais notas_fiscais_boleto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notas_fiscais
    ADD CONSTRAINT notas_fiscais_boleto_id_fkey FOREIGN KEY (boleto_id) REFERENCES public.boletos(id);


--
-- Name: notas_fiscais notas_fiscais_orcamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notas_fiscais
    ADD CONSTRAINT notas_fiscais_orcamento_id_fkey FOREIGN KEY (orcamento_id) REFERENCES public.orcamentos(id) ON DELETE SET NULL;


--
-- Name: orcamento_itens orcamento_itens_item_pai_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orcamento_itens
    ADD CONSTRAINT orcamento_itens_item_pai_id_fkey FOREIGN KEY (item_pai_id) REFERENCES public.orcamento_itens(id);


--
-- Name: orcamento_itens orcamento_itens_orcamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orcamento_itens
    ADD CONSTRAINT orcamento_itens_orcamento_id_fkey FOREIGN KEY (orcamento_id) REFERENCES public.orcamentos(id) ON DELETE CASCADE;


--
-- Name: orcamento_itens orcamento_itens_produto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orcamento_itens
    ADD CONSTRAINT orcamento_itens_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id);


--
-- Name: orcamentos orcamentos_arquiteto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orcamentos
    ADD CONSTRAINT orcamentos_arquiteto_id_fkey FOREIGN KEY (arquiteto_id) REFERENCES public.contatos(id);


--
-- Name: orcamentos orcamentos_cliente_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orcamentos
    ADD CONSTRAINT orcamentos_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES public.contatos(id);


--
-- Name: orcamentos orcamentos_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orcamentos
    ADD CONSTRAINT orcamentos_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id);


--
-- Name: orcamentos orcamentos_informacoes_cliente_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orcamentos
    ADD CONSTRAINT orcamentos_informacoes_cliente_id_fkey FOREIGN KEY (informacoes_cliente_id) REFERENCES public.informacoes_cliente_ubiqua(id) ON DELETE SET NULL;


--
-- Name: orcamentos orcamentos_projeto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orcamentos
    ADD CONSTRAINT orcamentos_projeto_id_fkey FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE SET NULL;


--
-- Name: orcamentos_revenda_ubiqua orcamentos_revenda_ubiqua_cliente_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orcamentos_revenda_ubiqua
    ADD CONSTRAINT orcamentos_revenda_ubiqua_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES public.informacoes_cliente_ubiqua(id) ON DELETE RESTRICT;


--
-- Name: orcamentos orcamentos_vendedor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orcamentos
    ADD CONSTRAINT orcamentos_vendedor_id_fkey FOREIGN KEY (vendedor_id) REFERENCES public.funcionarios(id) ON DELETE SET NULL;


--
-- Name: periodos_aquisitivos periodos_aquisitivos_funcionario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.periodos_aquisitivos
    ADD CONSTRAINT periodos_aquisitivos_funcionario_id_fkey FOREIGN KEY (funcionario_id) REFERENCES public.funcionarios(id) ON DELETE CASCADE;


--
-- Name: plano_de_contas plano_de_contas_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plano_de_contas
    ADD CONSTRAINT plano_de_contas_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.plano_de_contas(id);


--
-- Name: produtos produtos_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.produtos
    ADD CONSTRAINT produtos_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorias_produto(id);


--
-- Name: produtos produtos_fornecedor_principal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.produtos
    ADD CONSTRAINT produtos_fornecedor_principal_id_fkey FOREIGN KEY (fornecedor_principal_id) REFERENCES public.contatos(id);


--
-- Name: produtos produtos_marca_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.produtos
    ADD CONSTRAINT produtos_marca_id_fkey FOREIGN KEY (marca_id) REFERENCES public.marcas(id) ON DELETE SET NULL;


--
-- Name: projeto_itens projeto_itens_orcamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projeto_itens
    ADD CONSTRAINT projeto_itens_orcamento_id_fkey FOREIGN KEY (orcamento_id) REFERENCES public.orcamentos(id) ON DELETE SET NULL;


--
-- Name: projeto_itens projeto_itens_produto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projeto_itens
    ADD CONSTRAINT projeto_itens_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id) ON DELETE SET NULL;


--
-- Name: projeto_itens projeto_itens_projeto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projeto_itens
    ADD CONSTRAINT projeto_itens_projeto_id_fkey FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE CASCADE;


--
-- Name: projeto_parcelas projeto_parcelas_orcamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projeto_parcelas
    ADD CONSTRAINT projeto_parcelas_orcamento_id_fkey FOREIGN KEY (orcamento_id) REFERENCES public.orcamentos(id) ON DELETE SET NULL;


--
-- Name: projeto_parcelas projeto_parcelas_projeto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projeto_parcelas
    ADD CONSTRAINT projeto_parcelas_projeto_id_fkey FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE CASCADE;


--
-- Name: projeto_parcelas projeto_parcelas_transacao_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projeto_parcelas
    ADD CONSTRAINT projeto_parcelas_transacao_id_fkey FOREIGN KEY (transacao_id) REFERENCES public.transacoes(id) ON DELETE SET NULL;


--
-- Name: projeto_produtos projeto_produtos_produto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projeto_produtos
    ADD CONSTRAINT projeto_produtos_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id) ON DELETE CASCADE;


--
-- Name: projeto_produtos projeto_produtos_projeto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projeto_produtos
    ADD CONSTRAINT projeto_produtos_projeto_id_fkey FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE CASCADE;


--
-- Name: projeto_sinal projeto_sinal_projeto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projeto_sinal
    ADD CONSTRAINT projeto_sinal_projeto_id_fkey FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE CASCADE;


--
-- Name: projeto_sinal projeto_sinal_transacao_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projeto_sinal
    ADD CONSTRAINT projeto_sinal_transacao_id_fkey FOREIGN KEY (transacao_id) REFERENCES public.transacoes(id) ON DELETE SET NULL;


--
-- Name: projetos projetos_arquiteto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projetos
    ADD CONSTRAINT projetos_arquiteto_id_fkey FOREIGN KEY (arquiteto_id) REFERENCES public.contatos(id) ON DELETE CASCADE;


--
-- Name: projetos projetos_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projetos
    ADD CONSTRAINT projetos_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.contatos(id) ON DELETE SET NULL;


--
-- Name: projetos projetos_cliente_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projetos
    ADD CONSTRAINT projetos_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES public.contatos(id);


--
-- Name: projetos projetos_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projetos
    ADD CONSTRAINT projetos_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: projetos projetos_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projetos
    ADD CONSTRAINT projetos_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id) ON DELETE SET NULL;


--
-- Name: projetos projetos_responsavel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projetos
    ADD CONSTRAINT projetos_responsavel_id_fkey FOREIGN KEY (responsavel_id) REFERENCES public.usuarios(id);


--
-- Name: projetos projetos_responsavel_obra_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projetos
    ADD CONSTRAINT projetos_responsavel_obra_id_fkey FOREIGN KEY (responsavel_obra_id) REFERENCES public.contatos(id) ON DELETE SET NULL;


--
-- Name: quote_history quote_history_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_history
    ADD CONSTRAINT quote_history_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: quote_history quote_history_quote_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_history
    ADD CONSTRAINT quote_history_quote_id_fkey FOREIGN KEY (quote_id) REFERENCES public.quotes(id) ON DELETE CASCADE;


--
-- Name: remessas remessas_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.remessas
    ADD CONSTRAINT remessas_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id) ON DELETE CASCADE;


--
-- Name: remessas remessas_fornecedor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.remessas
    ADD CONSTRAINT remessas_fornecedor_id_fkey FOREIGN KEY (fornecedor_id) REFERENCES public.fornecedores(id) ON DELETE SET NULL;


--
-- Name: retornos_processados retornos_processados_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.retornos_processados
    ADD CONSTRAINT retornos_processados_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id);


--
-- Name: separacao_itens separacao_itens_produto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.separacao_itens
    ADD CONSTRAINT separacao_itens_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id) ON DELETE SET NULL;


--
-- Name: separacao_itens separacao_itens_separacao_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.separacao_itens
    ADD CONSTRAINT separacao_itens_separacao_id_fkey FOREIGN KEY (separacao_id) REFERENCES public.separacoes(id) ON DELETE CASCADE;


--
-- Name: separacoes separacoes_cliente_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.separacoes
    ADD CONSTRAINT separacoes_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES public.contatos(id) ON DELETE SET NULL;


--
-- Name: separacoes separacoes_projeto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.separacoes
    ADD CONSTRAINT separacoes_projeto_id_fkey FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE SET NULL;


--
-- Name: separacoes separacoes_responsavel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.separacoes
    ADD CONSTRAINT separacoes_responsavel_id_fkey FOREIGN KEY (responsavel_id) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: solicitacoes_compra solicitacoes_compra_produto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitacoes_compra
    ADD CONSTRAINT solicitacoes_compra_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id);


--
-- Name: solicitacoes_compra solicitacoes_compra_projeto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitacoes_compra
    ADD CONSTRAINT solicitacoes_compra_projeto_id_fkey FOREIGN KEY (projeto_id) REFERENCES public.projetos(id);


--
-- Name: sync_history sync_history_executado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sync_history
    ADD CONSTRAINT sync_history_executado_por_fkey FOREIGN KEY (executado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: transacoes transacoes_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transacoes
    ADD CONSTRAINT transacoes_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorias_financeiras(id) ON DELETE SET NULL;


--
-- Name: transacoes transacoes_conta_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transacoes
    ADD CONSTRAINT transacoes_conta_id_fkey FOREIGN KEY (conta_id) REFERENCES public.contas_bancarias(id) ON DELETE RESTRICT;


--
-- Name: transacoes transacoes_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transacoes
    ADD CONSTRAINT transacoes_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: transacoes transacoes_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transacoes
    ADD CONSTRAINT transacoes_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id) ON DELETE RESTRICT;


--
-- Name: transacoes transacoes_funcionario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transacoes
    ADD CONSTRAINT transacoes_funcionario_id_fkey FOREIGN KEY (funcionario_id) REFERENCES public.funcionarios(id);


--
-- Name: transacoes transacoes_negociacao_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transacoes
    ADD CONSTRAINT transacoes_negociacao_id_fkey FOREIGN KEY (negociacao_id) REFERENCES public.negociacoes(id);


--
-- Name: transacoes transacoes_parcela_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transacoes
    ADD CONSTRAINT transacoes_parcela_id_fkey FOREIGN KEY (parcela_id) REFERENCES public.projeto_parcelas(id) ON DELETE SET NULL;


--
-- Name: transacoes transacoes_projeto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transacoes
    ADD CONSTRAINT transacoes_projeto_id_fkey FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE SET NULL;


--
-- Name: user_system_access user_system_access_system_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_system_access
    ADD CONSTRAINT user_system_access_system_id_fkey FOREIGN KEY (system_id) REFERENCES public.systems(id) ON DELETE CASCADE;


--
-- Name: user_system_access user_system_access_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_system_access
    ADD CONSTRAINT user_system_access_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: usuarios usuarios_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id);


--
-- Name: usuarios usuarios_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: usuarios_ubiqua usuarios_ubiqua_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios_ubiqua
    ADD CONSTRAINT usuarios_ubiqua_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresa_ubiqua(id) ON DELETE CASCADE;


--
-- Name: usuarios_ubiqua usuarios_ubiqua_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios_ubiqua
    ADD CONSTRAINT usuarios_ubiqua_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: vendas_marca vendas_marca_marca_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendas_marca
    ADD CONSTRAINT vendas_marca_marca_id_fkey FOREIGN KEY (marca_id) REFERENCES public.marcas(id) ON DELETE CASCADE;


--
-- Name: vendas vendas_projeto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendas
    ADD CONSTRAINT vendas_projeto_id_fkey FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE CASCADE;


--
-- Name: informacoes_cliente_ubiqua Permitir leitura admin_gerente; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Permitir leitura admin_gerente" ON public.informacoes_cliente_ubiqua FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: informacoes_cliente_ubiqua Permitir leitura anon e auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Permitir leitura anon e auth" ON public.informacoes_cliente_ubiqua FOR SELECT TO authenticated, anon USING (true);


--
-- Name: pedido_compra Permitir leitura para autenticados; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Permitir leitura para autenticados" ON public.pedido_compra FOR SELECT USING ((auth.role() = 'authenticated'::text));


--
-- Name: produtos Permitir leitura para autenticados; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Permitir leitura para autenticados" ON public.produtos FOR SELECT USING ((auth.role() = 'authenticated'::text));


--
-- Name: projeto_parcelas Permitir leitura para autenticados; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Permitir leitura para autenticados" ON public.projeto_parcelas FOR SELECT USING ((auth.role() = 'authenticated'::text));


--
-- Name: projeto_produtos Permitir leitura para autenticados; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Permitir leitura para autenticados" ON public.projeto_produtos FOR SELECT USING ((auth.role() = 'authenticated'::text));


--
-- Name: projetos Permitir leitura para autenticados; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Permitir leitura para autenticados" ON public.projetos FOR SELECT USING ((auth.role() = 'authenticated'::text));


--
-- Name: vendas Permitir leitura para autenticados; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Permitir leitura para autenticados" ON public.vendas FOR SELECT USING ((auth.role() = 'authenticated'::text));


--
-- Name: user_roles_separacao Permitir leitura para usuarios autenticados; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Permitir leitura para usuarios autenticados" ON public.user_roles_separacao FOR SELECT TO authenticated USING (true);


--
-- Name: pedido_compra Permitir tudo para service_role; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Permitir tudo para service_role" ON public.pedido_compra USING ((auth.role() = 'service_role'::text));


--
-- Name: produtos Permitir tudo para service_role; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Permitir tudo para service_role" ON public.produtos USING ((auth.role() = 'service_role'::text));


--
-- Name: projeto_parcelas Permitir tudo para service_role; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Permitir tudo para service_role" ON public.projeto_parcelas USING ((auth.role() = 'service_role'::text));


--
-- Name: projeto_produtos Permitir tudo para service_role; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Permitir tudo para service_role" ON public.projeto_produtos USING ((auth.role() = 'service_role'::text));


--
-- Name: projetos Permitir tudo para service_role; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Permitir tudo para service_role" ON public.projetos USING ((auth.role() = 'service_role'::text));


--
-- Name: vendas Permitir tudo para service_role; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Permitir tudo para service_role" ON public.vendas USING ((auth.role() = 'service_role'::text));


--
-- Name: logs_auditoria admin_all_logs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_all_logs ON public.logs_auditoria TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());


--
-- Name: user_system_access admin_all_usa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_all_usa ON public.user_system_access TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());


--
-- Name: usuarios admin_all_usuarios; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_all_usuarios ON public.usuarios TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());


--
-- Name: quote_history all_quote_history_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY all_quote_history_auth ON public.quote_history USING (true);


--
-- Name: quotes all_quotes_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY all_quotes_auth ON public.quotes USING (true) WITH CHECK (true);


--
-- Name: informacoes_cliente_ubiqua all_select_informacoes_cliente; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY all_select_informacoes_cliente ON public.informacoes_cliente_ubiqua FOR SELECT TO authenticated, anon USING (true);


--
-- Name: itens_orcamento_ubiqua all_select_itens_orcamento_ubiqua; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY all_select_itens_orcamento_ubiqua ON public.itens_orcamento_ubiqua FOR SELECT USING (true);


--
-- Name: orcamentos_revenda_ubiqua all_select_orcamentos_revenda_ubiqua; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY all_select_orcamentos_revenda_ubiqua ON public.orcamentos_revenda_ubiqua FOR SELECT USING (true);


--
-- Name: informacoes_cliente_ubiqua anon_insert_informacoes_cliente; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_insert_informacoes_cliente ON public.informacoes_cliente_ubiqua FOR INSERT TO anon WITH CHECK (true);


--
-- Name: itens_orcamento_ubiqua anon_insert_itens_orcamento_ubiqua; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_insert_itens_orcamento_ubiqua ON public.itens_orcamento_ubiqua FOR INSERT TO anon WITH CHECK (true);


--
-- Name: orcamento_itens anon_insert_orcamento_itens; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_insert_orcamento_itens ON public.orcamento_itens FOR INSERT TO authenticated, anon WITH CHECK (true);


--
-- Name: orcamentos anon_insert_orcamentos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_insert_orcamentos ON public.orcamentos FOR INSERT TO authenticated, anon WITH CHECK (true);


--
-- Name: orcamentos_revenda_ubiqua anon_insert_orcamentos_revenda_ubiqua; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_insert_orcamentos_revenda_ubiqua ON public.orcamentos_revenda_ubiqua FOR INSERT TO anon WITH CHECK (true);


--
-- Name: empresas anon_select_empresas; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_select_empresas ON public.empresas FOR SELECT TO authenticated, anon USING (true);


--
-- Name: informacoes_cliente_ubiqua anon_update_informacoes_cliente; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_update_informacoes_cliente ON public.informacoes_cliente_ubiqua FOR UPDATE TO anon USING (true) WITH CHECK (true);


--
-- Name: informacoes_cliente_ubiqua auth_insert_informacoes_cliente; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY auth_insert_informacoes_cliente ON public.informacoes_cliente_ubiqua FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: itens_orcamento_ubiqua auth_insert_itens_orcamento_ubiqua; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY auth_insert_itens_orcamento_ubiqua ON public.itens_orcamento_ubiqua FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: orcamentos_revenda_ubiqua auth_insert_orcamentos_revenda_ubiqua; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY auth_insert_orcamentos_revenda_ubiqua ON public.orcamentos_revenda_ubiqua FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: informacoes_cliente_ubiqua auth_update_informacoes_cliente; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY auth_update_informacoes_cliente ON public.informacoes_cliente_ubiqua FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: contato_tipos authenticated_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_all ON public.contato_tipos TO authenticated USING (true) WITH CHECK (true);


--
-- Name: projeto_parcelas_backup_migration authenticated_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_all ON public.projeto_parcelas_backup_migration TO authenticated USING (true) WITH CHECK (true);


--
-- Name: boletos authenticated_all_boletos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_all_boletos ON public.boletos TO authenticated USING (true) WITH CHECK (true);


--
-- Name: contatos authenticated_all_contatos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_all_contatos ON public.contatos TO authenticated USING (true) WITH CHECK (true);


--
-- Name: itens_orcamento_ubiqua authenticated_all_itens_orcamento_ubiqua; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_all_itens_orcamento_ubiqua ON public.itens_orcamento_ubiqua TO authenticated USING (true) WITH CHECK (true);


--
-- Name: notas_fiscais authenticated_all_notas_fiscais; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_all_notas_fiscais ON public.notas_fiscais TO authenticated USING (true) WITH CHECK (true);


--
-- Name: orcamentos_revenda_ubiqua authenticated_all_orcamentos_revenda_ubiqua; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_all_orcamentos_revenda_ubiqua ON public.orcamentos_revenda_ubiqua TO authenticated USING (true) WITH CHECK (true);


--
-- Name: projeto_parcelas authenticated_all_projeto_parcelas; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_all_projeto_parcelas ON public.projeto_parcelas TO authenticated USING (true) WITH CHECK (true);


--
-- Name: projetos authenticated_all_projetos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_all_projetos ON public.projetos TO authenticated USING (true) WITH CHECK (true);


--
-- Name: retornos_processados authenticated_all_retornos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_all_retornos ON public.retornos_processados TO authenticated USING (true) WITH CHECK (true);


--
-- Name: transacoes authenticated_all_transacoes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_all_transacoes ON public.transacoes TO authenticated USING (true) WITH CHECK (true);


--
-- Name: contatos authenticated_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_delete ON public.contatos FOR DELETE TO authenticated USING (true);


--
-- Name: boletos authenticated_delete_boletos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_delete_boletos ON public.boletos FOR DELETE TO authenticated USING (true);


--
-- Name: contatos authenticated_delete_contatos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_delete_contatos ON public.contatos FOR DELETE TO authenticated USING (true);


--
-- Name: estoque_itens authenticated_delete_estoque_itens; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_delete_estoque_itens ON public.estoque_itens FOR DELETE TO authenticated USING (true);


--
-- Name: notas_fiscais authenticated_delete_nf; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_delete_nf ON public.notas_fiscais FOR DELETE TO authenticated USING (true);


--
-- Name: orcamento_itens authenticated_delete_orcamento_itens; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_delete_orcamento_itens ON public.orcamento_itens FOR DELETE TO authenticated USING (true);


--
-- Name: orcamentos authenticated_delete_orcamentos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_delete_orcamentos ON public.orcamentos FOR DELETE TO authenticated USING (true);


--
-- Name: produtos authenticated_delete_produtos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_delete_produtos ON public.produtos FOR DELETE TO authenticated USING (true);


--
-- Name: projetos authenticated_delete_projetos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_delete_projetos ON public.projetos FOR DELETE TO authenticated USING (true);


--
-- Name: retornos_processados authenticated_delete_retornos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_delete_retornos ON public.retornos_processados FOR DELETE TO authenticated USING (true);


--
-- Name: solicitacoes_compra authenticated_delete_solicitacoes_compra; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_delete_solicitacoes_compra ON public.solicitacoes_compra FOR DELETE TO authenticated USING (true);


--
-- Name: contatos authenticated_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert ON public.contatos FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: boletos authenticated_insert_boletos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert_boletos ON public.boletos FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: contatos authenticated_insert_contatos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert_contatos ON public.contatos FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: estoque_itens authenticated_insert_estoque_itens; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert_estoque_itens ON public.estoque_itens FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: historico_status_orcamento authenticated_insert_historico_status_orcamento; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert_historico_status_orcamento ON public.historico_status_orcamento FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: historico_status_orcamentos authenticated_insert_historico_status_orcamentos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert_historico_status_orcamentos ON public.historico_status_orcamentos FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: notas_fiscais authenticated_insert_nf; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert_nf ON public.notas_fiscais FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: orcamento_itens authenticated_insert_orcamento_itens; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert_orcamento_itens ON public.orcamento_itens FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: orcamentos authenticated_insert_orcamentos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert_orcamentos ON public.orcamentos FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: produtos authenticated_insert_produtos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert_produtos ON public.produtos FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: projetos authenticated_insert_projetos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert_projetos ON public.projetos FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: retornos_processados authenticated_insert_retornos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert_retornos ON public.retornos_processados FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: solicitacoes_compra authenticated_insert_solicitacoes_compra; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert_solicitacoes_compra ON public.solicitacoes_compra FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: contatos authenticated_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select ON public.contatos FOR SELECT TO authenticated USING (true);


--
-- Name: boletos authenticated_select_boletos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_boletos ON public.boletos FOR SELECT TO authenticated USING (true);


--
-- Name: contatos authenticated_select_contatos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_contatos ON public.contatos FOR SELECT TO authenticated USING (true);


--
-- Name: empresas authenticated_select_empresas; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_empresas ON public.empresas FOR SELECT TO authenticated USING (true);


--
-- Name: estoque_itens authenticated_select_estoque_itens; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_estoque_itens ON public.estoque_itens FOR SELECT TO authenticated USING (true);


--
-- Name: funcionarios authenticated_select_funcionarios; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_funcionarios ON public.funcionarios FOR SELECT TO authenticated USING (true);


--
-- Name: historico_status_orcamento authenticated_select_historico_status_orcamento; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_historico_status_orcamento ON public.historico_status_orcamento FOR SELECT TO authenticated USING (true);


--
-- Name: historico_status_orcamentos authenticated_select_historico_status_orcamentos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_historico_status_orcamentos ON public.historico_status_orcamentos FOR SELECT TO authenticated USING (true);


--
-- Name: notas_fiscais authenticated_select_nf; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_nf ON public.notas_fiscais FOR SELECT TO authenticated USING (true);


--
-- Name: orcamento_itens authenticated_select_orcamento_itens; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_orcamento_itens ON public.orcamento_itens FOR SELECT TO authenticated USING (true);


--
-- Name: orcamentos authenticated_select_orcamentos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_orcamentos ON public.orcamentos FOR SELECT TO authenticated USING (true);


--
-- Name: produtos authenticated_select_produtos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_produtos ON public.produtos FOR SELECT TO authenticated USING (true);


--
-- Name: projetos authenticated_select_projetos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_projetos ON public.projetos FOR SELECT TO authenticated USING (true);


--
-- Name: retornos_processados authenticated_select_retornos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_retornos ON public.retornos_processados FOR SELECT TO authenticated USING (true);


--
-- Name: revenda_ubiqua authenticated_select_revenda; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_revenda ON public.revenda_ubiqua FOR SELECT TO authenticated USING (true);


--
-- Name: usuarios authenticated_select_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_self ON public.usuarios FOR SELECT TO authenticated USING ((auth.uid() = id));


--
-- Name: solicitacoes_compra authenticated_select_solicitacoes_compra; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_solicitacoes_compra ON public.solicitacoes_compra FOR SELECT TO authenticated USING (true);


--
-- Name: systems authenticated_select_systems; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_systems ON public.systems FOR SELECT TO authenticated USING (true);


--
-- Name: usuarios authenticated_select_usuarios; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_usuarios ON public.usuarios FOR SELECT TO authenticated USING (true);


--
-- Name: contatos authenticated_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update ON public.contatos FOR UPDATE TO authenticated USING (true);


--
-- Name: boletos authenticated_update_boletos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update_boletos ON public.boletos FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: contatos authenticated_update_contatos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update_contatos ON public.contatos FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: estoque_itens authenticated_update_estoque_itens; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update_estoque_itens ON public.estoque_itens FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: notas_fiscais authenticated_update_nf; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update_nf ON public.notas_fiscais FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: orcamento_itens authenticated_update_orcamento_itens; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update_orcamento_itens ON public.orcamento_itens FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: orcamentos authenticated_update_orcamentos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update_orcamentos ON public.orcamentos FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: orcamentos_revenda_ubiqua authenticated_update_orcamentos_revenda_ubiqua; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update_orcamentos_revenda_ubiqua ON public.orcamentos_revenda_ubiqua FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: produtos authenticated_update_produtos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update_produtos ON public.produtos FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: projetos authenticated_update_projetos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update_projetos ON public.projetos FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: retornos_processados authenticated_update_retornos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update_retornos ON public.retornos_processados FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: solicitacoes_compra authenticated_update_solicitacoes_compra; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update_solicitacoes_compra ON public.solicitacoes_compra FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: boletos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.boletos ENABLE ROW LEVEL SECURITY;

--
-- Name: categorias_financeiras; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.categorias_financeiras ENABLE ROW LEVEL SECURITY;

--
-- Name: categorias_produto; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.categorias_produto ENABLE ROW LEVEL SECURITY;

--
-- Name: categorias_produto categorias_produto_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY categorias_produto_select ON public.categorias_produto FOR SELECT TO authenticated USING (true);


--
-- Name: categorias_produto categorias_produto_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY categorias_produto_write ON public.categorias_produto TO service_role USING (true);


--
-- Name: categorias_financeiras catfin_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY catfin_delete ON public.categorias_financeiras FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: categorias_financeiras catfin_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY catfin_insert ON public.categorias_financeiras FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: categorias_financeiras catfin_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY catfin_select ON public.categorias_financeiras FOR SELECT TO authenticated USING (true);


--
-- Name: categorias_financeiras catfin_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY catfin_update ON public.categorias_financeiras FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: contas_bancarias; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.contas_bancarias ENABLE ROW LEVEL SECURITY;

--
-- Name: contas_bancarias contas_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contas_delete ON public.contas_bancarias FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = 'admin'::public.usuario_role)))));


--
-- Name: contas_bancarias contas_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contas_insert ON public.contas_bancarias FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = 'admin'::public.usuario_role)))));


--
-- Name: contas_bancarias contas_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contas_select ON public.contas_bancarias FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role, 'operador'::public.usuario_role]))))));


--
-- Name: contas_bancarias contas_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contas_update ON public.contas_bancarias FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = 'admin'::public.usuario_role)))));


--
-- Name: contato_origens; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.contato_origens ENABLE ROW LEVEL SECURITY;

--
-- Name: contato_origens contato_origens_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contato_origens_select ON public.contato_origens FOR SELECT TO authenticated USING (true);


--
-- Name: contato_origens contato_origens_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contato_origens_write ON public.contato_origens TO service_role USING (true);


--
-- Name: contato_tipos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.contato_tipos ENABLE ROW LEVEL SECURITY;

--
-- Name: contato_tipos contato_tipos_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contato_tipos_select ON public.contato_tipos FOR SELECT TO authenticated USING (true);


--
-- Name: contato_tipos contato_tipos_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contato_tipos_write ON public.contato_tipos TO service_role USING (true);


--
-- Name: contatos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.contatos ENABLE ROW LEVEL SECURITY;

--
-- Name: contatos contatos_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contatos_delete_admin ON public.contatos FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: contatos contatos_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contatos_insert ON public.contatos FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role, 'operador'::public.usuario_role]))))));


--
-- Name: contatos_revisao; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.contatos_revisao ENABLE ROW LEVEL SECURITY;

--
-- Name: contatos_revisao contatos_revisao_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contatos_revisao_select ON public.contatos_revisao FOR SELECT TO authenticated USING (true);


--
-- Name: contatos_revisao contatos_revisao_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contatos_revisao_write ON public.contatos_revisao TO service_role USING (true);


--
-- Name: contatos contatos_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contatos_select ON public.contatos FOR SELECT TO authenticated USING (true);


--
-- Name: contatos contatos_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contatos_update ON public.contatos FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role, 'operador'::public.usuario_role]))))));


--
-- Name: controle_falta; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.controle_falta ENABLE ROW LEVEL SECURITY;

--
-- Name: custos_recorrentes custos_rec_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY custos_rec_delete ON public.custos_recorrentes FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: custos_recorrentes custos_rec_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY custos_rec_insert ON public.custos_recorrentes FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: custos_recorrentes custos_rec_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY custos_rec_select ON public.custos_recorrentes FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role, 'operador'::public.usuario_role]))))));


--
-- Name: custos_recorrentes custos_rec_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY custos_rec_update ON public.custos_recorrentes FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: custos_recorrentes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.custos_recorrentes ENABLE ROW LEVEL SECURITY;

--
-- Name: custos_recorrentes_lancamentos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.custos_recorrentes_lancamentos ENABLE ROW LEVEL SECURITY;

--
-- Name: departamentos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.departamentos ENABLE ROW LEVEL SECURITY;

--
-- Name: departamentos dept_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY dept_delete_admin ON public.departamentos FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: departamentos dept_insert_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY dept_insert_admin ON public.departamentos FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: departamentos dept_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY dept_select ON public.departamentos FOR SELECT TO authenticated USING (true);


--
-- Name: departamentos dept_update_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY dept_update_admin ON public.departamentos FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: empresa_ubiqua; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.empresa_ubiqua ENABLE ROW LEVEL SECURITY;

--
-- Name: empresa_ubiqua empresa_ubiqua_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY empresa_ubiqua_insert ON public.empresa_ubiqua FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: empresa_ubiqua empresa_ubiqua_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY empresa_ubiqua_select ON public.empresa_ubiqua FOR SELECT TO authenticated USING (true);


--
-- Name: empresa_ubiqua empresa_ubiqua_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY empresa_ubiqua_update ON public.empresa_ubiqua FOR UPDATE TO authenticated USING ((id IN ( SELECT usuarios_ubiqua.empresa_id
   FROM public.usuarios_ubiqua
  WHERE (usuarios_ubiqua.id = auth.uid())))) WITH CHECK ((id IN ( SELECT usuarios_ubiqua.empresa_id
   FROM public.usuarios_ubiqua
  WHERE (usuarios_ubiqua.id = auth.uid()))));


--
-- Name: empresas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.empresas ENABLE ROW LEVEL SECURITY;

--
-- Name: empresas empresas_delete_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY empresas_delete_auth ON public.empresas FOR DELETE TO authenticated USING (true);


--
-- Name: empresas empresas_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY empresas_insert ON public.empresas FOR INSERT TO service_role WITH CHECK (true);


--
-- Name: empresas empresas_insert_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY empresas_insert_auth ON public.empresas FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: empresas empresas_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY empresas_select ON public.empresas FOR SELECT TO authenticated USING (true);


--
-- Name: empresas empresas_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY empresas_update ON public.empresas FOR UPDATE TO service_role USING (true);


--
-- Name: empresas empresas_update_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY empresas_update_auth ON public.empresas FOR UPDATE TO authenticated USING (true);


--
-- Name: entregas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.entregas ENABLE ROW LEVEL SECURITY;

--
-- Name: entregas entregas_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY entregas_delete_admin ON public.entregas FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: entregas_finalizadas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.entregas_finalizadas ENABLE ROW LEVEL SECURITY;

--
-- Name: entregas_finalizadas entregas_finalizadas_authenticated_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY entregas_finalizadas_authenticated_all ON public.entregas_finalizadas TO authenticated USING (true) WITH CHECK (true);


--
-- Name: entregas entregas_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY entregas_insert ON public.entregas FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role, 'operador'::public.usuario_role]))))));


--
-- Name: entregas entregas_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY entregas_select ON public.entregas FOR SELECT TO authenticated USING (true);


--
-- Name: entregas entregas_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY entregas_update ON public.entregas FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role, 'operador'::public.usuario_role]))))));


--
-- Name: estoque_itens estoque_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY estoque_delete ON public.estoque_itens FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role, 'operador'::public.usuario_role]))))));


--
-- Name: estoque_itens estoque_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY estoque_insert ON public.estoque_itens FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role, 'operador'::public.usuario_role]))))));


--
-- Name: estoque_itens; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.estoque_itens ENABLE ROW LEVEL SECURITY;

--
-- Name: estoque_itens estoque_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY estoque_select ON public.estoque_itens FOR SELECT TO authenticated USING (true);


--
-- Name: estoque_itens estoque_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY estoque_update ON public.estoque_itens FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role, 'operador'::public.usuario_role]))))));


--
-- Name: ferias; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ferias ENABLE ROW LEVEL SECURITY;

--
-- Name: ferias ferias_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ferias_delete_admin ON public.ferias FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: ferias ferias_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ferias_insert ON public.ferias FOR INSERT TO authenticated WITH CHECK (((funcionario_id IN ( SELECT funcionarios.id
   FROM public.funcionarios
  WHERE (funcionarios.usuario_id = ( SELECT auth.uid() AS uid)))) OR (EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role])))))));


--
-- Name: ferias ferias_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ferias_select ON public.ferias FOR SELECT TO authenticated USING (((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))) OR (funcionario_id IN ( SELECT funcionarios.id
   FROM public.funcionarios
  WHERE (funcionarios.usuario_id = ( SELECT auth.uid() AS uid))))));


--
-- Name: ferias ferias_update_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ferias_update_admin ON public.ferias FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: folha_pagamento folha_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY folha_delete ON public.folha_pagamento FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: folha_pagamento folha_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY folha_insert ON public.folha_pagamento FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: folha_pagamento folha_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY folha_own ON public.folha_pagamento FOR SELECT TO authenticated USING (((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))) OR (funcionario_id IN ( SELECT funcionarios.id
   FROM public.funcionarios
  WHERE (funcionarios.usuario_id = ( SELECT auth.uid() AS uid))))));


--
-- Name: folha_pagamento; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.folha_pagamento ENABLE ROW LEVEL SECURITY;

--
-- Name: folha_pagamento folha_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY folha_update ON public.folha_pagamento FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: fornecedores; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.fornecedores ENABLE ROW LEVEL SECURITY;

--
-- Name: fornecedores fornecedores_delete_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fornecedores_delete_policy ON public.fornecedores FOR DELETE USING (true);


--
-- Name: fornecedores fornecedores_insert_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fornecedores_insert_policy ON public.fornecedores FOR INSERT WITH CHECK ((auth.uid() IS NOT NULL));


--
-- Name: fornecedores fornecedores_select_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fornecedores_select_policy ON public.fornecedores FOR SELECT USING (true);


--
-- Name: fornecedores fornecedores_update_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fornecedores_update_policy ON public.fornecedores FOR UPDATE USING (true) WITH CHECK ((auth.uid() IS NOT NULL));


--
-- Name: funcionarios func_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY func_delete_admin ON public.funcionarios FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: funcionarios func_insert_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY func_insert_admin ON public.funcionarios FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: funcionarios func_select_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY func_select_admin ON public.funcionarios FOR SELECT TO authenticated USING (((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))) OR (usuario_id = ( SELECT auth.uid() AS uid))));


--
-- Name: funcionarios func_update_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY func_update_admin ON public.funcionarios FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: funcionarios_beneficios_empresas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.funcionarios_beneficios_empresas ENABLE ROW LEVEL SECURITY;

--
-- Name: funcionarios_beneficios_empresas funcionarios_beneficios_empresas_authenticated_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY funcionarios_beneficios_empresas_authenticated_all ON public.funcionarios_beneficios_empresas TO authenticated USING (true) WITH CHECK (true);


--
-- Name: funcionarios_detalhes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.funcionarios_detalhes ENABLE ROW LEVEL SECURITY;

--
-- Name: funcionarios_detalhes funcionarios_detalhes_authenticated_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY funcionarios_detalhes_authenticated_all ON public.funcionarios_detalhes TO authenticated USING (true) WITH CHECK (true);


--
-- Name: funcionarios_financeiro; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.funcionarios_financeiro ENABLE ROW LEVEL SECURITY;

--
-- Name: funcionarios_financeiro funcionarios_financeiro_authenticated_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY funcionarios_financeiro_authenticated_all ON public.funcionarios_financeiro TO authenticated USING (true) WITH CHECK (true);


--
-- Name: funcionarios_novo; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.funcionarios_novo ENABLE ROW LEVEL SECURITY;

--
-- Name: funcionarios_novo funcionarios_novo_authenticated_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY funcionarios_novo_authenticated_all ON public.funcionarios_novo TO authenticated USING (true) WITH CHECK (true);


--
-- Name: historico_status_orcamento; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.historico_status_orcamento ENABLE ROW LEVEL SECURITY;

--
-- Name: historico_status_orcamento historico_status_orcamento_authenticated_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY historico_status_orcamento_authenticated_all ON public.historico_status_orcamento TO authenticated USING (true) WITH CHECK (true);


--
-- Name: historico_status_orcamentos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.historico_status_orcamentos ENABLE ROW LEVEL SECURITY;

--
-- Name: informacoes_cliente_ubiqua; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.informacoes_cliente_ubiqua ENABLE ROW LEVEL SECURITY;

--
-- Name: itens_orcamento_ubiqua; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.itens_orcamento_ubiqua ENABLE ROW LEVEL SECURITY;

--
-- Name: custos_recorrentes_lancamentos lanc_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY lanc_delete ON public.custos_recorrentes_lancamentos FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: custos_recorrentes_lancamentos lanc_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY lanc_insert ON public.custos_recorrentes_lancamentos FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: custos_recorrentes_lancamentos lanc_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY lanc_select ON public.custos_recorrentes_lancamentos FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role, 'operador'::public.usuario_role]))))));


--
-- Name: custos_recorrentes_lancamentos lanc_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY lanc_update ON public.custos_recorrentes_lancamentos FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: logs_auditoria; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.logs_auditoria ENABLE ROW LEVEL SECURITY;

--
-- Name: logs_auditoria logs_auditoria_delete_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY logs_auditoria_delete_policy ON public.logs_auditoria FOR DELETE USING (false);


--
-- Name: logs_auditoria logs_auditoria_insert_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY logs_auditoria_insert_policy ON public.logs_auditoria FOR INSERT WITH CHECK (false);


--
-- Name: logs_auditoria logs_auditoria_select_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY logs_auditoria_select_policy ON public.logs_auditoria FOR SELECT USING (true);


--
-- Name: logs_auditoria logs_auditoria_update_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY logs_auditoria_update_policy ON public.logs_auditoria FOR UPDATE USING (false);


--
-- Name: logs_operacoes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.logs_operacoes ENABLE ROW LEVEL SECURITY;

--
-- Name: marcas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.marcas ENABLE ROW LEVEL SECURITY;

--
-- Name: marcas marcas_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY marcas_delete ON public.marcas FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: marcas marcas_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY marcas_insert ON public.marcas FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: marcas marcas_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY marcas_select ON public.marcas FOR SELECT TO authenticated USING (true);


--
-- Name: marcas marcas_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY marcas_update ON public.marcas FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: negociacoes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.negociacoes ENABLE ROW LEVEL SECURITY;

--
-- Name: negociacoes negociacoes_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY negociacoes_select ON public.negociacoes FOR SELECT TO authenticated USING (true);


--
-- Name: negociacoes negociacoes_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY negociacoes_write ON public.negociacoes TO service_role USING (true);


--
-- Name: notas_fiscais; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notas_fiscais ENABLE ROW LEVEL SECURITY;

--
-- Name: orcamento_itens; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.orcamento_itens ENABLE ROW LEVEL SECURITY;

--
-- Name: orcamento_itens orcamento_itens_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY orcamento_itens_delete ON public.orcamento_itens FOR DELETE TO authenticated USING (true);


--
-- Name: orcamento_itens orcamento_itens_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY orcamento_itens_insert ON public.orcamento_itens FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: orcamento_itens orcamento_itens_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY orcamento_itens_select ON public.orcamento_itens FOR SELECT TO authenticated USING (true);


--
-- Name: orcamento_itens orcamento_itens_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY orcamento_itens_update ON public.orcamento_itens FOR UPDATE TO authenticated USING (true);


--
-- Name: orcamentos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.orcamentos ENABLE ROW LEVEL SECURITY;

--
-- Name: orcamentos orcamentos_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY orcamentos_delete ON public.orcamentos FOR DELETE TO authenticated USING (true);


--
-- Name: orcamentos orcamentos_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY orcamentos_insert ON public.orcamentos FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: orcamentos_revenda_ubiqua; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.orcamentos_revenda_ubiqua ENABLE ROW LEVEL SECURITY;

--
-- Name: orcamentos orcamentos_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY orcamentos_select ON public.orcamentos FOR SELECT TO authenticated USING (true);


--
-- Name: orcamentos orcamentos_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY orcamentos_update ON public.orcamentos FOR UPDATE TO authenticated USING (true);


--
-- Name: projeto_parcelas parcelas_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY parcelas_delete_admin ON public.projeto_parcelas FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: projeto_parcelas parcelas_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY parcelas_insert ON public.projeto_parcelas FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role, 'operador'::public.usuario_role]))))));


--
-- Name: projeto_parcelas parcelas_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY parcelas_select ON public.projeto_parcelas FOR SELECT TO authenticated USING (true);


--
-- Name: projeto_parcelas parcelas_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY parcelas_update ON public.projeto_parcelas FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role, 'operador'::public.usuario_role]))))));


--
-- Name: pedido_compra; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.pedido_compra ENABLE ROW LEVEL SECURITY;

--
-- Name: projeto_itens pi_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pi_delete_admin ON public.projeto_itens FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: projeto_itens pi_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pi_insert ON public.projeto_itens FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role, 'operador'::public.usuario_role]))))));


--
-- Name: projeto_itens pi_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pi_select ON public.projeto_itens FOR SELECT TO authenticated USING (true);


--
-- Name: projeto_itens pi_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pi_update ON public.projeto_itens FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role, 'operador'::public.usuario_role]))))));


--
-- Name: plano_de_contas plano_contas_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY plano_contas_select ON public.plano_de_contas FOR SELECT TO authenticated USING (true);


--
-- Name: plano_de_contas plano_contas_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY plano_contas_write ON public.plano_de_contas TO service_role USING (true);


--
-- Name: plano_de_contas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.plano_de_contas ENABLE ROW LEVEL SECURITY;

--
-- Name: controle_falta ponto_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ponto_delete_admin ON public.controle_falta FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: controle_falta ponto_insert_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ponto_insert_admin ON public.controle_falta FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: controle_falta ponto_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ponto_select ON public.controle_falta FOR SELECT TO authenticated USING (((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))) OR (funcionario_id IN ( SELECT funcionarios.id
   FROM public.funcionarios
  WHERE (funcionarios.usuario_id = ( SELECT auth.uid() AS uid))))));


--
-- Name: controle_falta ponto_update_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ponto_update_admin ON public.controle_falta FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: produtos prod_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY prod_delete ON public.produtos FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: produtos prod_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY prod_insert ON public.produtos FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: produtos prod_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY prod_select ON public.produtos FOR SELECT TO authenticated USING (true);


--
-- Name: produtos prod_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY prod_update ON public.produtos FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: produtos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.produtos ENABLE ROW LEVEL SECURITY;

--
-- Name: projeto_itens; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.projeto_itens ENABLE ROW LEVEL SECURITY;

--
-- Name: projeto_parcelas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.projeto_parcelas ENABLE ROW LEVEL SECURITY;

--
-- Name: projeto_parcelas_backup_migration; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.projeto_parcelas_backup_migration ENABLE ROW LEVEL SECURITY;

--
-- Name: projeto_produtos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.projeto_produtos ENABLE ROW LEVEL SECURITY;

--
-- Name: projeto_sinal; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.projeto_sinal ENABLE ROW LEVEL SECURITY;

--
-- Name: projetos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.projetos ENABLE ROW LEVEL SECURITY;

--
-- Name: projetos projetos_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY projetos_delete_admin ON public.projetos FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: projetos_fechados; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.projetos_fechados ENABLE ROW LEVEL SECURITY;

--
-- Name: projetos_fechados projetos_fechados_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY projetos_fechados_delete ON public.projetos_fechados FOR DELETE TO authenticated USING (true);


--
-- Name: projetos_fechados projetos_fechados_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY projetos_fechados_insert ON public.projetos_fechados FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: projetos_fechados projetos_fechados_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY projetos_fechados_select ON public.projetos_fechados FOR SELECT TO authenticated USING (true);


--
-- Name: projetos_fechados projetos_fechados_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY projetos_fechados_update ON public.projetos_fechados FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: projetos projetos_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY projetos_insert ON public.projetos FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role, 'operador'::public.usuario_role]))))));


--
-- Name: projetos projetos_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY projetos_select ON public.projetos FOR SELECT TO authenticated USING (true);


--
-- Name: projetos projetos_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY projetos_update ON public.projetos FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role, 'operador'::public.usuario_role]))))));


--
-- Name: quote_history; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quote_history ENABLE ROW LEVEL SECURITY;

--
-- Name: quotes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quotes ENABLE ROW LEVEL SECURITY;

--
-- Name: remessas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.remessas ENABLE ROW LEVEL SECURITY;

--
-- Name: remessas remessas_delete_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY remessas_delete_policy ON public.remessas FOR DELETE USING (true);


--
-- Name: remessas remessas_insert_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY remessas_insert_policy ON public.remessas FOR INSERT WITH CHECK ((auth.uid() IS NOT NULL));


--
-- Name: remessas remessas_select_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY remessas_select_policy ON public.remessas FOR SELECT USING (true);


--
-- Name: remessas remessas_update_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY remessas_update_policy ON public.remessas FOR UPDATE USING (true) WITH CHECK ((auth.uid() IS NOT NULL));


--
-- Name: retornos_processados; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.retornos_processados ENABLE ROW LEVEL SECURITY;

--
-- Name: revenda_ubiqua; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.revenda_ubiqua ENABLE ROW LEVEL SECURITY;

--
-- Name: revenda_ubiqua revenda_ubiqua_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY revenda_ubiqua_delete ON public.revenda_ubiqua FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: revenda_ubiqua revenda_ubiqua_delete_admin_ubiqua; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY revenda_ubiqua_delete_admin_ubiqua ON public.revenda_ubiqua FOR DELETE TO authenticated USING (((EXISTS ( SELECT 1
   FROM public.usuarios_ubiqua u
  WHERE ((u.id = auth.uid()) AND (u.nivel_acesso = 'admin'::public.nivel_acesso_tipo)))) OR (EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role])))))));


--
-- Name: revenda_ubiqua revenda_ubiqua_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY revenda_ubiqua_insert ON public.revenda_ubiqua FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: revenda_ubiqua revenda_ubiqua_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY revenda_ubiqua_select ON public.revenda_ubiqua FOR SELECT TO authenticated USING (true);


--
-- Name: revenda_ubiqua revenda_ubiqua_select_anon; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY revenda_ubiqua_select_anon ON public.revenda_ubiqua FOR SELECT TO anon USING (true);


--
-- Name: revenda_ubiqua revenda_ubiqua_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY revenda_ubiqua_update ON public.revenda_ubiqua FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: separacao_itens sep_itens_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sep_itens_delete ON public.separacao_itens FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: separacao_itens sep_itens_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sep_itens_insert ON public.separacao_itens FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role, 'operador'::public.usuario_role]))))));


--
-- Name: separacao_itens sep_itens_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sep_itens_select ON public.separacao_itens FOR SELECT TO authenticated USING (true);


--
-- Name: separacao_itens sep_itens_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sep_itens_update ON public.separacao_itens FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role, 'operador'::public.usuario_role]))))));


--
-- Name: separacao_arquivos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.separacao_arquivos ENABLE ROW LEVEL SECURITY;

--
-- Name: separacao_arquivos separacao_arquivos_authenticated_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY separacao_arquivos_authenticated_all ON public.separacao_arquivos TO authenticated USING (true) WITH CHECK (true);


--
-- Name: separacao_itens; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.separacao_itens ENABLE ROW LEVEL SECURITY;

--
-- Name: separacoes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.separacoes ENABLE ROW LEVEL SECURITY;

--
-- Name: separacoes_arquivos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.separacoes_arquivos ENABLE ROW LEVEL SECURITY;

--
-- Name: separacoes_arquivos separacoes_arquivos_authenticated_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY separacoes_arquivos_authenticated_all ON public.separacoes_arquivos TO authenticated USING (true) WITH CHECK (true);


--
-- Name: separacoes separacoes_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY separacoes_delete_admin ON public.separacoes FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: separacoes separacoes_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY separacoes_insert ON public.separacoes FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role, 'operador'::public.usuario_role]))))));


--
-- Name: separacoes separacoes_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY separacoes_select ON public.separacoes FOR SELECT TO authenticated USING (true);


--
-- Name: separacoes separacoes_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY separacoes_update ON public.separacoes FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role, 'operador'::public.usuario_role]))))));


--
-- Name: projeto_sinal sinal_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sinal_delete_admin ON public.projeto_sinal FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: projeto_sinal sinal_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sinal_insert ON public.projeto_sinal FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role, 'operador'::public.usuario_role]))))));


--
-- Name: projeto_sinal sinal_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sinal_select ON public.projeto_sinal FOR SELECT TO authenticated USING (true);


--
-- Name: projeto_sinal sinal_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sinal_update ON public.projeto_sinal FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role, 'operador'::public.usuario_role]))))));


--
-- Name: solicitacoes_compra; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.solicitacoes_compra ENABLE ROW LEVEL SECURITY;

--
-- Name: sync_history; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sync_history ENABLE ROW LEVEL SECURITY;

--
-- Name: sync_history sync_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sync_insert ON public.sync_history FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role, 'operador'::public.usuario_role]))))));


--
-- Name: sync_history sync_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sync_select ON public.sync_history FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: systems; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.systems ENABLE ROW LEVEL SECURITY;

--
-- Name: transacoes trans_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY trans_delete_admin ON public.transacoes FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = 'admin'::public.usuario_role)))));


--
-- Name: transacoes trans_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY trans_insert ON public.transacoes FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role, 'operador'::public.usuario_role]))))));


--
-- Name: transacoes trans_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY trans_select ON public.transacoes FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role, 'operador'::public.usuario_role]))))));


--
-- Name: transacoes trans_update_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY trans_update_admin ON public.transacoes FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = 'admin'::public.usuario_role)))));


--
-- Name: transacoes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.transacoes ENABLE ROW LEVEL SECURITY;

--
-- Name: orcamentos_revenda_ubiqua update_orcamentos_revenda_ubiqua; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY update_orcamentos_revenda_ubiqua ON public.orcamentos_revenda_ubiqua FOR UPDATE TO authenticated, anon USING (true) WITH CHECK (true);


--
-- Name: logs_auditoria user_insert_logs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_insert_logs ON public.logs_auditoria FOR INSERT TO authenticated WITH CHECK ((usuario_id = auth.uid()));


--
-- Name: user_roles_separacao; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_roles_separacao ENABLE ROW LEVEL SECURITY;

--
-- Name: user_system_access user_select_usa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_select_usa ON public.user_system_access FOR SELECT TO authenticated USING ((user_id = auth.uid()));


--
-- Name: user_system_access; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_system_access ENABLE ROW LEVEL SECURITY;

--
-- Name: usuarios; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;

--
-- Name: usuarios usuarios_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY usuarios_delete_admin ON public.usuarios FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = 'admin'::public.usuario_role)))));


--
-- Name: usuarios usuarios_insert_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY usuarios_insert_admin ON public.usuarios FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = 'admin'::public.usuario_role)))));


--
-- Name: usuarios usuarios_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY usuarios_select_own ON public.usuarios FOR SELECT TO authenticated USING (true);


--
-- Name: usuarios_ubiqua; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.usuarios_ubiqua ENABLE ROW LEVEL SECURITY;

--
-- Name: usuarios_ubiqua usuarios_ubiqua_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY usuarios_ubiqua_delete ON public.usuarios_ubiqua FOR DELETE TO authenticated USING (((id = auth.uid()) OR public.is_ubiqua_admin()));


--
-- Name: usuarios_ubiqua usuarios_ubiqua_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY usuarios_ubiqua_insert ON public.usuarios_ubiqua FOR INSERT TO authenticated WITH CHECK (((id = auth.uid()) OR public.is_ubiqua_admin()));


--
-- Name: usuarios_ubiqua usuarios_ubiqua_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY usuarios_ubiqua_select ON public.usuarios_ubiqua FOR SELECT TO authenticated USING (((id = auth.uid()) OR public.is_ubiqua_admin()));


--
-- Name: usuarios_ubiqua usuarios_ubiqua_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY usuarios_ubiqua_update ON public.usuarios_ubiqua FOR UPDATE TO authenticated USING (((id = auth.uid()) OR public.is_ubiqua_admin())) WITH CHECK (((id = auth.uid()) OR public.is_ubiqua_admin()));


--
-- Name: usuarios usuarios_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY usuarios_update_own ON public.usuarios FOR UPDATE TO authenticated USING (((id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = auth.uid()) AND (u.role = 'admin'::public.usuario_role))))));


--
-- Name: vendas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.vendas ENABLE ROW LEVEL SECURITY;

--
-- Name: vendas_marca vendas_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY vendas_delete ON public.vendas_marca FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: vendas_marca vendas_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY vendas_insert ON public.vendas_marca FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: vendas_marca; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.vendas_marca ENABLE ROW LEVEL SECURITY;

--
-- Name: vendas_marca vendas_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY vendas_select ON public.vendas_marca FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role, 'operador'::public.usuario_role]))))));


--
-- Name: vendas_marca vendas_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY vendas_update ON public.vendas_marca FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- PostgreSQL database dump complete
--

\unrestrict bEOEq0x0RgSEJMK4u2zA0jM9A12IpctkQStRH3JoNXs9TmjSS0absABRm0c70Uc

