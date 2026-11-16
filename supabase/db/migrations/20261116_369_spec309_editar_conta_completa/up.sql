-- SPEC-309: o Editar do Contas a Pagar/Receber abre o formulario completo tambem para contas do financeiro novo (Connect/manual).
-- Duas funcoes novas (nenhuma tabela/coluna nova): leitura da conta para edicao e gravacao completa com justificativa + auditoria.
BEGIN;

CREATE OR REPLACE FUNCTION public.financeiro_conta_para_edicao(p_parcela uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE p public.financeiro_parcelas; t public.financeiro_titulos; v_parcelas jsonb; v_bloq text;
BEGIN
  SELECT * INTO p FROM public.financeiro_parcelas WHERE id = p_parcela;
  IF NOT FOUND THEN RAISE EXCEPTION 'Parcela inexistente.' USING ERRCODE='P0001'; END IF;
  SELECT * INTO t FROM public.financeiro_titulos WHERE id = p.titulo_id;
  PERFORM public.financeiro_exige(t.especie);
  IF t.cancelado_em IS NOT NULL THEN
    v_bloq := 'Conta cancelada nao pode ser editada.';
  ELSIF t.origem_tipo NOT IN ('legado_connect','manual') THEN
    v_bloq := 'Conta de origem "' || t.origem_tipo || '": altere pela origem (NF/pedido no Compras, venda no Orcamentos).';
  END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', x.id, 'numero', x.numero, 'vencimento', x.vencimento, 'valor', x.valor, 'situacao', x.situacao,
           'valor_liquidado', coalesce(x.valor_liquidado,0), 'descricao', x.descricao, 'observacao', x.observacao,
           'emissao', x.emissao, 'aberta', (x.situacao IN ('prevista','firme') AND coalesce(x.valor_liquidado,0) = 0)
         ) ORDER BY x.numero), '[]'::jsonb)
    INTO v_parcelas FROM public.financeiro_parcelas x WHERE x.titulo_id = t.id;
  RETURN jsonb_build_object(
    'editavel', v_bloq IS NULL, 'motivo_bloqueio', v_bloq, 'parcela_id', p_parcela,
    'titulo', jsonb_build_object(
      'id', t.id, 'natureza', t.natureza, 'origem_tipo', t.origem_tipo, 'especie', t.especie, 'empresa_id', t.empresa_id,
      'perfil', t.perfil, 'contato_id', t.contato_id, 'plano_contas_id', t.plano_contas_id, 'documento', t.documento,
      'descricao', t.descricao, 'responsavel_id', t.responsavel_id, 'numero_duplicata', t.numero_duplicata,
      'legado_cod_duplicata', t.legado_cod_duplicata),
    'parcelas', v_parcelas);
END $fn$;

