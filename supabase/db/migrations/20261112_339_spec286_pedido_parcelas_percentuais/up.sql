-- SPEC-286: pedido de compra com parcelas de valores diferentes (sinal + resto).
-- Aditivo: coluna nova guarda o PERCENTUAL de cada parcela (na ordem das datas de condicoes_pagamento).
-- Sem percentuais (NULL) tudo segue como antes: partes iguais. O texto condicoes_pagamento nao muda
-- (PDF, Entrada de NF e e-mail continuam lendo as datas como sempre).
BEGIN;

ALTER TABLE public.pedidos_compra ADD COLUMN IF NOT EXISTS condicoes_percentuais numeric(7,4)[];
COMMENT ON COLUMN public.pedidos_compra.condicoes_percentuais IS
  'SPEC-286: % de cada parcela do pedido, na ordem das datas de condicoes_pagamento (soma 100). NULL = partes iguais.';

-- Grava/limpa os percentuais; mesma trava da edicao do pedido (SPEC-263) e so em "Aguardando aprovar".
CREATE OR REPLACE FUNCTION public.definir_percentuais_parcelas_pedido(p_pedido_id uuid, p_percentuais numeric[])
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
DECLARE v_status text; v_soma numeric;
BEGIN
  IF NOT hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar') THEN
    RAISE EXCEPTION 'Sem permissao para editar pedido de compra.' USING ERRCODE = '42501';
  END IF;
  SELECT status::text INTO v_status FROM public.pedidos_compra WHERE id = p_pedido_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Pedido de compra % nao encontrado.', p_pedido_id USING ERRCODE = 'P0001'; END IF;
  IF v_status <> 'aguardando_aprovar' THEN
    RAISE EXCEPTION 'So pedido em "Aguardando aprovar" pode mudar as parcelas.' USING ERRCODE = 'P0001';
  END IF;
  IF p_percentuais IS NULL OR coalesce(array_length(p_percentuais, 1), 0) = 0 THEN
    UPDATE public.pedidos_compra SET condicoes_percentuais = NULL WHERE id = p_pedido_id;
    RETURN;
  END IF;
  IF EXISTS (SELECT 1 FROM unnest(p_percentuais) x WHERE x IS NULL OR x <= 0 OR x > 100) THEN
    RAISE EXCEPTION 'Cada parcela precisa ter percentual entre 0 e 100.' USING ERRCODE = 'P0001';
  END IF;
  SELECT sum(x) INTO v_soma FROM unnest(p_percentuais) x;
  IF abs(v_soma - 100) > 0.01 THEN
    RAISE EXCEPTION 'A soma das parcelas precisa ser 100%% (esta %).', round(v_soma, 2) USING ERRCODE = 'P0001';
  END IF;
  UPDATE public.pedidos_compra SET condicoes_percentuais = p_percentuais::numeric(7,4)[] WHERE id = p_pedido_id;
END $f$;
REVOKE ALL ON FUNCTION public.definir_percentuais_parcelas_pedido(uuid, numeric[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.definir_percentuais_parcelas_pedido(uuid, numeric[]) TO authenticated;

-- Mesma funcao de hoje; so o valor de cada parcela muda quando ha percentuais com a mesma quantidade de datas.
CREATE OR REPLACE FUNCTION public.gerar_parcelas_pedido_compra(p_pedido_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_pedido          public.pedidos_compra%ROWTYPE;
    v_datas           date[];
    v_qtd_parcelas    integer;
    v_valor_base      numeric(12,2);
    v_valor_acumulado numeric(12,2) := 0;
    v_valor_parcela   numeric(12,2);
    v_i               integer;
    v_criadas         integer := 0;
    v_pct             numeric[];
BEGIN
    SELECT * INTO v_pedido FROM public.pedidos_compra WHERE id = p_pedido_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pedido de compra % nao encontrado.', p_pedido_id USING ERRCODE = 'P0001';
    END IF;

    IF v_pedido.valor_total IS NULL OR v_pedido.valor_total <= 0 THEN
        RAISE EXCEPTION 'Pedido % nao possui valor_total valido.', v_pedido.numero USING ERRCODE = 'P0001';
    END IF;

    -- SPEC-222 F9: pago antecipado (ja lancado no Contas a Pagar) nao gera previsao - evita saida em dobro
    IF lower(coalesce(v_pedido.condicoes_pagamento, '')) ~ 'antecipad' THEN
        RETURN jsonb_build_object('pedido_id', p_pedido_id, 'parcelas_criadas', 0, 'antecipado', true);
    END IF;

    -- SPEC-209 C1: dias ("30/60/90") contados da data do pedido, ou datas digitadas ("15/11, 15/12")
    v_datas := public._lucenera_datas_parcelas(
        v_pedido.condicoes_pagamento, v_pedido.prazo_pagamento_dias, COALESCE(v_pedido.data_emissao, CURRENT_DATE)
    );
    v_qtd_parcelas := COALESCE(array_length(v_datas, 1), 0);

    IF v_qtd_parcelas = 0 THEN
        RAISE EXCEPTION 'Nao foi possivel interpretar condicoes_pagamento/prazo_pagamento_dias do pedido %.', v_pedido.numero
            USING ERRCODE = 'P0001';
    END IF;

    -- Idempotente: nao duplica se ja houver parcelas geradas
    IF EXISTS (SELECT 1 FROM public.pedido_compra_parcelas WHERE pedido_id = p_pedido_id) THEN
        RAISE EXCEPTION 'Pedido % ja possui parcelas geradas.', v_pedido.numero USING ERRCODE = 'P0001';
    END IF;

    -- SPEC-286: percentuais por parcela (sinal + resto) so valem se baterem com a quantidade de datas
    v_pct := v_pedido.condicoes_percentuais;
    IF v_pct IS NOT NULL AND coalesce(array_length(v_pct, 1), 0) <> v_qtd_parcelas THEN
        v_pct := NULL;
    END IF;

    v_valor_base := round(v_pedido.valor_total / v_qtd_parcelas, 2);

    FOR v_i IN 1..v_qtd_parcelas LOOP
        v_valor_parcela := CASE
            WHEN v_i = v_qtd_parcelas THEN v_pedido.valor_total - v_valor_acumulado
            WHEN v_pct IS NOT NULL THEN round(v_pedido.valor_total * v_pct[v_i] / 100, 2)
            ELSE v_valor_base
        END;

        INSERT INTO public.pedido_compra_parcelas (
            pedido_id, numero_parcela, valor, data_vencimento, status
        ) VALUES (
            p_pedido_id, v_i, v_valor_parcela,
            v_datas[v_i],
            'pendente'
        );

        v_valor_acumulado := v_valor_acumulado + v_valor_parcela;
        v_criadas := v_criadas + 1;
    END LOOP;

    RETURN jsonb_build_object('pedido_id', p_pedido_id, 'parcelas_criadas', v_criadas);
END;
$function$;

COMMIT;
