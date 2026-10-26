-- SPEC-226 (complemento): o painel Admin do Logística passa a ler/editar
-- user_roles_separacao (a tabela user_roles não existe no banco SP).
-- Admin do Logística (logistica_eh_admin) pode incluir, editar e remover acesso.
BEGIN;

DROP POLICY IF EXISTS spec196_user_roles_sep_insert ON public.user_roles_separacao;
DROP POLICY IF EXISTS spec196_user_roles_sep_update ON public.user_roles_separacao;
DROP POLICY IF EXISTS logistica_user_roles_sep_insert ON public.user_roles_separacao;
DROP POLICY IF EXISTS logistica_user_roles_sep_update ON public.user_roles_separacao;
DROP POLICY IF EXISTS logistica_user_roles_sep_delete ON public.user_roles_separacao;

CREATE POLICY logistica_user_roles_sep_insert ON public.user_roles_separacao
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.logistica_eh_admin()));

CREATE POLICY logistica_user_roles_sep_update ON public.user_roles_separacao
  FOR UPDATE TO authenticated
  USING ((SELECT public.logistica_eh_admin()))
  WITH CHECK ((SELECT public.logistica_eh_admin()));

CREATE POLICY logistica_user_roles_sep_delete ON public.user_roles_separacao
  FOR DELETE TO authenticated
  USING ((SELECT public.logistica_eh_admin()));

COMMIT;
