-- Migration 20260630_012 — Parte 1
-- Adiciona coluna equipe_id em projetos e a liga a equipes_projetos.
--
-- responsavel_obra_id já existe mas aponta para contatos.id (pessoa física).
-- equipe_id é uma coluna nova que aponta para a equipe responsável pelo projeto,
-- permitindo calcular comissão por funcionário vinculado àquela equipe.

ALTER TABLE public.projetos
  ADD COLUMN IF NOT EXISTS equipe_id uuid NULL
    REFERENCES public.equipes_projetos (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_projetos_equipe_id
  ON public.projetos USING btree (equipe_id);
