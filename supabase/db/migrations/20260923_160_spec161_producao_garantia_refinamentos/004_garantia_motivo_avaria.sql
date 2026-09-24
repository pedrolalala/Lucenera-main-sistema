-- SPEC-161 Prioridade 9 — Controle de Garantia: motivo "Avaria" (dano na
-- entrega/transporte, peça chegou quebrada).

BEGIN;

ALTER TABLE public.garantia_itens
  DROP CONSTRAINT garantia_itens_motivo_check;

ALTER TABLE public.garantia_itens
  ADD CONSTRAINT garantia_itens_motivo_check
  CHECK (motivo IN ('queimou', 'sobrecarga_mau_uso', 'envio_errado', 'producao_errada', 'avaria', 'outro'));

COMMIT;
