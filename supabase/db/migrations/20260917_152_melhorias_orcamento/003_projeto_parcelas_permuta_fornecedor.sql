-- SPEC-152 (item 6) — parcela paga por permuta precisa registrar QUEM é o
-- fornecedor da contrapartida (mesma mercadoria/serviço trocada em vez de
-- dinheiro) -- obrigatório na aplicação quando
-- projeto_parcelas.forma_pagamento = 'permuta' (não dá pra expressar como
-- CHECK simples porque forma_pagamento é um ENUM comum a todo o sistema;
-- validação fica em aprovar_orcamento_financeiro, ver 005).
--
-- Nullable no banco (parcela normal não tem fornecedor de permuta).

BEGIN;

ALTER TABLE public.projeto_parcelas
  ADD COLUMN IF NOT EXISTS permuta_fornecedor_id uuid REFERENCES public.contatos(id);

COMMENT ON COLUMN public.projeto_parcelas.permuta_fornecedor_id IS
  'SPEC-152: fornecedor da contrapartida quando forma_pagamento = ''permuta'' (contatos.tipo = ''fornecedor''). Obrigatório nesse caso, validado em aprovar_orcamento_financeiro -- não há CHECK de banco porque forma_pagamento é enum compartilhado por todo o sistema.';

COMMIT;
