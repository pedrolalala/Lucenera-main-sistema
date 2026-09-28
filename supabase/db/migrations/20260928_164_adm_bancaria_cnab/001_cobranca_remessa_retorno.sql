-- SPEC-165 Fase 1 — Administração Bancária: dados de cobrança por conta,
-- nosso número bancário, reserva atômica de remessa e reescrita do
-- processamento de retorno (Bradesco CNAB 400).

BEGIN;

-- 1.1 Dados de cobrança por conta bancária -------------------------------
ALTER TABLE public.contas_bancarias
  ADD COLUMN IF NOT EXISTS agencia_digito        text,
  ADD COLUMN IF NOT EXISTS conta_digito          text,
  ADD COLUMN IF NOT EXISTS carteira              text,
  ADD COLUMN IF NOT EXISTS codigo_empresa_banco  text,
  ADD COLUMN IF NOT EXISTS proximo_nosso_numero  bigint NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS sequencial_remessa    integer NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.contas_bancarias.codigo_empresa_banco IS
  'SPEC-165: código da empresa no banco (Bradesco: 20 posições do header da remessa CNAB 400).';
COMMENT ON COLUMN public.contas_bancarias.proximo_nosso_numero IS
  'SPEC-165: próximo nosso número (11 dígitos) a atribuir na remessa desta conta.';

-- 1.2 Boleto: nosso número bancário e pagador rastreável ----------------
ALTER TABLE public.boletos
  ADD COLUMN IF NOT EXISTS nosso_numero_banco         text,
  ADD COLUMN IF NOT EXISTS conta_bancaria_remessa_id  uuid REFERENCES public.contas_bancarias(id),
  ADD COLUMN IF NOT EXISTS remessa_sequencial         integer,
  ADD COLUMN IF NOT EXISTS contato_id                 uuid REFERENCES public.contatos(id);

CREATE UNIQUE INDEX IF NOT EXISTS boletos_nosso_numero_banco_conta_key
  ON public.boletos (conta_bancaria_remessa_id, nosso_numero_banco)
  WHERE nosso_numero_banco IS NOT NULL;

-- 1.3 Reserva atômica de remessa ------------------------------------------
CREATE OR REPLACE FUNCTION public.reservar_remessa_cnab(p_conta_bancaria_id uuid, p_boleto_ids uuid[])
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_conta   public.contas_bancarias%ROWTYPE;
  v_seq     integer;
  v_boleto  record;
  v_itens   jsonb := '[]'::jsonb;
BEGIN
  IF NOT public.hub_pode_executar(auth.uid(), 'financeiro', NULL, 'editar') THEN
    RAISE EXCEPTION 'Sem permissão para gerar remessa.' USING ERRCODE = '42501';
  END IF;
  IF p_boleto_ids IS NULL OR array_length(p_boleto_ids, 1) IS NULL THEN
    RAISE EXCEPTION 'Nenhum boleto informado.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_conta FROM public.contas_bancarias WHERE id = p_conta_bancaria_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Conta bancária não encontrada.' USING ERRCODE = 'P0001';
  END IF;
  IF coalesce(v_conta.agencia,'') = '' OR coalesce(v_conta.conta,'') = '' OR coalesce(v_conta.conta_digito,'') = ''
     OR coalesce(v_conta.carteira,'') = '' OR coalesce(v_conta.codigo_empresa_banco,'') = '' THEN
    RAISE EXCEPTION 'Conta % sem dados de cobrança completos (agência, conta, dígito, carteira e código da empresa).', v_conta.nome
      USING ERRCODE = 'P0001';
  END IF;

  v_seq := v_conta.sequencial_remessa + 1;

  FOR v_boleto IN
    SELECT id, nosso_numero_banco, conta_bancaria_remessa_id, empresa_id, status
      FROM public.boletos
     WHERE id = ANY (p_boleto_ids)
     ORDER BY vencimento, id
       FOR UPDATE
  LOOP
    IF v_boleto.status = 'Pago' THEN
      RAISE EXCEPTION 'Boleto % já está pago e não pode ir para remessa.', v_boleto.id USING ERRCODE = 'P0001';
    END IF;
    IF v_conta.empresa_id IS NOT NULL AND v_boleto.empresa_id IS DISTINCT FROM v_conta.empresa_id THEN
      RAISE EXCEPTION 'Boleto % é de outra empresa que não a da conta %.', v_boleto.id, v_conta.nome USING ERRCODE = 'P0001';
    END IF;
    -- Reenvio pela mesma conta mantém o nosso número já registrado.
    IF v_boleto.nosso_numero_banco IS NULL OR v_boleto.conta_bancaria_remessa_id IS DISTINCT FROM p_conta_bancaria_id THEN
      UPDATE public.boletos
         SET nosso_numero_banco = lpad(v_conta.proximo_nosso_numero::text, 11, '0'),
             conta_bancaria_remessa_id = p_conta_bancaria_id
       WHERE id = v_boleto.id;
      v_conta.proximo_nosso_numero := v_conta.proximo_nosso_numero + 1;
    END IF;
    UPDATE public.boletos SET remessa_sequencial = v_seq WHERE id = v_boleto.id;
  END LOOP;

  UPDATE public.contas_bancarias
     SET sequencial_remessa = v_seq,
         proximo_nosso_numero = v_conta.proximo_nosso_numero,
         updated_at = now()
   WHERE id = p_conta_bancaria_id;

  SELECT coalesce(jsonb_agg(jsonb_build_object('id', id, 'nosso_numero_banco', nosso_numero_banco)), '[]'::jsonb)
    INTO v_itens
    FROM public.boletos
   WHERE id = ANY (p_boleto_ids);

  RETURN jsonb_build_object('sequencial', v_seq, 'boletos', v_itens);
END;
$function$;

REVOKE ALL ON FUNCTION public.reservar_remessa_cnab(uuid, uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reservar_remessa_cnab(uuid, uuid[]) TO authenticated;

-- 1.4 Retorno reescrito ---------------------------------------------------
-- Mesma assinatura (text,text,text,jsonb,boolean): CREATE OR REPLACE substitui
-- sem criar overload. Cada registro: nosso_numero, valor_recebido,
-- data_pagamento, ocorrencia_codigo, motivo (opcional).
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

    INSERT INTO public.transacoes (parcela_id, tipo, descricao, valor, data_transacao, vl_pago, dt_pagamento, status_pago, created_by)
    VALUES (v_boleto.parcela_id, 'receita'::public.transacao_tipo,
            'Recebimento boleto ' || coalesce(v_boleto.nosso_numero_banco, v_boleto.nosso_numero),
            v_boleto.valor, v_data, v_recebido, v_data, 1, auth.uid())
    RETURNING id INTO v_transacao_id;

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

NOTIFY pgrst, 'reload schema';

COMMIT;
