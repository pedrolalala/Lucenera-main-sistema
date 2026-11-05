BEGIN;
DELETE FROM public.estoque_movimentos_projeto_item WHERE tipo='estorno_aprovacao_orcamento';
ALTER TABLE public.estoque_movimentos_projeto_item DROP CONSTRAINT estoque_movimentos_projeto_item_tipo_check;
ALTER TABLE public.estoque_movimentos_projeto_item ADD CONSTRAINT estoque_movimentos_projeto_item_tipo_check
  CHECK (tipo = ANY (ARRAY['aprovacao_orcamento','alocacao_reserva','alocacao_entrega_futura','transferencia_saida','transferencia_entrada','recebimento_para_reserva','solicitacao_separacao','separado','entregue','devolucao','cancelamento','devolucao_recebida']));
COMMIT;
