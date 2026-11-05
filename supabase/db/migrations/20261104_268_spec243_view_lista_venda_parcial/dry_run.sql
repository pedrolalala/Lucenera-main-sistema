-- Dry-run da 268: cria a view, confere e DESFAZ. Termina em ROLLBACK.
BEGIN;
-- SPEC-243 — lista da Venda Parcial: uma linha por venda, com a ORIGEM (sistema × connect).
-- Por quê: a tela lia vw_estoque_saldos_projeto_item inteira (1 linha por item) e agrupava no navegador. Com as vendas Connect
-- (2.645 itens) isso passaria do limite de 1.000 linhas do PostgREST e misturaria as duas origens.
-- security_invoker: vale o RLS de quem consulta (SPEC-200: a equipe só enxerga os próprios orçamentos; Estoque/Admin enxergam todos).
-- Sem nenhum valor em dinheiro (SPEC-072: a Venda Parcial não mostra dinheiro).

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


DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT origem, count(*) n, sum(itens) it, sum(q_reserva) res, sum(q_entrega_futura) ef, count(*) FILTER (WHERE venda_antiga) antigas
             FROM public.vw_venda_parcial_lista GROUP BY 1 LOOP
    RAISE NOTICE 'origem=% vendas=% itens=% reserva=% ef=% antigas=%', r.origem, r.n, r.it, r.res, r.ef, r.antigas;
  END LOOP;
  RAISE NOTICE 'CNX-7994: %', (SELECT row(venda_numero, cliente_nome, projeto_codigo, empresa_nome, equipe_nome, vendedor_nome, vendas_vinculadas_connect, itens, q_venda)::text
                               FROM public.vw_venda_parcial_lista WHERE orcamento_numero = 'CNX-7994');
  RAISE NOTICE 'anon le? %', has_table_privilege('anon', 'public.vw_venda_parcial_lista', 'SELECT');
END $$;
-- como Marina (equipe própria) e como Matheus (Estoque)
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"role":"authenticated","sub":"438d37e0-ae72-4226-83c7-15d501a49dd4"}', true);
DO $$ BEGIN RAISE NOTICE 'Marina ve % vendas connect', (SELECT count(*) FROM public.vw_venda_parcial_lista WHERE origem = 'connect'); END $$;
SELECT set_config('request.jwt.claims', '{"role":"authenticated","sub":"af3035fd-266b-4b3a-952b-cb8866096c49"}', true);
DO $$ BEGIN RAISE NOTICE 'Matheus ve % vendas connect', (SELECT count(*) FROM public.vw_venda_parcial_lista WHERE origem = 'connect'); END $$;
RESET ROLE;
ROLLBACK;
