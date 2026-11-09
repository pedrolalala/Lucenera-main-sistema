BEGIN;
ALTER FUNCTION public.fn_sync_estoque_itens_from_produtos() SECURITY INVOKER;
COMMIT;
