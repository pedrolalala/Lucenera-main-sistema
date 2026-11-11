-- SPEC-280: dry-run da migration 331 (ROLLBACK).
\set ON_ERROR_STOP on
BEGIN;
\ir up.sql
SELECT has_function_privilege('anon', 'public.reserva_dados_vendas(uuid[])', 'execute') AS anon_executa;
SELECT has_function_privilege('authenticated', 'public.reserva_dados_vendas(uuid[])', 'execute') AS authenticated_executa;
SELECT count(*) AS linhas_sem_login FROM public.reserva_dados_vendas(ARRAY(SELECT id FROM public.orcamentos LIMIT 5));
ROLLBACK;
