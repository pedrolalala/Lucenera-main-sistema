-- SPEC-182 (C2, 06/10/2026): consulta de peça do Cadastro com abas por setor no
-- modelo do Connect. Uma linha por item de venda (projeto_item) com a quantidade
-- da peça em cada setor + os dados da venda (orçamento, venda, vendedor,
-- cliente, datas e valor total do orçamento — decisão do usuário 06/10).
-- Entregue = histórico (q_entregue não baixa na devolução, SPEC-182 D7).
-- A view de pedidos de compra da peça ganha data de emissão e perfil (colunas
-- novas no fim; usada também pelo Compras).
-- Sem BEGIN/COMMIT no texto (aplicar com dry-run + rollback antes).

CREATE OR REPLACE VIEW public.vw_cadastro_produto_movimentos
WITH (security_invoker = true) AS
SELECT
  pi.produto_id,
  esp.projeto_item_id,
  pi.orcamento_id,
  o.numero                         AS orcamento_numero,
  o.numero_venda                   AS venda_numero,
  f.nome                           AS funcionario_nome,
  c.nome                           AS cliente_nome,
  pr.codigo                        AS projeto_codigo,
  pi.l_fixo,
  o.data_emissao                   AS data_orcamento,
  o.previsao_entrega               AS data_entrega,
  o.valor_total                    AS valor_total_orcamento,
  esp.q_reserva,
  esp.q_entrega_futura,
  esp.q_ag_separar + esp.q_separado AS q_separacao,
  esp.q_entregue,
  esp.q_devolvida_entregue,
  esp.status_operacional
FROM public.estoque_saldos_projeto_item esp
JOIN public.projeto_itens pi ON pi.id = esp.projeto_item_id
LEFT JOIN public.orcamentos o ON o.id = pi.orcamento_id
LEFT JOIN public.projetos pr ON pr.id = pi.projeto_id
LEFT JOIN public.contatos c ON c.id = COALESCE(o.cliente_id, pr.cliente_id)
LEFT JOIN public.funcionarios f ON f.id = o.vendedor_id
WHERE pi.produto_id IS NOT NULL
  AND esp.status_operacional <> 'cancelado'
  AND (esp.q_reserva > 0 OR esp.q_entrega_futura > 0 OR esp.q_ag_separar > 0
       OR esp.q_separado > 0 OR esp.q_entregue > 0);

GRANT SELECT ON public.vw_cadastro_produto_movimentos TO authenticated;

CREATE OR REPLACE VIEW public.vw_necessidade_compra_pedido_detalhe
WITH (security_invoker = true) AS
 SELECT pci.produto_id,
    pc.id AS pedido_id,
    pc.numero,
    pc.status,
    e.nome AS empresa_nome,
    pc.data_prevista_entrega,
    (pci.quantidade - pci.qtd_recebida) AS qtd_pendente,
    pc.data_emissao,
    pc.perfil
   FROM ((pedido_compra_itens pci
     JOIN pedidos_compra pc ON ((pc.id = pci.pedido_id)))
     LEFT JOIN empresas e ON ((e.id = pc.empresa_id)))
  WHERE (pc.status <> ALL (ARRAY['recebido'::text, 'cancelado'::text]))
  ORDER BY pc.data_prevista_entrega;

NOTIFY pgrst, 'reload schema';
