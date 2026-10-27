-- Rollback SPEC-231 C1: volta a view como estava em 27/10 (security_invoker = true, sem portão próprio, valor sem filtro).
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
    o.valor_total AS valor_total_orcamento,
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
;

ALTER VIEW public.vw_cadastro_produto_movimentos SET (security_invoker = true);
GRANT ALL ON public.vw_cadastro_produto_movimentos TO authenticated;

COMMIT;
