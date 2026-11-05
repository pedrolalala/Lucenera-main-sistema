-- Dry-run da 271: troca as funções, REMOVE e RECARREGA o lote atual dentro da transação, confere e DESFAZ. Termina em ROLLBACK.
BEGIN;
-- SPEC-243 (RASCUNHO, NÃO APLICADA) — os orçamentos Connect passam a ter os ITENS DO ORÇAMENTO (orcamento_itens).
-- Defeito: a carga criava só projeto_itens (o que a Venda Parcial lê), então o sistema Orçamentos abria o orçamento sem nenhum produto.
-- Correção: a carga também cria orcamento_itens (peça, quantidade, preço = valor da planilha ÷ quantidade, L em custom_id, como a aprovação normal)
-- e liga projeto_itens.orcamento_item_id a eles. projeto_itens segue com preço 0 (nunca mexe em projetos.valor_total).
-- Cuidado tratado: inserir/apagar item em orçamento aprovado reiniciaria a aprovação (handle_orcamento_item_change_reset); a função usa app.skip_approval_reset.
-- Para os 230 orçamentos já gravados: reimportar (python scripts/importar_reserva_entrega_futura_connect.py --aplicar).

CREATE OR REPLACE FUNCTION public.carregar_connect_reserva_ambiente(p_lote uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
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
     AND r.empresa_id IS NOT NULL AND r.projeto_id IS NOT NULL AND r.cliente_id IS NOT NULL AND r.produto_id IS NOT NULL
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
  SELECT gen_random_uuid() AS orc_id, g.*, public._valor_venda_connect(g.vendas) AS valor_total
    FROM (
      SELECT e.cod_orcamento_connect,
             min(e.cod_venda_connect)                       AS cod_venda_connect,
             (array_agg(e.empresa_id))[1]                   AS empresa_id,
             (array_agg(e.projeto_id))[1]                   AS projeto_id,
             (array_agg(e.cliente_id))[1]                   AS cliente_id,
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
  SELECT o.orc_id, o.empresa_id, o.cliente_id, o.funcionario_id, o.digitado_por, o.equipe_id, o.projeto_id,
         'Orçamento Aprovado', 'CNX-' || o.cod_orcamento_connect,
         CASE WHEN o.cod_venda_connect IS NULL THEN NULL ELSE 'CNX-' || o.cod_venda_connect END,
         o.valor_total, 'Histórico da Connect (SPEC-243): reserva e entrega futura herdadas. Somente consulta. O valor é o total da venda no Contas a Receber da Connect (parcelas vigentes).',
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
$fn$;

CREATE OR REPLACE FUNCTION public.remover_connect_lote(p_lote uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
DECLARE
  v_orc integer; v_itens integer;
BEGIN
  IF NOT (auth.role() = 'service_role' OR session_user IN ('postgres', 'supabase_admin') OR coalesce(public.is_admin(), false)) THEN
    RAISE EXCEPTION 'Só a carga administrativa (service_role) ou um administrador pode remover um lote da Connect.' USING ERRCODE = '42501';
  END IF;

  IF EXISTS (
    SELECT 1
      FROM public.projeto_itens pi
      JOIN public.orcamentos o ON o.id = pi.orcamento_id AND o.origem = 'connect' AND o.connect_lote = p_lote
      JOIN public.estoque_saldos_projeto_item s ON s.projeto_item_id = pi.id
     WHERE s.q_ag_separar + s.q_separado + s.q_entregue + s.q_devolvida + s.q_transferida_saida > 0
  ) OR EXISTS (
    SELECT 1 FROM public.separacao_itens si
      JOIN public.projeto_itens pi ON pi.id = si.projeto_item_id
      JOIN public.orcamentos o ON o.id = pi.orcamento_id AND o.origem = 'connect' AND o.connect_lote = p_lote
  ) THEN
    RAISE EXCEPTION 'O lote % já teve separação/entrega/devolução no sistema; não pode ser removido por inteiro.', p_lote USING ERRCODE = 'P0001';
  END IF;

  ALTER TABLE public.projeto_itens DISABLE TRIGGER trg_sync_valor_total;

  UPDATE public.connect_reserva_ambiente SET orcamento_id = NULL, projeto_item_id = NULL
   WHERE lote_importacao = p_lote OR orcamento_id IN (SELECT id FROM public.orcamentos WHERE origem = 'connect' AND connect_lote = p_lote);

  DELETE FROM public.estoque_saldos_projeto_item
   WHERE projeto_item_id IN (SELECT pi.id FROM public.projeto_itens pi JOIN public.orcamentos o ON o.id = pi.orcamento_id
                              WHERE o.origem = 'connect' AND o.connect_lote = p_lote);
  DELETE FROM public.projeto_itens
   WHERE orcamento_id IN (SELECT id FROM public.orcamentos WHERE origem = 'connect' AND connect_lote = p_lote);
  GET DIAGNOSTICS v_itens = ROW_COUNT;
  -- SPEC-243: orcamento_itens saem ANTES do orçamento (projeto_itens.orcamento_item_id já foi apagado acima) e sem o gatilho que
  -- reiniciaria a aprovação / tentaria gravar histórico de um orçamento que está saindo.
  PERFORM set_config('app.skip_approval_reset', 'true', true);
  DELETE FROM public.orcamento_itens
   WHERE orcamento_id IN (SELECT id FROM public.orcamentos WHERE origem = 'connect' AND connect_lote = p_lote);
  DELETE FROM public.orcamentos WHERE origem = 'connect' AND connect_lote = p_lote;
  GET DIAGNOSTICS v_orc = ROW_COUNT;
  PERFORM set_config('app.skip_approval_reset', 'false', true);

  ALTER TABLE public.projeto_itens ENABLE TRIGGER trg_sync_valor_total;
  RETURN jsonb_build_object('lote', p_lote, 'orcamentos_removidos', v_orc, 'itens_removidos', v_itens);
END
$fn$;

REVOKE ALL ON FUNCTION public.carregar_connect_reserva_ambiente(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.remover_connect_lote(uuid)               FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.carregar_connect_reserva_ambiente(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.remover_connect_lote(uuid)               TO service_role;


DO $$
DECLARE l uuid; r jsonb; n int; h0 int; h1 int; st0 int;
BEGIN
  SELECT DISTINCT connect_lote INTO l FROM public.orcamentos WHERE origem = 'connect';
  SELECT count(*) INTO h0 FROM public.historico_status_orcamentos;
  RAISE NOTICE 'remover: %', public.remover_connect_lote(l);
  RAISE NOTICE 'orcamento_itens depois de remover (esperado 0): %', (SELECT count(*) FROM public.orcamento_itens oi JOIN public.orcamentos o ON o.id=oi.orcamento_id WHERE o.origem='connect');
  RAISE NOTICE 'carregar: %', public.carregar_connect_reserva_ambiente(l);
  RAISE NOTICE 'orçamentos connect: % | todos Orçamento Aprovado: %', (SELECT count(*) FROM public.orcamentos WHERE origem='connect'),
        (SELECT count(*) FILTER (WHERE status = 'Orçamento Aprovado') FROM public.orcamentos WHERE origem='connect');
  RAISE NOTICE 'orcamento_itens: % | projeto_itens: % | projeto_itens ligados a orcamento_item: %',
        (SELECT count(*) FROM public.orcamento_itens oi JOIN public.orcamentos o ON o.id=oi.orcamento_id WHERE o.origem='connect'),
        (SELECT count(*) FROM public.projeto_itens pi JOIN public.orcamentos o ON o.id=pi.orcamento_id WHERE o.origem='connect'),
        (SELECT count(*) FROM public.projeto_itens pi JOIN public.orcamentos o ON o.id=pi.orcamento_id JOIN public.orcamento_itens oi ON oi.id=pi.orcamento_item_id WHERE o.origem='connect');
  SELECT count(*) INTO h1 FROM public.historico_status_orcamentos;
  RAISE NOTICE 'histórico de status (reinício de aprovação) criado: % linhas (esperado 0)', h1 - h0;
  RAISE NOTICE 'itens com L (custom_id) = L do projeto_item: %', (SELECT count(*) FROM public.projeto_itens pi JOIN public.orcamento_itens oi ON oi.id=pi.orcamento_item_id WHERE pi.l_fixo IS NOT DISTINCT FROM oi.custom_id);
  RAISE NOTICE 'quantidade igual nas duas tabelas: %', (SELECT count(*) FROM public.projeto_itens pi JOIN public.orcamento_itens oi ON oi.id=pi.orcamento_item_id WHERE pi.quantidade = oi.quantidade);
  RAISE NOTICE 'itens do orçamento com preço > 0: % | projeto_itens com preço > 0 (esperado 0): %',
        (SELECT count(*) FROM public.orcamento_itens oi JOIN public.orcamentos o ON o.id=oi.orcamento_id WHERE o.origem='connect' AND oi.preco_unitario > 0),
        (SELECT count(*) FROM public.projeto_itens pi JOIN public.orcamentos o ON o.id=pi.orcamento_id WHERE o.origem='connect' AND pi.preco_unitario > 0);
  RAISE NOTICE 'CNX-7994 itens (peça, L, qtd, preço): %', (SELECT string_agg(row(p.codigo_produto, oi.custom_id, oi.quantidade, oi.preco_unitario)::text, ' | ' ORDER BY oi.ordem)
        FROM (SELECT * FROM public.orcamento_itens WHERE orcamento_id = (SELECT id FROM public.orcamentos WHERE numero='CNX-7994') ORDER BY ordem LIMIT 3) oi JOIN public.produtos p ON p.id=oi.produto_id);
  RAISE NOTICE 'estoque/reservado iguais; projetos.valor_total (28): %', (SELECT count(*) FROM public.projetos WHERE valor_total IS NOT NULL AND valor_total <> 0);
  -- remover de novo funciona (FKs ok)
  RAISE NOTICE 'remover de novo: %', public.remover_connect_lote(l);
  RAISE NOTICE 'sobrou orcamento_itens/orcamentos Connect (esperado 0/0): %/%', (SELECT count(*) FROM public.orcamento_itens oi JOIN public.orcamentos o ON o.id=oi.orcamento_id WHERE o.origem='connect'), (SELECT count(*) FROM public.orcamentos WHERE origem='connect');
END $$;
ROLLBACK;
