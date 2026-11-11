-- SPEC-258 Fase 4e: rollback. So ASCII. Remove as previsoes geradas (so as que nao tem baixa), o agendamento, as funcoes, a view e as colunas novas.
BEGIN;
DO $do$
BEGIN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'financeiro_recorrentes_gerar') THEN PERFORM cron.unschedule('financeiro_recorrentes_gerar'); END IF;
END $do$;
DO $do$
BEGIN
    IF EXISTS (SELECT 1 FROM public.financeiro_baixas b JOIN public.financeiro_parcelas p ON p.id = b.parcela_id JOIN public.financeiro_titulos t ON t.id = p.titulo_id WHERE t.origem_tipo = 'custo_recorrente') THEN
        RAISE EXCEPTION 'Ha baixa em parcela de custo recorrente: estorne e cancele antes do rollback.';
    END IF;
END $do$;
DELETE FROM public.financeiro_parcelas WHERE titulo_id IN (SELECT id FROM public.financeiro_titulos WHERE origem_tipo = 'custo_recorrente');
DELETE FROM public.financeiro_titulos WHERE origem_tipo = 'custo_recorrente';
DROP VIEW IF EXISTS public.vw_financeiro_recorrentes_integridade;
DROP FUNCTION IF EXISTS public.financeiro_gerar_recorrentes(integer);
DROP FUNCTION IF EXISTS public.financeiro_recorrentes_gerar_interno(integer);
DELETE FROM public.custos_recorrentes WHERE origem = 'historico';
DROP INDEX IF EXISTS public.custos_recorrentes_uq_ativo;
ALTER TABLE public.custos_recorrentes DROP CONSTRAINT IF EXISTS custos_recorrentes_perfil_check;
ALTER TABLE public.custos_recorrentes DROP CONSTRAINT IF EXISTS custos_recorrentes_origem_check;
ALTER TABLE public.custos_recorrentes DROP COLUMN IF EXISTS origem, DROP COLUMN IF EXISTS perfil, DROP COLUMN IF EXISTS plano_contas_id, DROP COLUMN IF EXISTS contato_id, DROP COLUMN IF EXISTS empresa_id;
COMMIT;
