-- Dry-run da 279: aplica o rascunho, separa 1 peça da herança como projetista, confere saldo/estoque/setores e as recusas, e DESFAZ. Termina em ROLLBACK.
BEGIN;
-- SPEC-244 (05/11, decisão final do usuário): OPERAÇÃO EM PARALELO com a Connect. O que foi importado até aqui é histórico; a partir de agora a herança da
-- Connect "sem data de entrega" é liberada para as equipes pedirem a separação no sistema novo (mesmo fluxo e mesmas funções da venda do sistema; a regra de
-- estoque é a da SPEC-232: separar tira da Reserva, a baixa do Estoque Geral e a liberação do reservado acontecem ao FINALIZAR a entrega).
--  * connect_operacao_paralela: marco único ("a partir de agora"). Com ele gravado, as planilhas de Reserva/Entrega Futura NÃO podem mais ser recarregadas
--    (remover_connect_lote e carregar_connect_reserva_ambiente recusam) e o script de estoque da Connect também recusa (guarda no importador).
--  * connect_item_liberado(): item de orçamento Connect liberado para separar = Reserva "sem data de entrega" na Connect (aviso_data) OU já recebeu da NF
--    (entrega futura -> reserva). Quem tem data definida na Connect segue na Connect. connect_itens_liberados(): versão em lote para a tela.
--  * registrar_separacao_setor: recusa item da Connect que não esteja liberado (a regra vale também fora da tela).
--  * vw_cadastro_produto_setores: o setor Separação passa a somar a herança da Connect (Reserva e Entrega Futura continuam separadas por origem).

CREATE TABLE IF NOT EXISTS public.connect_operacao_paralela (
  id          integer PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  iniciada_em timestamptz NOT NULL DEFAULT now(),
  observacao  text
);
ALTER TABLE public.connect_operacao_paralela ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.connect_operacao_paralela FROM anon, authenticated;
GRANT SELECT ON public.connect_operacao_paralela TO authenticated;
GRANT ALL ON public.connect_operacao_paralela TO service_role;
DROP POLICY IF EXISTS connect_operacao_paralela_select ON public.connect_operacao_paralela;
CREATE POLICY connect_operacao_paralela_select ON public.connect_operacao_paralela FOR SELECT TO authenticated USING (true);
INSERT INTO public.connect_operacao_paralela (id, observacao)
VALUES (1, 'Decisão final de 05/11/2026: a partir daqui a Connect e o sistema novo operam em paralelo; o importado até aqui é histórico.')
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.connect_item_liberado(p_projeto_item_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.projeto_itens pi JOIN public.orcamentos o ON o.id = pi.orcamento_id AND o.origem = 'connect'
     WHERE pi.id = p_projeto_item_id
       AND (EXISTS (SELECT 1 FROM public.connect_reserva_ambiente r
                     WHERE r.projeto_item_id = pi.id AND r.tipo = 'reserva' AND r.aviso_data)
            OR EXISTS (SELECT 1 FROM public.estoque_movimentos_projeto_item m
                        WHERE m.projeto_item_id = pi.id AND m.tipo = 'recebimento_para_reserva')));
$function$;

CREATE OR REPLACE FUNCTION public.connect_itens_liberados(p_projeto_item_ids uuid[])
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT x FROM unnest(p_projeto_item_ids) AS x WHERE public.connect_item_liberado(x);
$function$;

