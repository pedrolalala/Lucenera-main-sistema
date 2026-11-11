-- SPEC-282 Parte B: reajuste de preco/ST/custo de pecas em lote (previa, aplicar, historico, desfazer).
-- So admin (usuarios.role = 'admin'). Escrita so por funcoes SECURITY DEFINER. Sem acesso anon.
BEGIN;

CREATE TABLE IF NOT EXISTS public.produto_reajuste_lote (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  numero        bigint GENERATED ALWAYS AS IDENTITY,
  criado_em     timestamptz NOT NULL DEFAULT now(),
  criado_por    uuid,
  criado_por_nome text,
  motivo        text NOT NULL,
  escopo        jsonb NOT NULL,
  regra         jsonb NOT NULL,
  qtd_pecas     integer NOT NULL DEFAULT 0,
  desfeito_em   timestamptz,
  desfeito_por  uuid
);

CREATE TABLE IF NOT EXISTS public.produto_reajuste_item (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  lote_id     uuid NOT NULL REFERENCES public.produto_reajuste_lote(id) ON DELETE CASCADE,
  produto_id  uuid NOT NULL,
  codigo_produto integer,
  antes       jsonb NOT NULL,
  depois      jsonb NOT NULL,
  desfeito    boolean NOT NULL DEFAULT false
);
CREATE INDEX IF NOT EXISTS idx_reajuste_item_lote ON public.produto_reajuste_item(lote_id);
CREATE INDEX IF NOT EXISTS idx_reajuste_item_produto ON public.produto_reajuste_item(produto_id);

ALTER TABLE public.produto_reajuste_lote ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.produto_reajuste_item ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.produto_reajuste_lote, public.produto_reajuste_item FROM anon, authenticated;
-- leitura so de admin (historico); nenhuma politica de escrita: so as funcoes gravam.
GRANT SELECT ON public.produto_reajuste_lote, public.produto_reajuste_item TO authenticated;

CREATE OR REPLACE FUNCTION public.pode_reajustar_precos()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
  SELECT COALESCE(auth.role(), '') = 'service_role'
      OR EXISTS (SELECT 1 FROM public.usuarios u
                 WHERE u.id = auth.uid() AND u.role::text = 'admin' AND COALESCE(u.ativo, true));
$$;
REVOKE ALL ON FUNCTION public.pode_reajustar_precos() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pode_reajustar_precos() TO authenticated, service_role;

CREATE POLICY reajuste_lote_admin_select ON public.produto_reajuste_lote
  FOR SELECT TO authenticated USING ((SELECT public.pode_reajustar_precos()));
CREATE POLICY reajuste_item_admin_select ON public.produto_reajuste_item
  FOR SELECT TO authenticated USING ((SELECT public.pode_reajustar_precos()));

-- aplica um campo da regra: {"modo":"definir|somar|percentual","valor":n}
CREATE OR REPLACE FUNCTION public._reaj_valor(p_atual numeric, p_regra jsonb, p_campo text)
RETURNS numeric LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE r jsonb := p_regra -> p_campo; v numeric;
BEGIN
  IF r IS NULL THEN RETURN p_atual; END IF;
  v := (r ->> 'valor')::numeric;
  RETURN CASE r ->> 'modo'
    WHEN 'definir'    THEN v
    WHEN 'somar'      THEN COALESCE(p_atual, 0) + v
    WHEN 'percentual' THEN COALESCE(p_atual, 0) * (1 + v / 100)
    ELSE p_atual END;
END $$;

