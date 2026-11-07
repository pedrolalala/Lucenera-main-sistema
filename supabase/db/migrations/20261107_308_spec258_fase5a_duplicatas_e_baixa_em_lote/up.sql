-- SPEC-258 Fase 5a: camada de banco para as telas Contas a Pagar / Contas a Receber passarem a usar o modelo novo.
--  * vw_financeiro_duplicatas: UMA lista (legado da Connect + nativo) no formato que as telas já montam hoje juntando boletos + transacoes.
--  * financeiro_baixar_lote: dá baixa em várias parcelas de uma vez (juros e desconto iguais para todas, como a tela Baixar Duplicata faz hoje).
--    Resolve o buraco atual: as duplicatas da Connect eram "só consulta" (a baixa vinha da planilha do dia) e a carga de 05/11 foi a última.
-- Aditivo: nada antigo é alterado.

CREATE OR REPLACE VIEW public.vw_financeiro_duplicatas WITH (security_invoker = true) AS
SELECT p.id AS parcela_id,
       t.id AS titulo_id,
       t.natureza,
       CASE WHEN t.natureza = 'pagar' THEN 'CP' ELSE 'CR' END AS tipo_operacao,
       CASE WHEN coalesce(n.num_nota::text, '') <> '' OR t.origem_tipo = 'nota_fiscal_compra' THEN 'Nota Fiscal' ELSE 'Normal' END AS tipo,
       CASE WHEN p.situacao IN ('cancelada', 'substituida', 'renegociada') THEN 'Cancelado'
            WHEN b.n_baixas > 0 AND p.valor_liquidado >= p.valor THEN 'Pago'
            WHEN p.situacao = 'prevista' THEN 'Previsto'
            ELSE 'Pendente' END AS status,
       p.situacao,
       coalesce(t.legado_cod_duplicata::text, t.documento, o.numero_venda, o.numero, '') AS numero_documento,
       p.numero AS num_parcela,
       (SELECT count(*) FROM public.financeiro_parcelas x WHERE x.titulo_id = t.id AND x.situacao IN ('prevista', 'firme')) AS total_parcelas,
       coalesce(n.cod_venda::text, o.numero_venda, '') AS venda,
       coalesce(n.num_nota::text, CASE WHEN t.origem_tipo = 'nota_fiscal_compra' THEN t.documento END, '') AS fatura,
       coalesce(nullif(n.nome_pessoa, ''), nullif(n.razao_pessoa, ''), c.nome, CASE WHEN n.cod_pessoa IS NOT NULL THEN 'Pessoa ' || n.cod_pessoa END, '') AS nome_pagador,
       p.emissao AS emissao,
       p.vencimento AS vencimento,
       CASE WHEN b.n_baixas > 0 AND p.valor_liquidado >= p.valor THEN b.ultima_data END AS data_pagamento,
       p.valor AS valor,
       CASE WHEN b.n_baixas > 0 AND p.valor_liquidado >= p.valor THEN b.dinheiro ELSE 0 END AS valor_pago,
       b.juros_multa,
       p.desconto AS desconto,
       coalesce(b.forma, p.forma_prevista) AS forma_pagamento,
       coalesce(p.descricao, t.descricao) AS observacao,
       t.perfil,
       e.nome AS empresa_nome,
       t.empresa_id,
       t.contato_id,
       t.plano_contas_id,
       pc.nome AS plano_contas_nome,
       t.projeto_id,
       t.origem_tipo,
       t.especie,
       p.valor_liquidado,
       (p.valor - p.valor_liquidado) AS saldo,
       t.legado_cod_duplicata,
       p.legado_cod_itens_duplicata
FROM public.financeiro_parcelas p
JOIN public.financeiro_titulos t ON t.id = p.titulo_id
LEFT JOIN public.financeiro_legado_ids ln ON ln.tabela_antiga = 'negociacoes' AND ln.id_novo = t.id
LEFT JOIN public.negociacoes n ON n.id = ln.id_antigo
LEFT JOIN public.orcamentos o ON o.id = t.orcamento_id
LEFT JOIN public.contatos c ON c.id = t.contato_id
LEFT JOIN public.empresas e ON e.id = t.empresa_id
LEFT JOIN public.plano_de_contas pc ON pc.id = t.plano_contas_id
LEFT JOIN LATERAL (
    SELECT count(*) FILTER (WHERE bx.tipo <> 'estorno') AS n_baixas,
           max(bx.data) FILTER (WHERE bx.tipo <> 'estorno') AS ultima_data,
           coalesce(sum(CASE WHEN bx.movimenta_caixa THEN bx.valor + bx.juros
                             WHEN bx.tipo = 'estorno' AND ox.movimenta_caixa THEN -(ox.valor + ox.juros) ELSE 0 END), 0) AS dinheiro,
           coalesce(sum(CASE WHEN bx.movimenta_caixa THEN bx.juros + bx.multa WHEN bx.tipo = 'estorno' AND ox.movimenta_caixa THEN -(ox.juros + ox.multa) ELSE 0 END), 0) AS juros_multa,
           (array_agg(bx.forma ORDER BY bx.criado_em DESC) FILTER (WHERE bx.tipo <> 'estorno'))[1] AS forma
    FROM public.financeiro_baixas bx LEFT JOIN public.financeiro_baixas ox ON ox.id = bx.estorno_de
    WHERE bx.parcela_id = p.id
) b ON true;

