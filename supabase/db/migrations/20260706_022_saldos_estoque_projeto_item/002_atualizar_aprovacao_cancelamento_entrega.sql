-- Migration 20260706_022 — Parte 2
-- SPEC-010: liga as RPCs de aprovação, cancelamento e entrega ao saldo
-- operacional por projeto_item_id.
--
-- 1) aprovar_orcamento_financeiro_base_spec001
--    Passa a criar uma linha em estoque_saldos_projeto_item para cada item
--    aprovado com produto, dividindo a quantidade vendida entre q_reserva
--    (coberta por estoque físico disponível) e q_entrega_futura (o que
--    faltar). A alocação agora roda em loop, item por item, travando
--    (FOR UPDATE) a linha de estoque_itens por produto/local antes de ler o
--    saldo físico disponível — isso evita corrida quando o mesmo produto
--    aparece em mais de um item do mesmo orçamento (problema explicitamente
--    apontado na SPEC-010 como risco do desenho anterior, que fazia um único
--    INSERT em lote sem lock por linha).
--
-- 2) cancelar_orcamento
--    Passa a reverter a reserva física com base no saldo aberto real do item
--    (q_reserva + q_entrega_futura + q_ag_separar + q_separado), não mais na
--    quantidade original do orçamento — isso evita reverter em dobro um item
--    que já tenha sido parcialmente entregue/transferido antes do
--    cancelamento. Também encerra o saldo operacional do item
--    (status_operacional = 'cancelado') e registra o movimento.
--
-- 3) trigger_fechar_projeto
--    Passa a mover o saldo aberto do item para q_entregue no fechamento do
--    projeto, além do comportamento legado já existente (zerar
--    quantidade_reservada em estoque_itens). A granularidade por etapa
--    (separar antes de entregar) fica para o futuro sistema de Logística/
--    Estoque (EST-14/LOG-*); este trigger legado continua fechando o
--    projeto inteiro de uma vez, como já fazia antes desta SPEC.

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
$function$;

-- 2) cancelar_orcamento
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

COMMENT ON FUNCTION public.cancelar_orcamento(uuid, text) IS
'Cancela um orçamento. Se aprovado: reverte quantidade_reservada em estoque_itens
com base no saldo aberto real do item (SPEC-010), cancela projeto_parcelas,
cancela boletos, invalida projeto_itens e encerra o saldo operacional do item.
Todos os artefatos são mantidos para auditoria (soft-cancel). Registra em
historico_status_orcamentos e estoque_movimentos_projeto_item.';

-- 3) trigger_fechar_projeto
CREATE OR REPLACE FUNCTION public.trigger_fechar_projeto()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
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

    -- 3a. Baixar estoque físico (local='Estoque') pelo saldo coberto aberto
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

    -- 3b. Zerar reserva — novo sistema (quantidade_reservada na linha Estoque)
    --     usando o saldo aberto coberto real, nao a quantidade original do item.
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

    -- 3b-legado. Compatibilidade com reservas antigas em local='Reservado'
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

    -- 3b-saldo. Mover o saldo operacional do item para q_entregue (SPEC-010).
    --   Move tudo o que ainda estiver coberto e aberto (reserva + ag_separar +
    --   separado) para q_entregue. Entrega futura foi bloqueada acima.
    --   A granularidade por etapa
    --   (exigir separação antes de entregar) fica para o futuro fluxo de
    --   Logística/Estoque (EST-14/LOG-*); este trigger legado continua
    --   fechando o projeto inteiro de uma vez, como já fazia antes desta SPEC.
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

    -- 3c. Marcar sinal como 'creditado'
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
$$;
