-- Volta às políticas abertas de antes (qualquer usuário logado vê todos os orçamentos).
BEGIN;
DROP POLICY IF EXISTS orcamentos_ubiqua_do_representante ON public.orcamentos_revenda_ubiqua;
DROP POLICY IF EXISTS itens_orcamento_ubiqua_do_representante ON public.itens_orcamento_ubiqua;
CREATE POLICY authenticated_all_orcamentos_revenda_ubiqua ON public.orcamentos_revenda_ubiqua
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY authenticated_all_itens_orcamento_ubiqua ON public.itens_orcamento_ubiqua
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
ALTER FUNCTION public.fn_gerar_numero_orcamento() SECURITY INVOKER RESET search_path;
COMMIT;
