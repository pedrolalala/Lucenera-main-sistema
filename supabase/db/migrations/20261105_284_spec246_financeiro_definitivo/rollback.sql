-- Rollback da 284: remove marco, gatilho, índice único, mapas e a view. Não toca em transações nem negociações.
BEGIN;
DROP VIEW IF EXISTS public.vw_financeiro_integridade;
DROP TABLE IF EXISTS public.vendas_connect;
DROP TABLE IF EXISTS public.contato_legado_ids;
DROP INDEX IF EXISTS public.uq_transacoes_tipo_cod_ativa;
DROP TRIGGER IF EXISTS trg_transacoes_legado_imutavel ON public.transacoes;
DROP FUNCTION IF EXISTS public.trg_transacoes_legado_imutavel();
DROP TABLE IF EXISTS public.connect_financeiro_encerrado;
COMMIT;
