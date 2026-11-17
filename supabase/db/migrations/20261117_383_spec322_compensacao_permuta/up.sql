-- SPEC-322: compensação (permuta) entre a pagar e a receber da MESMA pessoa, sem dinheiro.
-- Grava 2 baixas 'compensacao' (uma em cada parcela) ligadas por compensacao_id. Não mexe em caixa (movimenta_caixa = false).
-- Baixa é imutável (trigger) -> o vínculo nasce no INSERT; estorno usa financeiro_estornar nas duas.
BEGIN;

ALTER TABLE public.financeiro_baixas ADD COLUMN IF NOT EXISTS compensacao_id uuid;
CREATE INDEX IF NOT EXISTS financeiro_baixas_compensacao_idx ON public.financeiro_baixas (compensacao_id) WHERE compensacao_id IS NOT NULL;

-- Candidatas: parcelas firmes, com saldo, do lado OPOSTO, da mesma pessoa e da mesma empresa da parcela informada.
CREATE OR REPLACE FUNCTION public.financeiro_compensacao_candidatas(p_parcela uuid)
 RETURNS TABLE(parcela_id uuid, titulo_id uuid, natureza public.fin_natureza, numero integer, vencimento date, valor numeric, saldo numeric, documento text, descricao text)
 LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $f$
DECLARE v_t public.financeiro_titulos;
BEGIN
  SELECT t.* INTO v_t FROM public.financeiro_parcelas p JOIN public.financeiro_titulos t ON t.id = p.titulo_id WHERE p.id = p_parcela;
  IF NOT FOUND THEN RAISE EXCEPTION 'Parcela inexistente.' USING ERRCODE = 'P0001'; END IF;
  PERFORM public.financeiro_exige(v_t.especie);
  IF v_t.contato_id IS NULL THEN RETURN; END IF;
  RETURN QUERY
    SELECT p.id, t.id, t.natureza, p.numero, p.vencimento, p.valor, p.valor - p.valor_liquidado, t.documento, t.descricao
      FROM public.financeiro_parcelas p JOIN public.financeiro_titulos t ON t.id = p.titulo_id
     WHERE t.contato_id = v_t.contato_id AND t.empresa_id IS NOT DISTINCT FROM v_t.empresa_id
       AND t.natureza <> v_t.natureza AND t.cancelado_em IS NULL
       AND p.situacao = 'firme' AND p.valor - p.valor_liquidado > 0
     ORDER BY p.vencimento, t.id, p.numero;
END $f$;

-- Compensa p_valor entre uma parcela a pagar e uma a receber. Devolve o id da compensação (compensacao_id).
CREATE OR REPLACE FUNCTION public.financeiro_compensar(p_parcela_pagar uuid, p_parcela_receber uuid, p_valor numeric, p_motivo text, p_data date DEFAULT CURRENT_DATE)
 RETURNS uuid
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
DECLARE
  pp public.financeiro_parcelas; pr public.financeiro_parcelas; tp public.financeiro_titulos; tr public.financeiro_titulos; v_id uuid := gen_random_uuid();
