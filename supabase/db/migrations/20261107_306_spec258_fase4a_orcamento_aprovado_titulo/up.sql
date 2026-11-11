-- SPEC-258 Fase 4a: orçamento aprovado -> título a receber no modelo novo.
-- Em vez de reescrever aprovar_orcamento_financeiro (555 linhas), espelhamos o FUNIL que ele já usa: projeto_parcelas -> negociacoes/transacoes nativas
-- (parcelas sem código da Connect). Tudo que passa por esse funil (aprovação, retorno bancário, baixa manual, desfazer aprovação) vira título/parcela/baixa/estorno
-- no modelo novo, na mesma transação. Se o espelho falhar, a operação antiga NÃO é bloqueada: a falha fica em financeiro_ponte_falhas e a integridade acusa.
-- Aditivo: nenhuma função/tabela antiga é alterada.

-- 1) origem 'ponte' para baixas espelhadas do funil antigo (conta pode faltar -> pendência)
ALTER TABLE public.financeiro_baixas DROP CONSTRAINT financeiro_baixas_origem_baixa_check;
ALTER TABLE public.financeiro_baixas ADD CONSTRAINT financeiro_baixas_origem_baixa_check CHECK (origem_baixa IN ('manual', 'retorno_bancario', 'antecipacao', 'legado', 'ponte'));
ALTER TABLE public.financeiro_baixas DROP CONSTRAINT financeiro_baixas_check;
ALTER TABLE public.financeiro_baixas ADD CONSTRAINT financeiro_baixas_check CHECK (NOT movimenta_caixa OR conta_bancaria_id IS NOT NULL OR origem_baixa IN ('legado', 'ponte'));

-- 2) falhas do espelho (visíveis; nunca silenciosas)
CREATE TABLE public.financeiro_ponte_falhas (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transacao_id  uuid NOT NULL,
    erro          text NOT NULL,
    criado_em     timestamptz NOT NULL DEFAULT now(),
    resolvida_em  timestamptz
);
ALTER TABLE public.financeiro_ponte_falhas ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.financeiro_ponte_falhas FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.financeiro_ponte_falhas TO authenticated;
CREATE POLICY fin_ponte_falhas_select ON public.financeiro_ponte_falhas FOR SELECT TO authenticated USING ((SELECT public.pode_acessar_sistema('financeiro')));

