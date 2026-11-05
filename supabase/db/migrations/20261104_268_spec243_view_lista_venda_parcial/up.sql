-- SPEC-243 — lista da Venda Parcial: uma linha por venda, com a ORIGEM (sistema × connect).
-- Por quê: a tela lia vw_estoque_saldos_projeto_item inteira (1 linha por item) e agrupava no navegador. Com as vendas Connect
-- (2.645 itens) isso passaria do limite de 1.000 linhas do PostgREST e misturaria as duas origens.
-- security_invoker: vale o RLS de quem consulta (SPEC-200: a equipe só enxerga os próprios orçamentos; Estoque/Admin enxergam todos).
-- Sem nenhum valor em dinheiro (SPEC-072: a Venda Parcial não mostra dinheiro).
BEGIN;

CREATE OR REPLACE VIEW public.vw_venda_parcial_lista
WITH (security_invoker = true) AS
SELECT o.id                                         AS orcamento_id,
       o.numero                                     AS orcamento_numero,
       o.numero_venda                               AS venda_numero,
       o.origem,
       o.cliente_id,
       c.nome                                       AS cliente_nome,
       c.razao_social                               AS cliente_razao_social,
       p.codigo                                     AS projeto_codigo,
       emp.nome                                     AS empresa_nome,
       coalesce(o.aprovado_cliente_em, o.data_emissao) AS data_venda,
       o.previsao_entrega,
       eq.equipes                                   AS equipe_nome,
       f.nome                                       AS vendedor_nome,
       o.vendas_vinculadas_connect,
       o.origem_connect_cod_orcamento,
       (o.origem = 'connect' AND EXISTS (
          SELECT 1 FROM public.connect_reserva_ambiente r WHERE r.orcamento_id = o.id AND r.venda_antiga)) AS venda_antiga,
       t.itens, t.q_venda, t.q_reserva, t.q_entrega_futura, t.q_ag_separar, t.q_separado, t.q_entregue
  FROM public.orcamentos o
  JOIN (SELECT pi.orcamento_id,
               count(*)                         AS itens,
               sum(pi.quantidade)               AS q_venda,
               sum(s.q_reserva)                 AS q_reserva,
               sum(s.q_entrega_futura)          AS q_entrega_futura,
               sum(s.q_ag_separar)              AS q_ag_separar,
               sum(s.q_separado)                AS q_separado,
               sum(s.q_entregue)                AS q_entregue
          FROM public.projeto_itens pi
          JOIN public.estoque_saldos_projeto_item s ON s.projeto_item_id = pi.id
         WHERE s.status_operacional = 'ativo' AND pi.orcamento_id IS NOT NULL
         GROUP BY pi.orcamento_id) t ON t.orcamento_id = o.id
  LEFT JOIN public.contatos c ON c.id = o.cliente_id
  LEFT JOIN public.projetos p ON p.id = o.projeto_id
  LEFT JOIN public.empresas emp ON emp.id = o.empresa_id
  LEFT JOIN public.equipes_projetos eq ON eq.id = o.equipe_id
  LEFT JOIN public.funcionarios f ON f.id = o.vendedor_id;

COMMENT ON VIEW public.vw_venda_parcial_lista IS
  'SPEC-243: lista da Venda Parcial, uma linha por venda com saldo operacional. origem = sistema | connect.';

REVOKE ALL ON public.vw_venda_parcial_lista FROM anon;
GRANT SELECT ON public.vw_venda_parcial_lista TO authenticated;

COMMIT;
