-- Dry-run da 286: aplica, simula aprovação/baixa/reabertura/cancelamento/desfazer com a venda real de R$ 35.000,00 e DESFAZ. Termina em ROLLBACK.
BEGIN;

ALTER TABLE public.negociacoes ADD COLUMN IF NOT EXISTS orcamento_id uuid REFERENCES public.orcamentos (id) ON DELETE SET NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_negociacoes_orcamento ON public.negociacoes (orcamento_id) WHERE orcamento_id IS NOT NULL;
CREATE SEQUENCE IF NOT EXISTS public.seq_cod_duplicata_nativa START WITH 900000 MINVALUE 900000;

CREATE OR REPLACE FUNCTION public.criar_transacao_da_parcela_projeto(p_parcela_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $f$
DECLARE
  pp record; v_o record; v_neg uuid; v_tx uuid; v_plano uuid; v_total integer; v_nome text; v_razao text;
BEGIN
  SELECT * INTO pp FROM public.projeto_parcelas WHERE id = p_parcela_id;
  IF NOT FOUND OR pp.orcamento_id IS NULL THEN RETURN NULL; END IF;
  IF pp.transacao_id IS NOT NULL THEN RETURN pp.transacao_id; END IF;
  IF pp.status::text = 'cancelada' OR lower(coalesce(pp.forma_pagamento::text, '')) = 'permuta' THEN RETURN NULL; END IF;
  SELECT o.id, o.empresa_id, o.cliente_id, o.projeto_id, o.perfil, o.numero, o.numero_venda, o.natureza_operacao INTO v_o FROM public.orcamentos o WHERE o.id = pp.orcamento_id;
  IF NOT FOUND OR v_o.empresa_id IS NULL OR coalesce(v_o.natureza_operacao, '') = 'devolucao' THEN RETURN NULL; END IF;

  SELECT id INTO v_neg FROM public.negociacoes WHERE orcamento_id = v_o.id;
  IF v_neg IS NULL THEN
    SELECT id INTO v_plano FROM public.plano_de_contas WHERE codigo_connect = 1010002 LIMIT 1; -- VENDAS A PRAZO
    SELECT nome, razao_social INTO v_nome, v_razao FROM public.contatos WHERE id = v_o.cliente_id;
    INSERT INTO public.negociacoes (empresa_id, contato_id, plano_contas_id, projeto_id, tipo, cod_duplicata, total_parc, observacao, nome_pessoa, razao_pessoa, orcamento_id)
    VALUES (v_o.empresa_id, v_o.cliente_id, v_plano, coalesce(v_o.projeto_id, pp.projeto_id), 'receita', nextval('public.seq_cod_duplicata_nativa'), 1,
            'Venda ' || coalesce(v_o.numero_venda, v_o.numero) || ' (orçamento ' || coalesce(v_o.numero, '') || ')', v_nome, coalesce(v_razao, v_nome), v_o.id)
    RETURNING id INTO v_neg;
  END IF;

  INSERT INTO public.transacoes (negociacao_id, parcela_id, tipo, descricao, valor, data_transacao, num_parc, dt_emissao, dt_vencimento, vl_parcela, vl_pago, status_pago, tipo_pagamento, perfil, projeto_id)
  VALUES (v_neg, pp.id, 'receita', 'Venda ' || coalesce(v_o.numero_venda, v_o.numero) || ' — parcela ' || pp.numero_parcela, pp.valor, current_date, pp.numero_parcela,
          current_date, pp.data_vencimento, pp.valor, CASE WHEN pp.status::text = 'paga' THEN coalesce(pp.valor_pago, pp.valor) ELSE 0 END,
          CASE WHEN pp.status::text = 'paga' THEN 1 ELSE 0 END, pp.forma_pagamento::text, v_o.perfil, coalesce(v_o.projeto_id, pp.projeto_id))
  RETURNING id INTO v_tx;
  UPDATE public.projeto_parcelas SET transacao_id = v_tx WHERE id = pp.id;

  SELECT count(*) INTO v_total FROM public.projeto_parcelas WHERE orcamento_id = v_o.id AND status::text <> 'cancelada' AND lower(coalesce(forma_pagamento::text, '')) <> 'permuta';
  UPDATE public.negociacoes SET total_parc = greatest(v_total, 1) WHERE id = v_neg;
  RETURN v_tx;
END $f$;

CREATE OR REPLACE FUNCTION public.trg_projeto_parcela_financeiro()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $f$
DECLARE v_pago boolean;
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM public.criar_transacao_da_parcela_projeto(NEW.id);
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.transacao_id IS NOT NULL AND (
         OLD.status IS DISTINCT FROM NEW.status OR OLD.valor_pago IS DISTINCT FROM NEW.valor_pago OR OLD.data_pagamento IS DISTINCT FROM NEW.data_pagamento
         OR OLD.valor IS DISTINCT FROM NEW.valor OR OLD.data_vencimento IS DISTINCT FROM NEW.data_vencimento OR OLD.juros IS DISTINCT FROM NEW.juros
         OR OLD.multa IS DISTINCT FROM NEW.multa OR OLD.desconto IS DISTINCT FROM NEW.desconto OR OLD.forma_pagamento IS DISTINCT FROM NEW.forma_pagamento) THEN
      v_pago := NEW.status::text = 'paga';
      UPDATE public.transacoes SET
        status_pago   = CASE NEW.status::text WHEN 'paga' THEN 1 WHEN 'cancelada' THEN 2 ELSE 0 END,
        vl_pago       = CASE WHEN v_pago THEN coalesce(NEW.valor_pago, NEW.valor) ELSE 0 END,
        dt_pagamento  = CASE WHEN v_pago THEN coalesce(NEW.data_pagamento, current_date) ELSE NULL END,
        vl_parcela    = NEW.valor, valor = NEW.valor, dt_vencimento = NEW.data_vencimento,
        vl_juros      = coalesce(NEW.juros, 0) + coalesce(NEW.multa, 0), vl_desconto = coalesce(NEW.desconto, 0),
        tipo_pagamento = NEW.forma_pagamento::text
      WHERE id = NEW.transacao_id;
    END IF;
    RETURN NEW;
  ELSE -- DELETE (desfazer aprovação): transação em aberto é cancelada e solta da parcela; a paga fica preservada
    UPDATE public.transacoes SET status_pago = CASE WHEN status_pago = 1 THEN 1 ELSE 2 END, parcela_id = NULL WHERE parcela_id = OLD.id;
    RETURN OLD;
  END IF;
END $f$;

DROP TRIGGER IF EXISTS trg_projeto_parcela_financeiro_aiu ON public.projeto_parcelas;
CREATE TRIGGER trg_projeto_parcela_financeiro_aiu AFTER INSERT OR UPDATE ON public.projeto_parcelas FOR EACH ROW EXECUTE FUNCTION public.trg_projeto_parcela_financeiro();
DROP TRIGGER IF EXISTS trg_projeto_parcela_financeiro_bd ON public.projeto_parcelas;
CREATE TRIGGER trg_projeto_parcela_financeiro_bd BEFORE DELETE ON public.projeto_parcelas FOR EACH ROW EXECUTE FUNCTION public.trg_projeto_parcela_financeiro();

-- funções existentes com o trecho trocado
CREATE OR REPLACE FUNCTION public.processar_retorno_bancario(p_nome_arquivo text, p_hash text, p_conta text, p_registros jsonb, p_forcar boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_arquivo_id      uuid;
  v_reg             jsonb;
  v_boleto          public.boletos%ROWTYPE;
  v_transacao_id    uuid;
  v_nn              text;
  v_oc              text;
  v_recebido        numeric;
  v_data            date;
  v_aplicados       integer := 0;
  v_divergentes     integer := 0;
  v_nao_encontrados integer := 0;
BEGIN
  IF p_registros IS NULL OR jsonb_typeof(p_registros) <> 'array' THEN
    RAISE EXCEPTION 'p_registros deve ser um array JSON.' USING ERRCODE = 'P0001';
  END IF;

  IF NOT p_forcar AND EXISTS (SELECT 1 FROM public.retorno_bancario_arquivos WHERE hash_conteudo = p_hash) THEN
    RAISE EXCEPTION 'Arquivo % já foi processado anteriormente (hash %). Use a opção de forçar reprocessamento se isso for intencional.', p_nome_arquivo, p_hash
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.retorno_bancario_arquivos (nome_arquivo, hash_conteudo, conta, processado_por, forcado, total_registros)
  VALUES (p_nome_arquivo, p_hash, p_conta, auth.uid(), p_forcar, jsonb_array_length(p_registros))
  RETURNING id INTO v_arquivo_id;

  FOR v_reg IN SELECT * FROM jsonb_array_elements(p_registros)
  LOOP
    v_nn       := nullif(btrim(v_reg->>'nosso_numero'), '');
    v_oc       := coalesce(v_reg->>'ocorrencia_codigo', '');
    v_recebido := coalesce((v_reg->>'valor_recebido')::numeric, 0);
    v_data     := (v_reg->>'data_pagamento')::date;

    SELECT * INTO v_boleto
      FROM public.boletos
     WHERE nosso_numero_banco = v_nn OR nosso_numero = v_nn
     ORDER BY (nosso_numero_banco = v_nn) DESC NULLS LAST
     LIMIT 1;

    IF NOT FOUND THEN
      INSERT INTO public.retorno_bancario_registros
        (arquivo_id, nosso_numero, valor_recebido, data_pagamento, ocorrencia_codigo, status_aplicacao, motivo_divergencia)
      VALUES (v_arquivo_id, v_nn, v_recebido, v_data, v_oc, 'nao_encontrado', nullif(v_reg->>'motivo', ''));
      v_nao_encontrados := v_nao_encontrados + 1;
      CONTINUE;
    END IF;

    -- Não é liquidação (06/15/17): registra e só ajusta status quando faz sentido.
    IF v_oc NOT IN ('06', '15', '17') THEN
      IF v_oc = '02' AND v_boleto.status NOT IN ('Pago', 'cancelado', 'Cancelado') THEN
        UPDATE public.boletos SET status = 'Registrado' WHERE id = v_boleto.id;
      END IF;
      INSERT INTO public.retorno_bancario_registros
        (arquivo_id, nosso_numero, boleto_id, parcela_id, valor_esperado, valor_recebido, data_pagamento,
         ocorrencia_codigo, status_aplicacao, motivo_divergencia)
      VALUES (v_arquivo_id, v_nn, v_boleto.id, v_boleto.parcela_id, v_boleto.valor, v_recebido, v_data, v_oc,
              CASE WHEN v_oc = '03' THEN 'divergente' ELSE 'ja_processado' END,
              CASE v_oc
                WHEN '02' THEN 'Entrada confirmada pelo banco (registro).'
                WHEN '03' THEN 'Entrada rejeitada pelo banco. Motivos: ' || coalesce(nullif(v_reg->>'motivo', ''), '-')
                WHEN '09' THEN 'Baixado pelo banco.'
                ELSE 'Ocorrência ' || v_oc || ' registrada sem alterar o boleto.'
              END);
      IF v_oc = '03' THEN v_divergentes := v_divergentes + 1; END IF;
      CONTINUE;
    END IF;

    IF v_boleto.status = 'Pago' THEN
      INSERT INTO public.retorno_bancario_registros
        (arquivo_id, nosso_numero, boleto_id, parcela_id, valor_esperado, valor_recebido, data_pagamento,
         ocorrencia_codigo, status_aplicacao, motivo_divergencia)
      VALUES (v_arquivo_id, v_nn, v_boleto.id, v_boleto.parcela_id, v_boleto.valor, v_recebido, v_data, v_oc,
              'ja_processado', 'Boleto já estava pago; nada alterado.');
      CONTINUE;
    END IF;

    IF v_recebido < coalesce(v_boleto.valor, 0) THEN
      INSERT INTO public.retorno_bancario_registros
        (arquivo_id, nosso_numero, boleto_id, parcela_id, valor_esperado, valor_recebido, data_pagamento,
         ocorrencia_codigo, status_aplicacao, motivo_divergencia)
      VALUES (v_arquivo_id, v_nn, v_boleto.id, v_boleto.parcela_id, v_boleto.valor, v_recebido, v_data, v_oc,
              'divergente', 'Valor recebido menor que o valor do boleto.');
      v_divergentes := v_divergentes + 1;
      CONTINUE;
    END IF;

    UPDATE public.boletos
       SET status = 'Pago',
           valor_pago = v_recebido,
           juros_multa = v_recebido - coalesce(v_boleto.valor, 0),
           data_pagamento = v_data,
           forma_pagamento = coalesce(forma_pagamento, 'Boleto')
     WHERE id = v_boleto.id;

    IF v_boleto.parcela_id IS NOT NULL THEN
      UPDATE public.projeto_parcelas
         SET status = 'paga'::public.parcela_status, valor_pago = v_recebido, data_pagamento = v_data
       WHERE id = v_boleto.parcela_id;
    END IF;

    -- SPEC-246: a parcela de projeto já nasce com a sua transação em aberto (previsão) na aprovação do orçamento; o gatilho de projeto_parcelas
    -- marcou a transação como paga acima. Só cria uma nova para parcelas antigas, que nunca tiveram transação.
    SELECT transacao_id INTO v_transacao_id FROM public.projeto_parcelas WHERE id = v_boleto.parcela_id;
    IF v_transacao_id IS NULL THEN
      INSERT INTO public.transacoes (parcela_id, tipo, descricao, valor, data_transacao, vl_pago, dt_pagamento, status_pago, created_by)
      VALUES (v_boleto.parcela_id, 'receita'::public.transacao_tipo,
              'Recebimento boleto ' || coalesce(v_boleto.nosso_numero_banco, v_boleto.nosso_numero),
              v_boleto.valor, v_data, v_recebido, v_data, 1, auth.uid())
      RETURNING id INTO v_transacao_id;
    END IF;

    IF v_boleto.parcela_id IS NOT NULL THEN
      UPDATE public.projeto_parcelas SET transacao_id = v_transacao_id WHERE id = v_boleto.parcela_id;
    END IF;

    INSERT INTO public.retorno_bancario_registros
      (arquivo_id, nosso_numero, boleto_id, parcela_id, transacao_id, valor_esperado, valor_recebido, data_pagamento,
       ocorrencia_codigo, status_aplicacao, motivo_divergencia)
    VALUES (v_arquivo_id, v_nn, v_boleto.id, v_boleto.parcela_id, v_transacao_id, v_boleto.valor, v_recebido, v_data, v_oc,
            'aplicado',
            CASE WHEN v_recebido > coalesce(v_boleto.valor, 0)
                 THEN 'Pago com juros/multa de ' || (v_recebido - coalesce(v_boleto.valor, 0))::text END);
    v_aplicados := v_aplicados + 1;
  END LOOP;

  UPDATE public.retorno_bancario_arquivos
     SET total_aplicados = v_aplicados, total_divergentes = v_divergentes, total_nao_encontrados = v_nao_encontrados
   WHERE id = v_arquivo_id;

  RETURN jsonb_build_object('arquivo_id', v_arquivo_id, 'aplicados', v_aplicados,
                            'divergentes', v_divergentes, 'nao_encontrados', v_nao_encontrados);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.desfazer_aprovacao_financeira(p_orcamento_id uuid, p_motivo text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_orcamento public.orcamentos%ROWTYPE;
  v_status_anterior text;
  v_numero text;
  v_user_role text;
  v_item record;
  v_itens_apagados integer := 0;
  v_parcelas_apagadas integer := 0;
  v_boletos_apagados integer := 0;
BEGIN
  IF p_motivo IS NULL OR btrim(p_motivo) = '' THEN
    RAISE EXCEPTION 'Informe o motivo antes de desfazer a aprovação financeira.' USING ERRCODE = 'P0001';
  END IF;

  SELECT u.role INTO v_user_role FROM public.usuarios u WHERE u.id = auth.uid();

  IF NOT (
    COALESCE(auth.role(), '') = 'service_role'
    OR v_user_role IN ('admin', 'gerente')
  ) THEN
    RAISE EXCEPTION 'Apenas admin ou gerente podem desfazer uma aprovação financeira.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_orcamento FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento não encontrado.' USING ERRCODE = 'P0001';
  END IF;

  -- SPEC-195: vínculo Connect não tem reserva para estornar — usar desvincular_orcamento_connect.
  IF v_orcamento.vinculo_connect THEN
    RAISE EXCEPTION 'Orçamento % é vínculo de venda da Connect — use "Desfazer vínculo".', coalesce(v_orcamento.numero, p_orcamento_id::text)
      USING ERRCODE = 'P0001';
  END IF;

  v_status_anterior := v_orcamento.status;
  v_numero := COALESCE(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.status <> 'Orçamento Aprovado' THEN
    RAISE EXCEPTION 'Orçamento % não está em Orçamento Aprovado. Status atual: %', v_numero, v_status_anterior
      USING ERRCODE = 'P0002';
  END IF;

  IF v_orcamento.natureza_operacao = 'devolucao' THEN
    RAISE EXCEPTION 'Orçamento % é de devolução — desfazer aprovação financeira de devolução não é suportado.', v_numero
      USING ERRCODE = 'P0001';
  END IF;

  -- SPEC-234 A: uso e consumo / descarte já baixaram o Estoque Geral (não há item de projeto para desfazer).
  IF public.tipo_operacao_regra(v_orcamento.natureza_operacao, v_orcamento.subgrupo) = 'baixa_direta' THEN
    RAISE EXCEPTION 'Orçamento % (%) já baixou o Estoque Geral — para voltar a peça, faça a entrada pela Movimentação de Peças.', v_numero, v_orcamento.subgrupo
      USING ERRCODE = 'P0001';
  END IF;

  -- Bloqueios: algo já consumiu o que essa aprovação criou.
  IF EXISTS (
    SELECT 1 FROM public.boletos b WHERE b.orcamento_id = p_orcamento_id AND b.status <> 'pendente_registro'
  ) THEN
    RAISE EXCEPTION 'Orçamento % tem boleto com status diferente de "pendente_registro" — não pode desfazer (já foi remessado/pago).', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.notas_fiscais nf
    JOIN public.boletos b ON b.id = nf.boleto_id
    WHERE b.orcamento_id = p_orcamento_id
  ) THEN
    RAISE EXCEPTION 'Orçamento % já tem nota fiscal emitida sobre um dos boletos — não pode desfazer.', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.retorno_bancario_registros rbr
    WHERE rbr.boleto_id IN (SELECT id FROM public.boletos WHERE orcamento_id = p_orcamento_id)
       OR rbr.parcela_id IN (SELECT id FROM public.projeto_parcelas WHERE orcamento_id = p_orcamento_id)
  ) THEN
    RAISE EXCEPTION 'Orçamento % já tem retorno bancário registrado — não pode desfazer.', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.projeto_parcelas pp WHERE pp.orcamento_id = p_orcamento_id AND pp.status <> 'pendente'
  ) THEN
    RAISE EXCEPTION 'Orçamento % tem parcela com status diferente de "pendente" — não pode desfazer.', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.transacoes t
    WHERE t.parcela_id IN (SELECT id FROM public.projeto_parcelas WHERE orcamento_id = p_orcamento_id)
      AND t.status_pago <> 0 -- SPEC-246: a transação em aberto da aprovação é cancelada pelo gatilho ao apagar a parcela
  ) THEN
    RAISE EXCEPTION 'Orçamento % já tem transação financeira lançada — não pode desfazer.', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.devolucoes_estoque de
    WHERE de.projeto_item_id IN (SELECT id FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id)
  ) THEN
    RAISE EXCEPTION 'Orçamento % já teve item devolvido ao estoque — não pode desfazer.', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.separacao_itens si
    WHERE si.projeto_item_id IN (SELECT id FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id)
  ) THEN
    RAISE EXCEPTION 'Orçamento % já teve item separado para entrega — não pode desfazer.', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.transferencias_estoque te
    WHERE te.origem_projeto_item_id IN (SELECT id FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id)
       OR te.destino_projeto_item_id IN (SELECT id FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id)
  ) THEN
    RAISE EXCEPTION 'Orçamento % já teve item usado em transferência de estoque — não pode desfazer.', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.pedido_compra_item_origem pio
    WHERE pio.projeto_item_id IN (SELECT id FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id)
  ) THEN
    RAISE EXCEPTION 'Orçamento % já teve item usado como origem de pedido de compra — não pode desfazer.', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.orcamento_itens oi
    WHERE oi.projeto_item_origem_id IN (SELECT id FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id)
  ) THEN
    RAISE EXCEPTION 'Orçamento % já teve item usado como origem de um orçamento de devolução — não pode desfazer.', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  -- Nenhum bloqueio: desfaz reserva de estoque item a item, depois apaga em cascata manual.
  FOR v_item IN
    SELECT id, produto_id, quantidade FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id
  LOOP
    IF v_item.produto_id IS NOT NULL AND COALESCE(v_item.quantidade, 0) > 0 THEN
      UPDATE public.estoque_itens
      SET quantidade_reservada = GREATEST(0, quantidade_reservada - v_item.quantidade),
          atualizado_em = NOW()
      WHERE produto_id = v_item.produto_id AND local = 'Estoque'::public.estoque_local;

      INSERT INTO public.estoque_movimentos_projeto_item (
        projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por
      ) VALUES (
        v_item.id, 'estorno_aprovacao_orcamento', v_item.quantidade, 'desfazer_aprovacao_financeira', p_orcamento_id,
        format('Estorno de reserva ao desfazer aprovação do orçamento %s: %s', v_numero, p_motivo),
        auth.uid()
      );
    END IF;
  END LOOP;

  DELETE FROM public.estoque_saldos_projeto_item
  WHERE projeto_item_id IN (SELECT id FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id);

  DELETE FROM public.boletos WHERE orcamento_id = p_orcamento_id;
  GET DIAGNOSTICS v_boletos_apagados = ROW_COUNT;

  DELETE FROM public.projeto_parcelas WHERE orcamento_id = p_orcamento_id;
  GET DIAGNOSTICS v_parcelas_apagadas = ROW_COUNT;

  DELETE FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id;
  GET DIAGNOSTICS v_itens_apagados = ROW_COUNT;

  UPDATE public.orcamentos
  SET status = 'Aprovação Financeira',
      requer_revisao_financeira = true
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (p_orcamento_id, v_status_anterior, 'Aprovação Financeira', auth.uid()::text, p_motivo);

  RETURN jsonb_build_object(
    'orcamento_id', p_orcamento_id,
    'numero', v_numero,
    'status', 'Aprovação Financeira',
    'projeto_itens_apagados', v_itens_apagados,
    'parcelas_apagadas', v_parcelas_apagadas,
    'boletos_apagados', v_boletos_apagados
  );
