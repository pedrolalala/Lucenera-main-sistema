BEGIN;
ALTER TABLE public.projetos ENABLE TRIGGER trg_proteger_fechamento;
ALTER TABLE public.projetos ENABLE TRIGGER trg_fechar_projeto;
COMMIT;
