BEGIN;
DROP FUNCTION IF EXISTS public.financeiro_editar_conta(uuid, jsonb, jsonb, text);
DROP FUNCTION IF EXISTS public.financeiro_conta_para_edicao(uuid);
COMMIT;
