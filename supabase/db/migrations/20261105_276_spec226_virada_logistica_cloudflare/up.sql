-- SPEC-226 — virada da Logística: o card "Sistema de Entregas" da Central deixa o Lovable e abre o sistema novo na Cloudflare.
-- O histórico do Lovable NÃO migra; o sistema antigo segue no ar só para consulta (https://lucenera.lovable.app/separacao).
BEGIN;
UPDATE public.systems
   SET link = 'https://logistica-lucenera.pages.dev'
 WHERE slug = 'logistica' AND link = 'https://lucenera.lovable.app/separacao';
DO $$ BEGIN
  IF (SELECT link FROM public.systems WHERE slug = 'logistica') <> 'https://logistica-lucenera.pages.dev' THEN
    RAISE EXCEPTION 'O link da Logística não foi trocado (já estava diferente do esperado).';
  END IF;
END $$;
COMMIT;
