-- SPEC-069: guards de permissão em RPCs SECURITY DEFINER que ignoram RLS.
--
-- criar_produto_orcamento: já tinha checagem de role legado (admin/gerente/
-- operador) — confirmado ao ler a função real antes de mexer, a "achado sem
-- checagem nenhuma" do rascunho da SPEC estava desatualizado. Adiciono uma
-- camada extra (AND, nunca amplia acesso) exigindo também 'criar' em
-- cadastro OU orcamentos via hub_pode_executar — é isso que bloqueia
-- especificamente quem tem só "Editar sem cadastrar" (equipe_projetos).
--
-- aprovar_orcamento_financeiro: confirmado que realmente NÃO tinha nenhuma
-- checagem de permissão. Guard novo: só quem tem a ação 'aprovar' em
-- orcamentos (admin_geral via TOTAL/coringa, ou administracao_comercial que
-- recebeu 'aprovar' explicitamente na SPEC-069) pode chamar.

CREATE OR REPLACE FUNCTION public.criar_produto_orcamento(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user_role text;
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

    -- SPEC-069: camada adicional sobre a matriz de papéis granular — quem
    -- tem "Editar sem cadastrar" (ex.: equipe_projetos) passa no role legado
    -- mas não tem a ação 'criar', então é bloqueado aqui.
    IF NOT (
      public.hub_pode_executar(auth.uid(), 'cadastro', NULL, 'criar')
      OR public.hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'criar')
    ) THEN
      RAISE EXCEPTION 'Permissão negada para criar produto (matriz de papéis).'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

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
$function$;

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
  v_item record;
  v_estoque_fisico numeric(10,2);
  v_estoque_reservado_atual numeric(10,2);
  v_disponivel_fisico numeric(10,3);
  v_q_reserva numeric(10,3);
  v_q_entrega_futura numeric(10,3);
  v_reservas_criadas integer := 0;
  v_saldos_criados integer := 0;
