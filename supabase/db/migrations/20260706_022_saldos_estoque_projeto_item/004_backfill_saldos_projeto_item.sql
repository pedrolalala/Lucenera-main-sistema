-- Migration 20260706_022 — Parte 4
-- SPEC-010: backfill de estoque_saldos_projeto_item para projeto_itens
-- aprovados antes desta migration existir.
--
-- Decisão conservadora (registrada como pendência aberta na SPEC-010,
-- seção "Pendências"): todo o saldo histórico entra como q_reserva, sem
-- tentar reconstruir, por item, quanto já tinha cobertura física real no
-- momento da aprovação original. Motivo: o histórico de estoque físico
-- daquele momento não é recuperável com precisão (quantidade_reservada é um
-- agregado por produto, não por item), e superestimar q_reserva é o lado
-- seguro do erro — não cria uma falsa "entrega futura" para itens que já
-- foram normalmente entregues no fluxo antigo.
--
-- Critério de seleção: pi.validado = true (não o texto de status do
-- orçamento). validado é o flag que aprovar_orcamento_financeiro liga na
-- aprovação e cancelar_orcamento desliga no cancelamento — é a fonte de
-- verdade real do código, e evita ter que adivinhar entre os valores de
-- status já registrados como legados/inconsistentes em
-- supabase/docs/status_enums.md ('aprovado', 'Orçamento Aprovado',
-- 'aprovado_cliente', 'aprovado_financeiro').
--
-- Idempotente: ON CONFLICT DO NOTHING preserva qualquer linha já criada pelo
-- fluxo novo (002_atualizar_aprovacao_cancelamento_entrega.sql) com a
-- divisão real reserva/entrega futura; só preenche o que faltar.

WITH saldos_inseridos AS (
INSERT INTO public.estoque_saldos_projeto_item (
    projeto_item_id,
    q_reserva,
    q_entrega_futura
)
SELECT
    pi.id,
    coalesce(pi.quantidade, 0),
    0
FROM public.projeto_itens pi
WHERE pi.produto_id IS NOT NULL
  AND coalesce(pi.quantidade, 0) > 0
  AND pi.validado = true
ON CONFLICT (projeto_item_id) DO NOTHING
RETURNING projeto_item_id, q_reserva
)

-- Auditoria do backfill: um movimento por linha criada acima (evita
-- duplicar auditoria se a migration for reexecutada).
INSERT INTO public.estoque_movimentos_projeto_item (
    projeto_item_id, tipo, quantidade, origem, referencia_id, observacao
)
SELECT
    si.projeto_item_id,
    'aprovacao_orcamento',
    si.q_reserva,
    'backfill_spec010',
    pi.orcamento_id,
    'Saldo criado por backfill da SPEC-010 (conservador: 100% em q_reserva).'
FROM saldos_inseridos si
JOIN public.projeto_itens pi ON pi.id = si.projeto_item_id;

-- Relatório de conferência (rodar manualmente após a migration, não faz
-- parte da migration em si): itens cujo q_reserva de backfill excede o
-- saldo físico disponível hoje — produto pode estar sobre-comprometido no
-- histórico e merece revisão manual antes de confiar na tela de estoque.
--
-- SELECT esp.projeto_item_id, pi.produto_id, p.nome, esp.q_reserva,
--        ei.quantidade, ei.quantidade_reservada
-- FROM public.estoque_saldos_projeto_item esp
-- JOIN public.projeto_itens pi ON pi.id = esp.projeto_item_id
-- JOIN public.produtos p ON p.id = pi.produto_id
-- LEFT JOIN public.estoque_itens ei
--        ON ei.produto_id = pi.produto_id AND ei.local = 'Estoque'
-- WHERE esp.q_reserva > coalesce(ei.quantidade, 0)
-- ORDER BY p.nome;
