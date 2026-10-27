-- SPEC-231 F2/F3 (reunião 26/10/2026): emissão de NF no Vendas sem digitar número/série/data (vêm da Focus/SEFAZ)
-- e com os dados que o faturamento precisa poder mexer: CPF/CNPJ e IE do destinatário (quando o cadastro veio
-- errado), dados adicionais, transportadora, modalidade de frete (CIF/FOB) e desconto.
--   1. colunas novas em notas_fiscais (todas opcionais; nulo = usa o cadastro/orçamento como antes);
--   2. registrar_nota_fiscal_parcial: mesma assinatura (sem sobrecarga), número vazio vira 'A DEFINIR';
--   3. definir_dados_emissao_nota_fiscal: grava esses dados no rascunho (mesma permissão da emissão, só enquanto
--      a nota não foi enviada/autorizada). Quem lê é a Edge Function emitir-nota-fiscal.
--   4. SPEC-231 F1 (especificação do usuário 27/10): tipo da nota (venda | devolucao). A devolução nasce no
--      orçamento de Devolução (que já gera o crédito e devolve as peças — SPEC-071/178/181); a nota de devolução
--      é só o documento fiscal, referenciando a chave da NF de venda original. O tipo vem do orçamento.

BEGIN;

ALTER TABLE public.notas_fiscais
  ADD COLUMN IF NOT EXISTS dados_adicionais text,
  ADD COLUMN IF NOT EXISTS modalidade_frete text,
  ADD COLUMN IF NOT EXISTS transportadora_nome text,
  ADD COLUMN IF NOT EXISTS transportadora_cnpj text,
  ADD COLUMN IF NOT EXISTS valor_desconto numeric(12,2),
  ADD COLUMN IF NOT EXISTS destinatario_cpf_cnpj text,
  ADD COLUMN IF NOT EXISTS destinatario_ie text,
  ADD COLUMN IF NOT EXISTS tipo_nota text NOT NULL DEFAULT 'venda',
  ADD COLUMN IF NOT EXISTS chave_nfe_referenciada text;

ALTER TABLE public.notas_fiscais
  ADD CONSTRAINT notas_fiscais_modalidade_frete_check
    CHECK (modalidade_frete IS NULL OR modalidade_frete IN ('0', '1', '2', '9')),
  ADD CONSTRAINT notas_fiscais_valor_desconto_check
    CHECK (valor_desconto IS NULL OR valor_desconto >= 0),
  ADD CONSTRAINT notas_fiscais_tipo_nota_check
    CHECK (tipo_nota IN ('venda', 'devolucao'));

COMMENT ON COLUMN public.notas_fiscais.tipo_nota IS
  'SPEC-231 F1: venda (faturamento) ou devolucao (documento fiscal da devolução; crédito e estoque são do orçamento de Devolução). Vem de orcamentos.natureza_operacao.';
COMMENT ON COLUMN public.notas_fiscais.chave_nfe_referenciada IS
  'SPEC-231 F1: na devolução, chave de 44 dígitos da NF de venda original (notas_referenciadas da NF-e).';

COMMENT ON COLUMN public.notas_fiscais.modalidade_frete IS
  'SPEC-231 F3: modFrete da NF-e - 0 CIF (por conta do emitente), 1 FOB (por conta do destinatário), 2 terceiros, 9 sem frete. Nulo = default pelo frete do orçamento.';
COMMENT ON COLUMN public.notas_fiscais.destinatario_cpf_cnpj IS
  'SPEC-231 F3: correção do CPF/CNPJ do destinatário só nesta nota (nulo = o do cadastro).';
