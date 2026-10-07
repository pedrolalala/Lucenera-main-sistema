-- SPEC-164 — Busca da base de conhecimento.
--
-- kb_buscar: busca estilo Google sobre título + conteúdo (resumo + todos os
-- campos do template) + tags, com
--   * acento e caixa ignorados (kb_norm);
--   * sinônimos/jargão (kb_sinonimos): "downlight" também acha "luminária de
--     embutir"; expressões com várias palavras são reconhecidas inteiras;
--   * semântica E entre conceitos: cada palavra (ou expressão) da busca
--     precisa aparecer em algum campo, direto ou por sinônimo;
--   * relevância: título (10) > conteúdo (4) > tags (2), por conceito;
--     casamento por sinônimo vale 80% do casamento direto;
--   * fallback por semelhança (pg_trgm) quando nada casa — tolera erro de
--     digitação ("dowlight").
-- SECURITY INVOKER: o RLS de kb_itens decide o que cada pessoa vê.
--
-- kb_sugerir: autocomplete (títulos, tags e termos técnicos) enquanto digita.

BEGIN;

-- Regex de palavra para um termo normalizado (uma ou várias palavras).
-- Palavras curtas (<= 3, ex.: CRI, UGR, IP, "de") exigem palavra inteira para
-- não casar dentro de "descrição". Palavras longas casam como início de
-- palavra ("embutido" acha "embutidos"), e plural simples é reduzido
-- ("spots" acha "spot"). p_prefixo libera a última palavra curta como
-- prefixo (palavra ainda sendo digitada no autocomplete).
CREATE FUNCTION memoria.kb_rx(p_termo text, p_prefixo boolean DEFAULT false)
RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE
AS $$
  SELECT '\m' || string_agg(
           regexp_replace(
             CASE WHEN length(w) > 4 AND w ~ '[^s]s$' THEN left(w, -1) ELSE w END,
             '([.*+?^${}()|\[\]\\])', '\\\1', 'g')
           || CASE WHEN length(w) <= 3 AND NOT (p_prefixo AND ord = n) THEN '\M' ELSE '\w*' END,
           '\s+' ORDER BY ord)
  FROM (
    SELECT w, ord, count(*) OVER () AS n
    FROM regexp_split_to_table(p_termo, ' ') WITH ORDINALITY AS t(w, ord)
    WHERE w <> ''
  ) x
$$;

-- Quebra a busca em conceitos. Cada conceito = lista de variantes (o termo
-- digitado + sinônimos). Retorna jsonb: [["downlight","embutir",...], ["sala"]].
CREATE FUNCTION memoria.kb_conceitos(p_q text)
RETURNS jsonb
LANGUAGE plpgsql STABLE
SET search_path = memoria, public
AS $$
DECLARE
  v_resto     text := ' ' || memoria.kb_norm(p_q) || ' ';
  v_conceitos jsonb := '[]'::jsonb;
  v_termo     text;
  v_variantes text[];
  v_tok       text;
BEGIN
  -- 1) Expressões do dicionário presentes na busca (as mais longas primeiro).
  FOR v_termo IN
    SELECT s.termo FROM (SELECT DISTINCT termo FROM memoria.kb_sinonimos) s
    WHERE position(' ' || s.termo || ' ' in v_resto) > 0
    ORDER BY length(s.termo) DESC, s.termo
  LOOP
    CONTINUE WHEN position(' ' || v_termo || ' ' in v_resto) = 0;  -- já consumido por expressão maior
    SELECT array_agg(DISTINCT s2.termo) INTO v_variantes
    FROM memoria.kb_sinonimos s1
    JOIN memoria.kb_sinonimos s2 ON s2.grupo = s1.grupo
    WHERE s1.termo = v_termo;
    -- Variante digitada vai primeiro (casamento direto pesa mais).
    v_conceitos := v_conceitos || jsonb_build_array(to_jsonb(array_prepend(v_termo, array_remove(v_variantes, v_termo))));
    v_resto := replace(v_resto, ' ' || v_termo || ' ', ' ');
  END LOOP;

  -- 2) Palavras restantes, sem artigos/preposições.
  FOREACH v_tok IN ARRAY regexp_split_to_array(btrim(v_resto), '\s+') LOOP
    CONTINUE WHEN v_tok = '' OR v_tok = ANY (ARRAY['a','o','as','os','de','da','do','das','dos','e','em','no','na','nos','nas','para','pra','com','por','um','uma','que','como','se']);
    v_conceitos := v_conceitos || jsonb_build_array(jsonb_build_array(v_tok));
  END LOOP;

  RETURN v_conceitos;
END;
$$;

