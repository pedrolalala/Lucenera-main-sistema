-- SPEC-258 Fase 4c (parte 1): tela "Regras de RT" em Contas a Pagar. Este arquivo so cria o que a tela precisa para DEFINIR o RT por arquiteto.
-- NAO calcula nem lanca RT (o motor vem depois, quando as decisoes de base/gatilho estiverem fechadas): so grava a regra em financeiro_regras_repasse.
--  * vw_financeiro_rt_arquitetos: os arquitetos (contatos.tipo='arquiteto') com a regra ativa deles (ou sem regra).
--  * financeiro_definir_rt(...): grava/troca/remove a regra de UM arquiteto (ou a padrao, contato NULL). Historico: regra antiga fica inativa com fim; a auditoria ja existe (trigger).
--  * financeiro_definir_rt_lote(jsonb): varias de uma vez, tudo ou nada (para carregar a planilha de RT depois).
-- Acesso: financeiro_exige('rt_arquiteto') = sistema 'financeiro'. Sem gravacao direta na tabela (so por estas funcoes). Aditivo: nada existente muda.

CREATE OR REPLACE FUNCTION public.financeiro_definir_rt(
    p_contato uuid, p_percentual numeric, p_base text DEFAULT 'recebido', p_gatilho text DEFAULT 'proporcional_recebido',
    p_dia_fixo integer DEFAULT NULL, p_exige_nf boolean DEFAULT NULL, p_obs text DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE v_escopo text; v_ativa public.financeiro_regras_repasse; v_id uuid;
BEGIN
    IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sem usuario autenticado.' USING ERRCODE = '42501'; END IF;
    PERFORM public.financeiro_exige('rt_arquiteto'::public.fin_especie);
    IF p_percentual IS NOT NULL AND (p_percentual < 0 OR p_percentual > 100) THEN
        RAISE EXCEPTION 'O percentual do RT deve ficar entre 0 e 100.' USING ERRCODE = 'P0001';
    END IF;
    IF p_contato IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.contatos WHERE id = p_contato AND tipo = 'arquiteto') THEN
        RAISE EXCEPTION 'O contato informado nao e um arquiteto.' USING ERRCODE = 'P0001';
    END IF;
    v_escopo := CASE WHEN p_contato IS NULL THEN 'padrao' ELSE 'beneficiario' END;

    SELECT * INTO v_ativa FROM public.financeiro_regras_repasse
     WHERE tipo = 'rt_arquiteto' AND ativo AND escopo = v_escopo AND beneficiario_contato_id IS NOT DISTINCT FROM p_contato
     ORDER BY vigencia_inicio DESC, criado_em DESC LIMIT 1 FOR UPDATE;

    IF p_percentual IS NULL THEN                      -- remover a regra: fica inativa, com fim
        IF FOUND THEN
            UPDATE public.financeiro_regras_repasse SET ativo = false, vigencia_fim = greatest(vigencia_inicio, current_date) WHERE id = v_ativa.id;
        END IF;
        RETURN NULL;
    END IF;

    IF FOUND AND v_ativa.vigencia_inicio = current_date THEN   -- ajuste no mesmo dia: edita no lugar (o trigger de auditoria guarda o antes/depois)
        UPDATE public.financeiro_regras_repasse
           SET percentual = p_percentual, base_calculo = p_base, gatilho = p_gatilho, dia_fixo = p_dia_fixo,
               exige_nota_fiscal = p_exige_nf, observacao = p_obs
         WHERE id = v_ativa.id;
        RETURN v_ativa.id;
    END IF;

    IF FOUND THEN
        UPDATE public.financeiro_regras_repasse SET ativo = false, vigencia_fim = greatest(vigencia_inicio, current_date) WHERE id = v_ativa.id;
    END IF;
    INSERT INTO public.financeiro_regras_repasse (tipo, escopo, beneficiario_contato_id, percentual, base_calculo, gatilho, dia_fixo, exige_nota_fiscal, observacao, criado_por)
    VALUES ('rt_arquiteto', v_escopo, p_contato, p_percentual, p_base, p_gatilho, p_dia_fixo, p_exige_nf, p_obs, auth.uid())
    RETURNING id INTO v_id;
    RETURN v_id;
END $fn$;

CREATE OR REPLACE FUNCTION public.financeiro_definir_rt_lote(p_itens jsonb)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE r jsonb; n integer := 0;
BEGIN
    IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sem usuario autenticado.' USING ERRCODE = '42501'; END IF;
    PERFORM public.financeiro_exige('rt_arquiteto'::public.fin_especie);
    IF jsonb_typeof(p_itens) <> 'array' THEN RAISE EXCEPTION 'p_itens deve ser uma lista.' USING ERRCODE = 'P0001'; END IF;
    FOR r IN SELECT * FROM jsonb_array_elements(p_itens) LOOP
        PERFORM public.financeiro_definir_rt(
            nullif(r->>'contato_id', '')::uuid, nullif(r->>'percentual', '')::numeric,
            coalesce(r->>'base_calculo', 'recebido'), coalesce(r->>'gatilho', 'proporcional_recebido'),
            nullif(r->>'dia_fixo', '')::integer, nullif(r->>'exige_nf', '')::boolean, r->>'observacao');
        n := n + 1;
    END LOOP;
    RETURN n;
END $fn$;

REVOKE ALL ON FUNCTION public.financeiro_definir_rt(uuid, numeric, text, text, integer, boolean, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.financeiro_definir_rt_lote(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.financeiro_definir_rt(uuid, numeric, text, text, integer, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.financeiro_definir_rt_lote(jsonb) TO authenticated;

CREATE OR REPLACE VIEW public.vw_financeiro_rt_arquitetos WITH (security_invoker = true) AS
SELECT c.id AS contato_id,
       c.nome,
       r.id AS regra_id,
       r.percentual,
       r.base_calculo,
       r.gatilho,
       r.dia_fixo,
       r.exige_nota_fiscal,
       r.observacao,
       r.vigencia_inicio,
       (r.id IS NOT NULL) AS tem_regra
FROM public.contatos c
LEFT JOIN LATERAL (
    SELECT x.* FROM public.financeiro_regras_repasse x
     WHERE x.tipo = 'rt_arquiteto' AND x.ativo AND x.escopo = 'beneficiario' AND x.beneficiario_contato_id = c.id
       AND x.vigencia_inicio <= current_date AND (x.vigencia_fim IS NULL OR x.vigencia_fim >= current_date)
     ORDER BY x.vigencia_inicio DESC, x.criado_em DESC LIMIT 1
) r ON true
WHERE c.tipo = 'arquiteto';

REVOKE ALL ON public.vw_financeiro_rt_arquitetos FROM PUBLIC, anon;
GRANT SELECT ON public.vw_financeiro_rt_arquitetos TO authenticated;