CREATE OR REPLACE FUNCTION public.financeiro_editar_conta(p_titulo uuid, p_dados jsonb, p_parcelas jsonb, p_motivo text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE t public.financeiro_titulos; r jsonb; p public.financeiro_parcelas; v_bol uuid; b public.boletos;
        v_venc date; v_valor numeric; v_desc text; v_obs text; v_emissao date; v_antes jsonb; v_depois jsonb;
        v_log_p jsonb := '[]'::jsonb; v_mudou boolean;
BEGIN
  IF length(btrim(coalesce(p_motivo,''))) = 0 THEN RAISE EXCEPTION 'Informe a justificativa da alteracao.' USING ERRCODE='P0001'; END IF;
  IF p_dados IS NULL OR jsonb_typeof(p_dados) <> 'object' THEN RAISE EXCEPTION 'Dados da conta invalidos.' USING ERRCODE='P0001'; END IF;
  IF p_parcelas IS NULL OR jsonb_typeof(p_parcelas) <> 'array' THEN RAISE EXCEPTION 'Parcelas invalidas.' USING ERRCODE='P0001'; END IF;
  SELECT * INTO t FROM public.financeiro_titulos WHERE id = p_titulo FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Conta inexistente.' USING ERRCODE='P0001'; END IF;
  PERFORM public.financeiro_exige(t.especie);
  IF t.cancelado_em IS NOT NULL THEN RAISE EXCEPTION 'Conta cancelada nao pode ser editada.' USING ERRCODE='P0001'; END IF;
  IF t.origem_tipo NOT IN ('legado_connect','manual') THEN
    RAISE EXCEPTION 'Conta de origem "%": altere pela origem (NF/pedido no Compras, venda no Orcamentos).', t.origem_tipo USING ERRCODE='P0001';
  END IF;
  IF nullif(p_dados->>'empresa_id','') IS NULL THEN RAISE EXCEPTION 'Selecione a empresa.' USING ERRCODE='P0001'; END IF;

  v_antes := jsonb_build_object('empresa_id', t.empresa_id, 'perfil', t.perfil, 'contato_id', t.contato_id,
    'plano_contas_id', t.plano_contas_id, 'documento', t.documento, 'descricao', t.descricao, 'responsavel_id', t.responsavel_id);

  UPDATE public.financeiro_titulos SET
    empresa_id      = (p_dados->>'empresa_id')::uuid,
    perfil          = nullif(btrim(coalesce(p_dados->>'perfil','')),''),
    contato_id      = nullif(p_dados->>'contato_id','')::uuid,
    plano_contas_id = nullif(p_dados->>'plano_contas_id','')::uuid,
    documento       = nullif(btrim(coalesce(p_dados->>'documento','')),''),
    descricao       = nullif(btrim(coalesce(p_dados->>'descricao','')),''),
    responsavel_id  = nullif(p_dados->>'responsavel_id','')::uuid
  WHERE id = t.id;
  v_depois := jsonb_build_object('empresa_id', p_dados->>'empresa_id', 'perfil', p_dados->>'perfil', 'contato_id', p_dados->>'contato_id',
    'plano_contas_id', p_dados->>'plano_contas_id', 'documento', p_dados->>'documento', 'descricao', p_dados->>'descricao',
    'responsavel_id', p_dados->>'responsavel_id');

  FOR r IN SELECT * FROM jsonb_array_elements(p_parcelas) LOOP
    SELECT * INTO p FROM public.financeiro_parcelas WHERE id = (r->>'id')::uuid AND titulo_id = t.id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Parcela nao pertence a esta conta.' USING ERRCODE='P0001'; END IF;
    CONTINUE WHEN NOT (p.situacao IN ('prevista','firme') AND coalesce(p.valor_liquidado,0) = 0); -- parcela paga/baixada fica intacta
    v_venc := (r->>'vencimento')::date; v_valor := round((r->>'valor')::numeric, 2);
    v_desc := nullif(btrim(coalesce(r->>'descricao','')),''); v_obs := nullif(btrim(coalesce(r->>'observacao','')),'');
    v_emissao := coalesce(nullif(r->>'emissao','')::date, p.emissao);
    IF v_venc IS NULL OR v_valor IS NULL OR v_valor = 0 THEN RAISE EXCEPTION 'Vencimento e valor (diferente de zero) sao obrigatorios.' USING ERRCODE='P0001'; END IF;
    IF (v_valor > 0) IS DISTINCT FROM (p.valor > 0) THEN RAISE EXCEPTION 'O valor nao pode trocar de sinal (credito x debito).' USING ERRCODE='P0001'; END IF;
    v_mudou := v_venc IS DISTINCT FROM p.vencimento OR v_valor IS DISTINCT FROM p.valor;
    IF v_mudou THEN
      IF EXISTS (SELECT 1 FROM public.financeiro_legado_ids l WHERE l.id_novo = p.id AND l.tabela_antiga = 'projeto_parcelas')
         OR EXISTS (SELECT 1 FROM public.financeiro_legado_ids l JOIN public.transacoes x ON x.id = l.id_antigo
                     WHERE l.id_novo = p.id AND l.tabela_antiga = 'transacoes' AND x.cod_itens_duplicata IS NULL) THEN
        RAISE EXCEPTION 'Conta ligada a uma venda/devolucao do sistema: nao da para editar valor/vencimento aqui (a venda refaz o valor).' USING ERRCODE='P0001';
      END IF;
      SELECT boleto_id INTO v_bol FROM public.vw_financeiro_duplicatas WHERE parcela_id = p.id;
      IF v_bol IS NOT NULL THEN
        SELECT * INTO b FROM public.boletos WHERE id = v_bol FOR UPDATE;
        IF b.status NOT IN ('pendente_registro','Pendente','Aberto') OR b.nosso_numero_banco IS NOT NULL OR b.remessa_sequencial IS NOT NULL
           OR EXISTS (SELECT 1 FROM public.retorno_bancario_registros x WHERE x.boleto_id = b.id)
           OR EXISTS (SELECT 1 FROM public.notas_fiscais n WHERE n.boleto_id = b.id) THEN
          RAISE EXCEPTION 'O boleto desta conta ja foi registrado/pago/usado: nao da para alterar valor/vencimento por aqui.' USING ERRCODE='P0001';
        END IF;
        UPDATE public.boletos SET vencimento = v_venc, valor = v_valor WHERE id = v_bol;
      END IF;
    END IF;
    UPDATE public.financeiro_parcelas
       SET vencimento = v_venc, valor = v_valor, descricao = v_desc, observacao = v_obs, emissao = v_emissao
     WHERE id = p.id;
    IF v_mudou OR v_desc IS DISTINCT FROM p.descricao OR v_obs IS DISTINCT FROM p.observacao OR v_emissao IS DISTINCT FROM p.emissao THEN
      v_log_p := v_log_p || jsonb_build_array(jsonb_build_object('parcela_id', p.id, 'numero', p.numero,
        'antes', jsonb_build_object('vencimento', p.vencimento, 'valor', p.valor, 'descricao', p.descricao, 'observacao', p.observacao, 'emissao', p.emissao),
        'depois', jsonb_build_object('vencimento', v_venc, 'valor', v_valor, 'descricao', v_desc, 'observacao', v_obs, 'emissao', v_emissao)));
    END IF;
  END LOOP;

  PERFORM auditoria.inserir(auth.uid(), 'financeiro', 'editou_conta', 'financeiro_titulos', t.id::text, coalesce(t.documento, t.descricao),
    jsonb_build_object('motivo', btrim(p_motivo), 'titulo_antes', v_antes, 'titulo_depois', v_depois, 'parcelas', v_log_p, 'natureza', t.natureza));
END $fn$;

REVOKE ALL ON FUNCTION public.financeiro_conta_para_edicao(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.financeiro_editar_conta(uuid, jsonb, jsonb, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.financeiro_conta_para_edicao(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.financeiro_editar_conta(uuid, jsonb, jsonb, text) TO authenticated;

COMMIT;