REVOKE ALL ON FUNCTION public.connect_item_liberado(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.connect_itens_liberados(uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.connect_item_liberado(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.connect_itens_liberados(uuid[]) TO authenticated;

CREATE OR REPLACE FUNCTION public.remover_connect_lote(p_lote uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_orc integer; v_itens integer;
BEGIN
  -- SPEC-244: a partir do início da operação em paralelo a herança da Connect é operada no sistema novo; recarregar as planilhas apagaria saldos em uso.
  IF EXISTS (SELECT 1 FROM public.connect_operacao_paralela) THEN
    RAISE EXCEPTION 'Operação em paralelo com a Connect já começou (%): a herança não pode mais ser recarregada das planilhas.',
      (SELECT to_char(iniciada_em AT TIME ZONE 'America/Sao_Paulo', 'DD/MM/YYYY HH24:MI') FROM public.connect_operacao_paralela LIMIT 1) USING ERRCODE = 'P0001';
  END IF;
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
$function$;

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
  -- SPEC-244: a partir do início da operação em paralelo a herança da Connect é operada no sistema novo; recarregar as planilhas apagaria saldos em uso.
  IF EXISTS (SELECT 1 FROM public.connect_operacao_paralela) THEN
    RAISE EXCEPTION 'Operação em paralelo com a Connect já começou (%): a herança não pode mais ser recarregada das planilhas.',
      (SELECT to_char(iniciada_em AT TIME ZONE 'America/Sao_Paulo', 'DD/MM/YYYY HH24:MI') FROM public.connect_operacao_paralela LIMIT 1) USING ERRCODE = 'P0001';
  END IF;
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

CREATE OR REPLACE FUNCTION public.registrar_separacao_setor(p_projeto_item_id uuid, p_quantidade numeric, p_separacao_id uuid DEFAULT NULL::uuid, p_motivo text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

DECLARE

    v_saldo    public.estoque_saldos_projeto_item%ROWTYPE;

BEGIN

    IF p_quantidade IS NULL OR p_quantidade <= 0 THEN

        RAISE EXCEPTION 'Quantidade deve ser maior que zero.' USING ERRCODE = 'P0001';

    END IF;



    SELECT * INTO v_saldo

    FROM public.estoque_saldos_projeto_item

    WHERE projeto_item_id = p_projeto_item_id

    FOR UPDATE;



    IF NOT FOUND THEN

        RAISE EXCEPTION 'Item de projeto % nao possui saldo operacional (estoque_saldos_projeto_item).', p_projeto_item_id USING ERRCODE = 'P0001';

    END IF;



    -- SPEC-244: item da Connect só é separado no sistema novo quando está "sem data de entrega" na Connect (ou já recebeu da NF); os demais seguem na Connect.
    IF EXISTS (SELECT 1 FROM public.projeto_itens pi JOIN public.orcamentos o ON o.id = pi.orcamento_id
                WHERE pi.id = p_projeto_item_id AND o.origem = 'connect')
       AND NOT public.connect_item_liberado(p_projeto_item_id) THEN
        RAISE EXCEPTION 'Esta peça da Connect tem data de entrega definida na Connect: ainda não está liberada para separar no sistema novo.' USING ERRCODE = 'P0001';
    END IF;

    IF p_quantidade > v_saldo.q_reserva THEN

        RAISE EXCEPTION 'Quantidade de separacao (%) excede o saldo em reserva (%). Separacao so pode sair da reserva.',

            p_quantidade, v_saldo.q_reserva USING ERRCODE = 'P0001';

    END IF;



    UPDATE public.estoque_saldos_projeto_item

    SET q_reserva = q_reserva - p_quantidade,

        q_ag_separar = q_ag_separar + p_quantidade,

        atualizado_em = now()

    WHERE projeto_item_id = p_projeto_item_id;



    INSERT INTO public.estoque_movimentos_projeto_item

        (projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por)

    VALUES

        (p_projeto_item_id, 'solicitacao_separacao', p_quantidade, 'separacao_parcial', p_separacao_id, p_motivo, auth.uid());



    RETURN jsonb_build_object(

        'projeto_item_id', p_projeto_item_id,

        'quantidade', p_quantidade,

        'q_reserva_restante', v_saldo.q_reserva - p_quantidade,

        'q_ag_separar_novo', v_saldo.q_ag_separar + p_quantidade

    );

END;

$function$;

-- Setor Separação do Cadastro passa a somar também a herança da Connect (agora ela é operada aqui)
CREATE OR REPLACE VIEW public.vw_cadastro_produto_setores AS
SELECT produto_id,
    COALESCE(sum(q_reserva) FILTER (WHERE origem <> 'connect'::text), 0::numeric) AS q_reserva,
    COALESCE(sum(q_ag_separar), 0::numeric) + COALESCE(sum(q_separado), 0::numeric) AS q_separacao,
    COALESCE(sum(q_entrega_futura) FILTER (WHERE origem <> 'connect'::text), 0::numeric) AS q_entrega_futura,
    COALESCE(sum(q_reserva) FILTER (WHERE origem = 'connect'::text), 0::numeric) AS q_reserva_connect,
    COALESCE(sum(q_entrega_futura) FILTER (WHERE origem = 'connect'::text), 0::numeric) AS q_entrega_futura_connect
   FROM vw_estoque_por_produto_projeto v
  GROUP BY produto_id;


CREATE TEMP TABLE _ctx (k text PRIMARY KEY, v text);
GRANT SELECT ON _ctx TO authenticated;
INSERT INTO _ctx SELECT 'A', s.projeto_item_id::text FROM public.estoque_saldos_projeto_item s
  WHERE s.q_reserva >= 2 AND EXISTS (SELECT 1 FROM public.connect_reserva_ambiente r WHERE r.projeto_item_id = s.projeto_item_id AND r.tipo='reserva' AND r.aviso_data)
  ORDER BY s.projeto_item_id LIMIT 1;
INSERT INTO _ctx SELECT 'B', s.projeto_item_id::text FROM public.estoque_saldos_projeto_item s
  WHERE s.q_reserva >= 1 AND EXISTS (SELECT 1 FROM public.connect_reserva_ambiente r WHERE r.projeto_item_id = s.projeto_item_id AND r.tipo='reserva' AND NOT r.aviso_data)
    AND NOT EXISTS (SELECT 1 FROM public.connect_reserva_ambiente r WHERE r.projeto_item_id = s.projeto_item_id AND r.tipo='reserva' AND r.aviso_data)
    AND NOT EXISTS (SELECT 1 FROM public.estoque_movimentos_projeto_item m WHERE m.projeto_item_id = s.projeto_item_id AND m.tipo='recebimento_para_reserva')
  ORDER BY s.projeto_item_id LIMIT 1;
CREATE FUNCTION pg_temp.foto(p uuid) RETURNS text LANGUAGE sql SECURITY DEFINER AS $f$
  SELECT 'geral ' || coalesce((SELECT quantidade::text FROM public.estoque_itens ei WHERE ei.produto_id = pi.produto_id AND ei.local='Estoque'), '-')
      || ' | reservado ' || coalesce((SELECT quantidade_reservada::text FROM public.estoque_itens ei WHERE ei.produto_id = pi.produto_id AND ei.local='Estoque'), '-')
      || ' | saldo res ' || s.q_reserva || ' ag ' || s.q_ag_separar || ' sep ' || s.q_separado || ' ent ' || s.q_entregue
  FROM public.projeto_itens pi JOIN public.estoque_saldos_projeto_item s ON s.projeto_item_id = pi.id WHERE pi.id = p
$f$;
GRANT EXECUTE ON FUNCTION pg_temp.foto(uuid) TO authenticated;
CREATE FUNCTION pg_temp.setor(p uuid) RETURNS text LANGUAGE sql SECURITY DEFINER AS $f$
  SELECT 'q_separacao ' || v.q_separacao || ' | reserva_sistema ' || v.q_reserva || ' | reserva_connect ' || v.q_reserva_connect
  FROM public.vw_cadastro_produto_setores v WHERE v.produto_id = (SELECT produto_id FROM public.projeto_itens WHERE id = p)
$f$;
GRANT EXECUTE ON FUNCTION pg_temp.setor(uuid) TO authenticated;

DO $$ BEGIN
  RAISE NOTICE 'ctx: %', (SELECT string_agg(k, ',') FROM _ctx);
  RAISE NOTICE 'liberados (A deve entrar, B não): A=% B=%',
    (SELECT count(*) FROM public.connect_itens_liberados(ARRAY[(SELECT v::uuid FROM _ctx WHERE k='A')])),
    (SELECT count(*) FROM public.connect_itens_liberados(ARRAY[(SELECT v::uuid FROM _ctx WHERE k='B')]));
  RAISE NOTICE 'itens Connect liberados no total: %', (SELECT count(*) FROM public.connect_itens_liberados(ARRAY(SELECT pi.id FROM public.projeto_itens pi JOIN public.orcamentos o ON o.id = pi.orcamento_id WHERE o.origem='connect')));
END $$;

-- usuário comum (Marina, projetista) pede a separação
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"role":"authenticated","sub":"438d37e0-ae72-4226-83c7-15d501a49dd4"}', true);
DO $$
DECLARE a uuid := (SELECT v::uuid FROM _ctx WHERE k='A'); b uuid := (SELECT v::uuid FROM _ctx WHERE k='B'); r jsonb;
BEGIN
  RAISE NOTICE 'A antes : %', pg_temp.foto(a);
  r := public.registrar_separacao_setor(a, 1, NULL, 'ensaio SPEC-244');
  RAISE NOTICE 'A depois: % -> %', pg_temp.foto(a), r;
  RAISE NOTICE 'Setores do Cadastro depois: %', pg_temp.setor(a);
  IF b IS NOT NULL THEN
    BEGIN PERFORM public.registrar_separacao_setor(b, 1, NULL, 'ensaio'); RAISE NOTICE 'FALHOU: separou item com data na Connect';
    EXCEPTION WHEN SQLSTATE 'P0001' THEN RAISE NOTICE 'OK: item com data na Connect recusado: %', SQLERRM; END;
  ELSE RAISE NOTICE 'sem item B para testar'; END IF;
END $$;
RESET ROLE;
DO $$ BEGIN
  BEGIN PERFORM public.remover_connect_lote((SELECT connect_lote FROM public.orcamentos WHERE origem='connect' LIMIT 1)); RAISE NOTICE 'FALHOU: recarregou a herança';
  EXCEPTION WHEN SQLSTATE 'P0001' THEN RAISE NOTICE 'OK: recarga recusada: %', left(SQLERRM, 100); END;
END $$;
DO $$ BEGIN
  RAISE NOTICE 'estoque total: %', (SELECT sum(quantidade)::text || '/' || sum(quantidade_reservada)::text FROM public.estoque_itens);
  RAISE NOTICE 'marco da operação em paralelo: %', (SELECT iniciada_em::date FROM public.connect_operacao_paralela);
END $$;
ROLLBACK;