END;
$function$
;

CREATE OR REPLACE VIEW public.vw_financeiro_integridade WITH (security_invoker = true) AS
 SELECT 'negociacao_sem_pessoa'::text AS verificacao,
    'A duplicata não tem contato nem nome de pessoa'::text AS descricao,
    count(*) AS qtd,
    0::numeric AS valor
   FROM negociacoes
  WHERE negociacoes.contato_id IS NULL AND COALESCE(NULLIF(btrim(negociacoes.nome_pessoa), ''::text), NULLIF(btrim(negociacoes.razao_pessoa), ''::text)) IS NULL
UNION ALL
 SELECT 'negociacao_sem_contato_cadastrado'::text AS verificacao,
    'Duplicata só com o nome da planilha (sem cadastro de contato ligado)'::text AS descricao,
    count(*) AS qtd,
    0 AS valor
   FROM negociacoes
  WHERE negociacoes.contato_id IS NULL AND COALESCE(NULLIF(btrim(negociacoes.nome_pessoa), ''::text), NULLIF(btrim(negociacoes.razao_pessoa), ''::text)) IS NOT NULL
UNION ALL
 SELECT 'negociacao_sem_empresa'::text AS verificacao,
    'Duplicata sem empresa do grupo'::text AS descricao,
    count(*) AS qtd,
    0 AS valor
   FROM negociacoes
  WHERE negociacoes.empresa_id IS NULL