BEGIN
  IF length(btrim(coalesce(p_motivo, ''))) = 0 THEN RAISE EXCEPTION 'Informe o motivo da compensação.' USING ERRCODE = 'P0001'; END IF;
  IF p_valor IS NULL OR p_valor <= 0 THEN RAISE EXCEPTION 'Valor da compensação deve ser maior que zero.' USING ERRCODE = 'P0001'; END IF;
  IF p_parcela_pagar = p_parcela_receber THEN RAISE EXCEPTION 'Escolha uma parcela a pagar e outra a receber.' USING ERRCODE = 'P0001'; END IF;
  -- trava sempre na mesma ordem (evita deadlock entre duas compensações)
  PERFORM 1 FROM public.financeiro_parcelas WHERE id = least(p_parcela_pagar, p_parcela_receber) FOR UPDATE;
  PERFORM 1 FROM public.financeiro_parcelas WHERE id = greatest(p_parcela_pagar, p_parcela_receber) FOR UPDATE;
  SELECT * INTO pp FROM public.financeiro_parcelas WHERE id = p_parcela_pagar;
  SELECT * INTO pr FROM public.financeiro_parcelas WHERE id = p_parcela_receber;
  IF pp.id IS NULL OR pr.id IS NULL THEN RAISE EXCEPTION 'Parcela inexistente.' USING ERRCODE = 'P0001'; END IF;
  SELECT * INTO tp FROM public.financeiro_titulos WHERE id = pp.titulo_id;
  SELECT * INTO tr FROM public.financeiro_titulos WHERE id = pr.titulo_id;
  PERFORM public.financeiro_exige(tp.especie);
  PERFORM public.financeiro_exige(tr.especie);
  IF tp.natureza <> 'pagar' OR tr.natureza <> 'receber' THEN RAISE EXCEPTION 'Compensação é entre uma conta a pagar e uma a receber.' USING ERRCODE = 'P0001'; END IF;
  IF tp.cancelado_em IS NOT NULL OR tr.cancelado_em IS NOT NULL THEN RAISE EXCEPTION 'Título cancelado.' USING ERRCODE = 'P0001'; END IF;
  IF tp.contato_id IS NULL OR tp.contato_id IS DISTINCT FROM tr.contato_id THEN RAISE EXCEPTION 'As duas contas precisam ser da mesma pessoa.' USING ERRCODE = 'P0001'; END IF;
  IF tp.empresa_id IS DISTINCT FROM tr.empresa_id THEN RAISE EXCEPTION 'As duas contas precisam ser da mesma empresa.' USING ERRCODE = 'P0001'; END IF;
  IF pp.situacao <> 'firme' OR pr.situacao <> 'firme' THEN RAISE EXCEPTION 'Compensação só em parcela firme.' USING ERRCODE = 'P0001'; END IF;
  IF p_valor > pp.valor - pp.valor_liquidado OR p_valor > pr.valor - pr.valor_liquidado THEN
    RAISE EXCEPTION 'Valor (%) maior que o menor saldo (a pagar % / a receber %).', p_valor, pp.valor - pp.valor_liquidado, pr.valor - pr.valor_liquidado USING ERRCODE = 'P0001';
  END IF;
  INSERT INTO public.financeiro_baixas (parcela_id, tipo, data, valor, forma, motivo, origem_baixa, compensacao_id, criado_por)
  VALUES (pp.id, 'compensacao', p_data, p_valor, 'permuta', p_motivo, 'manual', v_id, auth.uid()),
         (pr.id, 'compensacao', p_data, p_valor, 'permuta', p_motivo, 'manual', v_id, auth.uid());
  RETURN v_id;
END $f$;

-- Estorna as duas baixas da compensação de uma vez.
CREATE OR REPLACE FUNCTION public.financeiro_estornar_compensacao(p_compensacao uuid, p_motivo text)
 RETURNS integer
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
DECLARE b record; n integer := 0;
BEGIN
  IF length(btrim(coalesce(p_motivo, ''))) = 0 THEN RAISE EXCEPTION 'Informe o motivo do estorno.' USING ERRCODE = 'P0001'; END IF;
  FOR b IN SELECT id FROM public.financeiro_baixas WHERE compensacao_id = p_compensacao AND tipo = 'compensacao' ORDER BY id LOOP
    PERFORM public.financeiro_estornar(b.id, p_motivo);
    n := n + 1;
  END LOOP;
  IF n = 0 THEN RAISE EXCEPTION 'Compensação inexistente.' USING ERRCODE = 'P0001'; END IF;
  RETURN n;
END $f$;

-- Opção 1 (SPEC-322): cadastro manual pelo modelo novo (Cadastrar Duplicatas do Contas a Pagar). Envolve financeiro_criar_titulo e completa
-- o que ela não grava: responsável do título e emissão de cada parcela. Origem sempre 'manual'; parcela nasce firme.
CREATE OR REPLACE FUNCTION public.financeiro_cadastrar_conta_manual(p_titulo jsonb, p_parcelas jsonb)
 RETURNS uuid
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
DECLARE v_id uuid; v_resp uuid := nullif(p_titulo->>'responsavel_id', '')::uuid; i int := 0; r record;
BEGIN
  IF coalesce(p_titulo->>'natureza', '') NOT IN ('pagar', 'receber') THEN RAISE EXCEPTION 'Natureza inválida.' USING ERRCODE = 'P0001'; END IF;
  IF nullif(p_titulo->>'plano_contas_id', '') IS NULL THEN RAISE EXCEPTION 'Escolha a Apropriação.' USING ERRCODE = 'P0001'; END IF;
  v_id := public.financeiro_criar_titulo(
    (p_titulo - 'responsavel_id') || jsonb_build_object('origem_tipo', 'manual', 'especie', coalesce(p_titulo->>'especie', 'despesa')),
    (SELECT jsonb_agg(e || jsonb_build_object('situacao', 'firme')) FROM jsonb_array_elements(p_parcelas) e));
  IF v_resp IS NOT NULL THEN UPDATE public.financeiro_titulos SET responsavel_id = v_resp WHERE id = v_id; END IF;
  FOR r IN SELECT id FROM public.financeiro_parcelas WHERE titulo_id = v_id ORDER BY numero LOOP
    UPDATE public.financeiro_parcelas SET emissao = coalesce(nullif(p_parcelas->i->>'emissao', '')::date, emissao) WHERE id = r.id;
    i := i + 1;
  END LOOP;
  RETURN v_id;