BEGIN
  IF COALESCE(auth.role(), '') <> 'service_role'
     AND NOT public.hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'aprovar') THEN
    RAISE EXCEPTION 'Permissão negada para aprovar orçamento financeiramente.'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_orcamento FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento % não encontrado.', p_orcamento_id USING ERRCODE = 'P0001';
  END IF;

  v_status_anterior := v_orcamento.status;
  v_numero_orcamento := coalesce(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.projeto_id IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui projeto vinculado.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;
  IF v_orcamento.empresa_id IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui empresa vinculada.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;
  IF v_orcamento.cliente_id IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui cliente vinculado.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;
  IF coalesce(v_orcamento.valor_total, 0) <= 0 THEN
    RAISE EXCEPTION 'Orçamento % possui valor total inválido.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;
  IF v_orcamento.forma_pagamento IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui forma de pagamento estruturada.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.orcamento_itens oi WHERE oi.orcamento_id = p_orcamento_id) THEN
    RAISE EXCEPTION 'Orçamento % não possui itens.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.orcamento_itens oi
    WHERE oi.orcamento_id = p_orcamento_id AND (coalesce(oi.quantidade, 0) <= 0 OR coalesce(oi.preco_unitario, 0) <= 0)
  ) THEN
    RAISE EXCEPTION 'Orçamento % possui item sem quantidade ou preço válido.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;

  v_prazos := public._lucenera_parse_prazo_pagamento(v_orcamento.condicoes_pagamento, v_orcamento.prazo_pagamento_dias);
  v_qtd_parcelas := coalesce(array_length(v_prazos, 1), 0);
  IF v_qtd_parcelas = 0 THEN
    RAISE EXCEPTION 'Orçamento % não possui prazo de pagamento interpretável.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;

  SELECT nome INTO v_cliente_nome FROM public.contatos WHERE id = v_orcamento.cliente_id;

  SELECT count(*) INTO v_itens_existentes FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id;
  SELECT count(*) INTO v_parcelas_existentes FROM public.projeto_parcelas WHERE orcamento_id = p_orcamento_id;
  SELECT count(*) INTO v_boletos_existentes FROM public.boletos WHERE orcamento_id = p_orcamento_id;

  IF v_itens_existentes > 0 AND v_parcelas_existentes = v_qtd_parcelas AND v_boletos_existentes = v_qtd_parcelas THEN
    UPDATE public.orcamentos SET status = 'Orçamento Aprovado' WHERE id = p_orcamento_id;
    RETURN jsonb_build_object(
      'orcamento_id', p_orcamento_id, 'status', 'Orçamento Aprovado', 'projeto_id', v_orcamento.projeto_id,
      'projeto_itens_criados', 0, 'parcelas_criadas', 0, 'boletos_criados', 0,
      'reservas_estoque_aplicadas', 0, 'saldos_operacionais_criados', 0,
      'nota_fiscal_status', 'pendente_api', 'ja_processado', true
    );
  END IF;

  IF v_itens_existentes > 0 OR v_parcelas_existentes > 0 OR v_boletos_existentes > 0 THEN
    RAISE EXCEPTION 'Orçamento % possui processamento parcial inconsistente: itens %, parcelas %, boletos %.',
      v_numero_orcamento, v_itens_existentes, v_parcelas_existentes, v_boletos_existentes USING ERRCODE = 'P0001';
  END IF;

  IF v_orcamento.status != 'Aprovação Financeira' THEN
    RAISE EXCEPTION 'Orçamento % não está aguardando aprovação financeira. Status atual: %', v_numero_orcamento, v_status_anterior
      USING ERRCODE = 'P0003';
  END IF;

  UPDATE public.orcamentos SET status = 'Orçamento Aprovado', requer_revisao_financeira = false WHERE id = p_orcamento_id;

  BEGIN
    INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
    VALUES (p_orcamento_id, v_status_anterior, 'Orçamento Aprovado', auth.uid()::text, 'Aprovação financeira — processamento de itens, parcelas e boletos');
  EXCEPTION
    WHEN undefined_table OR undefined_column OR foreign_key_violation THEN
      NULL;
  END;

  FOR v_item IN
    INSERT INTO public.projeto_itens (
      projeto_id, produto_id, descricao, quantidade, preco_unitario, desconto, validado, orcamento_id,
      orcamento_item_id, l_fixo
    )
    SELECT v_orcamento.projeto_id, oi.produto_id, coalesce(oi.descricao, oi.custom_id, p.nome, 'Item do Orçamento'),
      coalesce(oi.quantidade, 0), coalesce(oi.preco_unitario, 0), coalesce(oi.desconto, 0),
      true, p_orcamento_id,
      oi.id, oi.custom_id
    FROM public.orcamento_itens oi LEFT JOIN public.produtos p ON p.id = oi.produto_id
    WHERE oi.orcamento_id = p_orcamento_id
    RETURNING id, produto_id, quantidade
  LOOP
    v_itens_criados := v_itens_criados + 1;

    CONTINUE WHEN v_item.produto_id IS NULL OR coalesce(v_item.quantidade, 0) <= 0;

    INSERT INTO public.estoque_itens (produto_id, local, quantidade, quantidade_reservada, atualizado_em)
    VALUES (v_item.produto_id, 'Estoque'::public.estoque_local, 0, 0, NOW())
    ON CONFLICT (produto_id, local) DO NOTHING;

    SELECT quantidade, quantidade_reservada
      INTO v_estoque_fisico, v_estoque_reservado_atual
    FROM public.estoque_itens
    WHERE produto_id = v_item.produto_id AND local = 'Estoque'::public.estoque_local
    FOR UPDATE;

    v_disponivel_fisico := GREATEST(0, coalesce(v_estoque_fisico, 0) - coalesce(v_estoque_reservado_atual, 0));
    v_q_reserva := LEAST(v_item.quantidade, v_disponivel_fisico);
    v_q_entrega_futura := GREATEST(0, v_item.quantidade - v_q_reserva);

    UPDATE public.estoque_itens
    SET quantidade_reservada = quantidade_reservada + v_item.quantidade, atualizado_em = NOW()
    WHERE produto_id = v_item.produto_id AND local = 'Estoque'::public.estoque_local;

    v_reservas_criadas := v_reservas_criadas + 1;

    INSERT INTO public.estoque_saldos_projeto_item (projeto_item_id, q_reserva, q_entrega_futura)
    VALUES (v_item.id, v_q_reserva, v_q_entrega_futura)
    ON CONFLICT (projeto_item_id) DO NOTHING;

    v_saldos_criados := v_saldos_criados + 1;

    INSERT INTO public.estoque_movimentos_projeto_item (
      projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por
    )
    VALUES (
      v_item.id, 'aprovacao_orcamento', v_item.quantidade, 'aprovar_orcamento_financeiro', p_orcamento_id,
      format('Reserva %s / entrega futura %s na aprovação do orçamento %s', v_q_reserva, v_q_entrega_futura, v_numero_orcamento),
      auth.uid()
    );
  END LOOP;

  v_valor_total := coalesce(v_orcamento.valor_total, 0);
  v_valor_base := round(v_valor_total / v_qtd_parcelas, 2);

  FOR v_i IN 1..v_qtd_parcelas LOOP
    IF v_i = v_qtd_parcelas THEN
      v_valor_parcela := v_valor_total - v_valor_acumulado;
    ELSE
      v_valor_parcela := v_valor_base;
      v_valor_acumulado := v_valor_acumulado + v_valor_parcela;
    END IF;
    INSERT INTO public.projeto_parcelas (projeto_id, numero_parcela, valor, data_fechamento, data_vencimento, status, forma_pagamento, orcamento_id, descricao)
    VALUES (v_orcamento.projeto_id, v_i, v_valor_parcela, current_date, v_data_base + v_prazos[v_i], 'pendente', v_orcamento.forma_pagamento, p_orcamento_id, 'Parcela gerada pelo orçamento ' || v_numero_orcamento);
    v_parcelas_criadas := v_parcelas_criadas + 1;
  END LOOP;

  INSERT INTO public.boletos (nosso_numero, numero_documento, parcela_id, orcamento_id, empresa_id, valor, vencimento, nome_pagador, status, tipo, venda, num_parcela, total_parcelas, emissao)
  SELECT 'ORC-' || regexp_replace(v_numero_orcamento, '[^a-zA-Z0-9]', '', 'g') || '-P' || pp.numero_parcela,
    v_numero_orcamento || '-P' || pp.numero_parcela, pp.id, p_orcamento_id, v_orcamento.empresa_id,
    pp.valor, pp.data_vencimento, coalesce(v_cliente_nome, 'Cliente do orçamento'), 'pendente_registro', 'Nota Fiscal', NULL,
    pp.numero_parcela, v_qtd_parcelas, current_date
  FROM public.projeto_parcelas pp WHERE pp.orcamento_id = p_orcamento_id
  ON CONFLICT (nosso_numero) DO NOTHING;
  GET DIAGNOSTICS v_boletos_criados = ROW_COUNT;

  RETURN jsonb_build_object(
    'orcamento_id', p_orcamento_id, 'status', 'Orçamento Aprovado', 'projeto_id', v_orcamento.projeto_id,
    'projeto_itens_criados', v_itens_criados, 'parcelas_criadas', v_parcelas_criadas, 'boletos_criados', v_boletos_criados,
    'reservas_estoque_aplicadas', v_reservas_criadas, 'saldos_operacionais_criados', v_saldos_criados,
    'nota_fiscal_status', 'pendente_api', 'ja_processado', false
  );
END;
$function$;
