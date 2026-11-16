-- SPEC-284 Parte B: o gatilho trg_sync_estoque_itens_from_produtos deixa de copiar produtos.estoque_* para o
-- estoque real em UPDATE (importar_produtos_estoque.py --incluir-estoque ou edição manual sobrescreviam entradas
-- de nota, reservas e ajustes). Continua só no INSERT: peça nova ganha a linha 'Estoque' em estoque_itens.
-- A função fn_sync_estoque_itens_from_produtos não muda.
BEGIN;

DROP TRIGGER IF EXISTS trg_sync_estoque_itens_from_produtos ON public.produtos;

CREATE TRIGGER trg_sync_estoque_itens_from_produtos
  AFTER INSERT ON public.produtos
  FOR EACH ROW EXECUTE FUNCTION public.fn_sync_estoque_itens_from_produtos();

COMMENT ON TRIGGER trg_sync_estoque_itens_from_produtos ON public.produtos IS
  'SPEC-284 B (11/11/2026): só no INSERT (cria a linha Estoque da peça nova). Em UPDATE não copia mais produtos.estoque_* para estoque_itens.';

COMMIT;
