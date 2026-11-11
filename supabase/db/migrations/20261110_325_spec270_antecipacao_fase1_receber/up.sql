-- SPEC-270 Fase 1 (SO CONTAS A RECEBER): lancar uma "Antecipacao de pagamento" (reuniao 48, Carol, 10/11/2026).
-- Modelo novo (SPEC-258): titulo especie 'adiantamento' (origem 'adiantamento') a RECEBER + 1 parcela firme + 1 baixa 'recebimento' na data do pagamento
-- (origem_baixa 'antecipacao', dinheiro de verdade: exige conta bancaria). Nasce PAGA, com saldo a compensar (a compensacao vem na Fase 2).
-- Aparece em Consultar Duplicatas (selo "Antecipada") e fica FORA de Contas em Aberto/vencimentos do dia, porque ja esta paga.
-- Decisoes assumidas ate a Carol responder (SPEC-270 P2/P7): nasce recebida na data; responsavel = equipe do orcamento e NUNCA quem esta lancando.
-- Contas a Pagar NAO entra aqui: o pagamento antecipado de fornecedor ja existe (SPEC-215, Entrada de NF) e lancar nos dois lugares contaria em dobro (P5).
-- Aditivo: nada existente muda. O motor de RT (migration 321) so reage a recebimento de titulo 'venda', entao a antecipacao nao gera RT (P6).
-- Sem BEGIN/COMMIT de proposito (dry-run em ROLLBACK).

ALTER TABLE public.financeiro_titulos ADD COLUMN IF NOT EXISTS responsavel_id uuid REFERENCES public.usuarios(id);
COMMENT ON COLUMN public.financeiro_titulos.responsavel_id IS 'SPEC-270: usuario responsavel (equipe do orcamento; quem gera a LT). So preenchido na antecipacao de pagamento.';

CREATE OR REPLACE FUNCTION public.financeiro_lancar_antecipacao(
    p_natureza public.fin_natureza, p_empresa_id uuid, p_perfil text, p_contato_id uuid, p_responsavel_id uuid,
    p_emissao date, p_data_pagamento date, p_valor numeric, p_plano_contas_id uuid, p_conta_bancaria_id uuid,
    p_forma text DEFAULT NULL, p_observacao text DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE v_tit uuid; v_par uuid;
BEGIN
    IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sem usuario autenticado.' USING ERRCODE = '42501'; END IF;
    PERFORM public.financeiro_exige('adiantamento'::public.fin_especie);
    IF p_natureza IS DISTINCT FROM 'receber' THEN
        RAISE EXCEPTION 'Antecipacao a pagar ainda nao esta liberada: use o pagamento antecipado de fornecedor (SPEC-215) ate a unificacao (SPEC-270 P5).' USING ERRCODE = 'P0001';
    END IF;
    IF coalesce(p_valor, 0) <= 0 THEN RAISE EXCEPTION 'Informe o valor da antecipacao.' USING ERRCODE = 'P0001'; END IF;
    IF p_emissao IS NULL OR p_data_pagamento IS NULL THEN RAISE EXCEPTION 'Informe a data de emissao e a data do pagamento.' USING ERRCODE = 'P0001'; END IF;
    IF p_data_pagamento > current_date THEN RAISE EXCEPTION 'A data do pagamento nao pode ser futura: a antecipacao e um valor que ja entrou.' USING ERRCODE = 'P0001'; END IF;
    IF p_perfil IS NOT NULL AND p_perfil NOT IN ('ribeirao', 'sao_paulo') THEN RAISE EXCEPTION 'Perfil da empresa invalido.' USING ERRCODE = 'P0001'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.empresas WHERE id = p_empresa_id) THEN RAISE EXCEPTION 'Empresa nao encontrada.' USING ERRCODE = 'P0001'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.contatos WHERE id = p_contato_id AND tipo = 'cliente') THEN RAISE EXCEPTION 'Informe o cliente que pagou a antecipacao.' USING ERRCODE = 'P0001'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.plano_de_contas WHERE id = p_plano_contas_id AND nivel = 3 AND ativo) THEN RAISE EXCEPTION 'Informe a apropriacao (grupo / subgrupo / apropriacao).' USING ERRCODE = 'P0001'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.contas_bancarias WHERE id = p_conta_bancaria_id) THEN RAISE EXCEPTION 'Informe a conta bancaria em que o valor entrou.' USING ERRCODE = 'P0001'; END IF;
    IF p_responsavel_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.usuarios WHERE id = p_responsavel_id) THEN
        RAISE EXCEPTION 'Informe o responsavel (equipe do orcamento).' USING ERRCODE = 'P0001';
    END IF;
    IF p_responsavel_id = auth.uid() THEN
        RAISE EXCEPTION 'O responsavel e a equipe do orcamento (quem gera a LT), nunca quem esta lancando.' USING ERRCODE = 'P0001';
    END IF;

    v_tit := public.financeiro_criar_titulo(
        jsonb_build_object('natureza', 'receber', 'origem_tipo', 'adiantamento', 'especie', 'adiantamento',
                           'empresa_id', p_empresa_id, 'perfil', p_perfil, 'contato_id', p_contato_id,
                           'plano_contas_id', p_plano_contas_id, 'descricao', nullif(btrim(coalesce(p_observacao, '')), '')),
        jsonb_build_array(jsonb_build_object('vencimento', p_data_pagamento, 'valor', round(p_valor, 2), 'situacao', 'firme',
                                             'observacao', nullif(btrim(coalesce(p_observacao, '')), ''))));
    UPDATE public.financeiro_titulos SET responsavel_id = p_responsavel_id WHERE id = v_tit;
    SELECT id INTO v_par FROM public.financeiro_parcelas WHERE titulo_id = v_tit AND numero = 1;
    UPDATE public.financeiro_parcelas SET emissao = p_emissao WHERE id = v_par;
    PERFORM public.financeiro_baixar(v_par, 'recebimento', round(p_valor, 2), p_data_pagamento, p_conta_bancaria_id,
                                     coalesce(nullif(btrim(coalesce(p_forma, '')), ''), 'Antecipacao'), NULL, 0, 0, 0, NULL, NULL, 'antecipacao');
    RETURN v_tit;
