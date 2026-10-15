-- Cópias de segurança (_bkp_*, *_backup_migration) saem do schema public:
-- ficam no schema "backup", fora do Table Editor padrão e da API (PostgREST
-- só expõe public). Só postgres/service_role enxergam.
BEGIN;
CREATE SCHEMA IF NOT EXISTS backup;
REVOKE ALL ON SCHEMA backup FROM PUBLIC, anon, authenticated;
COMMENT ON SCHEMA backup IS 'Cópias de segurança feitas antes de limpezas/migrations. Não é usado pelos sistemas.';
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind = 'r'
      AND (c.relname LIKE '\_bkp\_%' OR c.relname LIKE '%\_backup\_migration')
  LOOP
    EXECUTE format('ALTER TABLE public.%I SET SCHEMA backup', r.relname);
  END LOOP;
END $$;
COMMIT;
