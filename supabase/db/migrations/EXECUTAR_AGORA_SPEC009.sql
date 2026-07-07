-- ═══════════════════════════════════════════════════════════════════════════════
-- SPEC-009 — Aprovação do Cliente no Orçamento
-- Cole tudo no Supabase SQL Editor e clique em "Run"
-- ═══════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCO 1 — Novas colunas em orcamentos (idempotente)
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.orcamentos
    ADD COLUMN IF NOT EXISTS enviado_cliente_em      timestamptz,
    ADD COLUMN IF NOT EXISTS enviado_cliente_por     uuid REFERENCES auth.users(id),
    ADD COLUMN IF NOT EXISTS aprovado_cliente_em     timestamptz,
    ADD COLUMN IF NOT EXISTS recusado_cliente_em     timestamptz,
    ADD COLUMN IF NOT EXISTS motivo_recusa_cliente   text,
    ADD COLUMN IF NOT EXISTS token_aprovacao_cliente text;

CREATE UNIQUE INDEX IF NOT EXISTS uq_orcamentos_token_aprovacao_cliente
    ON public.orcamentos (token_aprovacao_cliente)
    WHERE token_aprovacao_cliente IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_orcamentos_token_aprovacao
    ON public.orcamentos (token_aprovacao_cliente)
    WHERE token_aprovacao_cliente IS NOT NULL;

COMMENT ON COLUMN public.orcamentos.enviado_cliente_em     IS 'Quando o orçamento foi enviado ao cliente pela última vez';
COMMENT ON COLUMN public.orcamentos.enviado_cliente_por    IS 'Usuário interno que enviou o orçamento ao cliente';
COMMENT ON COLUMN public.orcamentos.aprovado_cliente_em    IS 'Quando o cliente aprovou o orçamento';
COMMENT ON COLUMN public.orcamentos.recusado_cliente_em    IS 'Quando o cliente recusou o orçamento (mais recente)';
COMMENT ON COLUMN public.orcamentos.motivo_recusa_cliente  IS 'Motivo informado pelo cliente na recusa mais recente';
COMMENT ON COLUMN public.orcamentos.token_aprovacao_cliente IS 'Token de uso único para o link de aprovação do cliente';


