-- SPEC-258 Fase 5c: a coluna desconto da vw_financeiro_duplicatas passa a mostrar o desconto concedido na baixa.
-- Achado no teste em tela (07/11): baixa nativa com desconto grava um 'abatimento' em financeiro_baixas e deixa parcelas.desconto = 0,
-- entao a grade mostrava desconto 0. No legado copiado o desconto esta nos DOIS lugares (105 parcelas): por isso usa o MAIOR dos dois
-- (nunca soma, para nao contar em dobro) e o abatimento estornado sai (estorno de abatimento entra negativo).
-- Aditivo: so muda o valor da coluna desconto; nomes, ordem e tipos das colunas ficam iguais.

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
       greatest(p.desconto, b.abatimento)::numeric(14,2) AS desconto,
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
       p.legado_cod_itens_duplicata,
       coalesce(
           (SELECT bo.id FROM public.financeiro_legado_ids lt JOIN public.transacoes tx ON tx.id = lt.id_antigo
              JOIN public.boletos bo ON bo.parcela_id = tx.parcela_id
             WHERE lt.id_novo = p.id AND lt.tabela_antiga = 'transacoes' AND tx.parcela_id IS NOT NULL LIMIT 1),
           (SELECT bo.id FROM public.financeiro_legado_ids ln2 JOIN public.boletos bo ON bo.nosso_numero = 'NFC-' || ln2.id_antigo::text
             WHERE ln2.id_novo = p.id AND ln2.tabela_antiga = 'nota_fiscal_compra_parcelas' LIMIT 1)
       ) AS boleto_id
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
           coalesce(sum(CASE WHEN bx.tipo = 'abatimento' THEN bx.valor WHEN bx.tipo = 'estorno' AND ox.tipo = 'abatimento' THEN -bx.valor ELSE 0 END), 0) AS abatimento,
           (array_agg(bx.forma ORDER BY bx.criado_em DESC) FILTER (WHERE bx.tipo <> 'estorno'))[1] AS forma
    FROM public.financeiro_baixas bx LEFT JOIN public.financeiro_baixas ox ON ox.id = bx.estorno_de
    WHERE bx.parcela_id = p.id
) b ON true;
