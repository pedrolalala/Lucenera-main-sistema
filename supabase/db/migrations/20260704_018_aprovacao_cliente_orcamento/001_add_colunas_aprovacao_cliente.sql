-- Migration 20260704_018 — Parte 1
-- Adiciona colunas de rastreio do ciclo de aprovação do cliente em orcamentos.
-- Todas idempotentes (IF NOT EXISTS / UNIQUE já trata reexecução).

ALTER TABLE public.orcamentos
    ADD COLUMN IF NOT EXISTS enviado_cliente_em      timestamptz,
    ADD COLUMN IF NOT EXISTS enviado_cliente_por     uuid REFERENCES auth.users(id),
    ADD COLUMN IF NOT EXISTS aprovado_cliente_em     timestamptz,
    ADD COLUMN IF NOT EXISTS recusado_cliente_em     timestamptz,
    ADD COLUMN IF NOT EXISTS motivo_recusa_cliente   text,
    ADD COLUMN IF NOT EXISTS token_aprovacao_cliente text;

-- Unique só se ainda não existir (idempotente via índice único)
CREATE UNIQUE INDEX IF NOT EXISTS uq_orcamentos_token_aprovacao_cliente
    ON public.orcamentos (token_aprovacao_cliente)
    WHERE token_aprovacao_cliente IS NOT NULL;

-- Índice de busca rápida por token (link de aprovação)
CREATE INDEX IF NOT EXISTS idx_orcamentos_token_aprovacao
    ON public.orcamentos (token_aprovacao_cliente)
    WHERE token_aprovacao_cliente IS NOT NULL;

COMMENT ON COLUMN public.orcamentos.enviado_cliente_em     IS 'Quando o orçamento foi enviado ao cliente pela última vez (status → enviado_cliente)';
COMMENT ON COLUMN public.orcamentos.enviado_cliente_por    IS 'Usuário interno que enviou o orçamento ao cliente';
COMMENT ON COLUMN public.orcamentos.aprovado_cliente_em    IS 'Quando o cliente aprovou o orçamento (status → aprovado_cliente)';
COMMENT ON COLUMN public.orcamentos.recusado_cliente_em    IS 'Quando o cliente recusou o orçamento (status → recusado_cliente)';
COMMENT ON COLUMN public.orcamentos.motivo_recusa_cliente  IS 'Motivo informado pelo cliente na recusa mais recente';
COMMENT ON COLUMN public.orcamentos.token_aprovacao_cliente IS 'Token de uso único gerado para o link de aprovação do cliente. Invalidado após uso.';
