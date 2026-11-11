-- Volta editar_pedido_compra para a versao de 8 parametros (SPEC-209/213) — conteudo em 20261108_313.../versao_anterior_editar_pedido_compra.sql —
-- e remove a funcao de impostos por marca. Colunas valor_negociado/valor_tabela ficam (nulas nao atrapalham); itens ja incluidos ficam no pedido.
DROP FUNCTION IF EXISTS public.ajustar_impostos_marca(uuid, numeric, numeric, boolean, boolean);
DROP FUNCTION IF EXISTS public.editar_pedido_compra(uuid, jsonb, date, text, text, numeric, uuid, text, numeric);

-- Versao de 8 parametros que estava em producao antes da SPEC-263 (para rollback).
CREATE OR REPLACE FUNCTION public.editar_pedido_compra(p_pedido_id uuid, p_itens jsonb DEFAULT '[]'::jsonb, p_data_prevista_entrega date DEFAULT NULL::date, p_condicoes_pagamento text DEFAULT NULL::text, p_observacao text DEFAULT NULL::text, p_desconto_percentual numeric DEFAULT NULL::numeric, p_empresa_id uuid DEFAULT NULL::uuid, p_local_entrega text DEFAULT NULL::text)
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

  UPDATE public.pedidos_compra SET
    data_prevista_entrega = p_data_prevista_entrega,
    condicoes_pagamento   = NULLIF(trim(p_condicoes_pagamento), ''),
    observacao            = NULLIF(trim(p_observacao), ''),
    desconto_percentual   = NULLIF(p_desconto_percentual, 0),
    empresa_id            = coalesce(p_empresa_id, empresa_id),
    local_entrega         = NULLIF(trim(p_local_entrega), ''),
    atualizado_em         = now()
  WHERE id = p_pedido_id;

  SELECT round(sum(quantidade * custo_unitario) * (1 - coalesce(NULLIF(p_desconto_percentual, 0), 0) / 100), 2)
    INTO v_total FROM public.pedido_compra_itens WHERE pedido_id = p_pedido_id;
  UPDATE public.pedidos_compra SET valor_total = v_total WHERE id = p_pedido_id;

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
$function$
;
GRANT EXECUTE ON FUNCTION public.editar_pedido_compra(uuid,jsonb,date,text,text,numeric,uuid,text) TO authenticated, service_role;
