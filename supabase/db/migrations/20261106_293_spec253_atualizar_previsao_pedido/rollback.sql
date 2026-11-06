-- SPEC-253 C: remove a função de atualizar previsão do pedido.
DROP FUNCTION IF EXISTS public.atualizar_previsao_pedido_compra(uuid, date, text);
