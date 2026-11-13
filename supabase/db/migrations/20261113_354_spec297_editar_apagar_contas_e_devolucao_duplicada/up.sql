-- SPEC-297 (13/11/2026): Contas a Receber/Pagar.
-- A) Devolucao aparecia 2x em Consultar Duplicatas (ORC-0042-P1 = boleto "Nota de Credito" + ORC-0042 = titulo novo): a view so ligava
--    boleto a parcela pela rota das vendas (transacoes). Agora liga tambem pela rota da devolucao (financeiro_legado_ids 'projeto_parcelas'
--    -> boletos.parcela_id, tipo 'Nota de Credito'); a tela mostra so o boleto (boleto_id preenchido) e esconde a linha do financeiro.
-- B) financeiro_editar_parcela / financeiro_apagar_parcela / boleto_apagar_avulso: motivo obrigatorio, so quem acessa o financeiro,
--    nada que ja tenha baixa (estornar antes), grava em auditoria.eventos (antes/depois + motivo) e, no apagar, copia em backup.
--    "Apagar" no financeiro novo = CANCELAR (parcela/titulo ficam no historico); boleto avulso e copiado para backup e removido.
BEGIN;

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
         LIMIT 1), ( SELECT bo.id
           FROM (financeiro_legado_ids ld
             JOIN boletos bo ON (((bo.parcela_id)::text = (ld.id_antigo)::text)))
          WHERE ((ld.id_novo = p.id) AND (ld.tabela_antiga = 'projeto_parcelas'::text) AND (bo.tipo = 'Nota de Crédito'::text))
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

CREATE SCHEMA IF NOT EXISTS backup;
CREATE TABLE IF NOT EXISTS backup.spec297_boletos_apagados (
  apagado_em timestamptz NOT NULL DEFAULT now(), apagado_por uuid, motivo text NOT NULL, boleto jsonb NOT NULL
);

-- ===== editar =====
CREATE OR REPLACE FUNCTION public.financeiro_editar_parcela(p_parcela uuid, p_vencimento date, p_valor numeric, p_descricao text, p_motivo text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $f$
DECLARE p public.financeiro_parcelas; t public.financeiro_titulos; v_bol uuid; v_antes jsonb; b public.boletos;
BEGIN
  IF length(btrim(coalesce(p_motivo,''))) = 0 THEN RAISE EXCEPTION 'Informe a justificativa da alteracao.' USING ERRCODE='P0001'; END IF;
  IF p_vencimento IS NULL OR p_valor IS NULL OR p_valor = 0 THEN RAISE EXCEPTION 'Vencimento e valor (diferente de zero) sao obrigatorios.' USING ERRCODE='P0001'; END IF;
  SELECT * INTO p FROM public.financeiro_parcelas WHERE id = p_parcela FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Parcela inexistente.' USING ERRCODE='P0001'; END IF;
  SELECT * INTO t FROM public.financeiro_titulos WHERE id = p.titulo_id;
  PERFORM public.financeiro_exige(t.especie);
  IF p.situacao NOT IN ('prevista','firme') THEN RAISE EXCEPTION 'So e possivel editar parcela aberta (situacao atual: %).', p.situacao USING ERRCODE='P0001'; END IF;
  IF coalesce(p.valor_liquidado,0) <> 0 THEN RAISE EXCEPTION 'Parcela com baixa: estorne a baixa antes de editar.' USING ERRCODE='P0001'; END IF;
  IF (p_valor > 0) IS DISTINCT FROM (p.valor > 0) THEN RAISE EXCEPTION 'O valor nao pode trocar de sinal (credito x debito).' USING ERRCODE='P0001'; END IF;
  -- parcela de venda/devolucao: as pontes (transacoes / projeto_parcelas) refazem valor e vencimento a partir da origem -> a edicao seria desfeita
  -- (as contas da Connect, transacoes com cod_itens_duplicata, NAO sao reescritas pela ponte: podem ser editadas)
  IF EXISTS (SELECT 1 FROM public.financeiro_legado_ids l WHERE l.id_novo = p_parcela AND l.tabela_antiga = 'projeto_parcelas')
     OR EXISTS (SELECT 1 FROM public.financeiro_legado_ids l JOIN public.transacoes x ON x.id = l.id_antigo
                 WHERE l.id_novo = p_parcela AND l.tabela_antiga = 'transacoes' AND x.cod_itens_duplicata IS NULL) THEN
    RAISE EXCEPTION 'Conta ligada a uma venda/devolucao do sistema: nao da para editar aqui (a venda refaz o valor). Apague com justificativa e relance, ou altere pela venda.' USING ERRCODE='P0001';
  END IF;
  v_antes := jsonb_build_object('vencimento', p.vencimento, 'valor', p.valor, 'descricao', p.descricao);
  SELECT boleto_id INTO v_bol FROM public.vw_financeiro_duplicatas WHERE parcela_id = p_parcela;
  IF v_bol IS NOT NULL THEN
    SELECT * INTO b FROM public.boletos WHERE id = v_bol FOR UPDATE;
    IF b.status NOT IN ('pendente_registro','Pendente','Aberto') OR b.nosso_numero_banco IS NOT NULL OR b.remessa_sequencial IS NOT NULL
       OR EXISTS (SELECT 1 FROM public.retorno_bancario_registros r WHERE r.boleto_id = b.id)
       OR EXISTS (SELECT 1 FROM public.notas_fiscais n WHERE n.boleto_id = b.id) THEN
      RAISE EXCEPTION 'O boleto desta conta ja foi registrado/pago/usado: nao da para alterar valor/vencimento por aqui.' USING ERRCODE='P0001';
    END IF;
    UPDATE public.boletos SET vencimento = p_vencimento, valor = round(p_valor,2) WHERE id = v_bol;
  END IF;
  UPDATE public.financeiro_parcelas SET vencimento = p_vencimento, valor = round(p_valor,2), descricao = nullif(btrim(p_descricao),'') WHERE id = p_parcela;
  PERFORM auditoria.inserir(auth.uid(), 'financeiro', 'editou_conta', 'financeiro_parcelas', p_parcela::text, coalesce(t.documento, t.descricao),
    jsonb_build_object('motivo', btrim(p_motivo), 'antes', v_antes,
                       'depois', jsonb_build_object('vencimento', p_vencimento, 'valor', p_valor, 'descricao', nullif(btrim(p_descricao),'')),
                       'natureza', t.natureza, 'boleto_id', v_bol));
END $f$;

-- ===== apagar (cancelar) parcela do financeiro novo =====
CREATE OR REPLACE FUNCTION public.financeiro_apagar_parcela(p_parcela uuid, p_motivo text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $f$
DECLARE p public.financeiro_parcelas; t public.financeiro_titulos; v_bol uuid; b public.boletos; v_restam int;
BEGIN
  IF length(btrim(coalesce(p_motivo,''))) = 0 THEN RAISE EXCEPTION 'Informe a justificativa da exclusao.' USING ERRCODE='P0001'; END IF;
  SELECT * INTO p FROM public.financeiro_parcelas WHERE id = p_parcela FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Parcela inexistente.' USING ERRCODE='P0001'; END IF;
  SELECT * INTO t FROM public.financeiro_titulos WHERE id = p.titulo_id;
  PERFORM public.financeiro_exige(t.especie);
  IF p.situacao NOT IN ('prevista','firme') THEN RAISE EXCEPTION 'Esta parcela ja esta % e nao pode ser apagada.', p.situacao USING ERRCODE='P0001'; END IF;
  IF coalesce(p.valor_liquidado,0) <> 0 OR EXISTS (SELECT 1 FROM public.financeiro_baixas WHERE parcela_id = p_parcela) THEN
    RAISE EXCEPTION 'Parcela com baixa: estorne a baixa antes de apagar.' USING ERRCODE='P0001';
  END IF;
  SELECT boleto_id INTO v_bol FROM public.vw_financeiro_duplicatas WHERE parcela_id = p_parcela;
  IF v_bol IS NOT NULL THEN
    SELECT * INTO b FROM public.boletos WHERE id = v_bol FOR UPDATE;
    IF b.id IS NOT NULL THEN
      IF b.status NOT IN ('pendente_registro','Pendente','Aberto') OR b.nosso_numero_banco IS NOT NULL OR b.remessa_sequencial IS NOT NULL
         OR EXISTS (SELECT 1 FROM public.retorno_bancario_registros r WHERE r.boleto_id = b.id)
         OR EXISTS (SELECT 1 FROM public.notas_fiscais n WHERE n.boleto_id = b.id) THEN
        RAISE EXCEPTION 'O boleto desta conta ja foi registrado/pago/usado: apagar so pelo banco ou pelo TI.' USING ERRCODE='P0001';
      END IF;
      INSERT INTO backup.spec297_boletos_apagados (apagado_por, motivo, boleto) VALUES (auth.uid(), btrim(p_motivo), to_jsonb(b));
      DELETE FROM public.boletos WHERE id = b.id;
    END IF;
  END IF;
  UPDATE public.financeiro_parcelas SET situacao = 'cancelada' WHERE id = p_parcela;
  SELECT count(*) INTO v_restam FROM public.financeiro_parcelas WHERE titulo_id = t.id AND situacao IN ('prevista','firme');
  IF v_restam = 0 AND t.cancelado_em IS NULL THEN
    UPDATE public.financeiro_titulos SET cancelado_em = now(), cancelado_por = auth.uid(), motivo_cancelamento = btrim(p_motivo) WHERE id = t.id;
  END IF;
  PERFORM auditoria.inserir(auth.uid(), 'financeiro', 'apagou_conta', 'financeiro_parcelas', p_parcela::text, coalesce(t.documento, t.descricao),
    jsonb_build_object('motivo', btrim(p_motivo), 'natureza', t.natureza, 'especie', t.especie, 'vencimento', p.vencimento, 'valor', p.valor,
                       'boleto_removido', v_bol, 'titulo_cancelado', (v_restam = 0)));
END $f$;

-- ===== apagar boleto avulso (sem parcela no financeiro novo) =====
CREATE OR REPLACE FUNCTION public.boleto_apagar_avulso(p_boleto uuid, p_motivo text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $f$
DECLARE b public.boletos;
BEGIN
  IF length(btrim(coalesce(p_motivo,''))) = 0 THEN RAISE EXCEPTION 'Informe a justificativa da exclusao.' USING ERRCODE='P0001'; END IF;
  PERFORM public.financeiro_exige(NULL);
  SELECT * INTO b FROM public.boletos WHERE id = p_boleto FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Boleto inexistente.' USING ERRCODE='P0001'; END IF;
  IF EXISTS (SELECT 1 FROM public.vw_financeiro_duplicatas WHERE boleto_id = p_boleto) THEN
    RAISE EXCEPTION 'Este boleto tem parcela no financeiro: apague pela parcela.' USING ERRCODE='P0001';
  END IF;
  IF b.parcela_id IS NOT NULL AND (EXISTS (SELECT 1 FROM public.projeto_parcelas WHERE id = b.parcela_id)
                                   OR EXISTS (SELECT 1 FROM public.transacoes WHERE parcela_id = b.parcela_id)) THEN
    RAISE EXCEPTION 'Este boleto e de uma venda/devolucao (parcela do projeto): nao apague por aqui.' USING ERRCODE='P0001';
  END IF;
  IF b.status NOT IN ('pendente_registro','Pendente','Aberto') OR b.nosso_numero_banco IS NOT NULL OR b.remessa_sequencial IS NOT NULL
     OR coalesce(b.valor_pago,0) <> 0 OR b.data_pagamento IS NOT NULL
     OR EXISTS (SELECT 1 FROM public.retorno_bancario_registros r WHERE r.boleto_id = b.id)
     OR EXISTS (SELECT 1 FROM public.notas_fiscais n WHERE n.boleto_id = b.id) THEN
    RAISE EXCEPTION 'Boleto ja registrado/pago/usado: nao pode ser apagado por aqui.' USING ERRCODE='P0001';
  END IF;
  INSERT INTO backup.spec297_boletos_apagados (apagado_por, motivo, boleto) VALUES (auth.uid(), btrim(p_motivo), to_jsonb(b));
  DELETE FROM public.boletos WHERE id = b.id;
  PERFORM auditoria.inserir(auth.uid(), 'financeiro', 'apagou_conta', 'boletos', p_boleto::text, b.numero_documento,
    jsonb_build_object('motivo', btrim(p_motivo), 'tipo_operacao', b.tipo_operacao, 'valor', b.valor, 'vencimento', b.vencimento, 'nome_pagador', b.nome_pagador));
END $f$;

REVOKE ALL ON FUNCTION public.financeiro_editar_parcela(uuid,date,numeric,text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.financeiro_apagar_parcela(uuid,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.boleto_apagar_avulso(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.financeiro_editar_parcela(uuid,date,numeric,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.financeiro_apagar_parcela(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.boleto_apagar_avulso(uuid,text) TO authenticated;
REVOKE ALL ON backup.spec297_boletos_apagados FROM PUBLIC, anon, authenticated;

COMMIT;
