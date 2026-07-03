-- ═══════════════════════════════════════════════════════════════════════════════
-- EXECUTAR ESTE ARQUIVO COMPLETO NO SUPABASE SQL EDITOR
-- Cole tudo e clique em "Run"
-- ═══════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCO 1 — Remove triggers legados que conflitam com o novo sistema
-- ─────────────────────────────────────────────────────────────────────────────
DROP TRIGGER  IF EXISTS trg_reserva_estoque        ON public.projetos;
DROP TRIGGER  IF EXISTS trg_gerenciar_fluxo_projeto ON public.projetos;
DROP FUNCTION IF EXISTS public.trigger_reserva_estoque();
DROP FUNCTION IF EXISTS public.gerenciar_fluxo_projeto();


-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCO 2 — Corrige trigger_fechar_projeto:
--           passo 3b agora zera quantidade_reservada (novo sistema)
--           ao invés de tentar reduzir linha local='Reservado' (legado)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.trigger_fechar_projeto()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_sinal RECORD;
BEGIN
  IF NEW.status = 'Entrega materiais'::public.projeto_status
     AND OLD.status <> 'Entrega materiais'::public.projeto_status THEN

    -- 3a. Baixar estoque físico
    UPDATE estoque_itens ei
    SET quantidade    = GREATEST(0, ei.quantidade - pi.quantidade),
        atualizado_em = NOW()
    FROM projeto_itens pi
    WHERE pi.projeto_id = NEW.id
      AND pi.produto_id = ei.produto_id
      AND ei.local = 'Estoque'::public.estoque_local;

    -- 3b. Zerar reserva — novo sistema (quantidade_reservada na linha Estoque)
    UPDATE estoque_itens ei
    SET quantidade_reservada = GREATEST(0, ei.quantidade_reservada - pi.quantidade),
        atualizado_em        = NOW()
    FROM projeto_itens pi
    WHERE pi.projeto_id = NEW.id
      AND pi.produto_id = ei.produto_id
      AND ei.local = 'Estoque'::public.estoque_local;

    -- 3b-legado. Compatibilidade com reservas antigas em local='Reservado'
    UPDATE estoque_itens ei
    SET quantidade    = GREATEST(0, ei.quantidade - pi.quantidade),
        atualizado_em = NOW()
    FROM projeto_itens pi
    WHERE pi.projeto_id = NEW.id
      AND pi.produto_id = ei.produto_id
      AND ei.local = 'Reservado'::public.estoque_local;

    -- 3c. Marcar sinal como creditado
    UPDATE projeto_sinal
    SET status     = 'creditado'::public.sinal_status,
        updated_at = NOW()
    WHERE projeto_id = NEW.id
      AND status = 'recebido'::public.sinal_status;

    -- 3d. Criar separação automaticamente
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
      SELECT nova_sep.id, pi.produto_id, pi.descricao, pi.quantidade, NULL
      FROM projeto_itens pi, nova_sep
      WHERE pi.projeto_id = NEW.id
        AND pi.validado = true;
    END IF;

  END IF;
  RETURN NEW;
