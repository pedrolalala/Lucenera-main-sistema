-- SPEC-322 rollback (só se nenhuma compensação foi gravada; senão a coluna compensacao_id perde o vínculo).
BEGIN;
DROP FUNCTION IF EXISTS public.financeiro_compensar_nova_conta(uuid, numeric, numeric, uuid, text, text, date, text, date);
DROP FUNCTION IF EXISTS public.financeiro_cadastrar_conta_manual(jsonb, jsonb);
DROP FUNCTION IF EXISTS public.financeiro_estornar_compensacao(uuid, text);
DROP FUNCTION IF EXISTS public.financeiro_compensar(uuid, uuid, numeric, text, date);
DROP FUNCTION IF EXISTS public.financeiro_compensacao_candidatas(uuid);
DROP INDEX IF EXISTS public.financeiro_baixas_compensacao_idx;
ALTER TABLE public.financeiro_baixas DROP COLUMN IF EXISTS compensacao_id;
COMMIT;
