-- Desfaz a migration 219 (SPEC-204). Apaga as notas da Connect importadas.
BEGIN;
DROP TABLE IF EXISTS public.notas_fiscais_connect_eventos;
DROP TABLE IF EXISTS public.notas_fiscais_connect_duplicatas;
DROP TABLE IF EXISTS public.notas_fiscais_connect_itens;
DROP TABLE IF EXISTS public.notas_fiscais_connect;
COMMIT;
