-- Rollback SPEC-297: volta a view antiga e remove as 3 funcoes. A tabela backup.spec297_boletos_apagados fica (historico).
BEGIN;
DROP FUNCTION IF EXISTS public.financeiro_editar_parcela(uuid,date,numeric,text,text);
DROP FUNCTION IF EXISTS public.financeiro_apagar_parcela(uuid,text);
DROP FUNCTION IF EXISTS public.boleto_apagar_avulso(uuid,text);
CREATE OR REPLACE VIEW public.vw_financeiro_duplicatas WITH (security_invoker=true) AS
 SELECT p.id AS parcela_id,
    t.id AS titulo_id,
    t.natureza,
        CASE
            WHEN (t.natureza = 'pagar'::fin_natureza) THEN 'CP'::text
            ELSE 'CR'::text
        END AS tipo_operacao,
        CASE
            WHEN ((COALESCE((n.num_nota)::text, ''::text) <> ''::text) OR (t.origem_tipo = 'nota_fiscal_compra'::fin_origem)) THEN 'Nota Fiscal'::text
            ELSE 'Normal'::text
        END AS tipo,
        CASE
            WHEN (p.situacao = ANY (ARRAY['cancelada'::fin_situacao, 'substituida'::fin_situacao, 'renegociada'::fin_situacao])) THEN 'Cancelado'::text
            WHEN ((b.n_baixas > 0) AND (p.valor_liquidado >= p.valor)) THEN 'Pago'::text
            WHEN (p.situacao = 'prevista'::fin_situacao) THEN 'Previsto'::text
            ELSE 'Pendente'::text
        END AS status,
    p.situacao,
    COALESCE((t.legado_cod_duplicata)::text, (t.numero_duplicata)::text, t.documento, o.numero_venda, o.numero, ''::text) AS numero_documento,
    p.numero AS num_parcela,
    ( SELECT count(*) AS count
           FROM financeiro_parcelas x
          WHERE ((x.titulo_id = t.id) AND (x.situacao = ANY (ARRAY['prevista'::fin_situacao, 'firme'::fin_situacao])))) AS total_parcelas,
    COALESCE((n.cod_venda)::text, o.numero_venda, ''::text) AS venda,
    COALESCE((n.num_nota)::text,
        CASE
            WHEN (t.origem_tipo = 'nota_fiscal_compra'::fin_origem) THEN t.documento
            ELSE NULL::text
        END, ''::text) AS fatura,
    COALESCE(NULLIF(n.nome_pessoa, ''::text), NULLIF(n.razao_pessoa, ''::text), c.nome,
        CASE
            WHEN (n.cod_pessoa IS NOT NULL) THEN ('Pessoa '::text || n.cod_pessoa)
            ELSE NULL::text
        END, ''::text) AS nome_pagador,
    p.emissao,
    p.vencimento,
        CASE
            WHEN ((b.n_baixas > 0) AND (p.valor_liquidado >= p.valor)) THEN b.ultima_data
            ELSE NULL::date
        END AS data_pagamento,
    p.valor,
        CASE
            WHEN ((b.n_baixas > 0) AND (p.valor_liquidado >= p.valor)) THEN b.dinheiro
            ELSE (0)::numeric
        END AS valor_pago,
    b.juros_multa,
    (GREATEST(p.desconto, b.abatimento))::numeric(14,2) AS desconto,
    COALESCE(b.forma, p.forma_prevista) AS forma_pagamento,
    COALESCE(p.descricao, t.descricao) AS observacao,
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
    p.legado_cod_itens_duplicata,
    COALESCE(( SELECT bo.id
           FROM ((financeiro_legado_ids lt
             JOIN transacoes tx ON ((tx.id = lt.id_antigo)))
             JOIN boletos bo ON ((bo.parcela_id = tx.parcela_id)))
          WHERE ((lt.id_novo = p.id) AND (lt.tabela_antiga = 'transacoes'::text) AND (tx.parcela_id IS NOT NULL))
         LIMIT 1), ( SELECT bo.id
           FROM (financeiro_legado_ids ln2
             JOIN boletos bo ON ((bo.nosso_numero = ('NFC-'::text || (ln2.id_antigo)::text))))
          WHERE ((ln2.id_novo = p.id) AND (ln2.tabela_antiga = 'nota_fiscal_compra_parcelas'::text))
         LIMIT 1)) AS boleto_id,
    ( SELECT string_agg(((('Pedido '::text || COALESCE(v.pedido_numero, '?'::text)) || ' / NF '::text) || COALESCE(v.numero_nf, '?'::text)), '; '::text ORDER BY v.criado_em) AS string_agg
           FROM pagamento_existente_vinculos v
          WHERE ((v.parcela_id = p.id) AND (v.cancelado_em IS NULL))) AS pago_antecipado
   FROM ((((((((financeiro_parcelas p
     JOIN financeiro_titulos t ON ((t.id = p.titulo_id)))
     LEFT JOIN financeiro_legado_ids ln ON (((ln.tabela_antiga = 'negociacoes'::text) AND (ln.id_novo = t.id))))
     LEFT JOIN negociacoes n ON ((n.id = ln.id_antigo)))
     LEFT JOIN orcamentos o ON ((o.id = t.orcamento_id)))
     LEFT JOIN contatos c ON ((c.id = t.contato_id)))
     LEFT JOIN empresas e ON ((e.id = t.empresa_id)))
     LEFT JOIN plano_de_contas pc ON ((pc.id = t.plano_contas_id)))
     LEFT JOIN LATERAL ( SELECT count(*) FILTER (WHERE (bx.tipo <> 'estorno'::fin_baixa_tipo)) AS n_baixas,
            max(bx.data) FILTER (WHERE (bx.tipo <> 'estorno'::fin_baixa_tipo)) AS ultima_data,
            COALESCE(sum(
                CASE
                    WHEN bx.movimenta_caixa THEN (bx.valor + bx.juros)
                    WHEN ((bx.tipo = 'estorno'::fin_baixa_tipo) AND ox.movimenta_caixa) THEN (- (ox.valor + ox.juros))
                    ELSE (0)::numeric
                END), (0)::numeric) AS dinheiro,
            COALESCE(sum(
                CASE
                    WHEN bx.movimenta_caixa THEN (bx.juros + bx.multa)
                    WHEN ((bx.tipo = 'estorno'::fin_baixa_tipo) AND ox.movimenta_caixa) THEN (- (ox.juros + ox.multa))
                    ELSE (0)::numeric
                END), (0)::numeric) AS juros_multa,
            COALESCE(sum(
                CASE
                    WHEN (bx.tipo = 'abatimento'::fin_baixa_tipo) THEN bx.valor
                    WHEN ((bx.tipo = 'estorno'::fin_baixa_tipo) AND (ox.tipo = 'abatimento'::fin_baixa_tipo)) THEN (- bx.valor)
                    ELSE (0)::numeric
                END), (0)::numeric) AS abatimento,
            (array_agg(bx.forma ORDER BY bx.criado_em DESC) FILTER (WHERE (bx.tipo <> 'estorno'::fin_baixa_tipo)))[1] AS forma
           FROM (financeiro_baixas bx
             LEFT JOIN financeiro_baixas ox ON ((ox.id = bx.estorno_de)))
          WHERE (bx.parcela_id = p.id)) b ON (true));
COMMIT;
