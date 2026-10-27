-- Rollback SPEC-231 F2/F3: volta registrar_nota_fiscal_parcial como estava em 27/10, apaga a função nova e as colunas.
BEGIN;

CREATE OR REPLACE FUNCTION public.registrar_nota_fiscal_parcial(p_orcamento_id uuid, p_numero_nf text, p_itens jsonb, p_serie text DEFAULT NULL::text, p_data_emissao date DEFAULT NULL::date, p_cliente_id uuid DEFAULT NULL::uuid, p_nome_destinatario text DEFAULT NULL::text, p_tipo_operacao text DEFAULT 'CR'::text, p_perfil text DEFAULT NULL::text, p_fornecedor text DEFAULT NULL::text, p_arquivo_url text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_orcamento public.orcamentos%ROWTYPE;
  v_item jsonb;
  v_orcamento_item_id uuid;
  v_quantidade_faturada numeric;
  v_valor_faturado numeric;
  v_quantidade_disponivel numeric;
  v_ja_faturado numeric;
  v_quantidade_item numeric;
  v_nota_fiscal_id uuid;
  v_valor_total numeric := 0;
  v_itens_inseridos integer := 0;
BEGIN
  IF COALESCE(auth.role(), '') <> 'service_role'
     AND NOT public.hub_pode_executar(auth.uid(), 'vendas', NULL, 'emitir_nota_fiscal') THEN
    RAISE EXCEPTION 'Permissão negada para registrar nota fiscal.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_numero_nf IS NULL OR btrim(p_numero_nf) = '' THEN
    RAISE EXCEPTION 'Número da NF é obrigatório.' USING ERRCODE = 'P0001';
  END IF;

  IF p_itens IS NULL OR jsonb_array_length(p_itens) = 0 THEN
    RAISE EXCEPTION 'Nota fiscal precisa de ao menos um item.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_orcamento FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento/venda % não encontrado.', p_orcamento_id USING ERRCODE = 'P0001';
  END IF;

  IF v_orcamento.status <> 'Orçamento Aprovado' OR v_orcamento.natureza_operacao <> 'venda' THEN
    RAISE EXCEPTION 'Só é possível emitir nota fiscal para uma venda em "Orçamento Aprovado".'
      USING ERRCODE = 'P0001';
  END IF;

  -- Trava as linhas de orcamento_itens envolvidas nesta chamada antes de
  -- somar a cobertura já existente, para bloquear corrida real entre duas
  -- notas parciais simultâneas.
  PERFORM 1
  FROM public.orcamento_itens oi
  WHERE oi.id IN (
    SELECT (elem->>'orcamento_item_id')::uuid FROM jsonb_array_elements(p_itens) elem
  )
  FOR UPDATE;

  INSERT INTO public.notas_fiscais (
    numero_nf, serie, data_emissao, valor, fornecedor, orcamento_id,
    cliente_id, nome_destinatario, tipo_operacao, perfil, arquivo_url
  ) VALUES (
    p_numero_nf, p_serie, p_data_emissao, 0, p_fornecedor, p_orcamento_id,
    p_cliente_id, p_nome_destinatario, p_tipo_operacao, p_perfil, p_arquivo_url
  ) RETURNING id INTO v_nota_fiscal_id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_itens)
  LOOP
    v_orcamento_item_id := (v_item->>'orcamento_item_id')::uuid;
    v_quantidade_faturada := (v_item->>'quantidade_faturada')::numeric;
    v_valor_faturado := NULLIF(v_item->>'valor_faturado', '')::numeric;

    IF v_orcamento_item_id IS NULL OR COALESCE(v_quantidade_faturada, 0) <= 0 THEN
      RAISE EXCEPTION 'Item de nota fiscal inválido (orcamento_item_id/quantidade).'
        USING ERRCODE = 'P0001';
    END IF;

    SELECT quantidade INTO v_quantidade_item
    FROM public.orcamento_itens
    WHERE id = v_orcamento_item_id AND orcamento_id = p_orcamento_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Item % não pertence à venda %.', v_orcamento_item_id, p_orcamento_id
        USING ERRCODE = 'P0001';
    END IF;

    SELECT COALESCE(SUM(quantidade_faturada), 0) INTO v_ja_faturado
    FROM public.notas_fiscais_itens
    WHERE orcamento_item_id = v_orcamento_item_id;

    v_quantidade_disponivel := COALESCE(v_quantidade_item, 0) - v_ja_faturado;

    IF v_quantidade_faturada > v_quantidade_disponivel THEN
      RAISE EXCEPTION 'Item % excede a quantidade disponível para nota fiscal (disponível %, pedido %).',
        v_orcamento_item_id, v_quantidade_disponivel, v_quantidade_faturada
        USING ERRCODE = 'P0001';
    END IF;

    INSERT INTO public.notas_fiscais_itens (
      nota_fiscal_id, orcamento_item_id, quantidade_faturada, valor_faturado
    ) VALUES (
      v_nota_fiscal_id, v_orcamento_item_id, v_quantidade_faturada, v_valor_faturado
    );

    v_itens_inseridos := v_itens_inseridos + 1;
    v_valor_total := v_valor_total + COALESCE(v_valor_faturado, 0);
  END LOOP;

  UPDATE public.notas_fiscais SET valor = v_valor_total WHERE id = v_nota_fiscal_id;

  RETURN jsonb_build_object(
    'nota_fiscal_id', v_nota_fiscal_id,
    'orcamento_id', p_orcamento_id,
    'itens_inseridos', v_itens_inseridos,
    'valor_total', v_valor_total
  );
END;
$function$;

DROP FUNCTION IF EXISTS public.definir_dados_emissao_nota_fiscal(uuid, jsonb);

ALTER TABLE public.notas_fiscais
  DROP CONSTRAINT IF EXISTS notas_fiscais_modalidade_frete_check,
  DROP CONSTRAINT IF EXISTS notas_fiscais_valor_desconto_check,
  DROP CONSTRAINT IF EXISTS notas_fiscais_tipo_nota_check,
  DROP COLUMN IF EXISTS tipo_nota,
  DROP COLUMN IF EXISTS chave_nfe_referenciada,
  DROP COLUMN IF EXISTS dados_adicionais,
  DROP COLUMN IF EXISTS modalidade_frete,
  DROP COLUMN IF EXISTS transportadora_nome,
  DROP COLUMN IF EXISTS transportadora_cnpj,
  DROP COLUMN IF EXISTS valor_desconto,
  DROP COLUMN IF EXISTS destinatario_cpf_cnpj,
  DROP COLUMN IF EXISTS destinatario_ie;

COMMIT;
