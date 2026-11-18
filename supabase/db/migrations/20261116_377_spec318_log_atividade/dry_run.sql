-- Dry-run da 377 (SPEC-318): aplica a up.sql e roda os testes na MESMA transacao. DESFAZ. Termina em ROLLBACK.
BEGIN;
-- SPEC-318 (16/11/2026): sistema "Log de Atividade". Leitura de auditoria.eventos SOMENTE por uma LISTA de pessoas
-- (Pedro e Filippo), nao por papel admin (o Vinicius e admin e e um dos auditados).
-- NAO altera auditoria_listar / auditoria_resumo_usuarios (aba Movimentacao da Central continua igual).
-- Cria: auditoria.log_visualizadores, auditoria.pode_ver_log(), public.auditoria_log_listar / _resumo_usuarios / _filtros.
-- Nao muda nada do que e gravado em auditoria.eventos.

-- ---------------------------------------------------------------- lista de quem pode ver
CREATE TABLE IF NOT EXISTS auditoria.log_visualizadores (
  usuario_id uuid PRIMARY KEY
);
ALTER TABLE auditoria.log_visualizadores ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON auditoria.log_visualizadores FROM PUBLIC, anon, authenticated;
-- sem policy: ninguem le a tabela direto; so as funcoes SECURITY DEFINER abaixo.

INSERT INTO auditoria.log_visualizadores (usuario_id) VALUES
  ('99b32325-87bb-4387-9c75-610cd9fef816'),  -- Pedro
  ('56bdfb69-01de-462d-94c3-f89db555fd66')   -- Filippo
ON CONFLICT (usuario_id) DO NOTHING;

CREATE OR REPLACE FUNCTION auditoria.pode_ver_log()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT coalesce((SELECT true FROM auditoria.log_visualizadores v WHERE v.usuario_id = (SELECT auth.uid())), false);
$$;
REVOKE ALL ON FUNCTION auditoria.pode_ver_log() FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------- listar
-- p_sql_direto: 'todos' (padrao) | 'ocultar' | 'somente'. SQL direto = usuario_nome 'SQL direto (...)'.
CREATE OR REPLACE FUNCTION public.auditoria_log_listar(
  p_de timestamptz DEFAULT now() - interval '7 days',
  p_ate timestamptz DEFAULT now(),
  p_sistema text DEFAULT NULL,
  p_usuario uuid DEFAULT NULL,
  p_tipo text DEFAULT NULL,
  p_busca text DEFAULT NULL,
  p_limite int DEFAULT 100,
  p_offset int DEFAULT 0,
  p_incluir_telas boolean DEFAULT false,
  p_sql_direto text DEFAULT 'todos')
