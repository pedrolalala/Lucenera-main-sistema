-- SPEC-282: historico de edicao de preco/custo/ST da peca (quem mudou, quando, de quanto, por qual caminho).
-- A auditoria geral (auditoria.eventos) esconde custo/ST/margem como ***; este historico guarda os valores e so
-- e legivel por quem pode ver custo (pode_ver_custo_produto, lista da Administracao).
BEGIN;

CREATE TABLE IF NOT EXISTS public.produto_preco_historico (
  id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  criado_em      timestamptz NOT NULL DEFAULT now(),
  produto_id     uuid NOT NULL,
  codigo_produto integer,
  usuario_id     uuid,
  usuario_nome   text,
  origem         text NOT NULL,
  campos         jsonb NOT NULL   -- {"porc_st": [antes, depois], ...}
);
CREATE INDEX IF NOT EXISTS idx_produto_preco_hist_produto ON public.produto_preco_historico (produto_id, criado_em DESC);

ALTER TABLE public.produto_preco_historico ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.produto_preco_historico FROM anon, authenticated;
GRANT SELECT ON public.produto_preco_historico TO authenticated;
CREATE POLICY produto_preco_historico_select ON public.produto_preco_historico
  FOR SELECT TO authenticated USING ((SELECT public.pode_ver_custo_produto()));

CREATE OR REPLACE FUNCTION public.fn_produto_preco_historico()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_old jsonb := to_jsonb(OLD);
  v_new jsonb := to_jsonb(NEW);
  v_campos jsonb := '{}'::jsonb;
  k text;
  v_uid uuid := auth.uid();
  v_nome text;
  v_origem text := nullif(current_setting('app.origem_preco', true), '');
  v_role text := coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role', '');
BEGIN
  FOREACH k IN ARRAY ARRAY['preco_custo','porc_desconto','porc_frete','porc_despesas','porc_st','ipi_entrada',
                           'margem_lucro','porc_bdi','custo_total','valor_venda','preco_venda'] LOOP
    IF (v_old -> k) IS DISTINCT FROM (v_new -> k) THEN
      v_campos := v_campos || jsonb_build_object(k, jsonb_build_array(v_old -> k, v_new -> k));
    END IF;
  END LOOP;
  IF v_campos = '{}'::jsonb THEN RETURN NULL; END IF;

  IF v_uid IS NOT NULL THEN
    SELECT coalesce(u.nome, u.email) INTO v_nome FROM public.usuarios u WHERE u.id = v_uid;
    v_origem := coalesce(v_origem, 'edição manual');
  ELSIF v_role = 'service_role' OR coalesce(current_setting('app.origem', true), '') = 'script' THEN
    v_nome := 'Importação / script';
    v_origem := coalesce(v_origem, 'importação ou script');
  ELSE
    v_nome := 'SQL direto (' || session_user || ')';
    v_origem := coalesce(v_origem, 'SQL direto');
  END IF;

  INSERT INTO public.produto_preco_historico (produto_id, codigo_produto, usuario_id, usuario_nome, origem, campos)
  VALUES (NEW.id, NEW.codigo_produto, v_uid, v_nome, v_origem, v_campos);
  RETURN NULL;
END $fn$;
REVOKE ALL ON FUNCTION public.fn_produto_preco_historico() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_produto_preco_historico ON public.produtos;
CREATE TRIGGER trg_produto_preco_historico
  AFTER UPDATE OF preco_custo, porc_desconto, porc_frete, porc_despesas, porc_st, ipi_entrada, margem_lucro,
                  porc_bdi, custo_total, valor_venda, preco_venda
  ON public.produtos FOR EACH ROW EXECUTE FUNCTION public.fn_produto_preco_historico();

