-- SPEC-258 Fase 4c (parte 1): remove a view e as funcoes da tela de RT. As regras ja gravadas em financeiro_regras_repasse ficam (nao apaga dado).
DROP VIEW IF EXISTS public.vw_financeiro_rt_arquitetos;
DROP FUNCTION IF EXISTS public.financeiro_definir_rt_lote(jsonb);
DROP FUNCTION IF EXISTS public.financeiro_definir_rt(uuid, numeric, text, text, integer, boolean, text);
