-- SPEC-288 (item A): o pagamento antecipado do Contas a Pagar passa a ter ESPELHO no financeiro novo.
-- Hoje ele vive so em pagamentos_antecipados (SPEC-215) e por isso nao aparece em Consultar Duplicatas (caso Omega Light, 05/11).
-- Aditivo: coluna titulo_id + gatilho que cria/cancela um titulo 'adiantamento' (natureza pagar) ja baixado, igual ao Contas a Receber (SPEC-270).
-- Nada muda para a Entrada de NF: pagamento_antecipado_vinculos e vw_pagamentos_antecipados continuam como estao.
-- A baixa nasce com origem_baixa 'ponte' (o lancamento nao informa conta bancaria).
-- Falha do espelho NUNCA trava o lancamento: vai para financeiro_ponte_falhas (origem 'pagamentos_antecipados').
BEGIN;

ALTER TABLE public.pagamentos_antecipados ADD COLUMN IF NOT EXISTS titulo_id uuid REFERENCES public.financeiro_titulos(id);
CREATE INDEX IF NOT EXISTS ix_pagamentos_antecipados_titulo ON public.pagamentos_antecipados (titulo_id);
COMMENT ON COLUMN public.pagamentos_antecipados.titulo_id IS 'SPEC-288: titulo adiantamento (pagar) que espelha este pagamento no financeiro novo.';

