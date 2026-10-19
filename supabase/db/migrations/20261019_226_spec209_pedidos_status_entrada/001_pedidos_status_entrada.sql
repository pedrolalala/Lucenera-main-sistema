-- SPEC-209 D/E/C (reunião 19/10 com Vinicius e Débora).
-- D2 status do pedido: aguardando_aprovar (enviado ao fornecedor, esperando retorno) -> aprovado -> parcialmente_recebido
--    (tela: "Concluído parcialmente") / recebido ("Concluído"); ou cancelado. 'enviado' e 'rascunho' deixam de existir:
--    os 52 pedidos 'enviado' viram 'aprovado' (decisão do usuário 19/10).
-- D3 editar só em aguardando_aprovar; D4 aprovar; D5 cancelar exige justificativa (a necessidade volta sozinha: as
--    views de necessidade ignoram pedido cancelado).
-- E  registrar_entrada_pedido_compra: quantidade recebida por item -> status automático. Não mexe em estoque.
-- C1 parcelas por dias ou por datas; C4 prazo médio do fornecedor (primeira_entrada_em - data_emissao).
-- A3 vw_necessidade_compra_item_orcamento ganha empresa_id/empresa_nome (empresa da venda) no fim.
BEGIN;

ALTER TABLE public.pedidos_compra ADD COLUMN IF NOT EXISTS recebido_em timestamptz;
ALTER TABLE public.pedidos_compra ADD COLUMN IF NOT EXISTS primeira_entrada_em timestamptz;
COMMENT ON COLUMN public.pedidos_compra.recebido_em IS 'SPEC-209: quando a entrada completou o pedido (status recebido).';
COMMENT ON COLUMN public.pedidos_compra.primeira_entrada_em IS 'SPEC-209: primeira entrada de mercadoria do pedido (base do prazo médio do fornecedor).';

ALTER TABLE public.pedidos_compra DROP CONSTRAINT pedidos_compra_status_check;
UPDATE public.pedidos_compra SET status = 'aprovado' WHERE status IN ('enviado', 'rascunho');
ALTER TABLE public.pedidos_compra ADD CONSTRAINT pedidos_compra_status_check
  CHECK (status = ANY (ARRAY['aguardando_aprovar'::text, 'aprovado'::text, 'parcialmente_recebido'::text, 'recebido'::text, 'cancelado'::text]));
ALTER TABLE public.pedidos_compra ALTER COLUMN status SET DEFAULT 'aguardando_aprovar';

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
        NULLIF(trim(p_numero), ''), p_fornecedor_id, 'aguardando_aprovar', CURRENT_DATE,
        p_data_prevista_entrega, p_condicoes_pagamento,
        v_valor_total, p_observacao,
        NULL, NULL, auth.uid(),
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
        'status',      'aguardando_aprovar',
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
        NULLIF(trim(p_numero), ''), p_fornecedor_id, 'aguardando_aprovar', CURRENT_DATE,
        p_data_prevista_entrega, p_condicoes_pagamento,
        p_quantidade * p_custo_unitario, p_observacao,
        NULL, NULL, auth.uid(),
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
        'status',         'aguardando_aprovar'
    );
END;
$function$;

-- ---------------------------------------------------------------------------
-- D4: aprovar (fornecedor confirmou): Aguardando aprovar -> Aprovado
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.aprovar_pedido_compra(p_pedido_id uuid)
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
    RAISE EXCEPTION 'Sem permissao para aprovar pedido de compra.' USING ERRCODE = '42501';
  END IF;

  SELECT status, numero INTO v_status, v_numero FROM public.pedidos_compra WHERE id = p_pedido_id FOR UPDATE;
  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Pedido de compra % nao encontrado.', p_pedido_id USING ERRCODE = 'P0001';
  END IF;
  IF v_status <> 'aguardando_aprovar' THEN
    RAISE EXCEPTION 'So pedido em "Aguardando aprovar" pode ser aprovado (pedido % esta em %).', v_numero, v_status
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.pedidos_compra
     SET status = 'aprovado', aprovado_por = auth.uid(), aprovado_em = now(), atualizado_em = now()
   WHERE id = p_pedido_id;

  RETURN jsonb_build_object('pedido_id', p_pedido_id, 'numero', v_numero, 'status', 'aprovado');
END;
$function$;

