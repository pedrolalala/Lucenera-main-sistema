-- SPEC-164 — correções achadas no teste ponta a ponta (2026-09-24), depois
-- de 001-005 aplicadas:
--   1. project_code não era pesquisável: buscar "26.181" não achava o item,
--      embora a tela do item linke o código para essa busca.
--   2. service_role sem GRANT nas tabelas kb_* (scripts administrativos e
--      futura importação usam service role).
-- Nenhum item existente tinha project_code preenchido na aplicação, então
-- não é preciso recalcular linhas.

BEGIN;

CREATE OR REPLACE FUNCTION memoria.kb_itens_preparar()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = memoria, public
AS $$
DECLARE
  v_campos_texto text;
BEGIN
  NEW.titulo := btrim(NEW.titulo);
  NEW.tags := coalesce((
    -- Remove vazias e repetidas ("LED" e "led" contam como a mesma tag).
    SELECT array_agg(t ORDER BY ord)
    FROM (
      SELECT DISTINCT ON (memoria.kb_norm(u.t)) btrim(u.t) AS t, u.ord
      FROM unnest(NEW.tags) WITH ORDINALITY AS u(t, ord)
      WHERE memoria.kb_norm(u.t) <> ''
      ORDER BY memoria.kb_norm(u.t), u.ord
    ) x
  ), '{}');

  SELECT string_agg(v #>> '{}', E'\n')
    INTO v_campos_texto
  FROM jsonb_path_query(NEW.campos, 'strict $.**') AS v
  WHERE jsonb_typeof(v) IN ('string', 'number');

  NEW.conteudo_texto := concat_ws(E'\n', nullif(btrim(coalesce(NEW.resumo, '')), ''), v_campos_texto);
  NEW.titulo_norm    := memoria.kb_norm(NEW.titulo);
  -- O código do projeto entra no texto pesquisável (a tela do item linka
  -- "Projeto 26.181" para a busca por ele), mas não no trecho exibido.
  NEW.conteudo_norm  := memoria.kb_norm(concat_ws(' ', NEW.conteudo_texto, NEW.project_code));
  NEW.tags_norm      := memoria.kb_norm(array_to_string(NEW.tags, ' '));

  IF TG_OP = 'UPDATE' THEN
    NEW.updated_at     := now();
    NEW.atualizado_por := coalesce(auth.uid(), NEW.atualizado_por);
    -- Autor, origem e rastreio não mudam por edição.
    NEW.autor_id      := OLD.autor_id;
    NEW.created_at    := OLD.created_at;
    NEW.origem        := OLD.origem;
    NEW.origem_fonte  := OLD.origem_fonte;
    NEW.origem_chave  := OLD.origem_chave;
    NEW.legado_tabela := OLD.legado_tabela;
    NEW.legado_id     := OLD.legado_id;
  END IF;
  RETURN NEW;
END;
$$;

GRANT ALL ON memoria.kb_itens, memoria.kb_itens_versoes, memoria.kb_anexos, memoria.kb_sinonimos TO service_role;

COMMIT;
