-- SPEC-253: previsão de chegada por peça, para a Venda Parcial e a janela Transferir.
-- Só leitura: lista as compras em andamento (pedido aprovado ou parcialmente recebido, com item ainda não recebido por inteiro).
-- Não expõe custo, fornecedor nem valor. security_invoker: vale o RLS de quem consulta (as tabelas já são legíveis por authenticated).
CREATE OR REPLACE VIEW public.vw_previsao_chegada_produto
WITH (security_invoker = true) AS
SELECT
    i.produto_id,
    p.id                                              AS pedido_id,
    p.numero                                          AS pedido_numero,
    p.status                                          AS pedido_status,
    p.data_prevista_entrega,
    (i.quantidade - COALESCE(i.qtd_recebida, 0))      AS qtd_pendente,
    s.projeto_id                                      AS projeto_id
FROM public.pedido_compra_itens i
JOIN public.pedidos_compra p ON p.id = i.pedido_id
LEFT JOIN public.solicitacoes_compra s ON s.id = i.solicitacao_id
WHERE p.status IN ('aprovado', 'parcialmente_recebido')
  AND i.quantidade > COALESCE(i.qtd_recebida, 0);

REVOKE ALL ON public.vw_previsao_chegada_produto FROM PUBLIC, anon;
GRANT SELECT ON public.vw_previsao_chegada_produto TO authenticated;

COMMENT ON VIEW public.vw_previsao_chegada_produto IS
  'SPEC-253: compras em andamento por peça (pedido, data prevista, quantidade pendente, projeto da solicitação quando houver). Sem custo.';
