-- SPEC-284 Parte B rollback: volta o gatilho como era (INSERT ou UPDATE de estoque_total/estoque_disponivel).
BEGIN;

DROP TRIGGER IF EXISTS trg_sync_estoque_itens_from_produtos ON public.produtos;

CREATE TRIGGER trg_sync_estoque_itens_from_produtos
  AFTER INSERT OR UPDATE OF estoque_total, estoque_disponivel ON public.produtos
  FOR EACH ROW EXECUTE FUNCTION public.fn_sync_estoque_itens_from_produtos();

COMMIT;
