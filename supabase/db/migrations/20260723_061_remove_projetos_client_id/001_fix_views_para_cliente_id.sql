-- Migration 20260723_061 - Remove projetos.client_id (coluna morta duplicada de cliente_id)
-- Parte 1/2: recria as 10 views que ainda liam de projetos.client_id, apontando para projetos.cliente_id.
-- 4 delas (pipeline, por_status, financeiro_projetos, dashboard_crm_fechamento) nao tinham fallback
-- e estavam retornando cliente/contagem vazios para 100% dos projetos, pois client_id nunca foi preenchido.

CREATE OR REPLACE VIEW public.vw_projetos_pipeline AS SELECT p.id,
    p.codigo,
    p.nome,
    p.status,
    p.data_entrada,
    (p.area_do_projeto ->> 'tipo'::text) AS tipo_projeto,
    p.cliente_id AS client_id,
    c.nome AS cliente_nome,
    COALESCE(v.valor_total, (0)::numeric) AS valor_total
   FROM ((projetos p
     LEFT JOIN contatos c ON (((c.id = p.cliente_id) AND (c.tipo = 'cliente'::contato_tipo))))
     LEFT JOIN LATERAL ( SELECT sum(vendas.valor_total) AS valor_total
           FROM vendas
          WHERE (vendas.projeto_id = p.id)) v ON (true))
  WHERE ((p.arquivado = false) OR (p.arquivado IS NULL));;

CREATE OR REPLACE VIEW public.vw_projetos_por_status AS SELECT p.status,
    count(*) AS total_projetos,
    count(DISTINCT p.cliente_id) AS total_clientes,
    COALESCE(sum(v.valor_total), (0)::numeric) AS valor_total
   FROM (projetos p
     LEFT JOIN LATERAL ( SELECT sum(vendas.valor_total) AS valor_total
           FROM vendas
          WHERE (vendas.projeto_id = p.id)) v ON (true))
  WHERE ((p.arquivado = false) OR (p.arquivado IS NULL))
  GROUP BY p.status
  ORDER BY (count(*)) DESC;;

CREATE OR REPLACE VIEW public.vw_financeiro_projetos AS SELECT p.id,
    p.codigo,
    p.nome,
    p.status,
    p.cliente_id AS client_id,
    c.nome AS cliente_nome,
    v.valor_total,
    v.valor_recebido,
    v.valor_pendente,
    v.total_parcelas,
    v.parcelas_pagas,
    v.parcelas_pendentes
   FROM ((projetos p
     LEFT JOIN contatos c ON (((c.id = p.cliente_id) AND (c.tipo = 'cliente'::contato_tipo))))
     LEFT JOIN LATERAL ( SELECT sum(vendas.valor_total) AS valor_total,
            sum(
                CASE
                    WHEN (vendas.status_pagamento = 'Pago'::status_pagamento) THEN vendas.valor_total
                    ELSE (0)::numeric
                END) AS valor_recebido,
            sum(
                CASE
                    WHEN (vendas.status_pagamento <> 'Pago'::status_pagamento) THEN vendas.valor_total
                    ELSE (0)::numeric
                END) AS valor_pendente,
            count(*) AS total_parcelas,
            count(*) FILTER (WHERE (vendas.status_pagamento = 'Pago'::status_pagamento)) AS parcelas_pagas,
            count(*) FILTER (WHERE (vendas.status_pagamento <> 'Pago'::status_pagamento)) AS parcelas_pendentes
           FROM vendas
          WHERE (vendas.projeto_id = p.id)) v ON (true));;

CREATE OR REPLACE VIEW public.vw_dashboard_crm_fechamento AS SELECT date_trunc('month'::text, (p.data_entrada)::timestamp with time zone) AS mes,
    count(*) AS total_projetos,
    count(DISTINCT p.cliente_id) AS total_clientes,
    COALESCE(sum(v.valor_total), (0)::numeric) AS valor_total,
    count(*) FILTER (WHERE ((p.area_do_projeto ->> 'tipo'::text) = 'Residential'::text)) AS projetos_residenciais,
    count(*) FILTER (WHERE ((p.area_do_projeto ->> 'tipo'::text) = 'Corporativo'::text)) AS projetos_corporativos,
    count(*) FILTER (WHERE ((p.area_do_projeto ->> 'tipo'::text) = 'Exposição Comercial'::text)) AS projetos_comerciais,
    count(*) FILTER (WHERE ((p.area_do_projeto ->> 'tipo'::text) = 'Paisagismo'::text)) AS projetos_paisagismo
   FROM (projetos p
     LEFT JOIN LATERAL ( SELECT sum(vendas.valor_total) AS valor_total
           FROM vendas
          WHERE (vendas.projeto_id = p.id)) v ON (true))
  WHERE (p.data_entrada IS NOT NULL)
  GROUP BY (date_trunc('month'::text, (p.data_entrada)::timestamp with time zone))
  ORDER BY (date_trunc('month'::text, (p.data_entrada)::timestamp with time zone)) DESC;;

