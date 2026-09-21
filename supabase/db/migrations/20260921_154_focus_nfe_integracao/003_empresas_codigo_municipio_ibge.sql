-- SPEC-154: endereço fiscal do emitente exige o código IBGE do município
-- (campo `codigo_municipio` no payload NF-e/Focus). `public.empresas` não
-- tem esse dado hoje -- confirmado tanto no snapshot
-- supabase/db/current/01_schema_full.sql (linha ~4724) quanto direto no
-- banco em 2026-09-21.
--
-- RASCUNHO -- NÃO aplicar sem execução manual do usuário. Preenchimento
-- real é passo manual do usuário (ver "Passos manuais" da SPEC-154) --
-- nullable de propósito, para não travar nada que já usa `empresas` hoje.

BEGIN;

ALTER TABLE public.empresas
  ADD COLUMN IF NOT EXISTS codigo_municipio_ibge text;

COMMENT ON COLUMN public.empresas.codigo_municipio_ibge IS
  'SPEC-154. Código IBGE do município da empresa emitente (7 dígitos), exigido no payload NF-e/Focus (emitente.codigo_municipio). Nullable -- preenchimento manual do usuário por empresa antes da primeira emissão real via emitir-nota-fiscal.';

NOTIFY pgrst, 'reload schema';

COMMIT;
