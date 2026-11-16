-- SPEC-293 (reuniao 55, 13/11/2026): o proximo pedido de compra automatico deve ser 2004 (a Connect ja emitiu ate 2003).
-- Sobe a sequencia para 2003 (nextval devolve 2004). Nunca retrocede.
BEGIN;
SELECT setval('public.pedidos_compra_numero_seq',
              GREATEST((SELECT last_value FROM public.pedidos_compra_numero_seq), 2003), true);
COMMIT;
