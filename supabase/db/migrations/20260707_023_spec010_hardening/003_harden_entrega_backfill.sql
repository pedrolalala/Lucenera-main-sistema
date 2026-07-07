-- Migration 20260707_023 - Parte 3
-- SPEC-010 hardening: impede entrega direta de q_entrega_futura e ajusta
-- trigger_fechar_projeto para usar o saldo aberto coberto real.

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

    -- 3a. Baixar estoque fisico (local='Estoque') pelo saldo coberto aberto
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

    -- 3b. Zerar reserva usando o saldo aberto coberto real, nao a quantidade
    --     original do item.
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

    -- 3b-legado. Compatibilidade com reservas antigas em local='Reservado'.
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

    -- 3b-saldo. Mover para q_entregue somente o saldo coberto aberto.
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

    -- 3c. Marcar sinal como 'creditado'.
    UPDATE projeto_sinal
    SET status     = 'creditado'::public.sinal_status,
        updated_at = NOW()
    WHERE projeto_id = NEW.id
      AND status = 'recebido'::public.sinal_status;

    -- 3d. Criar separacao automaticamente com os itens validados.
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

-- Guard rail de backfill: a migration 20260706_022 foi ajustada localmente
-- para auditar apenas linhas inseridas no proprio backfill. Como o banco real
-- ja recebeu o backfill, esta etapa apenas falha se houver duplicidade que
-- precise de limpeza manual antes de prosseguir.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.estoque_movimentos_projeto_item
    WHERE origem = 'backfill_spec010'
    GROUP BY projeto_item_id
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION
      'Backfill SPEC-010 possui movimentos duplicados. Revisar antes de concluir hardening.';
  END IF;
END;
$$;
