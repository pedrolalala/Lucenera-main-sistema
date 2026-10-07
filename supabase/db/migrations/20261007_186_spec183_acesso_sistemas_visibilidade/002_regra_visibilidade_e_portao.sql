-- SPEC-183 (07/10/2026): regra nova.
--   Cartão no Hub / menu lateral = sistema marcado em user_system_access.
--   Agir dentro do sistema       = marcado em user_system_access E (exceção
--                                  'conceder' OU papel permite).
--   Admin (usuarios.role = 'admin') continua com bypass.
-- Mesmas assinaturas de antes (CREATE OR REPLACE sem overload).
-- Sem BEGIN/COMMIT no texto (aplicar com dry-run + rollback antes).

CREATE OR REPLACE FUNCTION public.hub_sistemas_permitidos(p_usuario_id uuid)
 RETURNS SETOF systems
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT s.*
  FROM systems s
  JOIN user_system_access usa ON usa.system_id = s.id AND usa.user_id = p_usuario_id
  WHERE s.visivel_no_hub = true
$function$;

CREATE OR REPLACE FUNCTION public.hub_pode_executar(p_usuario_id uuid, p_system_slug text, p_modulo_chave text, p_acao text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_excecao text;
BEGIN
  -- 0. SPEC-183: portão de "Acesso a Sistemas". Sistema visível no Hub que
  -- não está marcado para o usuário = sem acesso, mesmo que papel/exceção
  -- permitam. Admin passa direto. Sistemas internos (visivel_no_hub = false)
  -- seguem só por papel.
  IF NOT EXISTS (
       SELECT 1 FROM usuarios WHERE id = p_usuario_id AND role::text = 'admin'
     )
     AND EXISTS (
       SELECT 1 FROM systems WHERE slug = p_system_slug AND visivel_no_hub = true
     )
     AND NOT EXISTS (
       SELECT 1
       FROM user_system_access usa
       JOIN systems s ON s.id = usa.system_id
       WHERE usa.user_id = p_usuario_id AND s.slug = p_system_slug
     )
  THEN
    RETURN false;
  END IF;

  -- 1. Excecao individual tem precedencia. modulo_id NULL na excecao = vale
  -- para o sistema inteiro; caso contrario precisa bater com o modulo
  -- pedido. p_acao NULL (chamador pedindo "acesso ao sistema, qualquer
  -- ação") ou e.acao NULL (exceção vale pra qualquer ação) também casam.
  SELECT e.tipo INTO v_excecao
  FROM usuario_permissao_excecoes e
  JOIN systems s ON s.id = e.system_id AND s.slug = p_system_slug
  LEFT JOIN modulos m ON m.id = e.modulo_id
  WHERE e.usuario_id = p_usuario_id
    AND (p_acao IS NULL OR e.acao IS NULL OR e.acao = p_acao)
    AND (e.valido_até IS NULL OR e.valido_até > now())
    AND (e.modulo_id IS NULL OR m.chave = p_modulo_chave)
  ORDER BY e.criado_em DESC
  LIMIT 1;

  IF v_excecao = 'negar' THEN RETURN false; END IF;
  IF v_excecao = 'conceder' THEN RETURN true; END IF;

  -- 2. Papel do usuario (sistema inteiro OU modulo especifico; p_acao NULL
  -- do chamador = "tem algum acesso a esse sistema", casa com qualquer
  -- acao concedida pelo papel).
  RETURN EXISTS (
    SELECT 1
    FROM usuario_papeis up
    JOIN papel_permissoes pp ON pp.papel_id = up.papel_id
    JOIN systems s ON s.id = pp.system_id AND s.slug = p_system_slug
    LEFT JOIN modulos m ON m.id = pp.modulo_id
    WHERE up.usuario_id = p_usuario_id
      AND (p_acao IS NULL OR pp.acao IS NULL OR pp.acao = p_acao)
      AND (pp.modulo_id IS NULL OR m.chave = p_modulo_chave)
  );
END;
$function$;

-- Usuário comum não pode mais se dar acesso sozinho (só admin grava,
-- via admin_all_usa; cada um continua lendo o próprio via user_select_usa).
DROP POLICY IF EXISTS user_insert_usa ON public.user_system_access;

NOTIFY pgrst, 'reload schema';