END;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCO 3 — Atualiza cancelar_orcamento:
--           ao cancelar orçamento aprovado também cancela parcelas,
--           boletos e invalida projeto_itens
-- ─────────────────────────────────────────────────────────────────────────────
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

    IF v_status_anterior = 'cancelado' THEN
        RETURN jsonb_build_object(
            'orcamento_id', p_orcamento_id, 'numero', v_numero_orcamento,
            'status', 'cancelado', 'ja_cancelado', true,
            'reservas_revertidas', 0, 'parcelas_canceladas', 0,
            'boletos_cancelados', 0, 'itens_invalidados', 0
        );
    END IF;

    IF v_status_anterior = 'aprovado' THEN

        -- reverter reservas de estoque
        UPDATE public.estoque_itens ei
        SET quantidade_reservada = GREATEST(0, ei.quantidade_reservada - oi.quantidade),
            atualizado_em        = NOW()
        FROM public.orcamento_itens oi
        WHERE oi.orcamento_id = p_orcamento_id
          AND oi.produto_id   IS NOT NULL
          AND coalesce(oi.quantidade, 0) > 0
          AND ei.produto_id   = oi.produto_id
          AND ei.local        = 'Estoque'::public.estoque_local;
        GET DIAGNOSTICS v_reservas_revertidas = ROW_COUNT;

        -- cancelar parcelas
        UPDATE public.projeto_parcelas
        SET status = 'cancelada'::public.parcela_status
        WHERE orcamento_id = p_orcamento_id
          AND status = 'pendente'::public.parcela_status;
        GET DIAGNOSTICS v_parcelas_canceladas = ROW_COUNT;

        -- cancelar boletos
        UPDATE public.boletos
        SET status = 'cancelado'
        WHERE orcamento_id = p_orcamento_id
          AND status IN ('pendente_registro', 'Pendente', 'pendente');
        GET DIAGNOSTICS v_boletos_cancelados = ROW_COUNT;

        -- invalidar projeto_itens (soft — preserva auditoria)
        UPDATE public.projeto_itens
        SET validado = false
        WHERE orcamento_id = p_orcamento_id
          AND validado = true;
        GET DIAGNOSTICS v_itens_invalidados = ROW_COUNT;

    END IF;

    UPDATE public.orcamentos SET status = 'cancelado' WHERE id = p_orcamento_id;

    INSERT INTO public.historico_status_orcamentos (
        orcamento_id, status_anterior, status_novo, usuario, observacao
    ) VALUES (
        p_orcamento_id, v_status_anterior, 'cancelado',
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
        'ja_cancelado',        false
    );
END;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCO 4 — BACKFILL: cria quantidade_reservada para os orçamentos aprovados
--           que foram aprovados ANTES desta correção existir.
--           Exclui projetos já entregues/finalizados (estoque físico já baixado).
-- ─────────────────────────────────────────────────────────────────────────────
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
    0,                              -- não altera o saldo físico
    COALESCE(oi.quantidade, 0),
    NOW()
FROM public.orcamento_itens oi
JOIN public.orcamentos o ON o.id = oi.orcamento_id
JOIN public.projetos   p ON p.id = o.projeto_id
WHERE o.status = 'aprovado'
  AND oi.produto_id IS NOT NULL
  AND COALESCE(oi.quantidade, 0) > 0
  AND p.status::text NOT IN (
      'Obra Finalizada', 'Finalizado',
      'Entrega materiais', 'Ajustes finais'
  )
ON CONFLICT (produto_id, local) DO UPDATE
    SET quantidade_reservada = public.estoque_itens.quantidade_reservada
                               + EXCLUDED.quantidade_reservada,
        atualizado_em        = NOW();


-- ─────────────────────────────────────────────────────────────────────────────
-- VERIFICAÇÃO FINAL — rode depois e confira o resultado
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    pr.nome                         AS produto,
    o.numero                        AS orcamento,
    proj.codigo                     AS projeto,
    proj.status::text               AS status_projeto,
    oi.quantidade                   AS qtd_reservada_esperada,
    ei.quantidade                   AS fisico,
    ei.quantidade_reservada         AS reservado,
    ei.quantidade - ei.quantidade_reservada AS disponivel
FROM public.orcamento_itens oi
JOIN public.orcamentos   o    ON o.id    = oi.orcamento_id
JOIN public.projetos     proj ON proj.id = o.projeto_id
JOIN public.produtos     pr   ON pr.id   = oi.produto_id
LEFT JOIN public.estoque_itens ei
       ON ei.produto_id = oi.produto_id
      AND ei.local = 'Estoque'::public.estoque_local
WHERE o.status = 'aprovado'
ORDER BY o.numero, pr.nome;