RETURNS TABLE (id bigint, criado_em timestamptz, usuario_id uuid, usuario_nome text, sistema text, tipo text,
               entidade text, registro_id text, referencia text, mudancas jsonb, ip text, navegador text,
               sql_direto boolean, total bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF (SELECT auditoria.pode_ver_log()) IS NOT TRUE THEN
    RAISE EXCEPTION 'Sem acesso ao log de atividade.' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT e.id, e.criado_em, e.usuario_id, e.usuario_nome, e.sistema, e.tipo, e.entidade, e.registro_id,
         e.referencia, e.mudancas, e.ip, e.navegador,
         coalesce(e.usuario_nome LIKE 'SQL direto%', false) AS sql_direto,
         count(*) OVER () AS total
    FROM auditoria.eventos e
   WHERE e.criado_em >= p_de AND e.criado_em <= p_ate
     AND (p_sistema IS NULL OR e.sistema = p_sistema)
     AND (p_usuario IS NULL OR e.usuario_id = p_usuario)
     AND (p_tipo IS NULL OR e.tipo = p_tipo)
     AND (coalesce(p_incluir_telas, false) OR p_tipo = 'abriu_tela' OR e.tipo <> 'abriu_tela')
     AND (coalesce(p_sql_direto, 'todos') NOT IN ('ocultar', 'somente')
          OR (p_sql_direto = 'ocultar' AND coalesce(e.usuario_nome, '') NOT LIKE 'SQL direto%')
          OR (p_sql_direto = 'somente' AND e.usuario_nome LIKE 'SQL direto%'))
     AND (nullif(trim(p_busca), '') IS NULL
          OR e.referencia ILIKE '%' || trim(p_busca) || '%'
          OR e.entidade ILIKE '%' || trim(p_busca) || '%'
          OR e.usuario_nome ILIKE '%' || trim(p_busca) || '%')
   ORDER BY e.criado_em DESC, e.id DESC
   LIMIT least(greatest(coalesce(p_limite, 100), 1), 5000) OFFSET greatest(coalesce(p_offset, 0), 0);
END $$;

-- ---------------------------------------------------------------- resumo por usuario
CREATE OR REPLACE FUNCTION public.auditoria_log_resumo_usuarios(
  p_de timestamptz DEFAULT now() - interval '7 days',
  p_ate timestamptz DEFAULT now())
RETURNS TABLE (usuario_id uuid, nome text, email text, ativo boolean, papel text,
               ultimo_login timestamptz, logins_hoje bigint, logins_periodo bigint, dias_com_login bigint,
               acoes_periodo bigint, telas_periodo bigint, sistemas text[])
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_hoje timestamptz := date_trunc('day', now() AT TIME ZONE 'America/Sao_Paulo') AT TIME ZONE 'America/Sao_Paulo';
BEGIN
  IF (SELECT auditoria.pode_ver_log()) IS NOT TRUE THEN
    RAISE EXCEPTION 'Sem acesso ao log de atividade.' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT u.id, u.nome, u.email, u.ativo, u.role::text,
         greatest(au.last_sign_in_at, (SELECT max(e.criado_em) FROM auditoria.eventos e WHERE e.usuario_id = u.id AND e.tipo = 'login')),
         (SELECT count(*) FROM auditoria.eventos e WHERE e.usuario_id = u.id AND e.tipo = 'login' AND e.criado_em >= v_hoje),
         (SELECT count(*) FROM auditoria.eventos e WHERE e.usuario_id = u.id AND e.tipo = 'login' AND e.criado_em BETWEEN p_de AND p_ate),
         (SELECT count(DISTINCT (e.criado_em AT TIME ZONE 'America/Sao_Paulo')::date) FROM auditoria.eventos e
           WHERE e.usuario_id = u.id AND e.tipo = 'login' AND e.criado_em BETWEEN p_de AND p_ate),
         (SELECT count(*) FROM auditoria.eventos e WHERE e.usuario_id = u.id
             AND e.tipo NOT IN ('login', 'senha_alterada', 'abriu_tela') AND e.criado_em BETWEEN p_de AND p_ate),
         (SELECT count(*) FROM auditoria.eventos e WHERE e.usuario_id = u.id AND e.tipo = 'abriu_tela'
             AND e.criado_em BETWEEN p_de AND p_ate),
         (SELECT array_agg(x.sistema ORDER BY x.qtd DESC) FROM (
             SELECT e.sistema, count(*) AS qtd FROM auditoria.eventos e
              WHERE e.usuario_id = u.id AND e.sistema IS NOT NULL AND e.sistema NOT IN ('automacao', 'local')
                AND e.criado_em BETWEEN p_de AND p_ate
              GROUP BY 1 ORDER BY 2 DESC LIMIT 3) x)
    FROM public.usuarios u
    JOIN auth.users au ON au.id = u.id
   ORDER BY u.ativo DESC NULLS LAST, u.nome;
END $$;

-- ---------------------------------------------------------------- opcoes dos filtros
CREATE OR REPLACE FUNCTION public.auditoria_log_filtros()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF (SELECT auditoria.pode_ver_log()) IS NOT TRUE THEN
    RAISE EXCEPTION 'Sem acesso ao log de atividade.' USING ERRCODE = '42501';
  END IF;
  RETURN jsonb_build_object(
    'sistemas', coalesce((SELECT jsonb_agg(s.x ORDER BY s.x) FROM (SELECT DISTINCT sistema AS x FROM auditoria.eventos WHERE sistema IS NOT NULL) s), '[]'::jsonb),
    'tipos', coalesce((SELECT jsonb_agg(s.x ORDER BY s.x) FROM (SELECT DISTINCT tipo AS x FROM auditoria.eventos) s), '[]'::jsonb),
    'entidades', coalesce((SELECT jsonb_agg(s.x ORDER BY s.x) FROM (SELECT DISTINCT entidade AS x FROM auditoria.eventos WHERE entidade IS NOT NULL) s), '[]'::jsonb),
    'usuarios', coalesce((SELECT jsonb_agg(jsonb_build_object('id', u.id, 'nome', coalesce(u.nome, u.email), 'ativo', u.ativo)
                                           ORDER BY u.ativo DESC NULLS LAST, u.nome)
                            FROM public.usuarios u), '[]'::jsonb),
    'sistemas_nomes', coalesce((SELECT jsonb_object_agg(s.slug, s.name) FROM public.systems s), '{}'::jsonb));
END $$;

REVOKE ALL ON FUNCTION public.auditoria_log_listar(timestamptz, timestamptz, text, uuid, text, text, int, int, boolean, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.auditoria_log_resumo_usuarios(timestamptz, timestamptz) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.auditoria_log_filtros() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.auditoria_log_listar(timestamptz, timestamptz, text, uuid, text, text, int, int, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.auditoria_log_resumo_usuarios(timestamptz, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.auditoria_log_filtros() TO authenticated;

NOTIFY pgrst, 'reload schema';
-- Testes da 377 (SPEC-318). Rodar DEPOIS de aplicar a up.sql (ou dentro do dry_run.sql). Tudo em ROLLBACK.
-- Esperado: cada bloco imprime NOTICE 'OK ...'; qualquer falha levanta EXCEPTION.

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
