-- SPEC-164 — Memória Lucenera: base de conhecimento corporativa.
--
-- Cria o modelo novo (tabela unificada por TIPO de conhecimento) ao lado das
-- tabelas antigas do app pessoal (knowledge_items, entities, ...), que ficam
-- intactas. Nenhum DROP, nenhuma alteração em tabela existente.
--
-- 9 tipos (enum kb_tipo) agrupados em 5 núcleos (enum kb_categoria). A
-- categoria é DERIVADA do tipo (coluna gerada) — nunca diverge.
-- Os campos específicos de cada template ficam em `campos jsonb`; o frontend
-- define os templates. As colunas *_norm (sem acento, minúsculas) são
-- mantidas por trigger e usadas pela busca (003).
--
-- Busca por imagem no futuro: anexos ficam em kb_anexos (1 linha por
-- arquivo, com metadata jsonb). Um embedding visual pode ser acrescentado
-- depois como coluna nova ou tabela 1:1 sem quebrar nada.

BEGIN;

CREATE TYPE memoria.kb_tipo AS ENUM (
  'reuniao_projeto',   -- Reuniões de projeto        (PROJETO)
  'visita_obra',       -- Visitas em obra            (PROJETO)
  'teste_material',    -- Resultados de testes       (TÉCNICO)
  'regra_material',    -- Regras de uso de materiais (TÉCNICO)
  'padrao_projeto',    -- Padrões de projeto         (TÉCNICO)
  'procedimento',      -- Procedimentos internos     (OPERACIONAL)
  'marca',             -- Marcas que trabalhamos     (COMERCIAL)
  'designer',          -- Designers que trabalhamos  (COMERCIAL)
  'vivencia_evento'    -- Vivências de eventos       (APRENDIZADO)
);

CREATE TYPE memoria.kb_categoria AS ENUM ('tecnico', 'comercial', 'operacional', 'projeto', 'aprendizado');
CREATE TYPE memoria.kb_status    AS ENUM ('rascunho', 'publicado', 'arquivado');
CREATE TYPE memoria.kb_origem    AS ENUM ('manual', 'importada');

CREATE FUNCTION memoria.kb_categoria_do_tipo(p_tipo memoria.kb_tipo)
RETURNS memoria.kb_categoria
LANGUAGE sql IMMUTABLE PARALLEL SAFE
AS $$
  SELECT CASE p_tipo
    WHEN 'regra_material'  THEN 'tecnico'
    WHEN 'padrao_projeto'  THEN 'tecnico'
    WHEN 'teste_material'  THEN 'tecnico'
    WHEN 'marca'           THEN 'comercial'
    WHEN 'designer'        THEN 'comercial'
    WHEN 'procedimento'    THEN 'operacional'
    WHEN 'reuniao_projeto' THEN 'projeto'
    WHEN 'visita_obra'     THEN 'projeto'
    WHEN 'vivencia_evento' THEN 'aprendizado'
  END::memoria.kb_categoria
$$;

-- Normalização usada em toda a busca: sem acento, minúsculas, só letras/
-- dígitos separados por 1 espaço. unaccent de 2 argumentos é STABLE no
-- catálogo; o dicionário é fixo, então marcar IMMUTABLE é seguro (padrão
-- documentado do Postgres para índices com unaccent).
CREATE FUNCTION memoria.kb_norm(p_texto text)
RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE
AS $$
  SELECT btrim(regexp_replace(
           lower(public.unaccent('public.unaccent'::regdictionary, coalesce(p_texto, ''))),
           '[^a-z0-9]+', ' ', 'g'))
$$;

CREATE TABLE memoria.kb_itens (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo             memoria.kb_tipo NOT NULL,
  categoria        memoria.kb_categoria GENERATED ALWAYS AS (memoria.kb_categoria_do_tipo(tipo)) STORED,
  titulo           text NOT NULL CHECK (btrim(titulo) <> ''),
  resumo           text,
  campos           jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(campos) = 'object'),
  tags             text[] NOT NULL DEFAULT '{}',
  -- Data do fato (reunião, visita, teste, evento). NULL nos tipos de referência.
  data_referencia  date,
  -- Código do projeto operacional Lucenera (ex.: 26.181), texto livre como na SPEC-134.
  project_code     text,
  status           memoria.kb_status NOT NULL DEFAULT 'publicado',
  origem           memoria.kb_origem NOT NULL DEFAULT 'manual',
  -- Para itens importados: de onde vieram e a chave estável na origem.
  origem_fonte     text,
  origem_chave     text,
  -- Rastreio da migração a partir das tabelas antigas (005).
  legado_tabela    text,
  legado_id        uuid,
  revisado_em      timestamptz,
  proxima_revisao  date,
  -- SET NULL (e não CASCADE como nas tabelas antigas): desligar um
  -- colaborador não pode apagar o conhecimento que ele registrou.
  autor_id         uuid DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE SET NULL,
  atualizado_por   uuid DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE SET NULL,
  metadata         jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  -- Mantidas pelo trigger kb_itens_preparar; não escrever pelo app.
  conteudo_texto   text NOT NULL DEFAULT '',
  titulo_norm      text NOT NULL DEFAULT '',
  conteudo_norm    text NOT NULL DEFAULT '',
  tags_norm        text NOT NULL DEFAULT '',
  CONSTRAINT kb_itens_origem_chave_ck CHECK (origem = 'manual' OR (origem_fonte IS NOT NULL AND origem_chave IS NOT NULL))
);

