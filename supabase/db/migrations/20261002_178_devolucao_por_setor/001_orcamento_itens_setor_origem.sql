-- SPEC-178 (R3, 02/10/2026): cada linha de um orçamento de devolução guarda o
-- SETOR de onde a quantidade sai na venda de origem — uma linha por setor,
-- nunca somando setores. NULL = linha antiga (antes desta SPEC), aprovada pela
-- regra em cascata de registrar_devolucao_projeto_item.
-- Sem BEGIN/COMMIT no texto (aplicar com dry-run + rollback antes).

ALTER TABLE public.orcamento_itens
  ADD COLUMN IF NOT EXISTS setor_origem text;

ALTER TABLE public.orcamento_itens
  DROP CONSTRAINT IF EXISTS orcamento_itens_setor_origem_check;

ALTER TABLE public.orcamento_itens
  ADD CONSTRAINT orcamento_itens_setor_origem_check
  CHECK (setor_origem IS NULL OR setor_origem IN ('reserva', 'entrega_futura', 'em_separacao', 'entregue'));

COMMENT ON COLUMN public.orcamento_itens.setor_origem IS
  'SPEC-178: setor da venda de origem de onde sai a devolução (reserva, entrega_futura, em_separacao, entregue). Só em itens de devolução.';

-- Rollback: ALTER TABLE public.orcamento_itens DROP CONSTRAINT IF EXISTS orcamento_itens_setor_origem_check;
--           ALTER TABLE public.orcamento_itens DROP COLUMN IF EXISTS setor_origem;
