-- SPEC-281: dry-run da migration 332 (ROLLBACK).
\set ON_ERROR_STOP on
BEGIN;
\ir up.sql
SELECT has_function_privilege('anon', 'public.replace_orcamento_itens(uuid,jsonb)', 'execute') AS anon_executa;
SELECT has_function_privilege('authenticated', 'public.replace_orcamento_itens(uuid,jsonb)', 'execute') AS authenticated_executa;
-- Ensaio sugerido (ainda dentro da transacao, como service_role):
--  1) chamar replace_orcamento_itens no CNX-5154 com os mesmos itens -> nada muda (conjunto identico);
--  2) chamar sem o item sem produto (LUC91) -> deve dar a mensagem clara de item ligado a venda, sem alterar nada;
--  3) num orcamento rascunho sem venda: remover/adicionar item -> funciona e mantem o id dos demais.
ROLLBACK;
