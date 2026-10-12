-- Rollback da 202 (SPEC-193 C2 parte 1). Só rodar se a 203 (fechamento) NÃO estiver aplicada,
-- ou depois do rollback da 203.
DROP VIEW IF EXISTS public.vw_produtos_custo;
ALTER TABLE public.produtos DROP COLUMN IF EXISTS tem_st;
DROP FUNCTION IF EXISTS public.pode_ver_custo_produto();
DROP TABLE IF EXISTS public.produto_custo_visualizadores;
