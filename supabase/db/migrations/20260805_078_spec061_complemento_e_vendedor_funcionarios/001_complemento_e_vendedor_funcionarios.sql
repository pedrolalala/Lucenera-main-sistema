-- Migration 20260805_078 - SPEC-061
--
-- 1. Campo "Complemento" nos 3 blocos de endereco de contatos (principal,
--    entrega, cobranca) -- hoje so existe numero/numero_entrega/
--    numero_cobranca, sem complemento em nenhum bloco.
ALTER TABLE public.contatos
  ADD COLUMN IF NOT EXISTS complemento text,
  ADD COLUMN IF NOT EXISTS complemento_entrega text,
  ADD COLUMN IF NOT EXISTS complemento_cobranca text;

-- 2. contatos.vendedor_id/vendedor_padrao_id passam a apontar para
--    public.funcionarios(id) em vez de auth.users(id) -- decisao do
--    usuario em 2026-08-05. Checado antes de aplicar: 0 linhas em
--    `contatos` tem vendedor_id ou vendedor_padrao_id preenchido hoje,
--    entao nao ha risco de FK orfa / nao precisa de backfill.
ALTER TABLE public.contatos
  DROP CONSTRAINT IF EXISTS contatos_vendedor_id_fkey;

ALTER TABLE public.contatos
  DROP CONSTRAINT IF EXISTS contatos_vendedor_padrao_id_fkey;

ALTER TABLE public.contatos
  ADD CONSTRAINT contatos_vendedor_id_fkey
    FOREIGN KEY (vendedor_id) REFERENCES public.funcionarios(id);

ALTER TABLE public.contatos
  ADD CONSTRAINT contatos_vendedor_padrao_id_fkey
    FOREIGN KEY (vendedor_padrao_id) REFERENCES public.funcionarios(id);
