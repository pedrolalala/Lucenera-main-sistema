-- SPEC-165 — Reuniões de projeto: decisões vinculadas ao projeto e fila de
-- revisão das sugestões de aproveitamento para os demais temas.
--
-- Regras garantidas no banco (não só na tela):
--   * decisão sempre tem project_code e pertence a uma reunião;
--   * sugestão nasce 'pendente'; só curador muda o status, só a partir de
--     'pendente';
--   * 'aprovada' exige item_criado_id de um item existente do mesmo tipo de
--     destino — ou seja, uma pessoa criou o item; a IA nunca insere em tema;
--   * sugestão não pode se apoiar numa decisão marcada como solução
--     excepcional (fica só como histórico da reunião).
-- Aditivo: nenhuma tabela existente é alterada.

BEGIN;

CREATE TABLE memoria.kb_decisoes (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reuniao_id   uuid NOT NULL REFERENCES memoria.kb_itens(id) ON DELETE CASCADE,
  project_code text NOT NULL CHECK (btrim(project_code) <> ''),
  decisao      text NOT NULL CHECK (btrim(decisao) <> ''),
  contexto     text,
  -- Solução excepcional para este projeto: nunca vira padrão/regra.
  excepcional  boolean NOT NULL DEFAULT false,
  ordem        integer NOT NULL DEFAULT 0,
  autor_id     uuid DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX kb_decisoes_projeto_idx ON memoria.kb_decisoes (project_code, created_at DESC);
CREATE INDEX kb_decisoes_reuniao_idx ON memoria.kb_decisoes (reuniao_id, ordem);

-- Decisão só em item do tipo reunião de projeto.
CREATE FUNCTION memoria.kb_decisoes_validar()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = memoria, public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM memoria.kb_itens i WHERE i.id = NEW.reuniao_id AND i.tipo = 'reuniao_projeto') THEN
    RAISE EXCEPTION 'Decisão precisa pertencer a uma reunião de projeto';
  END IF;
  NEW.project_code := btrim(NEW.project_code);
  RETURN NEW;
END;
$$;
CREATE TRIGGER kb_decisoes_validar
  BEFORE INSERT OR UPDATE ON memoria.kb_decisoes
  FOR EACH ROW EXECUTE FUNCTION memoria.kb_decisoes_validar();

CREATE TABLE memoria.kb_sugestoes (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reuniao_id      uuid NOT NULL REFERENCES memoria.kb_itens(id) ON DELETE CASCADE,
  -- Decisão da reunião em que a sugestão se apoia (opcional).
  decisao_id      uuid REFERENCES memoria.kb_decisoes(id) ON DELETE SET NULL,
  tipo_destino    memoria.kb_tipo NOT NULL CHECK (tipo_destino <> 'reuniao_projeto'),
  titulo          text NOT NULL CHECK (btrim(titulo) <> ''),
  campos          jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(campos) = 'object'),
  tags            text[] NOT NULL DEFAULT '{}',
  justificativa   text,
  trecho_origem   text,
  status          text NOT NULL DEFAULT 'pendente' CHECK (status IN ('pendente', 'aprovada', 'rejeitada')),
  motivo_rejeicao text,
  item_criado_id  uuid REFERENCES memoria.kb_itens(id) ON DELETE SET NULL,
  criado_por      uuid DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  revisado_por    uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  revisado_em     timestamptz
);
CREATE INDEX kb_sugestoes_status_idx ON memoria.kb_sugestoes (status, created_at);
CREATE INDEX kb_sugestoes_reuniao_idx ON memoria.kb_sugestoes (reuniao_id);

