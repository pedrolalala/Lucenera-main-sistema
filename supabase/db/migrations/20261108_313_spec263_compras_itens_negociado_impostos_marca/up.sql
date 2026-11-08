-- SPEC-263: Necessidade de Compra — (A) ajustar ST/IPI em lote por marca, (B) incluir itens ao editar pedido,
-- (C) valor final negociado do pedido.

-- ===== C. colunas do pedido =====
ALTER TABLE public.pedidos_compra
  ADD COLUMN IF NOT EXISTS valor_negociado numeric(12,2),  -- valor final combinado com o fornecedor (fixa o total)
  ADD COLUMN IF NOT EXISTS valor_tabela    numeric(12,2);  -- total dos itens antes de desconto/negociacao (so pedidos editados a partir de agora)
COMMENT ON COLUMN public.pedidos_compra.valor_negociado IS 'SPEC-263: valor final negociado; quando preenchido, valor_total = valor_negociado.';
COMMENT ON COLUMN public.pedidos_compra.valor_tabela IS 'SPEC-263: soma quantidade x custo dos itens antes do desconto/valor negociado.';

-- ===== B + C. editar_pedido_compra (mesma funcao, +1 parametro com DEFAULT; DROP+CREATE na mesma transacao: sem sobrecarga) =====
DROP FUNCTION public.editar_pedido_compra(uuid, jsonb, date, text, text, numeric, uuid, text);
CREATE OR REPLACE FUNCTION public.editar_pedido_compra(p_pedido_id uuid, p_itens jsonb DEFAULT '[]'::jsonb, p_data_prevista_entrega date DEFAULT NULL::date, p_condicoes_pagamento text DEFAULT NULL::text, p_observacao text DEFAULT NULL::text, p_desconto_percentual numeric DEFAULT NULL::numeric, p_empresa_id uuid DEFAULT NULL::uuid, p_local_entrega text DEFAULT NULL::text, p_valor_negociado numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_pedido      public.pedidos_compra%ROWTYPE;
  v_item        jsonb;
  v_item_id     uuid;
  v_qtd         numeric;
  v_custo       numeric;
  v_solic       uuid;
  v_sobra       numeric;
  v_orig        record;
  v_total       numeric(12,2);
  v_restantes   integer;
  v_parcelas    integer := 0;
  v_prod        uuid;
  v_nsolic      uuid;
  v_bruto       numeric;
  v_desc        numeric;
BEGIN
  IF NOT hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar') THEN
    RAISE EXCEPTION 'Sem permissao para editar pedido de compra.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_pedido FROM public.pedidos_compra WHERE id = p_pedido_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pedido de compra % nao encontrado.', p_pedido_id USING ERRCODE = 'P0001';
  END IF;
  IF v_pedido.status <> 'aguardando_aprovar' THEN
    RAISE EXCEPTION 'So pedido em "Aguardando aprovar" pode ser editado (pedido % esta em %).', v_pedido.numero, v_pedido.status
      USING ERRCODE = 'P0001';
  END IF;
  IF p_desconto_percentual IS NOT NULL AND (p_desconto_percentual < 0 OR p_desconto_percentual > 100) THEN
    RAISE EXCEPTION 'Desconto precisa estar entre 0 e 100.' USING ERRCODE = 'P0001';
  END IF;
  IF p_empresa_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.empresas WHERE id = p_empresa_id) THEN
    RAISE EXCEPTION 'Empresa % nao encontrada.', p_empresa_id USING ERRCODE = 'P0001';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(coalesce(p_itens, '[]'::jsonb))
  LOOP
    -- SPEC-263 B: item novo = elemento com produto_id e SEM pedido_item_id. Nasce como nos pedidos avulsos:
    -- uma solicitacao (status pedido_gerado) + o item do pedido, sem vinculo com venda.
    IF NOT (v_item ? 'pedido_item_id') AND (v_item ? 'produto_id') THEN
      v_prod  := (v_item->>'produto_id')::uuid;
      v_qtd   := NULLIF(v_item->>'quantidade', '')::numeric;
      v_custo := NULLIF(v_item->>'custo_unitario', '')::numeric;
      IF NOT EXISTS (SELECT 1 FROM public.produtos WHERE id = v_prod) THEN
        RAISE EXCEPTION 'Produto % nao encontrado.', v_prod USING ERRCODE = 'P0001';
      END IF;
      IF EXISTS (SELECT 1 FROM public.pedido_compra_itens WHERE pedido_id = p_pedido_id AND produto_id = v_prod) THEN
        RAISE EXCEPTION 'Esse produto ja esta no pedido %: altere a quantidade da linha existente.', v_pedido.numero USING ERRCODE = 'P0001';
      END IF;
      IF v_qtd IS NULL OR v_qtd <= 0 THEN
        RAISE EXCEPTION 'Quantidade deve ser maior que zero.' USING ERRCODE = 'P0001';
      END IF;
      IF v_custo IS NULL OR v_custo <= 0 THEN
        RAISE EXCEPTION 'Custo unitario deve ser maior que zero.' USING ERRCODE = 'P0001';
      END IF;
      INSERT INTO public.solicitacoes_compra (produto_id, quantidade, status, prioridade, observacao, solicitado_por)
      VALUES (v_prod, v_qtd, 'pedido_gerado', 'normal', 'Incluido na edicao do pedido ' || v_pedido.numero, auth.uid())
      RETURNING id INTO v_nsolic;
      INSERT INTO public.pedido_compra_itens (pedido_id, solicitacao_id, produto_id, quantidade, qtd_recebida, custo_unitario,
                                              custo_liquido, valor_ipi, valor_st, valor_outras_despesas)
      VALUES (p_pedido_id, v_nsolic, v_prod, v_qtd, 0, v_custo,
              NULLIF(v_item->>'custo_liquido', '')::numeric, NULLIF(v_item->>'valor_ipi', '')::numeric,
              NULLIF(v_item->>'valor_st', '')::numeric, NULLIF(v_item->>'valor_outras_despesas', '')::numeric);
      CONTINUE;
    END IF;

    v_item_id := (v_item->>'pedido_item_id')::uuid;
    IF NOT EXISTS (SELECT 1 FROM public.pedido_compra_itens WHERE id = v_item_id AND pedido_id = p_pedido_id) THEN
      RAISE EXCEPTION 'Item % nao pertence ao pedido %.', v_item_id, v_pedido.numero USING ERRCODE = 'P0001';
    END IF;

    IF coalesce((v_item->>'remover')::boolean, false) THEN
      SELECT solicitacao_id INTO v_solic FROM public.pedido_compra_itens WHERE id = v_item_id;
      DELETE FROM public.pedido_compra_itens WHERE id = v_item_id;  -- origens saem em cascata
      IF v_solic IS NOT NULL THEN
        DELETE FROM public.solicitacoes_compra s
         WHERE s.id = v_solic AND NOT EXISTS (SELECT 1 FROM public.pedido_compra_itens x WHERE x.solicitacao_id = v_solic);
      END IF;
      CONTINUE;
    END IF;

    v_qtd   := NULLIF(v_item->>'quantidade', '')::numeric;
    v_custo := NULLIF(v_item->>'custo_unitario', '')::numeric;
    IF v_qtd IS NOT NULL AND v_qtd <= 0 THEN
      RAISE EXCEPTION 'Quantidade deve ser maior que zero.' USING ERRCODE = 'P0001';
    END IF;
    IF v_custo IS NOT NULL AND v_custo <= 0 THEN
      RAISE EXCEPTION 'Custo unitario deve ser maior que zero.' USING ERRCODE = 'P0001';
    END IF;

    UPDATE public.pedido_compra_itens SET
      quantidade            = coalesce(v_qtd, quantidade),
      custo_unitario        = coalesce(v_custo, custo_unitario),
      custo_liquido         = CASE WHEN v_item ? 'custo_liquido' THEN NULLIF(v_item->>'custo_liquido', '')::numeric ELSE custo_liquido END,
      valor_ipi             = CASE WHEN v_item ? 'valor_ipi' THEN NULLIF(v_item->>'valor_ipi', '')::numeric ELSE valor_ipi END,
      valor_st              = CASE WHEN v_item ? 'valor_st' THEN NULLIF(v_item->>'valor_st', '')::numeric ELSE valor_st END,
      valor_outras_despesas = CASE WHEN v_item ? 'valor_outras_despesas' THEN NULLIF(v_item->>'valor_outras_despesas', '')::numeric ELSE valor_outras_despesas END
    WHERE id = v_item_id;

    -- quantidade menor que a já ligada aos L de origem: devolve a diferença para a necessidade
    IF v_qtd IS NOT NULL THEN
      SELECT coalesce(sum(quantidade_atendida), 0) - v_qtd INTO v_sobra
        FROM public.pedido_compra_item_origem WHERE pedido_compra_item_id = v_item_id;
      IF v_sobra > 0 THEN
        FOR v_orig IN
          SELECT id, quantidade_atendida FROM public.pedido_compra_item_origem
           WHERE pedido_compra_item_id = v_item_id AND quantidade_atendida > 0
           ORDER BY criado_em DESC
        LOOP
          EXIT WHEN v_sobra <= 0;
          UPDATE public.pedido_compra_item_origem
             SET quantidade_atendida = greatest(0, v_orig.quantidade_atendida - v_sobra)
           WHERE id = v_orig.id;
          v_sobra := v_sobra - v_orig.quantidade_atendida;
        END LOOP;
      END IF;
    END IF;
  END LOOP;

  SELECT count(*) INTO v_restantes FROM public.pedido_compra_itens WHERE pedido_id = p_pedido_id;
  IF v_restantes = 0 THEN
    RAISE EXCEPTION 'O pedido precisa ficar com ao menos 1 item (para desistir dele, cancele).' USING ERRCODE = 'P0001';
  END IF;

  -- SPEC-263 C: valor final negociado. Com ele, o total do pedido e exatamente esse valor e o desconto vira so
  -- a informacao equivalente (desconto_percentual tem 2 casas); sem ele, vale o desconto % como sempre.
  SELECT coalesce(sum(quantidade * custo_unitario), 0) INTO v_bruto
    FROM public.pedido_compra_itens WHERE pedido_id = p_pedido_id;
  IF p_valor_negociado IS NOT NULL THEN
    IF p_valor_negociado <= 0 THEN
      RAISE EXCEPTION 'O valor negociado deve ser maior que zero.' USING ERRCODE = 'P0001';
    END IF;
    IF round(p_valor_negociado, 2) > round(v_bruto, 2) THEN
      RAISE EXCEPTION 'O valor negociado (R$ %) nao pode ser maior que o total do pedido sem desconto (R$ %).',
        round(p_valor_negociado, 2), round(v_bruto, 2) USING ERRCODE = 'P0001';
    END IF;
    v_total := round(p_valor_negociado, 2);
    v_desc  := CASE WHEN v_bruto > 0 THEN round((1 - v_total / v_bruto) * 100, 2) ELSE NULL END;
  ELSE
    v_desc  := NULLIF(p_desconto_percentual, 0);
    v_total := round(v_bruto * (1 - coalesce(v_desc, 0) / 100), 2);
  END IF;

  UPDATE public.pedidos_compra SET
    data_prevista_entrega = p_data_prevista_entrega,
    condicoes_pagamento   = NULLIF(trim(p_condicoes_pagamento), ''),
    observacao            = NULLIF(trim(p_observacao), ''),
    desconto_percentual   = NULLIF(v_desc, 0),
    empresa_id            = coalesce(p_empresa_id, empresa_id),
    local_entrega         = NULLIF(trim(p_local_entrega), ''),
    valor_negociado       = CASE WHEN p_valor_negociado IS NOT NULL THEN v_total END,
    valor_tabela          = round(v_bruto, 2),
    valor_total           = v_total,
    atualizado_em         = now()
  WHERE id = p_pedido_id;

  -- parcelas: refaz as não pagas com o valor e a condição novos
  IF NOT EXISTS (SELECT 1 FROM public.pedido_compra_parcelas WHERE pedido_id = p_pedido_id AND status = 'pago') THEN
    DELETE FROM public.pedido_compra_parcelas WHERE pedido_id = p_pedido_id;
    IF NULLIF(trim(p_condicoes_pagamento), '') IS NOT NULL THEN
      BEGIN
        v_parcelas := (public.gerar_parcelas_pedido_compra(p_pedido_id)->>'parcelas_criadas')::integer;
      EXCEPTION WHEN OTHERS THEN
        v_parcelas := 0;  -- condição não reconhecida: pedido salvo, parcelas ficam para fazer à mão
      END;
    END IF;
  END IF;

  RETURN jsonb_build_object('pedido_id', p_pedido_id, 'numero', v_pedido.numero, 'valor_total', v_total,
                            'parcelas_criadas', v_parcelas);
