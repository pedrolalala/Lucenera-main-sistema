BEGIN;
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
           WHERE n.nspname = 'backup' AND c.relkind = 'r'
  LOOP
    EXECUTE format('ALTER TABLE backup.%I SET SCHEMA public', r.relname);
  END LOOP;
END $$;
COMMIT;
