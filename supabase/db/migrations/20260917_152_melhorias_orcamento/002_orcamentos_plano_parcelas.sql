-- SPEC-152 (item 5/7) — Opção B decidida pelo usuário (2026-09-17):
-- orcamentos.plano_parcelas jsonb, array de
-- {numero, dias_offset, valor, forma_pagamento, permuta_fornecedor_id},
-- substituindo gradualmente prazo_pagamento_dias como fonte de valor de
-- cada parcela (não remove prazo_pagamento_dias -- continua sendo gravado
-- em paralelo pelo frontend, só deixa de ser a única fonte de verdade).
--
-- Nullable, sem backfill: orçamento salvo antes desta SPEC continua sem
-- plano_parcelas (NULL) e aprovar_orcamento_financeiro cai de volta na
-- divisão igual já existente, exatamente como hoje.
--
-- Precisa rodar DEPOIS de 001_enum_carteira_e_permuta.sql já commitado
-- (não referencia o enum diretamente, mas faz parte do mesmo conjunto
-- funcional consumido pela função de aprovação em 005).

BEGIN;

ALTER TABLE public.orcamentos
  ADD COLUMN IF NOT EXISTS plano_parcelas jsonb;

COMMENT ON COLUMN public.orcamentos.plano_parcelas IS
  'SPEC-152: array de {numero, dias_offset, valor, forma_pagamento, permuta_fornecedor_id} -- valor/forma de pagamento customizados por parcela, substitui gradualmente prazo_pagamento_dias como fonte de valor. NULL = comportamento legado (divisão igual de valor_total).';

COMMIT;