CREATE FUNCTION memoria.kb_sugestoes_guardar()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = memoria, public
AS $$
BEGIN
  IF NEW.decisao_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM memoria.kb_decisoes d WHERE d.id = NEW.decisao_id AND d.excepcional
  ) THEN
    RAISE EXCEPTION 'Solução excepcional não pode virar padrão: sugestão bloqueada';
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.status <> 'pendente' OR NEW.item_criado_id IS NOT NULL THEN
      RAISE EXCEPTION 'Sugestão nasce pendente, sem item criado';
    END IF;
    NEW.revisado_por := NULL;
    NEW.revisado_em := NULL;
    RETURN NEW;
  END IF;

  -- UPDATE: conteúdo da sugestão é imutável; só a revisão muda.
  IF (NEW.reuniao_id, NEW.tipo_destino, NEW.titulo, NEW.campos, NEW.trecho_origem, NEW.criado_por, NEW.created_at)
     IS DISTINCT FROM
     (OLD.reuniao_id, OLD.tipo_destino, OLD.titulo, OLD.campos, OLD.trecho_origem, OLD.criado_por, OLD.created_at) THEN
    RAISE EXCEPTION 'O conteúdo de uma sugestão não pode ser alterado; ajuste no item ao aprovar';
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF OLD.status <> 'pendente' THEN
      RAISE EXCEPTION 'Sugestão já revisada';
    END IF;
    IF NEW.status = 'aprovada' AND NOT EXISTS (
      SELECT 1 FROM memoria.kb_itens i WHERE i.id = NEW.item_criado_id AND i.tipo = NEW.tipo_destino
    ) THEN
      RAISE EXCEPTION 'Aprovação exige o item criado pelo revisor no tema de destino';
    END IF;
    IF NEW.status = 'rejeitada' THEN
      NEW.item_criado_id := NULL;
    END IF;
    NEW.revisado_por := auth.uid();
    NEW.revisado_em := now();
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER kb_sugestoes_guardar
  BEFORE INSERT OR UPDATE ON memoria.kb_sugestoes
  FOR EACH ROW EXECUTE FUNCTION memoria.kb_sugestoes_guardar();

-- Quem pode editar um item (autor ou curador) — usado nas policies abaixo.
CREATE FUNCTION memoria.kb_pode_editar(p_item uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = memoria, public
AS $$
  SELECT memoria.kb_eh_interno() AND EXISTS (
    SELECT 1 FROM memoria.kb_itens i
    WHERE i.id = p_item AND (i.autor_id = auth.uid() OR memoria.kb_eh_curador())
  )
$$;
REVOKE ALL ON FUNCTION memoria.kb_pode_editar(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION memoria.kb_pode_editar(uuid) TO authenticated;

ALTER TABLE memoria.kb_decisoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE memoria.kb_sugestoes ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON memoria.kb_decisoes, memoria.kb_sugestoes TO authenticated;
GRANT ALL ON memoria.kb_decisoes, memoria.kb_sugestoes TO service_role;

-- Leitura: quem enxerga a reunião (o RLS de kb_itens decide).
CREATE POLICY kb_decisoes_select ON memoria.kb_decisoes
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM memoria.kb_itens i WHERE i.id = reuniao_id));
CREATE POLICY kb_decisoes_escrita ON memoria.kb_decisoes
  FOR ALL TO authenticated
  USING (memoria.kb_pode_editar(reuniao_id))
  WITH CHECK (memoria.kb_pode_editar(reuniao_id));

CREATE POLICY kb_sugestoes_select ON memoria.kb_sugestoes
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM memoria.kb_itens i WHERE i.id = reuniao_id));
CREATE POLICY kb_sugestoes_insert ON memoria.kb_sugestoes
  FOR INSERT TO authenticated
  WITH CHECK (criado_por = auth.uid() AND memoria.kb_pode_editar(reuniao_id));
CREATE POLICY kb_sugestoes_revisar ON memoria.kb_sugestoes
  FOR UPDATE TO authenticated
  USING (memoria.kb_eh_curador())
  WITH CHECK (memoria.kb_eh_curador());
-- Apagar: curador, ou quem criou enquanto ainda está pendente.
CREATE POLICY kb_sugestoes_delete ON memoria.kb_sugestoes
  FOR DELETE TO authenticated
  USING (memoria.kb_eh_curador() OR (status = 'pendente' AND criado_por = auth.uid()));

COMMIT;
