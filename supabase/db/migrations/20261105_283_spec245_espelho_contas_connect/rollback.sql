-- Rollback da 283: apaga o espelho e as duas colunas de nome (os nomes voltam a vir só do cadastro de contatos).
BEGIN;
DROP TABLE IF EXISTS public.connect_contas_espelho;
ALTER TABLE public.negociacoes DROP COLUMN IF EXISTS nome_pessoa, DROP COLUMN IF EXISTS razao_pessoa;
COMMIT;
