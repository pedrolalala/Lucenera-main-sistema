-- Dry-run da 262: roda o mesmo DO, confere e desfaz. NÃO tem COMMIT (ver feedback "dry-run com COMMIT embutido").
-- Antes de rodar: conferir que este arquivo não contém a palavra COMMIT.
BEGIN;

-- 0) estado antes: quem executa cada função
SELECT p.oid::regprocedure AS funcao,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_executa,
       pg_get_functiondef(p.oid) LIKE '%IF v_caller_role != ''admin'' THEN%' AS tem_furo
FROM pg_proc p
WHERE p.oid IN ('public.admin_update_user_password(uuid, text)'::regprocedure,
                'public.admin_update_user_role(uuid, text)'::regprocedure,
                'public.admin_update_user_status(uuid, boolean)'::regprocedure,
                'public.criar_usuario(text, text, text, public.usuario_role)'::regprocedure);

DO $$
DECLARE f text; def text;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'public.admin_update_user_password(uuid, text)',
    'public.admin_update_user_role(uuid, text)',
    'public.admin_update_user_status(uuid, boolean)',
    'public.criar_usuario(text, text, text, public.usuario_role)'
  ] LOOP
    def := pg_get_functiondef(f::regprocedure);
    IF def NOT LIKE '%IF v_caller_role != ''admin'' THEN%' THEN
      RAISE NOTICE '% sem a trava esperada', f; CONTINUE;
    END IF;
    EXECUTE replace(def, 'IF v_caller_role != ''admin'' THEN', 'IF v_caller_role IS DISTINCT FROM ''admin'' THEN');
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role', f);
  END LOOP;
END $$;
REVOKE ALL ON public.produto_caixa_editores FROM anon;

-- 1) depois: anon não executa, furo fechado
SELECT p.oid::regprocedure AS funcao,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_executa,
       pg_get_functiondef(p.oid) LIKE '%IS DISTINCT FROM ''admin''%' AS corrigida
FROM pg_proc p
WHERE p.proname IN ('admin_update_user_password','admin_update_user_role','admin_update_user_status','criar_usuario')
  AND p.pronamespace = 'public'::regnamespace;

-- 2) logado sem linha em usuarios agora é barrado
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"role":"authenticated","sub":"00000000-0000-0000-0000-0000000000ff"}', true);
DO $$ BEGIN
  PERFORM public.admin_update_user_status('00000000-0000-0000-0000-0000000000ff', true);
  RAISE NOTICE 'FALHOU: passou sem ser admin';
EXCEPTION WHEN raise_exception THEN RAISE NOTICE 'OK: barrado (%)', SQLERRM;
END $$;
RESET ROLE;

ROLLBACK;
