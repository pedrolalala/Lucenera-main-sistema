-- Migration 20260928_167 - SPEC-167
--
-- Campo "Previsão de Entrega" no orçamento: uma data por orçamento,
-- opcional, preenchida manualmente no formulário do sistema Orçamentos
-- (Skip 32554) e exibida na lista de orçamentos.
--
-- Não reaproveita orcamentos.prazo_entrega_dias (integer, legado: 17 linhas,
-- todas = 27, sem uso em nenhum frontend) — o pedido é uma DATA.
-- Não entra na lista de campos de handle_orcamento_workflow que reiniciam a
-- aprovação (editar a previsão num orçamento aprovado não reseta o ciclo).
--
-- Rollback: ALTER TABLE public.orcamentos DROP COLUMN previsao_entrega;

ALTER TABLE public.orcamentos
  ADD COLUMN IF NOT EXISTS previsao_entrega date;

COMMENT ON COLUMN public.orcamentos.previsao_entrega IS
  'SPEC-167: previsão de entrega do orçamento (data informada manualmente, opcional).';
