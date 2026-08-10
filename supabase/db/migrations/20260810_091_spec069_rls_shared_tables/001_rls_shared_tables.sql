-- SPEC-069: estende o hardening de RLS (já aplicado em Financeiro/RH/produtos
-- nas migrations 085/086/087) para as tabelas compartilhadas de
-- crm/orcamentos/cadastro, logística e necessidade-de-compra.
--
-- Princípio seguido em toda a migration (mesmo já usado em 085/086/087):
-- só derruba as policies "USING (true)"/"WITH CHECK (true)" que neutralizam
-- qualquer policy nova via OR (Postgres combina policies PERMISSIVE da
-- mesma ação com OR). Policies já restritivas por role legado
-- (usuarios.role IN admin/gerente/operador) são mantidas como caminho
-- adicional válido — papel_permissoes é aditivo, nunca revoga.
--
-- Leitura (SELECT) NÃO é restringida nesta migration — mantida "true" em
-- todas as tabelas, igual ao critério de aceite da SPEC-069 ("um usuário só
-- com papel equipe_entrega consegue SELECT em orcamentos mas recebe erro de
-- RLS ao tentar INSERT ou UPDATE"). Só escrita (INSERT/UPDATE/DELETE) é
-- travada.

-- ============================================================
-- projetos (crm + orcamentos escrevem)
-- ============================================================
DROP POLICY IF EXISTS authenticated_all_projetos ON public.projetos;
DROP POLICY IF EXISTS authenticated_delete_projetos ON public.projetos;
DROP POLICY IF EXISTS authenticated_delete_projetos_v2 ON public.projetos;
DROP POLICY IF EXISTS authenticated_insert_projetos ON public.projetos;
DROP POLICY IF EXISTS authenticated_insert_projetos_v2 ON public.projetos;
DROP POLICY IF EXISTS authenticated_update_projetos ON public.projetos;
DROP POLICY IF EXISTS authenticated_update_projetos_v2 ON public.projetos;
-- mantidas: projetos_delete_admin, projetos_insert, projetos_update (já
-- restritas a usuarios.role IN admin/gerente/operador — caminho adicional)

CREATE POLICY spec069_projetos_insert ON public.projetos FOR INSERT
  WITH CHECK (
    hub_pode_executar(auth.uid(), 'crm', NULL, 'criar')
    OR hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'criar')
  );

CREATE POLICY spec069_projetos_update ON public.projetos FOR UPDATE
  USING (
    hub_pode_executar(auth.uid(), 'crm', NULL, 'editar')
    OR hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'editar')
  )
  WITH CHECK (
    hub_pode_executar(auth.uid(), 'crm', NULL, 'editar')
    OR hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'editar')
  );

CREATE POLICY spec069_projetos_delete ON public.projetos FOR DELETE
  USING (
    hub_pode_executar(auth.uid(), 'crm', NULL, 'deletar')
    OR hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'deletar')
  );

-- ============================================================
-- contatos (P4, aprovado pelo usuário: separa cliente/arquiteto/engenheiro
-- de fornecedor — cliente é gerido pelo CRM, fornecedor por
-- Cadastro/Necessidade de Compra)
-- ============================================================
DROP POLICY IF EXISTS authenticated_all_contatos ON public.contatos;
DROP POLICY IF EXISTS authenticated_delete ON public.contatos;
DROP POLICY IF EXISTS authenticated_delete_contatos ON public.contatos;
DROP POLICY IF EXISTS authenticated_insert ON public.contatos;
DROP POLICY IF EXISTS authenticated_insert_contatos ON public.contatos;
DROP POLICY IF EXISTS authenticated_update ON public.contatos;
DROP POLICY IF EXISTS authenticated_update_contatos ON public.contatos;
-- mantidas: contatos_delete_admin, contatos_insert, contatos_update (role legado)

CREATE POLICY spec069_contatos_insert ON public.contatos FOR INSERT
  WITH CHECK (
    CASE
      WHEN tipo = 'fornecedor' THEN
        hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'criar')
        OR hub_pode_executar(auth.uid(), 'cadastro', NULL, 'criar')
      ELSE
        hub_pode_executar(auth.uid(), 'crm', NULL, 'criar')
    END
  );

