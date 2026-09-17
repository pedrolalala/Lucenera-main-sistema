-- SPEC-153: Sistema de Vendas + Nota Fiscal pós-aprovação (nota parcial
-- multi-pagador). Prepara o terreno de dados para o sistema novo "Vendas" --
-- a emissão real via Focus NFe é a SPEC-154, fora do escopo desta migration.
--
-- RASCUNHO -- NÃO aplicar sem aprovação/execução manual do usuário.
--
-- Contexto conferido em supabase/db/current/01_schema_full.sql (linhas
-- 5287-5321) e nas migrations já aplicadas 20260806_081 (notas_fiscais.
-- tipo_operacao/perfil), 20260807_088 (orcamentos.natureza_operacao) e
-- 20260911_136 (orcamentos.numero_venda) antes de escrever este SQL --
-- nenhum nome de coluna abaixo foi inventado.

BEGIN;

-- =============================================================================
-- 1. notas_fiscais ganha pagador explícito, independente do cliente_id do
--    orçamento (caso real e recorrente: nota parcial emitida em nome de
--    pessoa diferente do titular da venda, ex. cônjuge sem cadastro).
-- =============================================================================

ALTER TABLE public.notas_fiscais
  ADD COLUMN IF NOT EXISTS cliente_id uuid REFERENCES public.contatos(id),
  ADD COLUMN IF NOT EXISTS nome_destinatario text;

COMMENT ON COLUMN public.notas_fiscais.cliente_id IS
  'SPEC-153. Pagador real desta nota parcial quando tem cadastro em contatos -- pode ser diferente de orcamentos.cliente_id. NULL assume o cliente do orçamento.';
COMMENT ON COLUMN public.notas_fiscais.nome_destinatario IS
  'SPEC-153. Pagador real desta nota parcial sem cadastro em contatos (ex. cônjuge), sem forçar cadastro novo.';

-- =============================================================================
-- 2. notas_fiscais_itens: rastreia por venda quais itens (e quanto de cada)
--    já foram cobertos por nota parcial. A soma de quantidade_faturada por
--    orcamento_item_id nunca pode ultrapassar orcamento_itens.quantidade --
--    garantido pela RPC abaixo (transacional), não por trigger cega.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.notas_fiscais_itens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nota_fiscal_id uuid NOT NULL REFERENCES public.notas_fiscais(id) ON DELETE CASCADE,
  orcamento_item_id uuid NOT NULL REFERENCES public.orcamento_itens(id),
  quantidade_faturada numeric NOT NULL CHECK (quantidade_faturada > 0),
  valor_faturado numeric,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.notas_fiscais_itens IS
  'SPEC-153. Granularidade de nota fiscal parcial: quais itens do orçamento (e quanto de cada) uma nota específica cobre. Sistema "Vendas" é o dono do CRUD; o schema é compartilhado.';

CREATE INDEX IF NOT EXISTS idx_notas_fiscais_itens_nota_fiscal_id
  ON public.notas_fiscais_itens (nota_fiscal_id);
CREATE INDEX IF NOT EXISTS idx_notas_fiscais_itens_orcamento_item_id
  ON public.notas_fiscais_itens (orcamento_item_id);

ALTER TABLE public.notas_fiscais_itens ENABLE ROW LEVEL SECURITY;

-- Mesmo padrão permissivo já usado em notas_fiscais/orcamento_itens
-- (supabase/db/current/07_rls_policies.sql) -- controle de acesso real do
-- ecossistema ainda depende de hub_pode_executar dentro das RPCs/telas, não
-- de RLS granular por linha.
DROP POLICY IF EXISTS authenticated_all_notas_fiscais_itens ON public.notas_fiscais_itens;
CREATE POLICY authenticated_all_notas_fiscais_itens ON public.notas_fiscais_itens
  AS PERMISSIVE FOR ALL TO authenticated
  USING (true) WITH CHECK (true);

-- =============================================================================
-- 3. RPC transacional: valida cobertura (soma de notas já existentes + a
--    nova não pode ultrapassar orcamento_itens.quantidade) e insere
--    notas_fiscais + notas_fiscais_itens numa única transação -- evita
--    corrida entre duas notas parciais simultâneas da mesma venda.
--
--    p_itens: jsonb array de {"orcamento_item_id": uuid, "quantidade_faturada":
--    numeric, "valor_faturado": numeric}.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.registrar_nota_fiscal_parcial(
  p_orcamento_id uuid,
  p_numero_nf text,
  p_itens jsonb,
  p_serie text DEFAULT NULL,
  p_data_emissao date DEFAULT NULL,
  p_cliente_id uuid DEFAULT NULL,
  p_nome_destinatario text DEFAULT NULL,
  p_tipo_operacao text DEFAULT 'CR',
  p_perfil text DEFAULT NULL,
  p_fornecedor text DEFAULT NULL,
  p_arquivo_url text DEFAULT NULL
)
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

COMMENT ON FUNCTION public.registrar_nota_fiscal_parcial IS
  'SPEC-153. Registro manual de nota fiscal (parcial, multi-pagador) a partir de uma venda -- sem chamar API fiscal externa (isso é a SPEC-154). Transacional: trava os orcamento_itens envolvidos e valida cobertura antes de inserir.';

NOTIFY pgrst, 'reload schema';

COMMIT;
