-- Rollback da 262: volta a trava antiga (com o furo do NULL) e a execução para anon. Só usar se a 262 quebrar a Central.
BEGIN;

DO $$
DECLARE
  f text;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'public.admin_update_user_password(uuid, text)',
    'public.admin_update_user_role(uuid, text)',
    'public.admin_update_user_status(uuid, boolean)',
    'public.criar_usuario(text, text, text, public.usuario_role)'
  ] LOOP
    EXECUTE replace(pg_get_functiondef(f::regprocedure),
                    'IF v_caller_role IS DISTINCT FROM ''admin'' THEN', 'IF v_caller_role != ''admin'' THEN');
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO PUBLIC, anon', f);
  END LOOP;
END $$;

GRANT ALL ON public.produto_caixa_editores TO anon;

COMMIT;
