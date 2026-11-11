-- SPEC-258 Fase 4d: crédito de devolução no modelo novo (decisão do usuário 08/11: título a receber de valor NEGATIVO ligado à venda de origem).
-- Achado: o funil antigo NAO cria transacao para devolução (criar_transacao_da_parcela_projeto devolve vazio quando natureza_operacao = 'devolucao');
-- só nasce a parcela de projeto negativa + boleto "Nota de Crédito". Por isso a ponte da Fase 4a não enxerga a devolução e o modelo novo ficava sem ela.
-- Aqui: um gatilho em projeto_parcelas (parcela NEGATIVA, de orçamento de devolução, forma diferente de permuta) espelha no modelo novo:
--   título (origem 'devolucao', espécie credito_devolucao, a receber, plano VENDAS A PRAZO como a venda) + parcela firme de valor negativo.
--   titulo_compensado_id = o título da venda de origem, quando todos os itens vêm de UMA venda que já tem título (senão fica vazio).
--   cancelar a parcela / desfazer a aprovação cancela a parcela (e o título quando não resta parcela ativa), só se nada foi liquidado.
-- Como a ponte da 4a: se o espelho falhar, a operação antiga NÃO é bloqueada; a falha fica em financeiro_ponte_falhas (origem 'devolucao_parcela_projeto') e a integridade acusa.
-- NÃO FAZ (decisão pendente, nenhum fluxo definido): a COMPENSAÇÃO do crédito (baixa 'compensacao'). O crédito nasce firme e fica em aberto (negativo) no a receber.
-- Permuta fica de fora (tem o próprio caminho: parcela paga + contrapartida CP). Aditivo: nenhuma função/tabela antiga é alterada.

