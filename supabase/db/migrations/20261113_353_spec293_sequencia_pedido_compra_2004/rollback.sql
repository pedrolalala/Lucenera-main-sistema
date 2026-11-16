-- Volta a sequencia para o maior numero puramente numerico existente (nunca abaixo dele).
BEGIN;
SELECT setval('public.pedidos_compra_numero_seq',
              GREATEST(COALESCE((SELECT max(numero::bigint) FROM public.pedidos_compra WHERE numero ~ '^[0-9]{1,9}$'), 1), 1), true);
COMMIT;