END $fn$;

-- cancelar uma antecipacao lancada errado: estorna o recebimento e cancela o titulo (so enquanto nada foi compensado; a compensacao vem na Fase 2)
CREATE OR REPLACE FUNCTION public.financeiro_cancelar_antecipacao(p_titulo uuid, p_motivo text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE b record;
BEGIN
    IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sem usuario autenticado.' USING ERRCODE = '42501'; END IF;
    PERFORM public.financeiro_exige('adiantamento'::public.fin_especie);
    IF length(btrim(coalesce(p_motivo, ''))) = 0 THEN RAISE EXCEPTION 'Informe o motivo do cancelamento.' USING ERRCODE = 'P0001'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.financeiro_titulos WHERE id = p_titulo AND especie = 'adiantamento' AND cancelado_em IS NULL) THEN
        RAISE EXCEPTION 'Antecipacao inexistente ou ja cancelada.' USING ERRCODE = 'P0001';
    END IF;
    IF EXISTS (SELECT 1 FROM public.financeiro_baixas bx JOIN public.financeiro_parcelas p ON p.id = bx.parcela_id
                WHERE p.titulo_id = p_titulo AND bx.tipo NOT IN ('recebimento', 'estorno')) THEN
        RAISE EXCEPTION 'Esta antecipacao ja foi usada: desfaca o uso antes de cancelar.' USING ERRCODE = 'P0001';
    END IF;
    FOR b IN SELECT bx.id FROM public.financeiro_baixas bx JOIN public.financeiro_parcelas p ON p.id = bx.parcela_id
              WHERE p.titulo_id = p_titulo AND bx.tipo = 'recebimento'
                AND NOT EXISTS (SELECT 1 FROM public.financeiro_baixas e WHERE e.estorno_de = bx.id) LOOP
        PERFORM public.financeiro_estornar(b.id, 'Cancelamento da antecipacao: ' || p_motivo);
    END LOOP;
    PERFORM public.financeiro_cancelar_titulo(p_titulo, p_motivo);
END $fn$;

REVOKE ALL ON FUNCTION public.financeiro_lancar_antecipacao(public.fin_natureza, uuid, text, uuid, uuid, date, date, numeric, uuid, uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.financeiro_cancelar_antecipacao(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.financeiro_lancar_antecipacao(public.fin_natureza, uuid, text, uuid, uuid, date, date, numeric, uuid, uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.financeiro_cancelar_antecipacao(uuid, text) TO authenticated;
