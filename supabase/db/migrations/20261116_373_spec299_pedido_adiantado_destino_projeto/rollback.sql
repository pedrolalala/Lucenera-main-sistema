-- Rollback SPEC-299: recria as 2 views como estavam antes e apaga RPCs/tabela de reserva.
BEGIN;
CREATE OR REPLACE VIEW public.vw_necessidade_compra_pedidos_abertos WITH (security_invoker = true) AS
 WITH pedidos_abertos AS (
         SELECT pci.produto_id,
            pc.id AS pedido_id,
            pc.status,
            pc.data_prevista_entrega,
            (pci.quantidade - pci.qtd_recebida) AS qtd_pendente_item
           FROM (pedido_compra_itens pci
             JOIN pedidos_compra pc ON ((pc.id = pci.pedido_id)))
          WHERE (pc.status <> ALL (ARRAY['recebido'::text, 'cancelado'::text]))
        ), pedido_mais_urgente AS (
         SELECT DISTINCT ON (pedidos_abertos.produto_id) pedidos_abertos.produto_id,
            pedidos_abertos.status AS status_mais_critico
           FROM pedidos_abertos
          ORDER BY pedidos_abertos.produto_id, pedidos_abertos.data_prevista_entrega, pedidos_abertos.pedido_id
        )
 SELECT pa.produto_id,
    count(DISTINCT pa.pedido_id) AS qtd_pedidos_abertos,
    sum(pa.qtd_pendente_item) AS qtd_em_pedidos_abertos,
    min(pa.data_prevista_entrega) AS proxima_data_prevista_entrega,
    pmu.status_mais_critico
   FROM (pedidos_abertos pa
     JOIN pedido_mais_urgente pmu ON ((pmu.produto_id = pa.produto_id)))
  GROUP BY pa.produto_id, pmu.status_mais_critico;
CREATE OR REPLACE VIEW public.vw_necessidade_compra_item_orcamento AS
 WITH cobertura_pedidos AS (
         SELECT pcio.projeto_item_id,
            sum(pcio.quantidade_atendida) AS qtd_coberta_por_pedido_aberto
           FROM ((pedido_compra_item_origem pcio
             JOIN pedido_compra_itens pci ON ((pci.id = pcio.pedido_compra_item_id)))
             JOIN pedidos_compra pc ON ((pc.id = pci.pedido_id)))
          WHERE ((pc.status <> ALL (ARRAY['recebido'::text, 'cancelado'::text])) AND (pcio.quantidade_atendida IS NOT NULL))
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
            COALESCE(cob.qtd_coberta_por_pedido_aberto, (0)::numeric) AS qtd_coberta_por_pedido_aberto,
            GREATEST((0)::numeric, (esp.q_entrega_futura - COALESCE(cob.qtd_coberta_por_pedido_aberto, (0)::numeric))) AS pendente_item,
            o.empresa_id,
            emp.nome AS empresa_nome
           FROM (((((((projeto_itens pi
             JOIN vw_produtos_custo_restrito p ON (((p.id = pi.produto_id) AND (p.ativo = true))))
             JOIN estoque_saldos_projeto_item esp ON (((esp.projeto_item_id = pi.id) AND (esp.status_operacional = 'ativo'::text))))
             LEFT JOIN orcamentos o ON ((o.id = pi.orcamento_id)))
             LEFT JOIN marcas mk ON ((mk.id = p.marca_id)))
             LEFT JOIN contatos forn ON ((forn.id = COALESCE(p.fornecedor_principal_id, mk.fornecedor_id))))
             LEFT JOIN cobertura_pedidos cob ON ((cob.projeto_item_id = pi.id)))
             LEFT JOIN empresas emp ON ((emp.id = o.empresa_id)))
          WHERE (pi.orcamento_item_id IS NOT NULL)
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
    pendente_item,
    empresa_id,
    empresa_nome
   FROM base
  WHERE (pendente_item > (0)::numeric)
  ORDER BY orcamento_numero, l_fixo, produto;
DROP FUNCTION IF EXISTS public.buscar_projetos_para_reserva(text, uuid);
DROP FUNCTION IF EXISTS public.destinos_projeto_do_pedido(uuid);
DROP FUNCTION IF EXISTS public.liberar_destino_projeto_pedido_item(uuid, text);
DROP FUNCTION IF EXISTS public.reservar_pedido_item_para_projeto(uuid, uuid, numeric);
DROP TABLE IF EXISTS public.pedido_compra_item_destino_projeto;
COMMIT;
