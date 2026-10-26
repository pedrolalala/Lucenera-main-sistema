-- SPEC-232 — "Reserva sem venda (herança Connect)" não muda com venda feita no sistema.
-- herança = estoque_itens.quantidade_reservada (local Estoque) − (Reserva + Entrega Futura + Separação dos L).
-- Toda operação de venda do sistema passa a mexer no reservado na mesma medida em que mexe nesses saldos.
-- Funções recriadas a partir de pg_get_functiondef de 26/10 (só os trechos marcados SPEC-232 mudaram).
BEGIN;

-- 1. Finalizar a separação (Entregue) baixa o Estoque Geral e libera o reservado
CREATE OR REPLACE FUNCTION public.sync_entregue_ao_finalizar_separacao()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_item record;
BEGIN
    IF NEW.status = 'finalizado' AND (OLD.status IS DISTINCT FROM NEW.status) THEN
        FOR v_item IN
            SELECT id, projeto_item_id, quantidade - quantidade_estornada AS quantidade, separado
            FROM public.separacao_itens
            WHERE separacao_id = NEW.id
              AND projeto_item_id IS NOT NULL
              AND NOT entregue
              AND quantidade > quantidade_estornada
        LOOP
            -- Defensivo: se por algum motivo o item nunca passou por
            -- 'Pronto' (não foi marcado separado), ainda assim move o
            -- que sobrar em q_ag_separar direto pra q_entregue.
            IF v_item.separado THEN
                UPDATE public.estoque_saldos_projeto_item
                SET q_separado = GREATEST(q_separado - v_item.quantidade, 0),
                    q_entregue = q_entregue + v_item.quantidade,
                    atualizado_em = now()
                WHERE projeto_item_id = v_item.projeto_item_id;
            ELSE
                UPDATE public.estoque_saldos_projeto_item
                SET q_ag_separar = GREATEST(q_ag_separar - v_item.quantidade, 0),
                    q_entregue = q_entregue + v_item.quantidade,
                    atualizado_em = now()
                WHERE projeto_item_id = v_item.projeto_item_id;
            END IF;

            UPDATE public.separacao_itens SET entregue = true WHERE id = v_item.id;

            -- SPEC-232: a peça saiu da venda (Separação -> Entregue): sai do Estoque Geral físico e libera o
            -- reservado na mesma medida, para a "Reserva sem venda (herança Connect)" não mudar com venda do sistema.
            UPDATE public.estoque_itens
            SET quantidade = GREATEST(quantidade - v_item.quantidade, 0),
                quantidade_reservada = GREATEST(quantidade_reservada - v_item.quantidade, 0),
                atualizado_em = now()
            WHERE produto_id = (SELECT produto_id FROM public.projeto_itens WHERE id = v_item.projeto_item_id)
              AND local = 'Estoque'::public.estoque_local;

            INSERT INTO public.estoque_movimentos_projeto_item
                (projeto_item_id, tipo, quantidade, origem, referencia_id, criado_por)
            VALUES
                (v_item.projeto_item_id, 'entregue', v_item.quantidade, 'separacao_parcial', NEW.id, auth.uid());
        END LOOP;
    END IF;
    RETURN NEW;
END;
$function$;

-- 2. Entrega concluída (Logística) baixa o Estoque Geral e libera o reservado, sem contar em dobro
CREATE OR REPLACE FUNCTION public.sync_entregue_ao_finalizar_entrega()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_item record;
BEGIN
    IF NEW.status = 'Entregue' AND (OLD.status IS DISTINCT FROM NEW.status) AND NEW.separacao_id IS NOT NULL THEN
        FOR v_item IN
            SELECT id, projeto_item_id, quantidade - quantidade_estornada AS quantidade
            FROM public.separacao_itens
            WHERE separacao_id = NEW.separacao_id
              AND projeto_item_id IS NOT NULL
              AND quantidade > quantidade_estornada
              -- SPEC-232: o que a separação já entregou não entra de novo (antes contava em dobro)
              AND NOT entregue
        LOOP
            UPDATE public.estoque_saldos_projeto_item
            SET q_separado = GREATEST(q_separado - v_item.quantidade, 0),
                q_entregue = q_entregue + v_item.quantidade,
                atualizado_em = now()
            WHERE projeto_item_id = v_item.projeto_item_id;

            UPDATE public.separacao_itens SET entregue = true WHERE id = v_item.id;

            -- SPEC-232: a peça saiu da venda (Separação -> Entregue): sai do Estoque Geral físico e libera o
            -- reservado na mesma medida, para a "Reserva sem venda (herança Connect)" não mudar com venda do sistema.
            UPDATE public.estoque_itens
            SET quantidade = GREATEST(quantidade - v_item.quantidade, 0),
                quantidade_reservada = GREATEST(quantidade_reservada - v_item.quantidade, 0),
                atualizado_em = now()
            WHERE produto_id = (SELECT produto_id FROM public.projeto_itens WHERE id = v_item.projeto_item_id)
              AND local = 'Estoque'::public.estoque_local;

            INSERT INTO public.estoque_movimentos_projeto_item
                (projeto_item_id, tipo, quantidade, origem, referencia_id, criado_por)
            VALUES
                (v_item.projeto_item_id, 'entregue', v_item.quantidade, 'entrega', NEW.id, auth.uid());
        END LOOP;
    END IF;
    RETURN NEW;
