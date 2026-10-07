-- SPEC-157 (2026-09-22): importar_pedido_compra.py passa a marcar como
-- "não vigente" o pedido que sai do export Connect atual, em vez de deixar
-- o registro parado sem sinalização nenhuma. PROIBIDO apagar fisicamente
-- (a planilha PedidoCompra só traz o vigente, não é histórico -- decisão
-- registrada no próprio script desde 2026-07-22).
--
-- RASCUNHO -- NÃO aplicar sem execução manual do usuário.

BEGIN;

ALTER TABLE public.pedido_compra
    ADD COLUMN IF NOT EXISTS vigente boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN public.pedido_compra.vigente IS
    'true = presente na última exportação PedidoCompra_*.xlsx processada. '
    'false = saiu do export (Connect não reconhece mais como pedido vigente) '
    '-- NUNCA apagado fisicamente, a planilha não traz histórico.';

COMMIT;
