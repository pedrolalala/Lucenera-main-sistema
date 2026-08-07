-- SPEC-068 (2.2): desconto global aceita percentual OU valor fechado em R$
-- (com cálculo automático entre os dois no frontend), e novo campo Sinal
-- (valor fixo em R$, informativo no documento do orçamento para o cliente,
-- não gera parcela financeira nem afeta a aprovação).
--
-- desconto_global (já existente) continua guardando o número digitado
-- (10 para "10%" OU 150 para "R$150,00"); desconto_tipo define como
-- interpretá-lo. Default 'percentual' preserva o comportamento atual para
-- todo orçamento já existente.

ALTER TABLE public.orcamentos
  ADD COLUMN IF NOT EXISTS desconto_tipo text NOT NULL DEFAULT 'percentual'
    CHECK (desconto_tipo IN ('percentual', 'valor')),
  ADD COLUMN IF NOT EXISTS valor_sinal numeric(12,2) NOT NULL DEFAULT 0
    CHECK (valor_sinal >= 0);

COMMENT ON COLUMN public.orcamentos.desconto_tipo IS
  'SPEC-068: como interpretar desconto_global — percentual (%) ou valor fechado em R$.';
COMMENT ON COLUMN public.orcamentos.valor_sinal IS
  'SPEC-068: sinal em R$, exibido no documento do orçamento para o cliente. Informativo — não gera parcela em projeto_parcelas nem afeta aprovação financeira.';

-- Atualiza a RPC pública consumida pela tela de aprovação do cliente
-- (ClientApproval.tsx, chamada por token/link) para expor desconto e sinal.
CREATE OR REPLACE FUNCTION public.buscar_orcamento_para_aprovacao(p_orcamento_id uuid, p_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_orcamento public.orcamentos%ROWTYPE;
  v_cliente_nome text;
  v_subtotal numeric;
  v_desconto_valor numeric;
  v_valor_liquido numeric;
BEGIN
  SELECT * INTO v_orcamento FROM public.orcamentos WHERE id = p_orcamento_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento não encontrado.' USING ERRCODE = 'P0001';
  END IF;

  IF v_orcamento.status NOT IN ('recusado_cliente', 'Aprovação Financeira', 'Orçamento Aprovado')
     AND (v_orcamento.token_aprovacao_cliente IS NULL OR v_orcamento.token_aprovacao_cliente != p_token) THEN
    RAISE EXCEPTION 'Token inválido ou expirado.' USING ERRCODE = 'P0001';
  END IF;

  SELECT nome INTO v_cliente_nome FROM public.contatos WHERE id = v_orcamento.cliente_id;

  SELECT COALESCE(SUM(quantidade * preco_unitario * (1 - COALESCE(desconto, 0) / 100)), 0)
    INTO v_subtotal
    FROM public.orcamento_itens
    WHERE orcamento_id = v_orcamento.id;

  v_desconto_valor := CASE
    WHEN v_orcamento.desconto_tipo = 'valor'
      THEN LEAST(GREATEST(COALESCE(v_orcamento.desconto_global, 0), 0), v_subtotal)
    ELSE v_subtotal * (LEAST(COALESCE(v_orcamento.desconto_global, 0), 100) / 100)
  END;
  v_valor_liquido := v_subtotal - v_desconto_valor;

  RETURN jsonb_build_object(
    'orcamento_id', v_orcamento.id,
    'numero', v_orcamento.numero,
    'valor_total', v_orcamento.valor_total,
    'data_emissao', v_orcamento.data_emissao,
    'cliente_nome', v_cliente_nome,
    'status', v_orcamento.status,
    'condicoes_pagamento', v_orcamento.condicoes_pagamento,
    'forma_pagamento', v_orcamento.forma_pagamento,
    'subtotal_itens', v_subtotal,
    'desconto_tipo', v_orcamento.desconto_tipo,
    'desconto_global', v_orcamento.desconto_global,
    'desconto_valor', v_desconto_valor,
    'valor_sinal', v_orcamento.valor_sinal,
    'saldo_restante_apos_sinal', v_orcamento.valor_total - COALESCE(v_orcamento.valor_sinal, 0)
  );
END;
$function$;
