-- SPEC-320: tira o card do Hub (a migration 385 continua no banco).
BEGIN;
DELETE FROM public.user_system_access WHERE system_id IN (SELECT id FROM public.systems WHERE slug = 'escoar-reserva');
DELETE FROM public.systems WHERE slug = 'escoar-reserva';
COMMIT;