UNION ALL
 SELECT 'negociacao_sem_plano_de_contas'::text AS verificacao,
    'Duplicata sem conta do plano de contas'::text AS descricao,
    count(*) AS qtd,
    0 AS valor
   FROM negociacoes
  WHERE negociacoes.plano_contas_id IS NULL
UNION ALL
 SELECT 'parcela_sem_negociacao'::text AS verificacao,
    'Parcela ativa sem duplicata'::text AS descricao,
    count(*) AS qtd,
    COALESCE(sum(transacoes.vl_parcela), 0::numeric) AS valor
   FROM transacoes
  WHERE transacoes.negociacao_id IS NULL AND transacoes.status_pago <> 2
UNION ALL
 SELECT 'parcela_paga_sem_conta_bancaria'::text AS verificacao,
    'Parcela paga sem conta bancária'::text AS descricao,
    count(*) AS qtd,
    COALESCE(sum(transacoes.vl_pago), 0::numeric) AS valor
   FROM transacoes
  WHERE transacoes.status_pago = 1 AND transacoes.conta_id IS NULL
UNION ALL
 SELECT 'parcela_aberta_sem_conta_bancaria'::text AS verificacao,
    'Parcela em aberto sem conta bancária prevista'::text AS descricao,
    count(*) AS qtd,
    COALESCE(sum(transacoes.vl_parcela), 0::numeric) AS valor
   FROM transacoes
  WHERE transacoes.status_pago = 0 AND transacoes.conta_id IS NULL
