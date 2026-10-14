-- Orçamento novo nasce e fica em RASCUNHO (pedido do usuário, 14/10).
-- handle_orcamento_workflow() estava promovendo sozinho para enviado_cliente qualquer rascunho completo, em
-- qualquer UPDATE (inclusive logo após criar). Igual à função atual, sem esse último bloco (o mesmo que a SPEC-051 tirou).
-- Rollback: rollback.sql (função como estava antes desta migration).

BEGIN;

CREATE OR REPLACE FUNCTION public.handle_orcamento_workflow()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_old_status text;
  v_skip_reset boolean := false;
  v_campos_pagamento_mudaram boolean := false;
BEGIN
  v_old_status := COALESCE(OLD.status, '');
  v_skip_reset := coalesce(current_setting('app.skip_approval_reset', true), 'false') = 'true';

  -- Mesma lista de campos de sempre (SPEC-019), extraída para uma variável
  -- só para não repetir o bloco em dois ramos.
  IF TG_OP = 'UPDATE' THEN
    v_campos_pagamento_mudaram := (
      NEW.valor_total IS DISTINCT FROM OLD.valor_total OR
      NEW.forma_pagamento IS DISTINCT FROM OLD.forma_pagamento OR
      NEW.frete_tipo IS DISTINCT FROM OLD.frete_tipo OR
      NEW.frete_valor IS DISTINCT FROM OLD.frete_valor OR
      NEW.condicoes_pagamento IS DISTINCT FROM OLD.condicoes_pagamento OR
      NEW.prazo_pagamento_dias IS DISTINCT FROM OLD.prazo_pagamento_dias OR
      NEW.desconto_global IS DISTINCT FROM OLD.desconto_global
    );
  END IF;

  -- RESET do ciclo de aprovação: SPEC-158 restringe a 'Orçamento Aprovado'.
  -- Antes incluía 'Aprovação Financeira' também, o que devolvia ao cliente
  -- uma correção feita pelo próprio financeiro.
  IF (
    TG_OP = 'UPDATE'
    AND NOT v_skip_reset
    AND v_old_status = 'Orçamento Aprovado'
    AND NEW.status = v_old_status
    AND v_campos_pagamento_mudaram
  ) THEN
    NEW.status := 'enviado_cliente';
    NEW.aprovado_cliente_em := NULL;
    NEW.aprovado_cliente_origem := NULL;
    NEW.requer_revisao_financeira := false;
    NEW.token_aprovacao_cliente := public.gen_token_hex();
    NEW.enviado_cliente_em := now();
    NEW.enviado_cliente_por := auth.uid();

    INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
    VALUES (NEW.id, v_old_status, 'enviado_cliente', auth.uid()::text,
      'Orçamento editado após aprovação — ciclo de aprovação reiniciado (cliente + financeiro)');

    RETURN NEW;
  END IF;

  -- SEM reset, só histórico: 'Aprovação Financeira' sempre (SPEC-158), e
  -- 'Orçamento Aprovado' quando o chamador pediu explicitamente para não
  -- resetar (app.skip_approval_reset, comportamento anterior preservado).
  IF (
    TG_OP = 'UPDATE'
    AND NEW.status = v_old_status
    AND v_campos_pagamento_mudaram
    AND (
      v_old_status = 'Aprovação Financeira'
      OR (v_skip_reset AND v_old_status = 'Orçamento Aprovado')
    )
  ) THEN
    INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
    VALUES (NEW.id, v_old_status, v_old_status, auth.uid()::text,
      CASE
        WHEN v_old_status = 'Aprovação Financeira'
          THEN 'Orçamento corrigido pelo financeiro durante a Aprovação Financeira — ciclo de aprovação do cliente mantido (SPEC-158)'
        ELSE 'Orçamento corrigido pelo financeiro durante a Aprovação Financeira — ciclo de aprovação do cliente mantido (não reiniciado, por escolha explícita)'
      END);

    RETURN NEW;
  END IF;

  IF (NEW.status = 'enviado_cliente' AND NEW.token_aprovacao_cliente IS NULL) THEN
    NEW.token_aprovacao_cliente := public.gen_token_hex();
    IF NEW.enviado_cliente_em IS NULL THEN
      NEW.enviado_cliente_em := now();
    END IF;
    IF NEW.enviado_cliente_por IS NULL THEN
      NEW.enviado_cliente_por := auth.uid();
    END IF;
  END IF;

  -- Achado 14/10: o bloco que promovia sozinho rascunho -> enviado_cliente
  -- (empresa + projeto + cliente + forma de pagamento + itens) tinha sido
  -- removido na SPEC-051 (migration 066) e voltou na 158, que regravou a
  -- função a partir de uma cópia antiga. Rascunho só sai de rascunho pela
  -- RPC enviar_orcamento_para_cliente (botão "Enviar para o Cliente").

  RETURN NEW;
END;
$function$

;
;

COMMIT;
