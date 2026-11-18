-- SPEC-320: remove o sistema de escoamento. ATENCAO: nao desfaz os movimentos de estoque ja lancados (estorne os lotes antes).
BEGIN;
DROP FUNCTION IF EXISTS public.escoar_reserva_estornar(uuid, text);
DROP FUNCTION IF EXISTS public.escoar_reserva_historico(integer);
DROP FUNCTION IF EXISTS public.escoar_reserva_lancar(text, text, date, jsonb, boolean);
DROP FUNCTION IF EXISTS public.escoar_reserva_pecas(text, boolean);
DROP FUNCTION IF EXISTS public.pode_escoar_reserva_connect();
DROP TABLE IF EXISTS public.escoar_reserva_itens;
DROP TABLE IF EXISTS public.escoar_reserva_lotes;
DROP TABLE IF EXISTS public.escoar_reserva_operadores;
COMMIT;
