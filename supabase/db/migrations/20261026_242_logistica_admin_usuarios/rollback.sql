BEGIN;
DROP POLICY IF EXISTS logistica_user_roles_sep_insert ON public.user_roles_separacao;
DROP POLICY IF EXISTS logistica_user_roles_sep_update ON public.user_roles_separacao;
DROP POLICY IF EXISTS logistica_user_roles_sep_delete ON public.user_roles_separacao;
CREATE POLICY spec196_user_roles_sep_insert ON public.user_roles_separacao
  FOR INSERT TO authenticated WITH CHECK ((SELECT is_admin() AS is_admin));
CREATE POLICY spec196_user_roles_sep_update ON public.user_roles_separacao
  FOR UPDATE TO authenticated USING ((SELECT is_admin() AS is_admin)) WITH CHECK ((SELECT is_admin() AS is_admin));
COMMIT;
