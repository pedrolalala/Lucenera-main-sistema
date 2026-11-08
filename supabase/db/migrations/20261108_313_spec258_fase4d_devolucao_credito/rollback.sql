-- SPEC-258 Fase 4d: remove a ponte da devolucao e volta a view de integridade para a versao da 4a (4 testes).
-- As parcelas/titulos de credito ja criados NAO sao apagados (nada e apagado): ficam no modelo novo, sem gatilho.
DROP TRIGGER IF EXISTS trg_fin_ponte_devolucao_aiu ON public.projeto_parcelas;
DROP TRIGGER IF EXISTS trg_fin_ponte_devolucao_ad ON public.projeto_parcelas;
DROP FUNCTION IF EXISTS public.trg_financeiro_ponte_devolucao();
DROP FUNCTION IF EXISTS public.financeiro_ponte_devolucao_remover(uuid);
DROP FUNCTION IF EXISTS public.financeiro_ponte_devolucao(uuid);
CREATE OR REPLACE VIEW public.vw_financeiro_ponte_integridade AS
 SELECT teste, violacoes
   FROM ( SELECT 'espelho: falhas abertas'::text AS teste, count(*) AS violacoes
           FROM financeiro_ponte_falhas WHERE financeiro_ponte_falhas.resolvida_em IS NULL
        UNION ALL
         SELECT 'espelho: transacao nativa de orcamento sem parcela no modelo novo'::text, count(*)
           FROM transacoes t JOIN negociacoes n ON n.id = t.negociacao_id
          WHERE t.cod_itens_duplicata IS NULL AND n.orcamento_id IS NOT NULL AND t.tipo::text = 'receita'::text
            AND NOT (EXISTS ( SELECT 1 FROM financeiro_legado_ids l WHERE l.tabela_antiga = 'transacoes'::text AND l.id_antigo = t.id))
        UNION ALL
         SELECT 'espelho: situacao paga/cancelada diferente entre antigo e novo'::text, count(*)
           FROM transacoes t
             JOIN financeiro_legado_ids l ON l.tabela_antiga = 'transacoes'::text AND l.id_antigo = t.id
             JOIN financeiro_parcelas p ON p.id = l.id_novo
          WHERE t.cod_itens_duplicata IS NULL AND ((t.status_pago = 2) <> (p.situacao = 'cancelada'::fin_situacao) OR (t.status_pago = 1) <> (p.situacao = 'firme'::fin_situacao AND p.valor_liquidado >= p.valor AND p.valor_liquidado > 0::numeric OR p.situacao = 'firme'::fin_situacao AND p.valor = 0::numeric AND (EXISTS ( SELECT 1 FROM financeiro_baixas b WHERE b.parcela_id = p.id))))
        UNION ALL
         SELECT 'espelho: valor da parcela diferente entre antigo e novo'::text, count(*)
           FROM transacoes t
             JOIN financeiro_legado_ids l ON l.tabela_antiga = 'transacoes'::text AND l.id_antigo = t.id
             JOIN financeiro_parcelas p ON p.id = l.id_novo
          WHERE t.cod_itens_duplicata IS NULL AND t.status_pago <> 2 AND round(COALESCE(t.vl_parcela, 0::numeric), 2) <> round(p.valor, 2)) z
  WHERE ( SELECT pode_acessar_sistema('financeiro'::text) AS pode_acessar_sistema);