UNION ALL
 SELECT 'receita_igual_a_despesa'::text AS verificacao,
    'Receita ativa idêntica a uma despesa ativa (contagem em dobro)'::text AS descricao,
    count(*) AS qtd,
    COALESCE(sum(t.vl_parcela), 0::numeric) AS valor
   FROM transacoes t
  WHERE t.tipo::text = 'receita'::text AND t.status_pago <> 2 AND (EXISTS ( SELECT 1
           FROM transacoes d
          WHERE d.tipo::text = 'despesa'::text AND d.status_pago <> 2 AND d.cod_itens_duplicata = t.cod_itens_duplicata AND d.vl_parcela = t.vl_parcela AND d.dt_vencimento = t.dt_vencimento))
UNION ALL
 SELECT 'plano_de_contas_de_outro_tipo'::text AS verificacao,
    'Duplicata cujo plano de contas é de tipo diferente (legado da Connect; alerta)'::text AS descricao,
    count(*) AS qtd,
    0 AS valor
   FROM negociacoes n
     JOIN plano_de_contas p ON p.id = n.plano_contas_id
  WHERE n.tipo::text = 'receita'::text AND p.tipo <> 'receita'::text OR n.tipo::text = 'despesa'::text AND p.tipo = 'receita'::text
UNION ALL
 SELECT 'parcela_vencimento_antes_da_emissao'::text AS verificacao,
    'Vencimento anterior à emissão (dado da Connect)'::text AS descricao,
    count(*) AS qtd,
    0 AS valor
   FROM transacoes
  WHERE transacoes.status_pago <> 2 AND transacoes.dt_vencimento < transacoes.dt_emissao
