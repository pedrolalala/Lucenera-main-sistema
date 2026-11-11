-- Rollback da 263: bucket orcamentos público de novo e leitura por qualquer um nos buckets de documento.
-- As políticas apagadas do orcamentos são recriadas com os nomes do snapshot (06_storage.sql).
-- A escrita de visitante NÃO volta (era o furo).
BEGIN;

UPDATE storage.buckets SET public = true WHERE id = 'orcamentos';

DROP POLICY IF EXISTS orcamentos_public_read ON storage.objects;
CREATE POLICY orcamentos_public_read ON storage.objects FOR SELECT USING (bucket_id = 'orcamentos');
DROP POLICY IF EXISTS orcamentos_authenticated_insert ON storage.objects;
CREATE POLICY orcamentos_authenticated_insert ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'orcamentos');
DROP POLICY IF EXISTS orcamentos_authenticated_update ON storage.objects;
CREATE POLICY orcamentos_authenticated_update ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'orcamentos');

DO $$
DECLARE p record;
BEGIN
  FOR p IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects' AND cmd = 'SELECT' AND roles = '{authenticated}'
      AND (qual LIKE '%''notas_fiscais''%' OR qual LIKE '%''notas_fiscais_compra''%'
           OR qual LIKE '%''producao_pedidos''%' OR qual LIKE '%''garantia_anexos''%')
  LOOP
    EXECUTE format('ALTER POLICY %I ON storage.objects TO public', p.policyname);
  END LOOP;
END $$;

COMMIT;
