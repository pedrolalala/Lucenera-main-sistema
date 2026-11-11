BEGIN;
DROP FUNCTION IF EXISTS public.orcamento_regra_salvar(text, jsonb);
DROP FUNCTION IF EXISTS public.pode_editar_regras_orcamento();
DROP TABLE IF EXISTS public.orcamento_regras;
COMMIT;
