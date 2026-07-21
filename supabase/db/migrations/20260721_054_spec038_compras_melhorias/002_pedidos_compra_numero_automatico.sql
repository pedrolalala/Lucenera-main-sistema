-- Migration 20260721_054 - SPEC-038 Item 2 (+ wiring do Item 1)
--
-- Item 2: numeracao automatica de pedidos_compra.numero, reaproveitando o
-- padrao ja usado por set_orcamento_numero() (01_schema_full.sql:3712-3728),
-- escopado por ano (bate com o placeholder "PC-2026-001" ja exibido na UI).
--
-- Esta migration tambem recria as duas RPCs de criacao de pedido
-- (criar_pedido_compra_de_necessidade, criar_pedido_compra_lote) -- o que ja
-- e necessario para tornar p_numero opcional -- e aproveita a recriacao para
-- adicionar os parametros novos do Item 1 (custo_liquido/valor_icms/
-- valor_ipi/valor_st), gravados em pedido_compra_itens (colunas criadas em
-- 001). Os parametros novos ficam no FINAL da lista, todos DEFAULT NULL,
-- para que CREATE OR REPLACE FUNCTION continue compativel com chamadas
-- antigas (regra do Postgres: so pode ADICIONAR parametros com default no
-- final; nao pode remover/reordenar/retipar).
--
-- Definicoes reais e atuais confirmadas antes de reescrever:
--   supabase/db/migrations/20260710_032_spec021_registrar_pedido_compra/001_rpc_criar_pedido.sql
--   supabase/db/migrations/20260716_049_spec030_pedido_lote_marca_fornecedor/003_rpc_criar_pedido_compra_lote.sql

-- -----------------------------------------------------------------------
-- 1. Trigger de numeracao automatica
-- -----------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.set_pedido_compra_numero()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_max_num integer;
  v_ano     text := to_char(CURRENT_DATE, 'YYYY');
BEGIN
  IF NEW.numero IS NULL OR trim(NEW.numero) = '' THEN
    SELECT COALESCE(MAX(CAST(SPLIT_PART(numero, '-', 3) AS integer)), 0)
    INTO v_max_num
    FROM public.pedidos_compra
    WHERE numero LIKE 'PC-' || v_ano || '-%'
      AND numero ~ ('^PC-' || v_ano || '-[0-9]+$');

    NEW.numero := 'PC-' || v_ano || '-' || LPAD((v_max_num + 1)::text, 4, '0');
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.set_pedido_compra_numero() IS
'SPEC-038. Gera pedidos_compra.numero automaticamente no formato PC-<ano>-NNNN
quando NEW.numero vier NULL/vazio. Mesmo padrao de set_orcamento_numero().';

DROP TRIGGER IF EXISTS trigger_set_pedido_compra_numero ON public.pedidos_compra;
CREATE TRIGGER trigger_set_pedido_compra_numero
  BEFORE INSERT ON public.pedidos_compra
  FOR EACH ROW EXECUTE FUNCTION public.set_pedido_compra_numero();

-- Gap de integridade pre-existente: numero nunca teve UNIQUE. Adicionar
-- agora. Se ja houver duplicatas reais no banco, este ALTER falha -- passo
-- manual do usuario checar antes de aplicar:
--   SELECT numero, count(*) FROM pedidos_compra GROUP BY numero HAVING count(*) > 1;
ALTER TABLE public.pedidos_compra
  ADD CONSTRAINT pedidos_compra_numero_uniq UNIQUE (numero);

-- -----------------------------------------------------------------------
-- 2. criar_pedido_compra_de_necessidade: p_numero opcional + campos de
--    imposto do Item 1 (custo_liquido/valor_icms/valor_ipi/valor_st)
-- -----------------------------------------------------------------------
--
-- A assinatura muda de 8 para 12 parametros. No Postgres a identidade de
-- uma funcao e (nome, lista ORDENADA de tipos de argumento) -- DEFAULT nao
-- conta para essa identidade, mas a QUANTIDADE de parametros conta. Como a
-- lista de tipos muda de tamanho, CREATE OR REPLACE FUNCTION NAO substitui
-- a versao antiga de 8 parametros -- cria uma sobrecarga nova, deixando a
-- antiga (numero obrigatorio, sem colunas de imposto) orfa e ainda
-- invocavel. DROP explicito da assinatura antiga antes de recriar:
DROP FUNCTION IF EXISTS public.criar_pedido_compra_de_necessidade(uuid, uuid, numeric, numeric, text, date, text, text);

