-- SPEC-243 (05/11): ligar a um PROJETO as vendas da Connect que entraram sem projeto (68 orçamentos de 05/11) — só Matheus e administração.
--  * connect_orcamento_projeto_manual: guarda o vínculo manual por orçamento da Connect, para ele SOBREVIVER à reimportação das planilhas
--    (a carga de Reserva/Entrega Futura passa a usar o vínculo manual quando as linhas não trazem projeto/cliente).
--  * ligar_projeto_connect(): grava o projeto no orçamento, nos projeto_itens e no espelho; completa o cliente se faltar; avisa se o cliente do projeto
--    é outro (só liga com confirmação); observação obrigatória; confere antes×depois que estoque, saldos, financeiro, vendas e valor dos projetos não mudaram.
--  * sync_projeto_valor_total: ignora item de orçamento da Connect (senão ligar a venda a um projeto recalcularia projetos.valor_total).
BEGIN;

CREATE TABLE IF NOT EXISTS public.connect_orcamento_projeto_manual (
  cod_orcamento_connect integer PRIMARY KEY,
  projeto_id            uuid NOT NULL REFERENCES public.projetos (id) ON DELETE CASCADE,
  cliente_id            uuid REFERENCES public.contatos (id) ON DELETE SET NULL,
  observacao            text NOT NULL CHECK (length(btrim(observacao)) > 0),
  usuario_id            uuid DEFAULT auth.uid(),
  criado_em             timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.connect_orcamento_projeto_manual ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.connect_orcamento_projeto_manual FROM anon, authenticated;
GRANT SELECT ON public.connect_orcamento_projeto_manual TO authenticated;
GRANT ALL ON public.connect_orcamento_projeto_manual TO service_role;
DROP POLICY IF EXISTS connect_orc_proj_manual_select ON public.connect_orcamento_projeto_manual;
CREATE POLICY connect_orc_proj_manual_select ON public.connect_orcamento_projeto_manual
  FOR SELECT TO authenticated USING ((SELECT public.pode_tratar_heranca_connect()));

CREATE OR REPLACE FUNCTION public.sync_projeto_valor_total()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- SPEC-243: item de orçamento da Connect nunca mexe em projetos.valor_total (a herança fica com preço 0 nos projeto_itens; ligar a venda a um
  -- projeto não pode recalcular o valor do projeto).
  IF EXISTS (SELECT 1 FROM public.orcamentos o WHERE o.id = COALESCE(NEW.orcamento_id, OLD.orcamento_id) AND o.origem = 'connect') THEN
    RETURN COALESCE(NEW, OLD);
  END IF;
  UPDATE projetos
  SET valor_total = (SELECT COALESCE(SUM(subtotal), 0) FROM projeto_itens WHERE projeto_id = projetos.id)
  WHERE id IN (NEW.projeto_id, OLD.projeto_id);
  RETURN COALESCE(NEW, OLD);
END;
$function$;


CREATE OR REPLACE FUNCTION public.ligar_projeto_connect(
  p_orcamento_id uuid, p_projeto_id uuid, p_observacao text, p_confirmar_cliente_diferente boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
DECLARE
  v_orc   record;
  v_proj  record;
  v_nome  text;
  v_n     integer;
  a text; b text;
BEGIN
  IF NOT public.pode_tratar_heranca_connect() THEN
    RAISE EXCEPTION 'Só o Matheus ou um administrador pode ligar uma venda da Connect a um projeto.' USING ERRCODE = '42501';
  END IF;
  IF p_observacao IS NULL OR length(btrim(p_observacao)) = 0 THEN
    RAISE EXCEPTION 'A observação é obrigatória (por que esta venda é deste projeto).' USING ERRCODE = 'P0001';
  END IF;

  SELECT o.id, o.numero, o.origem, o.projeto_id, o.cliente_id, o.origem_connect_cod_orcamento
    INTO v_orc FROM public.orcamentos o WHERE o.id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND OR v_orc.origem IS DISTINCT FROM 'connect' THEN
    RAISE EXCEPTION 'Este orçamento não é herança da Connect.' USING ERRCODE = 'P0001';
  END IF;
  IF v_orc.projeto_id IS NOT NULL THEN
    RAISE EXCEPTION 'Este orçamento já está ligado a um projeto.' USING ERRCODE = 'P0001';
  END IF;
  IF v_orc.origem_connect_cod_orcamento IS NULL THEN
    RAISE EXCEPTION 'Orçamento da Connect sem código de origem.' USING ERRCODE = 'P0001';
  END IF;

  SELECT p.id, p.codigo, p.nome, p.cliente_id INTO v_proj FROM public.projetos p WHERE p.id = p_projeto_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Projeto não encontrado.' USING ERRCODE = 'P0001';
  END IF;

  IF v_orc.cliente_id IS NOT NULL AND v_proj.cliente_id IS NOT NULL AND v_orc.cliente_id <> v_proj.cliente_id
     AND NOT coalesce(p_confirmar_cliente_diferente, false) THEN
    RETURN jsonb_build_object('ligado', false, 'cliente_diferente', true,
      'cliente_venda', (SELECT nome FROM public.contatos WHERE id = v_orc.cliente_id),
      'cliente_projeto', (SELECT nome FROM public.contatos WHERE id = v_proj.cliente_id));
  END IF;

  -- fotografia do que NÃO pode mudar
  SELECT concat_ws('|',
           (SELECT coalesce(sum(quantidade),0) || '/' || coalesce(sum(quantidade_reservada),0) FROM public.estoque_itens),
           (SELECT coalesce(sum(q_reserva),0) || '/' || coalesce(sum(q_entrega_futura),0) || '/' || coalesce(sum(q_ag_separar),0) || '/' || coalesce(sum(q_separado),0) || '/' || coalesce(sum(q_entregue),0) || '/' || coalesce(sum(q_devolvida),0) FROM public.estoque_saldos_projeto_item),
           (SELECT count(*) FROM public.transacoes), (SELECT count(*) FROM public.projeto_parcelas), (SELECT count(*) FROM public.boletos),
           (SELECT count(*) FROM public.vendas), (SELECT coalesce(sum(valor_total),0) FROM public.projetos), (SELECT count(*) FROM public.projeto_itens))
    INTO a;

  SELECT coalesce(nullif(u.nome, ''), u.email) INTO v_nome FROM public.usuarios u WHERE u.id = auth.uid();

  INSERT INTO public.connect_orcamento_projeto_manual (cod_orcamento_connect, projeto_id, cliente_id, observacao)
  VALUES (v_orc.origem_connect_cod_orcamento, v_proj.id, coalesce(v_orc.cliente_id, v_proj.cliente_id), btrim(p_observacao))
  ON CONFLICT (cod_orcamento_connect) DO UPDATE
     SET projeto_id = EXCLUDED.projeto_id, cliente_id = EXCLUDED.cliente_id, observacao = EXCLUDED.observacao,
         usuario_id = auth.uid(), criado_em = now();

  UPDATE public.orcamentos
     SET projeto_id = v_proj.id,
         cliente_id = coalesce(cliente_id, v_proj.cliente_id),
         observacoes = coalesce(observacoes, '') || ' Projeto ' || v_proj.codigo || ' ligado em ' || to_char(now() AT TIME ZONE 'America/Sao_Paulo', 'DD/MM/YYYY')
                       || ' por ' || coalesce(v_nome, '-') || ': ' || btrim(p_observacao) || '.'
   WHERE id = v_orc.id;

  UPDATE public.projeto_itens SET projeto_id = v_proj.id WHERE orcamento_id = v_orc.id AND projeto_id IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;

  UPDATE public.connect_reserva_ambiente
     SET projeto_id = v_proj.id, cliente_id = coalesce(cliente_id, v_proj.cliente_id)
   WHERE cod_orcamento_connect = v_orc.origem_connect_cod_orcamento AND projeto_id IS NULL;

  SELECT concat_ws('|',
           (SELECT coalesce(sum(quantidade),0) || '/' || coalesce(sum(quantidade_reservada),0) FROM public.estoque_itens),
           (SELECT coalesce(sum(q_reserva),0) || '/' || coalesce(sum(q_entrega_futura),0) || '/' || coalesce(sum(q_ag_separar),0) || '/' || coalesce(sum(q_separado),0) || '/' || coalesce(sum(q_entregue),0) || '/' || coalesce(sum(q_devolvida),0) FROM public.estoque_saldos_projeto_item),
           (SELECT count(*) FROM public.transacoes), (SELECT count(*) FROM public.projeto_parcelas), (SELECT count(*) FROM public.boletos),
           (SELECT count(*) FROM public.vendas), (SELECT coalesce(sum(valor_total),0) FROM public.projetos), (SELECT count(*) FROM public.projeto_itens))
    INTO b;
  IF a IS DISTINCT FROM b THEN
    RAISE EXCEPTION 'Ligar o projeto alterou estoque, saldos, financeiro, vendas ou valor dos projetos (% x %). Desfeito.', a, b USING ERRCODE = 'P0001';
  END IF;

  RETURN jsonb_build_object('ligado', true, 'orcamento', v_orc.numero, 'projeto', v_proj.codigo, 'itens_ligados', v_n);
END
$fn$;
REVOKE ALL ON FUNCTION public.ligar_projeto_connect(uuid, uuid, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ligar_projeto_connect(uuid, uuid, text, boolean) TO authenticated;

-- A carga de Reserva/Entrega Futura passa a respeitar o vínculo manual (sobrevive à reimportação)
CREATE OR REPLACE FUNCTION public.carregar_connect_reserva_ambiente(p_lote uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_orc_novos      integer := 0;
  v_itens_novos    integer := 0;
  v_linhas_ok      integer := 0;
  v_linhas_sem     integer := 0;
  v_conflitos      integer := 0;
  -- fotografia do que NÃO pode mudar
  e0 numeric; r0 numeric; t0 bigint; p0 bigint; b0 bigint; v0 bigint;
  e1 numeric; r1 numeric; t1 bigint; p1 bigint; b1 bigint; v1 bigint;
BEGIN
  IF NOT (auth.role() = 'service_role' OR session_user IN ('postgres', 'supabase_admin') OR coalesce(public.is_admin(), false)) THEN
    RAISE EXCEPTION 'Só a carga administrativa (service_role) ou um administrador pode carregar a herança Connect.' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.connect_reserva_ambiente WHERE lote_importacao = p_lote) THEN
    RAISE EXCEPTION 'Lote % não existe no espelho.', p_lote USING ERRCODE = 'P0001';
  END IF;

  SELECT coalesce(sum(quantidade), 0), coalesce(sum(quantidade_reservada), 0) INTO e0, r0 FROM public.estoque_itens;
  SELECT count(*) INTO t0 FROM public.transacoes;
  SELECT count(*) INTO p0 FROM public.projeto_parcelas;
  SELECT count(*) INTO b0 FROM public.boletos;
  SELECT count(*) INTO v0 FROM public.vendas;

  ALTER TABLE public.projeto_itens DISABLE TRIGGER trg_sync_valor_total;
  ALTER TABLE public.orcamentos    DISABLE TRIGGER trg_sync_contact_type_on_budget;

  DROP TABLE IF EXISTS _cra_elegiveis, _cra_conflito, _cra_orc, _cra_item;

  -- Linhas elegíveis: têm todos os vínculos e ainda não viraram orçamento; linhas já "matadas" não voltam.
  CREATE TEMP TABLE _cra_elegiveis AS
  SELECT r.*
    FROM public.connect_reserva_ambiente r
   WHERE r.lote_importacao = p_lote
     AND r.orcamento_id IS NULL
     AND r.cod_orcamento_connect IS NOT NULL
     AND r.produto_id IS NOT NULL   -- 277: projeto, empresa e cliente deixam de ser exigidos (venda sem vínculo também vira orçamento)
     AND NOT EXISTS (SELECT 1 FROM public.connect_reserva_tratamento t
                      WHERE t.chave = r.chave
                        AND t.acao IN ('entregue_sem_estoque', 'entregue_voltou_ao_estoque', 'cancelada_volta_ao_estoque'));

  -- Um orçamento Connect por cod_orcamento_connect. Se as linhas do mesmo orçamento discordam de projeto/cliente/empresa,
  -- o orçamento NÃO é gerado (fica no espelho para revisão).
  CREATE TEMP TABLE _cra_conflito AS
  SELECT cod_orcamento_connect
    FROM _cra_elegiveis
   GROUP BY cod_orcamento_connect
  HAVING count(DISTINCT projeto_id) > 1 OR count(DISTINCT cliente_id) > 1 OR count(DISTINCT empresa_id) > 1;
  GET DIAGNOSTICS v_conflitos = ROW_COUNT;
  DELETE FROM _cra_elegiveis WHERE cod_orcamento_connect IN (SELECT cod_orcamento_connect FROM _cra_conflito);
  UPDATE public.connect_reserva_ambiente r
     SET motivo_sem_vinculo = trim(both ',' FROM coalesce(r.motivo_sem_vinculo, '') || ',orcamento_com_vinculos_conflitantes')
   WHERE r.lote_importacao = p_lote AND r.cod_orcamento_connect IN (SELECT cod_orcamento_connect FROM _cra_conflito);

  -- Orçamentos
  CREATE TEMP TABLE _cra_orc AS
  SELECT gen_random_uuid() AS orc_id, g.*
    FROM (
      SELECT e.cod_orcamento_connect,
             min(e.cod_venda_connect)                       AS cod_venda_connect,
             (array_agg(e.empresa_id) FILTER (WHERE e.empresa_id IS NOT NULL))[1] AS empresa_id,
             coalesce((array_agg(e.projeto_id) FILTER (WHERE e.projeto_id IS NOT NULL))[1],
                      (SELECT m.projeto_id FROM public.connect_orcamento_projeto_manual m WHERE m.cod_orcamento_connect = e.cod_orcamento_connect)) AS projeto_id,
             coalesce((array_agg(e.cliente_id) FILTER (WHERE e.cliente_id IS NOT NULL))[1],
                      (SELECT m.cliente_id FROM public.connect_orcamento_projeto_manual m WHERE m.cod_orcamento_connect = e.cod_orcamento_connect)) AS cliente_id,
             min(e.nome_bruto)                              AS nome_bruto,
             (array_agg(e.funcionario_id) FILTER (WHERE e.funcionario_id IS NOT NULL))[1] AS funcionario_id,
             (array_agg(e.digitado_por)   FILTER (WHERE e.digitado_por   IS NOT NULL))[1] AS digitado_por,
             (array_agg(e.equipe_id)      FILTER (WHERE e.equipe_id      IS NOT NULL))[1] AS equipe_id,
             (array_agg(DISTINCT e.cod_venda_connect) FILTER (WHERE e.cod_venda_connect IS NOT NULL)) AS vendas
        FROM _cra_elegiveis e
       GROUP BY e.cod_orcamento_connect
    ) g;

  INSERT INTO public.orcamentos
        (id, empresa_id, cliente_id, vendedor_id, digitado_por, equipe_id, projeto_id, status, numero, numero_venda,
         valor_total, observacoes, origem, connect_lote, origem_connect_cod_orcamento, origem_connect_importado_em,
         vendas_vinculadas_connect, vinculo_connect)
  SELECT o.orc_id, coalesce(o.empresa_id, (SELECT id FROM public.empresas WHERE nome = 'MANOELLA' LIMIT 1)), o.cliente_id, o.funcionario_id, o.digitado_por, o.equipe_id, o.projeto_id,
         'Orçamento Aprovado', 'CNX-' || o.cod_orcamento_connect,
         CASE WHEN o.cod_venda_connect IS NULL THEN NULL ELSE 'CNX-' || o.cod_venda_connect END,
         0, 'Histórico da Connect (SPEC-243): reserva e entrega futura herdadas. Somente consulta. O valor é a soma das peças que a Connect ainda tem em Reserva e Entrega Futura (não é o valor total da venda).'
         || CASE WHEN o.projeto_id IS NULL THEN ' SEM PROJETO identificado: o ambiente na Connect é "' || coalesce(o.nome_bruto, '') || '". Ligar ao projeto quando for confirmado.' ELSE '' END
         || CASE WHEN o.empresa_id IS NULL THEN ' Empresa não deduzida pelo Contas a Receber/Pagar: MANOELLA provisória.' ELSE '' END,
         'connect', p_lote, o.cod_orcamento_connect, now(),
         coalesce(o.vendas, '{}'::integer[]), false
    FROM _cra_orc o;
  GET DIAGNOSTICS v_orc_novos = ROW_COUNT;

  -- Itens por (orçamento, peça, L): quantidade = Reserva + Entrega Futura da Connect (o entregue não vem da planilha)
  CREATE TEMP TABLE _cra_item AS
  SELECT gen_random_uuid() AS item_id, gen_random_uuid() AS oi_id, o.orc_id, o.projeto_id, e.produto_id, e.ambiente,
         sum(e.valor_venda)                                                  AS valor_linhas,
         round(sum(e.quantidade) FILTER (WHERE e.tipo = 'reserva'), 2)        AS q_res,
         round(sum(e.quantidade) FILTER (WHERE e.tipo = 'entrega_futura'), 2) AS q_ef,
         (array_agg(e.descricao))[1]                                          AS descricao
    FROM _cra_elegiveis e JOIN _cra_orc o USING (cod_orcamento_connect)
   GROUP BY o.orc_id, o.projeto_id, e.produto_id, e.ambiente;

  -- Itens do ORÇAMENTO (é o que o sistema Orçamentos lista), como a aprovação normal faz: o L fica em custom_id e
  -- projeto_itens.orcamento_item_id aponta para ele. Preço = valor da planilha ÷ quantidade (só aqui; projeto_itens fica com 0
  -- para nunca mexer em projetos.valor_total).
  -- ATENÇÃO: inserir item em orçamento 'Orçamento Aprovado' dispararia handle_orcamento_item_change_reset (volta o orçamento
  -- para 'enviado_cliente' e gera token). app.skip_approval_reset (local à transação) é o desvio oficial desse gatilho.
  PERFORM set_config('app.skip_approval_reset', 'true', true);
  INSERT INTO public.orcamento_itens (id, orcamento_id, produto_id, quantidade, preco_unitario, desconto, descricao, ordem, custom_id)
  SELECT i.oi_id, i.orc_id, i.produto_id, coalesce(i.q_res, 0) + coalesce(i.q_ef, 0),
         CASE WHEN coalesce(i.valor_linhas, 0) > 0 THEN round(i.valor_linhas / (coalesce(i.q_res, 0) + coalesce(i.q_ef, 0)), 2) ELSE 0 END,
         0, coalesce(nullif(btrim(i.descricao), ''), 'Item sem descrição'),
         row_number() OVER (PARTITION BY i.orc_id ORDER BY nullif(btrim(coalesce(i.ambiente, '')), '') NULLS LAST, i.produto_id)::integer,
         nullif(btrim(coalesce(i.ambiente, '')), '')
    FROM _cra_item i
   WHERE coalesce(i.q_res, 0) + coalesce(i.q_ef, 0) > 0;

  -- Valor do orçamento = soma dos itens (quantidade × preço já arredondado a 2 casas, como a tela soma). Um UPDATE de valor_total em orçamento
  -- aprovado dispararia handle_orcamento_workflow (reinício da aprovação + histórico); por isso o gatilho fica desligado só aqui, dentro da transação.
  ALTER TABLE public.orcamentos DISABLE TRIGGER trg_orcamento_workflow;
  UPDATE public.orcamentos o
     SET valor_total = (SELECT coalesce(sum(oi.quantidade * oi.preco_unitario), 0) FROM public.orcamento_itens oi WHERE oi.orcamento_id = o.id)
   WHERE o.id IN (SELECT orc_id FROM _cra_orc);
  ALTER TABLE public.orcamentos ENABLE TRIGGER trg_orcamento_workflow;

  INSERT INTO public.projeto_itens (id, projeto_id, produto_id, descricao, quantidade, preco_unitario, desconto, validado, orcamento_id, orcamento_item_id, l_fixo)
  SELECT i.item_id, i.projeto_id, i.produto_id, coalesce(nullif(btrim(i.descricao), ''), 'Item sem descrição'),
         coalesce(i.q_res, 0) + coalesce(i.q_ef, 0), 0, 0, true, i.orc_id, i.oi_id, nullif(btrim(coalesce(i.ambiente, '')), '')
    FROM _cra_item i
   WHERE coalesce(i.q_res, 0) + coalesce(i.q_ef, 0) > 0;
  GET DIAGNOSTICS v_itens_novos = ROW_COUNT;

  INSERT INTO public.estoque_saldos_projeto_item (projeto_item_id, q_reserva, q_entrega_futura)
  SELECT i.item_id, coalesce(i.q_res, 0), coalesce(i.q_ef, 0)
    FROM _cra_item i
   WHERE coalesce(i.q_res, 0) + coalesce(i.q_ef, 0) > 0;

  -- Devolve os vínculos ao espelho
  UPDATE public.connect_reserva_ambiente r
     SET orcamento_id = o.orc_id,
         projeto_item_id = i.item_id
    FROM _cra_elegiveis e
    JOIN _cra_orc o USING (cod_orcamento_connect)
    JOIN _cra_item i ON i.orc_id = o.orc_id AND i.produto_id = e.produto_id AND i.ambiente IS NOT DISTINCT FROM e.ambiente
   WHERE r.id = e.id;
  GET DIAGNOSTICS v_linhas_ok = ROW_COUNT;

  SELECT count(*) INTO v_linhas_sem FROM public.connect_reserva_ambiente r WHERE r.lote_importacao = p_lote AND r.orcamento_id IS NULL;

  PERFORM set_config('app.skip_approval_reset', 'false', true);
  ALTER TABLE public.projeto_itens ENABLE TRIGGER trg_sync_valor_total;
  ALTER TABLE public.orcamentos    ENABLE TRIGGER trg_sync_contact_type_on_budget;
  DROP TABLE IF EXISTS _cra_elegiveis, _cra_conflito, _cra_orc, _cra_item;

  -- Prova de que nada fora do escopo mudou
  SELECT coalesce(sum(quantidade), 0), coalesce(sum(quantidade_reservada), 0) INTO e1, r1 FROM public.estoque_itens;
  SELECT count(*) INTO t1 FROM public.transacoes;
  SELECT count(*) INTO p1 FROM public.projeto_parcelas;
  SELECT count(*) INTO b1 FROM public.boletos;
  SELECT count(*) INTO v1 FROM public.vendas;
  IF (e0, r0, t0, p0, b0, v0) IS DISTINCT FROM (e1, r1, t1, p1, b1, v1) THEN
    RAISE EXCEPTION 'A carga alterou estoque, financeiro ou vendas (%/% x %/%). Desfeita.', e0 || ',' || r0, t0 || ',' || p0 || ',' || b0 || ',' || v0, e1 || ',' || r1, t1 || ',' || p1 || ',' || b1 || ',' || v1
      USING ERRCODE = 'P0001';
  END IF;

  RETURN jsonb_build_object('lote', p_lote, 'orcamentos_criados', v_orc_novos, 'itens_criados', v_itens_novos,
                            'linhas_vinculadas', v_linhas_ok, 'linhas_so_no_espelho', v_linhas_sem,
                            'orcamentos_com_conflito', v_conflitos);
END
$function$;

COMMIT;
