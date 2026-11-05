-- Rollback da 265: volta a NULL só o que a 265 preencheu (os 6 nomes abaixo).
BEGIN;
UPDATE public.funcionarios SET nm_connect = NULL
 WHERE nm_connect IN ('FILIPPO', 'HELENA FOGAÇA', 'MATHEUS', 'RAFAELA NETTO', 'VITORIA LIDIA', 'TEREZINHA');
COMMIT;
