-- Migration 20260710_031 - SPEC-020 Parte 3
-- SPEC-EST-08: cotacoes_compra + cotacao_itens — propostas de fornecedor por solicitacao.
-- Idempotente: usa IF NOT EXISTS em todas as operacoes.

CREATE TABLE IF NOT EXISTS public.cotacoes_compra (
    id                   uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    numero               text NOT NULL,
    fornecedor_id        uuid NOT NULL REFERENCES public.contatos(id) ON DELETE RESTRICT,
    status               text NOT NULL DEFAULT 'em_andamento'
                         CHECK (status IN ('em_andamento', 'recebida', 'aprovada', 'rejeitada', 'cancelada')),
    validade             date,
    condicoes_pagamento  text,
    observacao           text,
    criado_por           uuid REFERENCES auth.users(id),
    criado_em            timestamptz NOT NULL DEFAULT now(),
    atualizado_em        timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.cotacoes_compra ADD COLUMN IF NOT EXISTS numero              text;
ALTER TABLE public.cotacoes_compra ADD COLUMN IF NOT EXISTS validade            date;
ALTER TABLE public.cotacoes_compra ADD COLUMN IF NOT EXISTS condicoes_pagamento text;
ALTER TABLE public.cotacoes_compra ADD COLUMN IF NOT EXISTS observacao          text;
ALTER TABLE public.cotacoes_compra ADD COLUMN IF NOT EXISTS criado_por          uuid REFERENCES auth.users(id);
ALTER TABLE public.cotacoes_compra ADD COLUMN IF NOT EXISTS criado_em           timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.cotacoes_compra ADD COLUMN IF NOT EXISTS atualizado_em       timestamptz NOT NULL DEFAULT now();

COMMENT ON TABLE public.cotacoes_compra IS
'SPEC-020 / SPEC-EST-08. Cotacao de compra por fornecedor. Itens em cotacao_itens.';

CREATE INDEX IF NOT EXISTS idx_cot_fornecedor ON public.cotacoes_compra (fornecedor_id);
CREATE INDEX IF NOT EXISTS idx_cot_status     ON public.cotacoes_compra (status);

ALTER TABLE public.cotacoes_compra ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS authenticated_select_cotacoes_compra ON public.cotacoes_compra;
CREATE POLICY authenticated_select_cotacoes_compra
  ON public.cotacoes_compra
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);

GRANT SELECT ON TABLE public.cotacoes_compra TO authenticated;

-- -----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.cotacao_itens (
    id                   uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    cotacao_id           uuid NOT NULL REFERENCES public.cotacoes_compra(id) ON DELETE CASCADE,
    solicitacao_id       uuid REFERENCES public.solicitacoes_compra(id) ON DELETE SET NULL,
    produto_id           uuid NOT NULL REFERENCES public.produtos(id) ON DELETE RESTRICT,
    quantidade           numeric(10,3) NOT NULL CHECK (quantidade > 0),
    custo_unitario       numeric(12,4),
    prazo_entrega_dias   integer CHECK (prazo_entrega_dias >= 0),
    descricao_fornecedor text,
    ncm                  text,
    observacao           text,
    criado_em            timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.cotacao_itens ADD COLUMN IF NOT EXISTS solicitacao_id       uuid REFERENCES public.solicitacoes_compra(id) ON DELETE SET NULL;
ALTER TABLE public.cotacao_itens ADD COLUMN IF NOT EXISTS custo_unitario       numeric(12,4);
ALTER TABLE public.cotacao_itens ADD COLUMN IF NOT EXISTS prazo_entrega_dias   integer;
ALTER TABLE public.cotacao_itens ADD COLUMN IF NOT EXISTS descricao_fornecedor text;
ALTER TABLE public.cotacao_itens ADD COLUMN IF NOT EXISTS ncm                  text;
ALTER TABLE public.cotacao_itens ADD COLUMN IF NOT EXISTS observacao           text;

COMMENT ON TABLE public.cotacao_itens IS
'SPEC-020 / SPEC-EST-08. Itens de cotacao. Referencia opcional a solicitacao_id para rastreabilidade.';

CREATE INDEX IF NOT EXISTS idx_ci_cotacao     ON public.cotacao_itens (cotacao_id);
CREATE INDEX IF NOT EXISTS idx_ci_solicitacao ON public.cotacao_itens (solicitacao_id);
CREATE INDEX IF NOT EXISTS idx_ci_produto     ON public.cotacao_itens (produto_id);

ALTER TABLE public.cotacao_itens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS authenticated_select_cotacao_itens ON public.cotacao_itens;
CREATE POLICY authenticated_select_cotacao_itens
  ON public.cotacao_itens
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);

GRANT SELECT ON TABLE public.cotacao_itens TO authenticated;