END;
$function$;

REVOKE ALL ON FUNCTION public.editar_pedido_compra(uuid, jsonb, date, text, text, numeric, uuid, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.editar_pedido_compra(uuid, jsonb, date, text, text, numeric, uuid, text, numeric) TO authenticated, service_role;

-- ===== A. ajustar ST e IPI em lote por marca =====
-- Mudanca tributaria: o percentual muda por marca. Duas etapas na mesma funcao: p_aplicar = false so MOSTRA o efeito
-- (quantas pecas, amostra antes/depois); p_aplicar = true grava. Colunas: porc_st (ST) e ipi_entrada (IPI) — as que o pedido de
-- compra usa. icms_entrada fica como esta. Por padrao so mexe em peca que JA tem o imposto (>0): nao inventa ST em peca sem ST.
-- Gravar em produtos dispara fn_atualizar_preco_venda: so muda o preco de venda de peca SEM valor_venda (custo total x 2,5);
-- a prévia diz quantas sao. Trava: mesma lista de quem ve custo (pode_ver_custo_produto) + editar em Necessidade de Compra.
CREATE OR REPLACE FUNCTION public.ajustar_impostos_marca(
  p_marca_id uuid,
  p_porc_st numeric DEFAULT NULL,
  p_ipi numeric DEFAULT NULL,
  p_somente_com_imposto boolean DEFAULT true,
  p_aplicar boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
DECLARE
  v_marca     text;
  v_total     integer;
  v_ativos    integer;
  v_alvo_st   integer;
  v_alvo_ipi  integer;
  v_afetados  integer;
  v_preco     integer;
  v_amostra   jsonb;
  v_gravados  integer := 0;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Faça login.' USING ERRCODE = '42501'; END IF;
  IF NOT public.pode_ver_custo_produto()
     OR NOT public.hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar') THEN
    RAISE EXCEPTION 'Sem permissão para alterar impostos de produtos.' USING ERRCODE = '42501';
  END IF;
  SELECT nome INTO v_marca FROM public.marcas WHERE id = p_marca_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Marca não encontrada.' USING ERRCODE = 'P0001'; END IF;
  IF p_porc_st IS NULL AND p_ipi IS NULL THEN
    RAISE EXCEPTION 'Informe o novo ST e/ou o novo IPI.' USING ERRCODE = 'P0001';
  END IF;
  IF (p_porc_st IS NOT NULL AND (p_porc_st < 0 OR p_porc_st > 100))
     OR (p_ipi IS NOT NULL AND (p_ipi < 0 OR p_ipi > 100)) THEN
    RAISE EXCEPTION 'Percentual deve estar entre 0 e 100.' USING ERRCODE = 'P0001';
  END IF;

  SELECT count(*), count(*) FILTER (WHERE ativo) INTO v_total, v_ativos FROM public.produtos WHERE marca_id = p_marca_id;

  DROP TABLE IF EXISTS _alvo_imp;
  CREATE TEMP TABLE _alvo_imp ON COMMIT DROP AS
    SELECT p.id, p.codigo_produto, p.nome, p.porc_st AS st_antes, p.ipi_entrada AS ipi_antes,
           (p_porc_st IS NOT NULL AND p.porc_st IS DISTINCT FROM p_porc_st
              AND (NOT p_somente_com_imposto OR coalesce(p.porc_st, 0) > 0)) AS muda_st,
           (p_ipi IS NOT NULL AND p.ipi_entrada IS DISTINCT FROM p_ipi
              AND (NOT p_somente_com_imposto OR coalesce(p.ipi_entrada, 0) > 0)) AS muda_ipi,
           (coalesce(p.valor_venda, 0) = 0) AS recalcula_preco
      FROM public.produtos p WHERE p.marca_id = p_marca_id;
  DELETE FROM _alvo_imp WHERE NOT (muda_st OR muda_ipi);

  SELECT count(*) FILTER (WHERE muda_st), count(*) FILTER (WHERE muda_ipi), count(*), count(*) FILTER (WHERE recalcula_preco)
    INTO v_alvo_st, v_alvo_ipi, v_afetados, v_preco FROM _alvo_imp;
  SELECT coalesce(jsonb_agg(jsonb_build_object('codigo', codigo_produto, 'nome', nome,
           'st_antes', st_antes, 'st_depois', CASE WHEN muda_st THEN p_porc_st ELSE st_antes END,
           'ipi_antes', ipi_antes, 'ipi_depois', CASE WHEN muda_ipi THEN p_ipi ELSE ipi_antes END)), '[]'::jsonb)
    INTO v_amostra FROM (SELECT * FROM _alvo_imp ORDER BY codigo_produto LIMIT 6) s;

  IF p_aplicar THEN
    UPDATE public.produtos p SET
      porc_st     = CASE WHEN a.muda_st  THEN p_porc_st ELSE p.porc_st END,
      ipi_entrada = CASE WHEN a.muda_ipi THEN p_ipi     ELSE p.ipi_entrada END
    FROM _alvo_imp a WHERE a.id = p.id;
    GET DIAGNOSTICS v_gravados = ROW_COUNT;
  END IF;

  RETURN jsonb_build_object('marca', v_marca, 'total_produtos', v_total, 'produtos_ativos', v_ativos,
    'alvo_st', v_alvo_st, 'alvo_ipi', v_alvo_ipi, 'produtos_afetados', v_afetados,
    'preco_venda_recalculado', v_preco, 'amostra', v_amostra, 'aplicado', p_aplicar, 'gravados', v_gravados);
END;
$fn$;

REVOKE ALL ON FUNCTION public.ajustar_impostos_marca(uuid, numeric, numeric, boolean, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ajustar_impostos_marca(uuid, numeric, numeric, boolean, boolean) TO authenticated;
