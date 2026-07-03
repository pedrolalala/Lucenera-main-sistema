-- Migration 20260630_010 — Parte 2
-- Adiciona reserva de estoque dentro da aprovação do orçamento.
--
-- Lógica nova (em negrito conceitual):
--   Após inserir projeto_itens, para cada item com produto_id não nulo,
--   incrementa estoque_itens.quantidade_reservada na linha (produto_id, 'Estoque').
--   Se a linha não existir, insere com quantidade=0 (saldo físico não muda) e
--   quantidade_reservada = qtd do item. Estoque negativo é permitido pela regra
--   de negócio (venda futura).
--
-- Idempotência:
--   A função já retorna cedo com ja_processado=true quando o triplo
--   (projeto_itens, parcelas, boletos) já existe. A reserva só roda na primeira
--   aprovação real. Não há risco de dupla reserva mesmo que a RPC seja chamada
--   duas vezes para o mesmo orçamento.
--
-- Relação com boletos/parcelas:
--   O orçamento define QUANTIDADE. Boletos definem VALOR e PARCELAS.
--   A reserva acontece uma única vez na aprovação, independente do número de
--   boletos (parcelas) gerados. Pagar ou não pagar o boleto não altera a reserva.

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
  v_numero_orcamento text;
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

  -- 7. Criar projeto_itens (snapshot dos itens aprovados)
  -- subtotal é coluna GENERATED ALWAYS — não inserir valor explícito.
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

  -- 8. Reservar estoque para cada produto aprovado.
  --    quantidade_reservada sobe; quantidade física não muda (o produto ainda
  --    não saiu do depósito). O sistema permite estoque negativo (venda futura):
  --    a linha pode já existir com qualquer quantidade e a reserva é somada.
  --    Itens sem produto_id (descrições livres) são silenciosamente ignorados.
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
    coalesce(oi.quantidade, 0),
    NOW()
  FROM public.orcamento_itens oi
  WHERE oi.orcamento_id = p_orcamento_id
    AND oi.produto_id IS NOT NULL
    AND coalesce(oi.quantidade, 0) > 0
  ON CONFLICT (produto_id, local) DO UPDATE
    SET quantidade_reservada = public.estoque_itens.quantidade_reservada
                               + EXCLUDED.quantidade_reservada,
        atualizado_em        = NOW();

  GET DIAGNOSTICS v_reservas_criadas = ROW_COUNT;

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
    'nota_fiscal_status',        'pendente_api',
    'ja_processado',             false
  );
END;
$function$;