-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCO 2 — RPC: enviar_orcamento_para_cliente
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.enviar_orcamento_para_cliente(
    p_orcamento_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
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


-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCO 3 — RPC: cliente_aprovar_orcamento
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.cliente_aprovar_orcamento(
    p_orcamento_id uuid,
    p_token        text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
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
    SET status                  = 'aprovado_cliente',
        aprovado_cliente_em     = now(),
        token_aprovacao_cliente = NULL
    WHERE id = p_orcamento_id;

    INSERT INTO public.historico_status_orcamentos (
        orcamento_id, status_anterior, status_novo, usuario, observacao
    ) VALUES (
        p_orcamento_id, 'enviado_cliente', 'aprovado_cliente',
        'cliente', 'Orçamento aprovado pelo cliente via link'
    );

    RETURN jsonb_build_object(
        'orcamento_id', p_orcamento_id,
        'numero',        v_numero,
        'status',        'aprovado_cliente',
        'aprovado_em',   now()
    );
END;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCO 4 — RPC: cliente_recusar_orcamento
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.cliente_recusar_orcamento(
    p_orcamento_id uuid,
    p_token        text,
    p_motivo       text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
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


-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCO 5 — RPC: adm_aprovar_pelo_cliente (aprovação manual / presencial)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.adm_aprovar_pelo_cliente(
    p_orcamento_id uuid,
    p_observacao   text DEFAULT 'Aprovação registrada manualmente pela administração'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
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

    IF v_orcamento.status NOT IN ('aguardando_aprovacao', 'enviado_cliente', 'recusado_cliente') THEN
        RAISE EXCEPTION
            'Não é possível registrar aprovação do cliente para orçamento % com status %.',
            v_numero, v_orcamento.status USING ERRCODE = 'P0002';
    END IF;

    UPDATE public.orcamentos
    SET status                  = 'aprovado_cliente',
        aprovado_cliente_em     = now(),
        token_aprovacao_cliente = NULL
    WHERE id = p_orcamento_id;

    INSERT INTO public.historico_status_orcamentos (
        orcamento_id, status_anterior, status_novo, usuario, observacao
    ) VALUES (
        p_orcamento_id, v_orcamento.status, 'aprovado_cliente',
        auth.uid()::text, p_observacao
    );

    RETURN jsonb_build_object(
        'orcamento_id', p_orcamento_id,
        'numero',        v_numero,
        'status',        'aprovado_cliente',
        'aprovado_em',   now(),
        'manual',        true
    );
END;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCO 6 — Guard em aprovar_orcamento_financeiro_base_spec001
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.aprovar_orcamento_financeiro_base_spec001(p_orcamento_id uuid)
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
  v_reservas_aplicadas integer := 0;
BEGIN
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

  -- ── GUARD SPEC-009 ────────────────────────────────────────────────────────
  IF v_orcamento.status NOT IN ('aprovado_cliente', 'aprovado') THEN
    RAISE EXCEPTION
      'Orçamento % não pode ser aprovado administrativamente: o cliente ainda não aprovou. '
      'Status atual: %. Use "Aprovação do Cliente" antes de prosseguir.',
      v_numero_orcamento, v_orcamento.status
      USING ERRCODE = 'P0003';
  END IF;
  -- ─────────────────────────────────────────────────────────────────────────

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
    SELECT 1 FROM public.orcamento_itens oi WHERE oi.orcamento_id = p_orcamento_id
  ) THEN
    RAISE EXCEPTION 'Orçamento % não possui itens.', v_numero_orcamento
      USING ERRCODE = 'P0001';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.orcamento_itens oi
    WHERE oi.orcamento_id = p_orcamento_id
      AND (coalesce(oi.quantidade, 0) <= 0 OR coalesce(oi.preco_unitario, 0) <= 0)
  ) THEN
    RAISE EXCEPTION 'Orçamento % possui item sem quantidade ou preço válido.', v_numero_orcamento
      USING ERRCODE = 'P0001';
  END IF;

  v_prazos       := public._lucenera_parse_prazo_pagamento(
                      v_orcamento.condicoes_pagamento,
                      v_orcamento.prazo_pagamento_dias);
  v_qtd_parcelas := coalesce(array_length(v_prazos, 1), 0);

  IF v_qtd_parcelas = 0 THEN
    RAISE EXCEPTION 'Orçamento % não possui prazo de pagamento interpretável. Edite o orçamento e informe o "Prazo para Início da Cobrança (dias)".', v_numero_orcamento
      USING ERRCODE = 'P0001';
  END IF;

  SELECT nome INTO v_cliente_nome FROM public.contatos WHERE id = v_orcamento.cliente_id;

  SELECT count(*) INTO v_itens_existentes    FROM public.projeto_itens    WHERE orcamento_id = p_orcamento_id;
  SELECT count(*) INTO v_parcelas_existentes FROM public.projeto_parcelas WHERE orcamento_id = p_orcamento_id;
  SELECT count(*) INTO v_boletos_existentes  FROM public.boletos           WHERE orcamento_id = p_orcamento_id;

  IF v_itens_existentes > 0 OR v_parcelas_existentes > 0 OR v_boletos_existentes > 0 THEN
    IF v_itens_existentes > 0
       AND v_parcelas_existentes = v_qtd_parcelas
       AND v_boletos_existentes  = v_qtd_parcelas THEN
      UPDATE public.orcamentos SET status = 'aprovado' WHERE id = p_orcamento_id;
      RETURN jsonb_build_object(
        'orcamento_id', p_orcamento_id, 'status', 'aprovado',
        'projeto_id', v_orcamento.projeto_id,
        'projeto_itens_criados', 0, 'parcelas_criadas', 0, 'boletos_criados', 0,
        'nota_fiscal_status', 'pendente_api', 'ja_processado', true
      );
    END IF;
    RAISE EXCEPTION
      'Orçamento % possui processamento parcial inconsistente: itens %, parcelas %, boletos %.',
      v_numero_orcamento, v_itens_existentes, v_parcelas_existentes, v_boletos_existentes
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.orcamentos SET status = 'aprovado' WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (
    orcamento_id, status_anterior, status_novo, usuario, observacao
  ) VALUES (
    p_orcamento_id, v_status_anterior, 'aprovado',
    auth.uid()::text, 'Aprovação integrada por aprovar_orcamento_financeiro'
  );

  INSERT INTO public.projeto_itens (
    projeto_id, produto_id, descricao, quantidade, preco_unitario, desconto, validado, orcamento_id
  )
  SELECT
    v_orcamento.projeto_id,
    oi.produto_id,
    coalesce(oi.descricao, (SELECT nome FROM public.produtos WHERE id = oi.produto_id), 'Item sem descrição'),
    coalesce(oi.quantidade, 1),
    coalesce(oi.preco_unitario, 0),
    coalesce(oi.desconto, 0),
    true,
    p_orcamento_id
  FROM public.orcamento_itens oi
  WHERE oi.orcamento_id = p_orcamento_id;
  GET DIAGNOSTICS v_itens_criados = ROW_COUNT;

  v_valor_total := v_orcamento.valor_total;
  v_valor_base  := round(v_valor_total / v_qtd_parcelas, 2);
  v_data_base   := current_date + coalesce(v_orcamento.prazo_inicio_cobranca_dias, 0);

  FOR v_i IN 1 .. v_qtd_parcelas LOOP
    v_valor_parcela   := CASE WHEN v_i < v_qtd_parcelas THEN v_valor_base
                              ELSE v_valor_total - v_valor_acumulado END;
    INSERT INTO public.projeto_parcelas (
      projeto_id, orcamento_id, numero_parcela, valor, data_vencimento, status, forma_pagamento
    ) VALUES (
      v_orcamento.projeto_id, p_orcamento_id, v_i, v_valor_parcela,
      v_data_base + v_prazos[v_i], 'pendente'::public.parcela_status, v_orcamento.forma_pagamento
    );
    v_valor_acumulado  := v_valor_acumulado + v_valor_parcela;
    v_parcelas_criadas := v_parcelas_criadas + 1;
  END LOOP;

  INSERT INTO public.boletos (
    orcamento_id, empresa_id, parcela_id, valor, vencimento,
    nome_pagador, numero_documento, status, tipo, nosso_numero
  )
  SELECT
    p_orcamento_id, v_orcamento.empresa_id, pp.id, pp.valor, pp.data_vencimento,
    v_cliente_nome,
    v_numero_orcamento || '-P' || pp.numero_parcela,
    'pendente_registro', 'Nota Fiscal',
    v_numero_orcamento || '-P' || pp.numero_parcela
  FROM public.projeto_parcelas pp
  WHERE pp.orcamento_id = p_orcamento_id;
  GET DIAGNOSTICS v_boletos_criados = ROW_COUNT;

  INSERT INTO public.estoque_itens (produto_id, local, quantidade, quantidade_reservada, atualizado_em)
  SELECT oi.produto_id, 'Estoque'::public.estoque_local, 0, coalesce(oi.quantidade, 0), now()
  FROM public.orcamento_itens oi
  WHERE oi.orcamento_id = p_orcamento_id
    AND oi.produto_id IS NOT NULL
    AND coalesce(oi.quantidade, 0) > 0
  ON CONFLICT (produto_id, local) DO UPDATE
    SET quantidade_reservada = public.estoque_itens.quantidade_reservada + EXCLUDED.quantidade_reservada,
        atualizado_em = now();
  GET DIAGNOSTICS v_reservas_aplicadas = ROW_COUNT;

  RETURN jsonb_build_object(
    'orcamento_id',               p_orcamento_id,
    'status',                     'aprovado',
    'projeto_id',                 v_orcamento.projeto_id,
    'projeto_itens_criados',      v_itens_criados,
    'parcelas_criadas',           v_parcelas_criadas,
    'boletos_criados',            v_boletos_criados,
    'reservas_estoque_aplicadas', v_reservas_aplicadas,
    'nota_fiscal_status',         'pendente_api',
    'ja_processado',              false
  );
END;
$function$;


-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCO 7 — Verificação de compatibilidade (rodar DEPOIS dos blocos acima)
-- Mostra orçamentos em 'aguardando_aprovacao' que ainda precisam de ação manual
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    o.numero,
    o.status,
    o.created_at::date AS criado_em,
    o.valor_total,
    count(pi.id) AS itens_projeto_vinculados
FROM public.orcamentos o
LEFT JOIN public.projeto_itens pi ON pi.orcamento_id = o.id
WHERE o.status NOT IN ('aprovado', 'cancelado')
GROUP BY o.id, o.numero, o.status, o.created_at, o.valor_total
ORDER BY o.created_at DESC;
