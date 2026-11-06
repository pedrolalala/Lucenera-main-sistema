-- SPEC-255 C/D: a lista da Venda Parcial passa a saber o tipo da operação (garantia, bonificação...) para mostrar o rótulo.
-- Só acrescenta duas colunas no FIM da view (as existentes ficam iguais). security_invoker continua valendo.
CREATE OR REPLACE VIEW public.vw_venda_parcial_lista
WITH (security_invoker = true) AS
SELECT o.id AS orcamento_id,
    o.numero AS orcamento_numero,
    o.numero_venda AS venda_numero,
    o.origem,
    o.cliente_id,
    c.nome AS cliente_nome,
    c.razao_social AS cliente_razao_social,
    p.codigo AS projeto_codigo,
    emp.nome AS empresa_nome,
    COALESCE(o.aprovado_cliente_em, o.data_emissao) AS data_venda,
    o.previsao_entrega,
    eq.equipes AS equipe_nome,
    f.nome AS vendedor_nome,
    o.vendas_vinculadas_connect,
    o.origem_connect_cod_orcamento,
    ((o.origem = 'connect'::text) AND (EXISTS ( SELECT 1
           FROM connect_reserva_ambiente r
          WHERE ((r.orcamento_id = o.id) AND r.venda_antiga)))) AS venda_antiga,
    t.itens,
    t.q_venda,
    t.q_reserva,
    t.q_entrega_futura,
    t.q_ag_separar,
    t.q_separado,
    t.q_entregue,
    o.natureza_operacao,
    o.subgrupo
   FROM ((((((orcamentos o
     JOIN ( SELECT pi.orcamento_id,
            count(*) AS itens,
            sum(pi.quantidade) AS q_venda,
            sum(s.q_reserva) AS q_reserva,
            sum(s.q_entrega_futura) AS q_entrega_futura,
            sum(s.q_ag_separar) AS q_ag_separar,
            sum(s.q_separado) AS q_separado,
            sum(s.q_entregue) AS q_entregue
           FROM (projeto_itens pi
             JOIN estoque_saldos_projeto_item s ON ((s.projeto_item_id = pi.id)))
          WHERE ((s.status_operacional = 'ativo'::text) AND (pi.orcamento_id IS NOT NULL))
          GROUP BY pi.orcamento_id) t ON ((t.orcamento_id = o.id)))
     LEFT JOIN contatos c ON ((c.id = o.cliente_id)))
     LEFT JOIN projetos p ON ((p.id = o.projeto_id)))
     LEFT JOIN empresas emp ON ((emp.id = o.empresa_id)))
     LEFT JOIN equipes_projetos eq ON ((eq.id = o.equipe_id)))
     LEFT JOIN funcionarios f ON ((f.id = o.vendedor_id)));
