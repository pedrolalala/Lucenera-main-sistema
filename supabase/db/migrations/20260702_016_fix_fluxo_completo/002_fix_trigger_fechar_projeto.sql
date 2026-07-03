-- Migration 20260702_016 — Parte 2
-- Corrige trigger_fechar_projeto para zerar quantidade_reservada na entrega.
--
-- Bug original (passo 3b):
--   Tentava reduzir quantidade em linhas local='Reservado' (sistema legado).
--   O novo sistema guarda reserva em quantidade_reservada na linha local='Estoque'.
--   Resultado: após cada entrega, quantidade_reservada ficava inflada para sempre,
--   tornando qtd_disponivel cada vez mais subnotificada.
--
-- Correção:
--   3b-novo: decrementa quantidade_reservada na linha local='Estoque'
--   3b-legado: mantém o UPDATE em local='Reservado' para compatibilidade com dados antigos

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

    -- 3a. Baixar estoque físico (local='Estoque') — sem alteração
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