-- o reajuste em lote e o desfazer passam a se identificar como origem
CREATE OR REPLACE FUNCTION public.reajuste_aplicar(p_escopo jsonb, p_regra jsonb, p_motivo text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_lote uuid; v_qtd integer; v_nome text;
BEGIN
  PERFORM set_config('app.origem_preco', 'reajuste em lote', true);
  IF NOT public.pode_reajustar_precos() THEN
    RAISE EXCEPTION 'Sem permissao para reajustar precos.' USING ERRCODE = 'P0001';
  END IF;
  IF NULLIF(btrim(COALESCE(p_motivo, '')), '') IS NULL THEN
    RAISE EXCEPTION 'Informe o motivo do reajuste.' USING ERRCODE = 'P0001';
  END IF;
  SELECT COALESCE(u.nome, u.email) INTO v_nome FROM public.usuarios u WHERE u.id = auth.uid();

  CREATE TEMP TABLE _reaj ON COMMIT DROP AS
    SELECT * FROM public._reajuste_calcular(p_escopo, p_regra) WHERE ignorado IS NULL;
  SELECT count(*) INTO v_qtd FROM _reaj;
  IF v_qtd = 0 THEN
    DROP TABLE IF EXISTS _reaj;
    RAISE EXCEPTION 'Nenhuma peca seria alterada por essa regra.' USING ERRCODE = 'P0001';
  END IF;
  IF v_qtd > 6000 THEN
    DROP TABLE IF EXISTS _reaj;
    RAISE EXCEPTION 'Lote grande demais (% pecas). Restrinja o escopo.', v_qtd USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.produto_reajuste_lote (criado_por, criado_por_nome, motivo, escopo, regra, qtd_pecas)
  VALUES (auth.uid(), v_nome, btrim(p_motivo), p_escopo, p_regra, v_qtd) RETURNING id INTO v_lote;
  INSERT INTO public.produto_reajuste_item (lote_id, produto_id, codigo_produto, antes, depois)
    SELECT v_lote, produto_id, codigo_produto, antes, depois FROM _reaj;

  UPDATE public.produtos pr SET
    preco_custo   = (r.depois ->> 'preco_custo')::numeric,
    porc_desconto = (r.depois ->> 'porc_desconto')::numeric,
    porc_frete    = (r.depois ->> 'porc_frete')::numeric,
    porc_despesas = (r.depois ->> 'porc_despesas')::numeric,
    porc_st       = (r.depois ->> 'porc_st')::numeric,
    ipi_entrada   = (r.depois ->> 'ipi_entrada')::numeric,
    margem_lucro  = (r.depois ->> 'margem_lucro')::numeric,
    porc_bdi      = (r.depois ->> 'porc_bdi')::numeric,
    custo_total   = (r.depois ->> 'custo_total')::numeric,
    valor_venda   = (r.depois ->> 'valor_venda')::numeric
    -- preco_venda: o gatilho fn_atualizar_preco_venda copia valor_venda (SPEC-230)
  FROM _reaj r WHERE pr.id = r.produto_id;

  DROP TABLE IF EXISTS _reaj;
  PERFORM set_config('app.origem_preco', '', true);
  RETURN jsonb_build_object('lote_id', v_lote, 'qtd_pecas', v_qtd);
END $$;

CREATE OR REPLACE FUNCTION public.reajuste_desfazer(p_lote uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_voltaram integer := 0; v_puladas integer := 0; it record; l record;
BEGIN
  PERFORM set_config('app.origem_preco', 'desfazer reajuste em lote', true);
  IF NOT public.pode_reajustar_precos() THEN
    RAISE EXCEPTION 'Sem permissao para reajustar precos.' USING ERRCODE = 'P0001';
  END IF;
  SELECT * INTO l FROM public.produto_reajuste_lote WHERE id = p_lote FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Lote nao encontrado.' USING ERRCODE = 'P0001'; END IF;
  IF l.desfeito_em IS NOT NULL THEN RAISE EXCEPTION 'Lote ja desfeito.' USING ERRCODE = 'P0001'; END IF;

  FOR it IN SELECT i.id AS item_id, i.produto_id, i.antes, i.depois,
                   pr.preco_custo, pr.porc_st, pr.ipi_entrada, pr.margem_lucro, pr.custo_total, pr.valor_venda
            FROM public.produto_reajuste_item i JOIN public.produtos pr ON pr.id = i.produto_id
            WHERE i.lote_id = p_lote AND NOT i.desfeito LOOP
    IF COALESCE(it.preco_custo,0) = COALESCE((it.depois ->> 'preco_custo')::numeric,0)
       AND COALESCE(it.porc_st,0) = COALESCE((it.depois ->> 'porc_st')::numeric,0)
       AND COALESCE(it.ipi_entrada,0) = COALESCE((it.depois ->> 'ipi_entrada')::numeric,0)
       AND COALESCE(it.margem_lucro,0) = COALESCE((it.depois ->> 'margem_lucro')::numeric,0)
       AND COALESCE(it.custo_total,0) = COALESCE((it.depois ->> 'custo_total')::numeric,0)
       AND COALESCE(it.valor_venda,0) = COALESCE((it.depois ->> 'valor_venda')::numeric,0) THEN
      UPDATE public.produtos SET
        preco_custo   = (it.antes ->> 'preco_custo')::numeric,
        porc_desconto = (it.antes ->> 'porc_desconto')::numeric,
        porc_frete    = (it.antes ->> 'porc_frete')::numeric,
        porc_despesas = (it.antes ->> 'porc_despesas')::numeric,
        porc_st       = (it.antes ->> 'porc_st')::numeric,
        ipi_entrada   = (it.antes ->> 'ipi_entrada')::numeric,
        margem_lucro  = (it.antes ->> 'margem_lucro')::numeric,
        porc_bdi      = (it.antes ->> 'porc_bdi')::numeric,
        custo_total   = (it.antes ->> 'custo_total')::numeric,
        valor_venda   = COALESCE((it.antes ->> 'valor_venda')::numeric, 0)
      WHERE id = it.produto_id;
      UPDATE public.produto_reajuste_item SET desfeito = true WHERE id = it.item_id;
      v_voltaram := v_voltaram + 1;
    ELSE
      v_puladas := v_puladas + 1;
    END IF;
  END LOOP;
  UPDATE public.produto_reajuste_lote SET desfeito_em = now(), desfeito_por = auth.uid() WHERE id = p_lote;
  PERFORM set_config('app.origem_preco', '', true);
  RETURN jsonb_build_object('voltaram', v_voltaram, 'puladas_editadas_depois', v_puladas);
END $$;

-- historico retroativo: as 153 pecas alinhadas ao ST da planilha da Connect em 11/11 (copia em backup.*)
INSERT INTO public.produto_preco_historico (criado_em, produto_id, codigo_produto, usuario_nome, origem, campos)
SELECT b.salvo_em, p.id, p.codigo_produto, 'Sistema (alinhamento)', 'alinhamento com a planilha da Connect (11/11)',
       jsonb_strip_nulls(jsonb_build_object(
         'porc_st',     CASE WHEN b.porc_st     IS DISTINCT FROM p.porc_st     THEN jsonb_build_array(b.porc_st, p.porc_st) END,
         'porc_bdi',    CASE WHEN b.porc_bdi    IS DISTINCT FROM p.porc_bdi    THEN jsonb_build_array(b.porc_bdi, p.porc_bdi) END,
         'custo_total', CASE WHEN b.custo_total IS DISTINCT FROM p.custo_total THEN jsonb_build_array(b.custo_total, p.custo_total) END,
         'valor_venda', CASE WHEN b.valor_venda IS DISTINCT FROM p.valor_venda THEN jsonb_build_array(b.valor_venda, p.valor_venda) END,
         'preco_venda', CASE WHEN b.preco_venda IS DISTINCT FROM p.preco_venda THEN jsonb_build_array(b.preco_venda, p.preco_venda) END))
FROM backup.produtos_preco_antes_sync_20261111 b
JOIN public.produtos p ON p.codigo_produto = b.codigo_produto
WHERE NOT EXISTS (SELECT 1 FROM public.produto_preco_historico h
                  WHERE h.produto_id = p.id AND h.origem LIKE 'alinhamento com a planilha%');

COMMIT;