CREATE OR REPLACE FUNCTION public.financeiro_ponte_devolucao(p_parcela uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
    pp public.projeto_parcelas; o public.orcamentos; v_tit uuid; v_par uuid; v_liq numeric; v_sit public.fin_situacao; v_num int;
    v_plano uuid; v_comp uuid; v_vendas int;
BEGIN
    SELECT * INTO pp FROM public.projeto_parcelas WHERE id = p_parcela;
    IF NOT FOUND OR pp.orcamento_id IS NULL OR pp.valor >= 0 THEN RETURN; END IF;
    IF lower(coalesce(pp.forma_pagamento::text, '')) = 'permuta' THEN RETURN; END IF;
    SELECT * INTO o FROM public.orcamentos WHERE id = pp.orcamento_id;
    IF NOT FOUND OR coalesce(o.natureza_operacao, '') <> 'devolucao' OR o.empresa_id IS NULL THEN RETURN; END IF;

    -- título (um por orçamento de devolução)
    SELECT id INTO v_tit FROM public.financeiro_titulos WHERE origem_tipo = 'devolucao' AND orcamento_id = o.id AND origem_seq = 1;
    IF v_tit IS NULL THEN
        SELECT id INTO v_plano FROM public.plano_de_contas WHERE codigo_connect = 1010002 LIMIT 1;   -- VENDAS A PRAZO (a devolução abate a venda)
        -- venda de origem: só quando todos os itens vêm de UMA venda que já tem título no modelo novo
        SELECT count(DISTINCT pi.orcamento_id), min(t.id::text)::uuid INTO v_vendas, v_comp
          FROM public.orcamento_itens oi
          JOIN public.projeto_itens pi ON pi.id = oi.projeto_item_origem_id
          LEFT JOIN public.financeiro_titulos t ON t.origem_tipo = 'orcamento' AND t.orcamento_id = pi.orcamento_id AND t.origem_seq = 1
         WHERE oi.orcamento_id = o.id;
        INSERT INTO public.financeiro_titulos (natureza, origem_tipo, orcamento_id, especie, empresa_id, perfil, contato_id, plano_contas_id, projeto_id,
                                               documento, descricao, titulo_compensado_id)
        VALUES ('receber', 'devolucao', o.id, 'credito_devolucao', o.empresa_id, CASE WHEN o.perfil IN ('ribeirao', 'sao_paulo') THEN o.perfil END,
                o.cliente_id, v_plano, coalesce(o.projeto_id, pp.projeto_id), o.numero,
                'Crédito de devolução (orçamento ' || coalesce(o.numero, '') || ')', CASE WHEN v_vendas = 1 THEN v_comp END)
        RETURNING id INTO v_tit;
    END IF;

    -- parcela (uma por parcela de projeto)
    SELECT id_novo INTO v_par FROM public.financeiro_legado_ids WHERE tabela_antiga = 'projeto_parcelas' AND id_antigo = pp.id;
    IF v_par IS NULL THEN
        v_num := coalesce(pp.numero_parcela, 1);
        IF EXISTS (SELECT 1 FROM public.financeiro_parcelas WHERE titulo_id = v_tit AND numero = v_num) THEN
            SELECT max(numero) + 1 INTO v_num FROM public.financeiro_parcelas WHERE titulo_id = v_tit;
        END IF;
        INSERT INTO public.financeiro_parcelas (titulo_id, numero, vencimento, valor, situacao, confirmada_em, forma_prevista, emissao, descricao, observacao)
        VALUES (v_tit, v_num, pp.data_vencimento, pp.valor,
                CASE WHEN pp.status::text = 'cancelada' THEN 'cancelada'::public.fin_situacao ELSE 'firme'::public.fin_situacao END,
                CASE WHEN pp.status::text <> 'cancelada' THEN now() END, nullif(pp.forma_pagamento::text, ''), current_date, pp.descricao,
                'Espelho da parcela de projeto ' || pp.id)
        RETURNING id INTO v_par;
        INSERT INTO public.financeiro_legado_ids (tabela_antiga, id_antigo, tabela_nova, id_novo) VALUES ('projeto_parcelas', pp.id, 'financeiro_parcelas', v_par);
    END IF;

    SELECT situacao, valor_liquidado INTO v_sit, v_liq FROM public.financeiro_parcelas WHERE id = v_par;

    IF pp.status::text = 'cancelada' AND v_sit <> 'cancelada' THEN
        IF v_liq <> 0 THEN RAISE EXCEPTION 'Parcela de devolução cancelada com compensação no modelo novo: estornar antes.'; END IF;
        UPDATE public.financeiro_parcelas SET situacao = 'cancelada' WHERE id = v_par;
        v_sit := 'cancelada';
    END IF;

    -- ajuste de valor/vencimento enquanto nada foi liquidado
    IF v_sit = 'firme' AND v_liq = 0 THEN
        UPDATE public.financeiro_parcelas SET valor = pp.valor, vencimento = pp.data_vencimento
         WHERE id = v_par AND (valor <> pp.valor OR vencimento <> pp.data_vencimento);
    END IF;

    -- parcela marcada paga no sistema antigo: a compensação ainda não existe no modelo novo -> falha visível (não bloqueia)
    IF pp.status::text = 'paga' AND v_sit = 'firme' AND v_liq = 0 THEN
        INSERT INTO public.financeiro_ponte_falhas (transacao_id, erro, origem)
        SELECT pp.id, 'Parcela de devolução marcada como paga no sistema antigo; a compensação do crédito ainda não existe no modelo novo.', 'devolucao_parcela_projeto'
         WHERE NOT EXISTS (SELECT 1 FROM public.financeiro_ponte_falhas f WHERE f.transacao_id = pp.id AND f.origem = 'devolucao_parcela_projeto' AND f.resolvida_em IS NULL);
    END IF;
END $fn$;

CREATE OR REPLACE FUNCTION public.financeiro_ponte_devolucao_remover(p_parcela uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE v_par uuid; v_liq numeric; v_tit uuid;
BEGIN
    SELECT id_novo INTO v_par FROM public.financeiro_legado_ids WHERE tabela_antiga = 'projeto_parcelas' AND id_antigo = p_parcela;
    IF v_par IS NULL THEN RETURN; END IF;
    SELECT valor_liquidado, titulo_id INTO v_liq, v_tit FROM public.financeiro_parcelas WHERE id = v_par;
    IF v_liq <> 0 THEN RAISE EXCEPTION 'Parcela de devolução com compensação no modelo novo: estornar antes de desfazer a aprovação.'; END IF;
    UPDATE public.financeiro_parcelas SET situacao = 'cancelada' WHERE id = v_par AND situacao <> 'cancelada';
    IF NOT EXISTS (SELECT 1 FROM public.financeiro_parcelas WHERE titulo_id = v_tit AND situacao <> 'cancelada') THEN
        UPDATE public.financeiro_titulos SET cancelado_em = now(), motivo_cancelamento = 'Aprovação da devolução desfeita no sistema antigo'
         WHERE id = v_tit AND cancelado_em IS NULL;
    END IF;
END $fn$;

CREATE OR REPLACE FUNCTION public.trg_financeiro_ponte_devolucao()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
BEGIN
    BEGIN
        IF TG_OP = 'DELETE' THEN PERFORM public.financeiro_ponte_devolucao_remover(OLD.id);
        ELSE PERFORM public.financeiro_ponte_devolucao(NEW.id); END IF;
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO public.financeiro_ponte_falhas (transacao_id, erro, origem)
        VALUES (coalesce(NEW.id, OLD.id), left(SQLERRM, 500), 'devolucao_parcela_projeto');
    END;
    RETURN NULL;
END $fn$;

REVOKE ALL ON FUNCTION public.financeiro_ponte_devolucao(uuid), public.financeiro_ponte_devolucao_remover(uuid), public.trg_financeiro_ponte_devolucao() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER trg_fin_ponte_devolucao_aiu AFTER INSERT OR UPDATE ON public.projeto_parcelas
    FOR EACH ROW WHEN (NEW.orcamento_id IS NOT NULL AND NEW.valor < 0) EXECUTE FUNCTION public.trg_financeiro_ponte_devolucao();
CREATE TRIGGER trg_fin_ponte_devolucao_ad AFTER DELETE ON public.projeto_parcelas
    FOR EACH ROW WHEN (OLD.orcamento_id IS NOT NULL AND OLD.valor < 0) EXECUTE FUNCTION public.trg_financeiro_ponte_devolucao();

-- integridade da ponte: + 1 teste (devolução sem parcela no modelo novo). As falhas da devolução já entram em "espelho: falhas abertas".
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
          WHERE t.cod_itens_duplicata IS NULL AND t.status_pago <> 2 AND round(COALESCE(t.vl_parcela, 0::numeric), 2) <> round(p.valor, 2)
        UNION ALL
         SELECT 'devolucao: parcela de projeto negativa (nao permuta) sem parcela no modelo novo'::text, count(*)
           FROM projeto_parcelas pp JOIN orcamentos o ON o.id = pp.orcamento_id
          WHERE pp.valor < 0 AND o.natureza_operacao = 'devolucao' AND pp.status::text <> 'cancelada'
            AND lower(coalesce(pp.forma_pagamento::text, '')) <> 'permuta'
            AND NOT (EXISTS ( SELECT 1 FROM financeiro_legado_ids l WHERE l.tabela_antiga = 'projeto_parcelas' AND l.id_antigo = pp.id))) z
  WHERE ( SELECT pode_acessar_sistema('financeiro'::text) AS pode_acessar_sistema);

-- integridade do modelo novo: o teste 'parcela liquidada acima do valor' passa a comparar com abs(valor), porque o credito de devolucao tem valor NEGATIVO
-- (liquidacao do credito = ate o valor absoluto). Para valores positivos o resultado e identico.
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
          WHERE financeiro_parcelas.valor_liquidado > abs(financeiro_parcelas.valor)
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
