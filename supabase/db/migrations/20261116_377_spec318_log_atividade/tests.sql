-- Testes da 377 (SPEC-318). Rodar DEPOIS de aplicar a up.sql (ou dentro do dry_run.sql). Tudo em ROLLBACK.
-- Esperado: cada bloco imprime NOTICE 'OK ...'; qualquer falha levanta EXCEPTION.
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.como(p_uid uuid, p_role text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', p_uid, 'role', p_role)::text, true);
  PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
END $$;

-- 0) estrutura: tabela com RLS ligado, sem grant para anon/authenticated, lista = 2 pessoas
DO $$
DECLARE n int; rls boolean;
BEGIN
  SELECT count(*) INTO n FROM auditoria.log_visualizadores
   WHERE usuario_id IN ('99b32325-87bb-4387-9c75-610cd9fef816', '56bdfb69-01de-462d-94c3-f89db555fd66');
  IF n <> 2 THEN RAISE EXCEPTION 'lista deveria ter Pedro e Filippo (achou %)', n; END IF;
  SELECT count(*) INTO n FROM auditoria.log_visualizadores;
  IF n <> 2 THEN RAISE EXCEPTION 'lista deveria ter so 2 pessoas (tem %)', n; END IF;
  SELECT relrowsecurity INTO rls FROM pg_class WHERE oid = 'auditoria.log_visualizadores'::regclass;
  IF rls IS NOT TRUE THEN RAISE EXCEPTION 'RLS desligado em auditoria.log_visualizadores'; END IF;
  IF has_table_privilege('anon', 'auditoria.log_visualizadores', 'SELECT')
     OR has_table_privilege('authenticated', 'auditoria.log_visualizadores', 'SELECT') THEN
    RAISE EXCEPTION 'anon/authenticated nao podem ler a tabela da lista';
  END IF;
  RAISE NOTICE 'OK 0: estrutura e lista';
END $$;

-- 1) Pedro (na lista): as 3 RPCs funcionam
DO $$
DECLARE r jsonb; n int;
BEGIN
  PERFORM pg_temp.como('99b32325-87bb-4387-9c75-610cd9fef816', 'authenticated');
  SET LOCAL ROLE authenticated;
  SELECT count(*) INTO n FROM public.auditoria_log_listar(now() - interval '30 days', now(), NULL, NULL, NULL, NULL, 10, 0, false, 'todos');
  r := public.auditoria_log_filtros();
  PERFORM 1 FROM public.auditoria_log_resumo_usuarios(now() - interval '7 days', now()) LIMIT 1;
  RESET ROLE;
  IF r->'sistemas' IS NULL THEN RAISE EXCEPTION 'filtros sem sistemas'; END IF;
  RAISE NOTICE 'OK 1: Pedro le (% linhas na amostra)', n;
END $$;

-- 2) Filippo (na lista)
DO $$
DECLARE n int;
BEGIN
  PERFORM pg_temp.como('56bdfb69-01de-462d-94c3-f89db555fd66', 'authenticated');
  SET LOCAL ROLE authenticated;
  SELECT count(*) INTO n FROM public.auditoria_log_listar(now() - interval '1 day', now(), NULL, NULL, NULL, NULL, 10, 0, false, 'todos');
  RESET ROLE;
  RAISE NOTICE 'OK 2: Filippo le';
END $$;

-- 3) Admin FORA da lista (ex.: Vinicius) e usuario sem papel admin: 42501 nas 3 RPCs
DO $$
DECLARE v_id uuid; v_sem uuid; k int := 0; alvo uuid; f text;
BEGIN
  SELECT u.id INTO v_id FROM public.usuarios u
   WHERE u.role::text = 'admin' AND u.id NOT IN (SELECT usuario_id FROM auditoria.log_visualizadores) LIMIT 1;
  SELECT u.id INTO v_sem FROM public.usuarios u
   WHERE u.role::text <> 'admin' AND u.id NOT IN (SELECT usuario_id FROM auditoria.log_visualizadores) LIMIT 1;
  IF v_id IS NULL THEN RAISE EXCEPTION 'nao achei admin fora da lista para testar'; END IF;
  FOREACH alvo IN ARRAY ARRAY[v_id, v_sem, gen_random_uuid()] LOOP
    CONTINUE WHEN alvo IS NULL;
    PERFORM pg_temp.como(alvo, 'authenticated');
    SET LOCAL ROLE authenticated;
    FOREACH f IN ARRAY ARRAY['listar', 'resumo', 'filtros'] LOOP
      BEGIN
        IF f = 'listar' THEN PERFORM 1 FROM public.auditoria_log_listar() LIMIT 1;
        ELSIF f = 'resumo' THEN PERFORM 1 FROM public.auditoria_log_resumo_usuarios() LIMIT 1;
        ELSE PERFORM public.auditoria_log_filtros(); END IF;
        RESET ROLE;
        RAISE EXCEPTION 'FALHA: % conseguiu chamar auditoria_log_% sem estar na lista', alvo, f;
      EXCEPTION WHEN insufficient_privilege THEN
        RESET ROLE; k := k + 1;
      END;
    END LOOP;
    RESET ROLE;
  END LOOP;
  RAISE NOTICE 'OK 3: % chamadas negadas (42501) para admin fora da lista, nao-admin e uuid aleatorio', k;
END $$;

-- 4) anon: sem permissao de execucao
DO $$
BEGIN
  PERFORM pg_temp.como(NULL, 'anon');
  SET LOCAL ROLE anon;
  BEGIN
    PERFORM public.auditoria_log_filtros();
    RESET ROLE;
    RAISE EXCEPTION 'FALHA: anon executou auditoria_log_filtros';
  EXCEPTION WHEN insufficient_privilege THEN
    RESET ROLE;
    RAISE NOTICE 'OK 4: anon negado';
  END;
END $$;

-- 5) as RPCs antigas continuam existindo e continuam so para admin (nao foram alteradas)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                  WHERE n.nspname = 'public' AND p.proname = 'auditoria_listar'
                    AND pg_get_functiondef(p.oid) LIKE '%is_admin()%') THEN
    RAISE EXCEPTION 'auditoria_listar antiga mudou';
  END IF;
  RAISE NOTICE 'OK 5: auditoria_listar antiga intacta (is_admin)';
END $$;

-- 6) filtro SQL direto (como Pedro): 'somente' so devolve SQL direto; 'ocultar' nao devolve nenhum
DO $$
DECLARE a int; b int;
BEGIN
  PERFORM pg_temp.como('99b32325-87bb-4387-9c75-610cd9fef816', 'authenticated');
  SET LOCAL ROLE authenticated;
  SELECT count(*) INTO a FROM public.auditoria_log_listar(now() - interval '365 days', now(), NULL, NULL, NULL, NULL, 5000, 0, true, 'somente') r WHERE NOT r.sql_direto;
  SELECT count(*) INTO b FROM public.auditoria_log_listar(now() - interval '365 days', now(), NULL, NULL, NULL, NULL, 5000, 0, true, 'ocultar') r WHERE r.sql_direto;
  RESET ROLE;
  IF a <> 0 OR b <> 0 THEN RAISE EXCEPTION 'filtro SQL direto vazou (somente=% ocultar=%)', a, b; END IF;
  RAISE NOTICE 'OK 6: filtro SQL direto';
END $$;

ROLLBACK;