GRANT SELECT ON public.vw_financeiro_duplicatas TO authenticated;
REVOKE ALL ON public.vw_financeiro_duplicatas FROM anon;

-- baixa em lote: juros e desconto IGUAIS para cada parcela escolhida (como a tela atual). Tudo ou nada.
-- Desconto: o cliente/fornecedor paga menos; a parcela fecha com a diferença como abatimento. Conta de outra empresa vira empresa_pagadora (não recusa).
CREATE OR REPLACE FUNCTION public.financeiro_baixar_lote(
    p_parcelas uuid[], p_data date, p_forma text, p_conta uuid, p_juros numeric DEFAULT 0, p_desconto numeric DEFAULT 0,
    p_comprovante_url text DEFAULT NULL, p_observacao text DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
DECLARE
    v_id uuid; r record; v_saldo numeric; v_desc numeric; v_cash numeric; v_conta_emp uuid; v_n int := 0; v_total numeric := 0; v_baixas uuid[] := '{}'; v_b uuid;
BEGIN
    IF p_parcelas IS NULL OR coalesce(array_length(p_parcelas, 1), 0) = 0 THEN RAISE EXCEPTION 'Nenhuma parcela escolhida.' USING ERRCODE = 'P0001'; END IF;
    IF p_conta IS NULL THEN RAISE EXCEPTION 'Informe a conta bancária.' USING ERRCODE = 'P0001'; END IF;
    IF p_data IS NULL THEN RAISE EXCEPTION 'Informe a data do pagamento.' USING ERRCODE = 'P0001'; END IF;
    IF coalesce(p_juros, 0) < 0 OR coalesce(p_desconto, 0) < 0 THEN RAISE EXCEPTION 'Juros e desconto não podem ser negativos.' USING ERRCODE = 'P0001'; END IF;
    SELECT empresa_id INTO v_conta_emp FROM public.contas_bancarias WHERE id = p_conta;
    IF NOT FOUND THEN RAISE EXCEPTION 'Conta bancária inexistente.' USING ERRCODE = 'P0001'; END IF;

    FOR r IN SELECT p.id, p.valor, p.valor_liquidado, p.situacao, t.natureza, t.especie, t.empresa_id, t.cancelado_em
               FROM public.financeiro_parcelas p JOIN public.financeiro_titulos t ON t.id = p.titulo_id
              WHERE p.id = ANY (p_parcelas) ORDER BY p.vencimento, p.numero FOR UPDATE OF p LOOP
        PERFORM public.financeiro_exige(r.especie);
        IF r.cancelado_em IS NOT NULL OR r.situacao <> 'firme' THEN
            RAISE EXCEPTION 'Parcela % não pode ser baixada (situação: %).', r.id, r.situacao USING ERRCODE = 'P0001';
        END IF;
        v_saldo := r.valor - r.valor_liquidado;
        IF v_saldo <= 0 THEN RAISE EXCEPTION 'Parcela % já está quitada.', r.id USING ERRCODE = 'P0001'; END IF;
        v_desc := least(coalesce(p_desconto, 0), v_saldo);
        v_cash := v_saldo - v_desc;
        IF v_cash > 0 THEN
            INSERT INTO public.financeiro_baixas (parcela_id, tipo, data, valor, juros, desconto, forma, conta_bancaria_id, empresa_pagadora_id, comprovante_url, motivo, origem_baixa, criado_por)
            VALUES (r.id, CASE WHEN r.natureza = 'receber' THEN 'recebimento'::public.fin_baixa_tipo ELSE 'pagamento'::public.fin_baixa_tipo END,
                    p_data, v_cash, coalesce(p_juros, 0), v_desc, nullif(p_forma, ''), p_conta,
                    CASE WHEN v_conta_emp IS NOT NULL AND v_conta_emp <> r.empresa_id THEN v_conta_emp END, p_comprovante_url, p_observacao, 'manual', auth.uid())
            RETURNING id INTO v_b;
            v_baixas := v_baixas || v_b;
        END IF;
        IF v_desc > 0 THEN
            INSERT INTO public.financeiro_baixas (parcela_id, tipo, data, valor, forma, motivo, origem_baixa, criado_por)
            VALUES (r.id, 'abatimento', p_data, v_desc, nullif(p_forma, ''), 'Desconto concedido na baixa' || coalesce(' — ' || p_observacao, ''), 'manual', auth.uid())
            RETURNING id INTO v_b;
            v_baixas := v_baixas || v_b;
        END IF;
        v_n := v_n + 1;
        v_total := v_total + v_cash + coalesce(p_juros, 0);
    END LOOP;
    IF v_n <> (SELECT count(DISTINCT x) FROM unnest(p_parcelas) x) THEN RAISE EXCEPTION 'Alguma parcela escolhida não existe.' USING ERRCODE = 'P0001'; END IF;
    RETURN jsonb_build_object('parcelas', v_n, 'dinheiro_total', v_total, 'baixas', to_jsonb(v_baixas));
END $f$;
REVOKE ALL ON FUNCTION public.financeiro_baixar_lote(uuid[], date, text, uuid, numeric, numeric, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.financeiro_baixar_lote(uuid[], date, text, uuid, numeric, numeric, text, text) TO authenticated, service_role;