CREATE OR REPLACE VIEW public.vw_estoque_saldos_projeto_item AS SELECT esp.projeto_item_id,
    pi.projeto_id,
    pi.orcamento_id,
    pi.produto_id,
    COALESCE(o.cliente_id, pr.cliente_id) AS cliente_id,
    p.nome AS produto,
    p.codigo_produto AS produto_codigo,
    pr.codigo AS projeto_codigo,
    o.numero AS orcamento_numero,
    pi.quantidade AS q_venda,
    esp.q_reserva,
    esp.q_entrega_futura,
    esp.q_ag_separar,
    esp.q_separado,
    esp.q_entregue,
    esp.q_devolvida,
    esp.q_transferida_saida,
    esp.status_operacional,
    esp.atualizado_em
   FROM ((((estoque_saldos_projeto_item esp
     JOIN projeto_itens pi ON ((pi.id = esp.projeto_item_id)))
     LEFT JOIN projetos pr ON ((pr.id = pi.projeto_id)))
     LEFT JOIN orcamentos o ON ((o.id = pi.orcamento_id)))
     LEFT JOIN produtos p ON ((p.id = pi.produto_id)));;

CREATE OR REPLACE VIEW public.vw_entrega_futura_projeto_item AS SELECT esp.projeto_item_id,
    pi.produto_id,
    p.nome AS produto,
    p.codigo_produto AS produto_codigo,
    pi.projeto_id,
    pr.codigo AS projeto_codigo,
    pi.orcamento_id,
    o.numero AS orcamento_numero,
    COALESCE(o.cliente_id, pr.cliente_id) AS cliente_id,
    c.nome AS cliente,
    pi.quantidade AS q_venda,
    esp.q_entrega_futura,
    esp.q_reserva,
    esp.q_transferida_saida,
    esp.atualizado_em,
    pi.created_at AS aberto_desde,
    (CURRENT_DATE - (pi.created_at)::date) AS dias_em_aberto
   FROM (((((estoque_saldos_projeto_item esp
     JOIN projeto_itens pi ON ((pi.id = esp.projeto_item_id)))
     LEFT JOIN produtos p ON ((p.id = pi.produto_id)))
     LEFT JOIN projetos pr ON ((pr.id = pi.projeto_id)))
     LEFT JOIN orcamentos o ON ((o.id = pi.orcamento_id)))
     LEFT JOIN contatos c ON ((c.id = COALESCE(o.cliente_id, pr.cliente_id))))
  WHERE ((esp.status_operacional = 'ativo'::text) AND (esp.q_entrega_futura > (0)::numeric))
  ORDER BY pi.created_at, p.nome;;

CREATE OR REPLACE VIEW public.vw_pedido_compra_item_origem AS SELECT pcio.id,
    pcio.pedido_compra_item_id,
    pcio.projeto_item_id,
    pcio.quantidade_atendida,
    pr.codigo AS projeto_codigo,
    pr.nome AS projeto_nome,
    o.numero AS orcamento_numero,
    c.nome AS cliente
   FROM ((((pedido_compra_item_origem pcio
     JOIN projeto_itens pi ON ((pi.id = pcio.projeto_item_id)))
     LEFT JOIN projetos pr ON ((pr.id = pi.projeto_id)))
     LEFT JOIN orcamentos o ON ((o.id = pi.orcamento_id)))
     LEFT JOIN contatos c ON ((c.id = COALESCE(o.cliente_id, pr.cliente_id))));;