CREATE OR REPLACE FUNCTION public.financeiro_espelhar_pagamento_antecipado(p_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
DECLARE a public.pagamentos_antecipados; v_tit uuid; v_par uuid; b record;
BEGIN
    SELECT * INTO a FROM public.pagamentos_antecipados WHERE id = p_id FOR UPDATE;
    IF NOT FOUND THEN RETURN; END IF;

    IF a.cancelado_em IS NULL AND a.titulo_id IS NULL THEN
        v_tit := public.financeiro_criar_titulo(
            jsonb_build_object('natureza', 'pagar', 'origem_tipo', 'adiantamento', 'especie', 'adiantamento',
                               'empresa_id', a.empresa_id, 'contato_id', a.fornecedor_id,
                               'plano_contas_id', public.financeiro_plano_compras(),
                               'descricao', 'Pagamento antecipado' || coalesce(' - ' || nullif(btrim(a.observacao), ''), '')),
            jsonb_build_array(jsonb_build_object('vencimento', a.data_pagamento, 'valor', a.valor, 'situacao', 'firme',
                                                 'observacao', nullif(btrim(coalesce(a.observacao, '')), ''))));
        SELECT id INTO v_par FROM public.financeiro_parcelas WHERE titulo_id = v_tit AND numero = 1;
        UPDATE public.financeiro_parcelas SET emissao = a.data_pagamento WHERE id = v_par;
        PERFORM public.financeiro_baixar(v_par, 'pagamento', a.valor, a.data_pagamento, NULL, 'Antecipacao', NULL, 0, 0, 0, NULL, NULL, 'ponte');
        UPDATE public.pagamentos_antecipados SET titulo_id = v_tit WHERE id = a.id;
    ELSIF a.cancelado_em IS NOT NULL AND a.titulo_id IS NOT NULL
          AND EXISTS (SELECT 1 FROM public.financeiro_titulos WHERE id = a.titulo_id AND cancelado_em IS NULL) THEN
        FOR b IN SELECT bx.id FROM public.financeiro_baixas bx JOIN public.financeiro_parcelas p ON p.id = bx.parcela_id
                  WHERE p.titulo_id = a.titulo_id AND bx.tipo = 'pagamento'
                    AND NOT EXISTS (SELECT 1 FROM public.financeiro_baixas e WHERE e.estorno_de = bx.id) LOOP
            PERFORM public.financeiro_estornar(b.id, 'Cancelamento do pagamento antecipado: ' || coalesce(nullif(btrim(a.motivo_cancelamento), ''), 'sem motivo informado'));
        END LOOP;
        PERFORM public.financeiro_cancelar_titulo(a.titulo_id, coalesce(nullif(btrim(a.motivo_cancelamento), ''), 'Pagamento antecipado cancelado'));
    END IF;
END $f$;
REVOKE ALL ON FUNCTION public.financeiro_espelhar_pagamento_antecipado(uuid) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.trg_financeiro_espelho_antecipado() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
BEGIN
    BEGIN
        PERFORM public.financeiro_espelhar_pagamento_antecipado(NEW.id);
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO public.financeiro_ponte_falhas (transacao_id, erro, origem) VALUES (NEW.id, left(SQLERRM, 500), 'pagamentos_antecipados');
    END;
    RETURN NULL;
END $f$;
REVOKE ALL ON FUNCTION public.trg_financeiro_espelho_antecipado() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_fin_espelho_antecipado ON public.pagamentos_antecipados;
CREATE TRIGGER trg_fin_espelho_antecipado AFTER INSERT OR UPDATE OF cancelado_em ON public.pagamentos_antecipados
    FOR EACH ROW EXECUTE FUNCTION public.trg_financeiro_espelho_antecipado();

-- retroativo: o que ja foi lancado (hoje 1 registro: Omega Light, 05/11/2026, R$ 2.608,52)
SELECT public.financeiro_espelhar_pagamento_antecipado(id) FROM public.pagamentos_antecipados WHERE cancelado_em IS NULL AND titulo_id IS NULL;

-- conferencia de integridade: agora so acusa o que ficou sem espelho
CREATE OR REPLACE VIEW public.vw_financeiro_ponte_pagar_integridade AS
 SELECT teste,
    violacoes
   FROM ( SELECT 'a pagar: falhas do espelho abertas'::text AS teste,
            count(*) AS violacoes
           FROM financeiro_ponte_falhas
          WHERE financeiro_ponte_falhas.resolvida_em IS NULL AND financeiro_ponte_falhas.origem <> 'transacoes'::text
        UNION ALL
         SELECT 'a pagar: pedido com previsao diferente da view antiga (aprovado/parcial)'::text,
            count(*) AS count
           FROM ( SELECT COALESCE(o.pid, nv.pid) AS "coalesce"
                   FROM ( SELECT vw_contas_pagar_pedidos_compra.pedido_compra_id AS pid,
                            round(sum(vw_contas_pagar_pedidos_compra.vl_parcela), 2) AS v
                           FROM vw_contas_pagar_pedidos_compra
                          WHERE vw_contas_pagar_pedidos_compra.origem = 'pedido_compra'::text
                          GROUP BY vw_contas_pagar_pedidos_compra.pedido_compra_id) o
                     FULL JOIN ( SELECT t.pedido_compra_id AS pid,
                            round(sum(p.valor), 2) AS v
                           FROM financeiro_parcelas p
                             JOIN financeiro_titulos t ON t.id = p.titulo_id
                             JOIN pedidos_compra pc ON pc.id = t.pedido_compra_id
                          WHERE t.origem_tipo = 'pedido_compra'::fin_origem AND p.situacao = 'prevista'::fin_situacao AND (pc.status = ANY (ARRAY['aprovado'::text, 'parcialmente_recebido'::text]))
                          GROUP BY t.pedido_compra_id) nv ON nv.pid = o.pid
                  WHERE o.v IS DISTINCT FROM nv.v) d
        UNION ALL
         SELECT 'a pagar: nota ativa sem titulo (fora a ja lancada pela Connect)'::text,
            count(*) AS count
           FROM notas_fiscais_compra n
          WHERE n.cancelada_em IS NULL AND (EXISTS ( SELECT 1
                   FROM nota_fiscal_compra_parcelas x
                  WHERE x.nota_id = n.id)) AND NOT (EXISTS ( SELECT 1
                   FROM financeiro_titulos t
                  WHERE t.origem_tipo = 'nota_fiscal_compra'::fin_origem AND t.nota_fiscal_compra_id = n.id)) AND NOT (EXISTS ( SELECT 1
                   FROM negociacoes g
                  WHERE g.tipo = 'despesa'::transacao_tipo AND g.empresa_id = COALESCE(n.empresa_id, ( SELECT pedidos_compra.empresa_id
                           FROM pedidos_compra
                          WHERE pedidos_compra.id = n.pedido_compra_id)) AND g.num_nota::numeric = NULLIF(regexp_replace(n.numero_nf, '\D'::text, ''::text, 'g'::text), ''::text)::numeric AND abs(COALESCE(( SELECT sum(t.vl_parcela) AS sum
                           FROM transacoes t
                          WHERE t.negociacao_id = g.id AND t.status_pago <> 2), 0::numeric) - n.valor) <= 1::numeric))
        UNION ALL
         SELECT 'a pagar: boleto CP pago sem baixa no modelo novo'::text,
            count(*) AS count
           FROM boletos b
             JOIN financeiro_legado_ids l ON l.tabela_antiga = 'nota_fiscal_compra_parcelas'::text AND ('NFC-'::text || l.id_antigo::text) = b.nosso_numero
             JOIN financeiro_parcelas p ON p.id = l.id_novo
          WHERE b.tipo_operacao = 'CP'::text AND b.status = 'Pago'::text AND p.situacao = 'firme'::fin_situacao AND p.valor_liquidado = 0::numeric
        UNION ALL
         SELECT 'a pagar: pagamento antecipado sem espelho no financeiro (SPEC-288)'::text,
            count(*) AS count
           FROM pagamentos_antecipados
          WHERE cancelado_em IS NULL AND titulo_id IS NULL
        UNION ALL
         SELECT 'a pagar: pedido recebido com previsao e pergunta sem resposta (informativo)'::text,
            count(*) AS count
           FROM financeiro_titulos t
             JOIN pedidos_compra pc ON pc.id = t.pedido_compra_id
          WHERE t.origem_tipo = 'pedido_compra'::fin_origem AND t.cancelado_em IS NULL AND pc.status = 'recebido'::text AND (EXISTS ( SELECT 1
                   FROM financeiro_parcelas p
                  WHERE p.titulo_id = t.id AND p.situacao = 'prevista'::fin_situacao)) AND NOT (EXISTS ( SELECT 1
                   FROM financeiro_pedido_pagamento_confirmacao c
                  WHERE c.pedido_id = pc.id))) z
  WHERE ( SELECT pode_acessar_sistema('financeiro'::text) AS pode_acessar_sistema);

COMMIT;
