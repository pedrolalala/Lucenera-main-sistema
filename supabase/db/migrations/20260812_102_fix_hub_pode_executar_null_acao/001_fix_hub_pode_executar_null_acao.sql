-- SPEC-069 (fix): hub_pode_executar tratava p_acao IS NULL incorretamente.
--
-- Sintoma real: Debora (papel compras_e_entregas) via "Acesso negado" ao
-- abrir Necessidade de Compra, mesmo com visualizar/criar/editar concedidos
-- em papel_permissoes para esse sistema.
--
-- Causa raiz: a checagem de papel usava `pp.acao = p_acao`. Em SQL,
-- `qualquer_coisa = NULL` sempre resulta em NULL (nunca TRUE) — inclusive
-- quando p_acao é NULL. O chamador passa p_acao=NULL justamente para
-- perguntar "esse usuário tem QUALQUER acesso a este sistema, seja qual for
-- a ação" (uso real: gate de tela inteira em ProtectedRoute dos apps
-- satélite). Como nenhuma linha de papel_permissoes tinha `acao IS NULL`
-- pra esses papéis/sistemas, a linha OR (`pp.acao IS NULL OR pp.acao =
-- p_acao`) nunca virava TRUE, e a função sempre retornava false pra esse
-- caso de uso — silenciosamente, sem erro.
--
-- Escopo real do bug (confirmado por query antes de escrever este fix):
-- 16 combinações de papel/sistema SEM nenhuma linha de acao=NULL —
-- administracao_comercial, compras_e_entregas, equipe_entrega,
-- equipe_projetos, em cadastro/necessidade-de-compra/orcamentos/
-- separacao-parcial/logistica/crm. Qualquer checagem "tenho acesso a esse
-- sistema" (p_acao NULL) pra esses papéis estava quebrada, não só
-- Necessidade de Compra.
--
-- Fix: adiciona `p_acao IS NULL OR` nas duas checagens (exceção individual
-- e permissão por papel) — puramente aditivo, amplia o caso "chamador
-- pergunta acesso geral" pra casar com qualquer linha de acao específica.
-- Não muda nenhuma checagem de ação específica já em uso (aprovar,
-- criar, editar, visualizar continuam exigindo bater exatamente).

CREATE OR REPLACE FUNCTION public.hub_pode_executar(p_usuario_id uuid, p_system_slug text, p_modulo_chave text, p_acao text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_excecao text;
BEGIN
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