-- 3) o espelho de uma transação nativa (idempotente: pode rodar quantas vezes quiser)
CREATE OR REPLACE FUNCTION public.financeiro_ponte_transacao(p_tx uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
DECLARE
    t public.transacoes; n public.negociacoes;
    v_tit uuid; v_par uuid; v_num int; v_liq numeric; v_sit public.fin_situacao; v_b record; v_baixa uuid;
BEGIN
    SELECT * INTO t FROM public.transacoes WHERE id = p_tx;
    IF NOT FOUND OR t.cod_itens_duplicata IS NOT NULL OR t.negociacao_id IS NULL THEN RETURN; END IF;
    SELECT * INTO n FROM public.negociacoes WHERE id = t.negociacao_id;
    IF n.orcamento_id IS NULL OR t.tipo::text <> 'receita' THEN RETURN; END IF;   -- só vendas de orçamento (4a); outras origens vêm nas próximas fases

    -- título (um por orçamento)
    SELECT id INTO v_tit FROM public.financeiro_titulos WHERE origem_tipo = 'orcamento' AND orcamento_id = n.orcamento_id AND origem_seq = 1;
    IF v_tit IS NULL THEN
        INSERT INTO public.financeiro_titulos (natureza, origem_tipo, orcamento_id, especie, empresa_id, perfil, contato_id, plano_contas_id, projeto_id, documento, descricao)
        VALUES ('receber', 'orcamento', n.orcamento_id, 'venda', n.empresa_id, CASE WHEN t.perfil IN ('ribeirao', 'sao_paulo') THEN t.perfil END,
                n.contato_id, n.plano_contas_id, n.projeto_id, n.num_nota::text, n.observacao)
        RETURNING id INTO v_tit;
    END IF;

    -- parcela (uma por transação)
    SELECT id_novo INTO v_par FROM public.financeiro_legado_ids WHERE tabela_antiga = 'transacoes' AND id_antigo = p_tx;
    IF v_par IS NULL THEN
        v_num := coalesce(t.num_parc, 1);
        IF EXISTS (SELECT 1 FROM public.financeiro_parcelas WHERE titulo_id = v_tit AND numero = v_num) THEN
            SELECT max(numero) + 1 INTO v_num FROM public.financeiro_parcelas WHERE titulo_id = v_tit;
        END IF;
        INSERT INTO public.financeiro_parcelas (titulo_id, numero, vencimento, valor, situacao, confirmada_em, forma_prevista, emissao, descricao, desconto, observacao)
        VALUES (v_tit, v_num, t.dt_vencimento, coalesce(t.vl_parcela, 0), CASE WHEN t.status_pago = 2 THEN 'cancelada'::public.fin_situacao ELSE 'firme'::public.fin_situacao END,
                CASE WHEN t.status_pago <> 2 THEN now() END, nullif(t.tipo_pagamento, ''), t.dt_emissao, t.descricao, greatest(coalesce(t.vl_desconto, 0), 0),
                'Espelho do funil antigo (transação ' || t.id || ')')
        RETURNING id INTO v_par;
        INSERT INTO public.financeiro_legado_ids (tabela_antiga, id_antigo, tabela_nova, id_novo) VALUES ('transacoes', p_tx, 'financeiro_parcelas', v_par);
    END IF;

    SELECT situacao, valor_liquidado INTO v_sit, v_liq FROM public.financeiro_parcelas WHERE id = v_par;

    -- cancelamento (só se nada foi liquidado)
    IF t.status_pago = 2 AND v_sit <> 'cancelada' THEN
        IF v_liq <> 0 THEN RAISE EXCEPTION 'Transação cancelada com baixa na parcela nova: estornar antes.'; END IF;
        UPDATE public.financeiro_parcelas SET situacao = 'cancelada' WHERE id = v_par;
        v_sit := 'cancelada';
    END IF;

    -- ajuste de valor/vencimento enquanto não houver baixa
    IF v_sit = 'firme' AND v_liq = 0 THEN
        UPDATE public.financeiro_parcelas SET valor = coalesce(t.vl_parcela, 0), vencimento = t.dt_vencimento, desconto = greatest(coalesce(t.vl_desconto, 0), 0)
         WHERE id = v_par AND (valor <> coalesce(t.vl_parcela, 0) OR vencimento <> t.dt_vencimento OR desconto <> greatest(coalesce(t.vl_desconto, 0), 0));
    END IF;

    -- pago agora e ainda sem baixa -> baixa
    IF t.status_pago = 1 AND v_sit = 'firme' AND v_liq = 0 THEN
        IF coalesce(t.vl_pago, 0) > 0 THEN
            INSERT INTO public.financeiro_baixas (parcela_id, tipo, data, valor, juros, desconto, forma, conta_bancaria_id, comprovante_url, origem_baixa)
            VALUES (v_par, 'recebimento', coalesce(t.dt_pagamento, current_date), least(t.vl_pago, coalesce(t.vl_parcela, 0)), greatest(t.vl_pago - coalesce(t.vl_parcela, 0), 0),
                    greatest(coalesce(t.vl_desconto, 0), 0), nullif(t.tipo_pagamento, ''), t.conta_id, t.comprovante_url, 'ponte')
            RETURNING id INTO v_baixa;
            IF t.conta_id IS NULL THEN
                INSERT INTO public.financeiro_pendencias (baixa_id, tipo, descricao, responsavel)
                VALUES (v_baixa, 'baixa_sem_conta_bancaria', 'Recebimento sem conta bancária (retorno/baixa manual): informar a conta.', 'Financeiro');
            END IF;
            IF t.vl_pago < coalesce(t.vl_parcela, 0) THEN
                INSERT INTO public.financeiro_baixas (parcela_id, tipo, data, valor, forma, motivo, origem_baixa)
                VALUES (v_par, 'abatimento', coalesce(t.dt_pagamento, current_date), t.vl_parcela - t.vl_pago, nullif(t.tipo_pagamento, ''),
                        'Diferença entre o valor da parcela e o valor recebido', 'ponte');
            END IF;
        ELSE
            INSERT INTO public.financeiro_baixas (parcela_id, tipo, data, valor, forma, motivo, origem_baixa)
            VALUES (v_par, 'baixa_interna', coalesce(t.dt_pagamento, current_date), coalesce(t.vl_parcela, 0), nullif(t.tipo_pagamento, ''),
                    'Baixa sem movimento de caixa no sistema antigo (pago com valor zero)', 'ponte');
        END IF;
    END IF;

    -- pagamento desfeito -> estorna as baixas que ainda estão de pé
    IF t.status_pago = 0 AND v_sit = 'firme' AND v_liq <> 0 THEN
        FOR v_b IN SELECT b.id FROM public.financeiro_baixas b WHERE b.parcela_id = v_par AND b.tipo <> 'estorno'
                    AND NOT EXISTS (SELECT 1 FROM public.financeiro_baixas e WHERE e.estorno_de = b.id) ORDER BY b.criado_em DESC LOOP
            INSERT INTO public.financeiro_baixas (parcela_id, tipo, data, valor, forma, conta_bancaria_id, motivo, origem_baixa, estorno_de)
            SELECT b.parcela_id, 'estorno', current_date, b.valor, b.forma, b.conta_bancaria_id, 'Pagamento desfeito no sistema antigo', 'ponte', b.id
              FROM public.financeiro_baixas b WHERE b.id = v_b.id;
        END LOOP;
    END IF;
END $f$;
REVOKE ALL ON FUNCTION public.financeiro_ponte_transacao(uuid) FROM PUBLIC, anon, authenticated;

-- 4) gatilho no funil: nunca bloqueia a operação antiga; falha vira registro
CREATE OR REPLACE FUNCTION public.trg_financeiro_ponte() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
BEGIN
    BEGIN
        PERFORM public.financeiro_ponte_transacao(NEW.id);
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO public.financeiro_ponte_falhas (transacao_id, erro) VALUES (NEW.id, left(SQLERRM, 500));
    END;
    RETURN NULL;
