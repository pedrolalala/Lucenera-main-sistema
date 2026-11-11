-- SPEC-279: dry-run da migration 329 (ROLLBACK).
\set ON_ERROR_STOP on
BEGIN;
SELECT count(*) AS linhas_antes FROM vw_venda_parcial_lista;
\ir up.sql
SELECT count(*) AS linhas_depois FROM vw_venda_parcial_lista;
SELECT orcamento_numero, natureza_operacao, subgrupo, q_venda, q_entregue FROM vw_venda_parcial_lista WHERE subgrupo IN ('USO E CONSUMO','DESCARTE');
SELECT position('_aprovar_operacao_sem_financeiro' IN pg_get_functiondef('public.equipe_aprovar_orcamento(uuid,text)'::regprocedure)) AS chamada_automatica_restante;
SELECT has_table_privilege('anon','public.vw_venda_parcial_lista','select') AS anon_le;
SELECT reloptions FROM pg_class WHERE relname='vw_venda_parcial_lista';
ROLLBACK;
