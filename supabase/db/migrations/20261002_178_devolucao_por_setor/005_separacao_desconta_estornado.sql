-- SPEC-178: os 3 triggers que andam a separação (Pronto -> separado,
-- finalizado/Entregue -> entregue) passam a mover só a quantidade NÃO estornada
-- (quantidade - quantidade_estornada). Sem isso, devolver material "em
-- separação" (que marca quantidade_estornada) — e também o estorno parcial que
-- já existia (estornar_item_separacao) — fazia a finalização mover a quantidade
-- cheia de novo, contando em dobro e estourando fn_validar_saldo_projeto_item.
-- Resto idêntico às versões em produção em 02/10/2026.

CREATE OR REPLACE FUNCTION public.sync_separado_ao_ficar_pronto()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_item record;
BEGIN
    IF NEW.status = 'Pronto' AND (OLD.status IS DISTINCT FROM NEW.status) THEN
        FOR v_item IN
            SELECT id, projeto_item_id, quantidade - quantidade_estornada AS quantidade
            FROM public.separacao_itens
            WHERE separacao_id = NEW.id
              AND projeto_item_id IS NOT NULL
              AND NOT separado
              AND quantidade > quantidade_estornada
        LOOP
            UPDATE public.estoque_saldos_projeto_item
            SET q_ag_separar = GREATEST(q_ag_separar - v_item.quantidade, 0),
                q_separado = q_separado + v_item.quantidade,
                atualizado_em = now()
            WHERE projeto_item_id = v_item.projeto_item_id;

            UPDATE public.separacao_itens SET separado = true WHERE id = v_item.id;

            INSERT INTO public.estoque_movimentos_projeto_item
                (projeto_item_id, tipo, quantidade, origem, referencia_id, criado_por)
            VALUES
                (v_item.projeto_item_id, 'separado', v_item.quantidade, 'separacao_parcial', NEW.id, auth.uid());
        END LOOP;
    END IF;
    RETURN NEW;
END;
$function$;

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

            INSERT INTO public.estoque_movimentos_projeto_item
                (projeto_item_id, tipo, quantidade, origem, referencia_id, criado_por)
            VALUES
                (v_item.projeto_item_id, 'entregue', v_item.quantidade, 'separacao_parcial', NEW.id, auth.uid());
        END LOOP;
    END IF;
    RETURN NEW;
END;
$function$;

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
            SELECT projeto_item_id, quantidade - quantidade_estornada AS quantidade
            FROM public.separacao_itens
            WHERE separacao_id = NEW.separacao_id
              AND projeto_item_id IS NOT NULL
              AND quantidade > quantidade_estornada
        LOOP
            UPDATE public.estoque_saldos_projeto_item
            SET q_separado = GREATEST(q_separado - v_item.quantidade, 0),
                q_entregue = q_entregue + v_item.quantidade,
                atualizado_em = now()
            WHERE projeto_item_id = v_item.projeto_item_id;

            INSERT INTO public.estoque_movimentos_projeto_item
                (projeto_item_id, tipo, quantidade, origem, referencia_id, criado_por)
            VALUES
                (v_item.projeto_item_id, 'entregue', v_item.quantidade, 'entrega', NEW.id, auth.uid());
        END LOOP;
    END IF;
    RETURN NEW;
END;
$function$;

NOTIFY pgrst, 'reload schema';
