-- SPEC-189 (08/10/2026): registro dos erros de tela capturados pelo ErrorBoundary dos sistemas
-- (a Lana viu "Algo deu errado nesta tela" e não havia como saber a causa).
-- Qualquer usuário logado grava; só admin lê. Sem BEGIN/COMMIT no texto.
CREATE TABLE IF NOT EXISTS public.erros_tela (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sistema text NOT NULL,
  usuario_id uuid DEFAULT auth.uid(),
  mensagem text,
  detalhe text,
  url text,
  navegador text,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.erros_tela ENABLE ROW LEVEL SECURITY;
CREATE POLICY erros_tela_insert ON public.erros_tela FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY erros_tela_select ON public.erros_tela FOR SELECT TO authenticated USING (get_user_role() = 'admin');
GRANT INSERT, SELECT ON public.erros_tela TO authenticated;
NOTIFY pgrst, 'reload schema';
