-- SPEC-258 Fase 3 passo 1: remove a view nova e as duas colunas copiadas (a view antiga nunca foi tocada).
DROP VIEW IF EXISTS public.v_financeiro_realizado_novo;
ALTER TABLE public.financeiro_parcelas DROP COLUMN IF EXISTS descricao;
ALTER TABLE public.financeiro_parcelas DROP COLUMN IF EXISTS desconto;
ALTER TABLE public.financeiro_parcelas DROP COLUMN IF EXISTS emissao;
