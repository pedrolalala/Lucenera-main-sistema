-- SPEC-243 (RASCUNHO, NÃO APLICADA) — Consultar produtos: setores "Reserva herança Connect" e "Entrega futura herança Connect".
-- Decisão da reunião de 04/11: a Connect aparece em setores PRÓPRIOS (só visualização), separados da Reserva/Entrega Futura do sistema.
-- Hoje, depois da carga dos 191 orçamentos Connect, vw_cadastro_produto_setores soma tudo junto (Reserva e Entrega Futura do sistema
-- passam a mostrar a Connect). Esta migration só ADICIONA a coluna `origem` e separa as somas; nenhum dado é alterado.
--
-- Por que a origem entra na view de saldos (e não por JOIN em orcamentos nas views do Cadastro): vw_cadastro_produto_setores é
-- security_invoker; um JOIN com orcamentos aplicaria o RLS por equipe (SPEC-200) e o total da peça mudaria de usuário para usuário.
-- vw_estoque_saldos_projeto_item roda como dono, então a origem sai igual para todos.
--
-- Todas as views só GANHAM uma coluna no fim (CREATE OR REPLACE exige isso); consumidores por nome de coluna não quebram.
BEGIN;

-- 1) saldos por item: + origem
CREATE OR REPLACE VIEW public.vw_estoque_saldos_projeto_item AS
 SELECT esp.projeto_item_id,
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
    esp.atualizado_em,
    o.numero_venda AS venda_numero,
    esp.q_devolvida_entregue,
    o.empresa_id,
    COALESCE(o.origem, 'sistema'::text) AS origem
   FROM ((((estoque_saldos_projeto_item esp
     JOIN projeto_itens pi ON ((pi.id = esp.projeto_item_id)))
     LEFT JOIN projetos pr ON ((pr.id = pi.projeto_id)))
     LEFT JOIN orcamentos o ON ((o.id = pi.orcamento_id)))
     LEFT JOIN produtos p ON ((p.id = pi.produto_id)));

-- 2) saldos ativos por peça/projeto: + origem
CREATE OR REPLACE VIEW public.vw_estoque_por_produto_projeto
WITH (security_invoker = true) AS
 SELECT projeto_item_id,
    projeto_id,
    orcamento_id,
    produto_id,
    cliente_id,
    produto,
    produto_codigo,
    projeto_codigo,
    orcamento_numero,
    q_venda,
    q_reserva,
    q_entrega_futura,
    q_ag_separar,
    q_separado,
    q_entregue,
    q_devolvida,
    q_transferida_saida,
    status_operacional,
    atualizado_em,
    origem
   FROM vw_estoque_saldos_projeto_item
  WHERE (status_operacional = 'ativo'::text);

-- 3) setores da peça: Reserva / Separação / Entrega Futura = SÓ vendas do sistema (como antes da carga);
--    Connect em colunas próprias, no fim.
CREATE OR REPLACE VIEW public.vw_cadastro_produto_setores
WITH (security_invoker = true) AS
 SELECT produto_id,
    COALESCE(sum(q_reserva) FILTER (WHERE origem <> 'connect'), (0)::numeric) AS q_reserva,
    (COALESCE(sum(q_ag_separar) FILTER (WHERE origem <> 'connect'), (0)::numeric)
       + COALESCE(sum(q_separado) FILTER (WHERE origem <> 'connect'), (0)::numeric)) AS q_separacao,
    COALESCE(sum(q_entrega_futura) FILTER (WHERE origem <> 'connect'), (0)::numeric) AS q_entrega_futura,
    COALESCE(sum(q_reserva) FILTER (WHERE origem = 'connect'), (0)::numeric) AS q_reserva_connect,
    COALESCE(sum(q_entrega_futura) FILTER (WHERE origem = 'connect'), (0)::numeric) AS q_entrega_futura_connect
   FROM vw_estoque_por_produto_projeto v
  GROUP BY produto_id;

-- 4) abas de detalhe da peça (Reserva / Entrega Futura / Separação por venda): + origem
CREATE OR REPLACE VIEW public.vw_cadastro_produto_movimentos
WITH (security_invoker = false) AS
 SELECT pi.produto_id,
    esp.projeto_item_id,
    pi.orcamento_id,
    o.numero AS orcamento_numero,
    o.numero_venda AS venda_numero,
    f.nome AS funcionario_nome,
    c.nome AS cliente_nome,
    pr.codigo AS projeto_codigo,
    pi.l_fixo,
    o.data_emissao AS data_orcamento,
    o.previsao_entrega AS data_entrega,
    (
        CASE
            WHEN (o.id IS NULL) THEN NULL::numeric
            WHEN ((( SELECT orcamentos_equipe_restrita() AS orcamentos_equipe_restrita) IS NULL) OR (o.equipe_id = ( SELECT orcamentos_equipe_restrita() AS orcamentos_equipe_restrita)) OR (o.digitado_por = ( SELECT auth.uid() AS uid))) THEN o.valor_total
            ELSE NULL::numeric
        END)::numeric(12,2) AS valor_total_orcamento,
    esp.q_reserva,
    esp.q_entrega_futura,
    (esp.q_ag_separar + esp.q_separado) AS q_separacao,
    esp.q_entregue,
    esp.q_devolvida_entregue,
    esp.status_operacional,
    COALESCE(( SELECT min(h.created_at) AS min
           FROM historico_status_orcamentos h
          WHERE ((h.orcamento_id = o.id) AND (h.status_novo ~~* 'Or_amento Aprovado'::text))), o.aprovado_cliente_em) AS data_venda,
    COALESCE(o.origem, 'sistema'::text) AS origem
   FROM (((((estoque_saldos_projeto_item esp
     JOIN projeto_itens pi ON ((pi.id = esp.projeto_item_id)))
     LEFT JOIN orcamentos o ON ((o.id = pi.orcamento_id)))
     LEFT JOIN projetos pr ON ((pr.id = pi.projeto_id)))
     LEFT JOIN contatos c ON ((c.id = COALESCE(o.cliente_id, pr.cliente_id))))
     LEFT JOIN funcionarios f ON ((f.id = o.vendedor_id)))
  WHERE ((pi.produto_id IS NOT NULL) AND (esp.status_operacional <> 'cancelado'::text) AND ((esp.q_reserva > (0)::numeric) OR (esp.q_entrega_futura > (0)::numeric) OR (esp.q_ag_separar > (0)::numeric) OR (esp.q_separado > (0)::numeric) OR (esp.q_entregue > (0)::numeric)) AND ( SELECT pode_acessar_algum(ARRAY['orcamentos'::text, 'crm'::text, 'financeiro'::text, 'dashboard-financeiro'::text, 'separacao-parcial'::text, 'vendas'::text, 'logistica'::text, 'necessidade-de-compra'::text, 'controle-producao'::text, 'controle-garantia'::text, 'cadastro'::text, 'rh'::text, 'solicitacoes'::text]) AS pode_acessar_algum));

COMMIT;
