-- SPEC-231 C1 (reunião 26/10/2026): na consulta da peça (Cadastro → abas Reserva / Entrega Futura / Separação /
-- Entregue), TODO MUNDO vê de quem é a peça — orçamento, venda, funcionário, cliente, projeto, quantidade, datas —
-- para poder pedir emprestado à colega ("Marina, preciso de uma lâmpada da venda tal"). Só o VALOR da venda continua
-- só para a própria equipe (mesma regra da SPEC-200).
--
-- Antes: security_invoker = true → a política restritiva spec200_orcamentos_equipe escondia o orçamento das outras
-- equipes e a linha aparecia sem venda/funcionário/datas.
-- Agora: a view roda como o dono (postgres) e leva no WHERE o mesmo portão de sistemas que orcamentos tem
-- (spec196_orcamentos_select); o valor_total_orcamento vem nulo quando o orçamento é de outra equipe
-- (mesma condição da spec200_orcamentos_equipe). Sem grant para anon.

BEGIN;

CREATE OR REPLACE VIEW public.vw_cadastro_produto_movimentos AS
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
    CASE
      WHEN o.id IS NULL THEN NULL
      WHEN (SELECT public.orcamentos_equipe_restrita()) IS NULL
        OR o.equipe_id = (SELECT public.orcamentos_equipe_restrita())
        OR o.digitado_por = (SELECT auth.uid())
      THEN o.valor_total
    END::numeric(12,2) AS valor_total_orcamento,
    esp.q_reserva,
    esp.q_entrega_futura,
    esp.q_ag_separar + esp.q_separado AS q_separacao,
    esp.q_entregue,
    esp.q_devolvida_entregue,
    esp.status_operacional,
    COALESCE(( SELECT min(h.created_at) AS min
           FROM historico_status_orcamentos h
          WHERE h.orcamento_id = o.id AND h.status_novo ~~* 'Or_amento Aprovado'::text), o.aprovado_cliente_em) AS data_venda
   FROM estoque_saldos_projeto_item esp
     JOIN projeto_itens pi ON pi.id = esp.projeto_item_id
     LEFT JOIN orcamentos o ON o.id = pi.orcamento_id
     LEFT JOIN projetos pr ON pr.id = pi.projeto_id
     LEFT JOIN contatos c ON c.id = COALESCE(o.cliente_id, pr.cliente_id)
     LEFT JOIN funcionarios f ON f.id = o.vendedor_id
  WHERE pi.produto_id IS NOT NULL AND esp.status_operacional <> 'cancelado'::text AND (esp.q_reserva > 0::numeric OR esp.q_entrega_futura > 0::numeric OR esp.q_ag_separar > 0::numeric OR esp.q_separado > 0::numeric OR esp.q_entregue > 0::numeric)
    -- portão: o mesmo da política spec196_orcamentos_select
    AND ( SELECT public.pode_acessar_algum(ARRAY['orcamentos'::text, 'crm'::text, 'financeiro'::text, 'dashboard-financeiro'::text, 'separacao-parcial'::text, 'vendas'::text, 'logistica'::text, 'necessidade-de-compra'::text, 'controle-producao'::text, 'controle-garantia'::text, 'cadastro'::text, 'rh'::text, 'solicitacoes'::text]));

ALTER VIEW public.vw_cadastro_produto_movimentos SET (security_invoker = false);

REVOKE ALL ON public.vw_cadastro_produto_movimentos FROM anon, PUBLIC;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.vw_cadastro_produto_movimentos FROM authenticated;
GRANT SELECT ON public.vw_cadastro_produto_movimentos TO authenticated;

COMMIT;
