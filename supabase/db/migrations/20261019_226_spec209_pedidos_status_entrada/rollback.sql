-- Desfaz a 226. Pedidos 'aguardando_aprovar' e 'aprovado' voltam para 'enviado' (o status antigo único de pedido aberto).
BEGIN;
DROP FUNCTION IF EXISTS public.aprovar_pedido_compra(uuid);
DROP FUNCTION IF EXISTS public.editar_pedido_compra(uuid, jsonb, date, text, text, numeric, uuid, text);
DROP FUNCTION IF EXISTS public.registrar_entrada_pedido_compra(uuid, jsonb);
DROP FUNCTION IF EXISTS public.prazo_medio_entrega_fornecedor(uuid);

ALTER TABLE public.pedidos_compra DROP CONSTRAINT pedidos_compra_status_check;
UPDATE public.pedidos_compra SET status = 'enviado' WHERE status IN ('aguardando_aprovar', 'aprovado');
ALTER TABLE public.pedidos_compra ADD CONSTRAINT pedidos_compra_status_check
  CHECK (status = ANY (ARRAY['rascunho'::text, 'aprovado'::text, 'enviado'::text, 'parcialmente_recebido'::text, 'recebido'::text, 'cancelado'::text]));
ALTER TABLE public.pedidos_compra ALTER COLUMN status SET DEFAULT 'rascunho';

