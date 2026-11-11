BEGIN;
DROP TRIGGER IF EXISTS trg_produto_preco_historico ON public.produtos;
DROP FUNCTION IF EXISTS public.fn_produto_preco_historico();
DROP TABLE IF EXISTS public.produto_preco_historico;
-- reajuste_aplicar / reajuste_desfazer: reaplicar a migration 333 para voltar a versao sem a origem
COMMIT;
