-- SPEC-294: aplicar_xml_connect_orcamentos casa linha do XML sem cod_produto pela referencia (evita item avulso duplicado).
-- Unica mudanca vs migration 273: CTE _x_grp (resolve produto por referencia) e filtro de _x_avulso.
BEGIN;
CREATE OR REPLACE FUNCTION public.aplicar_xml_connect_orcamentos()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $fn$
DECLARE
  v_orc integer := 0; v_it_upd integer := 0; v_it_new integer := 0; v_sem_prod integer := 0; v_menor integer := 0;
  v_emp_trocada integer := 0; v_desc integer := 0; v_total_maior integer := 0; v_sem_xml integer := 0; v_avulsos integer := 0;
  e0 numeric; r0 numeric; t0 bigint; p0 bigint; b0 bigint; v0 bigint; pj0 bigint; op0 text;
  e1 numeric; r1 numeric; t1 bigint; p1 bigint; b1 bigint; v1 bigint; pj1 bigint; op1 text;
BEGIN
  IF NOT (auth.role() = 'service_role' OR session_user IN ('postgres', 'supabase_admin') OR coalesce(public.is_admin(), false)) THEN
    RAISE EXCEPTION 'Só a carga administrativa (service_role) ou um administrador pode aplicar o XML da Connect.' USING ERRCODE = '42501';
  END IF;

  SELECT coalesce(sum(quantidade), 0), coalesce(sum(quantidade_reservada), 0) INTO e0, r0 FROM public.estoque_itens;
  SELECT count(*) INTO t0 FROM public.transacoes;
  SELECT count(*) INTO p0 FROM public.projeto_parcelas;
  SELECT count(*) INTO b0 FROM public.boletos;
  SELECT count(*) INTO v0 FROM public.vendas;
  SELECT count(*) INTO pj0 FROM public.projetos WHERE valor_total IS NOT NULL AND valor_total <> 0;
  SELECT (SELECT concat_ws('|', count(*), coalesce(sum(pi.quantidade),0), coalesce(sum(s.q_reserva),0), coalesce(sum(s.q_entrega_futura),0),
                                  coalesce(sum(s.q_ag_separar),0), coalesce(sum(s.q_separado),0), coalesce(sum(s.q_entregue),0), coalesce(sum(pi.preco_unitario),0))
                 FROM public.projeto_itens pi JOIN public.orcamentos o ON o.id = pi.orcamento_id AND o.origem = 'connect'
                 LEFT JOIN public.estoque_saldos_projeto_item s ON s.projeto_item_id = pi.id) INTO op0;

  DROP TABLE IF EXISTS _x_orc, _x_grp, _x_match, _x_novos, _x_avulso;

  -- orçamentos Connect do sistema que têm XML (empresa pelo CNPJ do XML)
  CREATE TEMP TABLE _x_orc AS
  SELECT o.id AS orc_id, o.empresa_id AS empresa_atual, x.cod_orcamento, x.vl_total_orcamento AS total, x.dt_orcamento, e.id AS empresa_xml
    FROM public.orcamentos o
    JOIN public.connect_xml_orcamento x ON x.cod_orcamento = o.origem_connect_cod_orcamento
    LEFT JOIN public.empresas e ON regexp_replace(coalesce(e.cnpj, ''), '\D', '', 'g') = regexp_replace(coalesce(x.cnpj_empresa, ''), '\D', '', 'g')
   WHERE o.origem = 'connect';
  GET DIAGNOSTICS v_orc = ROW_COUNT;
  SELECT count(*) INTO v_sem_xml FROM public.orcamentos o WHERE o.origem = 'connect' AND o.id NOT IN (SELECT orc_id FROM _x_orc);

  -- quantidade LÍQUIDA por (orçamento, L, peça): troca/devolução entra com sinal negativo; preço = média ponderada das linhas positivas
  CREATE TEMP TABLE _x_grp AS
  SELECT xo.orc_id, xi.cod_orcamento, nullif(btrim(coalesce(xi.desc_classificacao, '')), '') AS l, coalesce(p.id, pr.id) AS produto_id, coalesce(xi.cod_produto, pr.codigo_produto) AS cod_produto,
         sum(xi.qtd_produto) AS net,
         sum(xi.qtd_produto) FILTER (WHERE xi.qtd_produto > 0) AS pos_qtd,
         sum(xi.vl_total_produto) FILTER (WHERE xi.qtd_produto > 0) AS pos_total,
         (array_agg(xi.desc_produto ORDER BY xi.linha))[1] AS descr
    FROM public.connect_xml_item xi
    JOIN _x_orc xo USING (cod_orcamento)
    LEFT JOIN public.produtos p ON p.codigo_produto = xi.cod_produto
    -- SPEC-294: linha do XML SEM cod_produto casa pela REFERENCIA (so se ha uma unica peca com ela, ou se uma delas ja esta no projeto do orcamento)
    LEFT JOIN LATERAL (
      SELECT p2.id, p2.codigo_produto FROM public.produtos p2
       WHERE xi.cod_produto IS NULL AND nullif(btrim(coalesce(xi.referencia, '')), '') IS NOT NULL
         AND upper(btrim(p2.referencia)) = upper(btrim(xi.referencia))
         AND (EXISTS (SELECT 1 FROM public.projeto_itens pi2 WHERE pi2.orcamento_id = xo.orc_id AND pi2.produto_id = p2.id)
              OR (SELECT count(*) FROM public.produtos p3 WHERE upper(btrim(p3.referencia)) = upper(btrim(xi.referencia))) = 1)
       ORDER BY (EXISTS (SELECT 1 FROM public.projeto_itens pi2 WHERE pi2.orcamento_id = xo.orc_id AND pi2.produto_id = p2.id)) DESC, p2.id
       LIMIT 1) pr ON true
   GROUP BY xo.orc_id, xi.cod_orcamento, nullif(btrim(coalesce(xi.desc_classificacao, '')), ''), coalesce(p.id, pr.id), coalesce(xi.cod_produto, pr.codigo_produto);
  -- linhas SEM código de produto ("produto especial"/avulso): entram só como item do orçamento (para o total fechar), sem peça e sem estoque
  CREATE TEMP TABLE _x_avulso AS
  SELECT orc_id, l, net, round(pos_total / pos_qtd, 3) AS unit, descr FROM _x_grp WHERE cod_produto IS NULL AND produto_id IS NULL AND net > 0 AND coalesce(pos_qtd, 0) > 0;
  SELECT count(*) INTO v_sem_prod FROM _x_grp WHERE produto_id IS NULL AND cod_produto IS NOT NULL AND net > 0;
  DELETE FROM _x_grp WHERE produto_id IS NULL OR net <= 0 OR coalesce(pos_qtd, 0) <= 0;

  CREATE TEMP TABLE _x_match AS
  SELECT g.*, round(g.pos_total / g.pos_qtd, 3) AS unit, pi.id AS pi_id, pi.orcamento_item_id AS oi_id,
         coalesce(s.q_reserva, 0) + coalesce(s.q_entrega_futura, 0) AS pend
    FROM _x_grp g
    LEFT JOIN public.projeto_itens pi ON pi.orcamento_id = g.orc_id AND pi.produto_id = g.produto_id AND pi.l_fixo IS NOT DISTINCT FROM g.l
    LEFT JOIN public.estoque_saldos_projeto_item s ON s.projeto_item_id = pi.id;

  SELECT count(*) INTO v_menor FROM _x_match WHERE pi_id IS NOT NULL AND net < pend;

  ALTER TABLE public.orcamentos    DISABLE TRIGGER trg_orcamento_workflow;
  ALTER TABLE public.projeto_itens DISABLE TRIGGER trg_sync_valor_total;
  PERFORM set_config('app.skip_approval_reset', 'true', true);

  -- (a) itens que já existem (vieram da Reserva/Entrega Futura): SÓ o item do ORÇAMENTO (documento) recebe a quantidade e o preço do XML.
  --     projeto_itens e os saldos NÃO são tocados: a Venda Parcial e a herança continuam exatamente com o que as planilhas trouxeram.
  UPDATE public.orcamento_itens oi SET quantidade = m.net, preco_unitario = m.unit
    FROM _x_match m WHERE m.pi_id IS NOT NULL AND m.net >= m.pend AND oi.id = m.oi_id;
  GET DIAGNOSTICS v_it_upd = ROW_COUNT;

  -- (b) itens que só existem no XML (a Connect já entregou): entram SÓ no documento do orçamento (orcamento_itens), sem projeto_item e sem saldo.
  --     Recriados a cada execução (idempotente): os da execução anterior são os orcamento_itens com produto e SEM projeto_itens apontando para eles.
  DELETE FROM public.orcamento_itens oi
   WHERE oi.orcamento_id IN (SELECT orc_id FROM _x_orc) AND oi.produto_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.projeto_itens pi WHERE pi.orcamento_item_id = oi.id);
  CREATE TEMP TABLE _x_novos AS
  SELECT m.*, (SELECT coalesce(max(oi.ordem), 0) FROM public.orcamento_itens oi WHERE oi.orcamento_id = m.orc_id)
           + row_number() OVER (PARTITION BY m.orc_id ORDER BY m.l NULLS LAST, m.cod_produto) AS nova_ordem
    FROM _x_match m WHERE m.pi_id IS NULL;
  INSERT INTO public.orcamento_itens (orcamento_id, produto_id, quantidade, preco_unitario, desconto, descricao, ordem, custom_id)
  SELECT orc_id, produto_id, net, unit, 0, coalesce(nullif(btrim(descr), ''), 'Item sem descrição'), nova_ordem::integer, l FROM _x_novos;
  GET DIAGNOSTICS v_it_new = ROW_COUNT;

  -- (b2) itens avulsos (sem código de produto): recriados a cada execução, só em orcamento_itens
  DELETE FROM public.orcamento_itens WHERE produto_id IS NULL AND orcamento_id IN (SELECT orc_id FROM _x_orc);
  INSERT INTO public.orcamento_itens (orcamento_id, produto_id, quantidade, preco_unitario, desconto, descricao, ordem, custom_id)
  SELECT a.orc_id, NULL, a.net, a.unit, 0, coalesce(nullif(btrim(a.descr), ''), 'Item avulso (sem código de produto)'),
         (SELECT coalesce(max(oi.ordem), 0) FROM public.orcamento_itens oi WHERE oi.orcamento_id = a.orc_id) + (row_number() OVER (PARTITION BY a.orc_id ORDER BY a.l NULLS LAST))::integer, a.l
    FROM _x_avulso a;
  GET DIAGNOSTICS v_avulsos = ROW_COUNT;

  -- (c) orçamento: total REAL do XML, desconto geral = soma dos itens − total, empresa e data do XML
  SELECT count(*) INTO v_emp_trocada FROM _x_orc WHERE empresa_xml IS NOT NULL AND empresa_xml IS DISTINCT FROM empresa_atual;
  UPDATE public.orcamentos o
     SET empresa_id    = coalesce(xo.empresa_xml, o.empresa_id),
         data_emissao  = coalesce(xo.dt_orcamento::timestamptz, o.data_emissao),
         valor_total   = xo.total,
         desconto_tipo = 'valor',
         desconto_global = greatest(0, round((SELECT coalesce(sum(oi.quantidade * oi.preco_unitario), 0) FROM public.orcamento_itens oi WHERE oi.orcamento_id = o.id) - xo.total, 2))
    FROM _x_orc xo WHERE o.id = xo.orc_id AND xo.total IS NOT NULL;
  SELECT count(*) INTO v_desc FROM public.orcamentos o JOIN _x_orc xo ON xo.orc_id = o.id WHERE o.desconto_global > 0;
  SELECT count(*) INTO v_total_maior FROM public.orcamentos o JOIN _x_orc xo ON xo.orc_id = o.id
   WHERE xo.total > (SELECT coalesce(sum(oi.quantidade * oi.preco_unitario), 0) FROM public.orcamento_itens oi WHERE oi.orcamento_id = o.id) + 1;

  PERFORM set_config('app.skip_approval_reset', 'false', true);
  ALTER TABLE public.projeto_itens ENABLE TRIGGER trg_sync_valor_total;
  ALTER TABLE public.orcamentos    ENABLE TRIGGER trg_orcamento_workflow;
  DROP TABLE IF EXISTS _x_orc, _x_grp, _x_match, _x_novos, _x_avulso;

  SELECT coalesce(sum(quantidade), 0), coalesce(sum(quantidade_reservada), 0) INTO e1, r1 FROM public.estoque_itens;
  SELECT count(*) INTO t1 FROM public.transacoes;
  SELECT count(*) INTO p1 FROM public.projeto_parcelas;
  SELECT count(*) INTO b1 FROM public.boletos;
  SELECT count(*) INTO v1 FROM public.vendas;
  SELECT count(*) INTO pj1 FROM public.projetos WHERE valor_total IS NOT NULL AND valor_total <> 0;
  SELECT (SELECT concat_ws('|', count(*), coalesce(sum(pi.quantidade),0), coalesce(sum(s.q_reserva),0), coalesce(sum(s.q_entrega_futura),0),
                                  coalesce(sum(s.q_ag_separar),0), coalesce(sum(s.q_separado),0), coalesce(sum(s.q_entregue),0), coalesce(sum(pi.preco_unitario),0))
                 FROM public.projeto_itens pi JOIN public.orcamentos o ON o.id = pi.orcamento_id AND o.origem = 'connect'
                 LEFT JOIN public.estoque_saldos_projeto_item s ON s.projeto_item_id = pi.id) INTO op1;
  IF (e0, r0, t0, p0, b0, v0, pj0, op0) IS DISTINCT FROM (e1, r1, t1, p1, b1, v1, pj1, op1) THEN
    RAISE EXCEPTION 'O XML alterou quantidade (estoque, reserva, entrega futura, entregue, itens da venda), financeiro, vendas ou valor de projeto. Desfeito.' USING ERRCODE = 'P0001';
  END IF;

  RETURN jsonb_build_object('orcamentos_com_xml', v_orc, 'orcamentos_sem_xml', v_sem_xml, 'itens_do_orcamento_atualizados', v_it_upd, 'itens_so_do_xml_no_documento', v_it_new,
                            'itens_avulsos_sem_codigo_de_produto', v_avulsos, 'grupos_com_codigo_fora_do_cadastro', v_sem_prod, 'itens_xml_menor_que_pendente_ignorados', v_menor,
                            'empresas_alteradas', v_emp_trocada, 'orcamentos_com_desconto_geral', v_desc, 'orcamentos_total_maior_que_itens', v_total_maior);
