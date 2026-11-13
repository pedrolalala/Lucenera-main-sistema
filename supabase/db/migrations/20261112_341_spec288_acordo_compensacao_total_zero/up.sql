-- SPEC-288 (item B): acordo de total ZERO = compensacao (ex.: devolucao -2.640,95 + aquisicao 2.640,95 do mesmo cliente).
-- Mesma assinatura da financeiro_criar_acordo (migration 340): com p_novo_plano vazio/nulo e total das parcelas = 0,
-- as parcelas se anulam: as positivas recebem baixa tipo 'compensacao' (nao mexe em caixa), todas ficam 'renegociada'
-- e ligadas por financeiro_renegociacoes (negativa -> positiva) no mesmo grupo_acordo. Nao nasce titulo novo.
-- Com plano informado, tudo segue como na 340, mas total <= 0 e recusado (sobra de credito ainda sem regra: decisao do usuario).
BEGIN;

CREATE OR REPLACE FUNCTION public.financeiro_criar_acordo(
    p_parcelas uuid[],
    p_novo_plano jsonb,
    p_desconto numeric DEFAULT 0,
    p_motivo text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
DECLARE
    v_ids uuid[]; v_n int; v_par public.financeiro_parcelas; v_tit public.financeiro_titulos; v_first public.financeiro_titulos;
    v_grupo int; v_novo uuid; v_total_orig numeric := 0; v_total_novo numeric := 0; v_desc numeric := coalesce(p_desconto, 0);
    v_desc_rest numeric; v_d numeric; v_i int := 0; v_el jsonb; v_pn uuid; v_novas uuid[] := ARRAY[]::uuid[]; v_m int;
    v_titulos uuid[] := ARRAY[]::uuid[]; v_projetos uuid[] := ARRAY[]::uuid[]; v_plano uuid; v_com_boleto int := 0;
    v_comp boolean; v_neg uuid[] := ARRAY[]::uuid[]; v_pos uuid[] := ARRAY[]::uuid[];
BEGIN
    IF length(btrim(coalesce(p_motivo, ''))) = 0 THEN RAISE EXCEPTION 'Informe o motivo do acordo.' USING ERRCODE = 'P0001'; END IF;
    SELECT array_agg(DISTINCT x) INTO v_ids FROM unnest(coalesce(p_parcelas, ARRAY[]::uuid[])) x;
    v_n := coalesce(array_length(v_ids, 1), 0);
    IF v_n = 0 THEN RAISE EXCEPTION 'Selecione ao menos uma parcela para o acordo.' USING ERRCODE = 'P0001'; END IF;
    v_comp := p_novo_plano IS NULL OR jsonb_typeof(p_novo_plano) <> 'array' OR jsonb_array_length(p_novo_plano) = 0;
    IF v_desc < 0 THEN RAISE EXCEPTION 'Desconto nao pode ser negativo.' USING ERRCODE = 'P0001'; END IF;

    FOR v_par IN SELECT * FROM public.financeiro_parcelas WHERE id = ANY (v_ids) ORDER BY vencimento, numero, id FOR UPDATE LOOP
        SELECT * INTO v_tit FROM public.financeiro_titulos WHERE id = v_par.titulo_id;
        PERFORM public.financeiro_exige(v_tit.especie);
        IF v_first.id IS NULL THEN v_first := v_tit; END IF;
        IF v_tit.cancelado_em IS NOT NULL THEN RAISE EXCEPTION 'Titulo cancelado na selecao.' USING ERRCODE = 'P0001'; END IF;
        IF v_par.situacao <> 'firme' THEN
            RAISE EXCEPTION 'So parcela firme entra em acordo (parcela % esta %).', v_par.numero, v_par.situacao USING ERRCODE = 'P0001';
        END IF;
        IF v_par.valor_liquidado <> 0 THEN
            RAISE EXCEPTION 'Parcela % ja tem baixa: deixe fora do acordo ou estorne a baixa antes.', v_par.numero USING ERRCODE = 'P0001';
        END IF;
        IF v_tit.natureza <> v_first.natureza OR v_tit.contato_id IS DISTINCT FROM v_first.contato_id
           OR v_tit.empresa_id IS DISTINCT FROM v_first.empresa_id THEN
            RAISE EXCEPTION 'As parcelas do acordo precisam ser da mesma pessoa, empresa e tipo (a pagar ou a receber).' USING ERRCODE = 'P0001';
        END IF;
        v_total_orig := v_total_orig + v_par.valor;
        IF v_par.valor < 0 THEN v_neg := v_neg || v_par.id; ELSIF v_par.valor > 0 THEN v_pos := v_pos || v_par.id; END IF;
        IF NOT v_tit.id = ANY (v_titulos) THEN v_titulos := v_titulos || v_tit.id; END IF;
        IF v_tit.projeto_id IS NOT NULL AND NOT v_tit.projeto_id = ANY (v_projetos) THEN v_projetos := v_projetos || v_tit.projeto_id; END IF;
        IF v_plano IS NULL AND v_tit.plano_contas_id IS NOT NULL THEN v_plano := v_tit.plano_contas_id; END IF;
        IF EXISTS (SELECT 1 FROM public.financeiro_cobrancas c WHERE c.parcela_id = v_par.id) THEN v_com_boleto := v_com_boleto + 1; END IF;
        v_m := coalesce(v_m, 0) + 1;
    END LOOP;
    IF coalesce(v_m, 0) <> v_n THEN RAISE EXCEPTION 'Parcela inexistente na selecao.' USING ERRCODE = 'P0001'; END IF;

    -- ===== compensacao (sem plano novo): as parcelas se anulam =====
    IF v_comp THEN
        IF abs(v_total_orig) > 0.01 THEN
            RAISE EXCEPTION 'Informe as parcelas novas: o total das parcelas e %, nao zero.', round(v_total_orig, 2) USING ERRCODE = 'P0001';
        END IF;
        IF v_desc <> 0 THEN RAISE EXCEPTION 'Compensacao nao tem desconto.' USING ERRCODE = 'P0001'; END IF;
        IF coalesce(array_length(v_neg, 1), 0) = 0 OR coalesce(array_length(v_pos, 1), 0) = 0 THEN
            RAISE EXCEPTION 'Compensacao precisa de ao menos uma parcela negativa (devolucao) e uma positiva.' USING ERRCODE = 'P0001';
        END IF;
        v_grupo := nextval('public.seq_financeiro_acordo');
        FOR v_par IN SELECT * FROM public.financeiro_parcelas WHERE id = ANY (v_ids) ORDER BY vencimento, numero, id LOOP
            IF v_par.valor > 0 THEN
                INSERT INTO public.financeiro_baixas (parcela_id, tipo, data, valor, motivo, origem_baixa, criado_por)
                VALUES (v_par.id, 'compensacao', current_date, v_par.valor, 'Compensacao do acordo ' || v_grupo || ': ' || btrim(p_motivo), 'manual', auth.uid());
            END IF;
            UPDATE public.financeiro_parcelas SET situacao = 'renegociada', observacao = coalesce(observacao || ' | ', '') || 'Compensada no acordo ' || v_grupo WHERE id = v_par.id;
        END LOOP;
        INSERT INTO public.financeiro_renegociacoes (parcela_origem_id, parcela_nova_id, grupo_acordo, criado_por)
        SELECT n, p, v_grupo, auth.uid() FROM unnest(v_neg) n CROSS JOIN unnest(v_pos) p;
        RETURN jsonb_build_object('grupo_acordo', v_grupo, 'titulo_id', NULL, 'parcelas_novas', 0, 'parcelas_origem', v_n,
                                  'com_boleto_emitido', v_com_boleto, 'compensacao', true);
    END IF;

    -- ===== acordo com plano novo (como na 340) =====
    IF v_total_orig <= 0 THEN
        RAISE EXCEPTION 'O total das parcelas e % (zero ou negativo): para anular devolucao com aquisicao use a compensacao (sem parcelas novas).', round(v_total_orig, 2) USING ERRCODE = 'P0001';
    END IF;
    IF v_plano IS NULL THEN RAISE EXCEPTION 'Nenhum titulo da selecao tem plano de contas: defina o plano antes do acordo.' USING ERRCODE = 'P0001'; END IF;
    IF v_desc >= v_total_orig THEN RAISE EXCEPTION 'Desconto precisa ser menor que o total das parcelas.' USING ERRCODE = 'P0001'; END IF;

    FOR v_el IN SELECT * FROM jsonb_array_elements(p_novo_plano) LOOP
        IF (v_el->>'vencimento') IS NULL OR coalesce((v_el->>'valor')::numeric, 0) <= 0 THEN
            RAISE EXCEPTION 'Toda parcela nova precisa de vencimento e valor maior que zero.' USING ERRCODE = 'P0001';
        END IF;
        v_total_novo := v_total_novo + (v_el->>'valor')::numeric;
    END LOOP;
    IF abs((v_total_orig - v_desc) - v_total_novo) > 0.01 THEN
        RAISE EXCEPTION 'A soma do acordo (%) precisa ser igual ao total das parcelas (%) menos o desconto (%).',
            round(v_total_novo, 2), round(v_total_orig, 2), round(v_desc, 2) USING ERRCODE = 'P0001';
    END IF;

    v_grupo := nextval('public.seq_financeiro_acordo');

    INSERT INTO public.financeiro_titulos (natureza, origem_tipo, especie, empresa_id, perfil, contato_id, plano_contas_id, projeto_id,
                                           documento, descricao, substitui_titulo_id, criado_por)
    VALUES (v_first.natureza, 'manual', v_first.especie, v_first.empresa_id, v_first.perfil, v_first.contato_id, v_plano,
            CASE WHEN array_length(v_projetos, 1) = 1 THEN v_projetos[1] END,
            'ACORDO-' || v_grupo, 'Acordo ' || v_grupo || ': ' || btrim(p_motivo),
            CASE WHEN array_length(v_titulos, 1) = 1 THEN v_titulos[1] END, auth.uid())
    RETURNING id INTO v_novo;

    FOR v_el IN SELECT * FROM jsonb_array_elements(p_novo_plano) LOOP
        v_i := v_i + 1;
        INSERT INTO public.financeiro_parcelas (titulo_id, numero, vencimento, valor, situacao, confirmada_em, confirmada_por, forma_prevista, emissao, observacao, criado_por)
        VALUES (v_novo, v_i, (v_el->>'vencimento')::date, (v_el->>'valor')::numeric, 'firme', now(), auth.uid(), nullif(v_el->>'forma', ''),
                current_date, 'Acordo ' || v_grupo, auth.uid())
        RETURNING id INTO v_pn;
        v_novas := v_novas || v_pn;
    END LOOP;

    v_desc_rest := v_desc; v_i := 0;
    FOR v_par IN SELECT * FROM public.financeiro_parcelas WHERE id = ANY (v_ids) ORDER BY vencimento, numero, id LOOP
        v_i := v_i + 1;
        v_d := CASE WHEN v_i = v_n THEN v_desc_rest ELSE round(v_desc * v_par.valor / v_total_orig, 2) END;
        v_desc_rest := v_desc_rest - v_d;
        IF v_par.valor - v_d > 0 THEN
            INSERT INTO public.financeiro_baixas (parcela_id, tipo, data, valor, motivo, origem_baixa, criado_por)
            VALUES (v_par.id, 'renegociacao', current_date, v_par.valor - v_d, 'Acordo ' || v_grupo || ': ' || btrim(p_motivo), 'manual', auth.uid());
        END IF;
        IF v_d > 0 THEN
            INSERT INTO public.financeiro_baixas (parcela_id, tipo, data, valor, desconto, motivo, origem_baixa, criado_por)
            VALUES (v_par.id, 'abatimento', current_date, v_d, v_d, 'Desconto do acordo ' || v_grupo || ': ' || btrim(p_motivo), 'manual', auth.uid());
        END IF;
        UPDATE public.financeiro_parcelas SET situacao = 'renegociada' WHERE id = v_par.id;
        INSERT INTO public.financeiro_renegociacoes (parcela_origem_id, parcela_nova_id, grupo_acordo, criado_por)
        SELECT v_par.id, x, v_grupo, auth.uid() FROM unnest(v_novas) x;
    END LOOP;

    RETURN jsonb_build_object('grupo_acordo', v_grupo, 'titulo_id', v_novo, 'parcelas_novas', array_length(v_novas, 1),
                              'parcelas_origem', v_n, 'com_boleto_emitido', v_com_boleto);
END $f$;

REVOKE ALL ON FUNCTION public.financeiro_criar_acordo(uuid[], jsonb, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.financeiro_criar_acordo(uuid[], jsonb, numeric, text) TO authenticated;

COMMIT;
