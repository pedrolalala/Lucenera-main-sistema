-- SPEC-242 A1 (URGENTE): funções de gestão de usuário com trava de admin que deixa passar quem não tem cadastro.
-- `SELECT role INTO v_caller_role ... WHERE id = auth.uid()` fica NULL para visitante (anon) ou conta sem linha em
-- usuarios; `NULL != 'admin'` é NULL, o IF não dispara e a função segue: troca senha / papel / status / cria usuário.
-- Correção cirúrgica: troca só a linha do IF na definição que está NO BANCO (não reescreve o corpo a partir do
-- snapshot, para não desfazer mudança feita fora das migrations) e tira a execução de anon/public.
-- Também: REVOKE anon na produto_caixa_editores (SPEC-240, migration 260 esqueceu — regra 1 da SPEC-196).
BEGIN;

DO $$
DECLARE
  f   text;
  def text;
  novo text;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'public.admin_update_user_password(uuid, text)',
    'public.admin_update_user_role(uuid, text)',
    'public.admin_update_user_status(uuid, boolean)',
    'public.criar_usuario(text, text, text, public.usuario_role)'
  ] LOOP
    def := pg_get_functiondef(f::regprocedure);
    IF def LIKE '%v_caller_role IS DISTINCT FROM ''admin''%' THEN
      RAISE NOTICE '% já corrigida', f;
      CONTINUE;
    END IF;
    IF def NOT LIKE '%IF v_caller_role != ''admin'' THEN%' THEN
      RAISE EXCEPTION 'SPEC-242: % não tem a trava esperada — conferir a definição antes de aplicar', f;
    END IF;
    novo := replace(def, 'IF v_caller_role != ''admin'' THEN', 'IF v_caller_role IS DISTINCT FROM ''admin'' THEN');
    EXECUTE novo;
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role', f);
    RAISE NOTICE '% corrigida', f;
  END LOOP;
END $$;

REVOKE ALL ON public.produto_caixa_editores FROM anon;

COMMIT;
