-- SPEC-288 rollback do espelho do pagamento antecipado (A PAGAR).
-- ATENCAO: o titulo 'adiantamento' ja criado e suas baixas nao sao apagados (financeiro e imutavel); cancele-os pelo financeiro se precisar.
BEGIN;
DROP TRIGGER IF EXISTS trg_fin_espelho_antecipado ON public.pagamentos_antecipados;
DROP FUNCTION IF EXISTS public.trg_financeiro_espelho_antecipado();
DROP FUNCTION IF EXISTS public.financeiro_espelhar_pagamento_antecipado(uuid);
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
         SELECT 'a pagar: pagamento antecipado ainda sem espelho (fase 4b-2)'::text,
            count(*) AS count
           FROM pagamentos_antecipados
          WHERE pagamentos_antecipados.cancelado_em IS NULL
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
ALTER TABLE public.pagamentos_antecipados DROP COLUMN IF EXISTS titulo_id;
COMMIT;
