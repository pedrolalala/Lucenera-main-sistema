-- Migration 20260701_013 — Parte 1
-- Corrige gerenciar_fluxo_projeto(): comparação NEW.status = 'Aprovado' lança
-- "invalid input value for enum projeto_status" porque 'Aprovado' e 'Estornado'
-- nunca foram adicionados ao enum projeto_status.
--
-- Fix: cast NEW.status::text antes de comparar com string literal.
-- Comportamento não muda (ramos 'Aprovado' e 'Estornado' nunca disparam),
-- mas o erro de cast é eliminado, permitindo qualquer UPDATE de status no banco.
--
-- Contexto: SPEC-005 removeu o fluxo de aprovação via trigger; a lógica de
-- aprovação agora vive em aprovar_orcamento_financeiro(). Os ramos 'Aprovado'
-- e 'Estornado' abaixo são código morto mantido apenas por compatibilidade histórica.

CREATE OR REPLACE FUNCTION public.gerenciar_fluxo_projeto()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_item               RECORD;
    v_estoque_disponivel NUMERIC;
    v_faltante           NUMERIC;
    v_acao               VARCHAR(20);
    v_usuario            VARCHAR(100);
BEGIN
    IF TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN

        -- Comparação via ::text para evitar erro de cast quando o literal
        -- não existe no enum projeto_status.
        IF NEW.status::text = 'Aprovado' THEN
            v_acao    := 'APROVACAO';
            v_usuario := NEW.aprovado_por;

            FOR v_item IN
                SELECT oi.id, oi.item_id, oi.quantidade, oi.orcamento_id
                FROM orcamento_itens oi
                JOIN orcamentos o ON o.id = oi.orcamento_id
                WHERE o.projeto_id = NEW.id
            LOOP
                INSERT INTO projeto_itens (projeto_id, item_id, quantidade, orcamento_item_id)
                VALUES (NEW.id, v_item.item_id, v_item.quantidade, v_item.id);

                SELECT COALESCE(quantidade, 0) - COALESCE(quantidade_reservada, 0)
                  INTO v_estoque_disponivel
                FROM estoque_itens
                WHERE id = v_item.item_id;

                IF v_estoque_disponivel >= v_item.quantidade THEN
                    UPDATE estoque_itens
                    SET quantidade_reservada = COALESCE(quantidade_reservada, 0) + v_item.quantidade
                    WHERE id = v_item.item_id;
                ELSE
                    IF v_estoque_disponivel > 0 THEN
                        UPDATE estoque_itens
                        SET quantidade_reservada = COALESCE(quantidade_reservada, 0) + v_estoque_disponivel
                        WHERE id = v_item.item_id;
                        v_faltante := v_item.quantidade - v_estoque_disponivel;
                    ELSE
                        v_faltante := v_item.quantidade;
                    END IF;

                    INSERT INTO solicitacoes_compra (projeto_id, item_id, quantidade, status, data_solicitacao)
                    VALUES (NEW.id, v_item.item_id, v_faltante, 'Pendente', NOW());
                END IF;
            END LOOP;

        ELSIF NEW.status::text = 'Estornado' THEN
            v_acao    := 'ESTORNO';
            v_usuario := NEW.estornado_por;

            FOR v_item IN
                SELECT id, item_id, quantidade
                FROM projeto_itens
                WHERE projeto_id = NEW.id
            LOOP
                UPDATE estoque_itens
                SET quantidade_reservada = GREATEST(COALESCE(quantidade_reservada, 0) - v_item.quantidade, 0)
                WHERE id = v_item.item_id;
            END LOOP;

            UPDATE solicitacoes_compra
            SET status = 'Cancelado', data_cancelamento = NOW()
            WHERE projeto_id = NEW.id AND status = 'Pendente';
        END IF;

        IF v_acao IS NOT NULL THEN
            INSERT INTO logs_operacoes (projeto_id, acao, usuario, data_hora)
            VALUES (NEW.id, v_acao, v_usuario, NOW());
        END IF;
    END IF;

    RETURN NEW;
END;
$$;
