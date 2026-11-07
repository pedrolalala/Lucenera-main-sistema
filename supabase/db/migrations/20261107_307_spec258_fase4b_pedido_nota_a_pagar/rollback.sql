-- SPEC-258 Fase 4b: remove o espelho do a pagar. Títulos/parcelas/baixas já espelhados PERMANECEM (histórico financeiro não se apaga);
-- depois do rollback, pedido/nota/pagamento deixam de ser espelhados: avisar o financeiro antes.
DROP VIEW IF EXISTS public.vw_financeiro_ponte_pagar_integridade;
DROP TRIGGER IF EXISTS trg_fin_ponte_boleto_cp ON public.boletos;
DROP TRIGGER IF EXISTS trg_fin_ponte_nota_parcela ON public.nota_fiscal_compra_parcelas;
DROP TRIGGER IF EXISTS trg_fin_ponte_nota ON public.notas_fiscais_compra;
DROP TRIGGER IF EXISTS trg_fin_ponte_pedido_parcela ON public.pedido_compra_parcelas;
DROP TRIGGER IF EXISTS trg_fin_ponte_pedido ON public.pedidos_compra;
DROP FUNCTION IF EXISTS public.trg_financeiro_ponte_pagar();
DROP FUNCTION IF EXISTS public.financeiro_responder_pedido_pago(uuid, boolean, date, uuid, text);
DROP FUNCTION IF EXISTS public.financeiro_pedido_pergunta(uuid);
DROP FUNCTION IF EXISTS public.financeiro_ponte_nota(uuid);
DROP FUNCTION IF EXISTS public.financeiro_ponte_pedido(uuid);
DROP FUNCTION IF EXISTS public.financeiro_plano_compras();
-- a tabela de confirmações guarda respostas do usuário: só apagar se estiver vazia.
-- DROP TABLE public.financeiro_pedido_pagamento_confirmacao;