-- volta o teste de integridade do modelo novo para a versao anterior (valor_liquidado > valor)
CREATE OR REPLACE VIEW public.vw_financeiro_novo_integridade AS
SELECT teste,
    violacoes
   FROM ( SELECT 'parcela com liquidado diferente da soma das baixas'::text AS teste,
            count(*) AS violacoes
           FROM financeiro_parcelas p
          WHERE p.valor_liquidado <> COALESCE(( SELECT sum(
                        CASE
                            WHEN b.tipo = 'estorno'::fin_baixa_tipo THEN - b.valor
                            ELSE b.valor
                        END) AS sum
                   FROM financeiro_baixas b
                  WHERE b.parcela_id = p.id), 0::numeric)
        UNION ALL
         SELECT 'parcela liquidada acima do valor'::text,
            count(*) AS count
           FROM financeiro_parcelas
          WHERE financeiro_parcelas.valor_liquidado > financeiro_parcelas.valor
        UNION ALL
         SELECT 'parcela com liquidado negativo'::text,
            count(*) AS count
           FROM financeiro_parcelas
          WHERE financeiro_parcelas.valor_liquidado < 0::numeric
        UNION ALL
         SELECT 'titulo sem nenhuma parcela'::text,
            count(*) AS count
           FROM financeiro_titulos t
          WHERE NOT (EXISTS ( SELECT 1
                   FROM financeiro_parcelas p
                  WHERE p.titulo_id = t.id))
        UNION ALL
         SELECT 'titulo cancelado com parcela ativa'::text,
            count(*) AS count
           FROM financeiro_parcelas p
             JOIN financeiro_titulos t ON t.id = p.titulo_id
          WHERE t.cancelado_em IS NOT NULL AND (p.situacao = ANY (ARRAY['prevista'::fin_situacao, 'firme'::fin_situacao]))
        UNION ALL
         SELECT 'parcela cancelada/substituida com saldo liquidado'::text,
            count(*) AS count
           FROM financeiro_parcelas
          WHERE (financeiro_parcelas.situacao = ANY (ARRAY['cancelada'::fin_situacao, 'substituida'::fin_situacao])) AND financeiro_parcelas.valor_liquidado <> 0::numeric
        UNION ALL
         SELECT 'baixa estornada mais de uma vez'::text,
            count(*) AS count
           FROM ( SELECT financeiro_baixas.estorno_de
                   FROM financeiro_baixas
                  WHERE financeiro_baixas.estorno_de IS NOT NULL
                  GROUP BY financeiro_baixas.estorno_de
                 HAVING count(*) > 1) x
        UNION ALL
         SELECT 'estorno com valor diferente da baixa original'::text,
            count(*) AS count
           FROM financeiro_baixas e
             JOIN financeiro_baixas o ON o.id = e.estorno_de
          WHERE e.valor <> o.valor
        UNION ALL
         SELECT 'recebimento em titulo a pagar (ou pagamento em a receber)'::text,
            count(*) AS count
           FROM financeiro_baixas b
             JOIN financeiro_parcelas p ON p.id = b.parcela_id
             JOIN financeiro_titulos t ON t.id = p.titulo_id
          WHERE b.tipo = 'recebimento'::fin_baixa_tipo AND t.natureza <> 'receber'::fin_natureza OR b.tipo = 'pagamento'::fin_baixa_tipo AND t.natureza <> 'pagar'::fin_natureza
        UNION ALL
         SELECT 'titulo sem evento de criacao no historico permanente'::text,
            count(*) AS count
           FROM financeiro_titulos t
          WHERE NOT (EXISTS ( SELECT 1
                   FROM financeiro_eventos e
                  WHERE e.tabela = 'financeiro_titulos'::text AND e.registro_id = t.id AND e.operacao = 'INSERT'::text))
        UNION ALL
         SELECT 'baixa sem evento de criacao no historico permanente'::text,
            count(*) AS count
           FROM financeiro_baixas b
          WHERE NOT (EXISTS ( SELECT 1
                   FROM financeiro_eventos e
                  WHERE e.tabela = 'financeiro_baixas'::text AND e.registro_id = b.id AND e.operacao = 'INSERT'::text))
        UNION ALL
         SELECT 'parcela firme sem confirmacao nem codigo da Connect'::text,
            count(*) AS count
           FROM financeiro_parcelas
          WHERE financeiro_parcelas.situacao = 'firme'::fin_situacao AND financeiro_parcelas.confirmada_em IS NULL AND financeiro_parcelas.legado_cod_itens_duplicata IS NULL
        UNION ALL
         SELECT 'titulo nativo sem plano de contas'::text,
            count(*) AS count
           FROM financeiro_titulos
          WHERE financeiro_titulos.origem_tipo <> 'legado_connect'::fin_origem AND financeiro_titulos.plano_contas_id IS NULL
        UNION ALL
         SELECT 'regra_repasse sem titulo base'::text,
            count(*) AS count
           FROM financeiro_titulos
          WHERE financeiro_titulos.origem_tipo = 'regra_repasse'::fin_origem AND financeiro_titulos.titulo_base_id IS NULL
        UNION ALL
         SELECT 'pendencias abertas (informativo, nao e erro)'::text,
            count(*) AS count
           FROM financeiro_pendencias
          WHERE financeiro_pendencias.status = 'aberta'::fin_pendencia_status) z
  WHERE ( SELECT pode_acessar_sistema('financeiro'::text) AS pode_acessar_sistema);
