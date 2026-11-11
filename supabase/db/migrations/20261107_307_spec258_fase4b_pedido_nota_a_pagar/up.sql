-- SPEC-258 Fase 4b: pedido de compra e nota de entrada -> título a pagar no modelo novo (espelho idempotente; nunca bloqueia a operação antiga).
-- Regras decididas com o usuário (07/11/2026):
--  (a) a previsão do pedido DIMINUI quando a nota entra (mesma conta da vw_contas_pagar_pedidos_compra);
--  (b) com a nota paga e restante no pedido, o restante continua previsto;
--  (c) pedido RECEBIDO mantém a previsão restante ATÉ o Compras responder, no pop-up, se as parcelas já foram pagas
--      (financeiro_pedido_pergunta + financeiro_responder_pedido_pago). Sim = baixa de pagamento nas previstas; Não = continuam previstas.
-- Pagamento antecipado fica para a 4b-2 (hoje 0 registros): a integridade acusa se aparecer algum.
-- Aditivo: nenhuma tabela/função antiga é alterada.

ALTER TABLE public.financeiro_ponte_falhas ADD COLUMN IF NOT EXISTS origem text NOT NULL DEFAULT 'transacoes';

-- resposta do pop-up
CREATE TABLE public.financeiro_pedido_pagamento_confirmacao (
    pedido_id         uuid PRIMARY KEY REFERENCES public.pedidos_compra(id),
    parcelas_pagas    boolean NOT NULL,
    data_pagamento    date,
    conta_bancaria_id uuid REFERENCES public.contas_bancarias(id),
    observacao        text,
    respondido_por    uuid,
    respondido_em     timestamptz NOT NULL DEFAULT now(),
    CHECK (NOT parcelas_pagas OR data_pagamento IS NOT NULL)
);
ALTER TABLE public.financeiro_pedido_pagamento_confirmacao ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.financeiro_pedido_pagamento_confirmacao FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.financeiro_pedido_pagamento_confirmacao TO authenticated;
CREATE POLICY fin_pedido_conf_select ON public.financeiro_pedido_pagamento_confirmacao FOR SELECT TO authenticated
    USING ((SELECT public.pode_acessar_sistema('financeiro')) OR (SELECT public.pode_acessar_sistema('necessidade-de-compra')));

-- plano de contas padrão do a pagar de compras (COMPRAS - REVENDA, código Connect 2050001)
CREATE OR REPLACE FUNCTION public.financeiro_plano_compras() RETURNS uuid LANGUAGE sql STABLE SET search_path TO 'public' AS
$f$ SELECT id FROM public.plano_de_contas WHERE codigo_connect = 2050001 LIMIT 1 $f$;

