-- Entrada de NF (Debora) no Contas a Pagar: o boleto espelho da parcela saia com Duplicata = numero da NF e Fatura vazia.
-- Origem: Central de Solicitacoes a0bc76a8 ("Descritivo de fatura na entrada de nota fiscal", SPEC-284) reaberta em 17/11.
-- Causa: fn_nota_compra_parcela_gera_contas_pagar grava boletos.numero_documento = numero da NF e fatura NULL; a grade mostra o boleto
-- (parcela do modelo novo com boleto_id e escondida). A SPEC-284 so corrigiu a view do titulo.
-- Correcao: financeiro_ponte_nota sincroniza o boleto NFC-* (numero_documento = duplicata automatica do titulo, fatura = NF) + backfill.
BEGIN;

CREATE OR REPLACE FUNCTION public.financeiro_ponte_nota(p_nota uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

    -- o boleto espelho da parcela (NFC-...) e o que a grade Consultar Duplicatas mostra. Duplicata = numero automatico do titulo; Fatura = numero da NF.
    UPDATE public.boletos bo
       SET numero_documento = t.numero_duplicata::text, fatura = n.numero_nf
      FROM public.financeiro_titulos t
     WHERE t.id = v_tit AND t.numero_duplicata IS NOT NULL
       AND bo.conta_grupo_id = n.id AND bo.tipo_operacao = 'CP' AND bo.nosso_numero LIKE 'NFC-%'
       AND (bo.numero_documento IS DISTINCT FROM t.numero_duplicata::text OR bo.fatura IS DISTINCT FROM n.numero_nf);

    IF n.pedido_compra_id IS NOT NULL THEN PERFORM public.financeiro_ponte_pedido(n.pedido_compra_id); END IF;
END $function$;

-- backfill das NFs ja lancadas
UPDATE public.boletos bo
   SET numero_documento = t.numero_duplicata::text, fatura = n.numero_nf
  FROM public.notas_fiscais_compra n
  JOIN public.financeiro_titulos t ON t.origem_tipo = 'nota_fiscal_compra' AND t.nota_fiscal_compra_id = n.id AND t.origem_seq = 1
 WHERE bo.conta_grupo_id = n.id AND bo.tipo_operacao = 'CP' AND bo.nosso_numero LIKE 'NFC-%' AND t.numero_duplicata IS NOT NULL
   AND (bo.numero_documento IS DISTINCT FROM t.numero_duplicata::text OR bo.fatura IS DISTINCT FROM n.numero_nf);


SELECT 'amostra' AS k, bo.numero_documento, bo.fatura, n.numero_nf
  FROM public.boletos bo JOIN public.notas_fiscais_compra n ON n.id = bo.conta_grupo_id
 WHERE bo.nosso_numero LIKE 'NFC-%' ORDER BY n.criado_em DESC LIMIT 8;
SELECT 'ainda_iguais' AS k, count(*) FROM public.boletos bo JOIN public.notas_fiscais_compra n ON n.id=bo.conta_grupo_id
 WHERE bo.nosso_numero LIKE 'NFC-%' AND bo.numero_documento = n.numero_nf;
ROLLBACK;
