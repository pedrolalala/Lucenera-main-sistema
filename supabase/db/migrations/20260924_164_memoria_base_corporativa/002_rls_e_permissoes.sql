-- SPEC-164 — RLS corporativo da base de conhecimento (decisão 2026-09-24:
-- "todos leem, autor edita").
--
--   Ler:     usuário interno ativo (public.usuarios.ativo) vê tudo que está
--            publicado; rascunho/arquivado só o autor e o curador.
--   Criar:   qualquer usuário interno ativo (sempre como autor de si mesmo).
--   Editar:  o autor ou um curador.
--   Apagar:  só curador (o app arquiva em vez de apagar).
--   Curador: permissão do Hub — hub_pode_executar(uid, 'memoria', NULL,
--            'aprovar'). Concedida aqui aos papéis admin e admin_geral; o
--            Hub pode estender a outros papéis ou pessoas sem migration.
--
-- As tabelas antigas (knowledge_items, entities, ...) continuam com o RLS
-- por dono, sem alteração.

BEGIN;

CREATE FUNCTION memoria.kb_eh_interno()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM public.usuarios u WHERE u.id = auth.uid() AND coalesce(u.ativo, true))
$$;

CREATE FUNCTION memoria.kb_eh_curador()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT auth.uid() IS NOT NULL AND public.hub_pode_executar(auth.uid(), 'memoria', NULL, 'aprovar')
$$;

REVOKE ALL ON FUNCTION memoria.kb_eh_interno() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION memoria.kb_eh_curador() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION memoria.kb_eh_interno() TO authenticated;
GRANT EXECUTE ON FUNCTION memoria.kb_eh_curador() TO authenticated;
GRANT EXECUTE ON FUNCTION memoria.kb_norm(text) TO authenticated;
GRANT EXECUTE ON FUNCTION memoria.kb_categoria_do_tipo(memoria.kb_tipo) TO authenticated;

-- kb_itens -----------------------------------------------------------------
ALTER TABLE memoria.kb_itens ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON memoria.kb_itens TO authenticated;

CREATE POLICY kb_itens_select ON memoria.kb_itens
  FOR SELECT TO authenticated
  USING (memoria.kb_eh_interno()
         AND (status = 'publicado' OR autor_id = auth.uid() OR memoria.kb_eh_curador()));

-- Pelo app só entra conteúdo manual; importação roda com service role.
CREATE POLICY kb_itens_insert ON memoria.kb_itens
  FOR INSERT TO authenticated
  WITH CHECK (memoria.kb_eh_interno() AND autor_id = auth.uid() AND origem = 'manual');

CREATE POLICY kb_itens_update ON memoria.kb_itens
  FOR UPDATE TO authenticated
  USING (memoria.kb_eh_interno() AND (autor_id = auth.uid() OR memoria.kb_eh_curador()))
  WITH CHECK (memoria.kb_eh_interno() AND (autor_id = auth.uid() OR memoria.kb_eh_curador()));

CREATE POLICY kb_itens_delete ON memoria.kb_itens
  FOR DELETE TO authenticated
  USING (memoria.kb_eh_curador());

-- kb_itens_versoes (gravada só pelo trigger SECURITY DEFINER) ---------------
ALTER TABLE memoria.kb_itens_versoes ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON memoria.kb_itens_versoes TO authenticated;

CREATE POLICY kb_itens_versoes_select ON memoria.kb_itens_versoes
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM memoria.kb_itens i WHERE i.id = item_id));

-- kb_anexos: visível se o item é visível; mexe quem pode editar o item -----
ALTER TABLE memoria.kb_anexos ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON memoria.kb_anexos TO authenticated;

CREATE POLICY kb_anexos_select ON memoria.kb_anexos
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM memoria.kb_itens i WHERE i.id = item_id));

CREATE POLICY kb_anexos_insert ON memoria.kb_anexos
  FOR INSERT TO authenticated
  WITH CHECK (autor_id = auth.uid()
              AND EXISTS (SELECT 1 FROM memoria.kb_itens i
                          WHERE i.id = item_id
                            AND (i.autor_id = auth.uid() OR memoria.kb_eh_curador())));

CREATE POLICY kb_anexos_update ON memoria.kb_anexos
  FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM memoria.kb_itens i
                 WHERE i.id = item_id AND (i.autor_id = auth.uid() OR memoria.kb_eh_curador())));

CREATE POLICY kb_anexos_delete ON memoria.kb_anexos
  FOR DELETE TO authenticated
  USING (autor_id = auth.uid() OR memoria.kb_eh_curador());

-- kb_sinonimos: todos leem; curador mantém ---------------------------------
ALTER TABLE memoria.kb_sinonimos ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON memoria.kb_sinonimos TO authenticated;

CREATE POLICY kb_sinonimos_select ON memoria.kb_sinonimos
  FOR SELECT TO authenticated USING (memoria.kb_eh_interno());
CREATE POLICY kb_sinonimos_write ON memoria.kb_sinonimos
  FOR ALL TO authenticated USING (memoria.kb_eh_curador()) WITH CHECK (memoria.kb_eh_curador());

-- Storage: anexos da base corporativa no prefixo kb/ do bucket existente.
-- A policy antiga (pasta <uid>/) continua valendo para os arquivos do app antigo.
CREATE POLICY memoria_kb_anexos_read ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'lucenera-memory-files' AND name LIKE 'kb/%' AND memoria.kb_eh_interno());

CREATE POLICY memoria_kb_anexos_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'lucenera-memory-files' AND name LIKE 'kb/%' AND memoria.kb_eh_interno());

CREATE POLICY memoria_kb_anexos_delete ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'lucenera-memory-files' AND name LIKE 'kb/%'
         AND (owner = auth.uid() OR memoria.kb_eh_curador()));

-- Hub: papel de curador ('aprovar' no sistema memoria) para admin e admin_geral.
-- Não cria 'visualizar' — o tile continua como está hoje (SPEC-129).
INSERT INTO public.papel_permissoes (papel_id, system_id, modulo_id, acao)
SELECT p.id, s.id, NULL, 'aprovar'
FROM public.papeis p
CROSS JOIN public.systems s
WHERE p.nome IN ('admin', 'admin_geral')
  AND s.slug = 'memoria'
  AND NOT EXISTS (
    SELECT 1 FROM public.papel_permissoes pp
    WHERE pp.papel_id = p.id AND pp.system_id = s.id AND pp.modulo_id IS NULL AND pp.acao = 'aprovar'
  );

COMMIT;
