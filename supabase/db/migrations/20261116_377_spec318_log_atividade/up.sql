-- SPEC-318 (16/11/2026): sistema "Log de Atividade". Leitura de auditoria.eventos SOMENTE por uma LISTA de pessoas
-- (Pedro e Filippo), nao por papel admin (o Vinicius e admin e e um dos auditados).
-- NAO altera auditoria_listar / auditoria_resumo_usuarios (aba Movimentacao da Central continua igual).
-- Cria: auditoria.log_visualizadores, auditoria.pode_ver_log(), public.auditoria_log_listar / _resumo_usuarios / _filtros.
-- Nao muda nada do que e gravado em auditoria.eventos.
BEGIN;

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
COMMIT;
