-- Migration 20260710_031 - SPEC-020 Parte 4
-- SPEC-EST-09: pedidos_compra + pedido_compra_itens — pedido oficial de compra.
-- NOTA: o escopo cita "0 registros em pedido_compra" (tabela pode existir vazia).
-- Idempotente: usa IF NOT EXISTS em todas as operacoes.

CREATE TABLE IF NOT EXISTS public.pedidos_compra (
    id                      uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    numero                  text NOT NULL,
    fornecedor_id           uuid NOT NULL REFERENCES public.contatos(id) ON DELETE RESTRICT,
    cotacao_id              uuid REFERENCES public.cotacoes_compra(id) ON DELETE SET NULL,
    status                  text NOT NULL DEFAULT 'rascunho'
                            CHECK (status IN ('rascunho', 'aprovado', 'enviado',
                                              'parcialmente_recebido', 'recebido', 'cancelado')),
    data_emissao            date NOT NULL DEFAULT CURRENT_DATE,
    data_prevista_entrega   date,
    condicoes_pagamento     text,
    valor_total             numeric(12,2),
    observacao              text,
    aprovado_por            uuid REFERENCES auth.users(id),
    aprovado_em             timestamptz,
    criado_por              uuid REFERENCES auth.users(id),
    criado_em               timestamptz NOT NULL DEFAULT now(),
    atualizado_em           timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.pedidos_compra ADD COLUMN IF NOT EXISTS numero                text;
ALTER TABLE public.pedidos_compra ADD COLUMN IF NOT EXISTS cotacao_id            uuid REFERENCES public.cotacoes_compra(id) ON DELETE SET NULL;
ALTER TABLE public.pedidos_compra ADD COLUMN IF NOT EXISTS data_emissao          date NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE public.pedidos_compra ADD COLUMN IF NOT EXISTS data_prevista_entrega date;
ALTER TABLE public.pedidos_compra ADD COLUMN IF NOT EXISTS condicoes_pagamento   text;
ALTER TABLE public.pedidos_compra ADD COLUMN IF NOT EXISTS valor_total           numeric(12,2);
ALTER TABLE public.pedidos_compra ADD COLUMN IF NOT EXISTS observacao            text;
ALTER TABLE public.pedidos_compra ADD COLUMN IF NOT EXISTS aprovado_por          uuid REFERENCES auth.users(id);
ALTER TABLE public.pedidos_compra ADD COLUMN IF NOT EXISTS aprovado_em           timestamptz;
ALTER TABLE public.pedidos_compra ADD COLUMN IF NOT EXISTS criado_por            uuid REFERENCES auth.users(id);
ALTER TABLE public.pedidos_compra ADD COLUMN IF NOT EXISTS criado_em             timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.pedidos_compra ADD COLUMN IF NOT EXISTS atualizado_em         timestamptz NOT NULL DEFAULT now();

COMMENT ON TABLE public.pedidos_compra IS
'SPEC-020 / SPEC-EST-09. Pedido oficial de compra. Itens em pedido_compra_itens. Status acompanha recebimento via RPC.';

CREATE INDEX IF NOT EXISTS idx_pc_fornecedor ON public.pedidos_compra (fornecedor_id);
CREATE INDEX IF NOT EXISTS idx_pc_cotacao    ON public.pedidos_compra (cotacao_id);
CREATE INDEX IF NOT EXISTS idx_pc_status     ON public.pedidos_compra (status);

ALTER TABLE public.pedidos_compra ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS authenticated_select_pedidos_compra ON public.pedidos_compra;
CREATE POLICY authenticated_select_pedidos_compra
  ON public.pedidos_compra
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);

GRANT SELECT ON TABLE public.pedidos_compra TO authenticated;

-- -----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.pedido_compra_itens (
    id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    pedido_id        uuid NOT NULL REFERENCES public.pedidos_compra(id) ON DELETE CASCADE,
    solicitacao_id   uuid REFERENCES public.solicitacoes_compra(id) ON DELETE SET NULL,
    produto_id       uuid NOT NULL REFERENCES public.produtos(id) ON DELETE RESTRICT,
    quantidade       numeric(10,3) NOT NULL CHECK (quantidade > 0),
    qtd_recebida     numeric(10,3) NOT NULL DEFAULT 0 CHECK (qtd_recebida >= 0),
    custo_unitario   numeric(12,4) NOT NULL,
    observacao       text,
    criado_em        timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.pedido_compra_itens ADD COLUMN IF NOT EXISTS solicitacao_id uuid REFERENCES public.solicitacoes_compra(id) ON DELETE SET NULL;
ALTER TABLE public.pedido_compra_itens ADD COLUMN IF NOT EXISTS qtd_recebida   numeric(10,3) NOT NULL DEFAULT 0;
ALTER TABLE public.pedido_compra_itens ADD COLUMN IF NOT EXISTS custo_unitario numeric(12,4);
ALTER TABLE public.pedido_compra_itens ADD COLUMN IF NOT EXISTS observacao     text;
ALTER TABLE public.pedido_compra_itens ADD COLUMN IF NOT EXISTS criado_em      timestamptz NOT NULL DEFAULT now();

COMMENT ON TABLE public.pedido_compra_itens IS
'SPEC-020 / SPEC-EST-09. Itens do pedido de compra. qtd_recebida atualizada pela RPC registrar_recebimento_compra.';

CREATE INDEX IF NOT EXISTS idx_pci_pedido      ON public.pedido_compra_itens (pedido_id);
CREATE INDEX IF NOT EXISTS idx_pci_solicitacao ON public.pedido_compra_itens (solicitacao_id);
CREATE INDEX IF NOT EXISTS idx_pci_produto     ON public.pedido_compra_itens (produto_id);

ALTER TABLE public.pedido_compra_itens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS authenticated_select_pedido_compra_itens ON public.pedido_compra_itens;
CREATE POLICY authenticated_select_pedido_compra_itens
  ON public.pedido_compra_itens
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);

GRANT SELECT ON TABLE public.pedido_compra_itens TO authenticated;
