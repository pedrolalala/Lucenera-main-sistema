-- Rollback da 260 (SPEC-240): tira a trava de quem altera Itens por caixa. Os valores gravados em multiplo_compra ficam.
BEGIN;
DROP TRIGGER IF EXISTS trg_produtos_multiplo_compra_editor ON public.produtos;
DROP FUNCTION IF EXISTS public.trg_produtos_multiplo_compra_editor();
DROP FUNCTION IF EXISTS public.pode_editar_caixa_fechada();
DROP TABLE IF EXISTS public.produto_caixa_editores;
ALTER TABLE public.produtos DROP CONSTRAINT IF EXISTS produtos_multiplo_compra_positivo;
COMMENT ON COLUMN public.produtos.multiplo_compra IS
  'Múltiplo de compra / MOQ ("caixa fechada") — pedidos devem ser arredondados para o múltiplo mais próximo deste valor. Default 1 (sem restrição). SPEC-026.';
COMMIT;
