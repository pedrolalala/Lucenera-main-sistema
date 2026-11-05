-- Dry-run da 269: troca a função, REMOVE e RECARREGA o lote atual dentro da transação e DESFAZ tudo. Termina em ROLLBACK.
BEGIN;
-- SPEC-243 (RASCUNHO, NÃO APLICADA) — o orçamento Connect passa a mostrar o TOTAL DA VENDA (antes ficava R$ 0,00).
-- Decisão do usuário (04/11): o valor do orçamento pode aparecer para visualização; o que não pode aparecer no CRM é quanto foi pago.
-- A planilha Reserva/Entrega Futura NÃO serve de fonte (traz só as peças ainda em aberto, ex.: venda 1264 = R$ 155 contra R$ 80.000);
-- o total vem do Contas a Receber já importado. Preço por item continua 0 e projetos.valor_total não muda (trigger desligado na carga).
-- Para os 191 orçamentos já gravados: reimportar (python scripts/importar_reserva_entrega_futura_connect.py --aplicar), que remove o lote e recarrega.

-- Total da venda da Connect, para exibir no orçamento (SÓ VISUALIZAÇÃO: nenhum item recebe preço e nada é pago/recebido por aqui).
-- Fonte: parcelas vigentes (status_pago <> 2) de receita do Contas a Receber que a Connect já exportou.
-- 1) transações marcadas com o número da venda; 2) se não houver, as da negociação da venda (transacoes antigas sem cod_venda).
-- NÃO usa vl_pago: o quanto foi pago nunca entra no orçamento (decisão do usuário, 04/11).
-- Venda sem parcela no Contas a Receber fica com 0. Renegociação (acordo) pode somar a duplicata consolidada, não a original.
CREATE OR REPLACE FUNCTION public._valor_venda_connect(p_vendas integer[])
RETURNS numeric
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $f$
  SELECT round(coalesce(
           nullif((SELECT sum(t.vl_parcela) FROM public.transacoes t
                    WHERE t.tipo = 'receita' AND t.status_pago <> 2 AND t.cod_venda = ANY (p_vendas)), 0),
           (SELECT sum(t.vl_parcela) FROM public.negociacoes n JOIN public.transacoes t ON t.negociacao_id = n.id
             WHERE n.tipo = 'receita' AND n.cod_venda = ANY (p_vendas) AND t.status_pago <> 2),
           0), 2)
$f$;
REVOKE ALL ON FUNCTION public._valor_venda_connect(integer[]) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._valor_venda_connect(integer[]) TO service_role;

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
  SELECT gen_random_uuid() AS item_id, o.orc_id, o.projeto_id, e.produto_id, e.ambiente,
         round(sum(e.quantidade) FILTER (WHERE e.tipo = 'reserva'), 2)        AS q_res,
         round(sum(e.quantidade) FILTER (WHERE e.tipo = 'entrega_futura'), 2) AS q_ef,
         (array_agg(e.descricao))[1]                                          AS descricao
    FROM _cra_elegiveis e JOIN _cra_orc o USING (cod_orcamento_connect)
   GROUP BY o.orc_id, o.projeto_id, e.produto_id, e.ambiente;

  INSERT INTO public.projeto_itens (id, projeto_id, produto_id, descricao, quantidade, preco_unitario, desconto, validado, orcamento_id, l_fixo)
  SELECT i.item_id, i.projeto_id, i.produto_id, coalesce(nullif(btrim(i.descricao), ''), 'Item sem descrição'),
         coalesce(i.q_res, 0) + coalesce(i.q_ef, 0), 0, 0, true, i.orc_id, nullif(btrim(coalesce(i.ambiente, '')), '')
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

REVOKE ALL ON FUNCTION public.carregar_connect_reserva_ambiente(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.carregar_connect_reserva_ambiente(uuid) TO service_role;


DO $$
DECLARE l uuid; r jsonb; a record;
BEGIN
  SELECT DISTINCT connect_lote INTO l FROM public.orcamentos WHERE origem = 'connect';
  RAISE NOTICE 'lote atual: %', l;
  RAISE NOTICE 'remover: %', public.remover_connect_lote(l);
  RAISE NOTICE 'carregar: %', public.carregar_connect_reserva_ambiente(l);
  RAISE NOTICE 'orcamentos com valor > 0: % de %  | soma R$ %', (SELECT count(*) FROM public.orcamentos WHERE origem='connect' AND valor_total > 0),
        (SELECT count(*) FROM public.orcamentos WHERE origem='connect'), (SELECT sum(valor_total) FROM public.orcamentos WHERE origem='connect');
  FOR a IN SELECT o.numero, o.numero_venda, o.valor_total FROM public.orcamentos o
            WHERE o.origem='connect' AND o.vendas_vinculadas_connect && ARRAY[1405,1264,1351,1505,1641,1604,1812] ORDER BY o.numero_venda LOOP
    RAISE NOTICE '%  %  R$ %', a.numero, a.numero_venda, a.valor_total;
  END LOOP;
  RAISE NOTICE 'projeto_itens com preco > 0 (esperado 0): %', (SELECT count(*) FROM public.projeto_itens pi JOIN public.orcamentos o ON o.id=pi.orcamento_id WHERE o.origem='connect' AND pi.preco_unitario > 0);
  RAISE NOTICE 'projetos com valor_total preservado (28): %', (SELECT count(*) FROM public.projetos WHERE valor_total IS NOT NULL AND valor_total <> 0);
END $$;
ROLLBACK;
