-- Rollback da 287: remove a posição diária (tabela, função, gatilho e vista). Não toca em transações nem negociações.
BEGIN;
DROP VIEW IF EXISTS public.vw_financeiro_posicao_resumo;
DROP FUNCTION IF EXISTS public.congelar_posicao_financeira(date);
DROP TRIGGER IF EXISTS trg_financeiro_posicao_imutavel ON public.financeiro_posicao_diaria;
DROP TABLE IF EXISTS public.financeiro_posicao_diaria;
DROP FUNCTION IF EXISTS public.trg_financeiro_posicao_imutavel();
COMMIT;
