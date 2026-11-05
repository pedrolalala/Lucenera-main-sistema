-- Rollback da 268: remove a view de lista. A tela da Venda Parcial antiga (que lê vw_estoque_saldos_projeto_item) volta a funcionar sozinha.
BEGIN;
DROP VIEW IF EXISTS public.vw_venda_parcial_lista;
COMMIT;