CREATE OR REPLACE FUNCTION public.criar_pedido_compra_lote(p_fornecedor_id uuid, p_itens jsonb, p_numero text DEFAULT NULL::text, p_data_prevista_entrega date DEFAULT NULL::date, p_condicoes_pagamento text DEFAULT NULL::text, p_observacao text DEFAULT NULL::text, p_empresa_id uuid DEFAULT NULL::uuid, p_perfil text DEFAULT NULL::text, p_desconto_percentual numeric DEFAULT NULL::numeric, p_local_entrega text DEFAULT NULL::text)
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
    v_valor_outras    numeric;
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

    IF p_desconto_percentual IS NOT NULL AND (p_desconto_percentual < 0 OR p_desconto_percentual > 100) THEN
        RAISE EXCEPTION 'Desconto precisa estar entre 0 e 100 (recebido %).', p_desconto_percentual USING ERRCODE = 'P0001';
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

    -- SPEC-155: desconto negociado reduz o valor_total do pedido (não altera
    -- custo_unitario gravado por item -- o desconto é do PEDIDO, não do
    -- produto; item.custo_unitario continua sendo o preço de fato negociado
    -- por unidade, auditável separadamente).
    IF p_desconto_percentual IS NOT NULL AND p_desconto_percentual > 0 THEN
        v_valor_total := round(v_valor_total * (1 - p_desconto_percentual / 100), 2);
    END IF;

    INSERT INTO public.pedidos_compra (
        numero, fornecedor_id, status, data_emissao,
        data_prevista_entrega, condicoes_pagamento,
        valor_total, observacao, aprovado_por, aprovado_em, criado_por,
        empresa_id, perfil, desconto_percentual, local_entrega
    ) VALUES (
        NULLIF(trim(p_numero), ''), p_fornecedor_id, 'enviado', CURRENT_DATE,
        p_data_prevista_entrega, p_condicoes_pagamento,
        v_valor_total, p_observacao,
        auth.uid(), now(), auth.uid(),
        v_empresa_id, p_perfil, p_desconto_percentual, NULLIF(trim(p_local_entrega), '')
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
        v_valor_outras   := NULLIF(v_item->>'valor_outras_despesas', '')::numeric;

        INSERT INTO public.solicitacoes_compra (
            produto_id, quantidade, status, prioridade, observacao, solicitado_por
        ) VALUES (
            v_produto_id, v_quantidade, 'pedido_gerado', 'normal', p_observacao, auth.uid()
        )
        RETURNING id INTO v_solicitacao_id;

        INSERT INTO public.pedido_compra_itens (
            pedido_id, solicitacao_id, produto_id,
            quantidade, qtd_recebida, custo_unitario,
            custo_liquido, valor_icms, valor_ipi, valor_st, valor_outras_despesas
        ) VALUES (
            v_pedido_id, v_solicitacao_id, v_produto_id,
            v_quantidade, 0, v_custo_unitario,
            v_custo_liquido, v_valor_icms, v_valor_ipi, v_valor_st, v_valor_outras
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

CREATE OR REPLACE FUNCTION public.criar_pedido_compra_de_necessidade(p_produto_id uuid, p_fornecedor_id uuid, p_quantidade numeric, p_custo_unitario numeric, p_numero text DEFAULT NULL::text, p_data_prevista_entrega date DEFAULT NULL::date, p_condicoes_pagamento text DEFAULT NULL::text, p_observacao text DEFAULT NULL::text, p_custo_liquido numeric DEFAULT NULL::numeric, p_valor_icms numeric DEFAULT NULL::numeric, p_valor_ipi numeric DEFAULT NULL::numeric, p_valor_st numeric DEFAULT NULL::numeric, p_empresa_id uuid DEFAULT NULL::uuid, p_perfil text DEFAULT NULL::text, p_valor_outras_despesas numeric DEFAULT NULL::numeric)
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
        custo_liquido, valor_icms, valor_ipi, valor_st, valor_outras_despesas
    ) VALUES (
        v_pedido_id, v_solicitacao_id, p_produto_id,
        p_quantidade, 0, p_custo_unitario,
        p_custo_liquido, p_valor_icms, p_valor_ipi, p_valor_st, p_valor_outras_despesas
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

CREATE OR REPLACE FUNCTION public.gerar_parcelas_pedido_compra(p_pedido_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_pedido          public.pedidos_compra%ROWTYPE;
    v_prazos          integer[];
    v_qtd_parcelas    integer;
    v_valor_base      numeric(12,2);
    v_valor_acumulado numeric(12,2) := 0;
    v_valor_parcela   numeric(12,2);
    v_i               integer;
    v_criadas         integer := 0;
BEGIN
    SELECT * INTO v_pedido FROM public.pedidos_compra WHERE id = p_pedido_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pedido de compra % nao encontrado.', p_pedido_id USING ERRCODE = 'P0001';
    END IF;

    IF v_pedido.valor_total IS NULL OR v_pedido.valor_total <= 0 THEN
        RAISE EXCEPTION 'Pedido % nao possui valor_total valido.', v_pedido.numero USING ERRCODE = 'P0001';
    END IF;

    v_prazos := public._lucenera_parse_prazo_pagamento(
        v_pedido.condicoes_pagamento, v_pedido.prazo_pagamento_dias
    );
    v_qtd_parcelas := COALESCE(array_length(v_prazos, 1), 0);

    IF v_qtd_parcelas = 0 THEN
        RAISE EXCEPTION 'Nao foi possivel interpretar condicoes_pagamento/prazo_pagamento_dias do pedido %.', v_pedido.numero
            USING ERRCODE = 'P0001';
    END IF;

    -- Idempotente: nao duplica se ja houver parcelas geradas
    IF EXISTS (SELECT 1 FROM public.pedido_compra_parcelas WHERE pedido_id = p_pedido_id) THEN
        RAISE EXCEPTION 'Pedido % ja possui parcelas geradas.', v_pedido.numero USING ERRCODE = 'P0001';
    END IF;

    v_valor_base := round(v_pedido.valor_total / v_qtd_parcelas, 2);

    FOR v_i IN 1..v_qtd_parcelas LOOP
        v_valor_parcela := CASE
            WHEN v_i < v_qtd_parcelas THEN v_valor_base
            ELSE v_pedido.valor_total - v_valor_acumulado
        END;

        INSERT INTO public.pedido_compra_parcelas (
            pedido_id, numero_parcela, valor, data_vencimento, status
        ) VALUES (
            p_pedido_id, v_i, v_valor_parcela,
            v_pedido.data_emissao + v_prazos[v_i],
            'pendente'
        );

        v_valor_acumulado := v_valor_acumulado + v_valor_parcela;
        v_criadas := v_criadas + 1;
    END LOOP;

    RETURN jsonb_build_object('pedido_id', p_pedido_id, 'parcelas_criadas', v_criadas);
END;
$function$;

DROP FUNCTION IF EXISTS public._lucenera_datas_parcelas(text, integer[], date);

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

DROP VIEW public.vw_necessidade_compra_item_orcamento;
CREATE VIEW public.vw_necessidade_compra_item_orcamento AS
WITH cobertura_pedidos AS (
         SELECT pcio.projeto_item_id,
            sum(pcio.quantidade_atendida) AS qtd_coberta_por_pedido_aberto
           FROM ((pedido_compra_item_origem pcio
             JOIN pedido_compra_itens pci ON ((pci.id = pcio.pedido_compra_item_id)))
             JOIN pedidos_compra pc ON ((pc.id = pci.pedido_id)))
          WHERE ((pc.status <> ALL (ARRAY['recebido'::text, 'cancelado'::text])) AND (pcio.quantidade_atendida IS NOT NULL))
          GROUP BY pcio.projeto_item_id
        ), base AS (
         SELECT pi.id AS projeto_item_id,
            pi.produto_id,
            p.nome AS produto,
            p.codigo_produto AS produto_codigo,
            pi.orcamento_id,
            o.numero AS orcamento_numero,
            pi.orcamento_item_id,
            pi.l_fixo,
            p.preco_custo,
            p.percentual_desconto_compra,
            mk.id AS marca_id,
            mk.nome AS marca_nome,
            forn.id AS fornecedor_id,
            forn.nome AS fornecedor_nome,
            esp.q_entrega_futura,
            COALESCE(cob.qtd_coberta_por_pedido_aberto, (0)::numeric) AS qtd_coberta_por_pedido_aberto,
            GREATEST((0)::numeric, (esp.q_entrega_futura - COALESCE(cob.qtd_coberta_por_pedido_aberto, (0)::numeric))) AS pendente_item
           FROM ((((((projeto_itens pi
             JOIN vw_produtos_custo_restrito p ON (((p.id = pi.produto_id) AND (p.ativo = true))))
             JOIN estoque_saldos_projeto_item esp ON (((esp.projeto_item_id = pi.id) AND (esp.status_operacional = 'ativo'::text))))
             LEFT JOIN orcamentos o ON ((o.id = pi.orcamento_id)))
             LEFT JOIN marcas mk ON ((mk.id = p.marca_id)))
             LEFT JOIN contatos forn ON ((forn.id = COALESCE(p.fornecedor_principal_id, mk.fornecedor_id))))
             LEFT JOIN cobertura_pedidos cob ON ((cob.projeto_item_id = pi.id)))
          WHERE (pi.orcamento_item_id IS NOT NULL)
        )
 SELECT projeto_item_id,
    produto_id,
    produto,
    produto_codigo,
    orcamento_id,
    orcamento_numero,
    orcamento_item_id,
    l_fixo,
    preco_custo,
    percentual_desconto_compra,
    marca_id,
    marca_nome,
    fornecedor_id,
    fornecedor_nome,
    q_entrega_futura,
    qtd_coberta_por_pedido_aberto,
    pendente_item
   FROM base
  WHERE (pendente_item > (0)::numeric)
  ORDER BY orcamento_numero, l_fixo, produto;
GRANT ALL ON public.vw_necessidade_compra_item_orcamento TO authenticated, service_role;

ALTER TABLE public.pedidos_compra DROP COLUMN IF EXISTS recebido_em;
ALTER TABLE public.pedidos_compra DROP COLUMN IF EXISTS primeira_entrada_em;
COMMIT;
