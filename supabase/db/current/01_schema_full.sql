--
-- PostgreSQL database dump
--

\restrict e7TVCb6GY9ci1jGtCdkQIknYgVn4jxgjRbp53wNeV6ps8QEOAthc7ikZraw1yjP

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
    'Emissão Projeto Executivo',
    'Aprovação Financeira',
    'Orçamento Aprovado'
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
-- Name: adm_aprovar_pelo_cliente(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.adm_aprovar_pelo_cliente(p_orcamento_id uuid, p_observacao text DEFAULT 'Aprovação registrada manualmente pela administração'::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: FUNCTION adm_aprovar_pelo_cliente(p_orcamento_id uuid, p_observacao text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.adm_aprovar_pelo_cliente(p_orcamento_id uuid, p_observacao text) IS 'Registra aprovação do cliente manualmente (casos presenciais/verbais, sem token).
Permitido apenas pela ADM (SECURITY DEFINER). Registra em historico_status_orcamentos.';


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
-- Name: aprovar_orcamento_cliente(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aprovar_orcamento_cliente(p_orcamento_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: aprovar_orcamento_cliente_manual(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aprovar_orcamento_cliente_manual(p_orcamento_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: aprovar_orcamento_cliente_publico(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aprovar_orcamento_cliente_publico(p_orcamento_id uuid, p_token text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: aprovar_orcamento_financeiro(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aprovar_orcamento_financeiro(p_orcamento_id uuid) RETURNS jsonb
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
$$;


--
-- Name: FUNCTION aprovar_orcamento_financeiro(p_orcamento_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.aprovar_orcamento_financeiro(p_orcamento_id uuid) IS 'SPEC-016: aprovacao financeira transacional por orcamento_id. Aceita apenas status Aprovação Financeira e finaliza em Orçamento Aprovado.';


--
-- Name: aprovar_orcamento_financeiro_base_spec001(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aprovar_orcamento_financeiro_base_spec001(p_orcamento_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: FUNCTION aprovar_orcamento_financeiro_base_spec001(p_orcamento_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.aprovar_orcamento_financeiro_base_spec001(p_orcamento_id uuid) IS 'Wrapper legado da SPEC-001. O contrato oficial esta em aprovar_orcamento_financeiro(uuid).';


--
-- Name: aprovar_projeto_financeiro(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aprovar_projeto_financeiro(p_project_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  RAISE EXCEPTION 'aprovar_projeto_financeiro foi descontinuada. Use aprovar_orcamento_financeiro(p_orcamento_id) para aprovar apenas um orçamento.'
    USING ERRCODE = 'P0002';
END;
$$;


--
-- Name: FUNCTION aprovar_projeto_financeiro(p_project_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.aprovar_projeto_financeiro(p_project_id uuid) IS 'Descontinuada pela SPEC-016 para evitar aprovacao financeira por project_id.';


--
-- Name: aprovar_transferencia_estoque(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aprovar_transferencia_estoque(p_transferencia_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: FUNCTION aprovar_transferencia_estoque(p_transferencia_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.aprovar_transferencia_estoque(p_transferencia_id uuid) IS 'SPEC-011. Aprova transferencia: origem perde q_reserva e ganha q_entrega_futura; destino ganha q_reserva e perde q_entrega_futura ate o limite disponivel. Restrito a admin/gerente.';


--
-- Name: can_user_approve_quotes(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_user_approve_quotes() RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.usuarios
    WHERE id = auth.uid() AND coalesce(can_approve_quotes, false) = true
  );
END;
$$;


--
-- Name: cancelar_orcamento(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cancelar_orcamento(p_orcamento_id uuid, p_motivo text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
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
$$;


--
-- Name: FUNCTION cancelar_orcamento(p_orcamento_id uuid, p_motivo text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.cancelar_orcamento(p_orcamento_id uuid, p_motivo text) IS 'Cancela um orçamento. Se aprovado: reverte quantidade_reservada em estoque_itens
com base no saldo aberto real do item (SPEC-010), cancela projeto_parcelas,
cancela boletos, invalida projeto_itens e encerra o saldo operacional do item.
Todos os artefatos são mantidos para auditoria (soft-cancel). Registra em
historico_status_orcamentos e estoque_movimentos_projeto_item.';


--
-- Name: cancelar_transferencia_estoque(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cancelar_transferencia_estoque(p_transferencia_id uuid, p_motivo text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: FUNCTION cancelar_transferencia_estoque(p_transferencia_id uuid, p_motivo text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.cancelar_transferencia_estoque(p_transferencia_id uuid, p_motivo text) IS 'SPEC-011. Cancela transferencia ainda nao aprovada. Nao reverte saldo, pois transferencia solicitada nao altera saldo.';


--
-- Name: cliente_aprovar_orcamento(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cliente_aprovar_orcamento(p_orcamento_id uuid, p_token text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: FUNCTION cliente_aprovar_orcamento(p_orcamento_id uuid, p_token text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.cliente_aprovar_orcamento(p_orcamento_id uuid, p_token text) IS 'Aprovação do cliente via token (link enviado por e-mail/WhatsApp).
Token é de uso único — invalidado após aprovação. Registra em historico_status_orcamentos.';


--
-- Name: cliente_recusar_orcamento(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cliente_recusar_orcamento(p_orcamento_id uuid, p_token text, p_motivo text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: FUNCTION cliente_recusar_orcamento(p_orcamento_id uuid, p_token text, p_motivo text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.cliente_recusar_orcamento(p_orcamento_id uuid, p_token text, p_motivo text) IS 'Recusa do cliente via token (link enviado por e-mail/WhatsApp).
Registra motivo e invalida o token. Permite reenvio posterior via enviar_orcamento_para_cliente.';


--
-- Name: criar_produto_orcamento(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.criar_produto_orcamento(p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
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
$_$;


--
-- Name: FUNCTION criar_produto_orcamento(p_payload jsonb); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.criar_produto_orcamento(p_payload jsonb) IS 'SPEC-018: cria produto canonico em public.produtos a partir do modal de Orcamentos, com validacao de codigo_produto, sku, marca e categoria.';


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
-- Name: current_user_funcionario_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.current_user_funcionario_id() RETURNS uuid
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT id FROM public.funcionarios
  WHERE usuario_id = auth.uid()
  LIMIT 1;
$$;


--
-- Name: current_user_is_funcionario(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.current_user_is_funcionario() RETURNS boolean
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.funcionarios
    WHERE usuario_id = auth.uid()
  );
$$;


--
-- Name: enviar_orcamento_para_cliente(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enviar_orcamento_para_cliente(p_orcamento_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_orcamento  public.orcamentos%ROWTYPE;
    v_numero     text;
    v_status_ant text;
    v_token      text;
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
$$;


--
-- Name: FUNCTION enviar_orcamento_para_cliente(p_orcamento_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.enviar_orcamento_para_cliente(p_orcamento_id uuid) IS 'Envia orçamento para aprovação do cliente. Gera token único para o link de aprovação.
Permitido em: aguardando_aprovacao, recusado_cliente. Registra em historico_status_orcamentos.';


--
-- Name: finalizar_validacao_financeira(uuid, jsonb, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.finalizar_validacao_financeira(p_project_id uuid, p_project_data jsonb, p_orcamentos jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  RAISE EXCEPTION 'finalizar_validacao_financeira foi descontinuada. Edite o orçamento e depois chame aprovar_orcamento_financeiro(p_orcamento_id).'
    USING ERRCODE = 'P0002';
END;
$$;


--
-- Name: FUNCTION finalizar_validacao_financeira(p_project_id uuid, p_project_data jsonb, p_orcamentos jsonb); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.finalizar_validacao_financeira(p_project_id uuid, p_project_data jsonb, p_orcamentos jsonb) IS 'Descontinuada pela SPEC-016: edicao financeira nao aprova projeto/orcamentos em lote.';


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
-- Name: fn_auditoria_permissoes(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_auditoria_permissoes() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: FUNCTION fn_auditoria_permissoes(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_auditoria_permissoes() IS 'SPEC-006. Grava em auditoria_permissoes toda alteracao de papel/permissao/atribuicao/excecao. entidade_id vem da coluna id de cada tabela (usuario_papeis nao tem id proprio - ver excecao abaixo).';


--
-- Name: fn_auditoria_usuario_papeis(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_auditoria_usuario_papeis() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
-- Name: fn_sync_equipe_por_responsavel(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_sync_equipe_por_responsavel() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
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
-- Name: fn_validar_saldo_projeto_item(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_validar_saldo_projeto_item() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: gen_token_hex(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.gen_token_hex() RETURNS text
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT md5(gen_random_uuid()::text) || md5(gen_random_uuid()::text);
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
    equipe_responsavel_obra_id uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    area_do_projeto jsonb,
    "Nome Arquiteto" text,
    codigo_legado integer,
    empresa_id uuid,
    valor_total numeric(15,2) DEFAULT 0 NOT NULL,
    equipe_id uuid,
    responsavel_obra_id uuid,
    CONSTRAINT check_area_projeto_estrutura CHECK (((area_do_projeto IS NULL) OR (jsonb_typeof(area_do_projeto) = 'object'::text))),
    CONSTRAINT check_tipo_projeto_valido CHECK (((area_do_projeto IS NULL) OR ((area_do_projeto ->> 'tipo'::text) IS NULL) OR ((area_do_projeto ->> 'tipo'::text) = ANY (ARRAY['Residential'::text, 'Corporativo'::text, 'Exposição Comercial'::text, 'Paisagismo'::text])))),
    CONSTRAINT chk_historico_is_array CHECK ((jsonb_typeof(historico) = 'array'::text))
);


--
-- Name: COLUMN projetos.historico; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.projetos.historico IS 'Array JSON. Cada entrada: {"campo":"status","valor_anterior":"...","valor_novo":"...","alterado_em":"ISO8601","alterado_por":"uuid","sistema_origem":"crm|sharepoint|rh"}';



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
-- Name: get_my_funcionario_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_my_funcionario_id() RETURNS uuid
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT id FROM public.funcionarios WHERE usuario_id = auth.uid();
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
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT role::text FROM public.usuarios WHERE id = auth.uid();
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
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: handle_orcamento_item_workflow(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_orcamento_item_workflow() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_status text;
  v_empresa_id uuid;
  v_projeto_id uuid;
  v_cliente_id uuid;
  v_forma_pagamento public.pagamento_forma;
BEGIN
  SELECT status, empresa_id, projeto_id, cliente_id, forma_pagamento
    INTO v_status, v_empresa_id, v_projeto_id, v_cliente_id, v_forma_pagamento
  FROM public.orcamentos
  WHERE id = NEW.orcamento_id;

  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  IF (v_status IN ('rascunho', 'aguardando_cliente') OR v_status IS NULL) THEN
    IF v_empresa_id IS NOT NULL
       AND v_projeto_id IS NOT NULL
       AND v_cliente_id IS NOT NULL
       AND v_forma_pagamento IS NOT NULL THEN
      UPDATE public.orcamentos
      SET status = 'enviado_cliente',
          token_aprovacao_cliente = COALESCE(token_aprovacao_cliente, public.gen_token_hex()),
          enviado_cliente_em = COALESCE(enviado_cliente_em, now()),
          enviado_cliente_por = COALESCE(enviado_cliente_por, auth.uid())
      WHERE id = NEW.orcamento_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: handle_orcamento_workflow(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_orcamento_workflow() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_old_status text;
  v_has_items boolean := false;
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

  -- Auto-transition from rascunho/aguardando_cliente to enviado_cliente
  -- when all mandatory data AND at least one item exist
  IF (NEW.status IN ('rascunho', 'aguardando_cliente') OR NEW.status IS NULL) THEN
    IF NEW.empresa_id IS NOT NULL
       AND NEW.projeto_id IS NOT NULL
       AND NEW.cliente_id IS NOT NULL
       AND NEW.forma_pagamento IS NOT NULL THEN
      SELECT EXISTS(
        SELECT 1 FROM public.orcamento_itens WHERE orcamento_id = NEW.id
      ) INTO v_has_items;
      IF v_has_items THEN
        NEW.status := 'enviado_cliente';
        NEW.token_aprovacao_cliente := public.gen_token_hex();
        NEW.enviado_cliente_em := COALESCE(NEW.enviado_cliente_em, now());
        NEW.enviado_cliente_por := COALESCE(NEW.enviado_cliente_por, auth.uid());
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: handle_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;


--
-- Name: hub_pode_executar(uuid, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.hub_pode_executar(p_usuario_id uuid, p_system_slug text, p_modulo_chave text, p_acao text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: FUNCTION hub_pode_executar(p_usuario_id uuid, p_system_slug text, p_modulo_chave text, p_acao text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.hub_pode_executar(p_usuario_id uuid, p_system_slug text, p_modulo_chave text, p_acao text) IS 'SPEC-006. Combina papel + excecao individual (excecao sempre tem prioridade). Contrato publicado para os demais sistemas adotarem quando quiserem.';


--
-- Name: systems; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.systems (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text NOT NULL,
    link text NOT NULL,
    icon_name text,
    display_order integer DEFAULT 0,
    slug text NOT NULL,
    visivel_no_hub boolean DEFAULT true NOT NULL
);


--
-- Name: COLUMN systems.slug; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.systems.slug IS 'SPEC-006. Identificador estavel usado por hub_pode_executar/hub_sistemas_permitidos.';


--
-- Name: COLUMN systems.visivel_no_hub; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.systems.visivel_no_hub IS 'SPEC-006. Diferencia sistemas exibidos como card na Central dos regidos apenas por permissao (ex.: o proprio Hub, para auto-governanca). Nao substitui a distincao completa de TI-14.';


--
-- Name: hub_sistemas_permitidos(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.hub_sistemas_permitidos(p_usuario_id uuid) RETURNS SETOF public.systems
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT DISTINCT s.*
  FROM systems s
  JOIN papel_permissoes pp ON pp.system_id = s.id
  JOIN usuario_papeis up ON up.papel_id = pp.papel_id AND up.usuario_id = p_usuario_id
  WHERE (pp.acao = 'visualizar' OR pp.acao IS NULL)
    AND s.visivel_no_hub = true
$$;


--
-- Name: FUNCTION hub_sistemas_permitidos(p_usuario_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.hub_sistemas_permitidos(p_usuario_id uuid) IS 'SPEC-006. Substitui a leitura direta de user_system_access nos cards do Hub. Exclui sistemas com visivel_no_hub = false (ex.: o proprio Hub).';


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
-- Name: link_my_funcionario_record(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.link_my_funcionario_record() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: log_can_approve_quotes_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.log_can_approve_quotes_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: normalize_orcamento_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.normalize_orcamento_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: processar_retorno_bancario(text, text, text, jsonb, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.processar_retorno_bancario(p_nome_arquivo text, p_hash text, p_conta text, p_registros jsonb, p_forcar boolean DEFAULT false) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: FUNCTION processar_retorno_bancario(p_nome_arquivo text, p_hash text, p_conta text, p_registros jsonb, p_forcar boolean); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.processar_retorno_bancario(p_nome_arquivo text, p_hash text, p_conta text, p_registros jsonb, p_forcar boolean) IS 'SPEC-008. Aplica lote de retorno CNAB: baixa boleto/parcela + lanca transacao quando valor confere; marca divergente sem alterar nada quando nao confere; marca nao_encontrado quando nosso_numero nao existe. Bloqueia reprocessamento do mesmo hash salvo p_forcar=true.';


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
-- Name: registrar_devolucao_projeto_item(uuid, numeric, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.registrar_devolucao_projeto_item(p_projeto_item_id uuid, p_quantidade numeric, p_motivo text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: FUNCTION registrar_devolucao_projeto_item(p_projeto_item_id uuid, p_quantidade numeric, p_motivo text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.registrar_devolucao_projeto_item(p_projeto_item_id uuid, p_quantidade numeric, p_motivo text) IS 'SPEC-015. Devolucao por projeto_item_id, reduzindo saldos na ordem q_entrega_futura -> q_reserva -> q_entregue. Nao altera projeto_itens.quantidade (Q. Venda). Devolucao que toca q_entregue fica aguardando_coleta.';


--
-- Name: replace_orcamento_itens(uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.replace_orcamento_itens(p_orcamento_id uuid, p_items jsonb) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
-- Name: solicitar_transferencia_estoque(uuid, uuid, numeric, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.solicitar_transferencia_estoque(p_origem_projeto_item_id uuid, p_destino_projeto_item_id uuid, p_quantidade numeric, p_motivo text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: FUNCTION solicitar_transferencia_estoque(p_origem_projeto_item_id uuid, p_destino_projeto_item_id uuid, p_quantidade numeric, p_motivo text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.solicitar_transferencia_estoque(p_origem_projeto_item_id uuid, p_destino_projeto_item_id uuid, p_quantidade numeric, p_motivo text) IS 'SPEC-011. Registra solicitacao de transferencia de q_reserva entre dois projeto_item_id do mesmo produto. Nao altera saldo ainda.';


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
-- Name: sync_contact_type_on_budget(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_contact_type_on_budget() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
-- Name: trg_estoque_saldos_projeto_item_atualizado_em(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_estoque_saldos_projeto_item_atualizado_em() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.atualizado_em := now();
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
-- Name: auditoria_permissoes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auditoria_permissoes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    autor_id uuid,
    entidade text NOT NULL,
    entidade_id uuid,
    antes jsonb,
    depois jsonb,
    criado_em timestamp with time zone DEFAULT now()
);


--
-- Name: TABLE auditoria_permissoes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.auditoria_permissoes IS 'SPEC-006. Auditoria automatica de alteracoes em papeis/permissoes/atribuicoes/excecoes.';


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
-- Name: COLUMN contatos.razao_social; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contatos.razao_social IS 'Razão social (nome jurídico) do cliente. Equivale ao campo rzCliente da planilha de importação. Diferente de nome (nome fantasia/comercial = nmCliente).';


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
-- Name: cross_system_session_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cross_system_session_codes (
    code uuid DEFAULT gen_random_uuid() NOT NULL,
    usuario_id uuid NOT NULL,
    sistema_origem text NOT NULL,
    sistema_destino text,
    contexto jsonb,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    expira_em timestamp with time zone DEFAULT (now() + '00:01:00'::interval) NOT NULL,
    usado_em timestamp with time zone
);


--
-- Name: TABLE cross_system_session_codes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.cross_system_session_codes IS 'SPEC-007. Codigo opaco de curta duracao e uso unico para hidratar sessao Supabase entre apps.';


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
-- Name: devolucoes_estoque; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.devolucoes_estoque (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    projeto_item_id uuid NOT NULL,
    quantidade numeric(10,3) NOT NULL,
    qtd_de_entrega_futura numeric(10,3) DEFAULT 0 NOT NULL,
    qtd_de_reserva numeric(10,3) DEFAULT 0 NOT NULL,
    qtd_de_entregue numeric(10,3) DEFAULT 0 NOT NULL,
    status text DEFAULT 'registrada'::text NOT NULL,
    motivo text,
    gera_credito_financeiro boolean,
    solicitado_por uuid,
    aprovado_por uuid,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    aprovado_em timestamp with time zone,
    cancelado_em timestamp with time zone,
    CONSTRAINT devolucoes_estoque_qtd_de_entrega_futura_check CHECK ((qtd_de_entrega_futura >= (0)::numeric)),
    CONSTRAINT devolucoes_estoque_qtd_de_entregue_check CHECK ((qtd_de_entregue >= (0)::numeric)),
    CONSTRAINT devolucoes_estoque_qtd_de_reserva_check CHECK ((qtd_de_reserva >= (0)::numeric)),
    CONSTRAINT devolucoes_estoque_quantidade_check CHECK ((quantidade > (0)::numeric)),
    CONSTRAINT devolucoes_estoque_status_check CHECK ((status = ANY (ARRAY['registrada'::text, 'aguardando_coleta'::text, 'coletada'::text, 'cancelada'::text])))
);


--
-- Name: TABLE devolucoes_estoque; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.devolucoes_estoque IS 'SPEC-015. Devolucao por projeto_item_id, reduzindo saldos na ordem q_entrega_futura -> q_reserva -> q_entregue, preservando projeto_itens.quantidade (Q. Venda).';


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
    separacao_id uuid,
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
-- Name: equipes_projetos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.equipes_projetos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    equipes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
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
-- Name: estoque_movimentos_projeto_item; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.estoque_movimentos_projeto_item (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    projeto_item_id uuid NOT NULL,
    projeto_item_destino_id uuid,
    tipo text NOT NULL,
    quantidade numeric(10,3) NOT NULL,
    origem text,
    referencia_id uuid,
    observacao text,
    criado_por uuid,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT estoque_movimentos_projeto_item_quantidade_check CHECK ((quantidade > (0)::numeric)),
    CONSTRAINT estoque_movimentos_projeto_item_tipo_check CHECK ((tipo = ANY (ARRAY['aprovacao_orcamento'::text, 'alocacao_reserva'::text, 'alocacao_entrega_futura'::text, 'transferencia_saida'::text, 'transferencia_entrada'::text, 'recebimento_para_reserva'::text, 'solicitacao_separacao'::text, 'separado'::text, 'entregue'::text, 'devolucao'::text, 'cancelamento'::text])))
);


--
-- Name: TABLE estoque_movimentos_projeto_item; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.estoque_movimentos_projeto_item IS 'SPEC-010. Auditoria de cada movimento que altera estoque_saldos_projeto_item.';


--
-- Name: estoque_saldos_projeto_item; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.estoque_saldos_projeto_item (
    projeto_item_id uuid NOT NULL,
    q_reserva numeric(10,3) DEFAULT 0 NOT NULL,
    q_entrega_futura numeric(10,3) DEFAULT 0 NOT NULL,
    q_ag_separar numeric(10,3) DEFAULT 0 NOT NULL,
    q_separado numeric(10,3) DEFAULT 0 NOT NULL,
    q_entregue numeric(10,3) DEFAULT 0 NOT NULL,
    q_devolvida numeric(10,3) DEFAULT 0 NOT NULL,
    q_transferida_saida numeric(10,3) DEFAULT 0 NOT NULL,
    status_operacional text DEFAULT 'ativo'::text NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT estoque_saldos_projeto_item_q_ag_separar_check CHECK ((q_ag_separar >= (0)::numeric)),
    CONSTRAINT estoque_saldos_projeto_item_q_devolvida_check CHECK ((q_devolvida >= (0)::numeric)),
    CONSTRAINT estoque_saldos_projeto_item_q_entrega_futura_check CHECK ((q_entrega_futura >= (0)::numeric)),
    CONSTRAINT estoque_saldos_projeto_item_q_entregue_check CHECK ((q_entregue >= (0)::numeric)),
    CONSTRAINT estoque_saldos_projeto_item_q_reserva_check CHECK ((q_reserva >= (0)::numeric)),
    CONSTRAINT estoque_saldos_projeto_item_q_separado_check CHECK ((q_separado >= (0)::numeric)),
    CONSTRAINT estoque_saldos_projeto_item_q_transferida_saida_check CHECK ((q_transferida_saida >= (0)::numeric)),
    CONSTRAINT estoque_saldos_projeto_item_status_operacional_check CHECK ((status_operacional = ANY (ARRAY['ativo'::text, 'cancelado'::text, 'encerrado'::text])))
);


--
-- Name: TABLE estoque_saldos_projeto_item; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.estoque_saldos_projeto_item IS 'SPEC-010. Saldo operacional vivo por projeto_itens.id. Cliente/projeto/orçamento/produto são lidos por relacionamento (ver vw_estoque_saldos_projeto_item), nunca duplicados aqui.';


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
    email text,
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
    salario_liquido numeric(12,2) GENERATED ALWAYS AS ((salario_base + salario_por_fora)) STORED,
    equipes_id uuid
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
-- Name: modulo_acoes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.modulo_acoes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    modulo_id uuid NOT NULL,
    chave text NOT NULL,
    CONSTRAINT modulo_acoes_chave_check CHECK ((chave = ANY (ARRAY['criar'::text, 'editar'::text, 'deletar'::text, 'visualizar'::text])))
);


--
-- Name: TABLE modulo_acoes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.modulo_acoes IS 'SPEC-006. Acoes possiveis dentro de um modulo.';


--
-- Name: modulos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.modulos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    system_id uuid NOT NULL,
    chave text NOT NULL,
    nome text NOT NULL,
    descricao text,
    ordem integer DEFAULT 0
);


--
-- Name: TABLE modulos; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.modulos IS 'SPEC-006. Modulos/abas configuraveis por sistema.';


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
    descricao text,
    ordem integer DEFAULT 0,
    sub_ordem integer DEFAULT 0,
    peca_nova boolean DEFAULT false
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
    status text DEFAULT 'rascunho'::text,
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
    requer_revisao_financeira boolean DEFAULT false,
    enviado_cliente_em timestamp with time zone,
    enviado_cliente_por uuid,
    aprovado_cliente_em timestamp with time zone,
    recusado_cliente_em timestamp with time zone,
    motivo_recusa_cliente text,
    token_aprovacao_cliente text,
    CONSTRAINT orcamentos_frete_coerencia_check CHECK (((frete_tipo IS NULL) OR ((frete_tipo = 'sem_frete'::text) AND (COALESCE(frete_valor, (0)::numeric) = (0)::numeric)) OR ((frete_tipo = 'com_frete'::text) AND (frete_valor > (0)::numeric)))),
    CONSTRAINT orcamentos_frete_tipo_check CHECK (((frete_tipo IS NULL) OR (frete_tipo = ANY (ARRAY['com_frete'::text, 'sem_frete'::text])))),
    CONSTRAINT orcamentos_prazo_inicio_cobranca_dias_check CHECK (((prazo_inicio_cobranca_dias IS NULL) OR (prazo_inicio_cobranca_dias >= 0)))
);


--
-- Name: COLUMN orcamentos.empresa_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.orcamentos.empresa_id IS 'ÂNCORA: Define se a venda é Foco, Manoella ou Islight. Todo o fluxo financeiro e de estoque herdará este ID.';


--
-- Name: COLUMN orcamentos.enviado_cliente_em; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.orcamentos.enviado_cliente_em IS 'Quando o orçamento foi enviado ao cliente pela última vez';


--
-- Name: COLUMN orcamentos.enviado_cliente_por; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.orcamentos.enviado_cliente_por IS 'Usuário interno que enviou o orçamento ao cliente';


--
-- Name: COLUMN orcamentos.aprovado_cliente_em; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.orcamentos.aprovado_cliente_em IS 'Quando o cliente aprovou o orçamento';


--
-- Name: COLUMN orcamentos.recusado_cliente_em; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.orcamentos.recusado_cliente_em IS 'Quando o cliente recusou o orçamento (mais recente)';


--
-- Name: COLUMN orcamentos.motivo_recusa_cliente; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.orcamentos.motivo_recusa_cliente IS 'Motivo informado pelo cliente na recusa mais recente';


--
-- Name: COLUMN orcamentos.token_aprovacao_cliente; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.orcamentos.token_aprovacao_cliente IS 'Token de uso único para o link de aprovação do cliente';


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
-- Name: papeis; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.papeis (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nome text NOT NULL,
    descricao text,
    criado_em timestamp with time zone DEFAULT now()
);


--
-- Name: TABLE papeis; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.papeis IS 'SPEC-006. Papeis configuraveis; convivem com usuarios.role durante a transicao.';


--
-- Name: papel_permissoes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.papel_permissoes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    papel_id uuid NOT NULL,
    system_id uuid NOT NULL,
    modulo_id uuid,
    acao text,
    CONSTRAINT papel_permissoes_acao_check CHECK ((acao = ANY (ARRAY['criar'::text, 'editar'::text, 'deletar'::text, 'visualizar'::text])))
);


--
-- Name: TABLE papel_permissoes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.papel_permissoes IS 'SPEC-006. modulo_id NULL = todos os modulos ("ver tudo"); acao NULL = todas as acoes.';


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
    percentual_lucro numeric(9,2) DEFAULT 0,
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
-- Name: retorno_bancario_arquivos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.retorno_bancario_arquivos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nome_arquivo text NOT NULL,
    hash_conteudo text NOT NULL,
    conta text,
    processado_por uuid,
    processado_em timestamp with time zone DEFAULT now() NOT NULL,
    total_registros integer DEFAULT 0 NOT NULL,
    total_aplicados integer DEFAULT 0 NOT NULL,
    total_divergentes integer DEFAULT 0 NOT NULL,
    total_nao_encontrados integer DEFAULT 0 NOT NULL,
    forcado boolean DEFAULT false NOT NULL
);


--
-- Name: TABLE retorno_bancario_arquivos; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.retorno_bancario_arquivos IS 'SPEC-008. Um registro por arquivo de retorno CNAB processado, com hash do conteudo para bloquear reprocessamento acidental.';


--
-- Name: retorno_bancario_registros; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.retorno_bancario_registros (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    arquivo_id uuid NOT NULL,
    nosso_numero text NOT NULL,
    boleto_id uuid,
    parcela_id uuid,
    transacao_id uuid,
    valor_esperado numeric(12,2),
    valor_recebido numeric(12,2),
    data_pagamento date,
    ocorrencia_codigo text,
    status_aplicacao text NOT NULL,
    motivo_divergencia text,
    CONSTRAINT retorno_bancario_registros_status_aplicacao_check CHECK ((status_aplicacao = ANY (ARRAY['aplicado'::text, 'divergente'::text, 'nao_encontrado'::text, 'ja_processado'::text])))
);


--
-- Name: TABLE retorno_bancario_registros; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.retorno_bancario_registros IS 'SPEC-008. Um registro por linha do CNAB de retorno, com o resultado da aplicacao contra boletos/projeto_parcelas.';


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
-- Name: transferencias_estoque; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transferencias_estoque (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    origem_projeto_item_id uuid NOT NULL,
    destino_projeto_item_id uuid NOT NULL,
    quantidade numeric(10,3) NOT NULL,
    status text DEFAULT 'solicitada'::text NOT NULL,
    motivo text,
    solicitado_por uuid,
    aprovado_por uuid,
    solicitado_em timestamp with time zone DEFAULT now() NOT NULL,
    aprovado_em timestamp with time zone,
    cancelado_em timestamp with time zone,
    motivo_cancelamento text,
    CONSTRAINT transferencias_estoque_origem_destino_diff CHECK ((origem_projeto_item_id <> destino_projeto_item_id)),
    CONSTRAINT transferencias_estoque_quantidade_check CHECK ((quantidade > (0)::numeric)),
    CONSTRAINT transferencias_estoque_status_check CHECK ((status = ANY (ARRAY['solicitada'::text, 'aprovada'::text, 'cancelada'::text])))
);


--
-- Name: TABLE transferencias_estoque; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.transferencias_estoque IS 'SPEC-011. Transferencia de cobertura fisica (q_reserva) entre dois projeto_item_id do mesmo produto.';


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
-- Name: usuario_papeis; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usuario_papeis (
    usuario_id uuid NOT NULL,
    papel_id uuid NOT NULL
);


--
-- Name: TABLE usuario_papeis; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.usuario_papeis IS 'SPEC-006. Atribuicao de papeis a usuarios (um usuario pode ter mais de um papel).';


--
-- Name: usuario_permissao_excecoes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usuario_permissao_excecoes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    usuario_id uuid NOT NULL,
    system_id uuid NOT NULL,
    modulo_id uuid,
    acao text NOT NULL,
    tipo text NOT NULL,
    justificativa text,
    "valido_até" timestamp with time zone,
    criado_por uuid,
    criado_em timestamp with time zone DEFAULT now(),
    CONSTRAINT usuario_permissao_excecoes_acao_check CHECK ((acao = ANY (ARRAY['criar'::text, 'editar'::text, 'deletar'::text, 'visualizar'::text]))),
    CONSTRAINT usuario_permissao_excecoes_tipo_check CHECK ((tipo = ANY (ARRAY['conceder'::text, 'negar'::text])))
);


--
-- Name: TABLE usuario_permissao_excecoes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.usuario_permissao_excecoes IS 'SPEC-006. Excecao individual, com precedencia sobre o papel do usuario.';


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
    telefone text,
    can_approve_quotes boolean DEFAULT false
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
-- Name: vw_comissao_mensal; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_comissao_mensal AS
 SELECT fn.id AS funcionario_id,
    fn.nome AS funcionario,
    ep.id AS equipe_id,
    ep.equipes AS equipe,
    ff.comissao_percentual,
    (date_trunc('month'::text, (p.data_entrada)::timestamp with time zone))::date AS mes,
    count(p.id) AS total_projetos,
    round(sum(p.valor_total), 2) AS valor_total_projetos,
    round(sum(((p.valor_total * COALESCE(ff.comissao_percentual, (0)::numeric)) / 100.0)), 2) AS comissao_calculada
   FROM (((public.projetos p
     JOIN public.equipes_projetos ep ON ((ep.id = p.equipe_id)))
     JOIN public.funcionarios_financeiro ff ON ((ff.equipes_id = ep.id)))
     JOIN public.funcionarios_novo fn ON ((fn.id = ff.funcionario_id)))
  WHERE ((p.valor_total > (0)::numeric) AND (p.data_entrada IS NOT NULL) AND (fn.ativo IS TRUE))
  GROUP BY fn.id, fn.nome, ep.id, ep.equipes, ff.comissao_percentual, (date_trunc('month'::text, (p.data_entrada)::timestamp with time zone));


--
-- Name: VIEW vw_comissao_mensal; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.vw_comissao_mensal IS 'Comissão mensal por funcionário agrupada por data_entrada do projeto. Cada funcionário da equipe recebe sua própria % sobre o total da equipe no mês.';


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
    count(DISTINCT p.cliente_id) AS total_clientes,
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

CREATE VIEW public.vw_detalhe_produto_estoque WITH (security_invoker='true') AS
 SELECT produto_id,
    COALESCE(sum(quantidade), (0)::numeric) AS estoque_total,
    COALESCE(sum((quantidade - COALESCE(quantidade_reservada, (0)::numeric))), (0)::numeric) AS estoque_disponivel,
    COALESCE(sum(COALESCE(quantidade_reservada, (0)::numeric)), (0)::numeric) AS estoque_reservado
   FROM public.estoque_itens
  GROUP BY produto_id;


--
-- Name: vw_entrega_futura_projeto_item; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_entrega_futura_projeto_item WITH (security_invoker='true') AS
 SELECT esp.projeto_item_id,
    pi.produto_id,
    p.nome AS produto,
    p.codigo_produto AS produto_codigo,
    pi.projeto_id,
    pr.codigo AS projeto_codigo,
    pi.orcamento_id,
    o.numero AS orcamento_numero,
    COALESCE(o.cliente_id, pr.cliente_id) AS cliente_id,
    c.nome AS cliente,
    pi.quantidade AS q_venda,
    esp.q_entrega_futura,
    esp.q_reserva,
    esp.q_transferida_saida,
    esp.atualizado_em
   FROM (((((public.estoque_saldos_projeto_item esp
     JOIN public.projeto_itens pi ON ((pi.id = esp.projeto_item_id)))
     LEFT JOIN public.produtos p ON ((p.id = pi.produto_id)))
     LEFT JOIN public.projetos pr ON ((pr.id = pi.projeto_id)))
     LEFT JOIN public.orcamentos o ON ((o.id = pi.orcamento_id)))
     LEFT JOIN public.contatos c ON ((c.id = COALESCE(o.cliente_id, pr.cliente_id))))
  WHERE ((esp.status_operacional = 'ativo'::text) AND (esp.q_entrega_futura > (0)::numeric))
  ORDER BY p.nome, esp.atualizado_em;


--
-- Name: VIEW vw_entrega_futura_projeto_item; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.vw_entrega_futura_projeto_item IS 'SPEC-012. Saldo operacional detalhado por projeto_item_id sem cobertura fisica (q_entrega_futura > 0). SECURITY INVOKER.';


--
-- Name: vw_estoque_liquido; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_estoque_liquido AS
 WITH calc AS (
         SELECT p.id AS produto_id,
            p.nome AS produto,
            p.sku,
            m.nome AS marca,
            p.categoria,
            p.preco_custo,
            p.preco_venda,
            COALESCE(sum(ei.quantidade) FILTER (WHERE (ei.local = 'Estoque'::public.estoque_local)), (0)::numeric) AS qtd_fisico,
            (COALESCE(sum(ei.quantidade_reservada) FILTER (WHERE (ei.local = 'Estoque'::public.estoque_local)), (0)::numeric) + COALESCE(sum(ei.quantidade) FILTER (WHERE (ei.local = 'Reservado'::public.estoque_local)), (0)::numeric)) AS qtd_reservado,
            COALESCE(sum(ei.quantidade) FILTER (WHERE (ei.local = 'Showroom'::public.estoque_local)), (0)::numeric) AS qtd_showroom,
            COALESCE(sum(ei.quantidade) FILTER (WHERE (ei.local = 'Em trânsito'::public.estoque_local)), (0)::numeric) AS qtd_em_transito
           FROM ((public.produtos p
             LEFT JOIN public.marcas m ON ((m.id = p.marca_id)))
             LEFT JOIN public.estoque_itens ei ON ((ei.produto_id = p.id)))
          WHERE (p.ativo = true)
          GROUP BY p.id, p.nome, p.sku, m.nome, p.categoria, p.preco_custo, p.preco_venda
        )
 SELECT produto_id,
    produto,
    sku,
    marca,
    categoria,
    preco_custo,
    preco_venda,
    qtd_fisico,
    qtd_reservado,
    qtd_showroom,
    qtd_em_transito,
    GREATEST((0)::numeric, (qtd_fisico - qtd_reservado)) AS qtd_disponivel,
        CASE
            WHEN (GREATEST((0)::numeric, (qtd_fisico - qtd_reservado)) = (0)::numeric) THEN 'critico'::text
            WHEN (GREATEST((0)::numeric, (qtd_fisico - qtd_reservado)) <= (3)::numeric) THEN 'baixo'::text
            ELSE 'normal'::text
        END AS alerta_estoque,
    round((qtd_fisico * preco_venda), 2) AS valor_estoque_total,
    round((qtd_reservado * preco_venda), 2) AS valor_reservado_total
   FROM calc;


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
-- Name: vw_estoque_saldos_projeto_item; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_estoque_saldos_projeto_item WITH (security_invoker='true') AS
 SELECT esp.projeto_item_id,
    pi.projeto_id,
    pi.orcamento_id,
    pi.produto_id,
    COALESCE(o.cliente_id, pr.cliente_id) AS cliente_id,
    p.nome AS produto,
    p.codigo_produto AS produto_codigo,
    pr.codigo AS projeto_codigo,
    o.numero AS orcamento_numero,
    pi.quantidade AS q_venda,
    esp.q_reserva,
    esp.q_entrega_futura,
    esp.q_ag_separar,
    esp.q_separado,
    esp.q_entregue,
    esp.q_devolvida,
    esp.q_transferida_saida,
    esp.status_operacional,
    esp.atualizado_em
   FROM ((((public.estoque_saldos_projeto_item esp
     JOIN public.projeto_itens pi ON ((pi.id = esp.projeto_item_id)))
     LEFT JOIN public.projetos pr ON ((pr.id = pi.projeto_id)))
     LEFT JOIN public.orcamentos o ON ((o.id = pi.orcamento_id)))
     LEFT JOIN public.produtos p ON ((p.id = pi.produto_id)));


--
-- Name: VIEW vw_estoque_saldos_projeto_item; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.vw_estoque_saldos_projeto_item IS 'SPEC-010. Saldo operacional detalhado por item de projeto, com produto/projeto/orcamento/cliente resolvidos por relacionamento. SECURITY INVOKER para respeitar RLS das tabelas base.';


--
-- Name: vw_estoque_por_produto_projeto; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_estoque_por_produto_projeto WITH (security_invoker='true') AS
 SELECT projeto_item_id,
    projeto_id,
    orcamento_id,
    produto_id,
    cliente_id,
    produto,
    produto_codigo,
    projeto_codigo,
    orcamento_numero,
    q_venda,
    q_reserva,
    q_entrega_futura,
    q_ag_separar,
    q_separado,
    q_entregue,
    q_devolvida,
    q_transferida_saida,
    status_operacional,
    atualizado_em
   FROM public.vw_estoque_saldos_projeto_item
  WHERE (status_operacional = 'ativo'::text);


--
-- Name: VIEW vw_estoque_por_produto_projeto; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.vw_estoque_por_produto_projeto IS 'SPEC-010. Mesma leitura de vw_estoque_saldos_projeto_item, filtrada aos saldos ativos. SECURITY INVOKER para respeitar RLS das tabelas base.';


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
-- Name: vw_estoque_resumo; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_estoque_resumo WITH (security_invoker='true') AS
 SELECT ei.produto_id,
    p.nome AS produto,
    p.codigo_produto AS produto_codigo,
    ei.quantidade AS qtd_total,
    COALESCE(comprometido.qtd_comprometida, (0)::numeric) AS qtd_comprometida,
    (ei.quantidade - COALESCE(comprometido.qtd_comprometida, (0)::numeric)) AS qtd_disponivel,
    COALESCE(comprometido.qtd_entrega_futura, (0)::numeric) AS qtd_entrega_futura
   FROM ((public.estoque_itens ei
     JOIN public.produtos p ON ((p.id = ei.produto_id)))
     LEFT JOIN ( SELECT pi.produto_id,
            sum((((esp.q_reserva + esp.q_entrega_futura) + esp.q_ag_separar) + esp.q_separado)) AS qtd_comprometida,
            sum(esp.q_entrega_futura) AS qtd_entrega_futura
           FROM (public.estoque_saldos_projeto_item esp
             JOIN public.projeto_itens pi ON ((pi.id = esp.projeto_item_id)))
          WHERE (esp.status_operacional = 'ativo'::text)
          GROUP BY pi.produto_id) comprometido ON ((comprometido.produto_id = ei.produto_id)))
  WHERE (ei.local = 'Estoque'::public.estoque_local);


--
-- Name: VIEW vw_estoque_resumo; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.vw_estoque_resumo IS 'SPEC-010. Resumo por produto: total fisico, comprometido e disponivel. SECURITY INVOKER para respeitar RLS das tabelas base.';


--
-- Name: vw_financeiro_projetos; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_financeiro_projetos AS
 SELECT p.id,
    p.codigo,
    p.nome,
    p.status,
    p.cliente_id,
    c.nome AS cliente_nome,
    v.valor_total,
    v.valor_recebido,
    v.valor_pendente,
    v.total_parcelas,
    v.parcelas_pagas,
    v.parcelas_pendentes
   FROM ((public.projetos p
     LEFT JOIN public.contatos c ON (((c.id = p.cliente_id) AND (c.tipo = 'cliente'::public.contato_tipo))))
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
 SELECT fn.id,
    fn.nome,
    fn.cargo,
    fn.ativo,
    fn.data_admissao,
    fn.created_at,
    fd.cpf,
    fd.rg,
    fd.data_nascimento,
    fd.endereco,
    fd.telefone,
    fd.email,
    ff.salario_base,
    ff.salario_por_fora,
    ff.comissao_percentual,
    ff.salario_liquido,
    fb.empresa,
    fb.valor_vt_dia
   FROM (((public.funcionarios_novo fn
     LEFT JOIN public.funcionarios_detalhes fd ON ((fd.funcionario_id = fn.id)))
     LEFT JOIN public.funcionarios_financeiro ff ON ((ff.funcionario_id = fn.id)))
     LEFT JOIN public.funcionarios_beneficios_empresas fb ON ((fb.funcionario_id = fn.id)));


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
-- Name: vw_necessidade_compra; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_necessidade_compra WITH (security_invoker='true') AS
 SELECT pi.produto_id,
    p.nome AS produto,
    p.codigo_produto AS produto_codigo,
    COALESCE(ei.quantidade, (0)::numeric) AS qtd_fisica,
    sum((((esp.q_reserva + esp.q_entrega_futura) + esp.q_ag_separar) + esp.q_separado)) AS qtd_comprometida,
    sum(esp.q_entrega_futura) AS necessidade_compra,
    (COALESCE(ei.quantidade, (0)::numeric) - sum((((esp.q_reserva + esp.q_entrega_futura) + esp.q_ag_separar) + esp.q_separado))) AS qtd_disponivel,
    count(DISTINCT pi.projeto_id) FILTER (WHERE (esp.q_entrega_futura > (0)::numeric)) AS projetos_com_entrega_futura
   FROM (((public.estoque_saldos_projeto_item esp
     JOIN public.projeto_itens pi ON ((pi.id = esp.projeto_item_id)))
     LEFT JOIN public.produtos p ON ((p.id = pi.produto_id)))
     LEFT JOIN public.estoque_itens ei ON (((ei.produto_id = pi.produto_id) AND (ei.local = 'Estoque'::public.estoque_local))))
  WHERE ((esp.status_operacional = 'ativo'::text) AND (pi.produto_id IS NOT NULL))
  GROUP BY pi.produto_id, p.nome, p.codigo_produto, ei.quantidade
 HAVING (sum(esp.q_entrega_futura) > (0)::numeric)
  ORDER BY (sum(esp.q_entrega_futura)) DESC, p.nome;


--
-- Name: VIEW vw_necessidade_compra; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.vw_necessidade_compra IS 'SPEC-012. Deficit agregado por produto (soma de q_entrega_futura), sem vinculo fixo a cliente/projeto. SECURITY INVOKER.';


--
-- Name: vw_orcamentos_aprovacao_financeira_auditoria; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_orcamentos_aprovacao_financeira_auditoria AS
 SELECT o.id AS orcamento_id,
    o.numero,
    o.status,
    o.projeto_id,
    o.cliente_id,
    o.valor_total,
    o.requer_revisao_financeira,
    o.aprovado_cliente_em,
    count(DISTINCT pi.id) AS projeto_itens_por_orcamento,
    count(DISTINCT pp.id) AS parcelas_por_orcamento,
    count(DISTINCT b.id) AS boletos_por_orcamento,
        CASE
            WHEN (o.status = 'Aprovação Financeira'::text) THEN 'fila_financeira'::text
            WHEN (o.status = 'Orçamento Aprovado'::text) THEN 'aprovado_final'::text
            WHEN (o.status = ANY (ARRAY['aprovado_cliente'::text, 'aprovado'::text, 'aprovado_financeiro'::text])) THEN 'legado_revisar'::text
            ELSE 'fora_fluxo_financeiro'::text
        END AS classificacao_fluxo
   FROM (((public.orcamentos o
     LEFT JOIN public.projeto_itens pi ON ((pi.orcamento_id = o.id)))
     LEFT JOIN public.projeto_parcelas pp ON ((pp.orcamento_id = o.id)))
     LEFT JOIN public.boletos b ON ((b.orcamento_id = o.id)))
  GROUP BY o.id, o.numero, o.status, o.projeto_id, o.cliente_id, o.valor_total, o.requer_revisao_financeira, o.aprovado_cliente_em;


--
-- Name: VIEW vw_orcamentos_aprovacao_financeira_auditoria; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.vw_orcamentos_aprovacao_financeira_auditoria IS 'Auditoria da SPEC-016 para classificar orcamentos por status e artefatos financeiros gerados por orcamento_id.';


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
            (sum(
                CASE
                    WHEN (estoque_itens.local = 'Estoque'::public.estoque_local) THEN COALESCE(estoque_itens.quantidade_reservada, (0)::numeric)
                    ELSE (0)::numeric
                END) + sum(
                CASE
                    WHEN ((estoque_itens.local)::text ~~* 'reserva%'::text) THEN estoque_itens.quantidade
                    ELSE (0)::numeric
                END)) AS qtd_reserva,
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
    p.cliente_id,
    c.nome AS cliente_nome,
    COALESCE(v.valor_total, (0)::numeric) AS valor_total
   FROM ((public.projetos p
     LEFT JOIN public.contatos c ON (((c.id = p.cliente_id) AND (c.tipo = 'cliente'::public.contato_tipo))))
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
    count(DISTINCT p.cliente_id) AS total_clientes,
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
-- Name: vw_transferencias_estoque; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_transferencias_estoque WITH (security_invoker='true') AS
 SELECT t.id AS transferencia_id,
    t.status,
    pi_o.produto_id,
    p.nome AS produto,
    p.codigo_produto AS produto_codigo,
    t.quantidade,
    t.origem_projeto_item_id,
    pr_o.codigo AS origem_projeto_codigo,
    o_o.numero AS origem_orcamento_numero,
    c_o.nome AS origem_cliente,
    t.destino_projeto_item_id,
    pr_d.codigo AS destino_projeto_codigo,
    o_d.numero AS destino_orcamento_numero,
    c_d.nome AS destino_cliente,
    t.motivo,
    t.solicitado_por,
    t.aprovado_por,
    t.solicitado_em,
    t.aprovado_em,
    t.cancelado_em,
    t.motivo_cancelamento
   FROM (((((((((public.transferencias_estoque t
     JOIN public.projeto_itens pi_o ON ((pi_o.id = t.origem_projeto_item_id)))
     JOIN public.projeto_itens pi_d ON ((pi_d.id = t.destino_projeto_item_id)))
     LEFT JOIN public.produtos p ON ((p.id = pi_o.produto_id)))
     LEFT JOIN public.projetos pr_o ON ((pr_o.id = pi_o.projeto_id)))
     LEFT JOIN public.orcamentos o_o ON ((o_o.id = pi_o.orcamento_id)))
     LEFT JOIN public.contatos c_o ON ((c_o.id = COALESCE(o_o.cliente_id, pr_o.cliente_id))))
     LEFT JOIN public.projetos pr_d ON ((pr_d.id = pi_d.projeto_id)))
     LEFT JOIN public.orcamentos o_d ON ((o_d.id = pi_d.orcamento_id)))
     LEFT JOIN public.contatos c_d ON ((c_d.id = COALESCE(o_d.cliente_id, pr_d.cliente_id))))
  ORDER BY t.solicitado_em DESC;


--
-- Name: VIEW vw_transferencias_estoque; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.vw_transferencias_estoque IS 'SPEC-011. Historico/pendencias de transferencia com produto/projeto/orcamento/cliente resolvidos por JOIN. SECURITY INVOKER.';


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
-- Name: equipes_projetos Equipes_projetos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.equipes_projetos
    ADD CONSTRAINT "Equipes_projetos_pkey" PRIMARY KEY (id);


--
-- Name: auditoria_permissoes auditoria_permissoes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auditoria_permissoes
    ADD CONSTRAINT auditoria_permissoes_pkey PRIMARY KEY (id);


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
-- Name: cross_system_session_codes cross_system_session_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cross_system_session_codes
    ADD CONSTRAINT cross_system_session_codes_pkey PRIMARY KEY (code);


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
-- Name: devolucoes_estoque devolucoes_estoque_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.devolucoes_estoque
    ADD CONSTRAINT devolucoes_estoque_pkey PRIMARY KEY (id);


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
-- Name: estoque_movimentos_projeto_item estoque_movimentos_projeto_item_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estoque_movimentos_projeto_item
    ADD CONSTRAINT estoque_movimentos_projeto_item_pkey PRIMARY KEY (id);


--
-- Name: estoque_saldos_projeto_item estoque_saldos_projeto_item_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estoque_saldos_projeto_item
    ADD CONSTRAINT estoque_saldos_projeto_item_pkey PRIMARY KEY (projeto_item_id);


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
-- Name: modulo_acoes modulo_acoes_modulo_id_chave_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.modulo_acoes
    ADD CONSTRAINT modulo_acoes_modulo_id_chave_key UNIQUE (modulo_id, chave);


--
-- Name: modulo_acoes modulo_acoes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.modulo_acoes
    ADD CONSTRAINT modulo_acoes_pkey PRIMARY KEY (id);


--
-- Name: modulos modulos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.modulos
    ADD CONSTRAINT modulos_pkey PRIMARY KEY (id);


--
-- Name: modulos modulos_system_id_chave_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.modulos
    ADD CONSTRAINT modulos_system_id_chave_key UNIQUE (system_id, chave);


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
-- Name: papeis papeis_nome_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.papeis
    ADD CONSTRAINT papeis_nome_key UNIQUE (nome);


--
-- Name: papeis papeis_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.papeis
    ADD CONSTRAINT papeis_pkey PRIMARY KEY (id);


--
-- Name: papel_permissoes papel_permissoes_papel_id_system_id_modulo_id_acao_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.papel_permissoes
    ADD CONSTRAINT papel_permissoes_papel_id_system_id_modulo_id_acao_key UNIQUE (papel_id, system_id, modulo_id, acao);


--
-- Name: papel_permissoes papel_permissoes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.papel_permissoes
    ADD CONSTRAINT papel_permissoes_pkey PRIMARY KEY (id);


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
-- Name: retorno_bancario_arquivos retorno_bancario_arquivos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.retorno_bancario_arquivos
    ADD CONSTRAINT retorno_bancario_arquivos_pkey PRIMARY KEY (id);


--
-- Name: retorno_bancario_registros retorno_bancario_registros_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.retorno_bancario_registros
    ADD CONSTRAINT retorno_bancario_registros_pkey PRIMARY KEY (id);


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
-- Name: systems systems_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.systems
    ADD CONSTRAINT systems_slug_key UNIQUE (slug);


--
-- Name: transacoes transacoes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transacoes
    ADD CONSTRAINT transacoes_pkey PRIMARY KEY (id);


--
-- Name: transferencias_estoque transferencias_estoque_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transferencias_estoque
    ADD CONSTRAINT transferencias_estoque_pkey PRIMARY KEY (id);


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
-- Name: usuario_papeis usuario_papeis_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario_papeis
    ADD CONSTRAINT usuario_papeis_pkey PRIMARY KEY (usuario_id, papel_id);


--
-- Name: usuario_permissao_excecoes usuario_permissao_excecoes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario_permissao_excecoes
    ADD CONSTRAINT usuario_permissao_excecoes_pkey PRIMARY KEY (id);


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
-- Name: idx_cross_system_codes_expira; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cross_system_codes_expira ON public.cross_system_session_codes USING btree (expira_em);


--
-- Name: idx_cross_system_codes_usuario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cross_system_codes_usuario ON public.cross_system_session_codes USING btree (usuario_id, criado_em DESC);


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
-- Name: idx_dev_projeto_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dev_projeto_item ON public.devolucoes_estoque USING btree (projeto_item_id);


--
-- Name: idx_dev_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dev_status ON public.devolucoes_estoque USING btree (status);


--
-- Name: idx_empi_projeto_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_empi_projeto_item ON public.estoque_movimentos_projeto_item USING btree (projeto_item_id);


--
-- Name: idx_empi_referencia; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_empi_referencia ON public.estoque_movimentos_projeto_item USING btree (referencia_id);


--
-- Name: idx_empi_tipo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_empi_tipo ON public.estoque_movimentos_projeto_item USING btree (tipo);


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
-- Name: idx_esp_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_esp_status ON public.estoque_saldos_projeto_item USING btree (status_operacional);


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
-- Name: idx_orcamento_itens_ordem; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orcamento_itens_ordem ON public.orcamento_itens USING btree (ordem);


--
-- Name: idx_orcamento_itens_ordem_sub; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orcamento_itens_ordem_sub ON public.orcamento_itens USING btree (ordem, sub_ordem);


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
-- Name: idx_orcamentos_token_aprovacao; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orcamentos_token_aprovacao ON public.orcamentos USING btree (token_aprovacao_cliente) WHERE (token_aprovacao_cliente IS NOT NULL);


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
-- Name: idx_projetos_equipe_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projetos_equipe_id ON public.projetos USING btree (equipe_id);


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

CREATE INDEX idx_projetos_resp_obra ON public.projetos USING btree (equipe_responsavel_obra_id);


--
-- Name: idx_projetos_responsavel; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projetos_responsavel ON public.projetos USING btree (responsavel_id);


--
-- Name: idx_projetos_responsavel_obra_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projetos_responsavel_obra_id ON public.projetos USING btree (responsavel_obra_id);


--
-- Name: idx_projetos_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projetos_status ON public.projetos USING btree (status);


--
-- Name: idx_projetos_tipo_projeto; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projetos_tipo_projeto ON public.projetos USING btree (((area_do_projeto ->> 'tipo'::text)));


--
-- Name: idx_rbr_arquivo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rbr_arquivo ON public.retorno_bancario_registros USING btree (arquivo_id);


--
-- Name: idx_rbr_nosso_numero; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rbr_nosso_numero ON public.retorno_bancario_registros USING btree (nosso_numero);


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
-- Name: idx_retorno_bancario_arquivos_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_retorno_bancario_arquivos_hash ON public.retorno_bancario_arquivos USING btree (hash_conteudo);


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
-- Name: idx_sep_arquivos_separacao_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sep_arquivos_separacao_id ON public.separacao_arquivos USING btree (separacao_id);


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
-- Name: idx_te_destino; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_te_destino ON public.transferencias_estoque USING btree (destino_projeto_item_id);


--
-- Name: idx_te_origem; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_te_origem ON public.transferencias_estoque USING btree (origem_projeto_item_id);


--
-- Name: idx_te_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_te_status ON public.transferencias_estoque USING btree (status) WHERE (status = 'solicitada'::text);


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
-- Name: uq_orcamentos_token_aprovacao_cliente; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_orcamentos_token_aprovacao_cliente ON public.orcamentos USING btree (token_aprovacao_cliente) WHERE (token_aprovacao_cliente IS NOT NULL);


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
-- Name: estoque_saldos_projeto_item trg_atualizar_estoque_saldos_projeto_item; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_atualizar_estoque_saldos_projeto_item BEFORE UPDATE ON public.estoque_saldos_projeto_item FOR EACH ROW EXECUTE FUNCTION public.trg_estoque_saldos_projeto_item_atualizado_em();


--
-- Name: produtos trg_atualizar_preco_venda; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_atualizar_preco_venda BEFORE INSERT OR UPDATE OF preco_custo, porc_desconto, icms_entrada, ipi_entrada, porc_despesas ON public.produtos FOR EACH ROW EXECUTE FUNCTION public.fn_atualizar_preco_venda();


--
-- Name: papeis trg_auditoria_papeis; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_auditoria_papeis AFTER INSERT OR DELETE OR UPDATE ON public.papeis FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria_permissoes();


--
-- Name: papel_permissoes trg_auditoria_papel_permissoes; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_auditoria_papel_permissoes AFTER INSERT OR DELETE OR UPDATE ON public.papel_permissoes FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria_permissoes();


--
-- Name: usuario_papeis trg_auditoria_usuario_papeis; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_auditoria_usuario_papeis AFTER INSERT OR DELETE OR UPDATE ON public.usuario_papeis FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria_usuario_papeis();


--
-- Name: usuario_permissao_excecoes trg_auditoria_usuario_permissao_excecoes; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_auditoria_usuario_permissao_excecoes AFTER INSERT OR DELETE OR UPDATE ON public.usuario_permissao_excecoes FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria_permissoes();


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
-- Name: usuarios trg_log_can_approve_quotes; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_log_can_approve_quotes AFTER UPDATE OF can_approve_quotes ON public.usuarios FOR EACH ROW EXECUTE FUNCTION public.log_can_approve_quotes_change();


--
-- Name: orcamentos trg_normalize_orcamento_status; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_normalize_orcamento_status BEFORE INSERT OR UPDATE OF status ON public.orcamentos FOR EACH ROW EXECUTE FUNCTION public.normalize_orcamento_status();


--
-- Name: orcamento_itens trg_orcamento_item_workflow; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_orcamento_item_workflow AFTER INSERT ON public.orcamento_itens FOR EACH ROW EXECUTE FUNCTION public.handle_orcamento_item_workflow();


--
-- Name: orcamentos trg_orcamento_workflow; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_orcamento_workflow BEFORE INSERT OR UPDATE ON public.orcamentos FOR EACH ROW EXECUTE FUNCTION public.handle_orcamento_workflow();


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
-- Name: orcamentos trg_sync_contact_type_on_budget; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_sync_contact_type_on_budget AFTER INSERT OR UPDATE OF cliente_id ON public.orcamentos FOR EACH ROW EXECUTE FUNCTION public.sync_contact_type_on_budget();


--
-- Name: projetos trg_sync_equipe_por_responsavel; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_sync_equipe_por_responsavel BEFORE INSERT OR UPDATE OF responsavel_nome ON public.projetos FOR EACH ROW EXECUTE FUNCTION public.fn_sync_equipe_por_responsavel();


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
-- Name: estoque_saldos_projeto_item trg_validar_saldo_projeto_item; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_validar_saldo_projeto_item BEFORE INSERT OR UPDATE ON public.estoque_saldos_projeto_item FOR EACH ROW EXECUTE FUNCTION public.fn_validar_saldo_projeto_item();


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
-- Name: auditoria_permissoes auditoria_permissoes_autor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auditoria_permissoes
    ADD CONSTRAINT auditoria_permissoes_autor_id_fkey FOREIGN KEY (autor_id) REFERENCES public.usuarios(id);


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
-- Name: cross_system_session_codes cross_system_session_codes_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cross_system_session_codes
    ADD CONSTRAINT cross_system_session_codes_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


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
-- Name: devolucoes_estoque devolucoes_estoque_aprovado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.devolucoes_estoque
    ADD CONSTRAINT devolucoes_estoque_aprovado_por_fkey FOREIGN KEY (aprovado_por) REFERENCES auth.users(id);


--
-- Name: devolucoes_estoque devolucoes_estoque_projeto_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.devolucoes_estoque
    ADD CONSTRAINT devolucoes_estoque_projeto_item_id_fkey FOREIGN KEY (projeto_item_id) REFERENCES public.projeto_itens(id) ON DELETE RESTRICT;


--
-- Name: devolucoes_estoque devolucoes_estoque_solicitado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.devolucoes_estoque
    ADD CONSTRAINT devolucoes_estoque_solicitado_por_fkey FOREIGN KEY (solicitado_por) REFERENCES auth.users(id);


--
-- Name: entregas entregas_entregador_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entregas
    ADD CONSTRAINT entregas_entregador_id_fkey FOREIGN KEY (entregador_id) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: entregas_finalizadas entregas_finalizadas_separacao_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entregas_finalizadas
    ADD CONSTRAINT entregas_finalizadas_separacao_id_fkey FOREIGN KEY (separacao_id) REFERENCES public.separacoes(id) ON DELETE SET NULL;


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
-- Name: estoque_movimentos_projeto_item estoque_movimentos_projeto_item_criado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estoque_movimentos_projeto_item
    ADD CONSTRAINT estoque_movimentos_projeto_item_criado_por_fkey FOREIGN KEY (criado_por) REFERENCES auth.users(id);


--
-- Name: estoque_movimentos_projeto_item estoque_movimentos_projeto_item_projeto_item_destino_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estoque_movimentos_projeto_item
    ADD CONSTRAINT estoque_movimentos_projeto_item_projeto_item_destino_id_fkey FOREIGN KEY (projeto_item_destino_id) REFERENCES public.projeto_itens(id) ON DELETE SET NULL;


--
-- Name: estoque_movimentos_projeto_item estoque_movimentos_projeto_item_projeto_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estoque_movimentos_projeto_item
    ADD CONSTRAINT estoque_movimentos_projeto_item_projeto_item_id_fkey FOREIGN KEY (projeto_item_id) REFERENCES public.projeto_itens(id) ON DELETE CASCADE;


--
-- Name: estoque_saldos_projeto_item estoque_saldos_projeto_item_projeto_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estoque_saldos_projeto_item
    ADD CONSTRAINT estoque_saldos_projeto_item_projeto_item_id_fkey FOREIGN KEY (projeto_item_id) REFERENCES public.projeto_itens(id) ON DELETE CASCADE;


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
-- Name: funcionarios_financeiro funcionarios_financeiro_equipes_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.funcionarios_financeiro
    ADD CONSTRAINT funcionarios_financeiro_equipes_id_fkey FOREIGN KEY (equipes_id) REFERENCES public.equipes_projetos(id) ON DELETE SET NULL;


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
-- Name: modulo_acoes modulo_acoes_modulo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.modulo_acoes
    ADD CONSTRAINT modulo_acoes_modulo_id_fkey FOREIGN KEY (modulo_id) REFERENCES public.modulos(id) ON DELETE CASCADE;


--
-- Name: modulos modulos_system_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.modulos
    ADD CONSTRAINT modulos_system_id_fkey FOREIGN KEY (system_id) REFERENCES public.systems(id);


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
-- Name: orcamentos orcamentos_enviado_cliente_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orcamentos
    ADD CONSTRAINT orcamentos_enviado_cliente_por_fkey FOREIGN KEY (enviado_cliente_por) REFERENCES auth.users(id);


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
-- Name: papel_permissoes papel_permissoes_modulo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.papel_permissoes
    ADD CONSTRAINT papel_permissoes_modulo_id_fkey FOREIGN KEY (modulo_id) REFERENCES public.modulos(id);


--
-- Name: papel_permissoes papel_permissoes_papel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.papel_permissoes
    ADD CONSTRAINT papel_permissoes_papel_id_fkey FOREIGN KEY (papel_id) REFERENCES public.papeis(id) ON DELETE CASCADE;


--
-- Name: papel_permissoes papel_permissoes_system_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.papel_permissoes
    ADD CONSTRAINT papel_permissoes_system_id_fkey FOREIGN KEY (system_id) REFERENCES public.systems(id);


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
-- Name: projetos projetos_equipe_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projetos
    ADD CONSTRAINT projetos_equipe_id_fkey FOREIGN KEY (equipe_id) REFERENCES public.equipes_projetos(id) ON DELETE SET NULL;


--
-- Name: projetos projetos_equipe_responsavel_obra_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projetos
    ADD CONSTRAINT projetos_equipe_responsavel_obra_id_fkey FOREIGN KEY (equipe_responsavel_obra_id) REFERENCES public.equipes_projetos(id);


--
-- Name: projetos projetos_responsavel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projetos
    ADD CONSTRAINT projetos_responsavel_id_fkey FOREIGN KEY (responsavel_id) REFERENCES public.usuarios(id);


--
-- Name: projetos projetos_responsavel_obra_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projetos
    ADD CONSTRAINT projetos_responsavel_obra_id_fkey FOREIGN KEY (responsavel_obra_id) REFERENCES public.usuarios(id) ON DELETE SET NULL;


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
-- Name: retorno_bancario_arquivos retorno_bancario_arquivos_processado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.retorno_bancario_arquivos
    ADD CONSTRAINT retorno_bancario_arquivos_processado_por_fkey FOREIGN KEY (processado_por) REFERENCES public.usuarios(id);


--
-- Name: retorno_bancario_registros retorno_bancario_registros_arquivo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.retorno_bancario_registros
    ADD CONSTRAINT retorno_bancario_registros_arquivo_id_fkey FOREIGN KEY (arquivo_id) REFERENCES public.retorno_bancario_arquivos(id) ON DELETE CASCADE;


--
-- Name: retorno_bancario_registros retorno_bancario_registros_boleto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.retorno_bancario_registros
    ADD CONSTRAINT retorno_bancario_registros_boleto_id_fkey FOREIGN KEY (boleto_id) REFERENCES public.boletos(id);


--
-- Name: retorno_bancario_registros retorno_bancario_registros_parcela_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.retorno_bancario_registros
    ADD CONSTRAINT retorno_bancario_registros_parcela_id_fkey FOREIGN KEY (parcela_id) REFERENCES public.projeto_parcelas(id);


--
-- Name: retorno_bancario_registros retorno_bancario_registros_transacao_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.retorno_bancario_registros
    ADD CONSTRAINT retorno_bancario_registros_transacao_id_fkey FOREIGN KEY (transacao_id) REFERENCES public.transacoes(id);


--
-- Name: retornos_processados retornos_processados_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.retornos_processados
    ADD CONSTRAINT retornos_processados_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id);


--
-- Name: separacao_arquivos separacao_arquivos_separacao_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.separacao_arquivos
    ADD CONSTRAINT separacao_arquivos_separacao_id_fkey FOREIGN KEY (separacao_id) REFERENCES public.separacoes(id) ON DELETE CASCADE;


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
-- Name: transferencias_estoque transferencias_estoque_aprovado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transferencias_estoque
    ADD CONSTRAINT transferencias_estoque_aprovado_por_fkey FOREIGN KEY (aprovado_por) REFERENCES auth.users(id);


--
-- Name: transferencias_estoque transferencias_estoque_destino_projeto_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transferencias_estoque
    ADD CONSTRAINT transferencias_estoque_destino_projeto_item_id_fkey FOREIGN KEY (destino_projeto_item_id) REFERENCES public.projeto_itens(id) ON DELETE RESTRICT;


--
-- Name: transferencias_estoque transferencias_estoque_origem_projeto_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transferencias_estoque
    ADD CONSTRAINT transferencias_estoque_origem_projeto_item_id_fkey FOREIGN KEY (origem_projeto_item_id) REFERENCES public.projeto_itens(id) ON DELETE RESTRICT;


--
-- Name: transferencias_estoque transferencias_estoque_solicitado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transferencias_estoque
    ADD CONSTRAINT transferencias_estoque_solicitado_por_fkey FOREIGN KEY (solicitado_por) REFERENCES auth.users(id);


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
-- Name: usuario_papeis usuario_papeis_papel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario_papeis
    ADD CONSTRAINT usuario_papeis_papel_id_fkey FOREIGN KEY (papel_id) REFERENCES public.papeis(id) ON DELETE CASCADE;


--
-- Name: usuario_papeis usuario_papeis_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario_papeis
    ADD CONSTRAINT usuario_papeis_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: usuario_permissao_excecoes usuario_permissao_excecoes_criado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario_permissao_excecoes
    ADD CONSTRAINT usuario_permissao_excecoes_criado_por_fkey FOREIGN KEY (criado_por) REFERENCES public.usuarios(id);


--
-- Name: usuario_permissao_excecoes usuario_permissao_excecoes_modulo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario_permissao_excecoes
    ADD CONSTRAINT usuario_permissao_excecoes_modulo_id_fkey FOREIGN KEY (modulo_id) REFERENCES public.modulos(id);


--
-- Name: usuario_permissao_excecoes usuario_permissao_excecoes_system_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario_permissao_excecoes
    ADD CONSTRAINT usuario_permissao_excecoes_system_id_fkey FOREIGN KEY (system_id) REFERENCES public.systems(id);


--
-- Name: usuario_permissao_excecoes usuario_permissao_excecoes_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario_permissao_excecoes
    ADD CONSTRAINT usuario_permissao_excecoes_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


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
-- Name: modulo_acoes admin_all_modulo_acoes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_all_modulo_acoes ON public.modulo_acoes TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());


--
-- Name: modulos admin_all_modulos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_all_modulos ON public.modulos TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());


--
-- Name: papeis admin_all_papeis; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_all_papeis ON public.papeis TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());


--
-- Name: papel_permissoes admin_all_papel_permissoes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_all_papel_permissoes ON public.papel_permissoes TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());


--
-- Name: systems admin_all_systems; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_all_systems ON public.systems TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());


--
-- Name: user_system_access admin_all_usa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_all_usa ON public.user_system_access TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());


--
-- Name: usuario_papeis admin_all_usuario_papeis; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_all_usuario_papeis ON public.usuario_papeis TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());


--
-- Name: usuario_permissao_excecoes admin_all_usuario_permissao_excecoes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_all_usuario_permissao_excecoes ON public.usuario_permissao_excecoes TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());


--
-- Name: auditoria_permissoes admin_select_auditoria_permissoes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_select_auditoria_permissoes ON public.auditoria_permissoes FOR SELECT TO authenticated USING (public.is_admin());


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
-- Name: orcamentos anon_can_read_orcamento_by_token; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_can_read_orcamento_by_token ON public.orcamentos FOR SELECT TO authenticated, anon USING ((token_aprovacao_cliente IS NOT NULL));


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
-- Name: auditoria_permissoes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.auditoria_permissoes ENABLE ROW LEVEL SECURITY;

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
-- Name: projetos authenticated_delete_projetos_v2; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_delete_projetos_v2 ON public.projetos FOR DELETE TO authenticated USING (true);


--
-- Name: retornos_processados authenticated_delete_retornos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_delete_retornos ON public.retornos_processados FOR DELETE TO authenticated USING (true);


--
-- Name: solicitacoes_compra authenticated_delete_solicitacoes_compra; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_delete_solicitacoes_compra ON public.solicitacoes_compra FOR DELETE TO authenticated USING (true);


--
-- Name: transacoes authenticated_delete_transacoes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_delete_transacoes ON public.transacoes FOR DELETE TO authenticated USING (true);


--
-- Name: contatos authenticated_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert ON public.contatos FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: boletos authenticated_insert_boletos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert_boletos ON public.boletos FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: categorias_financeiras authenticated_insert_categorias_financeiras; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert_categorias_financeiras ON public.categorias_financeiras FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: contas_bancarias authenticated_insert_contas_bancarias; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert_contas_bancarias ON public.contas_bancarias FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: contatos authenticated_insert_contatos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert_contatos ON public.contatos FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: estoque_itens authenticated_insert_estoque_itens; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert_estoque_itens ON public.estoque_itens FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: historico_status_orcamentos authenticated_insert_historico_status_orcamentos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert_historico_status_orcamentos ON public.historico_status_orcamentos FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: logs_auditoria authenticated_insert_logs_auditoria; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert_logs_auditoria ON public.logs_auditoria FOR INSERT TO authenticated WITH CHECK (true);


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
-- Name: orcamentos authenticated_insert_orcamentos_approval; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert_orcamentos_approval ON public.orcamentos FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: produtos authenticated_insert_produtos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert_produtos ON public.produtos FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: projeto_parcelas authenticated_insert_projeto_parcelas; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert_projeto_parcelas ON public.projeto_parcelas FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: projetos authenticated_insert_projetos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert_projetos ON public.projetos FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: projetos authenticated_insert_projetos_v2; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert_projetos_v2 ON public.projetos FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: retornos_processados authenticated_insert_retornos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert_retornos ON public.retornos_processados FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: solicitacoes_compra authenticated_insert_solicitacoes_compra; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert_solicitacoes_compra ON public.solicitacoes_compra FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: transacoes authenticated_insert_transacoes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_insert_transacoes ON public.transacoes FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: contatos authenticated_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select ON public.contatos FOR SELECT TO authenticated USING (true);


--
-- Name: boletos authenticated_select_boletos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_boletos ON public.boletos FOR SELECT TO authenticated USING (true);


--
-- Name: categorias_financeiras authenticated_select_categorias_financeiras; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_categorias_financeiras ON public.categorias_financeiras FOR SELECT TO authenticated USING (true);


--
-- Name: categorias_produto authenticated_select_categorias_produto; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_categorias_produto ON public.categorias_produto FOR SELECT TO authenticated USING (true);


--
-- Name: contas_bancarias authenticated_select_contas_bancarias; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_contas_bancarias ON public.contas_bancarias FOR SELECT TO authenticated USING (true);


--
-- Name: contatos authenticated_select_contatos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_contatos ON public.contatos FOR SELECT TO authenticated USING (true);


--
-- Name: contatos authenticated_select_contatos_financial; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_contatos_financial ON public.contatos FOR SELECT TO authenticated USING (true);


--
-- Name: devolucoes_estoque authenticated_select_devolucoes_estoque; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_devolucoes_estoque ON public.devolucoes_estoque FOR SELECT TO authenticated USING (true);


--
-- Name: empresas authenticated_select_empresas; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_empresas ON public.empresas FOR SELECT TO authenticated USING (true);


--
-- Name: estoque_itens authenticated_select_estoque_itens; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_estoque_itens ON public.estoque_itens FOR SELECT TO authenticated USING (true);


--
-- Name: estoque_movimentos_projeto_item authenticated_select_estoque_movimentos_projeto_item; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_estoque_movimentos_projeto_item ON public.estoque_movimentos_projeto_item FOR SELECT TO authenticated USING (true);


--
-- Name: estoque_saldos_projeto_item authenticated_select_estoque_saldos_projeto_item; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_estoque_saldos_projeto_item ON public.estoque_saldos_projeto_item FOR SELECT TO authenticated USING (true);


--
-- Name: funcionarios authenticated_select_funcionarios; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_funcionarios ON public.funcionarios FOR SELECT TO authenticated USING (true);


--
-- Name: historico_status_orcamentos authenticated_select_historico_status_orcamentos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_historico_status_orcamentos ON public.historico_status_orcamentos FOR SELECT TO authenticated USING (true);


--
-- Name: logs_auditoria authenticated_select_logs_auditoria; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_logs_auditoria ON public.logs_auditoria FOR SELECT TO authenticated USING (true);


--
-- Name: marcas authenticated_select_marcas; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_marcas ON public.marcas FOR SELECT TO authenticated USING (true);


--
-- Name: notas_fiscais authenticated_select_nf; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_nf ON public.notas_fiscais FOR SELECT TO authenticated USING (true);


--
-- Name: orcamento_itens authenticated_select_orcamento_itens; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_orcamento_itens ON public.orcamento_itens FOR SELECT TO authenticated USING (true);


--
-- Name: orcamento_itens authenticated_select_orcamento_itens_financial; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_orcamento_itens_financial ON public.orcamento_itens FOR SELECT TO authenticated USING (true);


--
-- Name: orcamentos authenticated_select_orcamentos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_orcamentos ON public.orcamentos FOR SELECT TO authenticated USING (true);


--
-- Name: orcamentos authenticated_select_orcamentos_approval; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_orcamentos_approval ON public.orcamentos FOR SELECT TO authenticated USING (true);


--
-- Name: orcamentos authenticated_select_orcamentos_financial; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_orcamentos_financial ON public.orcamentos FOR SELECT TO authenticated USING (true);


--
-- Name: produtos authenticated_select_produtos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_produtos ON public.produtos FOR SELECT TO authenticated USING (true);


--
-- Name: projeto_parcelas authenticated_select_projeto_parcelas; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_projeto_parcelas ON public.projeto_parcelas FOR SELECT TO authenticated USING (true);


--
-- Name: projetos authenticated_select_projetos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_projetos ON public.projetos FOR SELECT TO authenticated USING (true);


--
-- Name: projetos authenticated_select_projetos_financial; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_projetos_financial ON public.projetos FOR SELECT TO authenticated USING (true);


--
-- Name: projetos authenticated_select_projetos_v2; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_projetos_v2 ON public.projetos FOR SELECT TO authenticated USING (true);


--
-- Name: retorno_bancario_arquivos authenticated_select_retorno_bancario_arquivos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_retorno_bancario_arquivos ON public.retorno_bancario_arquivos FOR SELECT TO authenticated USING (true);


--
-- Name: retorno_bancario_registros authenticated_select_retorno_bancario_registros; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_retorno_bancario_registros ON public.retorno_bancario_registros FOR SELECT TO authenticated USING (true);


--
-- Name: retornos_processados authenticated_select_retornos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_retornos ON public.retornos_processados FOR SELECT TO authenticated USING (true);


--
-- Name: revenda_ubiqua authenticated_select_revenda; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_revenda ON public.revenda_ubiqua FOR SELECT TO authenticated USING (true);


--
-- Name: solicitacoes_compra authenticated_select_solicitacoes_compra; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_solicitacoes_compra ON public.solicitacoes_compra FOR SELECT TO authenticated USING (true);


--
-- Name: systems authenticated_select_systems; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_systems ON public.systems FOR SELECT TO authenticated USING (true);


--
-- Name: transacoes authenticated_select_transacoes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_transacoes ON public.transacoes FOR SELECT TO authenticated USING (true);


--
-- Name: transferencias_estoque authenticated_select_transferencias_estoque; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_select_transferencias_estoque ON public.transferencias_estoque FOR SELECT TO authenticated USING (true);


--
-- Name: contatos authenticated_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update ON public.contatos FOR UPDATE TO authenticated USING (true);


--
-- Name: boletos authenticated_update_boletos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update_boletos ON public.boletos FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: categorias_financeiras authenticated_update_categorias_financeiras; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update_categorias_financeiras ON public.categorias_financeiras FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: contas_bancarias authenticated_update_contas_bancarias; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update_contas_bancarias ON public.contas_bancarias FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: contatos authenticated_update_contatos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update_contatos ON public.contatos FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: estoque_itens authenticated_update_estoque_itens; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update_estoque_itens ON public.estoque_itens FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: historico_status_orcamentos authenticated_update_historico_status_orcamentos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update_historico_status_orcamentos ON public.historico_status_orcamentos FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


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
-- Name: orcamentos authenticated_update_orcamentos_approval; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update_orcamentos_approval ON public.orcamentos FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: orcamentos_revenda_ubiqua authenticated_update_orcamentos_revenda_ubiqua; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update_orcamentos_revenda_ubiqua ON public.orcamentos_revenda_ubiqua FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: produtos authenticated_update_produtos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update_produtos ON public.produtos FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: projeto_parcelas authenticated_update_projeto_parcelas; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update_projeto_parcelas ON public.projeto_parcelas FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: projetos authenticated_update_projetos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update_projetos ON public.projetos FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: projetos authenticated_update_projetos_v2; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update_projetos_v2 ON public.projetos FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: retornos_processados authenticated_update_retornos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update_retornos ON public.retornos_processados FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: solicitacoes_compra authenticated_update_solicitacoes_compra; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update_solicitacoes_compra ON public.solicitacoes_compra FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: transacoes authenticated_update_transacoes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_update_transacoes ON public.transacoes FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


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
-- Name: controle_falta controle_falta_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY controle_falta_delete ON public.controle_falta FOR DELETE TO authenticated USING ((public.get_user_role() = ANY (ARRAY['admin'::text, 'gerente'::text])));


--
-- Name: controle_falta controle_falta_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY controle_falta_insert ON public.controle_falta FOR INSERT TO authenticated WITH CHECK (((public.get_user_role() = ANY (ARRAY['admin'::text, 'gerente'::text])) OR (funcionario_id = public.get_my_funcionario_id())));


--
-- Name: controle_falta controle_falta_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY controle_falta_select ON public.controle_falta FOR SELECT TO authenticated USING (((public.get_user_role() = ANY (ARRAY['admin'::text, 'gerente'::text])) OR (funcionario_id = public.get_my_funcionario_id())));


--
-- Name: controle_falta controle_falta_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY controle_falta_update ON public.controle_falta FOR UPDATE TO authenticated USING (((public.get_user_role() = ANY (ARRAY['admin'::text, 'gerente'::text])) OR (funcionario_id = public.get_my_funcionario_id())));


--
-- Name: cross_system_session_codes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cross_system_session_codes ENABLE ROW LEVEL SECURITY;

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
-- Name: departamentos departamentos_select_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY departamentos_select_all ON public.departamentos FOR SELECT TO authenticated USING (true);


--
-- Name: devolucoes_estoque; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.devolucoes_estoque ENABLE ROW LEVEL SECURITY;

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
-- Name: entregas_finalizadas ent_fin_delete_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ent_fin_delete_auth ON public.entregas_finalizadas FOR DELETE TO authenticated USING (true);


--
-- Name: entregas_finalizadas ent_fin_insert_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ent_fin_insert_auth ON public.entregas_finalizadas FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: entregas_finalizadas ent_fin_select_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ent_fin_select_auth ON public.entregas_finalizadas FOR SELECT TO authenticated USING (true);


--
-- Name: entregas_finalizadas ent_fin_update_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ent_fin_update_auth ON public.entregas_finalizadas FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


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
-- Name: entregas_finalizadas entregas_finalizadas_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY entregas_finalizadas_delete ON public.entregas_finalizadas FOR DELETE TO authenticated USING (true);


--
-- Name: entregas_finalizadas entregas_finalizadas_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY entregas_finalizadas_insert ON public.entregas_finalizadas FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: entregas_finalizadas entregas_finalizadas_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY entregas_finalizadas_select ON public.entregas_finalizadas FOR SELECT TO authenticated USING (true);


--
-- Name: entregas_finalizadas entregas_finalizadas_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY entregas_finalizadas_update ON public.entregas_finalizadas FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


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
-- Name: equipes_projetos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.equipes_projetos ENABLE ROW LEVEL SECURITY;

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
-- Name: estoque_movimentos_projeto_item; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.estoque_movimentos_projeto_item ENABLE ROW LEVEL SECURITY;

--
-- Name: estoque_saldos_projeto_item; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.estoque_saldos_projeto_item ENABLE ROW LEVEL SECURITY;

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
-- Name: ferias ferias_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ferias_delete ON public.ferias FOR DELETE TO authenticated USING ((public.get_user_role() = ANY (ARRAY['admin'::text, 'gerente'::text])));


--
-- Name: ferias ferias_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ferias_insert ON public.ferias FOR INSERT TO authenticated WITH CHECK (((public.get_user_role() = ANY (ARRAY['admin'::text, 'gerente'::text])) OR (funcionario_id = public.get_my_funcionario_id())));


--
-- Name: ferias ferias_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ferias_select ON public.ferias FOR SELECT TO authenticated USING (((public.get_user_role() = ANY (ARRAY['admin'::text, 'gerente'::text])) OR (funcionario_id = public.get_my_funcionario_id())));


--
-- Name: ferias ferias_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ferias_update ON public.ferias FOR UPDATE TO authenticated USING (((public.get_user_role() = ANY (ARRAY['admin'::text, 'gerente'::text])) OR (funcionario_id = public.get_my_funcionario_id())));


--
-- Name: funcionarios_beneficios_empresas fn_ben_delete_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fn_ben_delete_auth ON public.funcionarios_beneficios_empresas FOR DELETE TO authenticated USING (true);


--
-- Name: funcionarios_beneficios_empresas fn_ben_insert_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fn_ben_insert_auth ON public.funcionarios_beneficios_empresas FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: funcionarios_beneficios_empresas fn_ben_select_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fn_ben_select_auth ON public.funcionarios_beneficios_empresas FOR SELECT TO authenticated USING (true);


--
-- Name: funcionarios_beneficios_empresas fn_ben_update_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fn_ben_update_auth ON public.funcionarios_beneficios_empresas FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: funcionarios_detalhes fn_det_delete_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fn_det_delete_auth ON public.funcionarios_detalhes FOR DELETE TO authenticated USING (true);


--
-- Name: funcionarios_detalhes fn_det_insert_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fn_det_insert_auth ON public.funcionarios_detalhes FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: funcionarios_detalhes fn_det_select_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fn_det_select_auth ON public.funcionarios_detalhes FOR SELECT TO authenticated USING (true);


--
-- Name: funcionarios_detalhes fn_det_update_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fn_det_update_auth ON public.funcionarios_detalhes FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: funcionarios_financeiro fn_fin_delete_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fn_fin_delete_auth ON public.funcionarios_financeiro FOR DELETE TO authenticated USING (true);


--
-- Name: funcionarios_financeiro fn_fin_insert_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fn_fin_insert_auth ON public.funcionarios_financeiro FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: funcionarios_financeiro fn_fin_select_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fn_fin_select_auth ON public.funcionarios_financeiro FOR SELECT TO authenticated USING (true);


--
-- Name: funcionarios_financeiro fn_fin_update_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fn_fin_update_auth ON public.funcionarios_financeiro FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: funcionarios_novo fn_novo_delete_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fn_novo_delete_auth ON public.funcionarios_novo FOR DELETE TO authenticated USING (true);


--
-- Name: funcionarios_novo fn_novo_insert_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fn_novo_insert_auth ON public.funcionarios_novo FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: funcionarios_novo fn_novo_select_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fn_novo_select_auth ON public.funcionarios_novo FOR SELECT TO authenticated USING (true);


--
-- Name: funcionarios_novo fn_novo_update_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fn_novo_update_auth ON public.funcionarios_novo FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


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
-- Name: modulo_acoes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.modulo_acoes ENABLE ROW LEVEL SECURITY;

--
-- Name: modulos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.modulos ENABLE ROW LEVEL SECURITY;

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

CREATE POLICY orcamento_itens_update ON public.orcamento_itens FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


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
-- Name: papeis; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.papeis ENABLE ROW LEVEL SECURITY;

--
-- Name: papel_permissoes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.papel_permissoes ENABLE ROW LEVEL SECURITY;

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
-- Name: periodos_aquisitivos periodos_aquis_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY periodos_aquis_delete ON public.periodos_aquisitivos FOR DELETE TO authenticated USING ((public.get_user_role() = ANY (ARRAY['admin'::text, 'gerente'::text])));


--
-- Name: periodos_aquisitivos periodos_aquis_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY periodos_aquis_insert ON public.periodos_aquisitivos FOR INSERT TO authenticated WITH CHECK ((public.get_user_role() = ANY (ARRAY['admin'::text, 'gerente'::text])));


--
-- Name: periodos_aquisitivos periodos_aquis_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY periodos_aquis_select ON public.periodos_aquisitivos FOR SELECT TO authenticated USING (((public.get_user_role() = ANY (ARRAY['admin'::text, 'gerente'::text])) OR (funcionario_id = public.get_my_funcionario_id())));


--
-- Name: periodos_aquisitivos periodos_aquis_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY periodos_aquis_update ON public.periodos_aquisitivos FOR UPDATE TO authenticated USING ((public.get_user_role() = ANY (ARRAY['admin'::text, 'gerente'::text])));


--
-- Name: periodos_aquisitivos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.periodos_aquisitivos ENABLE ROW LEVEL SECURITY;

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
-- Name: retorno_bancario_arquivos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.retorno_bancario_arquivos ENABLE ROW LEVEL SECURITY;

--
-- Name: retorno_bancario_registros; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.retorno_bancario_registros ENABLE ROW LEVEL SECURITY;

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
-- Name: separacao_arquivos sep_arq_delete_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sep_arq_delete_auth ON public.separacao_arquivos FOR DELETE TO authenticated USING (true);


--
-- Name: separacao_arquivos sep_arq_insert_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sep_arq_insert_auth ON public.separacao_arquivos FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: separacao_arquivos sep_arq_select_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sep_arq_select_auth ON public.separacao_arquivos FOR SELECT TO authenticated USING (true);


--
-- Name: separacao_arquivos sep_arq_update_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sep_arq_update_auth ON public.separacao_arquivos FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: separacoes sep_delete_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sep_delete_auth ON public.separacoes FOR DELETE TO authenticated USING (true);


--
-- Name: separacoes sep_insert_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sep_insert_auth ON public.separacoes FOR INSERT TO authenticated WITH CHECK (true);


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
-- Name: separacoes sep_select_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sep_select_auth ON public.separacoes FOR SELECT TO authenticated USING (true);


--
-- Name: separacoes sep_update_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sep_update_auth ON public.separacoes FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: separacao_arquivos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.separacao_arquivos ENABLE ROW LEVEL SECURITY;

--
-- Name: separacao_arquivos separacao_arquivos_authenticated_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY separacao_arquivos_authenticated_all ON public.separacao_arquivos TO authenticated USING (true) WITH CHECK (true);


--
-- Name: separacao_arquivos separacao_arquivos_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY separacao_arquivos_delete ON public.separacao_arquivos FOR DELETE TO authenticated USING (true);


--
-- Name: separacao_arquivos separacao_arquivos_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY separacao_arquivos_insert ON public.separacao_arquivos FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: separacao_arquivos separacao_arquivos_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY separacao_arquivos_select ON public.separacao_arquivos FOR SELECT TO authenticated USING (true);


--
-- Name: separacao_arquivos separacao_arquivos_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY separacao_arquivos_update ON public.separacao_arquivos FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


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
-- Name: separacoes_arquivos separacoes_arquivos_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY separacoes_arquivos_delete ON public.separacoes_arquivos FOR DELETE TO authenticated USING (true);


--
-- Name: separacoes_arquivos separacoes_arquivos_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY separacoes_arquivos_insert ON public.separacoes_arquivos FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: separacoes_arquivos separacoes_arquivos_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY separacoes_arquivos_select ON public.separacoes_arquivos FOR SELECT TO authenticated USING (true);


--
-- Name: separacoes_arquivos separacoes_arquivos_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY separacoes_arquivos_update ON public.separacoes_arquivos FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: separacoes separacoes_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY separacoes_delete ON public.separacoes FOR DELETE TO authenticated USING (true);


--
-- Name: separacoes separacoes_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY separacoes_delete_admin ON public.separacoes FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::public.usuario_role, 'gerente'::public.usuario_role]))))));


--
-- Name: separacoes separacoes_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY separacoes_insert ON public.separacoes FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: separacoes separacoes_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY separacoes_select ON public.separacoes FOR SELECT TO authenticated USING (true);


--
-- Name: separacoes separacoes_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY separacoes_update ON public.separacoes FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


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
-- Name: transferencias_estoque; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.transferencias_estoque ENABLE ROW LEVEL SECURITY;

--
-- Name: orcamentos_revenda_ubiqua update_orcamentos_revenda_ubiqua; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY update_orcamentos_revenda_ubiqua ON public.orcamentos_revenda_ubiqua FOR UPDATE TO authenticated, anon USING (true) WITH CHECK (true);


--
-- Name: logs_auditoria user_insert_logs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_insert_logs ON public.logs_auditoria FOR INSERT TO authenticated WITH CHECK ((usuario_id = auth.uid()));


--
-- Name: user_roles_separacao user_role_sep_insert_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_role_sep_insert_auth ON public.user_roles_separacao FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: user_roles_separacao user_role_sep_select_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_role_sep_select_auth ON public.user_roles_separacao FOR SELECT TO authenticated USING (true);


--
-- Name: user_roles_separacao user_role_sep_update_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_role_sep_update_auth ON public.user_roles_separacao FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


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
-- Name: usuario_papeis; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.usuario_papeis ENABLE ROW LEVEL SECURITY;

--
-- Name: usuario_permissao_excecoes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.usuario_permissao_excecoes ENABLE ROW LEVEL SECURITY;

--
-- Name: usuarios; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;

--
-- Name: usuarios usuarios_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY usuarios_delete_admin ON public.usuarios FOR DELETE TO authenticated USING ((public.get_user_role() = 'admin'::text));


--
-- Name: usuarios usuarios_select_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY usuarios_select_all ON public.usuarios FOR SELECT TO authenticated USING (true);


--
-- Name: usuarios usuarios_select_own_or_funcionario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY usuarios_select_own_or_funcionario ON public.usuarios FOR SELECT TO authenticated USING (((id = auth.uid()) OR public.current_user_is_funcionario()));


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

CREATE POLICY usuarios_update_own ON public.usuarios FOR UPDATE TO authenticated USING ((id = auth.uid())) WITH CHECK ((id = auth.uid()));


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

\unrestrict e7TVCb6GY9ci1jGtCdkQIknYgVn4jxgjRbp53wNeV6ps8QEOAthc7ikZraw1yjP