CREATE OR REPLACE VIEW public.vw_pendencias_re_reserva AS SELECT espi.projeto_item_id,
    pi.produto_id,
    p.nome AS produto,
    p.codigo_produto AS produto_codigo,
    pi.projeto_id,
    pr.codigo AS projeto_codigo,
    pi.orcamento_id,
    o.numero AS orcamento_numero,
    COALESCE(o.cliente_id, pr.cliente_id) AS cliente_id,
    c.nome AS cliente,
    espi.q_entrega_futura,
    espi.q_reserva,
    COALESCE(ei.quantidade, (0)::numeric) AS qtd_fisica,
    COALESCE(ei.quantidade_reservada, (0)::numeric) AS qtd_comprometida,
    GREATEST((COALESCE(ei.quantidade, (0)::numeric) - COALESCE(ei.quantidade_reservada, (0)::numeric)), (0)::numeric) AS qtd_disponivel,
    LEAST(espi.q_entrega_futura, GREATEST((COALESCE(ei.quantidade, (0)::numeric) - COALESCE(ei.quantidade_reservada, (0)::numeric)), (0)::numeric)) AS qtd_pode_re_reservar,
    espi.atualizado_em
   FROM ((((((estoque_saldos_projeto_item espi
     JOIN projeto_itens pi ON ((pi.id = espi.projeto_item_id)))
     LEFT JOIN produtos p ON ((p.id = pi.produto_id)))
     LEFT JOIN projetos pr ON ((pr.id = pi.projeto_id)))
     LEFT JOIN orcamentos o ON ((o.id = pi.orcamento_id)))
     LEFT JOIN contatos c ON ((c.id = COALESCE(o.cliente_id, pr.cliente_id))))
     LEFT JOIN estoque_itens ei ON (((ei.produto_id = pi.produto_id) AND (ei.local = 'Estoque'::estoque_local))))
  WHERE ((espi.status_operacional = 'ativo'::text) AND (espi.q_entrega_futura > (0)::numeric) AND (GREATEST((COALESCE(ei.quantidade, (0)::numeric) - COALESCE(ei.quantidade_reservada, (0)::numeric)), (0)::numeric) > (0)::numeric));;

CREATE OR REPLACE VIEW public.vw_necessidade_compra_detalhe AS WITH deficit AS (
         SELECT estoque_itens.produto_id,
            sum(estoque_itens.quantidade) AS qtd_estoque,
            sum(estoque_itens.quantidade_reservada) AS qtd_reservada
           FROM estoque_itens
          GROUP BY estoque_itens.produto_id
         HAVING (sum(estoque_itens.quantidade_reservada) > sum(estoque_itens.quantidade))
        )
 SELECT d.produto_id,
    p.codigo_produto AS produto_codigo,
    p.nome AS produto,
    d.qtd_estoque,
    d.qtd_reservada,
    GREATEST((0)::numeric, (d.qtd_reservada - d.qtd_estoque)) AS deficit_total,
    pi.id AS projeto_item_id,
    pr.codigo AS projeto_codigo,
    pr.nome AS projeto_nome,
    o.numero AS orcamento_numero,
    COALESCE(o.cliente_id, pr.cliente_id) AS cliente_id,
    c.nome AS cliente,
    pi.quantidade AS qtd_vendida,
    esp.q_reserva,
    esp.q_entrega_futura,
    pi.created_at AS aberto_desde,
    (CURRENT_DATE - (pi.created_at)::date) AS dias_em_aberto
   FROM ((((((deficit d
     JOIN produtos p ON (((p.id = d.produto_id) AND (p.ativo = true))))
     JOIN projeto_itens pi ON ((pi.produto_id = d.produto_id)))
     JOIN estoque_saldos_projeto_item esp ON (((esp.projeto_item_id = pi.id) AND (esp.status_operacional = 'ativo'::text) AND ((esp.q_reserva > (0)::numeric) OR (esp.q_entrega_futura > (0)::numeric)))))
     LEFT JOIN projetos pr ON ((pr.id = pi.projeto_id)))
     LEFT JOIN orcamentos o ON ((o.id = pi.orcamento_id)))
     LEFT JOIN contatos c ON ((c.id = COALESCE(o.cliente_id, pr.cliente_id))))
  ORDER BY (CURRENT_DATE - (pi.created_at)::date) DESC, GREATEST((0)::numeric, (d.qtd_reservada - d.qtd_estoque)) DESC, p.nome, pr.codigo;;

CREATE OR REPLACE VIEW public.vw_transferencias_estoque AS SELECT t.id AS transferencia_id,
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
   FROM (((((((((transferencias_estoque t
     JOIN projeto_itens pi_o ON ((pi_o.id = t.origem_projeto_item_id)))
     JOIN projeto_itens pi_d ON ((pi_d.id = t.destino_projeto_item_id)))
     LEFT JOIN produtos p ON ((p.id = pi_o.produto_id)))
     LEFT JOIN projetos pr_o ON ((pr_o.id = pi_o.projeto_id)))
     LEFT JOIN orcamentos o_o ON ((o_o.id = pi_o.orcamento_id)))
     LEFT JOIN contatos c_o ON ((c_o.id = COALESCE(o_o.cliente_id, pr_o.cliente_id))))
     LEFT JOIN projetos pr_d ON ((pr_d.id = pi_d.projeto_id)))
     LEFT JOIN orcamentos o_d ON ((o_d.id = pi_d.orcamento_id)))
     LEFT JOIN contatos c_d ON ((c_d.id = COALESCE(o_d.cliente_id, pr_d.cliente_id))))
  ORDER BY t.solicitado_em DESC;;

ALTER VIEW public.vw_projetos_pipeline RENAME COLUMN client_id TO cliente_id;
ALTER VIEW public.vw_financeiro_projetos RENAME COLUMN client_id TO cliente_id;
