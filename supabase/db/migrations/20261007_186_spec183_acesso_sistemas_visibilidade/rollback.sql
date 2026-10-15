-- migration 218 (15/10): as cópias _bkp_* foram movidas para o schema backup.
-- Rollback da 20261007_186 (SPEC-183): volta a regra antiga (Hub por papel).

CREATE OR REPLACE FUNCTION public.hub_sistemas_permitidos(p_usuario_id uuid)
 RETURNS SETOF systems
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT DISTINCT s.*
  FROM systems s
  JOIN papel_permissoes pp ON pp.system_id = s.id
  JOIN usuario_papeis up ON up.papel_id = pp.papel_id AND up.usuario_id = p_usuario_id
  WHERE (pp.acao = 'visualizar' OR pp.acao IS NULL)
    AND s.visivel_no_hub = true
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

CREATE POLICY user_insert_usa ON public.user_system_access
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- Dados: restaurar user_system_access do backup
DELETE FROM public.user_system_access;
INSERT INTO public.user_system_access SELECT * FROM backup._bkp_user_system_access_20261007;

NOTIFY pgrst, 'reload schema';
