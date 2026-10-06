-- Rollback da 20261006_185.
DROP VIEW IF EXISTS public.vw_cadastro_produto_movimentos;
-- vw_necessidade_compra_pedido_detalhe: as colunas data_emissao/perfil ficam
-- (colunas extras no fim não atrapalham quem lê só as antigas); para tirar,
-- DROP VIEW + recriar com a definição anterior (sem as duas últimas colunas).
NOTIFY pgrst, 'reload schema';
