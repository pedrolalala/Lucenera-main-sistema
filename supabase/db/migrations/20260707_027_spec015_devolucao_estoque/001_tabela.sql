-- Migration 20260707_027 - SPEC-015 Parte 1
-- Devolucao de Estoque por Item de Projeto: tabela.

CREATE TABLE public.devolucoes_estoque (
    id                    uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    projeto_item_id        uuid NOT NULL REFERENCES public.projeto_itens(id) ON DELETE RESTRICT,
    quantidade             numeric(10,3) NOT NULL CHECK (quantidade > 0),

    qtd_de_entrega_futura  numeric(10,3) NOT NULL DEFAULT 0 CHECK (qtd_de_entrega_futura >= 0),
    qtd_de_reserva         numeric(10,3) NOT NULL DEFAULT 0 CHECK (qtd_de_reserva >= 0),
    qtd_de_entregue        numeric(10,3) NOT NULL DEFAULT 0 CHECK (qtd_de_entregue >= 0),

    status                 text NOT NULL DEFAULT 'registrada'
        CHECK (status IN ('registrada','aguardando_coleta','coletada','cancelada')),
    motivo                 text,
    gera_credito_financeiro boolean,
    solicitado_por         uuid REFERENCES auth.users(id),
    aprovado_por           uuid REFERENCES auth.users(id),
    criado_em              timestamptz NOT NULL DEFAULT now(),
    aprovado_em            timestamptz,
    cancelado_em           timestamptz
);

COMMENT ON TABLE public.devolucoes_estoque IS
'SPEC-015. Devolucao por projeto_item_id, reduzindo saldos na ordem q_entrega_futura -> q_reserva -> q_entregue, preservando projeto_itens.quantidade (Q. Venda).';

CREATE INDEX idx_dev_projeto_item ON public.devolucoes_estoque (projeto_item_id);
CREATE INDEX idx_dev_status       ON public.devolucoes_estoque (status);

ALTER TABLE public.devolucoes_estoque ENABLE ROW LEVEL SECURITY;

-- Leitura ampla para authenticated, mesmo padrao das demais tabelas da SPEC-010/011.
-- Escrita exclusiva via RPC SECURITY DEFINER (002_rpc.sql). Aprovacao/permissao
-- fina de quem pode registrar devolucao segue como pendencia aberta na propria
-- SPEC-015 ("Definir aprovacao/permissao da devolucao") - nao antecipada aqui.
CREATE POLICY authenticated_select_devolucoes_estoque
  ON public.devolucoes_estoque
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);

GRANT SELECT ON TABLE public.devolucoes_estoque TO authenticated;
