-- Migration 20260707_028 - SPEC-008 Parte 2
-- RPC processar_retorno_bancario: le um lote de registros de retorno CNAB
-- ja parseado pelo frontend (parseCnab400) e aplica baixa/divergencia/nao
-- encontrado em uma unica transacao, com trava contra reprocessamento.

CREATE OR REPLACE FUNCTION public.processar_retorno_bancario(
  p_nome_arquivo text,
  p_hash         text,
  p_conta        text,
  p_registros    jsonb,   -- array de {nosso_numero, valor_recebido, data_pagamento, ocorrencia_codigo}
  p_forcar       boolean DEFAULT false
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_arquivo_id     uuid;
  v_reg            jsonb;
  v_boleto         public.boletos%ROWTYPE;
  v_transacao_id   uuid;
  v_aplicados      integer := 0;
  v_divergentes    integer := 0;
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
    SELECT * INTO v_boleto FROM public.boletos WHERE nosso_numero = v_reg->>'nosso_numero' LIMIT 1;

    IF NOT FOUND THEN
      INSERT INTO public.retorno_bancario_registros
        (arquivo_id, nosso_numero, valor_recebido, data_pagamento, ocorrencia_codigo, status_aplicacao)
      VALUES
        (v_arquivo_id, v_reg->>'nosso_numero', (v_reg->>'valor_recebido')::numeric, (v_reg->>'data_pagamento')::date, v_reg->>'ocorrencia_codigo', 'nao_encontrado');
      v_nao_encontrados := v_nao_encontrados + 1;
      CONTINUE;
    END IF;

    IF coalesce((v_reg->>'valor_recebido')::numeric, 0) <> coalesce(v_boleto.valor, 0) THEN
      INSERT INTO public.retorno_bancario_registros
        (arquivo_id, nosso_numero, boleto_id, parcela_id, valor_esperado, valor_recebido, data_pagamento, ocorrencia_codigo, status_aplicacao, motivo_divergencia)
      VALUES
        (v_arquivo_id, v_reg->>'nosso_numero', v_boleto.id, v_boleto.parcela_id, v_boleto.valor, (v_reg->>'valor_recebido')::numeric, (v_reg->>'data_pagamento')::date, v_reg->>'ocorrencia_codigo', 'divergente', 'Valor recebido difere do valor esperado do boleto.');
      v_divergentes := v_divergentes + 1;
      CONTINUE;
    END IF;

    UPDATE public.boletos
    SET status = 'pago',
        valor_pago = (v_reg->>'valor_recebido')::numeric,
        data_pagamento = (v_reg->>'data_pagamento')::date
    WHERE id = v_boleto.id;

    IF v_boleto.parcela_id IS NOT NULL THEN
      UPDATE public.projeto_parcelas
      SET status = 'paga'::public.parcela_status,
          valor_pago = (v_reg->>'valor_recebido')::numeric,
          data_pagamento = (v_reg->>'data_pagamento')::date
      WHERE id = v_boleto.parcela_id;
    END IF;

    INSERT INTO public.transacoes (parcela_id, tipo, descricao, valor, data_transacao, vl_pago, dt_pagamento, status_pago, created_by)
    VALUES (
      v_boleto.parcela_id,
      'receita'::public.transacao_tipo,
      'Recebimento boleto ' || v_boleto.nosso_numero,
      v_boleto.valor,
      (v_reg->>'data_pagamento')::date,
      (v_reg->>'valor_recebido')::numeric,
      (v_reg->>'data_pagamento')::date,
      1,
      auth.uid()
    )
    RETURNING id INTO v_transacao_id;

    IF v_boleto.parcela_id IS NOT NULL THEN
      UPDATE public.projeto_parcelas
      SET transacao_id = v_transacao_id
      WHERE id = v_boleto.parcela_id;
    END IF;

    INSERT INTO public.retorno_bancario_registros
      (arquivo_id, nosso_numero, boleto_id, parcela_id, transacao_id, valor_esperado, valor_recebido, data_pagamento, ocorrencia_codigo, status_aplicacao)
    VALUES
      (v_arquivo_id, v_reg->>'nosso_numero', v_boleto.id, v_boleto.parcela_id, v_transacao_id, v_boleto.valor, (v_reg->>'valor_recebido')::numeric, (v_reg->>'data_pagamento')::date, v_reg->>'ocorrencia_codigo', 'aplicado');
    v_aplicados := v_aplicados + 1;
  END LOOP;

  UPDATE public.retorno_bancario_arquivos
  SET total_aplicados = v_aplicados, total_divergentes = v_divergentes, total_nao_encontrados = v_nao_encontrados
  WHERE id = v_arquivo_id;

  RETURN jsonb_build_object(
    'arquivo_id', v_arquivo_id,
    'aplicados', v_aplicados,
    'divergentes', v_divergentes,
    'nao_encontrados', v_nao_encontrados
  );
END;
$$;

COMMENT ON FUNCTION public.processar_retorno_bancario(text, text, text, jsonb, boolean) IS
'SPEC-008. Aplica lote de retorno CNAB: baixa boleto/parcela + lanca transacao quando valor confere; marca divergente sem alterar nada quando nao confere; marca nao_encontrado quando nosso_numero nao existe. Bloqueia reprocessamento do mesmo hash salvo p_forcar=true.';

GRANT EXECUTE ON FUNCTION public.processar_retorno_bancario(text, text, text, jsonb, boolean) TO authenticated;
