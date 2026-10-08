-- Rollback da 20261008_192 (os vínculos de período feitos pelo UPDATE não são desfeitos).
DROP TRIGGER IF EXISTS trg_ferias_definir_periodo ON public.ferias;
DROP FUNCTION IF EXISTS public.ferias_definir_periodo();
ALTER VIEW public.vw_ferias_periodos SET (security_invoker = false);
ALTER VIEW public.vw_controle_ferias_clt SET (security_invoker = false);
GRANT ALL ON public.vw_controle_ferias_clt TO anon;
NOTIFY pgrst, 'reload schema';
