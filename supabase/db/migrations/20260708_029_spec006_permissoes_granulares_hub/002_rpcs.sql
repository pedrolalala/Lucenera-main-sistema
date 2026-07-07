-- Migration 20260708_029 - SPEC-006 Parte 2
-- RPCs hub_pode_executar e hub_sistemas_permitidos.
--
-- Correcao em relacao ao desenho original da SPEC: a comparacao
-- "pp.acao = p_acao" nunca e verdadeira quando pp.acao e NULL (semantica
-- pretendida de "todas as acoes"), porque NULL nao e igual a nada em SQL.
-- Trocado por "(pp.acao IS NULL OR pp.acao = p_acao)" nos dois lugares
-- (papel_permissoes e usuario_permissao_excecoes).

CREATE OR REPLACE FUNCTION public.hub_pode_executar(
  p_usuario_id uuid,
  p_system_slug text,
  p_modulo_chave text,
  p_acao text
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_excecao text;
BEGIN
  -- 1. Excecao individual tem precedencia. modulo_id NULL na excecao = vale
  -- para o sistema inteiro; caso contrario precisa bater com o modulo pedido.
  SELECT e.tipo INTO v_excecao
  FROM usuario_permissao_excecoes e
  JOIN systems s ON s.id = e.system_id AND s.slug = p_system_slug
  LEFT JOIN modulos m ON m.id = e.modulo_id
  WHERE e.usuario_id = p_usuario_id
    AND e.acao = p_acao
    AND (e.valido_até IS NULL OR e.valido_até > now())
    AND (e.modulo_id IS NULL OR m.chave = p_modulo_chave)
  ORDER BY e.criado_em DESC
  LIMIT 1;

  IF v_excecao = 'negar' THEN RETURN false; END IF;
  IF v_excecao = 'conceder' THEN RETURN true; END IF;

  -- 2. Papel do usuario (sistema inteiro OU modulo especifico; acao NULL = todas)
  RETURN EXISTS (
    SELECT 1
    FROM usuario_papeis up
    JOIN papel_permissoes pp ON pp.papel_id = up.papel_id
    JOIN systems s ON s.id = pp.system_id AND s.slug = p_system_slug
    LEFT JOIN modulos m ON m.id = pp.modulo_id
    WHERE up.usuario_id = p_usuario_id
      AND (pp.acao IS NULL OR pp.acao = p_acao)
      AND (pp.modulo_id IS NULL OR m.chave = p_modulo_chave)
  );
END;
$$;

COMMENT ON FUNCTION public.hub_pode_executar(uuid, text, text, text) IS
'SPEC-006. Combina papel + excecao individual (excecao sempre tem prioridade). Contrato publicado para os demais sistemas adotarem quando quiserem.';

CREATE OR REPLACE FUNCTION public.hub_sistemas_permitidos(p_usuario_id uuid)
RETURNS SETOF public.systems
LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT DISTINCT s.*
  FROM systems s
  JOIN papel_permissoes pp ON pp.system_id = s.id
  JOIN usuario_papeis up ON up.papel_id = pp.papel_id AND up.usuario_id = p_usuario_id
  WHERE (pp.acao = 'visualizar' OR pp.acao IS NULL)
    AND s.visivel_no_hub = true
$$;

COMMENT ON FUNCTION public.hub_sistemas_permitidos(uuid) IS
'SPEC-006. Substitui a leitura direta de user_system_access nos cards do Hub. Exclui sistemas com visivel_no_hub = false (ex.: o proprio Hub).';

GRANT EXECUTE ON FUNCTION public.hub_pode_executar(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.hub_sistemas_permitidos(uuid) TO authenticated;