END $f$;
REVOKE ALL ON FUNCTION public.trg_financeiro_ponte() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER trg_transacoes_financeiro_ponte AFTER INSERT OR UPDATE ON public.transacoes
    FOR EACH ROW WHEN (NEW.cod_itens_duplicata IS NULL) EXECUTE FUNCTION public.trg_financeiro_ponte();

-- 5) o que já existe de nativo (hoje: 2 transações canceladas de 05/11)
DO $$ DECLARE r record; BEGIN
    FOR r IN SELECT id FROM public.transacoes WHERE cod_itens_duplicata IS NULL ORDER BY created_at LOOP
        BEGIN PERFORM public.financeiro_ponte_transacao(r.id);
        EXCEPTION WHEN OTHERS THEN INSERT INTO public.financeiro_ponte_falhas (transacao_id, erro) VALUES (r.id, left(SQLERRM, 500)); END;
    END LOOP;
END $$;

-- 6) integridade da ponte: tudo deve dar 0
CREATE OR REPLACE VIEW public.vw_financeiro_ponte_integridade AS
SELECT teste, violacoes FROM (
    SELECT 'espelho: falhas abertas'::text AS teste, count(*)::bigint AS violacoes FROM public.financeiro_ponte_falhas WHERE resolvida_em IS NULL
    UNION ALL SELECT 'espelho: transacao nativa de orcamento sem parcela no modelo novo', count(*) FROM public.transacoes t JOIN public.negociacoes n ON n.id = t.negociacao_id
        WHERE t.cod_itens_duplicata IS NULL AND n.orcamento_id IS NOT NULL AND t.tipo::text = 'receita'
          AND NOT EXISTS (SELECT 1 FROM public.financeiro_legado_ids l WHERE l.tabela_antiga = 'transacoes' AND l.id_antigo = t.id)
    UNION ALL SELECT 'espelho: situacao paga/cancelada diferente entre antigo e novo', count(*) FROM public.transacoes t
        JOIN public.financeiro_legado_ids l ON l.tabela_antiga = 'transacoes' AND l.id_antigo = t.id JOIN public.financeiro_parcelas p ON p.id = l.id_novo
        WHERE t.cod_itens_duplicata IS NULL AND ((t.status_pago = 2) <> (p.situacao = 'cancelada') OR (t.status_pago = 1) <> (p.situacao = 'firme' AND p.valor_liquidado >= p.valor AND p.valor_liquidado > 0 OR p.situacao = 'firme' AND p.valor = 0 AND EXISTS (SELECT 1 FROM public.financeiro_baixas b WHERE b.parcela_id = p.id)))
    UNION ALL SELECT 'espelho: valor da parcela diferente entre antigo e novo', count(*) FROM public.transacoes t
        JOIN public.financeiro_legado_ids l ON l.tabela_antiga = 'transacoes' AND l.id_antigo = t.id JOIN public.financeiro_parcelas p ON p.id = l.id_novo
        WHERE t.cod_itens_duplicata IS NULL AND t.status_pago <> 2 AND round(coalesce(t.vl_parcela, 0), 2) <> round(p.valor, 2)
) z WHERE (SELECT public.pode_acessar_sistema('financeiro'));
GRANT SELECT ON public.vw_financeiro_ponte_integridade TO authenticated;
REVOKE ALL ON public.vw_financeiro_ponte_integridade FROM anon;
COMMENT ON TABLE public.financeiro_ponte_falhas IS 'SPEC-258 Fase 4a: falhas do espelho do funil antigo (transacoes nativas) no modelo novo.';
