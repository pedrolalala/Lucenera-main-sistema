-- SPEC-052: usuário confirmou (2026-08-04) as duas únicas opções de
-- "Regime de Apuração" do sistema de referência: Simples Nacional e Regime
-- Normal. `contatos.regime_apuracao` era texto livre (nenhuma linha
-- preenchida ainda, confirmado antes de aplicar) porque o print anterior só
-- mostrava o campo fechado. Mesmo padrão de `tipo_pessoa`/`tipo_cliente`:
-- varchar existente + CHECK, sem ENUM novo.

ALTER TABLE public.contatos
  ADD CONSTRAINT contatos_regime_apuracao_check
  CHECK (
    regime_apuracao IS NULL
    OR regime_apuracao = ANY (ARRAY['simples_nacional', 'regime_normal']::text[])
  );

COMMENT ON COLUMN public.contatos.regime_apuracao IS
  'Regime tributário do cliente (SPEC-052): simples_nacional ou regime_normal. Opções confirmadas pelo usuário em 2026-08-04 (antes era texto livre, sem opções fixas).';