COMMENT ON COLUMN public.notas_fiscais.destinatario_ie IS
  'SPEC-231 F3: correção da inscrição estadual do destinatário só nesta nota (nulo = a do cadastro).';

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

  -- SPEC-231 F2: número e série são da SEFAZ/Focus (gravados na autorização por aplicar-resultado-focus);
  -- o rascunho não pede mais número digitado.
  IF p_numero_nf IS NULL OR btrim(p_numero_nf) = '' THEN
    p_numero_nf := 'A DEFINIR';
  END IF;

  IF p_itens IS NULL OR jsonb_array_length(p_itens) = 0 THEN
    RAISE EXCEPTION 'Nota fiscal precisa de ao menos um item.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_orcamento FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento/venda % não encontrado.', p_orcamento_id USING ERRCODE = 'P0001';
  END IF;

  -- SPEC-231 F1: devolução aprovada também emite (nota de devolução)
  IF v_orcamento.status <> 'Orçamento Aprovado' OR v_orcamento.natureza_operacao NOT IN ('venda', 'devolucao') THEN
    RAISE EXCEPTION 'Só é possível emitir nota fiscal para uma venda ou devolução em "Orçamento Aprovado".'
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

CREATE OR REPLACE FUNCTION public.definir_dados_emissao_nota_fiscal(p_nota_fiscal_id uuid, p_dados jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_status text;
  v_frete text := nullif(btrim(coalesce(p_dados->>'modalidade_frete', '')), '');
  v_desconto numeric := nullif(btrim(coalesce(p_dados->>'valor_desconto', '')), '')::numeric;
BEGIN
  IF COALESCE(auth.role(), '') <> 'service_role'
     AND NOT public.hub_pode_executar(auth.uid(), 'vendas', NULL, 'emitir_nota_fiscal') THEN
    RAISE EXCEPTION 'Permissão negada para editar a nota fiscal.' USING ERRCODE = 'P0001';
  END IF;

  SELECT status_emissao INTO v_status FROM public.notas_fiscais WHERE id = p_nota_fiscal_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Nota fiscal % não encontrada.', p_nota_fiscal_id USING ERRCODE = 'P0001';
  END IF;
  IF v_status NOT IN ('nao_emitida', 'erro_autorizacao') THEN
    RAISE EXCEPTION 'A nota já foi enviada para a SEFAZ — não dá mais para mudar os dados.' USING ERRCODE = 'P0001';
  END IF;
  IF v_frete IS NOT NULL AND v_frete NOT IN ('0', '1', '2', '9') THEN
    RAISE EXCEPTION 'Modalidade de frete inválida: %.', v_frete USING ERRCODE = 'P0001';
  END IF;
  IF v_desconto IS NOT NULL AND v_desconto < 0 THEN
    RAISE EXCEPTION 'Desconto não pode ser negativo.' USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.notas_fiscais
  SET dados_adicionais      = nullif(btrim(coalesce(p_dados->>'dados_adicionais', '')), ''),
      modalidade_frete      = v_frete,
      transportadora_nome   = nullif(btrim(coalesce(p_dados->>'transportadora_nome', '')), ''),
      transportadora_cnpj   = nullif(regexp_replace(coalesce(p_dados->>'transportadora_cnpj', ''), '\D', '', 'g'), ''),
      valor_desconto        = nullif(v_desconto, 0),
      destinatario_cpf_cnpj = nullif(regexp_replace(coalesce(p_dados->>'destinatario_cpf_cnpj', ''), '\D', '', 'g'), ''),
      destinatario_ie       = nullif(btrim(coalesce(p_dados->>'destinatario_ie', '')), ''),
      chave_nfe_referenciada = nullif(regexp_replace(coalesce(p_dados->>'chave_nfe_referenciada', ''), '\D', '', 'g'), ''),
      -- SPEC-231 F1: o tipo da nota segue o orçamento (Devolução -> nota de devolução)
      tipo_nota = CASE
        WHEN (SELECT o.natureza_operacao FROM public.orcamentos o WHERE o.id = notas_fiscais.orcamento_id) = 'devolucao'
        THEN 'devolucao' ELSE 'venda' END
  WHERE id = p_nota_fiscal_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.definir_dados_emissao_nota_fiscal(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.definir_dados_emissao_nota_fiscal(uuid, jsonb) TO authenticated;

COMMIT;
