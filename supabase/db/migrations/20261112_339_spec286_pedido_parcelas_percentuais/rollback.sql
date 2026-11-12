-- SPEC-286 rollback: volta a funcao para partes iguais e remove a coluna/RPC.
BEGIN;
CREATE OR REPLACE FUNCTION public.gerar_parcelas_pedido_compra(p_pedido_id uuid)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
    v_pedido public.pedidos_compra%ROWTYPE; v_datas date[]; v_qtd_parcelas integer; v_valor_base numeric(12,2);
    v_valor_acumulado numeric(12,2) := 0; v_valor_parcela numeric(12,2); v_i integer; v_criadas integer := 0;
BEGIN
    SELECT * INTO v_pedido FROM public.pedidos_compra WHERE id = p_pedido_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Pedido de compra % nao encontrado.', p_pedido_id USING ERRCODE = 'P0001'; END IF;
    IF v_pedido.valor_total IS NULL OR v_pedido.valor_total <= 0 THEN
        RAISE EXCEPTION 'Pedido % nao possui valor_total valido.', v_pedido.numero USING ERRCODE = 'P0001'; END IF;
    IF lower(coalesce(v_pedido.condicoes_pagamento, '')) ~ 'antecipad' THEN
        RETURN jsonb_build_object('pedido_id', p_pedido_id, 'parcelas_criadas', 0, 'antecipado', true); END IF;
    v_datas := public._lucenera_datas_parcelas(v_pedido.condicoes_pagamento, v_pedido.prazo_pagamento_dias, COALESCE(v_pedido.data_emissao, CURRENT_DATE));
    v_qtd_parcelas := COALESCE(array_length(v_datas, 1), 0);
    IF v_qtd_parcelas = 0 THEN
        RAISE EXCEPTION 'Nao foi possivel interpretar condicoes_pagamento/prazo_pagamento_dias do pedido %.', v_pedido.numero USING ERRCODE = 'P0001'; END IF;
    IF EXISTS (SELECT 1 FROM public.pedido_compra_parcelas WHERE pedido_id = p_pedido_id) THEN
        RAISE EXCEPTION 'Pedido % ja possui parcelas geradas.', v_pedido.numero USING ERRCODE = 'P0001'; END IF;
    v_valor_base := round(v_pedido.valor_total / v_qtd_parcelas, 2);
    FOR v_i IN 1..v_qtd_parcelas LOOP
        v_valor_parcela := CASE WHEN v_i < v_qtd_parcelas THEN v_valor_base ELSE v_pedido.valor_total - v_valor_acumulado END;
        INSERT INTO public.pedido_compra_parcelas (pedido_id, numero_parcela, valor, data_vencimento, status)
        VALUES (p_pedido_id, v_i, v_valor_parcela, v_datas[v_i], 'pendente');
        v_valor_acumulado := v_valor_acumulado + v_valor_parcela; v_criadas := v_criadas + 1;
    END LOOP;
    RETURN jsonb_build_object('pedido_id', p_pedido_id, 'parcelas_criadas', v_criadas);
END; $function$;
DROP FUNCTION IF EXISTS public.definir_percentuais_parcelas_pedido(uuid, numeric[]);
ALTER TABLE public.pedidos_compra DROP COLUMN IF EXISTS condicoes_percentuais;
COMMIT;