CREATE POLICY spec069_contatos_update ON public.contatos FOR UPDATE
  USING (
    CASE
      WHEN tipo = 'fornecedor' THEN
        hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar')
        OR hub_pode_executar(auth.uid(), 'cadastro', NULL, 'editar')
      ELSE
        hub_pode_executar(auth.uid(), 'crm', NULL, 'editar')
    END
  )
  WITH CHECK (
    CASE
      WHEN tipo = 'fornecedor' THEN
        hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar')
        OR hub_pode_executar(auth.uid(), 'cadastro', NULL, 'editar')
      ELSE
        hub_pode_executar(auth.uid(), 'crm', NULL, 'editar')
    END
  );

CREATE POLICY spec069_contatos_delete ON public.contatos FOR DELETE
  USING (
    CASE
      WHEN tipo = 'fornecedor' THEN
        hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'deletar')
        OR hub_pode_executar(auth.uid(), 'cadastro', NULL, 'deletar')
      ELSE
        hub_pode_executar(auth.uid(), 'crm', NULL, 'deletar')
    END
  );

-- ============================================================
-- orcamentos / orcamento_itens (só o app Orçamentos escreve;
-- políticas anon_* do fluxo de aprovação por link/token, SPEC-009,
-- NÃO são tocadas)
-- ============================================================
DROP POLICY IF EXISTS authenticated_delete_orcamentos ON public.orcamentos;
DROP POLICY IF EXISTS authenticated_insert_orcamentos ON public.orcamentos;
DROP POLICY IF EXISTS authenticated_insert_orcamentos_approval ON public.orcamentos;
DROP POLICY IF EXISTS authenticated_update_orcamentos ON public.orcamentos;
DROP POLICY IF EXISTS authenticated_update_orcamentos_approval ON public.orcamentos;
DROP POLICY IF EXISTS orcamentos_delete ON public.orcamentos;
DROP POLICY IF EXISTS orcamentos_insert ON public.orcamentos;
DROP POLICY IF EXISTS orcamentos_update ON public.orcamentos;
-- mantidas: anon_can_read_orcamento_by_token, anon_insert_orcamentos (SPEC-009)

CREATE POLICY spec069_orcamentos_insert ON public.orcamentos FOR INSERT
  WITH CHECK (hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'criar'));

CREATE POLICY spec069_orcamentos_update ON public.orcamentos FOR UPDATE
  USING (hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'editar'))
  WITH CHECK (hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'editar'));

CREATE POLICY spec069_orcamentos_delete ON public.orcamentos FOR DELETE
  USING (hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'deletar'));

DROP POLICY IF EXISTS authenticated_delete_orcamento_itens ON public.orcamento_itens;
DROP POLICY IF EXISTS authenticated_insert_orcamento_itens ON public.orcamento_itens;
DROP POLICY IF EXISTS authenticated_update_orcamento_itens ON public.orcamento_itens;
DROP POLICY IF EXISTS orcamento_itens_delete ON public.orcamento_itens;
DROP POLICY IF EXISTS orcamento_itens_insert ON public.orcamento_itens;
DROP POLICY IF EXISTS orcamento_itens_update ON public.orcamento_itens;
-- mantida: anon_insert_orcamento_itens (SPEC-009)

CREATE POLICY spec069_orcamento_itens_insert ON public.orcamento_itens FOR INSERT
  WITH CHECK (hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'criar'));

CREATE POLICY spec069_orcamento_itens_update ON public.orcamento_itens FOR UPDATE
  USING (hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'editar'))
  WITH CHECK (hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'editar'));

CREATE POLICY spec069_orcamento_itens_delete ON public.orcamento_itens FOR DELETE
  USING (hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'deletar'));

-- ============================================================
-- separacoes (logística + o sistema novo separacao-parcial, SPEC-072,
-- também escrevem aqui diretamente ao criar uma ficha de separação)
-- ============================================================
DROP POLICY IF EXISTS sep_delete_auth ON public.separacoes;
DROP POLICY IF EXISTS sep_insert_auth ON public.separacoes;
DROP POLICY IF EXISTS sep_update_auth ON public.separacoes;
DROP POLICY IF EXISTS separacoes_delete ON public.separacoes;
DROP POLICY IF EXISTS separacoes_insert ON public.separacoes;
DROP POLICY IF EXISTS separacoes_update ON public.separacoes;
-- mantida: separacoes_delete_admin (role legado)

CREATE POLICY spec069_separacoes_insert ON public.separacoes FOR INSERT
  WITH CHECK (
    hub_pode_executar(auth.uid(), 'logistica', NULL, 'criar')
    OR hub_pode_executar(auth.uid(), 'separacao-parcial', NULL, 'criar')
  );

