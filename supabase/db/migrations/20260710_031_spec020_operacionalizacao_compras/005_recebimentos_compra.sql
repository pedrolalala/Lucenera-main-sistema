-- Migration 20260710_031 - SPEC-020 Parte 5
-- SPEC-EST-12: recebimentos_compra + recebimento_itens — conferencia de chegada do material.
-- Idempotente: usa IF NOT EXISTS em todas as operacoes.

CREATE TABLE IF NOT EXISTS public.recebimentos_compra (
    id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    pedido_id        uuid NOT NULL REFERENCES public.pedidos_compra(id) ON DELETE RESTRICT,
    numero_nota      text,
    data_recebimento date NOT NULL DEFAULT CURRENT_DATE,
    observacao       text,
    recebido_por     uuid REFERENCES auth.users(id),
    criado_em        timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.recebimentos_compra ADD COLUMN IF NOT EXISTS numero_nota      text;
ALTER TABLE public.recebimentos_compra ADD COLUMN IF NOT EXISTS data_recebimento date NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE public.recebimentos_compra ADD COLUMN IF NOT EXISTS observacao       text;
ALTER TABLE public.recebimentos_compra ADD COLUMN IF NOT EXISTS recebido_por     uuid REFERENCES auth.users(id);
ALTER TABLE public.recebimentos_compra ADD COLUMN IF NOT EXISTS criado_em        timestamptz NOT NULL DEFAULT now();

COMMENT ON TABLE public.recebimentos_compra IS
'SPEC-020 / SPEC-EST-12. Registro de chegada de material contra pedido_compra. Itens em recebimento_itens.';

CREATE INDEX IF NOT EXISTS idx_rec_pedido ON public.recebimentos_compra (pedido_id);

ALTER TABLE public.recebimentos_compra ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS authenticated_select_recebimentos_compra ON public.recebimentos_compra;
CREATE POLICY authenticated_select_recebimentos_compra
  ON public.recebimentos_compra
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);

GRANT SELECT ON TABLE public.recebimentos_compra TO authenticated;

-- -----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.recebimento_itens (
    id                   uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    recebimento_id       uuid NOT NULL REFERENCES public.recebimentos_compra(id) ON DELETE CASCADE,
    pedido_item_id       uuid NOT NULL REFERENCES public.pedido_compra_itens(id) ON DELETE RESTRICT,
    produto_id           uuid NOT NULL REFERENCES public.produtos(id) ON DELETE RESTRICT,
    quantidade_recebida  numeric(10,3) NOT NULL CHECK (quantidade_recebida > 0),
    divergencia          text,
    criado_em            timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.recebimento_itens ADD COLUMN IF NOT EXISTS divergencia text;
ALTER TABLE public.recebimento_itens ADD COLUMN IF NOT EXISTS criado_em   timestamptz NOT NULL DEFAULT now();

COMMENT ON TABLE public.recebimento_itens IS
'SPEC-020 / SPEC-EST-12. Itens conferidos no recebimento. divergencia registra diferenca de quantidade ou especificacao.';

CREATE INDEX IF NOT EXISTS idx_ri_recebimento ON public.recebimento_itens (recebimento_id);
CREATE INDEX IF NOT EXISTS idx_ri_pedido_item ON public.recebimento_itens (pedido_item_id);
CREATE INDEX IF NOT EXISTS idx_ri_produto     ON public.recebimento_itens (produto_id);

ALTER TABLE public.recebimento_itens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS authenticated_select_recebimento_itens ON public.recebimento_itens;
CREATE POLICY authenticated_select_recebimento_itens
  ON public.recebimento_itens
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);

GRANT SELECT ON TABLE public.recebimento_itens TO authenticated;
