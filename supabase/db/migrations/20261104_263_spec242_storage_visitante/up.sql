-- SPEC-242 A2: storage — visitante (anon) listava e podia enviar arquivo nos buckets de documento.
-- 1) `orcamentos` vira privado: só a Edge Function process-budget-pdf (service_role) grava/lê e manda link com
--    prazo (createSignedUrl). Nenhuma tela usa storage.from('orcamentos') (conferido 04/11). Todas as políticas
--    desse bucket saem (inclusive "Anon can upload" e "Public Access").
-- 2) Nos outros buckets de documento, leitura/listagem por política passa a ser só de logado. Os buckets
--    continuam públicos nesta fase, então os links já gravados nas tabelas seguem abrindo (o endpoint público
--    não passa pelo RLS). Tornar privados + link com prazo nas telas = SPEC-242 fase B.
-- Fotos públicas de propósito (showroom-lucenera, revenda-ubiqua-images) não são tocadas.
-- Os nomes das políticas no banco podem diferir do snapshot: o bloco procura pelo bucket na condição.
BEGIN;

UPDATE storage.buckets SET public = false WHERE id = 'orcamentos';

DO $$
DECLARE
  p record;
  docs text[] := ARRAY['orcamentos','notas_fiscais','notas_fiscais_compra','producao_pedidos','garantia_anexos'];
  b text;
  alvo boolean;
BEGIN
  FOR p IN
    SELECT policyname, cmd, roles, coalesce(qual, '') || ' ' || coalesce(with_check, '') AS cond
    FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects'
  LOOP
    alvo := false;
    FOREACH b IN ARRAY docs LOOP
      IF p.cond LIKE '%''' || b || '''%' THEN alvo := true; END IF;
    END LOOP;
    CONTINUE WHEN NOT alvo;

    IF p.cond LIKE '%''orcamentos''%' THEN
      EXECUTE format('DROP POLICY %I ON storage.objects', p.policyname);
      RAISE NOTICE 'apagada (orcamentos): %', p.policyname;
    ELSIF 'anon' = ANY (p.roles) OR 'public' = ANY (p.roles) THEN
      IF p.cmd = 'SELECT' THEN
        EXECUTE format('ALTER POLICY %I ON storage.objects TO authenticated', p.policyname);
        RAISE NOTICE 'só logado: %', p.policyname;
      ELSE
        EXECUTE format('DROP POLICY %I ON storage.objects', p.policyname);
        RAISE NOTICE 'apagada (escrita de visitante): %', p.policyname;
      END IF;
    END IF;
  END LOOP;
END $$;

COMMIT;