END $f$;

-- Opção 2 (SPEC-322): a partir de uma parcela A RECEBER, registra o serviço (conta a pagar da mesma pessoa/empresa) e já compensa. Uma transação só.
CREATE OR REPLACE FUNCTION public.financeiro_compensar_nova_conta(p_parcela_receber uuid, p_valor_conta numeric, p_valor_comp numeric, p_plano_contas uuid,
    p_descricao text, p_documento text, p_vencimento date, p_motivo text, p_data date DEFAULT CURRENT_DATE)
 RETURNS uuid
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
DECLARE tr public.financeiro_titulos; v_tit uuid; v_par uuid;
BEGIN
  SELECT t.* INTO tr FROM public.financeiro_parcelas p JOIN public.financeiro_titulos t ON t.id = p.titulo_id WHERE p.id = p_parcela_receber;
  IF NOT FOUND THEN RAISE EXCEPTION 'Parcela inexistente.' USING ERRCODE = 'P0001'; END IF;
  PERFORM public.financeiro_exige(tr.especie);
  IF tr.natureza <> 'receber' THEN RAISE EXCEPTION 'Esta ação parte de uma conta a receber.' USING ERRCODE = 'P0001'; END IF;
  IF tr.contato_id IS NULL THEN RAISE EXCEPTION 'A conta a receber não tem pessoa cadastrada.' USING ERRCODE = 'P0001'; END IF;
  IF p_valor_conta IS NULL OR p_valor_conta <= 0 OR p_valor_comp IS NULL OR p_valor_comp <= 0 OR p_valor_comp > p_valor_conta THEN
    RAISE EXCEPTION 'Valor da conta e valor a compensar inválidos.' USING ERRCODE = 'P0001';
  END IF;
  v_tit := public.financeiro_cadastrar_conta_manual(
    jsonb_build_object('natureza', 'pagar', 'especie', 'despesa', 'empresa_id', tr.empresa_id, 'perfil', tr.perfil, 'contato_id', tr.contato_id,
                       'plano_contas_id', p_plano_contas, 'documento', p_documento, 'descricao', p_descricao, 'responsavel_id', tr.responsavel_id),
    jsonb_build_array(jsonb_build_object('vencimento', coalesce(p_vencimento, p_data), 'valor', p_valor_conta, 'emissao', p_data,
                                          'observacao', 'Permuta: ' || coalesce(nullif(btrim(p_motivo), ''), ''))));
  SELECT id INTO v_par FROM public.financeiro_parcelas WHERE titulo_id = v_tit AND numero = 1;
  RETURN public.financeiro_compensar(v_par, p_parcela_receber, p_valor_comp, p_motivo, p_data);
END $f$;

REVOKE ALL ON FUNCTION public.financeiro_compensacao_candidatas(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.financeiro_compensar(uuid, uuid, numeric, text, date) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.financeiro_estornar_compensacao(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.financeiro_cadastrar_conta_manual(jsonb, jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.financeiro_compensar_nova_conta(uuid, numeric, numeric, uuid, text, text, date, text, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.financeiro_compensacao_candidatas(uuid), public.financeiro_compensar(uuid, uuid, numeric, text, date), public.financeiro_estornar_compensacao(uuid, text),
  public.financeiro_cadastrar_conta_manual(jsonb, jsonb), public.financeiro_compensar_nova_conta(uuid, numeric, numeric, uuid, text, text, date, text, date) TO authenticated, service_role;

COMMIT;
