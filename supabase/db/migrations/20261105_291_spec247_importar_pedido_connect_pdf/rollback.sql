-- SPEC-247 fase 2: desfaz a migration 291 (so remove a funcao).
DROP FUNCTION IF EXISTS public.importar_pedido_connect_pdf(jsonb, boolean);

-- Pedidos/itens ja gravados NAO saem sozinhos. Para desfazer os itens importados pelo PDF (conferir antes):
--   SELECT numero FROM public.pedidos_compra WHERE observacao LIKE 'Importado da Connect (PDF do pedido)%';
--   Pedido CRIADO pelo PDF: DELETE FROM public.pedidos_compra WHERE observacao LIKE 'Importado da Connect (PDF do pedido)%'
--     AND NOT EXISTS (SELECT 1 FROM public.notas_fiscais_compra n WHERE n.pedido_compra_id = pedidos_compra.id);  -- itens saem em cascata
--   Pedido COMPLETADO (veio da planilha): apagar so os itens dele, sem nota ligada:
--     DELETE FROM public.pedido_compra_itens WHERE pedido_id = '<id>' AND NOT EXISTS
--       (SELECT 1 FROM public.nota_fiscal_compra_itens n WHERE n.pedido_item_id = pedido_compra_itens.id);