END;
$function$;

-- 3. Devolução do Entregue soma no Estoque Geral e não baixa o reservado
CREATE OR REPLACE FUNCTION public.registrar_devolucao_projeto_item_setor(p_projeto_item_id uuid, p_setor_origem text, p_quantidade numeric, p_motivo text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_saldo        public.estoque_saldos_projeto_item%ROWTYPE;
    v_produto_id   uuid;
    v_saldo_setor  numeric(10,3);
    v_devolucao_id uuid;
BEGIN
    IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
        RAISE EXCEPTION 'Quantidade deve ser maior que zero.' USING ERRCODE = 'P0001';
    END IF;

    -- SPEC-182 (D6): em separação não se devolve — cancelar a separação antes.
    IF p_setor_origem = 'em_separacao' THEN
        RAISE EXCEPTION 'Peça em separação não pode ser devolvida. Cancele a separação antes de devolver.'
            USING ERRCODE = 'P0001';
    END IF;

    IF p_setor_origem NOT IN ('entrega_futura', 'reserva', 'entregue') THEN
        RAISE EXCEPTION 'Setor de origem inválido: %. Use reserva, entrega_futura ou entregue.', p_setor_origem
            USING ERRCODE = 'P0001';
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

    v_saldo_setor := CASE p_setor_origem
        WHEN 'entrega_futura' THEN v_saldo.q_entrega_futura
        WHEN 'reserva' THEN v_saldo.q_reserva
        -- SPEC-182 (D7): Entregue não baixa; o que ainda pode voltar é o
        -- entregue menos o que já foi devolvido dele.
        WHEN 'entregue' THEN v_saldo.q_entregue - v_saldo.q_devolvida_entregue
    END;

    IF p_quantidade > v_saldo_setor THEN
        RAISE EXCEPTION 'Quantidade de devolucao (%) excede o saldo do setor % (%).',
            p_quantidade, p_setor_origem, v_saldo_setor USING ERRCODE = 'P0001';
    END IF;

    UPDATE public.estoque_saldos_projeto_item
    SET q_entrega_futura = q_entrega_futura - CASE WHEN p_setor_origem = 'entrega_futura' THEN p_quantidade ELSE 0 END,
        q_reserva        = q_reserva        - CASE WHEN p_setor_origem = 'reserva' THEN p_quantidade ELSE 0 END,
        q_devolvida      = q_devolvida + p_quantidade,
        q_devolvida_entregue = q_devolvida_entregue + CASE WHEN p_setor_origem = 'entregue' THEN p_quantidade ELSE 0 END,
        atualizado_em = now()
    WHERE projeto_item_id = p_projeto_item_id;

    -- R4: libera a reserva do produto. SPEC-232: só o que saiu de Reserva / Entrega Futura — o Entregue já
    -- liberou o reservado (e saiu do Estoque Geral) quando foi entregue: devolver do Entregue soma de volta no
    -- Estoque Geral e não mexe na herança da Connect.
    IF v_produto_id IS NOT NULL AND p_setor_origem = 'entregue' THEN
        UPDATE public.estoque_itens
        SET quantidade = quantidade + p_quantidade,
            atualizado_em = now()
        WHERE produto_id = v_produto_id
          AND local = 'Estoque'::public.estoque_local;
    ELSIF v_produto_id IS NOT NULL THEN
        UPDATE public.estoque_itens
        SET quantidade_reservada = GREATEST(quantidade_reservada - p_quantidade, 0),
            atualizado_em = now()
        WHERE produto_id = v_produto_id
          AND local = 'Estoque'::public.estoque_local;
    END IF;

    INSERT INTO public.devolucoes_estoque (
        projeto_item_id, quantidade, qtd_de_entrega_futura, qtd_de_reserva, qtd_de_entregue,
        status, motivo, solicitado_por
    ) VALUES (
        p_projeto_item_id, p_quantidade,
        CASE WHEN p_setor_origem = 'entrega_futura' THEN p_quantidade ELSE 0 END,
        CASE WHEN p_setor_origem = 'reserva' THEN p_quantidade ELSE 0 END,
        CASE WHEN p_setor_origem = 'entregue' THEN p_quantidade ELSE 0 END,
        'registrada',
        p_motivo, auth.uid()
    )
    RETURNING id INTO v_devolucao_id;

    INSERT INTO public.estoque_movimentos_projeto_item
        (projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por)
    VALUES
        (p_projeto_item_id, 'devolucao', p_quantidade, 'devolucao_estoque', v_devolucao_id,
         concat_ws(' — ', 'Setor: ' || p_setor_origem, p_motivo), auth.uid());

    RETURN jsonb_build_object(
        'devolucao_id', v_devolucao_id,
        'status', 'registrada',
        'setor_origem', p_setor_origem,
        'quantidade', p_quantidade
    );
END;
$function$;

-- 4. Receber devolução do Entregue não baixa o reservado
CREATE OR REPLACE FUNCTION public.confirmar_recebimento_devolucao(p_devolucao_id uuid, p_observacao text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_dev        public.devolucoes_estoque%ROWTYPE;
    v_produto_id uuid;
BEGIN
    IF auth.uid() IS NULL AND COALESCE(auth.role(), '') <> 'service_role' THEN
        RAISE EXCEPTION 'É preciso estar logado para confirmar o recebimento.' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_dev FROM public.devolucoes_estoque WHERE id = p_devolucao_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Devolução % não encontrada.', p_devolucao_id USING ERRCODE = 'P0001';
    END IF;
    IF v_dev.status <> 'aguardando_recebimento' THEN
        RAISE EXCEPTION 'Esta devolução não está aguardando recebimento (status atual: %).', v_dev.status USING ERRCODE = 'P0001';
    END IF;

    SELECT produto_id INTO v_produto_id FROM public.projeto_itens WHERE id = v_dev.projeto_item_id;

    -- SPEC-232: Entregue já liberou o reservado na entrega; receber a devolução não mexe mais nele.
    IF false AND v_produto_id IS NOT NULL AND v_dev.qtd_de_entregue > 0 THEN
        UPDATE public.estoque_itens
        SET quantidade_reservada = GREATEST(quantidade_reservada - v_dev.qtd_de_entregue, 0),
            atualizado_em = now()
        WHERE produto_id = v_produto_id
          AND local = 'Estoque'::public.estoque_local;
    END IF;

    UPDATE public.devolucoes_estoque
    SET status = 'recebida',
        recebido_em = now(),
        recebido_por = auth.uid(),
        observacao_recebimento = NULLIF(btrim(p_observacao), '')
    WHERE id = p_devolucao_id;

    INSERT INTO public.estoque_movimentos_projeto_item
        (projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por)
    VALUES
        (v_dev.projeto_item_id, 'devolucao_recebida', v_dev.quantidade, 'devolucao_estoque', v_dev.id,
         NULLIF(btrim(p_observacao), ''), auth.uid());

    RETURN jsonb_build_object('devolucao_id', p_devolucao_id, 'status', 'recebida', 'quantidade', v_dev.quantidade);
END;
$function$;

-- 5. Re-reserva (Entrega Futura -> Reserva) não soma o reservado de novo
CREATE OR REPLACE FUNCTION public.re_reservar_projeto_item(p_projeto_item_id uuid, p_quantidade numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_saldo RECORD;
  v_produto_id UUID;
  v_disponivel NUMERIC;
BEGIN
  SELECT * INTO v_saldo FROM public.estoque_saldos_projeto_item
  WHERE projeto_item_id = p_projeto_item_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Saldo não encontrado para o item do projeto.');
  END IF;

  IF p_quantidade <= 0 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Quantidade deve ser maior que zero.');
  END IF;

  IF p_quantidade > v_saldo.q_entrega_futura THEN
    RETURN jsonb_build_object('success', false, 'message', 'Quantidade excede a entrega futura disponível.');
  END IF;

  SELECT produto_id INTO v_produto_id FROM public.projeto_itens WHERE id = p_projeto_item_id;

  SELECT COALESCE(SUM(quantidade - quantidade_reservada), 0) INTO v_disponivel
  FROM public.estoque_itens WHERE produto_id = v_produto_id;

  IF p_quantidade > v_disponivel THEN
    RETURN jsonb_build_object('success', false, 'message', 'Estoque físico insuficiente para re-reserva.');
  END IF;

  UPDATE public.estoque_saldos_projeto_item
  SET q_entrega_futura = q_entrega_futura - p_quantidade,
      q_reserva = q_reserva + p_quantidade,
      atualizado_em = now()
  WHERE projeto_item_id = p_projeto_item_id;

  -- SPEC-232: a aprovação do orçamento já somou a venda inteira (reserva + entrega futura) em
  -- quantidade_reservada; Entrega Futura -> Reserva não soma de novo.

  RETURN jsonb_build_object('success', true, 'message', 'Re-reserva realizada com sucesso.');
END;
$function$;

-- 6. Aprovação: peça já com o cliente (empréstimo) não soma no reservado
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
  v_numero_venda text;
  v_seq_venda integer;
  v_item record;
  v_estoque_fisico numeric(10,2);
  v_estoque_reservado_atual numeric(10,2);
  v_disponivel_fisico numeric(10,3);
  v_q_reserva numeric(10,3);
  v_q_entrega_futura numeric(10,3);
  v_reservas_criadas integer := 0;
  v_saldos_criados integer := 0;
  v_devolucoes_processadas integer := 0;
  v_plano jsonb;
  v_usar_plano boolean := false;
  v_elem jsonb;
  v_valores numeric[];
  v_dias_offsets integer[];
  v_formas text[];
  v_permuta_ids uuid[];
  v_soma_plano numeric;
  v_qtd_boletos_esperados integer;
  v_plano_contas_permuta_id uuid;
  v_permuta_criados integer := 0;
  v_ja_com_cliente boolean;
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

  -- SPEC-195: vínculo de venda da Connect não passa pela aprovação financeira (não gera
  -- reserva, parcela nem boleto). Para aprovar de verdade, desfaça o vínculo antes.
  IF v_orcamento.vinculo_connect THEN
    RAISE EXCEPTION 'Orçamento % é vínculo de venda da Connect — não pode ser aprovado financeiramente. Desfaça o vínculo antes.', coalesce(v_orcamento.numero, p_orcamento_id::text)
      USING ERRCODE = 'P0001';
  END IF;

  -- SPEC-223: empréstimo não gera reserva, parcela nem boleto. Para cobrar, vira venda.
  IF v_orcamento.natureza_operacao = 'outros' AND v_orcamento.subgrupo = 'EMPRESTIMO' THEN
    RAISE EXCEPTION 'Empréstimo não passa pela aprovação financeira. Para cobrar, use "Virar venda" no empréstimo.'
      USING ERRCODE = 'P0001';
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

  -- =====================================================================
  -- SPEC-152: monta v_qtd_parcelas + arrays (valor/dias_offset/forma de
  -- pagamento/fornecedor de permuta) por parcela -- de plano_parcelas
  -- quando presente, senão do jeito legado (parse de prazo + divisão
  -- igual + forma de pagamento única do orçamento).
  -- =====================================================================
  v_plano := v_orcamento.plano_parcelas;
  v_valor_total := coalesce(v_orcamento.valor_total, 0);

  IF v_plano IS NOT NULL AND jsonb_typeof(v_plano) = 'array' AND jsonb_array_length(v_plano) > 0 THEN
    v_usar_plano := true;
    v_qtd_parcelas := jsonb_array_length(v_plano);
    v_valores := ARRAY[]::numeric[];
    v_dias_offsets := ARRAY[]::integer[];
    v_formas := ARRAY[]::text[];
    v_permuta_ids := ARRAY[]::uuid[];

    FOR v_i IN 0..v_qtd_parcelas - 1 LOOP
      v_elem := v_plano -> v_i;
      v_valores := v_valores || round(coalesce((v_elem->>'valor')::numeric, 0), 2);
      v_dias_offsets := v_dias_offsets || coalesce((v_elem->>'dias_offset')::integer, 0);
      v_formas := v_formas || coalesce(nullif(v_elem->>'forma_pagamento', ''), v_orcamento.forma_pagamento::text);
      v_permuta_ids := v_permuta_ids || nullif(v_elem->>'permuta_fornecedor_id', '')::uuid;
    END LOOP;

    -- Regra dura (decisão do usuário, 2026-09-17): soma das parcelas deve
    -- ser EXATAMENTE igual ao valor a pagar -- nunca arredonda
    -- silenciosamente. O frontend já valida isso antes de salvar o
    -- orçamento (BudgetFormPage.tsx); esta é a validação de segurança no
    -- backend, fonte de verdade final.
    SELECT coalesce(sum(v), 0) INTO v_soma_plano FROM unnest(v_valores) AS v;
    IF abs(v_soma_plano - v_valor_total) > 0.01 THEN
      RAISE EXCEPTION 'Soma do plano de parcelas (%) não bate com o valor total do orçamento (%).',
        v_soma_plano, v_valor_total USING ERRCODE = 'P0001';
    END IF;
  ELSE
    v_prazos := public._lucenera_parse_prazo_pagamento(v_orcamento.condicoes_pagamento, v_orcamento.prazo_pagamento_dias);
    v_qtd_parcelas := coalesce(array_length(v_prazos, 1), 0);
    IF v_qtd_parcelas = 0 THEN
      RAISE EXCEPTION 'Orçamento % não possui prazo de pagamento interpretável.', v_numero_orcamento USING ERRCODE = 'P0001';
    END IF;

    v_dias_offsets := v_prazos;
    v_formas := ARRAY(SELECT v_orcamento.forma_pagamento::text FROM generate_series(1, v_qtd_parcelas));
    v_permuta_ids := ARRAY(SELECT NULL::uuid FROM generate_series(1, v_qtd_parcelas));

    v_valor_base := round(v_valor_total / v_qtd_parcelas, 2);
    v_valores := ARRAY[]::numeric[];
    v_valor_acumulado := 0;
    FOR v_i IN 1..v_qtd_parcelas LOOP
      IF v_i = v_qtd_parcelas THEN
        v_valores := v_valores || round(v_valor_total - v_valor_acumulado, 2);
      ELSE
        v_valores := v_valores || v_valor_base;
        v_valor_acumulado := v_valor_acumulado + v_valor_base;
      END IF;
    END LOOP;
  END IF;

  -- SPEC-156: parcela de permuta exige contato real, fornecedor OU cliente
  -- (antes só aceitava tipo='fornecedor' -- às vezes a contraparte da
  -- permuta é o próprio cliente oferecendo produto/serviço em troca).
  FOR v_i IN 1..v_qtd_parcelas LOOP
    IF v_formas[v_i] = 'permuta' THEN
      IF v_permuta_ids[v_i] IS NULL THEN
        RAISE EXCEPTION 'Parcela % está marcada como permuta mas não tem fornecedor/cliente definido.', v_i
          USING ERRCODE = 'P0001';
      END IF;
      IF NOT EXISTS (SELECT 1 FROM public.contatos WHERE id = v_permuta_ids[v_i] AND tipo IN ('fornecedor', 'cliente')) THEN
        RAISE EXCEPTION 'Parcela % de permuta precisa de um fornecedor ou cliente válido (contatos.tipo IN (fornecedor, cliente)).', v_i
          USING ERRCODE = 'P0001';
      END IF;
    END IF;
  END LOOP;

  -- Quantidade de boletos esperada quando o processamento já rodou antes
  -- (idempotência) -- carteira/permuta não geram boleto, então já não é
  -- igual a v_qtd_parcelas como no comportamento legado.
  SELECT count(*) INTO v_qtd_boletos_esperados FROM unnest(v_formas) AS f WHERE f NOT IN ('carteira', 'permuta');

  SELECT nome INTO v_cliente_nome FROM public.contatos WHERE id = v_orcamento.cliente_id;

  -- =====================================================================
  -- SPEC-071: ramo de DEVOLUÇÃO — não cria projeto_itens/reserva de estoque
  -- positiva; devolve estoque via registrar_devolucao_projeto_item (SPEC-015)
  -- e lança crédito financeiro negativo em vez de cobrança.
  -- SPEC-136: devolução não gera numero_venda — é crédito sobre uma venda já
  -- existente, não uma venda nova.
  -- =====================================================================
  IF v_orcamento.natureza_operacao = 'devolucao' THEN
    IF EXISTS (
      SELECT 1 FROM public.orcamento_itens oi
      WHERE oi.orcamento_id = p_orcamento_id AND oi.projeto_item_origem_id IS NULL
    ) THEN
      RAISE EXCEPTION 'Orçamento de devolução % possui item sem venda de origem vinculada.', v_numero_orcamento
        USING ERRCODE = 'P0001';
    END IF;

    -- SPEC-182 (05/10): a devolução se liga ao CÓDIGO DO PROJETO (substitui a
    -- venda única da SPEC-181): cada item precisa vir de uma venda efetivada
    -- do mesmo projeto e da mesma empresa da devolução; pode misturar vendas.
    IF EXISTS (
      SELECT 1 FROM public.orcamento_itens oi
      JOIN public.projeto_itens pi ON pi.id = oi.projeto_item_origem_id
      LEFT JOIN public.orcamentos vo ON vo.id = pi.orcamento_id
      WHERE oi.orcamento_id = p_orcamento_id
        AND (vo.id IS NULL
             OR vo.numero_venda IS NULL
             OR vo.projeto_id IS DISTINCT FROM v_orcamento.projeto_id
             OR pi.projeto_id IS DISTINCT FROM v_orcamento.projeto_id
             OR vo.empresa_id IS DISTINCT FROM v_orcamento.empresa_id)
    ) THEN
      RAISE EXCEPTION 'Orçamento de devolução % possui item que não é de uma venda efetivada deste projeto e desta empresa.', v_numero_orcamento
        USING ERRCODE = 'P0001';
    END IF;
    -- SPEC-182 (D6): peça em separação não se devolve — cancelar a separação antes.
    IF EXISTS (
      SELECT 1 FROM public.orcamento_itens oi
      WHERE oi.orcamento_id = p_orcamento_id AND oi.setor_origem = 'em_separacao'
    ) THEN
      RAISE EXCEPTION 'Orçamento de devolução % tem peça em separação. Cancele a separação antes de devolver.', v_numero_orcamento
        USING ERRCODE = 'P0001';
    END IF;

    SELECT count(*) INTO v_parcelas_existentes FROM public.projeto_parcelas WHERE orcamento_id = p_orcamento_id;
    SELECT count(*) INTO v_boletos_existentes FROM public.boletos WHERE orcamento_id = p_orcamento_id AND tipo_operacao IS DISTINCT FROM 'CP';

    IF v_parcelas_existentes = v_qtd_parcelas AND v_boletos_existentes = v_qtd_boletos_esperados THEN
      UPDATE public.orcamentos SET status = 'Orçamento Aprovado' WHERE id = p_orcamento_id;
      RETURN jsonb_build_object(
        'orcamento_id', p_orcamento_id, 'status', 'Orçamento Aprovado', 'natureza_operacao', 'devolucao',
        'projeto_id', v_orcamento.projeto_id,
        'devolucoes_processadas', 0, 'parcelas_criadas', 0, 'boletos_criados', 0, 'ja_processado', true
      );
    END IF;

    IF v_parcelas_existentes > 0 OR v_boletos_existentes > 0 THEN
      RAISE EXCEPTION 'Orçamento de devolução % possui processamento parcial inconsistente: parcelas %, boletos %.',
        v_numero_orcamento, v_parcelas_existentes, v_boletos_existentes USING ERRCODE = 'P0001';
    END IF;

    IF v_orcamento.status != 'Aprovação Financeira' THEN
      RAISE EXCEPTION 'Orçamento % não está aguardando aprovação financeira. Status atual: %', v_numero_orcamento, v_status_anterior
        USING ERRCODE = 'P0003';
    END IF;

    UPDATE public.orcamentos SET status = 'Orçamento Aprovado', requer_revisao_financeira = false WHERE id = p_orcamento_id;

    BEGIN
      INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
      VALUES (p_orcamento_id, v_status_anterior, 'Orçamento Aprovado', auth.uid()::text, 'Aprovação financeira de devolução — estoque devolvido e crédito lançado');
    EXCEPTION
      WHEN undefined_table OR undefined_column OR foreign_key_violation THEN
        NULL;
    END;

    -- SPEC-178: linha com setor_origem devolve exatamente daquele setor
    -- (uma linha por setor); linha antiga sem setor segue a cascata original.
    FOR v_item IN
      SELECT oi.projeto_item_origem_id AS projeto_item_id, oi.quantidade, oi.descricao, oi.setor_origem
      FROM public.orcamento_itens oi
      WHERE oi.orcamento_id = p_orcamento_id
    LOOP
      IF v_item.setor_origem IS NOT NULL THEN
        PERFORM public.registrar_devolucao_projeto_item_setor(
          v_item.projeto_item_id,
          v_item.setor_origem,
          v_item.quantidade,
          format('Devolução via orçamento %s%s', v_numero_orcamento,
            CASE WHEN v_item.descricao IS NOT NULL THEN ' — ' || v_item.descricao ELSE '' END)
        );
      ELSE
        PERFORM public.registrar_devolucao_projeto_item(
          v_item.projeto_item_id,
          v_item.quantidade,
          format('Devolução via orçamento %s%s', v_numero_orcamento,
            CASE WHEN v_item.descricao IS NOT NULL THEN ' — ' || v_item.descricao ELSE '' END)
        );
      END IF;
      v_devolucoes_processadas := v_devolucoes_processadas + 1;
    END LOOP;

    FOR v_i IN 1..v_qtd_parcelas LOOP
      v_valor_parcela := v_valores[v_i];
      INSERT INTO public.projeto_parcelas (
        projeto_id, numero_parcela, valor, data_fechamento, data_vencimento, status,
        forma_pagamento, orcamento_id, descricao, permuta_fornecedor_id
      )
      VALUES (
        v_orcamento.projeto_id, v_i, -v_valor_parcela, current_date, v_data_base + v_dias_offsets[v_i],
        (CASE WHEN v_formas[v_i] = 'permuta' THEN 'paga' ELSE 'pendente' END)::public.parcela_status,
        v_formas[v_i]::public.pagamento_forma, p_orcamento_id,
        'Crédito de devolução gerado pelo orçamento ' || v_numero_orcamento,
        v_permuta_ids[v_i]
      );
      v_parcelas_criadas := v_parcelas_criadas + 1;
    END LOOP;

    -- SPEC-152: carteira/permuta não geram "boleto" (nota de crédito, no
    -- ramo devolução) -- ver comentário no topo do arquivo.
    INSERT INTO public.boletos (nosso_numero, numero_documento, parcela_id, orcamento_id, empresa_id, valor, vencimento, nome_pagador, status, tipo, venda, num_parcela, total_parcelas, emissao)
    SELECT 'DEV-' || regexp_replace(v_numero_orcamento, '[^a-zA-Z0-9]', '', 'g') || '-P' || pp.numero_parcela,
      v_numero_orcamento || '-P' || pp.numero_parcela, pp.id, p_orcamento_id, v_orcamento.empresa_id,
      pp.valor, pp.data_vencimento, coalesce(v_cliente_nome, 'Cliente do orçamento'), 'pendente_registro', 'Nota de Crédito', NULL,
      pp.numero_parcela, v_qtd_parcelas, current_date
    FROM public.projeto_parcelas pp
    WHERE pp.orcamento_id = p_orcamento_id AND pp.forma_pagamento NOT IN ('carteira', 'permuta')
    ON CONFLICT (nosso_numero) DO NOTHING;
    GET DIAGNOSTICS v_boletos_criados = ROW_COUNT;

    -- SPEC-152: contrapartida automática de Contas a Pagar pra cada
    -- parcela de permuta (mesmo padrão manual de "Cadastrar Duplicatas",
    -- SPEC-073: boletos.tipo_operacao = 'CP' + apropriacao_id).
    SELECT id INTO v_plano_contas_permuta_id FROM public.plano_de_contas WHERE nome = 'PERMUTA/CONTRAPARTIDA' AND nivel = 3 LIMIT 1;
    INSERT INTO public.boletos (
      nosso_numero, numero_documento, orcamento_id, empresa_id, apropriacao_id,
      tipo_operacao, valor, vencimento, nome_pagador, status, tipo, num_parcela, total_parcelas, emissao, observacao
    )
    SELECT
      'PERM-' || regexp_replace(v_numero_orcamento, '[^a-zA-Z0-9]', '', 'g') || '-P' || pp.numero_parcela,
      v_numero_orcamento || '-PERMUTA-P' || pp.numero_parcela,
      p_orcamento_id, v_orcamento.empresa_id, v_plano_contas_permuta_id,
      'CP', abs(pp.valor), pp.data_vencimento,
      coalesce(f.razao_social, f.nome, 'Contraparte da permuta'),
      'Pendente', 'Normal', pp.numero_parcela, v_qtd_parcelas, current_date,
      'Contrapartida automática de permuta gerada pela aprovação do orçamento ' || v_numero_orcamento
    FROM public.projeto_parcelas pp
    LEFT JOIN public.contatos f ON f.id = pp.permuta_fornecedor_id
    WHERE pp.orcamento_id = p_orcamento_id AND pp.forma_pagamento = 'permuta'
    ON CONFLICT (nosso_numero) DO NOTHING;
    GET DIAGNOSTICS v_permuta_criados = ROW_COUNT;

    RETURN jsonb_build_object(
      'orcamento_id', p_orcamento_id, 'status', 'Orçamento Aprovado', 'natureza_operacao', 'devolucao',
      'projeto_id', v_orcamento.projeto_id,
      'devolucoes_processadas', v_devolucoes_processadas,
      'parcelas_criadas', v_parcelas_criadas, 'boletos_criados', v_boletos_criados,
      'contrapartidas_permuta_criadas', v_permuta_criados,
      'ja_processado', false
    );
  END IF;

  -- =====================================================================
  -- Ramo VENDA — comportamento original, exceto pela correção de prioridade
  -- da descrição do item (ver cabeçalho da migration).
  -- =====================================================================
  -- SPEC-135: bloqueia aprovação (faturamento) quando existe item sem
  -- produto cadastrado — sem isso, vira uma venda "fantasma" sem controle
  -- de estoque nenhum (o loop abaixo já pula reserva pra item sem
  -- produto_id, mas antes disso deixava aprovar e gerar parcela/boleto
  -- normalmente). O item precisa ser vinculado a um produto real (cadastro)
  -- antes desta aprovação — não se aplica à devolução, que já retorna acima.
  IF EXISTS (
    SELECT 1 FROM public.orcamento_itens oi
    WHERE oi.orcamento_id = p_orcamento_id AND oi.produto_id IS NULL
  ) THEN
    RAISE EXCEPTION 'Orçamento % possui item sem produto cadastrado (peça sem código interno) — cadastre o produto antes de aprovar financeiramente.', v_numero_orcamento
      USING ERRCODE = 'P0001';
  END IF;

  SELECT count(*) INTO v_itens_existentes FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id;
  SELECT count(*) INTO v_parcelas_existentes FROM public.projeto_parcelas WHERE orcamento_id = p_orcamento_id;
  SELECT count(*) INTO v_boletos_existentes FROM public.boletos WHERE orcamento_id = p_orcamento_id AND tipo_operacao IS DISTINCT FROM 'CP';

  IF v_itens_existentes > 0 AND v_parcelas_existentes = v_qtd_parcelas AND v_boletos_existentes = v_qtd_boletos_esperados THEN
    UPDATE public.orcamentos SET status = 'Orçamento Aprovado' WHERE id = p_orcamento_id;
    RETURN jsonb_build_object(
      'orcamento_id', p_orcamento_id, 'status', 'Orçamento Aprovado', 'projeto_id', v_orcamento.projeto_id,
      'numero_venda', v_orcamento.numero_venda,
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

  -- SPEC-136: numero da venda, gerado uma unica vez, sequencia global
  -- "VENDA-0001" no mesmo padrao de set_orcamento_numero() para ORC-XXXX.
  IF v_orcamento.numero_venda IS NULL THEN
    SELECT COALESCE(MAX(CAST(SUBSTRING(numero_venda FROM 7) AS INTEGER)), 0) + 1
    INTO v_seq_venda
    FROM public.orcamentos
    WHERE numero_venda LIKE 'VENDA-%' AND numero_venda ~ '^VENDA-\d+$';
    v_numero_venda := 'VENDA-' || LPAD(v_seq_venda::text, 4, '0');
  ELSE
    v_numero_venda := v_orcamento.numero_venda;
  END IF;

  UPDATE public.orcamentos
  SET status = 'Orçamento Aprovado', requer_revisao_financeira = false, numero_venda = v_numero_venda
  WHERE id = p_orcamento_id;

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
    SELECT v_orcamento.projeto_id, oi.produto_id, coalesce(oi.descricao, p.nome, oi.custom_id, 'Item do Orçamento'),
      coalesce(oi.quantidade, 0), coalesce(oi.preco_unitario, 0), coalesce(oi.desconto, 0),
      true, p_orcamento_id,
      oi.id, oi.custom_id
    FROM public.orcamento_itens oi LEFT JOIN public.produtos p ON p.id = oi.produto_id
    WHERE oi.orcamento_id = p_orcamento_id
    RETURNING id, produto_id, quantidade, orcamento_item_id
  LOOP
    v_itens_criados := v_itens_criados + 1;

    CONTINUE WHEN v_item.produto_id IS NULL OR coalesce(v_item.quantidade, 0) <= 0;

    -- SPEC-223: peça de venda que veio de empréstimo e já está com o cliente vai direto para
    -- Entregue (sem reserva/separação). A reserva no estoque_itens segue a regra de sempre.
    SELECT coalesce(oi.ja_com_cliente, false) INTO v_ja_com_cliente
      FROM public.orcamento_itens oi WHERE oi.id = v_item.orcamento_item_id;
    IF v_ja_com_cliente THEN
      INSERT INTO public.estoque_itens (produto_id, local, quantidade, quantidade_reservada, atualizado_em)
      VALUES (v_item.produto_id, 'Estoque'::public.estoque_local, 0, 0, NOW())
      ON CONFLICT (produto_id, local) DO NOTHING;
      -- SPEC-232: peça já com o cliente vai direto para Entregue — não soma no reservado.
      v_reservas_criadas := v_reservas_criadas + 1;
      INSERT INTO public.estoque_saldos_projeto_item (projeto_item_id, q_reserva, q_entrega_futura, q_entregue)
      VALUES (v_item.id, 0, 0, v_item.quantidade)
      ON CONFLICT (projeto_item_id) DO NOTHING;
      v_saldos_criados := v_saldos_criados + 1;
      INSERT INTO public.estoque_movimentos_projeto_item (
        projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por
      )
      VALUES (
        v_item.id, 'entregue', v_item.quantidade, 'emprestimo', p_orcamento_id,
        format('Já estava com o cliente (empréstimo) — entregue na aprovação do orçamento %s', v_numero_orcamento),
        auth.uid()
      );
      CONTINUE;
    END IF;

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

  FOR v_i IN 1..v_qtd_parcelas LOOP
    v_valor_parcela := v_valores[v_i];
    INSERT INTO public.projeto_parcelas (
      projeto_id, numero_parcela, valor, data_fechamento, data_vencimento, status,
      forma_pagamento, orcamento_id, descricao, permuta_fornecedor_id
    )
    VALUES (
      v_orcamento.projeto_id, v_i, v_valor_parcela, current_date, v_data_base + v_dias_offsets[v_i],
      (CASE WHEN v_formas[v_i] = 'permuta' THEN 'paga' ELSE 'pendente' END)::public.parcela_status,
      v_formas[v_i]::public.pagamento_forma, p_orcamento_id,
      'Parcela gerada pelo orçamento ' || v_numero_orcamento,
      v_permuta_ids[v_i]
    );
    v_parcelas_criadas := v_parcelas_criadas + 1;
  END LOOP;

  -- SPEC-152: carteira/permuta não geram boleto de cobrança pro cliente
  -- (ver comentário no topo do arquivo).
  INSERT INTO public.boletos (nosso_numero, numero_documento, parcela_id, orcamento_id, empresa_id, valor, vencimento, nome_pagador, status, tipo, venda, num_parcela, total_parcelas, emissao)
  SELECT 'ORC-' || regexp_replace(v_numero_orcamento, '[^a-zA-Z0-9]', '', 'g') || '-P' || pp.numero_parcela,
    v_numero_orcamento || '-P' || pp.numero_parcela, pp.id, p_orcamento_id, v_orcamento.empresa_id,
    pp.valor, pp.data_vencimento, coalesce(v_cliente_nome, 'Cliente do orçamento'), 'pendente_registro', 'Nota Fiscal', NULL,
    pp.numero_parcela, v_qtd_parcelas, current_date
  FROM public.projeto_parcelas pp
  WHERE pp.orcamento_id = p_orcamento_id AND pp.forma_pagamento NOT IN ('carteira', 'permuta')
  ON CONFLICT (nosso_numero) DO NOTHING;
  GET DIAGNOSTICS v_boletos_criados = ROW_COUNT;

  -- SPEC-152: contrapartida automática de Contas a Pagar pra cada parcela
  -- de permuta (mesmo padrão manual de "Cadastrar Duplicatas", SPEC-073:
  -- boletos.tipo_operacao = 'CP' + apropriacao_id -- rastreado até a
  -- origem por boletos.orcamento_id, já existente).
  SELECT id INTO v_plano_contas_permuta_id FROM public.plano_de_contas WHERE nome = 'PERMUTA/CONTRAPARTIDA' AND nivel = 3 LIMIT 1;
  INSERT INTO public.boletos (
    nosso_numero, numero_documento, orcamento_id, empresa_id, apropriacao_id,
    tipo_operacao, valor, vencimento, nome_pagador, status, tipo, num_parcela, total_parcelas, emissao, observacao
  )
  SELECT
    'PERM-' || regexp_replace(v_numero_orcamento, '[^a-zA-Z0-9]', '', 'g') || '-P' || pp.numero_parcela,
    v_numero_orcamento || '-PERMUTA-P' || pp.numero_parcela,
    p_orcamento_id, v_orcamento.empresa_id, v_plano_contas_permuta_id,
    'CP', abs(pp.valor), pp.data_vencimento,
    coalesce(f.razao_social, f.nome, 'Contraparte da permuta'),
    'Pendente', 'Normal', pp.numero_parcela, v_qtd_parcelas, current_date,
    'Contrapartida automática de permuta gerada pela aprovação do orçamento ' || v_numero_orcamento
  FROM public.projeto_parcelas pp
  LEFT JOIN public.contatos f ON f.id = pp.permuta_fornecedor_id
  WHERE pp.orcamento_id = p_orcamento_id AND pp.forma_pagamento = 'permuta'
  ON CONFLICT (nosso_numero) DO NOTHING;
  GET DIAGNOSTICS v_permuta_criados = ROW_COUNT;

  RETURN jsonb_build_object(
    'orcamento_id', p_orcamento_id, 'status', 'Orçamento Aprovado', 'projeto_id', v_orcamento.projeto_id,
    'numero_venda', v_numero_venda,
    'projeto_itens_criados', v_itens_criados, 'parcelas_criadas', v_parcelas_criadas, 'boletos_criados', v_boletos_criados,
    'contrapartidas_permuta_criadas', v_permuta_criados,
    'reservas_estoque_aplicadas', v_reservas_criadas, 'saldos_operacionais_criados', v_saldos_criados,
    'nota_fiscal_status', 'pendente_api', 'ja_processado', false
  );
END;
$function$;


-- 7. Acerto da peça 12822 (único caso afetado, testes de 26/10): 9 entregues não liberaram o reservado (+9)
--    e 6 devolvidas do Entregue baixaram (−6) => reservado 3 a mais. 85 -> 82, herança 35 -> 32.
--    Estoque Geral físico: 9 entregues não saíram (−9) e 6 devolvidas do Entregue não voltaram (+6) => 100 -> 97.
UPDATE public.estoque_itens ei
   SET quantidade_reservada = ei.quantidade_reservada - 3, quantidade = ei.quantidade - 3, atualizado_em = now()
  FROM public.produtos p
 WHERE p.id = ei.produto_id AND p.codigo_produto = '12822' AND ei.local = 'Estoque'::public.estoque_local
   AND ei.quantidade_reservada = 85 AND ei.quantidade = 100;

COMMIT;
