-- Rollback da SPEC-312 (migration 372): remove o gatilho. Acordos ja cancelados e reabertos nao sao desfeitos.
BEGIN;
DROP TRIGGER IF EXISTS trg_financeiro_acordo_cancelado ON public.financeiro_parcelas;
DROP FUNCTION IF EXISTS public.financeiro_acordo_cancelado_reabre_originais();
COMMIT;
