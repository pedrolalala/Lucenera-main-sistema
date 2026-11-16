-- SPEC-311: Venda Parcial — vincular outras vendas do cliente à mesma entrega.
-- Só informativo: numero_venda continua sendo a venda da parcial (vínculo, reserva, saldo).
BEGIN;

ALTER TABLE public.separacoes
  ADD COLUMN IF NOT EXISTS outras_vendas text;

COMMENT ON COLUMN public.separacoes.outras_vendas IS
  'SPEC-311: números de outras vendas (separados por vírgula) entregues junto com esta parcial. Informativo; não move estoque.';

COMMIT;