-- nucleo: calcula antes/depois sem gravar. Conta igual a do Cadastro (PecaForm):
-- liquido = custo - desc; BDI = liquido*(frete+ST+IPI+despesas)/100; custo total = liquido+BDI; venda = custo total*(1+lucro/100)
CREATE OR REPLACE FUNCTION public._reajuste_calcular(p_escopo jsonb, p_regra jsonb)
RETURNS TABLE (produto_id uuid, codigo_produto integer, referencia text, nome text,
               antes jsonb, depois jsonb, ignorado text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  p record;
  v_manter text := COALESCE(p_regra ->> 'manter', 'lucro');
  v_todos boolean := COALESCE((p_escopo ->> 'todos')::boolean, false);
  c numeric; d numeric; f numeric; dp numeric; st numeric; ipi numeric; lu numeric;
  liq numeric; bdi numeric; ct numeric; pv numeric; pv_ant numeric;
  a jsonb; n jsonb; v_venda_direta boolean := (p_regra ? 'preco_venda');
BEGIN
  IF NOT public.pode_reajustar_precos() THEN
    RAISE EXCEPTION 'Sem permissao para reajustar precos.' USING ERRCODE = 'P0001';
  END IF;
  IF p_regra IS NULL OR NOT (p_regra ?| ARRAY['preco_custo','porc_desconto','porc_frete','porc_despesas','porc_st','ipi_entrada','margem_lucro','preco_venda']) THEN
    RAISE EXCEPTION 'Informe ao menos um campo para reajustar.' USING ERRCODE = 'P0001';
  END IF;
  IF NOT v_todos AND COALESCE(jsonb_array_length(p_escopo -> 'marca_ids'), 0) = 0
     AND COALESCE(jsonb_array_length(p_escopo -> 'categoria_ids'), 0) = 0
     AND COALESCE(jsonb_array_length(p_escopo -> 'fornecedor_ids'), 0) = 0
     AND COALESCE(jsonb_array_length(p_escopo -> 'produto_ids'), 0) = 0
     AND COALESCE(jsonb_array_length(p_escopo -> 'codigos'), 0) = 0 THEN
    RAISE EXCEPTION 'Escolha o escopo (marca, categoria, fornecedor ou pecas) ou marque "todos".' USING ERRCODE = 'P0001';
  END IF;

  FOR p IN
    SELECT pr.* FROM public.produtos pr
    WHERE (v_todos OR (
            (COALESCE(jsonb_array_length(p_escopo -> 'marca_ids'), 0) = 0 OR pr.marca_id::text IN (SELECT jsonb_array_elements_text(p_escopo -> 'marca_ids')))
        AND (COALESCE(jsonb_array_length(p_escopo -> 'categoria_ids'), 0) = 0 OR pr.categoria_id::text IN (SELECT jsonb_array_elements_text(p_escopo -> 'categoria_ids')))
        AND (COALESCE(jsonb_array_length(p_escopo -> 'fornecedor_ids'), 0) = 0 OR pr.fornecedor_principal_id::text IN (SELECT jsonb_array_elements_text(p_escopo -> 'fornecedor_ids')))
        AND (COALESCE(jsonb_array_length(p_escopo -> 'produto_ids'), 0) = 0 OR pr.id::text IN (SELECT jsonb_array_elements_text(p_escopo -> 'produto_ids')))
        AND (COALESCE(jsonb_array_length(p_escopo -> 'codigos'), 0) = 0 OR pr.codigo_produto::text IN (SELECT jsonb_array_elements_text(p_escopo -> 'codigos')))
          ))
      AND (NOT COALESCE((p_escopo ->> 'so_ativos')::boolean, true) OR COALESCE(pr.ativo, true))
    ORDER BY pr.codigo_produto
  LOOP
    pv_ant := COALESCE(NULLIF(p.preco_venda, 0), p.valor_venda, 0);
    a := jsonb_build_object('preco_custo', p.preco_custo, 'porc_desconto', p.porc_desconto, 'porc_frete', p.porc_frete,
           'porc_despesas', p.porc_despesas, 'porc_st', p.porc_st, 'ipi_entrada', p.ipi_entrada,
           'margem_lucro', p.margem_lucro, 'porc_bdi', p.porc_bdi, 'custo_total', p.custo_total,
           'valor_venda', p.valor_venda, 'preco_venda', pv_ant);

    c   := round(public._reaj_valor(COALESCE(p.preco_custo, 0), p_regra, 'preco_custo'), 2);
    d   := round(public._reaj_valor(COALESCE(p.porc_desconto, 0), p_regra, 'porc_desconto'), 4);
    f   := round(public._reaj_valor(COALESCE(p.porc_frete, 0), p_regra, 'porc_frete'), 4);
    dp  := round(public._reaj_valor(COALESCE(p.porc_despesas, 0), p_regra, 'porc_despesas'), 4);
    st  := round(public._reaj_valor(COALESCE(p.porc_st, 0), p_regra, 'porc_st'), 4);
    ipi := round(public._reaj_valor(COALESCE(p.ipi_entrada, 0), p_regra, 'ipi_entrada'), 4);
    lu  := round(public._reaj_valor(COALESCE(p.margem_lucro, 0), p_regra, 'margem_lucro'), 4);

    IF COALESCE(p.preco_custo, 0) = 0 AND NOT v_venda_direta THEN
      produto_id := p.id; codigo_produto := p.codigo_produto; referencia := p.referencia; nome := p.nome;
      antes := a; depois := a; ignorado := 'sem preco de custo (nao ha base para recalcular)';
      RETURN NEXT; CONTINUE;
    END IF;

    liq := c * (1 - d / 100);
    bdi := liq * ((f + st + ipi + dp) / 100);
    ct  := liq + bdi;

    IF v_venda_direta THEN
      pv := round(public._reaj_valor(pv_ant, p_regra, 'preco_venda'), 2);
      IF ct > 0 THEN lu := round((pv / ct - 1) * 100, 3); END IF;
    ELSIF v_manter = 'venda' THEN
      pv := pv_ant;
      IF ct > 0 THEN lu := round((pv / ct - 1) * 100, 3); END IF;
    ELSE
      pv := round(ct * (1 + lu / 100), 2);
    END IF;

    n := jsonb_build_object('preco_custo', c, 'porc_desconto', d, 'porc_frete', f, 'porc_despesas', dp,
           'porc_st', st, 'ipi_entrada', ipi, 'margem_lucro', lu, 'porc_bdi', round(bdi, 2),
           'custo_total', round(ct, 2), 'valor_venda', pv, 'preco_venda', pv);

    -- sem mudanca real: nao entra no lote
    IF round(COALESCE(pv_ant, 0), 2) = pv AND round(COALESCE(p.custo_total, 0), 2) = round(ct, 2)
       AND COALESCE(p.porc_st, 0) = st AND COALESCE(p.ipi_entrada, 0) = ipi AND COALESCE(p.preco_custo, 0) = c
       AND COALESCE(p.porc_desconto, 0) = d AND COALESCE(p.porc_frete, 0) = f AND COALESCE(p.porc_despesas, 0) = dp
       AND COALESCE(p.margem_lucro, 0) = lu THEN
      CONTINUE;
    END IF;

    produto_id := p.id; codigo_produto := p.codigo_produto; referencia := p.referencia; nome := p.nome;
    antes := a; depois := n; ignorado := NULL;
    RETURN NEXT;
  END LOOP;
END $$;
REVOKE ALL ON FUNCTION public._reajuste_calcular(jsonb, jsonb) FROM PUBLIC, anon, authenticated;

-- previa: nada grava
CREATE OR REPLACE FUNCTION public.reajuste_previa(p_escopo jsonb, p_regra jsonb, p_limite integer DEFAULT 300)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE r jsonb;
BEGIN
  IF NOT public.pode_reajustar_precos() THEN
    RAISE EXCEPTION 'Sem permissao para reajustar precos.' USING ERRCODE = 'P0001';
  END IF;
  CREATE TEMP TABLE _prev ON COMMIT DROP AS SELECT * FROM public._reajuste_calcular(p_escopo, p_regra);
  SELECT jsonb_build_object(
    'qtd_alteradas', count(*) FILTER (WHERE ignorado IS NULL),
    'qtd_ignoradas', count(*) FILTER (WHERE ignorado IS NOT NULL),
    'venda_antes',  COALESCE(sum((antes ->> 'preco_venda')::numeric)  FILTER (WHERE ignorado IS NULL), 0),
    'venda_depois', COALESCE(sum((depois ->> 'preco_venda')::numeric) FILTER (WHERE ignorado IS NULL), 0),
    'itens', COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM (
        SELECT codigo_produto, referencia, nome, antes, depois, ignorado
        FROM _prev ORDER BY (ignorado IS NOT NULL), codigo_produto LIMIT GREATEST(p_limite, 1)) x), '[]'::jsonb))
  INTO r FROM _prev;
  DROP TABLE IF EXISTS _prev;
  RETURN r;
END $$;

-- aplica em uma transacao, grava lote + itens (antes/depois)
CREATE OR REPLACE FUNCTION public.reajuste_aplicar(p_escopo jsonb, p_regra jsonb, p_motivo text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_lote uuid; v_qtd integer; v_nome text;
BEGIN
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
  RETURN jsonb_build_object('lote_id', v_lote, 'qtd_pecas', v_qtd);
END $$;

-- desfaz: so volta a peca que ainda esta com o valor que o lote deixou; as editadas depois sao puladas
CREATE OR REPLACE FUNCTION public.reajuste_desfazer(p_lote uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_voltaram integer := 0; v_puladas integer := 0; it record; l record;
BEGIN
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
  RETURN jsonb_build_object('voltaram', v_voltaram, 'puladas_editadas_depois', v_puladas);
END $$;

REVOKE ALL ON FUNCTION public.reajuste_previa(jsonb, jsonb, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.reajuste_aplicar(jsonb, jsonb, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.reajuste_desfazer(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reajuste_previa(jsonb, jsonb, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.reajuste_aplicar(jsonb, jsonb, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.reajuste_desfazer(uuid) TO authenticated, service_role;
COMMIT;