CREATE OR REPLACE FUNCTION public.criar_pedido_compra_de_necessidade(
    p_produto_id             uuid,
    p_fornecedor_id          uuid,
    p_quantidade             numeric,
    p_custo_unitario         numeric,
    p_numero                 text    DEFAULT NULL,
    p_data_prevista_entrega  date    DEFAULT NULL,
    p_condicoes_pagamento    text    DEFAULT NULL,
    p_observacao             text    DEFAULT NULL,
    p_custo_liquido          numeric DEFAULT NULL,
    p_valor_icms             numeric DEFAULT NULL,
    p_valor_ipi              numeric DEFAULT NULL,
    p_valor_st               numeric DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_solicitacao_id  uuid;
    v_pedido_id       uuid;
    v_pedido_item_id  uuid;
    v_numero_final    text;
BEGIN
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

    -- 1. Cria solicitacao de compra ja como pedido_gerado
    INSERT INTO public.solicitacoes_compra (
        produto_id, quantidade, status, prioridade, observacao, solicitado_por
    ) VALUES (
        p_produto_id, p_quantidade, 'pedido_gerado', 'normal', p_observacao, auth.uid()
    )
    RETURNING id INTO v_solicitacao_id;

    -- 2. Cria pedido de compra com status enviado.
    --    p_numero NULL/vazio: trigger_set_pedido_compra_numero preenche
    --    automaticamente (Item 2).
    INSERT INTO public.pedidos_compra (
        numero, fornecedor_id, status, data_emissao,
        data_prevista_entrega, condicoes_pagamento,
        valor_total, observacao, aprovado_por, aprovado_em, criado_por
    ) VALUES (
        NULLIF(trim(p_numero), ''), p_fornecedor_id, 'enviado', CURRENT_DATE,
        p_data_prevista_entrega, p_condicoes_pagamento,
        p_quantidade * p_custo_unitario, p_observacao,
        auth.uid(), now(), auth.uid()
    )
    RETURNING id, numero INTO v_pedido_id, v_numero_final;

    -- 3. Cria item do pedido vinculado a solicitacao, gravando o breakdown
    --    de impostos do Item 1 quando informado pelo frontend.
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
$$;

COMMENT ON FUNCTION public.criar_pedido_compra_de_necessidade(uuid, uuid, numeric, numeric, text, date, text, text, numeric, numeric, numeric, numeric) IS
'SPEC-021, atualizada pela SPEC-038: p_numero agora opcional -- se NULL/vazio,
gerado automaticamente por trigger_set_pedido_compra_numero (formato
PC-<ano>-NNNN, Item 2). p_custo_liquido/p_valor_icms/p_valor_ipi/p_valor_st
(Item 1, todos opcionais) gravam o breakdown de custo/impostos efetivo desta
compra em pedido_compra_itens -- nao alteram produtos.icms_entrada/
ipi_entrada/porc_st.';

GRANT EXECUTE ON FUNCTION public.criar_pedido_compra_de_necessidade(uuid, uuid, numeric, numeric, text, date, text, text, numeric, numeric, numeric, numeric) TO authenticated;

-- -----------------------------------------------------------------------
-- 3. criar_pedido_compra_lote: p_numero opcional + campos de imposto por
--    item (dentro do jsonb p_itens, sem mudar a assinatura da funcao)
-- -----------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.criar_pedido_compra_lote(
    p_fornecedor_id          uuid,
    p_itens                  jsonb,
    p_numero                 text    DEFAULT NULL,
    p_data_prevista_entrega  date    DEFAULT NULL,
    p_condicoes_pagamento    text    DEFAULT NULL,
    p_observacao             text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
BEGIN
    -- p_numero e opcional a partir da SPEC-038 (trigger_set_pedido_compra_numero
    -- preenche automaticamente se NULL/vazio) -- validacao de obrigatoriedade
    -- removida.

    IF NOT EXISTS (SELECT 1 FROM public.contatos WHERE id = p_fornecedor_id) THEN
        RAISE EXCEPTION 'Fornecedor % nao encontrado em contatos.', p_fornecedor_id USING ERRCODE = 'P0001';
    END IF;

    IF p_itens IS NULL OR jsonb_typeof(p_itens) <> 'array' OR jsonb_array_length(p_itens) = 0 THEN
        RAISE EXCEPTION 'Pedido em lote precisa de ao menos 1 item.' USING ERRCODE = 'P0001';
    END IF;

    -- Valida cada item e soma o valor total ANTES de criar qualquer registro
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

    -- 1. Cria pedido de compra unico (1 fornecedor fixo) com status enviado.
    --    p_numero NULL/vazio: trigger_set_pedido_compra_numero preenche
    --    automaticamente (Item 2).
    INSERT INTO public.pedidos_compra (
        numero, fornecedor_id, status, data_emissao,
        data_prevista_entrega, condicoes_pagamento,
        valor_total, observacao, aprovado_por, aprovado_em, criado_por
    ) VALUES (
        NULLIF(trim(p_numero), ''), p_fornecedor_id, 'enviado', CURRENT_DATE,
        p_data_prevista_entrega, p_condicoes_pagamento,
        v_valor_total, p_observacao,
        auth.uid(), now(), auth.uid()
    )
    RETURNING id, numero INTO v_pedido_id, v_numero_final;

    -- 2. Para cada item: cria solicitacao_compra (ja como pedido_gerado) +
    --    pedido_compra_itens vinculado a solicitacao e ao pedido unico.
    --    Campos de imposto do Item 1 sao opcionais dentro de cada elemento
    --    do jsonb (custo_liquido/valor_icms/valor_ipi/valor_st).
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
$$;

COMMENT ON FUNCTION public.criar_pedido_compra_lote(uuid, jsonb, text, date, text, text) IS
'SPEC-030 Parte 2, atualizada pela SPEC-038: p_numero agora opcional -- se
NULL/vazio, gerado automaticamente por trigger_set_pedido_compra_numero
(formato PC-<ano>-NNNN, Item 2). Cada elemento de p_itens pode incluir,
opcionalmente, custo_liquido/valor_icms/valor_ipi/valor_st (Item 1),
gravados em pedido_compra_itens.';

GRANT EXECUTE ON FUNCTION public.criar_pedido_compra_lote(uuid, jsonb, text, date, text, text) TO authenticated;
