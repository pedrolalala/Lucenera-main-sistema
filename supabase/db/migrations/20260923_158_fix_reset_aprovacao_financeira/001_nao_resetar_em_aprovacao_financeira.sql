-- SPEC-158 (P1.1): orçamento em "Aprovação Financeira" não volta mais para
-- "Aprovação do Cliente" quando o financeiro corrige um campo de pagamento.
--
-- Reproduzido ao vivo na reunião de 22/09/2026: com o orçamento em Aprovação
-- Financeira, mudar a data de pagamento devolvia o orçamento para
-- 'enviado_cliente'. Causa: mudar a data altera `prazo_pagamento_dias` (o
-- frontend converte cada vencimento calendário em offset de dias), e
-- `prazo_pagamento_dias` está na lista de campos que disparam o reset do
-- ciclo de aprovação em handle_orcamento_workflow() (regra originada na
-- SPEC-019). Achado do revisor (2026-09-23): a versão viva em produção já
-- diverge do histórico de migrations commitado neste ponto (o bloco de
-- reset/v_skip_reset não aparece em nenhuma migration rastreável, incluindo
-- a SPEC-135, que só mexeu em replace_orcamento_itens/
-- aprovar_orcamento_financeiro) -- drift pré-existente, não introduzido
-- nem corrigido por esta migration, que preserva fielmente o comportamento
-- atual de produção fora das duas condições descritas abaixo.
--
-- Decisão do usuário (Vinícius, 22/09/2026): "toda vez que tiver em revisão
-- financeira não é para voltar" -- quando o orçamento chega em Aprovação
-- Financeira a responsabilidade das vendedoras já terminou; dali em diante é
-- do financeiro, e uma correção do financeiro não pode reiniciar o ciclo com
-- o cliente.
--
-- Único ajuste desta migration: o ramo que RESETA passa a valer só para
-- 'Orçamento Aprovado' (orçamento já fechado sendo de fato alterado — cenário
-- diferente, não foi pedido para mudar). 'Aprovação Financeira' passa a cair
-- sempre no ramo que só registra em historico_status_orcamentos sem tocar no
-- status -- ramo que já existia para o caso `app.skip_approval_reset = true`.
--
-- Corpo idêntico ao da função viva em produção (lido via pg_get_functiondef
-- em 2026-09-23) fora essas duas condições. CREATE OR REPLACE, mesma
-- assinatura (trigger function, sem argumentos), não mexe em grants.

BEGIN;

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
$function$;

COMMENT ON FUNCTION public.handle_orcamento_workflow() IS
  'SPEC-019/158. Reset do ciclo de aprovação ao editar campos de pagamento vale SÓ para "Orçamento Aprovado" — orçamento em "Aprovação Financeira" mantém o status (correção do financeiro não devolve ao cliente, decisão do usuário 22/09/2026), registrando a alteração em historico_status_orcamentos.';

NOTIFY pgrst, 'reload schema';

COMMIT;