-- ---------------------------------------------------------------------------
-- D3: editar pedido em "Aguardando aprovar" (o fornecedor mudou quantidade, preço, desconto...)
--   p_itens: [{pedido_item_id, quantidade, custo_unitario, custo_liquido, valor_ipi, valor_st,
--              valor_outras_despesas, remover}] -- item não listado fica como está.
--   Parcelas ainda não pagas são refeitas se a condição de pagamento existir.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.editar_pedido_compra(
  p_pedido_id uuid,
  p_itens jsonb DEFAULT '[]'::jsonb,
  p_data_prevista_entrega date DEFAULT NULL,
  p_condicoes_pagamento text DEFAULT NULL,
  p_observacao text DEFAULT NULL,
  p_desconto_percentual numeric DEFAULT NULL,
  p_empresa_id uuid DEFAULT NULL,
  p_local_entrega text DEFAULT NULL
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_pedido      public.pedidos_compra%ROWTYPE;
  v_item        jsonb;
  v_item_id     uuid;
  v_qtd         numeric;
  v_custo       numeric;
  v_solic       uuid;
  v_sobra       numeric;
  v_orig        record;
  v_total       numeric(12,2);
  v_restantes   integer;
  v_parcelas    integer := 0;
BEGIN
  IF NOT hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar') THEN
    RAISE EXCEPTION 'Sem permissao para editar pedido de compra.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_pedido FROM public.pedidos_compra WHERE id = p_pedido_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pedido de compra % nao encontrado.', p_pedido_id USING ERRCODE = 'P0001';
  END IF;
  IF v_pedido.status <> 'aguardando_aprovar' THEN
    RAISE EXCEPTION 'So pedido em "Aguardando aprovar" pode ser editado (pedido % esta em %).', v_pedido.numero, v_pedido.status
      USING ERRCODE = 'P0001';
  END IF;
  IF p_desconto_percentual IS NOT NULL AND (p_desconto_percentual < 0 OR p_desconto_percentual > 100) THEN
    RAISE EXCEPTION 'Desconto precisa estar entre 0 e 100.' USING ERRCODE = 'P0001';
  END IF;
  IF p_empresa_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.empresas WHERE id = p_empresa_id) THEN
    RAISE EXCEPTION 'Empresa % nao encontrada.', p_empresa_id USING ERRCODE = 'P0001';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(coalesce(p_itens, '[]'::jsonb))
  LOOP
    v_item_id := (v_item->>'pedido_item_id')::uuid;
    IF NOT EXISTS (SELECT 1 FROM public.pedido_compra_itens WHERE id = v_item_id AND pedido_id = p_pedido_id) THEN
      RAISE EXCEPTION 'Item % nao pertence ao pedido %.', v_item_id, v_pedido.numero USING ERRCODE = 'P0001';
    END IF;

    IF coalesce((v_item->>'remover')::boolean, false) THEN
      SELECT solicitacao_id INTO v_solic FROM public.pedido_compra_itens WHERE id = v_item_id;
      DELETE FROM public.pedido_compra_itens WHERE id = v_item_id;  -- origens saem em cascata
      IF v_solic IS NOT NULL THEN
        DELETE FROM public.solicitacoes_compra s
         WHERE s.id = v_solic AND NOT EXISTS (SELECT 1 FROM public.pedido_compra_itens x WHERE x.solicitacao_id = v_solic);
      END IF;
      CONTINUE;
    END IF;

    v_qtd   := NULLIF(v_item->>'quantidade', '')::numeric;
    v_custo := NULLIF(v_item->>'custo_unitario', '')::numeric;
    IF v_qtd IS NOT NULL AND v_qtd <= 0 THEN
      RAISE EXCEPTION 'Quantidade deve ser maior que zero.' USING ERRCODE = 'P0001';
    END IF;
    IF v_custo IS NOT NULL AND v_custo <= 0 THEN
      RAISE EXCEPTION 'Custo unitario deve ser maior que zero.' USING ERRCODE = 'P0001';
    END IF;

    UPDATE public.pedido_compra_itens SET
      quantidade            = coalesce(v_qtd, quantidade),
      custo_unitario        = coalesce(v_custo, custo_unitario),
      custo_liquido         = CASE WHEN v_item ? 'custo_liquido' THEN NULLIF(v_item->>'custo_liquido', '')::numeric ELSE custo_liquido END,
      valor_ipi             = CASE WHEN v_item ? 'valor_ipi' THEN NULLIF(v_item->>'valor_ipi', '')::numeric ELSE valor_ipi END,
      valor_st              = CASE WHEN v_item ? 'valor_st' THEN NULLIF(v_item->>'valor_st', '')::numeric ELSE valor_st END,
      valor_outras_despesas = CASE WHEN v_item ? 'valor_outras_despesas' THEN NULLIF(v_item->>'valor_outras_despesas', '')::numeric ELSE valor_outras_despesas END
    WHERE id = v_item_id;

    -- quantidade menor que a já ligada aos L de origem: devolve a diferença para a necessidade
    IF v_qtd IS NOT NULL THEN
      SELECT coalesce(sum(quantidade_atendida), 0) - v_qtd INTO v_sobra
        FROM public.pedido_compra_item_origem WHERE pedido_compra_item_id = v_item_id;
      IF v_sobra > 0 THEN
        FOR v_orig IN
          SELECT id, quantidade_atendida FROM public.pedido_compra_item_origem
           WHERE pedido_compra_item_id = v_item_id AND quantidade_atendida > 0
           ORDER BY criado_em DESC
        LOOP
          EXIT WHEN v_sobra <= 0;
          UPDATE public.pedido_compra_item_origem
             SET quantidade_atendida = greatest(0, v_orig.quantidade_atendida - v_sobra)
           WHERE id = v_orig.id;
          v_sobra := v_sobra - v_orig.quantidade_atendida;
        END LOOP;
      END IF;
    END IF;
  END LOOP;

  SELECT count(*) INTO v_restantes FROM public.pedido_compra_itens WHERE pedido_id = p_pedido_id;
  IF v_restantes = 0 THEN
    RAISE EXCEPTION 'O pedido precisa ficar com ao menos 1 item (para desistir dele, cancele).' USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.pedidos_compra SET
    data_prevista_entrega = p_data_prevista_entrega,
    condicoes_pagamento   = NULLIF(trim(p_condicoes_pagamento), ''),
    observacao            = NULLIF(trim(p_observacao), ''),
    desconto_percentual   = NULLIF(p_desconto_percentual, 0),
    empresa_id            = coalesce(p_empresa_id, empresa_id),
    local_entrega         = NULLIF(trim(p_local_entrega), ''),
    atualizado_em         = now()
  WHERE id = p_pedido_id;

  SELECT round(sum(quantidade * custo_unitario) * (1 - coalesce(NULLIF(p_desconto_percentual, 0), 0) / 100), 2)
    INTO v_total FROM public.pedido_compra_itens WHERE pedido_id = p_pedido_id;
  UPDATE public.pedidos_compra SET valor_total = v_total WHERE id = p_pedido_id;

  -- parcelas: refaz as não pagas com o valor e a condição novos
  IF NOT EXISTS (SELECT 1 FROM public.pedido_compra_parcelas WHERE pedido_id = p_pedido_id AND status = 'pago') THEN
    DELETE FROM public.pedido_compra_parcelas WHERE pedido_id = p_pedido_id;
    IF NULLIF(trim(p_condicoes_pagamento), '') IS NOT NULL THEN
      BEGIN
        v_parcelas := (public.gerar_parcelas_pedido_compra(p_pedido_id)->>'parcelas_criadas')::integer;
      EXCEPTION WHEN OTHERS THEN
        v_parcelas := 0;  -- condição não reconhecida: pedido salvo, parcelas ficam para fazer à mão
      END;
    END IF;
  END IF;

  RETURN jsonb_build_object('pedido_id', p_pedido_id, 'numero', v_pedido.numero, 'valor_total', v_total,
                            'parcelas_criadas', v_parcelas);