CREATE FUNCTION memoria.kb_buscar(
  p_q         text DEFAULT NULL,
  p_categoria memoria.kb_categoria DEFAULT NULL,
  p_tipo      memoria.kb_tipo DEFAULT NULL,
  p_limite    integer DEFAULT 50,
  p_prefixo   boolean DEFAULT false
)
RETURNS TABLE (
  id              uuid,
  tipo            memoria.kb_tipo,
  categoria       memoria.kb_categoria,
  titulo          text,
  trecho          text,
  tags            text[],
  data_referencia date,
  project_code    text,
  status          memoria.kb_status,
  origem          memoria.kb_origem,
  updated_at      timestamptz,
  relevancia      numeric,
  aproximado      boolean
)
LANGUAGE plpgsql STABLE
SET search_path = memoria, public, extensions
AS $$
DECLARE
  v_conceitos jsonb := memoria.kb_conceitos(p_q);
  v_n         integer := jsonb_array_length(memoria.kb_conceitos(p_q));
  v_limite    integer := least(greatest(coalesce(p_limite, 50), 1), 200);
  v_qnorm     text := memoria.kb_norm(p_q);
  v_corrigida text;
BEGIN
  -- Sem texto: navegação por tema (mais recentes primeiro).
  IF v_n = 0 THEN
    RETURN QUERY
      SELECT i.id, i.tipo, i.categoria, i.titulo,
             left(coalesce(nullif(i.resumo, ''), i.conteudo_texto), 240),
             i.tags, i.data_referencia, i.project_code, i.status, i.origem, i.updated_at,
             0::numeric, false
      FROM memoria.kb_itens i
      WHERE i.status <> 'arquivado'
        AND (p_categoria IS NULL OR i.categoria = p_categoria)
        AND (p_tipo IS NULL OR i.tipo = p_tipo)
      ORDER BY coalesce(i.data_referencia::timestamptz, i.updated_at) DESC
      LIMIT v_limite;
    RETURN;
  END IF;

  RETURN QUERY
  WITH conceitos AS (
    SELECT c.ord, v.variante, v.pos,
           memoria.kb_rx(v.variante, p_prefixo AND c.ord = v_n) AS rx
    FROM jsonb_array_elements(v_conceitos) WITH ORDINALITY AS c(lista, ord)
    CROSS JOIN LATERAL jsonb_array_elements_text(c.lista) WITH ORDINALITY AS v(variante, pos)
  ),
  candidatos AS (
    SELECT i.* FROM memoria.kb_itens i
    WHERE i.status <> 'arquivado'
      AND (p_categoria IS NULL OR i.categoria = p_categoria)
      AND (p_tipo IS NULL OR i.tipo = p_tipo)
  ),
  por_conceito AS (
    SELECT ca.id, co.ord,
           max( ( CASE WHEN ca.titulo_norm   ~ co.rx THEN 10 ELSE 0 END
                + CASE WHEN ca.conteudo_norm ~ co.rx THEN 4  ELSE 0 END
                + CASE WHEN ca.tags_norm     ~ co.rx THEN 2  ELSE 0 END )
                * CASE WHEN co.pos = 1 THEN 1.0 ELSE 0.8 END ) AS pontos,
           -- variante que casou no conteúdo (para montar o trecho)
           min(co.variante) FILTER (WHERE ca.conteudo_norm ~ co.rx) AS variante_conteudo
    FROM candidatos ca CROSS JOIN conceitos co
    GROUP BY ca.id, co.ord
  ),
  pontuados AS (
    SELECT pc.id, sum(pc.pontos) AS pontos, min(pc.variante_conteudo) AS variante_conteudo
    FROM por_conceito pc
    GROUP BY pc.id
    HAVING count(*) FILTER (WHERE pc.pontos > 0) = v_n
  )
  SELECT i.id, i.tipo, i.categoria, i.titulo,
         memoria.kb_trecho(i.conteudo_texto, p.variante_conteudo, i.resumo),
         i.tags, i.data_referencia, i.project_code, i.status, i.origem, i.updated_at,
         (p.pontos + similarity(i.titulo_norm, v_qnorm))::numeric, false
  FROM pontuados p
  JOIN candidatos i ON i.id = p.id
  ORDER BY p.pontos + similarity(i.titulo_norm, v_qnorm) DESC, i.updated_at DESC
  LIMIT v_limite;

  IF FOUND THEN RETURN; END IF;

  -- Nada casou: aproximação (erro de digitação). Primeiro tenta corrigir
  -- cada palavra pelo termo técnico mais parecido do dicionário
  -- ("dowlight" -> "downlight") e refaz a busca; senão, semelhança com
  -- títulos e tags.
  IF NOT p_prefixo THEN
    SELECT string_agg(coalesce(
             (SELECT s.termo FROM memoria.kb_sinonimos s
              WHERE length(tok) >= 4 AND similarity(s.termo, tok) >= 0.45
              ORDER BY similarity(s.termo, tok) DESC LIMIT 1),
             tok), ' ' ORDER BY ord)
      INTO v_corrigida
    FROM regexp_split_to_table(v_qnorm, ' ') WITH ORDINALITY AS t(tok, ord);

    IF v_corrigida IS DISTINCT FROM v_qnorm THEN
      RETURN QUERY
        SELECT b.id, b.tipo, b.categoria, b.titulo, b.trecho, b.tags, b.data_referencia, b.project_code,
               b.status, b.origem, b.updated_at, b.relevancia, true
        FROM memoria.kb_buscar(v_corrigida, p_categoria, p_tipo, p_limite, true) b;
      IF FOUND THEN RETURN; END IF;
    END IF;
  END IF;

  RETURN QUERY
    SELECT i.id, i.tipo, i.categoria, i.titulo,
           left(coalesce(nullif(i.resumo, ''), i.conteudo_texto), 240),
           i.tags, i.data_referencia, i.project_code, i.status, i.origem, i.updated_at,
           greatest(word_similarity(v_qnorm, i.titulo_norm), word_similarity(v_qnorm, i.tags_norm))::numeric,
           true
    FROM memoria.kb_itens i
    WHERE i.status <> 'arquivado'
      AND (p_categoria IS NULL OR i.categoria = p_categoria)
      AND (p_tipo IS NULL OR i.tipo = p_tipo)
      AND greatest(word_similarity(v_qnorm, i.titulo_norm), word_similarity(v_qnorm, i.tags_norm)) >= 0.45
    ORDER BY 12 DESC
    LIMIT least(v_limite, 10);
