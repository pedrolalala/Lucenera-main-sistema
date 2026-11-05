-- SPEC-247: desfaz a migration 290 (so remove a funcao).
DROP FUNCTION IF EXISTS public.importar_pedidos_connect_cabecalho(jsonb, boolean);

-- Pedidos ja gravados NAO saem sozinhos. Para apagar os importados pela tela (sem itens nem notas ligadas),
-- conferir antes com SELECT e so entao rodar:
--   SELECT numero, valor_total FROM public.pedidos_compra WHERE observacao LIKE 'Importado da Connect (planilha)%';
--   DELETE FROM public.pedidos_compra WHERE observacao LIKE 'Importado da Connect (planilha)%'
--     AND NOT EXISTS (SELECT 1 FROM public.notas_fiscais_compra n WHERE n.pedido_compra_id = pedidos_compra.id);