END;
$function$;

-- ---------------------------------------------------------------------------
-- E: entrada de mercadoria amarrada ao pedido. Só registra o que chegou por item e muda o status
--    sozinho (Concluído / Concluído parcialmente). NÃO mexe em estoque: o estoque vem da Connect
--    (produtos -> fn_sync_estoque_itens_from_produtos); somar aqui contaria duas vezes.
--    p_itens: [{pedido_item_id, quantidade}]
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.registrar_entrada_pedido_compra(p_pedido_id uuid, p_itens jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_status   text;
  v_numero   text;
  v_item     jsonb;
  v_item_id  uuid;
  v_qtd      numeric;
  v_falta    numeric;
  v_novo     text;
  v_total_recebido numeric := 0;
BEGIN
  IF NOT hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar') THEN
    RAISE EXCEPTION 'Sem permissao para dar entrada em pedido de compra.' USING ERRCODE = '42501';
  END IF;

  SELECT status, numero INTO v_status, v_numero FROM public.pedidos_compra WHERE id = p_pedido_id FOR UPDATE;
  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Pedido de compra % nao encontrado.', p_pedido_id USING ERRCODE = 'P0001';
  END IF;
  IF v_status IN ('cancelado', 'recebido') THEN
    RAISE EXCEPTION 'Pedido % esta % e nao recebe mais entrada.', v_numero,
      CASE v_status WHEN 'cancelado' THEN 'cancelado' ELSE 'concluido' END USING ERRCODE = 'P0001';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(coalesce(p_itens, '[]'::jsonb))
  LOOP
    v_item_id := (v_item->>'pedido_item_id')::uuid;
    v_qtd     := coalesce(NULLIF(v_item->>'quantidade', '')::numeric, 0);
    CONTINUE WHEN v_qtd = 0;
    IF v_qtd < 0 THEN
      RAISE EXCEPTION 'Quantidade recebida nao pode ser negativa.' USING ERRCODE = 'P0001';
    END IF;
    SELECT quantidade - qtd_recebida INTO v_falta
      FROM public.pedido_compra_itens WHERE id = v_item_id AND pedido_id = p_pedido_id FOR UPDATE;
    IF v_falta IS NULL THEN
      RAISE EXCEPTION 'Item % nao pertence ao pedido %.', v_item_id, v_numero USING ERRCODE = 'P0001';
    END IF;
    IF v_qtd > v_falta THEN
      RAISE EXCEPTION 'Quantidade recebida (%) maior que a que falta chegar (%) num item do pedido %.', v_qtd, v_falta, v_numero
        USING ERRCODE = 'P0001';
    END IF;
    UPDATE public.pedido_compra_itens SET qtd_recebida = qtd_recebida + v_qtd WHERE id = v_item_id;
    v_total_recebido := v_total_recebido + v_qtd;
  END LOOP;

  IF v_total_recebido = 0 THEN
    RAISE EXCEPTION 'Informe a quantidade recebida de ao menos 1 item.' USING ERRCODE = 'P0001';
  END IF;

  SELECT CASE WHEN bool_and(qtd_recebida >= quantidade) THEN 'recebido' ELSE 'parcialmente_recebido' END
    INTO v_novo FROM public.pedido_compra_itens WHERE pedido_id = p_pedido_id;

  UPDATE public.pedidos_compra
     SET status = v_novo,
         recebido_em = CASE WHEN v_novo = 'recebido' THEN now() ELSE recebido_em END,
         primeira_entrada_em = coalesce(primeira_entrada_em, now()),
         atualizado_em = now()
   WHERE id = p_pedido_id;

  RETURN jsonb_build_object('pedido_id', p_pedido_id, 'numero', v_numero, 'status', v_novo);
END;
$function$;

-- ---------------------------------------------------------------------------
-- C4: prazo médio de entrega do fornecedor (pedido feito -> primeira entrada), só com histórico real
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.prazo_medio_entrega_fornecedor(p_fornecedor_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT jsonb_build_object(
    'dias', round(avg(primeira_entrada_em::date - data_emissao))::int,
    'pedidos', count(*)
  )
  FROM public.pedidos_compra
  WHERE fornecedor_id = p_fornecedor_id
    AND primeira_entrada_em IS NOT NULL
    AND data_emissao IS NOT NULL;
$function$;

-- ---------------------------------------------------------------------------
-- C1: datas das parcelas. Aceita prazos em dias ("30/60/90", "3x30") contados da data do pedido,
--     ou datas digitadas ("15/11, 15/12" ou "15/11/2026"). Data sem ano que já passou vai para o ano seguinte.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._lucenera_datas_parcelas(p_condicoes text, p_prazo_dias integer[], p_base date)
 RETURNS date[]
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
DECLARE
  v_txt    text := trim(coalesce(p_condicoes, ''));
  v_grupos text[];
  v_g      text;
  v_n      text[];
  v_eh_data boolean := false;
  v_datas  date[] := ARRAY[]::date[];
  v_d      date;
  v_ano    int;
  v_dias   integer[];
BEGIN
  -- Grupos separados por vírgula, ponto e vírgula, espaço ou " e ".
  -- É data quando todo grupo é "dd/mm" ou "dd/mm/aaaa" e (tem ano, ou há mais de um grupo, ou o mês
  -- é menor que o dia: "15/11"). "30/60/90" e "30/60" continuam sendo dias.
  v_grupos := regexp_split_to_array(regexp_replace(lower(v_txt), '\s+e\s+', ',', 'g'), '[,;\s]+');
  v_grupos := array_remove(v_grupos, '');
  IF coalesce(array_length(v_grupos, 1), 0) > 0 THEN
    v_eh_data := true;
    FOREACH v_g IN ARRAY v_grupos LOOP
      IF v_g !~ '^\d{1,2}/\d{1,2}(/\d{2,4})?$' THEN v_eh_data := false; EXIT; END IF;
      v_n := regexp_split_to_array(v_g, '/');
      IF v_n[2]::int < 1 OR v_n[2]::int > 12 OR v_n[1]::int < 1 OR v_n[1]::int > 31 THEN v_eh_data := false; EXIT; END IF;
    END LOOP;
    IF v_eh_data AND array_length(v_grupos, 1) = 1 AND v_grupos[1] !~ '/\d{2,4}$' THEN
      v_n := regexp_split_to_array(v_grupos[1], '/');
      v_eh_data := v_n[2]::int < v_n[1]::int;
    END IF;
  END IF;

  IF v_eh_data THEN
    FOREACH v_g IN ARRAY v_grupos LOOP
      v_n := regexp_split_to_array(v_g, '/');
      v_ano := CASE WHEN v_n[3] IS NULL THEN extract(year FROM p_base)::int
                    WHEN length(v_n[3]) = 2 THEN 2000 + v_n[3]::int
                    ELSE v_n[3]::int END;
      v_d := make_date(v_ano, v_n[2]::int, v_n[1]::int);
      IF v_n[3] IS NULL AND v_d < p_base THEN
        v_d := (v_d + interval '1 year')::date;
      END IF;
      v_datas := v_datas || v_d;
    END LOOP;
    RETURN v_datas;
  END IF;

  v_dias := public._lucenera_parse_prazo_pagamento(p_condicoes, p_prazo_dias);
  SELECT coalesce(array_agg(p_base + d ORDER BY ord), ARRAY[]::date[]) INTO v_datas
    FROM unnest(v_dias) WITH ORDINALITY AS t(d, ord);
  RETURN v_datas;
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
    v_datas           date[];
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

    -- SPEC-209 C1: dias ("30/60/90") contados da data do pedido, ou datas digitadas ("15/11, 15/12")
    v_datas := public._lucenera_datas_parcelas(
        v_pedido.condicoes_pagamento, v_pedido.prazo_pagamento_dias, COALESCE(v_pedido.data_emissao, CURRENT_DATE)
    );
    v_qtd_parcelas := COALESCE(array_length(v_datas, 1), 0);

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
            v_datas[v_i],
            'pendente'
        );

        v_valor_acumulado := v_valor_acumulado + v_valor_parcela;
        v_criadas := v_criadas + 1;
    END LOOP;

    RETURN jsonb_build_object('pedido_id', p_pedido_id, 'parcelas_criadas', v_criadas);
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

  -- SPEC-209 D5: cancelar exige justificativa
  IF NULLIF(trim(coalesce(p_motivo, '')), '') IS NULL THEN
    RAISE EXCEPTION 'Informe a justificativa do cancelamento.' USING ERRCODE = 'P0001';
  END IF;

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
      motivo_cancelamento = trim(p_motivo),
      atualizado_em = now()
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

CREATE OR REPLACE VIEW public.vw_necessidade_compra_item_orcamento AS
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
            GREATEST((0)::numeric, (esp.q_entrega_futura - COALESCE(cob.qtd_coberta_por_pedido_aberto, (0)::numeric))) AS pendente_item,
            o.empresa_id,
            emp.nome AS empresa_nome
           FROM (((((((projeto_itens pi
             JOIN vw_produtos_custo_restrito p ON (((p.id = pi.produto_id) AND (p.ativo = true))))
             JOIN estoque_saldos_projeto_item esp ON (((esp.projeto_item_id = pi.id) AND (esp.status_operacional = 'ativo'::text))))
             LEFT JOIN orcamentos o ON ((o.id = pi.orcamento_id)))
             LEFT JOIN marcas mk ON ((mk.id = p.marca_id)))
             LEFT JOIN contatos forn ON ((forn.id = COALESCE(p.fornecedor_principal_id, mk.fornecedor_id))))
             LEFT JOIN cobertura_pedidos cob ON ((cob.projeto_item_id = pi.id)))
             LEFT JOIN empresas emp ON ((emp.id = o.empresa_id)))
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
    pendente_item,
    empresa_id,
    empresa_nome
   FROM base
  WHERE (pendente_item > (0)::numeric)
  ORDER BY orcamento_numero, l_fixo, produto;

REVOKE ALL ON FUNCTION public.aprovar_pedido_compra(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.editar_pedido_compra(uuid, jsonb, date, text, text, numeric, uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.registrar_entrada_pedido_compra(uuid, jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.prazo_medio_entrega_fornecedor(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.aprovar_pedido_compra(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.editar_pedido_compra(uuid, jsonb, date, text, text, numeric, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_entrada_pedido_compra(uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.prazo_medio_entrega_fornecedor(uuid) TO authenticated;

COMMIT;