-- ===================================================================== PEDIDO
CREATE OR REPLACE FUNCTION public.financeiro_ponte_pedido(p_pedido uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
DECLARE
    p public.pedidos_compra; v_tit uuid; v_consumido numeric; v_pagas boolean; v_max int; v_cur jsonb; v_des jsonb; v_cmp jsonb; r record; v_n int := 0;
BEGIN
    SELECT * INTO p FROM public.pedidos_compra WHERE id = p_pedido;
    IF NOT FOUND OR p.numero LIKE 'PC-LEGADO-%' THEN RETURN; END IF;
    SELECT id INTO v_tit FROM public.financeiro_titulos WHERE origem_tipo = 'pedido_compra' AND pedido_compra_id = p.id AND origem_seq = 1;

    -- cancelado / voltou para edição: previsão cancelada
    IF p.status IN ('cancelado', 'aguardando_aprovar') THEN
        IF v_tit IS NOT NULL THEN
            UPDATE public.financeiro_parcelas SET situacao = 'cancelada' WHERE titulo_id = v_tit AND situacao IN ('prevista', 'firme') AND valor_liquidado = 0;
            IF NOT EXISTS (SELECT 1 FROM public.financeiro_parcelas WHERE titulo_id = v_tit AND situacao IN ('prevista', 'firme')) THEN
                UPDATE public.financeiro_titulos SET cancelado_em = coalesce(cancelado_em, now()),
                       motivo_cancelamento = coalesce(motivo_cancelamento, 'Pedido ' || p.status || ' no Compras') WHERE id = v_tit;
            END IF;
        END IF;
        RETURN;
    END IF;

    SELECT coalesce(sum(n.valor), 0) INTO v_consumido FROM public.notas_fiscais_compra n WHERE n.pedido_compra_id = p.id AND n.cancelada_em IS NULL;
    v_consumido := v_consumido + coalesce((SELECT sum(a.valor - coalesce((SELECT sum(x.valor_aplicado) FROM public.pagamento_antecipado_vinculos x WHERE x.pagamento_id = a.id), 0))
                                             FROM public.pagamentos_antecipados a WHERE a.pedido_compra_id = p.id AND a.cancelado_em IS NULL), 0);
    SELECT coalesce(parcelas_pagas, false) INTO v_pagas FROM public.financeiro_pedido_pagamento_confirmacao WHERE pedido_id = p.id;
    v_pagas := coalesce(v_pagas, false);

    -- previsão desejada = restante de cada parcela (mesma conta da view antiga); sem tabela temporária (o gatilho roda no fim da transação)
    v_des := '[]'::jsonb;
    IF NOT v_pagas THEN
        SELECT coalesce(jsonb_agg(jsonb_build_object('numero', q.numero_parcela, 'venc', q.data_vencimento, 'valor', greatest(0, least(q.valor, q.acum - v_consumido))::numeric(14,2),
                                                     'forma', q.forma_pagamento::text) ORDER BY q.numero_parcela), '[]'::jsonb)
          INTO v_des
          FROM (SELECT x.*, sum(x.valor) OVER (ORDER BY x.numero_parcela ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS acum
                  FROM public.pedido_compra_parcelas x WHERE x.pedido_id = p.id AND x.status <> 'cancelado') q
         WHERE q.status IN ('pendente', 'atrasado') AND q.data_vencimento IS NOT NULL AND greatest(0, least(q.valor, q.acum - v_consumido)) > 0;
    END IF;

    IF v_tit IS NULL AND jsonb_array_length(v_des) = 0 THEN RETURN; END IF;
    IF v_tit IS NULL THEN
        INSERT INTO public.financeiro_titulos (natureza, origem_tipo, pedido_compra_id, especie, empresa_id, perfil, contato_id, plano_contas_id, documento, descricao)
        VALUES ('pagar', 'pedido_compra', p.id, 'compra', p.empresa_id, CASE WHEN p.perfil IN ('ribeirao', 'sao_paulo') THEN p.perfil END,
                p.fornecedor_id, public.financeiro_plano_compras(), p.numero, 'Pedido de compra ' || p.numero)
        RETURNING id INTO v_tit;
    ELSE
        UPDATE public.financeiro_titulos SET cancelado_em = NULL, cancelado_por = NULL, motivo_cancelamento = NULL WHERE id = v_tit AND cancelado_em IS NOT NULL;
    END IF;

    SELECT coalesce(jsonb_agg(jsonb_build_array(vencimento, valor) ORDER BY vencimento, valor), '[]'::jsonb) INTO v_cur
      FROM public.financeiro_parcelas WHERE titulo_id = v_tit AND situacao = 'prevista';
    SELECT coalesce(jsonb_agg(jsonb_build_array(e->>'venc', (e->>'valor')::numeric) ORDER BY e->>'venc', (e->>'valor')::numeric), '[]'::jsonb) INTO v_cmp FROM jsonb_array_elements(v_des) e;
    IF v_cur IS DISTINCT FROM v_cmp THEN
        UPDATE public.financeiro_parcelas SET situacao = 'substituida' WHERE titulo_id = v_tit AND situacao = 'prevista';
        SELECT coalesce(max(numero), 0) INTO v_max FROM public.financeiro_parcelas WHERE titulo_id = v_tit;
        FOR r IN SELECT e FROM jsonb_array_elements(v_des) e LOOP
            v_n := v_n + 1;
            INSERT INTO public.financeiro_parcelas (titulo_id, numero, vencimento, valor, situacao, forma_prevista, observacao)
            VALUES (v_tit, v_max + v_n, (r.e->>'venc')::date, (r.e->>'valor')::numeric, 'prevista', r.e->>'forma', 'Previsão do pedido ' || p.numero || ' (parcela ' || (r.e->>'numero') || ')');
        END LOOP;
    END IF;
END $f$;

-- ===================================================================== NOTA DE ENTRADA
CREATE OR REPLACE FUNCTION public.financeiro_ponte_nota(p_nota uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
DECLARE
    n public.notas_fiscais_compra; p public.pedidos_compra; v_tit uuid; v_par uuid; v_emp uuid; v_dup boolean; np record; b record; v_liq numeric; v_sit public.fin_situacao;
    v_pg uuid; v_baixa uuid; v_digits text;
BEGIN
    SELECT * INTO n FROM public.notas_fiscais_compra WHERE id = p_nota;
    IF NOT FOUND THEN RETURN; END IF;
    SELECT * INTO p FROM public.pedidos_compra WHERE id = n.pedido_compra_id;
    v_emp := coalesce(n.empresa_id, p.empresa_id);

    -- mesma exclusão da view antiga: nota que a Connect já lançou como duplicata não vira título novo (evita contar em dobro)
    v_digits := nullif(regexp_replace(n.numero_nf, '\D', '', 'g'), '');
    v_dup := v_digits IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.negociacoes g WHERE g.tipo = 'despesa' AND g.empresa_id = v_emp AND g.num_nota::numeric = v_digits::numeric
           AND abs(coalesce((SELECT sum(t.vl_parcela) FROM public.transacoes t WHERE t.negociacao_id = g.id AND t.status_pago <> 2), 0) - n.valor) <= 1);

    SELECT id INTO v_tit FROM public.financeiro_titulos WHERE origem_tipo = 'nota_fiscal_compra' AND nota_fiscal_compra_id = n.id AND origem_seq = 1;
    IF v_tit IS NULL AND (v_dup OR n.cancelada_em IS NOT NULL) THEN
        IF n.pedido_compra_id IS NOT NULL THEN PERFORM public.financeiro_ponte_pedido(n.pedido_compra_id); END IF;
        RETURN;
    END IF;

    IF v_tit IS NULL THEN
        IF NOT EXISTS (SELECT 1 FROM public.nota_fiscal_compra_parcelas WHERE nota_id = n.id) THEN RETURN; END IF;
        INSERT INTO public.financeiro_titulos (natureza, origem_tipo, nota_fiscal_compra_id, especie, empresa_id, perfil, contato_id, plano_contas_id, documento, descricao)
        VALUES ('pagar', 'nota_fiscal_compra', n.id, 'nota_compra', v_emp, CASE WHEN p.perfil IN ('ribeirao', 'sao_paulo') THEN p.perfil END,
                coalesce(n.fornecedor_id, p.fornecedor_id), coalesce(n.plano_contas_id, public.financeiro_plano_compras()), n.numero_nf,
                'NF ' || n.numero_nf || coalesce(' (pedido ' || p.numero || ')', ''))
        RETURNING id INTO v_tit;
    END IF;

    -- nota cancelada: cancela o título (se nada foi pago)
    IF n.cancelada_em IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM public.financeiro_parcelas WHERE titulo_id = v_tit AND valor_liquidado <> 0) THEN
            RAISE EXCEPTION 'Nota cancelada com parcela já paga no modelo novo: estornar antes.';
        END IF;
        UPDATE public.financeiro_parcelas SET situacao = 'cancelada' WHERE titulo_id = v_tit AND situacao IN ('prevista', 'firme');
        UPDATE public.financeiro_titulos SET cancelado_em = coalesce(cancelado_em, now()), motivo_cancelamento = coalesce(motivo_cancelamento, 'Nota cancelada no Compras') WHERE id = v_tit;
        IF n.pedido_compra_id IS NOT NULL THEN PERFORM public.financeiro_ponte_pedido(n.pedido_compra_id); END IF;
        RETURN;
    END IF;

    FOR np IN SELECT * FROM public.nota_fiscal_compra_parcelas WHERE nota_id = n.id ORDER BY numero_parcela LOOP
        SELECT id_novo INTO v_par FROM public.financeiro_legado_ids WHERE tabela_antiga = 'nota_fiscal_compra_parcelas' AND id_antigo = np.id;
        IF v_par IS NULL THEN
            INSERT INTO public.financeiro_parcelas (titulo_id, numero, vencimento, valor, situacao, confirmada_em, emissao, descricao)
            VALUES (v_tit, np.numero_parcela, np.data_vencimento, np.valor, 'firme', now(), n.data_emissao, 'NF ' || n.numero_nf || ' parcela ' || np.numero_parcela)
            RETURNING id INTO v_par;
            INSERT INTO public.financeiro_legado_ids (tabela_antiga, id_antigo, tabela_nova, id_novo) VALUES ('nota_fiscal_compra_parcelas', np.id, 'financeiro_parcelas', v_par);
        END IF;
        SELECT situacao, valor_liquidado INTO v_sit, v_liq FROM public.financeiro_parcelas WHERE id = v_par;
        IF v_sit = 'cancelada' AND v_liq = 0 THEN
            UPDATE public.financeiro_parcelas SET situacao = 'firme' WHERE id = v_par; v_sit := 'firme';
        END IF;
        IF v_sit = 'firme' AND v_liq = 0 THEN
            UPDATE public.financeiro_parcelas SET valor = np.valor, vencimento = np.data_vencimento WHERE id = v_par AND (valor <> np.valor OR vencimento <> np.data_vencimento);
        END IF;

        -- pagamento: boleto CP da parcela
        SELECT * INTO b FROM public.boletos WHERE nosso_numero = 'NFC-' || np.id::text AND tipo_operacao = 'CP' LIMIT 1;
        IF FOUND AND v_sit = 'firme' THEN
            IF b.status = 'Pago' AND v_liq = 0 THEN
                INSERT INTO public.financeiro_baixas (parcela_id, tipo, data, valor, juros, forma, conta_bancaria_id, comprovante_url, origem_baixa)
                VALUES (v_par, 'pagamento', coalesce(b.data_pagamento, current_date), least(coalesce(b.valor_pago, b.valor), np.valor), greatest(coalesce(b.valor_pago, b.valor) - np.valor, 0),
                        nullif(b.forma_pagamento::text, ''), b.conta_bancaria_id, b.comprovante_url, 'ponte')
                RETURNING id INTO v_baixa;
                IF b.conta_bancaria_id IS NULL THEN
                    INSERT INTO public.financeiro_pendencias (baixa_id, tipo, descricao, responsavel)
                    VALUES (v_baixa, 'baixa_sem_conta_bancaria', 'Pagamento da nota sem conta bancária: informar a conta.', 'Financeiro');
                END IF;
                IF coalesce(b.valor_pago, b.valor) < np.valor THEN
                    INSERT INTO public.financeiro_baixas (parcela_id, tipo, data, valor, motivo, origem_baixa)
                    VALUES (v_par, 'abatimento', coalesce(b.data_pagamento, current_date), np.valor - coalesce(b.valor_pago, b.valor), 'Diferença entre o valor da parcela e o valor pago', 'ponte');
                END IF;
            ELSIF b.status <> 'Pago' AND v_liq <> 0 THEN
                INSERT INTO public.financeiro_baixas (parcela_id, tipo, data, valor, forma, conta_bancaria_id, motivo, origem_baixa, estorno_de)
                SELECT x.parcela_id, 'estorno', current_date, x.valor, x.forma, x.conta_bancaria_id, 'Pagamento desfeito no Compras/boleto', 'ponte', x.id
                  FROM public.financeiro_baixas x WHERE x.parcela_id = v_par AND x.tipo <> 'estorno' AND NOT EXISTS (SELECT 1 FROM public.financeiro_baixas e WHERE e.estorno_de = x.id);
            END IF;
        END IF;
    END LOOP;

    IF n.pedido_compra_id IS NOT NULL THEN PERFORM public.financeiro_ponte_pedido(n.pedido_compra_id); END IF;
END $f$;

-- ===================================================================== POP-UP: "as parcelas desse pedido já foram pagas?"
CREATE OR REPLACE FUNCTION public.financeiro_pedido_pergunta(p_pedido uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $f$
DECLARE v_status text; v_precisa boolean; v_parc jsonb; v_tit uuid;
BEGIN
    IF auth.uid() IS NOT NULL AND NOT (public.pode_acessar_sistema('financeiro') OR public.pode_acessar_sistema('necessidade-de-compra')) THEN
        RAISE EXCEPTION 'Sem permissão.' USING ERRCODE = '42501';
    END IF;
    SELECT status INTO v_status FROM public.pedidos_compra WHERE id = p_pedido;
    SELECT id INTO v_tit FROM public.financeiro_titulos WHERE origem_tipo = 'pedido_compra' AND pedido_compra_id = p_pedido AND origem_seq = 1 AND cancelado_em IS NULL;
    SELECT coalesce(jsonb_agg(jsonb_build_object('numero', p.numero, 'vencimento', p.vencimento, 'valor', p.valor) ORDER BY p.vencimento, p.numero), '[]'::jsonb)
      INTO v_parc FROM public.financeiro_parcelas p WHERE p.titulo_id = v_tit AND p.situacao = 'prevista';
    v_precisa := v_status = 'recebido' AND v_tit IS NOT NULL AND jsonb_array_length(v_parc) > 0
                 AND NOT EXISTS (SELECT 1 FROM public.financeiro_pedido_pagamento_confirmacao c WHERE c.pedido_id = p_pedido);
    RETURN jsonb_build_object('pedido_id', p_pedido, 'status', v_status, 'perguntar', coalesce(v_precisa, false), 'parcelas_previstas', v_parc);
END $f$;

CREATE OR REPLACE FUNCTION public.financeiro_responder_pedido_pago(p_pedido uuid, p_pagas boolean, p_data date DEFAULT NULL, p_conta uuid DEFAULT NULL, p_obs text DEFAULT NULL) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
DECLARE v_tit uuid; r record; v_n int := 0; v_baixa uuid; v_status text;
BEGIN
    IF auth.uid() IS NOT NULL AND NOT (public.pode_acessar_sistema('financeiro') OR public.pode_acessar_sistema('necessidade-de-compra')) THEN
        RAISE EXCEPTION 'Sem permissão.' USING ERRCODE = '42501';
    END IF;
    SELECT status INTO v_status FROM public.pedidos_compra WHERE id = p_pedido;
    IF v_status IS NULL THEN RAISE EXCEPTION 'Pedido inexistente.' USING ERRCODE = 'P0001'; END IF;
    IF EXISTS (SELECT 1 FROM public.financeiro_pedido_pagamento_confirmacao WHERE pedido_id = p_pedido) THEN
        RAISE EXCEPTION 'Este pedido já teve a pergunta respondida.' USING ERRCODE = 'P0001';
    END IF;
    IF p_pagas AND p_data IS NULL THEN RAISE EXCEPTION 'Informe a data do pagamento.' USING ERRCODE = 'P0001'; END IF;
    PERFORM public.financeiro_ponte_pedido(p_pedido);
    SELECT id INTO v_tit FROM public.financeiro_titulos WHERE origem_tipo = 'pedido_compra' AND pedido_compra_id = p_pedido AND origem_seq = 1;
    INSERT INTO public.financeiro_pedido_pagamento_confirmacao (pedido_id, parcelas_pagas, data_pagamento, conta_bancaria_id, observacao, respondido_por)
    VALUES (p_pedido, p_pagas, p_data, p_conta, p_obs, auth.uid());
    IF p_pagas AND v_tit IS NOT NULL THEN
        FOR r IN SELECT id, valor FROM public.financeiro_parcelas WHERE titulo_id = v_tit AND situacao = 'prevista' ORDER BY numero LOOP
            UPDATE public.financeiro_parcelas SET situacao = 'firme', confirmada_em = now(), confirmada_por = auth.uid() WHERE id = r.id;
            INSERT INTO public.financeiro_baixas (parcela_id, tipo, data, valor, conta_bancaria_id, motivo, origem_baixa, criado_por)
            VALUES (r.id, 'pagamento', p_data, r.valor, p_conta, 'Informado no Compras ao receber o pedido: parcelas já pagas' || coalesce(' — ' || p_obs, ''),
                    CASE WHEN p_conta IS NULL THEN 'ponte' ELSE 'manual' END, auth.uid())
            RETURNING id INTO v_baixa;
            IF p_conta IS NULL THEN
                INSERT INTO public.financeiro_pendencias (baixa_id, tipo, descricao, responsavel)
                VALUES (v_baixa, 'baixa_sem_conta_bancaria', 'Pagamento informado no Compras sem conta bancária: informar a conta.', 'Financeiro');
            END IF;
            v_n := v_n + 1;
        END LOOP;
    END IF;
    RETURN v_n;
END $f$;

-- ===================================================================== gatilhos (adiados para o fim da transação; nunca bloqueiam)
CREATE OR REPLACE FUNCTION public.trg_financeiro_ponte_pagar() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
DECLARE v_id uuid; v_nota uuid;
BEGIN
    BEGIN
        IF TG_TABLE_NAME = 'pedidos_compra' THEN v_id := NEW.id; PERFORM public.financeiro_ponte_pedido(v_id);
        ELSIF TG_TABLE_NAME = 'pedido_compra_parcelas' THEN v_id := coalesce(NEW.pedido_id, OLD.pedido_id); PERFORM public.financeiro_ponte_pedido(v_id);
        ELSIF TG_TABLE_NAME = 'notas_fiscais_compra' THEN v_id := NEW.id; PERFORM public.financeiro_ponte_nota(v_id);
        ELSIF TG_TABLE_NAME = 'nota_fiscal_compra_parcelas' THEN v_id := coalesce(NEW.nota_id, OLD.nota_id); PERFORM public.financeiro_ponte_nota(v_id);
        ELSIF TG_TABLE_NAME = 'boletos' THEN
            v_id := NEW.id;
            SELECT n.id INTO v_nota FROM public.notas_fiscais_compra n WHERE n.id = NEW.conta_grupo_id;
            IF v_nota IS NOT NULL THEN PERFORM public.financeiro_ponte_nota(v_nota); END IF;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO public.financeiro_ponte_falhas (transacao_id, erro, origem) VALUES (coalesce(v_id, gen_random_uuid()), left(SQLERRM, 500), TG_TABLE_NAME);
    END;
    RETURN NULL;
END $f$;

CREATE CONSTRAINT TRIGGER trg_fin_ponte_pedido AFTER INSERT OR UPDATE OF status, cancelado_em, empresa_id, fornecedor_id ON public.pedidos_compra
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.trg_financeiro_ponte_pagar();
CREATE CONSTRAINT TRIGGER trg_fin_ponte_pedido_parcela AFTER INSERT OR UPDATE OR DELETE ON public.pedido_compra_parcelas
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.trg_financeiro_ponte_pagar();
CREATE CONSTRAINT TRIGGER trg_fin_ponte_nota AFTER INSERT OR UPDATE ON public.notas_fiscais_compra
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.trg_financeiro_ponte_pagar();
CREATE CONSTRAINT TRIGGER trg_fin_ponte_nota_parcela AFTER INSERT OR UPDATE OR DELETE ON public.nota_fiscal_compra_parcelas
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.trg_financeiro_ponte_pagar();
CREATE CONSTRAINT TRIGGER trg_fin_ponte_boleto_cp AFTER INSERT OR UPDATE OF status, valor_pago, data_pagamento, conta_bancaria_id ON public.boletos
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW WHEN (NEW.tipo_operacao = 'CP' AND NEW.nosso_numero LIKE 'NFC-%') EXECUTE FUNCTION public.trg_financeiro_ponte_pagar();

REVOKE ALL ON FUNCTION public.financeiro_ponte_pedido(uuid), public.financeiro_ponte_nota(uuid), public.trg_financeiro_ponte_pagar() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.financeiro_pedido_pergunta(uuid), public.financeiro_responder_pedido_pago(uuid, boolean, date, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.financeiro_pedido_pergunta(uuid), public.financeiro_responder_pedido_pago(uuid, boolean, date, uuid, text) TO authenticated, service_role;

-- ===================================================================== o que já existe
DO $$ DECLARE r record; BEGIN
    FOR r IN SELECT id FROM public.notas_fiscais_compra ORDER BY criado_em LOOP
        BEGIN PERFORM public.financeiro_ponte_nota(r.id);
        EXCEPTION WHEN OTHERS THEN INSERT INTO public.financeiro_ponte_falhas (transacao_id, erro, origem) VALUES (r.id, left(SQLERRM, 500), 'notas_fiscais_compra'); END;
    END LOOP;
    FOR r IN SELECT id FROM public.pedidos_compra ORDER BY criado_em LOOP
        BEGIN PERFORM public.financeiro_ponte_pedido(r.id);
        EXCEPTION WHEN OTHERS THEN INSERT INTO public.financeiro_ponte_falhas (transacao_id, erro, origem) VALUES (r.id, left(SQLERRM, 500), 'pedidos_compra'); END;
    END LOOP;
END $$;

-- ===================================================================== integridade do a pagar nativo (tudo 0)
CREATE OR REPLACE VIEW public.vw_financeiro_ponte_pagar_integridade AS
SELECT teste, violacoes FROM (
    SELECT 'a pagar: falhas do espelho abertas'::text AS teste, count(*)::bigint AS violacoes FROM public.financeiro_ponte_falhas WHERE resolvida_em IS NULL AND origem <> 'transacoes'
    UNION ALL SELECT 'a pagar: pedido com previsao diferente da view antiga (aprovado/parcial)', count(*) FROM (
        SELECT coalesce(o.pid, nv.pid) FROM (SELECT pedido_compra_id AS pid, round(sum(vl_parcela), 2) AS v FROM public.vw_contas_pagar_pedidos_compra WHERE origem = 'pedido_compra' GROUP BY 1) o
        FULL JOIN (SELECT t.pedido_compra_id AS pid, round(sum(p.valor), 2) AS v FROM public.financeiro_parcelas p JOIN public.financeiro_titulos t ON t.id = p.titulo_id
                    JOIN public.pedidos_compra pc ON pc.id = t.pedido_compra_id WHERE t.origem_tipo = 'pedido_compra' AND p.situacao = 'prevista' AND pc.status IN ('aprovado', 'parcialmente_recebido') GROUP BY 1) nv ON nv.pid = o.pid
        WHERE o.v IS DISTINCT FROM nv.v) d
    UNION ALL SELECT 'a pagar: nota ativa sem titulo (fora a ja lancada pela Connect)', count(*) FROM public.notas_fiscais_compra n
        WHERE n.cancelada_em IS NULL AND EXISTS (SELECT 1 FROM public.nota_fiscal_compra_parcelas x WHERE x.nota_id = n.id)
          AND NOT EXISTS (SELECT 1 FROM public.financeiro_titulos t WHERE t.origem_tipo = 'nota_fiscal_compra' AND t.nota_fiscal_compra_id = n.id)
          AND NOT EXISTS (SELECT 1 FROM public.negociacoes g WHERE g.tipo = 'despesa' AND g.empresa_id = coalesce(n.empresa_id, (SELECT empresa_id FROM public.pedidos_compra WHERE id = n.pedido_compra_id))
                           AND g.num_nota::numeric = nullif(regexp_replace(n.numero_nf, '\D', '', 'g'), '')::numeric
                           AND abs(coalesce((SELECT sum(t.vl_parcela) FROM public.transacoes t WHERE t.negociacao_id = g.id AND t.status_pago <> 2), 0) - n.valor) <= 1)
    UNION ALL SELECT 'a pagar: boleto CP pago sem baixa no modelo novo', count(*) FROM public.boletos b
        JOIN public.financeiro_legado_ids l ON l.tabela_antiga = 'nota_fiscal_compra_parcelas' AND 'NFC-' || l.id_antigo::text = b.nosso_numero
        JOIN public.financeiro_parcelas p ON p.id = l.id_novo
        WHERE b.tipo_operacao = 'CP' AND b.status = 'Pago' AND p.situacao = 'firme' AND p.valor_liquidado = 0
    UNION ALL SELECT 'a pagar: pagamento antecipado ainda sem espelho (fase 4b-2)', count(*) FROM public.pagamentos_antecipados WHERE cancelado_em IS NULL
    UNION ALL SELECT 'a pagar: pedido recebido com previsao e pergunta sem resposta (informativo)', count(*) FROM public.financeiro_titulos t
        JOIN public.pedidos_compra pc ON pc.id = t.pedido_compra_id
        WHERE t.origem_tipo = 'pedido_compra' AND t.cancelado_em IS NULL AND pc.status = 'recebido' AND EXISTS (SELECT 1 FROM public.financeiro_parcelas p WHERE p.titulo_id = t.id AND p.situacao = 'prevista')
          AND NOT EXISTS (SELECT 1 FROM public.financeiro_pedido_pagamento_confirmacao c WHERE c.pedido_id = pc.id)
) z WHERE (SELECT public.pode_acessar_sistema('financeiro'));
GRANT SELECT ON public.vw_financeiro_ponte_pagar_integridade TO authenticated;
REVOKE ALL ON public.vw_financeiro_ponte_pagar_integridade FROM anon;
