-- Migration 20260721_054 - SPEC-038 Item 3
-- Vinculo INFORMATIVO (nao obrigatorio, nao bloqueante) entre um item de
-- pedido de compra e o(s) projeto_item(s) que o motivaram. Nao contradiz a
-- decisao da reuniao 08/06/2026 / SPEC-020 (compra agregada por produto, sem
-- dono fixo) -- e so rastreabilidade de "por que compramos isso".
--
-- Escrita via RPC SECURITY DEFINER (vincular_origem_pedido_compra_item),
-- nao via INSERT direto do frontend -- mesmo padrao ja usado por TODAS as
-- outras tabelas de escrita deste dominio (solicitacoes_compra,
-- pedidos_compra, pedido_compra_itens, pedido_compra_parcelas): policy so
-- de SELECT, escrita exclusiva via RPC.

CREATE TABLE IF NOT EXISTS public.pedido_compra_item_origem (
    id                    uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    pedido_compra_item_id uuid NOT NULL REFERENCES public.pedido_compra_itens(id) ON DELETE CASCADE,
    projeto_item_id       uuid NOT NULL REFERENCES public.projeto_itens(id) ON DELETE CASCADE,
    quantidade_atendida   numeric(10,3) CHECK (quantidade_atendida IS NULL OR quantidade_atendida > 0),
    observacao            text,
    criado_por            uuid REFERENCES auth.users(id),
    criado_em             timestamptz NOT NULL DEFAULT now(),
    UNIQUE (pedido_compra_item_id, projeto_item_id)
);

COMMENT ON TABLE public.pedido_compra_item_origem IS
'SPEC-038. Vinculo INFORMATIVO (nao obrigatorio) entre pedido_compra_itens e
projeto_itens -- registra qual(is) demanda(s) de projeto motivaram esta
compra, sem tornar a compra dependente de um unico cliente/projeto (decisao
da reuniao 08/06/2026, SPEC-020). orcamento_id/cliente sao resolvidos por
JOIN via projeto_itens -> orcamentos/projetos, nao duplicados aqui.';

CREATE INDEX IF NOT EXISTS idx_pcio_item    ON public.pedido_compra_item_origem (pedido_compra_item_id);
CREATE INDEX IF NOT EXISTS idx_pcio_projeto ON public.pedido_compra_item_origem (projeto_item_id);

ALTER TABLE public.pedido_compra_item_origem ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS authenticated_select_pedido_compra_item_origem ON public.pedido_compra_item_origem;
CREATE POLICY authenticated_select_pedido_compra_item_origem
  ON public.pedido_compra_item_origem
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);

GRANT SELECT ON TABLE public.pedido_compra_item_origem TO authenticated;

CREATE OR REPLACE FUNCTION public.vincular_origem_pedido_compra_item(
    p_pedido_compra_item_id uuid,
    p_projeto_item_id       uuid,
    p_quantidade_atendida   numeric DEFAULT NULL,
    p_observacao            text    DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id uuid;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.pedido_compra_itens WHERE id = p_pedido_compra_item_id) THEN
        RAISE EXCEPTION 'Item de pedido de compra % nao encontrado.', p_pedido_compra_item_id USING ERRCODE = 'P0001';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.projeto_itens WHERE id = p_projeto_item_id) THEN
        RAISE EXCEPTION 'Item de projeto % nao encontrado.', p_projeto_item_id USING ERRCODE = 'P0001';
    END IF;

    INSERT INTO public.pedido_compra_item_origem (
        pedido_compra_item_id, projeto_item_id, quantidade_atendida, observacao, criado_por
    ) VALUES (
        p_pedido_compra_item_id, p_projeto_item_id, p_quantidade_atendida, p_observacao, auth.uid()
    )
    ON CONFLICT (pedido_compra_item_id, projeto_item_id) DO UPDATE
        SET quantidade_atendida = EXCLUDED.quantidade_atendida,
            observacao = EXCLUDED.observacao
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;

COMMENT ON FUNCTION public.vincular_origem_pedido_compra_item(uuid, uuid, numeric, text) IS
'SPEC-038 (Item 3). Registra vinculo informativo entre um item de pedido de
compra e um item de projeto que motivou a compra. Idempotente por
(pedido_compra_item_id, projeto_item_id) via ON CONFLICT DO UPDATE. Nunca
bloqueia a criacao do pedido em si -- e chamada, se o usuario optar, depois
do pedido ja ter sido criado.';

GRANT EXECUTE ON FUNCTION public.vincular_origem_pedido_compra_item(uuid, uuid, numeric, text) TO authenticated;

-- View de leitura (opcional, para a UI mostrar orcamento/cliente por JOIN,
-- no mesmo espirito de vw_necessidade_compra_detalhe da SPEC-022). Colunas
-- de projetos/orcamentos/contatos confirmadas em supabase/db/current/01_schema_full.sql
-- (projetos.cliente_id, projetos.client_id, orcamentos.cliente_id).
CREATE OR REPLACE VIEW public.vw_pedido_compra_item_origem
WITH (security_invoker = true)
AS
SELECT
    pcio.id,
    pcio.pedido_compra_item_id,
    pcio.projeto_item_id,
    pcio.quantidade_atendida,
    pr.codigo   AS projeto_codigo,
    pr.nome     AS projeto_nome,
    o.numero    AS orcamento_numero,
    c.nome      AS cliente
FROM public.pedido_compra_item_origem pcio
JOIN public.projeto_itens pi ON pi.id = pcio.projeto_item_id
LEFT JOIN public.projetos pr ON pr.id = pi.projeto_id
LEFT JOIN public.orcamentos o ON o.id = pi.orcamento_id
LEFT JOIN public.contatos c ON c.id = COALESCE(o.cliente_id, pr.cliente_id, pr.client_id);

COMMENT ON VIEW public.vw_pedido_compra_item_origem IS
'SPEC-038. Resolve projeto/orcamento/cliente por JOIN a partir de
pedido_compra_item_origem, mesmo padrao da vw_necessidade_compra_detalhe
(SPEC-022). SECURITY INVOKER.';

GRANT SELECT ON public.vw_pedido_compra_item_origem TO authenticated;
