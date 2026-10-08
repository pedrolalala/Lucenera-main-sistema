-- Rollback da 20261008_191. Dados: restaurar de _bkp_ferias_20261008 / _bkp_periodos_aquisitivos_20261008 (feitos pelo import).
SELECT cron.unschedule('ferias-gerar-periodos');
DROP FUNCTION IF EXISTS public.gerar_periodos_aquisitivos();
DROP VIEW IF EXISTS public.vw_controle_ferias_clt;
DROP VIEW IF EXISTS public.vw_ferias_periodos;
DROP TABLE IF EXISTS public.ferias_lancamentos;
ALTER TABLE public.periodos_aquisitivos DROP COLUMN IF EXISTS direito_dias, DROP COLUMN IF EXISTS formalizacao;
-- recriar vw_controle_ferias_clt com 20261008_190_saldo_ferias_ultimo_periodo/001_vw_controle_ferias_clt.sql
NOTIFY pgrst, 'reload schema';
