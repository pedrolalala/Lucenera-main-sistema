-- Rollback da 203: devolve SELECT de todas as colunas e as 8 visões como estavam em 12/10/2026.

REVOKE SELECT (id, marca_id, nome, sku, categoria, preco_venda, ativo, created_at, updated_at, codigo_produto, referencia, estoque_total, estoque_showroom, estoque_disponivel, unidade, valor_venda, codigo_legado, categoria_id, fornecedor_principal_id, descricao_tecnica, ncm, tipo_fiscal, cst, cest, status_comercial, mascara_produto, prazo_entrega_dias, multiplo_compra, estoque_minimo, imagem_showroom_url, grupo_fiscal_nao_contribuinte, grupo_fiscal_revenda, tem_st) ON public.produtos FROM authenticated;

GRANT SELECT ON public.produtos TO authenticated;

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
   FROM produtos p
     LEFT JOIN marcas m ON m.id = p.marca_id
  WHERE p.ativo = true;

CREATE OR REPLACE VIEW public.vw_estoque_liquido AS
 WITH calc AS (
         SELECT p.id AS produto_id,
            p.nome AS produto,
            p.sku,
            m.nome AS marca,
            p.categoria,
            p.preco_custo,
            p.preco_venda,
            COALESCE(sum(ei.quantidade) FILTER (WHERE ei.local = 'Estoque'::estoque_local), 0::numeric) AS qtd_fisico,
            COALESCE(sum(ei.quantidade_reservada) FILTER (WHERE ei.local = 'Estoque'::estoque_local), 0::numeric) + COALESCE(sum(ei.quantidade) FILTER (WHERE ei.local = 'Reservado'::estoque_local), 0::numeric) AS qtd_reservado,
            COALESCE(sum(ei.quantidade) FILTER (WHERE ei.local = 'Showroom'::estoque_local), 0::numeric) AS qtd_showroom,
            COALESCE(sum(ei.quantidade) FILTER (WHERE ei.local = 'Em trânsito'::estoque_local), 0::numeric) AS qtd_em_transito
           FROM produtos p
             LEFT JOIN marcas m ON m.id = p.marca_id
             LEFT JOIN estoque_itens ei ON ei.produto_id = p.id
          WHERE p.ativo = true
          GROUP BY p.id, p.nome, p.sku, m.nome, p.categoria, p.preco_custo, p.preco_venda
        )
 SELECT produto_id,
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
    GREATEST(0::numeric, qtd_fisico - qtd_reservado) AS qtd_disponivel,
        CASE
            WHEN GREATEST(0::numeric, qtd_fisico - qtd_reservado) = 0::numeric THEN 'critico'::text
            WHEN GREATEST(0::numeric, qtd_fisico - qtd_reservado) <= 3::numeric THEN 'baixo'::text
            ELSE 'normal'::text
        END AS alerta_estoque,
    round(qtd_fisico * preco_venda, 2) AS valor_estoque_total,
    round(qtd_reservado * preco_venda, 2) AS valor_reservado_total
   FROM calc;

CREATE OR REPLACE VIEW public.vw_estoque_produtos WITH (security_invoker=true) AS
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
   FROM produtos p
     LEFT JOIN marcas m ON m.id = p.marca_id
     LEFT JOIN categorias_produto cat ON cat.id = p.categoria_id
     LEFT JOIN ( SELECT estoque_itens.produto_id,
            sum(estoque_itens.quantidade) AS qtd_estoque,
            sum(estoque_itens.quantidade_reservada) AS qtd_reservada
           FROM estoque_itens
          GROUP BY estoque_itens.produto_id) ei ON ei.produto_id = p.id
  WHERE p.ativo = true;

