-- Migration 20260721_054 - SPEC-038 Item 5
--
-- Decisao do usuario (P-05, 2026-07-21): Alternativa B -- coluna DEDICADA em
-- produtos, separada de porc_desconto (que ja alimenta fn_atualizar_preco_venda()
-- e o preco de VENDA ao cliente, via trigger trg_atualizar_preco_venda --
-- 01_schema_full.sql:10414). Evita efeito colateral nao intencional em
-- vendas ao editar um desconto de COMPRA na tela de Cotacoes.
--
-- NOTA sobre vw_necessidade_compra: a definicao abaixo foi conferida contra a
-- ultima migration real que recriou essa view --
-- supabase/db/migrations/20260716_049_spec030_pedido_lote_marca_fornecedor/
-- 002_vw_necessidade_compra_marca_fornecedor.sql -- e contra o historico
-- completo de migrations (nenhuma migration entre 049 e esta recria a view
-- novamente; confirmado via grep em supabase/db/migrations por
-- "vw_necessidade_compra"). Ainda assim, este agente NAO tem acesso ao
-- Supabase real nesta sessao para confirmar que a definicao aplicada no
-- banco bate 100% com a ultima migration desta pasta -- CONFERIR
-- (SELECT pg_get_viewdef('public.vw_necessidade_compra')) antes de aplicar
-- esta migration em produção.

ALTER TABLE public.produtos
  ADD COLUMN IF NOT EXISTS percentual_desconto_compra numeric(5,2) DEFAULT 0;

COMMENT ON COLUMN public.produtos.percentual_desconto_compra IS
'SPEC-038. Percentual de desconto negociado na COMPRA (tela Cotacoes,
compras-lucenera). Distinto de produtos.porc_desconto, que alimenta
fn_atualizar_preco_venda() e o preco de VENDA ao cliente -- NAO dispara
recalculo de preco_venda (nao esta na lista de colunas do trigger
trg_atualizar_preco_venda). Ver P-05 (pendencia) sobre se essa separacao deve
ser mantida ou se o valor deve, no futuro, alimentar o mesmo calculo.';

CREATE OR REPLACE FUNCTION public.atualizar_desconto_compra_produto(
    p_produto_id              uuid,
    p_percentual_desconto     numeric
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF p_percentual_desconto IS NULL OR p_percentual_desconto < 0 OR p_percentual_desconto > 100 THEN
        RAISE EXCEPTION 'Percentual de desconto deve estar entre 0 e 100.' USING ERRCODE = 'P0001';
    END IF;

    UPDATE public.produtos
    SET percentual_desconto_compra = p_percentual_desconto,
        updated_at = now()
    WHERE id = p_produto_id
      AND ativo = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Produto % nao encontrado ou inativo.', p_produto_id USING ERRCODE = 'P0001';
    END IF;
END;
$$;

COMMENT ON FUNCTION public.atualizar_desconto_compra_produto(uuid, numeric) IS
'SPEC-038. Atualiza produtos.percentual_desconto_compra via tela Cotacoes.
Mesmo padrao de atualizar_preco_custo_produto (SPEC-036). SECURITY DEFINER.
NAO afeta fn_atualizar_preco_venda()/preco_venda.';

GRANT EXECUTE ON FUNCTION public.atualizar_desconto_compra_produto(uuid, numeric) TO authenticated;

-- Estende vw_necessidade_compra (CREATE OR REPLACE acrescenta coluna no
-- final, sem quebrar consumidores existentes -- mesmo padrao das migrations
-- 20260713_036 e 20260716_049). Base identica a 20260716_049
-- (002_vw_necessidade_compra_marca_fornecedor.sql), com
-- percentual_desconto_compra adicionado ao final.
CREATE OR REPLACE VIEW public.vw_necessidade_compra
WITH (security_invoker = true)
AS
SELECT
    p.id                                            AS produto_id,
    p.nome                                          AS produto,
    p.codigo_produto                                AS produto_codigo,
    coalesce(ei_agg.qtd_estoque, 0)                 AS qtd_fisica,
    coalesce(ei_agg.qtd_reservada, 0)               AS qtd_comprometida,
    GREATEST(0,
        coalesce(ei_agg.qtd_reservada, 0)
        - coalesce(ei_agg.qtd_estoque, 0)
    )                                               AS necessidade_compra,
    coalesce(ei_agg.qtd_estoque, 0)
        - coalesce(ei_agg.qtd_reservada, 0)         AS qtd_disponivel,
    coalesce(proj.n_projetos, 0)                    AS projetos_com_entrega_futura,
    p.preco_custo,
    mk.id                                            AS marca_id,
    mk.nome                                          AS marca_nome,
    forn.id                                          AS fornecedor_id,
    forn.nome                                        AS fornecedor_nome,
    p.percentual_desconto_compra                     AS percentual_desconto_compra
FROM public.produtos p
JOIN (
    SELECT
        produto_id,
        SUM(quantidade)             AS qtd_estoque,
        SUM(quantidade_reservada)   AS qtd_reservada
    FROM public.estoque_itens
    GROUP BY produto_id
) ei_agg ON ei_agg.produto_id = p.id
LEFT JOIN (
    SELECT
        pi.produto_id,
        count(DISTINCT pi.projeto_id) AS n_projetos
    FROM public.estoque_saldos_projeto_item esp
    JOIN public.projeto_itens pi ON pi.id = esp.projeto_item_id
    WHERE esp.status_operacional = 'ativo'
      AND (esp.q_reserva > 0 OR esp.q_entrega_futura > 0)
    GROUP BY pi.produto_id
) proj ON proj.produto_id = p.id
LEFT JOIN public.marcas mk
    ON mk.id = p.marca_id
LEFT JOIN public.contatos forn
    ON forn.id = COALESCE(p.fornecedor_principal_id, mk.fornecedor_id)
WHERE p.ativo = true
  AND coalesce(ei_agg.qtd_reservada, 0) > coalesce(ei_agg.qtd_estoque, 0)
ORDER BY necessidade_compra DESC, p.nome;

COMMENT ON VIEW public.vw_necessidade_compra IS
'SPEC-038 (estende migration 20260716_049 + 20260713_036). Adiciona
percentual_desconto_compra ao final. SECURITY INVOKER.';

GRANT SELECT ON TABLE public.vw_necessidade_compra TO authenticated;
