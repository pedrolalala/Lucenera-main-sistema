-- SPEC-285 rollback: remove a trava de parcela manual (volta a valer só trg_proteger_parcelas).
BEGIN;
DROP TRIGGER IF EXISTS trg_bloquear_parcela_manual ON public.projeto_parcelas;
DROP FUNCTION IF EXISTS public.bloquear_parcela_manual();
COMMIT;
