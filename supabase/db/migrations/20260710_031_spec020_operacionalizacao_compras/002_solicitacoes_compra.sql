-- Migration 20260710_031 - SPEC-020 Parte 2
-- SPEC-EST-07: solicitacoes_compra — formaliza a necessidade por produto.
-- Sem vinculo fixo a cliente/projeto: a compra e agregada por produto (decisao reuniao 08).
-- NOTA: tabela ja pode existir vazia no banco (escopo cita "0 registros em solicitacoes_compra").
-- Este script e idempotente: usa IF NOT EXISTS em todas as operacoes.

CREATE TABLE IF NOT EXISTS public.solicitacoes_compra (
    id              uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    produto_id      uuid NOT NULL REFERENCES public.produtos(id) ON DELETE RESTRICT,
    quantidade      numeric(10,3) NOT NULL CHECK (quantidade > 0),
    status          text NOT NULL DEFAULT 'aberta'
                    CHECK (status IN ('aberta', 'em_cotacao', 'pedido_gerado', 'cancelada')),
    prioridade      text NOT NULL DEFAULT 'normal'
                    CHECK (prioridade IN ('urgente', 'alta', 'normal', 'baixa')),
    observacao      text,
    solicitado_por  uuid REFERENCES auth.users(id),
    criado_em       timestamptz NOT NULL DEFAULT now(),
    atualizado_em   timestamptz NOT NULL DEFAULT now()
);

-- Adiciona colunas ausentes caso a tabela ja existia com estrutura diferente
ALTER TABLE public.solicitacoes_compra ADD COLUMN IF NOT EXISTS produto_id     uuid REFERENCES public.produtos(id) ON DELETE RESTRICT;
ALTER TABLE public.solicitacoes_compra ADD COLUMN IF NOT EXISTS quantidade     numeric(10,3);
ALTER TABLE public.solicitacoes_compra ADD COLUMN IF NOT EXISTS status         text NOT NULL DEFAULT 'aberta';
ALTER TABLE public.solicitacoes_compra ADD COLUMN IF NOT EXISTS prioridade     text NOT NULL DEFAULT 'normal';
ALTER TABLE public.solicitacoes_compra ADD COLUMN IF NOT EXISTS observacao     text;
ALTER TABLE public.solicitacoes_compra ADD COLUMN IF NOT EXISTS solicitado_por uuid REFERENCES auth.users(id);
ALTER TABLE public.solicitacoes_compra ADD COLUMN IF NOT EXISTS criado_em      timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.solicitacoes_compra ADD COLUMN IF NOT EXISTS atualizado_em  timestamptz NOT NULL DEFAULT now();

COMMENT ON TABLE public.solicitacoes_compra IS
'SPEC-020 / SPEC-EST-07. Solicitacao formal de compra por produto. Sem vinculo fixo ao cliente: rastreabilidade de projetos impactados e consultada em vw_entrega_futura_projeto_item.';

CREATE INDEX IF NOT EXISTS idx_sc_produto ON public.solicitacoes_compra (produto_id);
CREATE INDEX IF NOT EXISTS idx_sc_status  ON public.solicitacoes_compra (status);

ALTER TABLE public.solicitacoes_compra ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS authenticated_select_solicitacoes_compra ON public.solicitacoes_compra;
CREATE POLICY authenticated_select_solicitacoes_compra
  ON public.solicitacoes_compra
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);

GRANT SELECT ON TABLE public.solicitacoes_compra TO authenticated;
