-- SPEC-284: Dashboard (Estoque) e Compras (Pedido Avulso) passam a ler o estoque real.
-- estoque_total / estoque_disponivel deixam de vir de produtos.estoque_* (paradas desde 05/11, só a importação
-- da Connect gravava, suspensa em 22/10 pela SPEC-222) e passam a vir de estoque_itens, local 'Estoque' (Estoque Geral).
-- Disponível = quantidade - quantidade_reservada (mesma conta da aprovação de orçamento).
-- Mesmas colunas, mesma ordem, mesmos tipos. Nenhuma tabela, função, permissão ou tela muda.
BEGIN;

-- 1) Dashboard -> Estoque (SPEC-028). View sem security_invoker, como antes.
CREATE OR REPLACE VIEW public.v_estoque_produtos AS
 WITH ei AS (
   SELECT e.produto_id,
          e.quantidade::numeric(15,3)                            AS estoque_total,
          (e.quantidade - e.quantidade_reservada)::numeric(15,3) AS estoque_disponivel
     FROM public.estoque_itens e
    WHERE e.local = 'Estoque'::public.estoque_local
 )
 SELECT p.id AS produto_id,
    p.codigo_produto,
    p.nome AS produto,
    p.marca_id,
    COALESCE(m.nome, 'SEM MARCA'::text) AS marca,
    COALESCE(ei.estoque_total, 0)::numeric(15,3) AS estoque_total,
    COALESCE(ei.estoque_disponivel, 0)::numeric(15,3) AS estoque_disponivel,
    p.estoque_showroom,
    p.custo_total AS custo_unitario,
    p.valor_venda AS venda_unitaria,
    round(COALESCE(ei.estoque_total, 0) * p.custo_total, 2) AS valor_custo_total,
    round(COALESCE(ei.estoque_total, 0) * p.valor_venda, 2) AS valor_venda_total,
    round(GREATEST(COALESCE(ei.estoque_disponivel, 0), 0::numeric) * p.custo_total, 2) AS valor_custo_disponivel,
    round(GREATEST(COALESCE(ei.estoque_disponivel, 0), 0::numeric) * p.valor_venda, 2) AS valor_venda_disponivel,
    round(GREATEST(- COALESCE(ei.estoque_disponivel, 0), 0::numeric) * p.custo_total, 2) AS valor_custo_negativo,
    round(GREATEST(- COALESCE(ei.estoque_disponivel, 0), 0::numeric) * p.valor_venda, 2) AS valor_venda_negativo,
    round(GREATEST(p.estoque_showroom, 0)::numeric * p.custo_total, 2) AS valor_custo_showroom,
        CASE
            WHEN p.custo_total > 0::numeric THEN round(p.valor_venda / p.custo_total, 2)
            ELSE NULL::numeric
        END AS mkp
   FROM public.vw_produtos_custo_restrito p
     LEFT JOIN public.marcas m ON m.id = p.marca_id
     LEFT JOIN ei ON ei.produto_id = p.id
  WHERE p.ativo = true;

COMMENT ON VIEW public.v_estoque_produtos IS 'Base do Dashboard de Estoque (SPEC-028) — uma linha por produto ativo, com valores de custo/venda já calculados (total, disponível, negativo/déficit, showroom) e markup. Fonte única de verdade das fórmulas validadas na SPEC. SPEC-284 (11/11/2026): estoque_total/estoque_disponivel vêm de estoque_itens (local Estoque), não mais de produtos.estoque_*.';

-- 2) Compras -> Pedido Avulso. Mantém security_invoker.
CREATE OR REPLACE VIEW public.vw_estoque_produtos WITH (security_invoker = true) AS
 SELECT p.id AS produto_id,
    p.codigo_produto::text AS produto_codigo,
    p.nome AS produto,
    p.sku,
    p.referencia,
    m.nome AS marca,
    cat.nome AS categoria,
    p.unidade,
    COALESCE(eg.quantidade, 0::numeric) AS estoque_total,
    COALESCE(eg.quantidade - eg.quantidade_reservada, 0::numeric) AS estoque_disponivel,
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
     LEFT JOIN public.estoque_itens eg ON eg.produto_id = p.id AND eg.local = 'Estoque'::public.estoque_local
  WHERE p.ativo = true;

COMMIT;
