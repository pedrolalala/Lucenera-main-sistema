-- Rollback 356: volta as funcoes de apagar da 354 (as de cancelar saem). Registros cancelados continuam cancelados.
BEGIN;
CREATE OR REPLACE FUNCTION public.financeiro_apagar_parcela(p_parcela uuid, p_motivo text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
END $function$;
CREATE OR REPLACE FUNCTION public.boleto_apagar_avulso(p_boleto uuid, p_motivo text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
END $function$;
CREATE OR REPLACE FUNCTION public.financeiro_editar_parcela(p_parcela uuid, p_vencimento date, p_valor numeric, p_descricao text, p_motivo text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
END $function$;
REVOKE ALL ON FUNCTION public.financeiro_apagar_parcela(uuid,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.boleto_apagar_avulso(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.financeiro_apagar_parcela(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.boleto_apagar_avulso(uuid,text) TO authenticated;
DROP FUNCTION IF EXISTS public.financeiro_cancelar_parcela(uuid,text);
DROP FUNCTION IF EXISTS public.boleto_cancelar_avulso(uuid,text);
COMMIT;
