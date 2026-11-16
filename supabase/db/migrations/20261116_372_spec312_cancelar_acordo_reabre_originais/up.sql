-- SPEC-312: cancelar o titulo/parcela de um ACORDO reabre as parcelas originais.
-- Antes: a parcela nova do acordo ia para 'cancelada', mas as originais ficavam 'renegociada' (baixa 'renegociacao' + abatimento)
-- para sempre: sem saldo, fora da lista e fora de um novo acordo (caso ORC-0041/ORC-0042, acordo 3, 16/11/2026).
-- Agora, quando a ULTIMA parcela aberta de um grupo de acordo e cancelada, as originais voltam a 'firme' e as baixas do acordo
-- (renegociacao/abatimento) sao ESTORNADAS (baixa e imutavel: o historico fica). Gatilho, para valer em cancelar_parcela e cancelar_titulo.
BEGIN;

CREATE OR REPLACE FUNCTION public.financeiro_acordo_cancelado_reabre_originais()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
DECLARE
    v_grupo int; v_orig uuid; v_b public.financeiro_baixas;
BEGIN
    FOR v_grupo IN SELECT DISTINCT grupo_acordo FROM public.financeiro_renegociacoes WHERE parcela_nova_id = NEW.id LOOP
        -- ainda ha parcela aberta no acordo: so reabre quando a ultima for cancelada
        IF EXISTS (SELECT 1 FROM public.financeiro_renegociacoes r JOIN public.financeiro_parcelas p ON p.id = r.parcela_nova_id
                    WHERE r.grupo_acordo = v_grupo AND p.id <> NEW.id AND p.situacao IN ('prevista', 'firme')) THEN
            CONTINUE;
        END IF;
        -- acordo de compensacao (sem parcela nova de verdade): as "novas" sao as proprias originais, nao se desfaz por aqui
        IF NOT EXISTS (SELECT 1 FROM public.financeiro_renegociacoes r JOIN public.financeiro_parcelas po ON po.id = r.parcela_origem_id
                        WHERE r.grupo_acordo = v_grupo AND r.parcela_nova_id = NEW.id AND po.situacao = 'renegociada') THEN
            CONTINUE;
        END IF;
        FOR v_orig IN SELECT DISTINCT r.parcela_origem_id FROM public.financeiro_renegociacoes r WHERE r.grupo_acordo = v_grupo LOOP
            -- precisa voltar a firme ANTES do estorno (baixa so entra em parcela firme)
            UPDATE public.financeiro_parcelas SET situacao = 'firme'
             WHERE id = v_orig AND situacao = 'renegociada';
            FOR v_b IN
                SELECT b.* FROM public.financeiro_baixas b
                 WHERE b.parcela_id = v_orig AND b.tipo IN ('renegociacao', 'abatimento')
                   AND (b.motivo LIKE 'Acordo ' || v_grupo || ':%' OR b.motivo LIKE 'Desconto do acordo ' || v_grupo || ':%')
                   AND NOT EXISTS (SELECT 1 FROM public.financeiro_baixas e WHERE e.estorno_de = b.id)
            LOOP
                INSERT INTO public.financeiro_baixas (parcela_id, tipo, data, valor, motivo, origem_baixa, estorno_de, criado_por)
                VALUES (v_orig, 'estorno', current_date, v_b.valor, 'Acordo ' || v_grupo || ' cancelado: parcela original reaberta', 'manual', v_b.id, auth.uid());
            END LOOP;
        END LOOP;
    END LOOP;
    RETURN NULL;
END $f$;

REVOKE ALL ON FUNCTION public.financeiro_acordo_cancelado_reabre_originais() FROM PUBLIC, anon;

DROP TRIGGER IF EXISTS trg_financeiro_acordo_cancelado ON public.financeiro_parcelas;
CREATE TRIGGER trg_financeiro_acordo_cancelado
    AFTER UPDATE OF situacao ON public.financeiro_parcelas
    FOR EACH ROW WHEN (NEW.situacao = 'cancelada' AND OLD.situacao IS DISTINCT FROM 'cancelada')
    EXECUTE FUNCTION public.financeiro_acordo_cancelado_reabre_originais();

COMMIT;
