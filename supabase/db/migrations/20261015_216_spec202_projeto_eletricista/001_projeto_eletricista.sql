-- SPEC-202: eletricista vinculado ao projeto (contato tipo eletricista, migration 214).
BEGIN;
ALTER TABLE public.projetos ADD COLUMN IF NOT EXISTS eletricista_id uuid
  REFERENCES public.contatos(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_projetos_eletricista_id ON public.projetos(eletricista_id);
COMMIT;
