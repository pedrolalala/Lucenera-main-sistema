-- Rollback SPEC-323 A3 (a cancelar_entrada_nota_compra volta pela migration 345; notas avulsas com quantidade ficam sem devolucao automatica)
BEGIN;
DROP FUNCTION IF EXISTS public.registrar_entrada_nota_avulsa(uuid, uuid, uuid, numeric, jsonb);
-- ALTER TABLE public.notas_fiscais_compra DROP COLUMN quantidade_avulsa;  -- so se nenhuma nota avulsa usou
COMMIT;
