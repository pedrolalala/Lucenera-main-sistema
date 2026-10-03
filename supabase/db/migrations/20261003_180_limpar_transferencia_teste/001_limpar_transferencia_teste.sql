-- 03/10/2026 (pedido do usuário: "pode apagar a transferência pois são testes"):
-- remove as 2 trocas de reserva de TESTE entre os aros da VENDA-0001
-- (projeto_item bb20260e…) e da VENDA-0002 (373df1a5…): 5 peças foram em 15/09 e
-- voltaram em 22/09, mesmo usuário. O efeito líquido nos saldos é zero; sobravam só
-- q_transferida_saida = 5 nos dois itens, as 2 linhas de transferencias_estoque e os
-- 4 movimentos. Sem FK nem trigger em transferencias_estoque.
-- Sem BEGIN/COMMIT no texto (aplicar com dry-run + rollback antes).

DELETE FROM public.estoque_movimentos_projeto_item
WHERE origem = 'transferencia_estoque'
  AND referencia_id IN ('959f9016-3abe-45a5-bd88-b321a1d3b5fd', '27450cb2-2c3b-4ab3-bc2d-0817437d570b');

DELETE FROM public.transferencias_estoque
WHERE id IN ('959f9016-3abe-45a5-bd88-b321a1d3b5fd', '27450cb2-2c3b-4ab3-bc2d-0817437d570b');

UPDATE public.estoque_saldos_projeto_item
SET q_transferida_saida = q_transferida_saida - 5,
    atualizado_em = now()
WHERE projeto_item_id IN ('bb20260e-aece-45cf-8828-7cdfc379234e', '373df1a5-5b47-4335-8faf-9d7ecede6296')
  AND q_transferida_saida = 5;
