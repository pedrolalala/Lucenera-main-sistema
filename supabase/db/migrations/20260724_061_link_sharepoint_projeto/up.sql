-- SPEC-045: link da pasta raiz do projeto no SharePoint (preenchido manualmente
-- pelo usuário no CRM, sem sincronização automática). Coluna aditiva, sem
-- impacto em dado ou query existente.

ALTER TABLE public.projetos
  ADD COLUMN IF NOT EXISTS link_sharepoint text;

COMMENT ON COLUMN public.projetos.link_sharepoint IS
  'Link da pasta raiz do projeto no SharePoint (contém subpastas padrão: WhatsApp, Projetos, Originais, Orçamentos, Fotos, Email, DocuSign). Preenchido manualmente pelo usuário no CRM — não é sincronizado automaticamente.';