END
$fn$;
REVOKE ALL ON FUNCTION public.aplicar_xml_connect_orcamentos() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.aplicar_xml_connect_orcamentos() TO service_role;

CREATE TEMP TABLE _antes AS SELECT orcamento_id, count(*) n, round(sum(quantidade*preco_unitario),2) base FROM public.orcamento_itens GROUP BY 1;
SELECT public.aplicar_xml_connect_orcamentos();
DO $$ DECLARE r record; BEGIN
  FOR r IN SELECT o.numero, a.n n_antes, d.n n_depois, a.base base_antes, d.base base_depois
    FROM _antes a JOIN (SELECT orcamento_id, count(*) n, round(sum(quantidade*preco_unitario),2) base FROM public.orcamento_itens GROUP BY 1) d USING (orcamento_id)
    JOIN public.orcamentos o ON o.id=a.orcamento_id WHERE a.n<>d.n OR a.base<>d.base ORDER BY 1 LOOP
    RAISE NOTICE '% itens % -> %  base % -> %', r.numero, r.n_antes, r.n_depois, r.base_antes, r.base_depois;
  END LOOP;
  RAISE NOTICE 'CNX-8479 itens: %', (SELECT count(*) FROM public.orcamento_itens i JOIN public.orcamentos o ON o.id=i.orcamento_id WHERE o.numero='CNX-8479');
  RAISE NOTICE 'orcamentos Connect com linha duplicada sem vinculo: %', (SELECT count(DISTINCT i.orcamento_id) FROM public.orcamento_itens i
     JOIN public.orcamentos o ON o.id=i.orcamento_id AND o.origem='connect'
     WHERE i.produto_id IS NULL AND EXISTS (SELECT 1 FROM public.orcamento_itens j WHERE j.orcamento_id=i.orcamento_id AND j.id<>i.id AND j.custom_id=i.custom_id AND j.quantidade=i.quantidade AND j.preco_unitario=i.preco_unitario));
END $$;
ROLLBACK;
