-- Migration 20260723_061 - Remove projetos.client_id (coluna morta duplicada de cliente_id)
-- Parte 2/2: remove o indice, a foreign key e a propria coluna, ja com as 10 views (001) migradas para cliente_id.

DROP INDEX IF EXISTS public.idx_projetos_client_id;

ALTER TABLE public.projetos DROP CONSTRAINT IF EXISTS projetos_client_id_fkey;

ALTER TABLE public.projetos DROP COLUMN IF EXISTS client_id;
