# SPEC-283 — Orçamento: Pix/Dinheiro não mostra Boleto no Plano de Parcelas

**Data:** 2026-11-11 | **Status:** implementada | **Sistema:** Orçamentos (`gestao-financeira-clone-544cb (1)`, `BudgetFormPage.tsx`)

## Problema
Em Condição de Pagamento, com forma = Pix e data de início preenchida, o Plano de Parcelas aparecia com a parcela em "Boleto". Causa: `parcelas_config[i].forma_pagamento` guardava o padrão `'boleto'` e nunca era atualizado ao trocar a forma de cima; o seletor por parcela aparecia mesmo para formas sem escolha.

## Regra
Formas não parceláveis (`pix`, `dinheiro`) → a parcela sempre segue a forma de cima; sem seletor por parcela (só o nome). Demais formas mantêm o seletor por parcela.

## Mudança
- `recalcularParcelasConfig` e o `useEffect` de sincronização forçam a forma da linha; o efeito não sai mais cedo se alguma linha diverge.
- Render: texto fixo no lugar do `Select` quando `formaFixa`.
- `onSubmit`: `planoParcelas` usa a forma de cima para Pix/Dinheiro.

## Banco
Nenhuma mudança. Rollback: reverter o commit.

## Aceite
Pix + data → parcela mostra "Pix", sem Boleto; trocar Boleto→Pix atualiza as linhas; salvar grava `pix`.
