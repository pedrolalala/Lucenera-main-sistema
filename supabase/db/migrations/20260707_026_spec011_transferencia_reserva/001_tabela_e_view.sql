-- Migration 20260707_026 - SPEC-011 Parte 1
-- Transferencia de Reserva Entre Itens de Projeto: tabela + view.
-- Depende da SPEC-010 (estoque_saldos_projeto_item / estoque_movimentos_projeto_item),
-- ja aplicada, com hardening 023 e RLS de leitura 024.

CREATE TABLE public.transferencias_estoque (
    id                         uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    origem_projeto_item_id     uuid NOT NULL REFERENCES public.projeto_itens(id) ON DELETE RESTRICT,
    destino_projeto_item_id    uuid NOT NULL REFERENCES public.projeto_itens(id) ON DELETE RESTRICT,
    quantidade                 numeric(10,3) NOT NULL CHECK (quantidade > 0),

    status                     text NOT NULL DEFAULT 'solicitada'
        CHECK (status IN ('solicitada','aprovada','cancelada')),
    motivo                     text,
    solicitado_por             uuid REFERENCES auth.users(id),
    aprovado_por               uuid REFERENCES auth.users(id),
    solicitado_em              timestamptz NOT NULL DEFAULT now(),
    aprovado_em                timestamptz,
    cancelado_em               timestamptz,
    motivo_cancelamento        text,

    CONSTRAINT transferencias_estoque_origem_destino_diff CHECK (origem_projeto_item_id <> destino_projeto_item_id)
);

COMMENT ON TABLE public.transferencias_estoque IS
'SPEC-011. Transferencia de cobertura fisica (q_reserva) entre dois projeto_item_id do mesmo produto.';

CREATE INDEX idx_te_origem  ON public.transferencias_estoque (origem_projeto_item_id);
CREATE INDEX idx_te_destino ON public.transferencias_estoque (destino_projeto_item_id);
CREATE INDEX idx_te_status  ON public.transferencias_estoque (status) WHERE status = 'solicitada';

ALTER TABLE public.transferencias_estoque ENABLE ROW LEVEL SECURITY;

-- Leitura ampla para authenticated (mesmo padrao de projeto_itens/estoque_saldos_projeto_item).
-- Escrita passa exclusivamente pelas RPCs SECURITY DEFINER definidas em 002_rpcs.sql;
-- nao ha policy de INSERT/UPDATE/DELETE direta para authenticated aqui.
CREATE POLICY authenticated_select_transferencias_estoque
  ON public.transferencias_estoque
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);

GRANT SELECT ON TABLE public.transferencias_estoque TO authenticated;

CREATE OR REPLACE VIEW public.vw_transferencias_estoque
WITH (security_invoker = true)
AS
SELECT
    t.id AS transferencia_id,
    t.status,
    pi_o.produto_id,
    p.nome AS produto,
    p.codigo_produto AS produto_codigo,
    t.quantidade,
    t.origem_projeto_item_id,
    pr_o.codigo AS origem_projeto_codigo,
    o_o.numero AS origem_orcamento_numero,
    c_o.nome AS origem_cliente,
    t.destino_projeto_item_id,
    pr_d.codigo AS destino_projeto_codigo,
    o_d.numero AS destino_orcamento_numero,
    c_d.nome AS destino_cliente,
    t.motivo,
    t.solicitado_por,
    t.aprovado_por,
    t.solicitado_em,
    t.aprovado_em,
    t.cancelado_em,
    t.motivo_cancelamento
FROM public.transferencias_estoque t
JOIN public.projeto_itens pi_o ON pi_o.id = t.origem_projeto_item_id
JOIN public.projeto_itens pi_d ON pi_d.id = t.destino_projeto_item_id
LEFT JOIN public.produtos p ON p.id = pi_o.produto_id
LEFT JOIN public.projetos pr_o ON pr_o.id = pi_o.projeto_id
LEFT JOIN public.orcamentos o_o ON o_o.id = pi_o.orcamento_id
LEFT JOIN public.contatos c_o ON c_o.id = coalesce(o_o.cliente_id, pr_o.cliente_id, pr_o.client_id)
LEFT JOIN public.projetos pr_d ON pr_d.id = pi_d.projeto_id
LEFT JOIN public.orcamentos o_d ON o_d.id = pi_d.orcamento_id
LEFT JOIN public.contatos c_d ON c_d.id = coalesce(o_d.cliente_id, pr_d.cliente_id, pr_d.client_id)
ORDER BY t.solicitado_em DESC;

COMMENT ON VIEW public.vw_transferencias_estoque IS
'SPEC-011. Historico/pendencias de transferencia com produto/projeto/orcamento/cliente resolvidos por JOIN. SECURITY INVOKER.';

GRANT SELECT ON TABLE public.vw_transferencias_estoque TO authenticated;