CREATE POLICY spec069_separacoes_update ON public.separacoes FOR UPDATE
  USING (
    hub_pode_executar(auth.uid(), 'logistica', NULL, 'editar')
    OR hub_pode_executar(auth.uid(), 'separacao-parcial', NULL, 'editar')
  )
  WITH CHECK (
    hub_pode_executar(auth.uid(), 'logistica', NULL, 'editar')
    OR hub_pode_executar(auth.uid(), 'separacao-parcial', NULL, 'editar')
  );

CREATE POLICY spec069_separacoes_delete ON public.separacoes FOR DELETE
  USING (
    hub_pode_executar(auth.uid(), 'logistica', NULL, 'deletar')
    OR hub_pode_executar(auth.uid(), 'separacao-parcial', NULL, 'deletar')
  );

-- entregas: NENHUMA alteração — já não tem nenhuma policy "true" de
-- escrita (entregas_insert/entregas_update já exigem usuarios.role IN
-- admin/gerente/operador); achado desta SPEC, não um bug.

-- ============================================================
-- necessidade-de-compra: solicitacoes_compra, pedido_compra_itens,
-- cotacoes_compra (pedidos_compra NÃO tem nenhuma policy de escrita para
-- authenticated hoje — só é gravada via as RPCs SECURITY DEFINER guardadas
-- abaixo, já está de facto travada, não precisa de policy nova)
-- ============================================================
DROP POLICY IF EXISTS authenticated_delete_solicitacoes_compra ON public.solicitacoes_compra;
DROP POLICY IF EXISTS authenticated_insert_solicitacoes_compra ON public.solicitacoes_compra;
DROP POLICY IF EXISTS authenticated_update_solicitacoes_compra ON public.solicitacoes_compra;
DROP POLICY IF EXISTS solicitacoes_delete ON public.solicitacoes_compra;
DROP POLICY IF EXISTS solicitacoes_insert ON public.solicitacoes_compra;
DROP POLICY IF EXISTS solicitacoes_update ON public.solicitacoes_compra;

CREATE POLICY spec069_solicitacoes_compra_insert ON public.solicitacoes_compra FOR INSERT
  WITH CHECK (hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'criar'));

CREATE POLICY spec069_solicitacoes_compra_update ON public.solicitacoes_compra FOR UPDATE
  USING (hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar'))
  WITH CHECK (hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar'));

CREATE POLICY spec069_solicitacoes_compra_delete ON public.solicitacoes_compra FOR DELETE
  USING (hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'deletar'));

DROP POLICY IF EXISTS pedido_itens_delete ON public.pedido_compra_itens;
DROP POLICY IF EXISTS pedido_itens_insert ON public.pedido_compra_itens;
DROP POLICY IF EXISTS pedido_itens_update ON public.pedido_compra_itens;

CREATE POLICY spec069_pedido_compra_itens_insert ON public.pedido_compra_itens FOR INSERT
  WITH CHECK (hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'criar'));

CREATE POLICY spec069_pedido_compra_itens_update ON public.pedido_compra_itens FOR UPDATE
  USING (hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar'))
  WITH CHECK (hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar'));

CREATE POLICY spec069_pedido_compra_itens_delete ON public.pedido_compra_itens FOR DELETE
  USING (hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'deletar'));

DROP POLICY IF EXISTS cotacoes_delete ON public.cotacoes_compra;
DROP POLICY IF EXISTS cotacoes_insert ON public.cotacoes_compra;
DROP POLICY IF EXISTS cotacoes_update ON public.cotacoes_compra;

CREATE POLICY spec069_cotacoes_compra_insert ON public.cotacoes_compra FOR INSERT
  WITH CHECK (hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'criar'));