CREATE OR REPLACE VIEW public.vw_necessidade_compra WITH (security_invoker=true) AS
 WITH base AS (
         SELECT p.id AS produto_id,
            p.nome AS produto,
            p.codigo_produto AS produto_codigo,
            COALESCE(ei_agg.qtd_estoque, 0::numeric) AS qtd_fisica,
            COALESCE(ei_agg.qtd_reservada, 0::numeric) AS qtd_comprometida,
            GREATEST(0::numeric, COALESCE(ei_agg.qtd_reservada, 0::numeric) - COALESCE(ei_agg.qtd_estoque, 0::numeric)) AS necessidade_compra,
            COALESCE(ei_agg.qtd_estoque, 0::numeric) - COALESCE(ei_agg.qtd_reservada, 0::numeric) AS qtd_disponivel,
            COALESCE(proj.n_projetos, 0::bigint) AS projetos_com_entrega_futura,
            p.preco_custo,
            mk.id AS marca_id,
            mk.nome AS marca_nome,
            forn.id AS fornecedor_id,
            forn.nome AS fornecedor_nome,
            p.percentual_desconto_compra,
            COALESCE(pca.qtd_pedidos_abertos, 0::bigint) AS qtd_pedidos_abertos,
            COALESCE(pca.qtd_em_pedidos_abertos, 0::numeric) AS qtd_em_pedidos_abertos,
            pca.proxima_data_prevista_entrega,
            pca.status_mais_critico,
            p.referencia
           FROM produtos p
             JOIN ( SELECT estoque_itens.produto_id,
                    sum(estoque_itens.quantidade) AS qtd_estoque,
                    sum(estoque_itens.quantidade_reservada) AS qtd_reservada
                   FROM estoque_itens
                  GROUP BY estoque_itens.produto_id) ei_agg ON ei_agg.produto_id = p.id
             LEFT JOIN ( SELECT pi.produto_id,
                    count(DISTINCT pi.projeto_id) AS n_projetos
                   FROM estoque_saldos_projeto_item esp
                     JOIN projeto_itens pi ON pi.id = esp.projeto_item_id
                  WHERE esp.status_operacional = 'ativo'::text AND (esp.q_reserva > 0::numeric OR esp.q_entrega_futura > 0::numeric)
                  GROUP BY pi.produto_id) proj ON proj.produto_id = p.id
             LEFT JOIN marcas mk ON mk.id = p.marca_id
             LEFT JOIN contatos forn ON forn.id = COALESCE(p.fornecedor_principal_id, mk.fornecedor_id)
             LEFT JOIN vw_necessidade_compra_pedidos_abertos pca ON pca.produto_id = p.id
          WHERE p.ativo = true
        )
 SELECT produto_id,
    produto,
    produto_codigo,
    qtd_fisica,
    qtd_comprometida,
    necessidade_compra,
    qtd_disponivel,
    projetos_com_entrega_futura,
    preco_custo,
    marca_id,
    marca_nome,
    fornecedor_id,
    fornecedor_nome,
    percentual_desconto_compra,
    qtd_pedidos_abertos,
    qtd_em_pedidos_abertos,
    proxima_data_prevista_entrega,
    status_mais_critico,
    GREATEST(0::numeric, necessidade_compra - qtd_em_pedidos_abertos) AS pendente,
    referencia
   FROM base
  WHERE GREATEST(0::numeric, necessidade_compra - qtd_em_pedidos_abertos) > 0::numeric
  ORDER BY necessidade_compra DESC, produto;

CREATE OR REPLACE VIEW public.vw_necessidade_compra_item_orcamento WITH (security_invoker=true) AS
 WITH cobertura_pedidos AS (
         SELECT pcio.projeto_item_id,
            sum(pcio.quantidade_atendida) AS qtd_coberta_por_pedido_aberto
           FROM pedido_compra_item_origem pcio
             JOIN pedido_compra_itens pci ON pci.id = pcio.pedido_compra_item_id
             JOIN pedidos_compra pc ON pc.id = pci.pedido_id
          WHERE (pc.status <> ALL (ARRAY['recebido'::text, 'cancelado'::text])) AND pcio.quantidade_atendida IS NOT NULL
          GROUP BY pcio.projeto_item_id
        ), base AS (
         SELECT pi.id AS projeto_item_id,
            pi.produto_id,
            p.nome AS produto,
            p.codigo_produto AS produto_codigo,
            pi.orcamento_id,
            o.numero AS orcamento_numero,
            pi.orcamento_item_id,
            pi.l_fixo,
            p.preco_custo,
            p.percentual_desconto_compra,
            mk.id AS marca_id,
            mk.nome AS marca_nome,
            forn.id AS fornecedor_id,
            forn.nome AS fornecedor_nome,
            esp.q_entrega_futura,
            COALESCE(cob.qtd_coberta_por_pedido_aberto, 0::numeric) AS qtd_coberta_por_pedido_aberto,
            GREATEST(0::numeric, esp.q_entrega_futura - COALESCE(cob.qtd_coberta_por_pedido_aberto, 0::numeric)) AS pendente_item
           FROM projeto_itens pi
             JOIN produtos p ON p.id = pi.produto_id AND p.ativo = true
             JOIN estoque_saldos_projeto_item esp ON esp.projeto_item_id = pi.id AND esp.status_operacional = 'ativo'::text
             LEFT JOIN orcamentos o ON o.id = pi.orcamento_id
             LEFT JOIN marcas mk ON mk.id = p.marca_id
             LEFT JOIN contatos forn ON forn.id = COALESCE(p.fornecedor_principal_id, mk.fornecedor_id)
             LEFT JOIN cobertura_pedidos cob ON cob.projeto_item_id = pi.id
          WHERE pi.orcamento_item_id IS NOT NULL
        )
 SELECT projeto_item_id,
    produto_id,
    produto,
    produto_codigo,
    orcamento_id,
    orcamento_numero,
    orcamento_item_id,
    l_fixo,
    preco_custo,
    percentual_desconto_compra,
    marca_id,
    marca_nome,
    fornecedor_id,
    fornecedor_nome,
    q_entrega_futura,
    qtd_coberta_por_pedido_aberto,
    pendente_item
   FROM base
  WHERE pendente_item > 0::numeric
  ORDER BY orcamento_numero, l_fixo, produto;