COMMENT ON TABLE memoria.kb_itens IS
  'SPEC-164: item da base de conhecimento corporativa. tipo (9) -> categoria (5, gerada). Campos do template em campos jsonb. RLS: internos leem publicados; autor ou curador (Hub memoria/aprovar) edita.';

CREATE UNIQUE INDEX kb_itens_origem_uq ON memoria.kb_itens (origem_fonte, origem_chave) WHERE origem_chave IS NOT NULL;
CREATE UNIQUE INDEX kb_itens_legado_uq ON memoria.kb_itens (legado_tabela, legado_id) WHERE legado_id IS NOT NULL;
CREATE INDEX kb_itens_tipo_idx       ON memoria.kb_itens (tipo, status);
CREATE INDEX kb_itens_categoria_idx  ON memoria.kb_itens (categoria, status);
CREATE INDEX kb_itens_project_idx    ON memoria.kb_itens (project_code) WHERE project_code IS NOT NULL;
CREATE INDEX kb_itens_tags_idx       ON memoria.kb_itens USING gin (tags);
CREATE INDEX kb_itens_titulo_trgm    ON memoria.kb_itens USING gin (titulo_norm extensions.gin_trgm_ops);
CREATE INDEX kb_itens_conteudo_trgm  ON memoria.kb_itens USING gin (conteudo_norm extensions.gin_trgm_ops);

-- Prepara colunas derivadas: limpa tags, achata campos jsonb em texto e
-- normaliza para a busca.
CREATE FUNCTION memoria.kb_itens_preparar()
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
  NEW.conteudo_norm  := memoria.kb_norm(NEW.conteudo_texto);
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

CREATE TRIGGER kb_itens_preparar
  BEFORE INSERT OR UPDATE ON memoria.kb_itens
  FOR EACH ROW EXECUTE FUNCTION memoria.kb_itens_preparar();

-- Histórico: snapshot da versão anterior a cada alteração de conteúdo.
CREATE TABLE memoria.kb_itens_versoes (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id      uuid NOT NULL REFERENCES memoria.kb_itens(id) ON DELETE CASCADE,
  snapshot     jsonb NOT NULL,
  alterado_por uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  alterado_em  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX kb_itens_versoes_item_idx ON memoria.kb_itens_versoes (item_id, alterado_em DESC);

CREATE FUNCTION memoria.kb_itens_versionar()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = memoria, public
AS $$
BEGIN
  IF (OLD.titulo, OLD.resumo, OLD.campos, OLD.tags, OLD.status, OLD.tipo, OLD.data_referencia, OLD.project_code)
     IS DISTINCT FROM
     (NEW.titulo, NEW.resumo, NEW.campos, NEW.tags, NEW.status, NEW.tipo, NEW.data_referencia, NEW.project_code) THEN
    INSERT INTO memoria.kb_itens_versoes (item_id, snapshot, alterado_por)
    VALUES (OLD.id,
            to_jsonb(OLD) - 'conteudo_texto' - 'titulo_norm' - 'conteudo_norm' - 'tags_norm',
            auth.uid());
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER kb_itens_versionar
  AFTER UPDATE ON memoria.kb_itens
  FOR EACH ROW EXECUTE FUNCTION memoria.kb_itens_versionar();

-- Anexos (fotos de obra, plantas, montagens, referências, documentos).
-- Arquivo no bucket lucenera-memory-files, prefixo kb/<item_id>/.
CREATE TABLE memoria.kb_anexos (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id       uuid NOT NULL REFERENCES memoria.kb_itens(id) ON DELETE CASCADE,
  storage_path  text NOT NULL UNIQUE CHECK (storage_path LIKE 'kb/%'),
  nome_arquivo  text NOT NULL,
  mime_type     text,
  tamanho_bytes bigint CHECK (tamanho_bytes IS NULL OR tamanho_bytes >= 0),
  -- 'imagem' | 'documento' (texto livre, derivado do mime no app).
  tipo_anexo    text NOT NULL DEFAULT 'imagem',
  legenda       text,
  largura_px    integer,
  altura_px     integer,
  ordem         integer NOT NULL DEFAULT 0,
  -- Reservado para a busca por imagem (descrição visual, tags, id de embedding).
  metadata      jsonb NOT NULL DEFAULT '{}'::jsonb,
  autor_id      uuid DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX kb_anexos_item_idx ON memoria.kb_anexos (item_id, ordem);

-- Sinônimos e jargão de light design. Um termo pode estar em mais de um
-- grupo; a busca expande o termo para todos os termos dos seus grupos.
-- termo já normalizado (kb_norm).
CREATE TABLE memoria.kb_sinonimos (
  grupo      text NOT NULL,
  termo      text NOT NULL CHECK (termo = memoria.kb_norm(termo) AND termo <> ''),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (grupo, termo)
);
CREATE INDEX kb_sinonimos_termo_idx ON memoria.kb_sinonimos (termo);

COMMIT;
