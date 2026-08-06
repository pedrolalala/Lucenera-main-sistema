-- SPEC-051 — Fase explícita de Rascunho antes do envio ao cliente
--
-- Hoje, `handle_orcamento_workflow()` promove automaticamente um orçamento
-- de `rascunho`/`aguardando_cliente`/`aguardando_aprovacao`/NULL para
-- `enviado_cliente` assim que `empresa_id`, `projeto_id`, `cliente_id` e
-- `forma_pagamento` estão preenchidos e já existe pelo menos 1 item — sem
-- nenhuma ação explícita do usuário.
--
-- Esta migration remove esse bloco final da função (mantendo os dois
-- blocos anteriores, que pertencem ao reset pós-aprovação da SPEC-019 e
-- não mudam). A transição rascunho -> enviado_cliente passa a acontecer
-- somente via RPC `enviar_orcamento_para_cliente`, chamada por ação
-- explícita do usuário na UI.

CREATE OR REPLACE FUNCTION public.handle_orcamento_workflow()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_old_status text;
BEGIN
  v_old_status := COALESCE(OLD.status, '');

  -- Auto-generate token when status is enviado_cliente and no token exists
  IF (NEW.status = 'enviado_cliente' AND NEW.token_aprovacao_cliente IS NULL) THEN
    NEW.token_aprovacao_cliente := public.gen_token_hex();
    IF NEW.enviado_cliente_em IS NULL THEN
      NEW.enviado_cliente_em := now();
    END IF;
    IF NEW.enviado_cliente_por IS NULL THEN
      NEW.enviado_cliente_por := auth.uid();
    END IF;
  END IF;

  -- When customer approves (transition to Aprovação Financeira from enviado_cliente),
  -- set financial review flag and approval timestamp
  IF (NEW.status = 'Aprovação Financeira' AND v_old_status = 'enviado_cliente') THEN
    NEW.requer_revisao_financeira := true;
    IF NEW.aprovado_cliente_em IS NULL THEN
      NEW.aprovado_cliente_em := now();
    END IF;
  END IF;

  -- SPEC-051: bloco de auto-transição de rascunho/aguardando_cliente/
  -- aguardando_aprovacao para enviado_cliente REMOVIDO. A partir de agora,
  -- essa transição só acontece por ação explícita do usuário via RPC
  -- public.enviar_orcamento_para_cliente(p_orcamento_id).

  RETURN NEW;
END;
$function$
;

COMMENT ON FUNCTION public.handle_orcamento_workflow() IS
  'SPEC-051 (27/07/2026): removida a auto-transição de rascunho/aguardando_cliente/aguardando_aprovacao para enviado_cliente. Mantido apenas o reset pós-aprovação da SPEC-019 e a geração de token quando o status já chega como enviado_cliente.';
