-- Migration 20260713_036 - Cotacoes: preco_custo na view + RPC de update
--
-- 1. Adiciona p.preco_custo ao final de vw_necessidade_compra
--    (CREATE OR REPLACE pode acrescentar colunas no final sem DROP)
-- 2. RPC atualizar_preco_custo_produto: atualiza produtos.preco_custo
--    via authenticated, sem expor service_role no frontend.

-- 1. View com preco_custo adicionado
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
    p.preco_custo
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
WHERE p.ativo = true
  AND coalesce(ei_agg.qtd_reservada, 0) > coalesce(ei_agg.qtd_estoque, 0)
ORDER BY necessidade_compra DESC, p.nome;

COMMENT ON VIEW public.vw_necessidade_compra IS
'Migration 036. Fonte: estoque_itens (quantidade_reservada > quantidade).
Inclui preco_custo para modulo de Cotacoes. SECURITY INVOKER.';

GRANT SELECT ON TABLE public.vw_necessidade_compra TO authenticated;


-- 2. RPC para atualizar preco_custo de um produto
CREATE OR REPLACE FUNCTION public.atualizar_preco_custo_produto(
    p_produto_id    uuid,
    p_preco_custo   numeric
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF p_preco_custo IS NULL OR p_preco_custo < 0 THEN
        RAISE EXCEPTION 'Preco de custo deve ser >= 0.' USING ERRCODE = 'P0001';
    END IF;

    UPDATE public.produtos
    SET preco_custo = p_preco_custo,
        updated_at  = now()
    WHERE id = p_produto_id
      AND ativo = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Produto % nao encontrado ou inativo.', p_produto_id
            USING ERRCODE = 'P0001';
    END IF;
END;
$$;

COMMENT ON FUNCTION public.atualizar_preco_custo_produto(uuid, numeric) IS
'SPEC-036. Atualiza produtos.preco_custo via modulo Cotacoes. SECURITY DEFINER.';

GRANT EXECUTE ON FUNCTION public.atualizar_preco_custo_produto(uuid, numeric) TO authenticated;
