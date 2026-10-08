-- Rollback da 20261008_189 (o UPDATE das pendentes não volta sozinho: em 08/10 era 1 registro,
-- Isabella Miguel Jacob, 07/09–11/09/2026).
ALTER TABLE public.ferias ALTER COLUMN status SET DEFAULT 'Pendente';
