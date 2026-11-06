-- SPEC-255: dry-run da migration 296 (ROLLBACK).
\set ON_ERROR_STOP on
BEGIN;
SELECT count(*) AS linhas_antes FROM vw_venda_parcial_lista;
\ir up.sql
SELECT count(*) AS linhas_depois FROM vw_venda_parcial_lista;
SELECT natureza_operacao, subgrupo, count(*) FROM vw_venda_parcial_lista GROUP BY 1,2 ORDER BY 3 DESC;
SELECT has_table_privilege('anon','public.vw_venda_parcial_lista','select') AS anon_le, has_table_privilege('authenticated','public.vw_venda_parcial_lista','select') AS auth_le;
SELECT reloptions FROM pg_class WHERE relname='vw_venda_parcial_lista';
ROLLBACK;