CREATE OR REPLACE VIEW public.vw_produtos_estoque_por_local AS
 SELECT p.codigo_produto,
    p.nome,
    p.unidade,
    p.preco_venda,
    p.cst,
    p.cest,
    p.porc_bdi,
    p.status_comercial,
    p.mascara_produto,
    e.local AS setor,
    e.quantidade,
    e.quantidade_reservada
   FROM produtos p
     JOIN estoque_itens e ON p.id = e.produto_id;

CREATE OR REPLACE VIEW public.vw_vendas_loja WITH (security_invoker=on) AS
 SELECT p.id AS produto_id,
    p.nome AS produto,
    p.sku,
    m.nome AS marca,
    p.categoria,
    si.quantidade,
    p.preco_custo,
    p.preco_venda,
    round((p.preco_venda - p.preco_custo) * si.quantidade, 2) AS margem_total,
    s.id AS separacao_id,
    s.created_at AS data_venda,
    s.cliente,
    s.observacoes
   FROM separacao_itens si
     JOIN produtos p ON p.id = si.produto_id
     JOIN separacoes s ON s.id = si.separacao_id
     LEFT JOIN marcas m ON m.id = p.marca_id
  WHERE si.produto_id IS NOT NULL AND s.projeto_id IS NULL;

CREATE OR REPLACE VIEW public.vw_vendas_produtos WITH (security_invoker=on) AS
 SELECT 'projeto'::text AS origem,
    p.id AS produto_id,
    p.nome AS produto,
    p.sku,
    m.nome AS marca,
    p.categoria,
    si.quantidade,
    p.preco_custo,
    p.preco_venda,
    round((p.preco_venda - p.preco_custo) * si.quantidade, 2) AS margem_total,
    s.created_at AS data_venda,
    pr.codigo AS projeto_codigo,
    pr.nome AS projeto_nome,
    COALESCE(cli.nome, s.cliente) AS cliente
   FROM separacao_itens si
     JOIN produtos p ON p.id = si.produto_id
     JOIN separacoes s ON s.id = si.separacao_id
     JOIN projetos pr ON pr.id = s.projeto_id
     LEFT JOIN marcas m ON m.id = p.marca_id
     LEFT JOIN contatos cli ON cli.id = pr.cliente_id
  WHERE si.produto_id IS NOT NULL AND s.projeto_id IS NOT NULL
UNION ALL
 SELECT 'loja'::text AS origem,
    p.id AS produto_id,
    p.nome AS produto,
    p.sku,
    m.nome AS marca,
    p.categoria,
    si.quantidade,
    p.preco_custo,
    p.preco_venda,
    round((p.preco_venda - p.preco_custo) * si.quantidade, 2) AS margem_total,
    s.created_at AS data_venda,
    NULL::character varying AS projeto_codigo,
    NULL::text AS projeto_nome,
    s.cliente
   FROM separacao_itens si
     JOIN produtos p ON p.id = si.produto_id
     JOIN separacoes s ON s.id = si.separacao_id
     LEFT JOIN marcas m ON m.id = p.marca_id
  WHERE si.produto_id IS NOT NULL AND s.projeto_id IS NULL;

DROP VIEW IF EXISTS public.vw_produtos_custo_restrito;
