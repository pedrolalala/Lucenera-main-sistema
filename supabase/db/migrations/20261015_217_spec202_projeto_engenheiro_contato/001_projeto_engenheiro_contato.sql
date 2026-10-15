-- SPEC-202 D: engenheiro do projeto = contato tipo engenheiro.
-- responsavel_obra_id continua com FK para usuarios porque a sincronizacao
-- SharePoint (pull/push) depende dele; as telas gravavam contato ali e
-- quebravam com projetos_responsavel_obra_id_fkey. 0 projetos tinham o campo.
BEGIN;
ALTER TABLE public.projetos ADD COLUMN IF NOT EXISTS engenheiro_id uuid
  REFERENCES public.contatos(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_projetos_engenheiro_id ON public.projetos(engenheiro_id);
COMMIT;