END;
$$;

-- Trecho de ~240 caracteres em volta da primeira ocorrência da variante que
-- casou. Procura em lower(unaccent(texto)), que preserva as posições do texto
-- original (1 caractere por caractere no português) — kb_norm não serve aqui
-- porque colapsa pontuação.
CREATE FUNCTION memoria.kb_trecho(p_texto text, p_variante text, p_resumo text)
RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE
AS $$
  WITH base AS (
    SELECT lower(public.unaccent('public.unaccent'::regdictionary, coalesce(p_texto, ''))) AS t
  ), pos AS (
    SELECT CASE WHEN p_variante IS NULL THEN 0
                ELSE greatest(position(p_variante in t),
                              position(split_part(p_variante, ' ', 1) in t)) END AS p
    FROM base
  )
  SELECT CASE
    WHEN p = 0 THEN left(coalesce(nullif(p_resumo, ''), p_texto), 240)
    ELSE (CASE WHEN p > 90 THEN '…' ELSE '' END)
         || substr(p_texto, greatest(p - 90, 1), 240)
         || (CASE WHEN length(p_texto) > greatest(p - 90, 1) + 239 THEN '…' ELSE '' END)
  END
  FROM pos
$$;

-- Autocomplete: até p_limite sugestões, misturando itens (título) e termos
-- (tags usadas na base + termos técnicos do dicionário).
CREATE FUNCTION memoria.kb_sugerir(p_q text, p_limite integer DEFAULT 8)
RETURNS TABLE (espec text, texto text, item_id uuid, tipo memoria.kb_tipo)
LANGUAGE plpgsql STABLE
SET search_path = memoria, public, extensions
AS $$
DECLARE
  v_q    text := memoria.kb_norm(p_q);
BEGIN
  IF length(v_q) < 2 THEN RETURN; END IF;

  RETURN QUERY
  (SELECT 'item'::text, b.titulo, b.id, b.tipo
   FROM memoria.kb_buscar(p_q, NULL, NULL, 5, true) b)
  UNION ALL
  (SELECT 'termo'::text, t.texto, NULL::uuid, NULL::memoria.kb_tipo
   FROM (
     SELECT DISTINCT ON (memoria.kb_norm(tag)) tag AS texto, 0 AS prioridade
     FROM memoria.kb_itens i, unnest(i.tags) AS tag
     WHERE i.status = 'publicado' AND memoria.kb_norm(tag) LIKE v_q || '%'
     UNION ALL
     SELECT DISTINCT s.termo, 1
     FROM memoria.kb_sinonimos s
     WHERE s.termo LIKE v_q || '%'
   ) t
   ORDER BY t.prioridade, length(t.texto)
   LIMIT 4)
  LIMIT greatest(coalesce(p_limite, 8), 1);
END;
$$;

REVOKE ALL ON FUNCTION memoria.kb_rx(text, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION memoria.kb_conceitos(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION memoria.kb_buscar(text, memoria.kb_categoria, memoria.kb_tipo, integer, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION memoria.kb_trecho(text, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION memoria.kb_sugerir(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION memoria.kb_rx(text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION memoria.kb_conceitos(text) TO authenticated;
GRANT EXECUTE ON FUNCTION memoria.kb_buscar(text, memoria.kb_categoria, memoria.kb_tipo, integer, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION memoria.kb_trecho(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION memoria.kb_sugerir(text, integer) TO authenticated;

COMMIT;
