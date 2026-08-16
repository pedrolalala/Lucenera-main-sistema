-- Migration 20260815_117 - SPEC-110
--
-- Reunião Vinícius 14/08/2026: quando existir um sinal padrão vinculado ao
-- cliente, o campo Sinal do orçamento deveria vir pré-preenchido (mas
-- continuar editável). Decisão do usuário (Vinícius citou "cliente e
-- projeto" de forma ambígua) — implementado a nível de CLIENTE
-- (public.contatos), reutilizável entre todos os projetos/orçamentos do
-- mesmo cliente, em vez de por projeto individual.
--
-- Nullable, sem default — a maioria dos clientes não tem sinal padrão
-- fixo; BudgetFormPage.tsx só pré-preenche quando o valor existir.

ALTER TABLE public.contatos
  ADD COLUMN IF NOT EXISTS valor_sinal_padrao numeric;

COMMENT ON COLUMN public.contatos.valor_sinal_padrao IS
'SPEC-110: valor de sinal (R$) padrão desse cliente, usado para
pré-preencher (não travar) o campo Sinal ao criar um orçamento novo em
BudgetFormPage.tsx. NULL = sem padrão cadastrado, campo nasce em 0 como
antes.';