UNION ALL
 SELECT 'receita_sem_projeto'::text AS verificacao,
    'Duplicata de receber sem projeto ligado'::text AS descricao,
    count(*) AS qtd,
    0 AS valor
   FROM negociacoes
  WHERE negociacoes.tipo::text = 'receita'::text AND negociacoes.projeto_id IS NULL
UNION ALL
SELECT 'parcela_projeto_sem_transacao'::text, 'Parcela de projeto pendente (orçamento aprovado) sem transação no Contas a Receber'::text, count(*)::bigint, coalesce(sum(valor), 0)::numeric
  FROM public.projeto_parcelas WHERE orcamento_id IS NOT NULL AND transacao_id IS NULL AND status::text IN ('pendente', 'atrasada') AND lower(coalesce(forma_pagamento::text, '')) <> 'permuta'
UNION ALL
SELECT 'parcela_projeto_situacao_diferente_da_transacao', 'Situação da parcela de projeto diferente da situação da transação', count(*), 0
  FROM public.projeto_parcelas pp JOIN public.transacoes t ON t.id = pp.transacao_id
  WHERE (pp.status::text = 'paga') <> (t.status_pago = 1) OR (pp.status::text = 'cancelada') <> (t.status_pago = 2);

-- backfill: parcelas de orçamento já aprovadas e ainda não pagas ganham a transação em aberto
SELECT public.criar_transacao_da_parcela_projeto(id) FROM public.projeto_parcelas
 WHERE orcamento_id IS NOT NULL AND transacao_id IS NULL AND status::text IN ('pendente', 'atrasada') ORDER BY orcamento_id, numero_parcela;


