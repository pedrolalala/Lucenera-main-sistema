-- Migration 20260702_015 — Parte 1
-- Corrige vw_estoque_liquido e vw_produtos_estoque_detalhado.
--
-- Problema:
--   A migration 010 passou a registrar reservas em estoque_itens.quantidade_reservada
--   (na linha com local='Estoque'). As views antigas usavam uma linha separada com
--   local='Reservado' para contar reservas — coluna que o novo sistema não alimenta.
--   Resultado: qtd_disponivel ficava sempre igual a qtd_fisico (zero reservas vistas).
--
-- Correção:
--   qtd_reservado = SUM(quantidade_reservada WHERE local='Estoque')   ← novo sistema
--                 + SUM(quantidade         WHERE local='Reservado')   ← legado (segurança)
--   qtd_disponivel = GREATEST(0, qtd_fisico - qtd_reservado)
--
-- Também corrigido: alerta_estoque agora produz 'normal' (era 'ok') para alinhar
-- com o dashboard. Escala: <=0 → critico | <=3 → baixo | >3 → normal.

-- ─── vw_estoque_liquido ────────────────────────────────────────────────────────
-- DROP + CREATE porque o esquema de colunas muda (CTE reorganiza);
-- CREATE OR REPLACE rejeita qualquer alteração na lista de colunas.
-- CASCADE remove automaticamente views dependentes (recriadas abaixo se existirem).
DROP VIEW IF EXISTS public.vw_estoque_liquido CASCADE;
CREATE VIEW public.vw_estoque_liquido AS
WITH calc AS (
    SELECT
        p.id            AS produto_id,
        p.nome          AS produto,
        p.sku,
        m.nome          AS marca,
        p.categoria,
        p.preco_custo,
        p.preco_venda,
        COALESCE(sum(ei.quantidade)           FILTER (WHERE ei.local = 'Estoque'::public.estoque_local),    0) AS qtd_fisico,
        COALESCE(sum(ei.quantidade_reservada) FILTER (WHERE ei.local = 'Estoque'::public.estoque_local),    0)
          + COALESCE(sum(ei.quantidade)       FILTER (WHERE ei.local = 'Reservado'::public.estoque_local),  0) AS qtd_reservado,
        COALESCE(sum(ei.quantidade)           FILTER (WHERE ei.local = 'Showroom'::public.estoque_local),   0) AS qtd_showroom,
        COALESCE(sum(ei.quantidade)           FILTER (WHERE ei.local = 'Em trânsito'::public.estoque_local), 0) AS qtd_em_transito
    FROM public.produtos p
    LEFT JOIN public.marcas m       ON m.id = p.marca_id
    LEFT JOIN public.estoque_itens ei ON ei.produto_id = p.id
    WHERE p.ativo = true
    GROUP BY p.id, p.nome, p.sku, m.nome, p.categoria, p.preco_custo, p.preco_venda
)
SELECT
    produto_id,
    produto,
    sku,
    marca,
    categoria,
    preco_custo,
    preco_venda,
    qtd_fisico,
    qtd_reservado,
    qtd_showroom,
    qtd_em_transito,
    GREATEST(0, qtd_fisico - qtd_reservado)            AS qtd_disponivel,
    CASE
        WHEN GREATEST(0, qtd_fisico - qtd_reservado) =  0 THEN 'critico'
        WHEN GREATEST(0, qtd_fisico - qtd_reservado) <= 3 THEN 'baixo'
        ELSE 'normal'
    END                                                AS alerta_estoque,
    round(qtd_fisico    * preco_venda, 2)              AS valor_estoque_total,
    round(qtd_reservado * preco_venda, 2)              AS valor_reservado_total
FROM calc;

-- ─── vw_produtos_estoque_detalhado ────────────────────────────────────────────
DROP VIEW IF EXISTS public.vw_produtos_estoque_detalhado CASCADE;
CREATE VIEW public.vw_produtos_estoque_detalhado AS
WITH estoque_calculado AS (
    SELECT
        produto_id,
        sum(CASE WHEN local::text ILIKE 'estoque%'
                 THEN quantidade   ELSE 0 END)                          AS qtd_geral,
        sum(CASE WHEN local::text ILIKE 'showroom%'
                 THEN quantidade   ELSE 0 END)                          AS qtd_showroom,
        -- novo sistema: quantidade_reservada na linha Estoque
        -- + legado: linha com local ILIKE 'reserva%'
        sum(CASE WHEN local = 'Estoque'::public.estoque_local
                 THEN COALESCE(quantidade_reservada, 0) ELSE 0 END)
          + sum(CASE WHEN local::text ILIKE 'reserva%'
                     THEN quantidade ELSE 0 END)                        AS qtd_reserva,
        sum(CASE WHEN local::text ILIKE 'separacao%'
                   OR local::text ILIKE 'separação%'
                 THEN quantidade   ELSE 0 END)                          AS qtd_separacao,
        sum(quantidade)                                                  AS total_fisico
    FROM public.estoque_itens
    GROUP BY produto_id
)
SELECT
    p.id,
    p.codigo_produto,
    p.nome,
    p.sku,
    p.preco_venda,
    COALESCE(ec.qtd_geral,     0)                                               AS estoque_geral,
    COALESCE(ec.qtd_reserva,   0)                                               AS reserva,
    COALESCE(ec.qtd_separacao, 0)                                               AS separacao,
    COALESCE(ec.qtd_geral, 0) - COALESCE(ec.qtd_reserva, 0) - COALESCE(ec.qtd_separacao, 0) AS disponivel
FROM public.produtos p
LEFT JOIN estoque_calculado ec ON p.id = ec.produto_id;
