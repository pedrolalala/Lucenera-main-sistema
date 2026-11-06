-- SPEC-254: desfaz os anexos do orçamento. ATENÇÃO: apaga os registros; os arquivos do bucket precisam ser removidos antes (o Supabase não deixa apagar bucket com arquivos).
DROP POLICY IF EXISTS spec254_orc_anexos_storage_select ON storage.objects;
DROP POLICY IF EXISTS spec254_orc_anexos_storage_insert ON storage.objects;
DROP POLICY IF EXISTS spec254_orc_anexos_storage_delete ON storage.objects;
DROP FUNCTION IF EXISTS public.orcamento_anexo_pode_acessar(text, boolean);
DROP TABLE IF EXISTS public.orcamento_anexos;
DELETE FROM storage.buckets WHERE id = 'orcamento-anexos';