DO $$
DECLARE o uuid; neg uuid; p1 uuid; p2 uuid; p3 uuid; p4 uuid; t1 uuid; r record; n bigint; pr uuid;
BEGIN
  SELECT orcamento_id INTO o FROM public.projeto_parcelas WHERE created_at::date = '2026-11-05' LIMIT 1;
  SELECT id INTO p1 FROM public.projeto_parcelas WHERE orcamento_id = o AND numero_parcela = 1;
  SELECT id INTO p2 FROM public.projeto_parcelas WHERE orcamento_id = o AND numero_parcela = 2;
  SELECT id INTO neg FROM public.negociacoes WHERE orcamento_id = o;
  RAISE NOTICE '1) backfill: duplicata % cod % total_parc % | transacoes em aberto: % somando %', neg, (SELECT cod_duplicata FROM public.negociacoes WHERE id = neg), (SELECT total_parc FROM public.negociacoes WHERE id = neg),
     (SELECT count(*) FROM public.transacoes WHERE negociacao_id = neg AND status_pago = 0), (SELECT sum(vl_parcela) FROM public.transacoes WHERE negociacao_id = neg AND status_pago = 0);
  RAISE NOTICE '   plano: %, contato ligado: %, projeto ligado: %', (SELECT p.nome FROM public.negociacoes n JOIN public.plano_de_contas p ON p.id = n.plano_contas_id WHERE n.id = neg), (SELECT contato_id IS NOT NULL FROM public.negociacoes WHERE id = neg), (SELECT projeto_id IS NOT NULL FROM public.negociacoes WHERE id = neg);

  -- 2) previsão no dashboard: lógica da view (sem filtro de permissão)
  SELECT count(*) INTO n FROM public.transacoes t JOIN public.negociacoes ng ON ng.id = t.negociacao_id
   WHERE ng.id = neg AND t.status_pago = 0 AND ng.created_at > (SELECT encerrado_em FROM public.connect_financeiro_encerrado LIMIT 1);
  RAISE NOTICE '2) entram no dashboard como PREVISAO (status 0, negociação criada após o marco): %', n;

  -- 3) baixa da parcela 1 (como faz o retorno do banco)
  UPDATE public.projeto_parcelas SET status = 'paga', valor_pago = 17500, data_pagamento = current_date WHERE id = p1;
  SELECT status_pago, vl_pago, dt_pagamento INTO r FROM public.transacoes WHERE parcela_id = p1;
  RAISE NOTICE '3) após baixa: status_pago % vl_pago % dt_pagamento %', r.status_pago, r.vl_pago, r.dt_pagamento;
  -- 4) reabre
  UPDATE public.projeto_parcelas SET status = 'pendente', valor_pago = NULL, data_pagamento = NULL WHERE id = p1;
  SELECT status_pago, vl_pago, dt_pagamento INTO r FROM public.transacoes WHERE parcela_id = p1;
  RAISE NOTICE '4) reaberta: status_pago % vl_pago % dt_pagamento %', r.status_pago, r.vl_pago, r.dt_pagamento;
  -- 5) cancela parcela 2
  UPDATE public.projeto_parcelas SET status = 'cancelada' WHERE id = p2;
  RAISE NOTICE '5) parcela 2 cancelada -> transação status_pago %', (SELECT status_pago FROM public.transacoes WHERE parcela_id = p2);
  UPDATE public.projeto_parcelas SET status = 'pendente' WHERE id = p2;
  -- 6) nova parcela (3) e permuta (4) no mesmo orçamento
  INSERT INTO public.projeto_parcelas (projeto_id, numero_parcela, valor, data_fechamento, data_vencimento, status, forma_pagamento, orcamento_id)
    SELECT projeto_id, 3, 1000, current_date, current_date + 30, 'pendente', 'boleto', orcamento_id FROM public.projeto_parcelas WHERE id = p1 RETURNING id INTO p3;
  INSERT INTO public.projeto_parcelas (projeto_id, numero_parcela, valor, data_fechamento, data_vencimento, status, forma_pagamento, orcamento_id)
    SELECT projeto_id, 4, 500, current_date, current_date + 30, 'paga', 'permuta', orcamento_id FROM public.projeto_parcelas WHERE id = p1 RETURNING id INTO p4;
  RAISE NOTICE '6) nova parcela gerou transação: % | permuta gerou transação: % | total_parc da duplicata: %', (SELECT transacao_id IS NOT NULL FROM public.projeto_parcelas WHERE id = p3),
     (SELECT transacao_id IS NOT NULL FROM public.projeto_parcelas WHERE id = p4), (SELECT total_parc FROM public.negociacoes WHERE id = neg);
  -- 7) desfaz: apaga a parcela 3 (sem boleto) -> transação cancelada e solta
  SELECT transacao_id INTO t1 FROM public.projeto_parcelas WHERE id = p3;
  DELETE FROM public.projeto_parcelas WHERE id = p3;
  RAISE NOTICE '7) parcela apagada -> transação status_pago % parcela_id %', (SELECT status_pago FROM public.transacoes WHERE id = t1), (SELECT parcela_id FROM public.transacoes WHERE id = t1);
  -- 8) integridade e recusas
  RAISE NOTICE '8) integridade: %', (SELECT string_agg(verificacao || '=' || qtd, ', ' ORDER BY verificacao) FROM public.vw_financeiro_integridade WHERE verificacao LIKE 'parcela_projeto%' OR verificacao = 'parcela_sem_negociacao');
  RAISE NOTICE '9) cod_duplicata nativo: %, duplicados ativos (tipo,cod): %', (SELECT cod_duplicata FROM public.negociacoes WHERE id = neg), (SELECT count(*) FROM (SELECT 1 FROM public.transacoes WHERE cod_itens_duplicata IS NOT NULL AND status_pago <> 2 GROUP BY tipo, cod_itens_duplicata HAVING count(*) > 1) x);
  RAISE NOTICE '10) retorno_bancario usa a transação existente: %, desfazer ignora transação em aberto: %',
     (SELECT position('SELECT transacao_id INTO v_transacao_id' IN pg_get_functiondef('public.processar_retorno_bancario'::regproc)) > 0),
     (SELECT position('t.status_pago <> 0' IN pg_get_functiondef('public.desfazer_aprovacao_financeira'::regproc)) > 0);
END $$;
ROLLBACK;
