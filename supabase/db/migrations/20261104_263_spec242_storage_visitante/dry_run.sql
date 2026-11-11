-- Dry-run da 263: mostra as políticas antes, roda o mesmo bloco e mostra depois. Termina em ROLLBACK (sem COMMIT).
BEGIN;

SELECT id, public FROM storage.buckets ORDER BY id;
SELECT policyname, cmd, roles, qual, with_check FROM pg_policies
WHERE schemaname = 'storage' AND tablename = 'objects' ORDER BY policyname;

UPDATE storage.buckets SET public = false WHERE id = 'orcamentos';
DO $$
DECLARE
  p record;
  docs text[] := ARRAY['orcamentos','notas_fiscais','notas_fiscais_compra','producao_pedidos','garantia_anexos'];
  b text; alvo boolean;
BEGIN
  FOR p IN SELECT policyname, cmd, roles, coalesce(qual, '') || ' ' || coalesce(with_check, '') AS cond
           FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects'
  LOOP
    alvo := false;
    FOREACH b IN ARRAY docs LOOP IF p.cond LIKE '%''' || b || '''%' THEN alvo := true; END IF; END LOOP;
    CONTINUE WHEN NOT alvo;
    IF p.cond LIKE '%''orcamentos''%' THEN
      EXECUTE format('DROP POLICY %I ON storage.objects', p.policyname); RAISE NOTICE 'apagada: %', p.policyname;
    ELSIF 'anon' = ANY (p.roles) OR 'public' = ANY (p.roles) THEN
      IF p.cmd = 'SELECT' THEN
        EXECUTE format('ALTER POLICY %I ON storage.objects TO authenticated', p.policyname); RAISE NOTICE 'só logado: %', p.policyname;
      ELSE
        EXECUTE format('DROP POLICY %I ON storage.objects', p.policyname); RAISE NOTICE 'apagada: %', p.policyname;
      END IF;
    END IF;
  END LOOP;
END $$;

SELECT policyname, cmd, roles, qual FROM pg_policies
WHERE schemaname = 'storage' AND tablename = 'objects' ORDER BY policyname;

-- visitante não lista mais nada nos buckets de documento
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{"role":"anon"}', true);
SELECT bucket_id, count(*) AS visitante_ve FROM storage.objects
WHERE bucket_id IN ('orcamentos','notas_fiscais','notas_fiscais_compra','producao_pedidos','garantia_anexos')
GROUP BY 1;
RESET ROLE;

ROLLBACK;