CREATE POLICY spec069_cotacoes_compra_update ON public.cotacoes_compra FOR UPDATE
  USING (hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar'))
  WITH CHECK (hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar'));

CREATE POLICY spec069_cotacoes_compra_delete ON public.cotacoes_compra FOR DELETE
  USING (hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'deletar'));

-- ============================================================
-- Guards de RPC SECURITY DEFINER (ignoram RLS de tabela por completo —
-- bloqueio precisa ser dentro do corpo da função, mesmo padrão já usado em
-- criar_produto_orcamento/aprovar_orcamento_financeiro, migration 086).
--
-- registrar_devolucao_projeto_item* (SPEC-015) e registrar_separacao_setor
-- (SPEC-072) DELIBERADAMENTE NÃO recebem guard nesta migration — a primeira
-- já é chamada de dentro de aprovar_orcamento_financeiro (que já tem seu
-- próprio guard de 'aprovar'), e adicionar um guard novo ali arrisca
-- quebrar o fluxo de devolução da SPEC-071 que acabou de ser testado nesta
-- sessão. Fica para uma iteração futura, com mais cuidado.
-- ============================================================

CREATE OR REPLACE FUNCTION public.criar_pedido_compra_lote(p_fornecedor_id uuid, p_itens jsonb, p_numero text DEFAULT NULL::text, p_data_prevista_entrega date DEFAULT NULL::date, p_condicoes_pagamento text DEFAULT NULL::text, p_observacao text DEFAULT NULL::text, p_empresa_id uuid DEFAULT NULL::uuid, p_perfil text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_pedido_id       uuid;
    v_numero_final    text;
    v_valor_total     numeric(12,2) := 0;
    v_item            jsonb;
    v_produto_id      uuid;
    v_quantidade      numeric;
    v_custo_unitario  numeric;
    v_custo_liquido   numeric;
    v_valor_icms      numeric;
    v_valor_ipi       numeric;
    v_valor_st        numeric;
    v_solicitacao_id  uuid;
    v_pedido_item_id  uuid;
    v_itens_criados   jsonb := '[]'::jsonb;
    v_qtd_itens       integer := 0;
    v_empresa_id      uuid;
BEGIN
    IF NOT hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'criar') THEN
        RAISE EXCEPTION 'Sem permissao para criar pedido de compra.' USING ERRCODE = '42501';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.contatos WHERE id = p_fornecedor_id) THEN
        RAISE EXCEPTION 'Fornecedor % nao encontrado em contatos.', p_fornecedor_id USING ERRCODE = 'P0001';
    END IF;

    IF p_itens IS NULL OR jsonb_typeof(p_itens) <> 'array' OR jsonb_array_length(p_itens) = 0 THEN
        RAISE EXCEPTION 'Pedido em lote precisa de ao menos 1 item.' USING ERRCODE = 'P0001';
    END IF;

    IF p_empresa_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM public.empresas WHERE id = p_empresa_id) THEN
            RAISE EXCEPTION 'Empresa % nao encontrada.', p_empresa_id USING ERRCODE = 'P0001';
        END IF;
        v_empresa_id := p_empresa_id;
    ELSE
        SELECT empresa_id INTO v_empresa_id FROM public.usuarios WHERE id = auth.uid();
    END IF;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_itens)
    LOOP
        v_produto_id     := NULLIF(v_item->>'produto_id', '')::uuid;
        v_quantidade     := NULLIF(v_item->>'quantidade', '')::numeric;
        v_custo_unitario := NULLIF(v_item->>'custo_unitario', '')::numeric;

        IF v_produto_id IS NULL THEN
            RAISE EXCEPTION 'Item de lote sem produto_id valido.' USING ERRCODE = 'P0001';
        END IF;

        IF v_quantidade IS NULL OR v_quantidade <= 0 THEN
            RAISE EXCEPTION 'Quantidade deve ser maior que zero (produto %).', v_produto_id USING ERRCODE = 'P0001';
        END IF;

        IF v_custo_unitario IS NULL OR v_custo_unitario <= 0 THEN
            RAISE EXCEPTION 'Custo unitario deve ser maior que zero (produto %).', v_produto_id USING ERRCODE = 'P0001';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.produtos WHERE id = v_produto_id) THEN
            RAISE EXCEPTION 'Produto % nao encontrado.', v_produto_id USING ERRCODE = 'P0001';
        END IF;

        v_valor_total := v_valor_total + (v_quantidade * v_custo_unitario);
        v_qtd_itens := v_qtd_itens + 1;
    END LOOP;

    INSERT INTO public.pedidos_compra (
        numero, fornecedor_id, status, data_emissao,
        data_prevista_entrega, condicoes_pagamento,
        valor_total, observacao, aprovado_por, aprovado_em, criado_por,
        empresa_id, perfil
    ) VALUES (
        NULLIF(trim(p_numero), ''), p_fornecedor_id, 'enviado', CURRENT_DATE,
        p_data_prevista_entrega, p_condicoes_pagamento,
        v_valor_total, p_observacao,
        auth.uid(), now(), auth.uid(),
        v_empresa_id, p_perfil
    )
    RETURNING id, numero INTO v_pedido_id, v_numero_final;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_itens)
    LOOP
        v_produto_id     := (v_item->>'produto_id')::uuid;
        v_quantidade     := (v_item->>'quantidade')::numeric;
        v_custo_unitario := (v_item->>'custo_unitario')::numeric;
        v_custo_liquido  := NULLIF(v_item->>'custo_liquido', '')::numeric;
        v_valor_icms     := NULLIF(v_item->>'valor_icms', '')::numeric;
        v_valor_ipi      := NULLIF(v_item->>'valor_ipi', '')::numeric;
        v_valor_st       := NULLIF(v_item->>'valor_st', '')::numeric;

        INSERT INTO public.solicitacoes_compra (
            produto_id, quantidade, status, prioridade, observacao, solicitado_por
        ) VALUES (
            v_produto_id, v_quantidade, 'pedido_gerado', 'normal', p_observacao, auth.uid()
        )
        RETURNING id INTO v_solicitacao_id;

        INSERT INTO public.pedido_compra_itens (
            pedido_id, solicitacao_id, produto_id,
            quantidade, qtd_recebida, custo_unitario,
            custo_liquido, valor_icms, valor_ipi, valor_st
        ) VALUES (
            v_pedido_id, v_solicitacao_id, v_produto_id,
            v_quantidade, 0, v_custo_unitario,
            v_custo_liquido, v_valor_icms, v_valor_ipi, v_valor_st
        )
        RETURNING id INTO v_pedido_item_id;

        v_itens_criados := v_itens_criados || jsonb_build_object(
            'produto_id',      v_produto_id,
            'solicitacao_id',  v_solicitacao_id,
            'pedido_item_id',  v_pedido_item_id,
            'quantidade',      v_quantidade,
            'custo_unitario',  v_custo_unitario
        );
    END LOOP;

    RETURN jsonb_build_object(
        'pedido_id',   v_pedido_id,
        'numero',      v_numero_final,
        'status',      'enviado',
        'valor_total', v_valor_total,
        'qtd_itens',   v_qtd_itens,
        'itens',       v_itens_criados
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.criar_pedido_compra_de_necessidade(p_produto_id uuid, p_fornecedor_id uuid, p_quantidade numeric, p_custo_unitario numeric, p_numero text DEFAULT NULL::text, p_data_prevista_entrega date DEFAULT NULL::date, p_condicoes_pagamento text DEFAULT NULL::text, p_observacao text DEFAULT NULL::text, p_custo_liquido numeric DEFAULT NULL::numeric, p_valor_icms numeric DEFAULT NULL::numeric, p_valor_ipi numeric DEFAULT NULL::numeric, p_valor_st numeric DEFAULT NULL::numeric, p_empresa_id uuid DEFAULT NULL::uuid, p_perfil text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_solicitacao_id  uuid;
    v_pedido_id       uuid;
    v_pedido_item_id  uuid;
    v_numero_final    text;
    v_empresa_id      uuid;
BEGIN
    IF NOT hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'criar') THEN
        RAISE EXCEPTION 'Sem permissao para criar pedido de compra.' USING ERRCODE = '42501';
    END IF;

    IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
        RAISE EXCEPTION 'Quantidade deve ser maior que zero.' USING ERRCODE = 'P0001';
    END IF;

    IF p_custo_unitario IS NULL OR p_custo_unitario <= 0 THEN
        RAISE EXCEPTION 'Custo unitario deve ser maior que zero.' USING ERRCODE = 'P0001';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.produtos WHERE id = p_produto_id) THEN
        RAISE EXCEPTION 'Produto % nao encontrado.', p_produto_id USING ERRCODE = 'P0001';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.contatos WHERE id = p_fornecedor_id) THEN
        RAISE EXCEPTION 'Fornecedor % nao encontrado em contatos.', p_fornecedor_id USING ERRCODE = 'P0001';
    END IF;

    IF p_empresa_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM public.empresas WHERE id = p_empresa_id) THEN
            RAISE EXCEPTION 'Empresa % nao encontrada.', p_empresa_id USING ERRCODE = 'P0001';
        END IF;
        v_empresa_id := p_empresa_id;
    ELSE
        SELECT empresa_id INTO v_empresa_id FROM public.usuarios WHERE id = auth.uid();
    END IF;

    INSERT INTO public.solicitacoes_compra (
        produto_id, quantidade, status, prioridade, observacao, solicitado_por
    ) VALUES (
        p_produto_id, p_quantidade, 'pedido_gerado', 'normal', p_observacao, auth.uid()
    )
    RETURNING id INTO v_solicitacao_id;

    INSERT INTO public.pedidos_compra (
        numero, fornecedor_id, status, data_emissao,
        data_prevista_entrega, condicoes_pagamento,
        valor_total, observacao, aprovado_por, aprovado_em, criado_por,
        empresa_id, perfil
    ) VALUES (
        NULLIF(trim(p_numero), ''), p_fornecedor_id, 'enviado', CURRENT_DATE,
        p_data_prevista_entrega, p_condicoes_pagamento,
        p_quantidade * p_custo_unitario, p_observacao,
        auth.uid(), now(), auth.uid(),
        v_empresa_id, p_perfil
    )
    RETURNING id, numero INTO v_pedido_id, v_numero_final;

    INSERT INTO public.pedido_compra_itens (
        pedido_id, solicitacao_id, produto_id,
        quantidade, qtd_recebida, custo_unitario,
        custo_liquido, valor_icms, valor_ipi, valor_st
    ) VALUES (
        v_pedido_id, v_solicitacao_id, p_produto_id,
        p_quantidade, 0, p_custo_unitario,
        p_custo_liquido, p_valor_icms, p_valor_ipi, p_valor_st
    )
    RETURNING id INTO v_pedido_item_id;

    RETURN jsonb_build_object(
        'pedido_id',      v_pedido_id,
        'solicitacao_id', v_solicitacao_id,
        'pedido_item_id', v_pedido_item_id,
        'numero',         v_numero_final,
        'status',         'enviado'
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.cancelar_pedido_compra(p_pedido_id uuid, p_motivo text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_status text;
  v_numero text;
BEGIN
  IF NOT hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar') THEN
    RAISE EXCEPTION 'Sem permissao para cancelar pedido de compra.' USING ERRCODE = '42501';
  END IF;

  SELECT status, numero INTO v_status, v_numero
  FROM public.pedidos_compra
  WHERE id = p_pedido_id
  FOR UPDATE;

  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Pedido de compra % nao encontrado.', p_pedido_id USING ERRCODE = 'P0001';
  END IF;

  IF v_status = 'cancelado' THEN
    RAISE EXCEPTION 'Pedido % ja esta cancelado.', v_numero USING ERRCODE = 'P0001';
  END IF;

  IF v_status IN ('recebido', 'parcialmente_recebido') THEN
    RAISE EXCEPTION 'Pedido % ja tem recebimento registrado e nao pode ser cancelado (use a tela de Devolucao).', v_numero
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.pedidos_compra
  SET status = 'cancelado',
      cancelado_em = now(),
      cancelado_por = auth.uid(),
      motivo_cancelamento = p_motivo
  WHERE id = p_pedido_id;

  -- Pedido cancelado nao deve permanecer como conta a pagar em aberto.
  -- Parcelas ja pagas ficam intocadas (registro financeiro real).
  UPDATE public.pedido_compra_parcelas
  SET status = 'cancelado'
  WHERE pedido_id = p_pedido_id
    AND status <> 'pago';

  RETURN jsonb_build_object(
    'pedido_id', p_pedido_id,
    'numero',    v_numero,
    'status',    'cancelado'
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.atualizar_preco_custo_produto(p_produto_id uuid, p_preco_custo numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    IF NOT (
        hub_pode_executar(auth.uid(), 'cadastro', NULL, 'editar')
        OR hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'editar')
        OR hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar')
    ) THEN
        RAISE EXCEPTION 'Sem permissao para atualizar preco de custo.' USING ERRCODE = '42501';
    END IF;

    IF p_preco_custo IS NULL OR p_preco_custo < 0 THEN
        RAISE EXCEPTION 'Preco de custo deve ser >= 0.' USING ERRCODE = 'P0001';
    END IF;

    UPDATE public.produtos
    SET preco_custo = p_preco_custo,
        updated_at  = now()
    WHERE id = p_produto_id
      AND ativo = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Produto % nao encontrado ou inativo.', p_produto_id
            USING ERRCODE = 'P0001';
    END IF;
END;
$function$;
