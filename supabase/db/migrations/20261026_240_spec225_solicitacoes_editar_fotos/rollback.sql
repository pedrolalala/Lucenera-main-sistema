-- Rollback SPEC-225 (migration 240). Sem BEGIN/COMMIT.
-- Os arquivos já enviados ao bucket solicitacoes-anexos não são apagados aqui (apagar pelo painel do Supabase).

DROP POLICY IF EXISTS solicitacoes_anexos_storage_select ON storage.objects;
DROP POLICY IF EXISTS solicitacoes_anexos_storage_insert ON storage.objects;
DROP POLICY IF EXISTS solicitacoes_anexos_storage_delete ON storage.objects;
DROP TABLE IF EXISTS public.solicitacao_anexos;
DROP FUNCTION IF EXISTS public.solicitacao_pode_anexar_arquivo(text);
DROP FUNCTION IF EXISTS public.solicitacao_pode_anexar(uuid);
DROP FUNCTION IF EXISTS public.editar_minha_solicitacao(uuid, text, text, text, uuid);

CREATE POLICY "solicitacoes_update_autor_aberto" ON public.solicitacoes
  FOR UPDATE TO authenticated
  USING (((usuario_id = auth.uid()) AND (status = 'aberto'::text)))
  WITH CHECK ((usuario_id = auth.uid()));
