-- Rollback da migration 212: devolve handle_orcamento_workflow() como estava (com a promoção automática).
CREATE OR REPLACE FUNCTION public.handle_orcamento_workflow()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_old_status text;
  v_has_items boolean := false;
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

  IF (NEW.status IN ('rascunho', 'aguardando_cliente', 'aguardando_aprovacao') OR NEW.status IS NULL) THEN
    IF NEW.empresa_id IS NOT NULL
       AND NEW.projeto_id IS NOT NULL
       AND NEW.cliente_id IS NOT NULL
       AND NEW.forma_pagamento IS NOT NULL THEN
      SELECT EXISTS(
        SELECT 1 FROM public.orcamento_itens WHERE orcamento_id = NEW.id
      ) INTO v_has_items;
      IF v_has_items THEN
        NEW.status := 'enviado_cliente';
        NEW.token_aprovacao_cliente := public.gen_token_hex();
        NEW.enviado_cliente_em := COALESCE(NEW.enviado_cliente_em, now());
        NEW.enviado_cliente_por := COALESCE(NEW.enviado_cliente_por, auth.uid());
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$

;
