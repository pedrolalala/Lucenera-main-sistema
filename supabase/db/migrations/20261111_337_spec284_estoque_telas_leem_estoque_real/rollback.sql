-- SPEC-284 rollback: recria as duas views exatamente como estavam em 11/11/2026 (lendo produtos.estoque_*).
BEGIN;

CREATE OR REPLACE VIEW public.v_estoque_produtos AS
 SELECT p.id AS produto_id,
    p.codigo_produto,
    p.nome AS produto,
    p.marca_id,
    COALESCE(m.nome, 'SEM MARCA'::text) AS marca,
    p.estoque_total,
    p.estoque_disponivel,
    p.estoque_showroom,
    p.custo_total AS custo_unitario,
    p.valor_venda AS venda_unitaria,
    round(p.estoque_total * p.custo_total, 2) AS valor_custo_total,
    round(p.estoque_total * p.valor_venda, 2) AS valor_venda_total,
    round(GREATEST(p.estoque_disponivel, 0::numeric) * p.custo_total, 2) AS valor_custo_disponivel,
    round(GREATEST(p.estoque_disponivel, 0::numeric) * p.valor_venda, 2) AS valor_venda_disponivel,
    round(GREATEST(- p.estoque_disponivel, 0::numeric) * p.custo_total, 2) AS valor_custo_negativo,
    round(GREATEST(- p.estoque_disponivel, 0::numeric) * p.valor_venda, 2) AS valor_venda_negativo,
    round(GREATEST(p.estoque_showroom, 0)::numeric * p.custo_total, 2) AS valor_custo_showroom,
        CASE
            WHEN p.custo_total > 0::numeric THEN round(p.valor_venda / p.custo_total, 2)
            ELSE NULL::numeric
        END AS mkp
   FROM public.vw_produtos_custo_restrito p
     LEFT JOIN public.marcas m ON m.id = p.marca_id
  WHERE p.ativo = true;

COMMENT ON VIEW public.v_estoque_produtos IS 'Base do Dashboard de Estoque (SPEC-028) — uma linha por produto ativo, com valores de custo/venda já calculados (total, disponível, negativo/déficit, showroom) e markup. Fonte única de verdade das fórmulas validadas na SPEC.';

CREATE OR REPLACE VIEW public.vw_estoque_produtos WITH (security_invoker = true) AS
 SELECT p.id AS produto_id,
    p.codigo_produto::text AS produto_codigo,
    p.nome AS produto,
    p.sku,
    p.referencia,
    m.nome AS marca,
    cat.nome AS categoria,
    p.unidade,
    COALESCE(p.estoque_total, 0::numeric) AS estoque_total,
    COALESCE(p.estoque_disponivel, 0::numeric) AS estoque_disponivel,
    COALESCE(p.estoque_showroom, 0) AS estoque_showroom,
    COALESCE(ei.qtd_estoque, 0::numeric) AS qtd_estoque_itens,
    COALESCE(ei.qtd_reservada, 0::numeric) AS qtd_reservada,
    COALESCE(p.custo_total, 0::numeric) AS custo_total,
    p.preco_custo,
    p.preco_venda,
    p.ativo,
    p.updated_at
   FROM public.vw_produtos_custo_restrito p
     LEFT JOIN public.marcas m ON m.id = p.marca_id
     LEFT JOIN public.categorias_produto cat ON cat.id = p.categoria_id
     LEFT JOIN ( SELECT estoque_itens.produto_id,
            sum(estoque_itens.quantidade) AS qtd_estoque,
            sum(estoque_itens.quantidade_reservada) AS qtd_reservada
           FROM public.estoque_itens
          GROUP BY estoque_itens.produto_id) ei ON ei.produto_id = p.id
  WHERE p.ativo = true;

COMMIT;
