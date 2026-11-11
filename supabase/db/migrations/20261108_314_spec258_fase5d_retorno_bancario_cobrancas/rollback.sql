-- SPEC-258 Fase 5d: volta ponte da transacao, processar_retorno_bancario e a view de integridade para as versoes anteriores; remove o espelho de cobrancas.
-- As cobrancas ja criadas e as baixas 'retorno_bancario' ja gravadas NAO sao apagadas (nada e apagado; baixa e imutavel).
DROP TRIGGER IF EXISTS trg_fin_ponte_cobranca_aiu ON public.boletos;
DROP FUNCTION IF EXISTS public.trg_financeiro_ponte_cobranca();
DROP FUNCTION IF EXISTS public.financeiro_ponte_cobranca(uuid);
CREATE OR REPLACE FUNCTION public.financeiro_ponte_transacao(p_tx uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    t public.transacoes; n public.negociacoes;
    v_tit uuid; v_par uuid; v_num int; v_liq numeric; v_sit public.fin_situacao; v_b record; v_baixa uuid;
BEGIN
    SELECT * INTO t FROM public.transacoes WHERE id = p_tx;
    IF NOT FOUND OR t.cod_itens_duplicata IS NOT NULL OR t.negociacao_id IS NULL THEN RETURN; END IF;
    SELECT * INTO n FROM public.negociacoes WHERE id = t.negociacao_id;
    IF n.orcamento_id IS NULL OR t.tipo::text <> 'receita' THEN RETURN; END IF;   -- só vendas de orçamento (4a); outras origens vêm nas próximas fases

    -- título (um por orçamento)
    SELECT id INTO v_tit FROM public.financeiro_titulos WHERE origem_tipo = 'orcamento' AND orcamento_id = n.orcamento_id AND origem_seq = 1;
    IF v_tit IS NULL THEN
        INSERT INTO public.financeiro_titulos (natureza, origem_tipo, orcamento_id, especie, empresa_id, perfil, contato_id, plano_contas_id, projeto_id, documento, descricao)
        VALUES ('receber', 'orcamento', n.orcamento_id, 'venda', n.empresa_id, CASE WHEN t.perfil IN ('ribeirao', 'sao_paulo') THEN t.perfil END,
                n.contato_id, n.plano_contas_id, n.projeto_id, n.num_nota::text, n.observacao)
        RETURNING id INTO v_tit;
    END IF;

    -- parcela (uma por transação)
    SELECT id_novo INTO v_par FROM public.financeiro_legado_ids WHERE tabela_antiga = 'transacoes' AND id_antigo = p_tx;
    IF v_par IS NULL THEN
        v_num := coalesce(t.num_parc, 1);
        IF EXISTS (SELECT 1 FROM public.financeiro_parcelas WHERE titulo_id = v_tit AND numero = v_num) THEN
            SELECT max(numero) + 1 INTO v_num FROM public.financeiro_parcelas WHERE titulo_id = v_tit;
        END IF;
        INSERT INTO public.financeiro_parcelas (titulo_id, numero, vencimento, valor, situacao, confirmada_em, forma_prevista, emissao, descricao, desconto, observacao)
        VALUES (v_tit, v_num, t.dt_vencimento, coalesce(t.vl_parcela, 0), CASE WHEN t.status_pago = 2 THEN 'cancelada'::public.fin_situacao ELSE 'firme'::public.fin_situacao END,
                CASE WHEN t.status_pago <> 2 THEN now() END, nullif(t.tipo_pagamento, ''), t.dt_emissao, t.descricao, greatest(coalesce(t.vl_desconto, 0), 0),
                'Espelho do funil antigo (transação ' || t.id || ')')
        RETURNING id INTO v_par;
        INSERT INTO public.financeiro_legado_ids (tabela_antiga, id_antigo, tabela_nova, id_novo) VALUES ('transacoes', p_tx, 'financeiro_parcelas', v_par);
    END IF;

    SELECT situacao, valor_liquidado INTO v_sit, v_liq FROM public.financeiro_parcelas WHERE id = v_par;

    -- cancelamento (só se nada foi liquidado)
    IF t.status_pago = 2 AND v_sit <> 'cancelada' THEN
        IF v_liq <> 0 THEN RAISE EXCEPTION 'Transação cancelada com baixa na parcela nova: estornar antes.'; END IF;
        UPDATE public.financeiro_parcelas SET situacao = 'cancelada' WHERE id = v_par;
        v_sit := 'cancelada';
    END IF;

    -- ajuste de valor/vencimento enquanto não houver baixa
    IF v_sit = 'firme' AND v_liq = 0 THEN
        UPDATE public.financeiro_parcelas SET valor = coalesce(t.vl_parcela, 0), vencimento = t.dt_vencimento, desconto = greatest(coalesce(t.vl_desconto, 0), 0)
         WHERE id = v_par AND (valor <> coalesce(t.vl_parcela, 0) OR vencimento <> t.dt_vencimento OR desconto <> greatest(coalesce(t.vl_desconto, 0), 0));
    END IF;

    -- pago agora e ainda sem baixa -> baixa
    IF t.status_pago = 1 AND v_sit = 'firme' AND v_liq = 0 THEN
        IF coalesce(t.vl_pago, 0) > 0 THEN
            INSERT INTO public.financeiro_baixas (parcela_id, tipo, data, valor, juros, desconto, forma, conta_bancaria_id, comprovante_url, origem_baixa)
            VALUES (v_par, 'recebimento', coalesce(t.dt_pagamento, current_date), least(t.vl_pago, coalesce(t.vl_parcela, 0)), greatest(t.vl_pago - coalesce(t.vl_parcela, 0), 0),
                    greatest(coalesce(t.vl_desconto, 0), 0), nullif(t.tipo_pagamento, ''), t.conta_id, t.comprovante_url, 'ponte')
            RETURNING id INTO v_baixa;
            IF t.conta_id IS NULL THEN
                INSERT INTO public.financeiro_pendencias (baixa_id, tipo, descricao, responsavel)
                VALUES (v_baixa, 'baixa_sem_conta_bancaria', 'Recebimento sem conta bancária (retorno/baixa manual): informar a conta.', 'Financeiro');
            END IF;
            IF t.vl_pago < coalesce(t.vl_parcela, 0) THEN
                INSERT INTO public.financeiro_baixas (parcela_id, tipo, data, valor, forma, motivo, origem_baixa)
                VALUES (v_par, 'abatimento', coalesce(t.dt_pagamento, current_date), t.vl_parcela - t.vl_pago, nullif(t.tipo_pagamento, ''),
                        'Diferença entre o valor da parcela e o valor recebido', 'ponte');
            END IF;
        ELSE
            INSERT INTO public.financeiro_baixas (parcela_id, tipo, data, valor, forma, motivo, origem_baixa)
            VALUES (v_par, 'baixa_interna', coalesce(t.dt_pagamento, current_date), coalesce(t.vl_parcela, 0), nullif(t.tipo_pagamento, ''),
                    'Baixa sem movimento de caixa no sistema antigo (pago com valor zero)', 'ponte');
        END IF;
    END IF;

    -- pagamento desfeito -> estorna as baixas que ainda estão de pé
    IF t.status_pago = 0 AND v_sit = 'firme' AND v_liq <> 0 THEN
        FOR v_b IN SELECT b.id FROM public.financeiro_baixas b WHERE b.parcela_id = v_par AND b.tipo <> 'estorno'
                    AND NOT EXISTS (SELECT 1 FROM public.financeiro_baixas e WHERE e.estorno_de = b.id) ORDER BY b.criado_em DESC LOOP
            INSERT INTO public.financeiro_baixas (parcela_id, tipo, data, valor, forma, conta_bancaria_id, motivo, origem_baixa, estorno_de)
            SELECT b.parcela_id, 'estorno', current_date, b.valor, b.forma, b.conta_bancaria_id, 'Pagamento desfeito no sistema antigo', 'ponte', b.id
              FROM public.financeiro_baixas b WHERE b.id = v_b.id;
        END LOOP;
    END IF;
END $function$;

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

$function$;

CREATE OR REPLACE VIEW public.vw_financeiro_ponte_integridade AS
SELECT teste,
    violacoes
   FROM ( SELECT 'espelho: falhas abertas'::text AS teste,
            count(*) AS violacoes
           FROM financeiro_ponte_falhas
          WHERE financeiro_ponte_falhas.resolvida_em IS NULL
        UNION ALL
         SELECT 'espelho: transacao nativa de orcamento sem parcela no modelo novo'::text AS text,
            count(*) AS count
           FROM transacoes t
             JOIN negociacoes n ON n.id = t.negociacao_id
          WHERE t.cod_itens_duplicata IS NULL AND n.orcamento_id IS NOT NULL AND t.tipo::text = 'receita'::text AND NOT (EXISTS ( SELECT 1
                   FROM financeiro_legado_ids l
                  WHERE l.tabela_antiga = 'transacoes'::text AND l.id_antigo = t.id))
        UNION ALL
         SELECT 'espelho: situacao paga/cancelada diferente entre antigo e novo'::text AS text,
            count(*) AS count
           FROM transacoes t
             JOIN financeiro_legado_ids l ON l.tabela_antiga = 'transacoes'::text AND l.id_antigo = t.id
             JOIN financeiro_parcelas p ON p.id = l.id_novo
          WHERE t.cod_itens_duplicata IS NULL AND ((t.status_pago = 2) <> (p.situacao = 'cancelada'::fin_situacao) OR (t.status_pago = 1) <> (p.situacao = 'firme'::fin_situacao AND p.valor_liquidado >= p.valor AND p.valor_liquidado > 0::numeric OR p.situacao = 'firme'::fin_situacao AND p.valor = 0::numeric AND (EXISTS ( SELECT 1
                   FROM financeiro_baixas b
                  WHERE b.parcela_id = p.id))))
        UNION ALL
         SELECT 'espelho: valor da parcela diferente entre antigo e novo'::text AS text,
            count(*) AS count
           FROM transacoes t
             JOIN financeiro_legado_ids l ON l.tabela_antiga = 'transacoes'::text AND l.id_antigo = t.id
             JOIN financeiro_parcelas p ON p.id = l.id_novo
          WHERE t.cod_itens_duplicata IS NULL AND t.status_pago <> 2 AND round(COALESCE(t.vl_parcela, 0::numeric), 2) <> round(p.valor, 2)
        UNION ALL
         SELECT 'devolucao: parcela de projeto negativa (nao permuta) sem parcela no modelo novo'::text AS text,
            count(*) AS count
           FROM projeto_parcelas pp
             JOIN orcamentos o ON o.id = pp.orcamento_id
          WHERE pp.valor < 0::numeric AND o.natureza_operacao = 'devolucao'::text AND pp.status::text <> 'cancelada'::text AND lower(COALESCE(pp.forma_pagamento::text, ''::text)) <> 'permuta'::text AND NOT (EXISTS ( SELECT 1
                   FROM financeiro_legado_ids l
                  WHERE l.tabela_antiga = 'projeto_parcelas'::text AND l.id_antigo = pp.id))) z
  WHERE ( SELECT pode_acessar_sistema('financeiro'::text) AS pode_acessar_sistema);
