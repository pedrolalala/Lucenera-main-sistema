-- SPEC-225 rollback: volta a ter só o card "Administração Bancária".
BEGIN;
DROP TRIGGER IF EXISTS trg_espelhar_acesso_financeiro ON public.user_system_access;
DROP FUNCTION IF EXISTS public.espelhar_acesso_financeiro();
-- ON DELETE CASCADE apaga os acessos dos 2 cards (o de 'financeiro' fica)
DELETE FROM public.systems WHERE slug IN ('contas-pagar', 'contas-receber');
UPDATE public.systems SET visivel_no_hub = true WHERE slug = 'financeiro';
COMMIT;
