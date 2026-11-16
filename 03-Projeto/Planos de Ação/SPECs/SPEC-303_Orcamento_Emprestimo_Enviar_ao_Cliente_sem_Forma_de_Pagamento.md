---
titulo: "SPEC-303 — Empréstimo: botão 'Enviar para o Cliente' trava na lista geral"
status: código corrigido localmente (tsc ok), NÃO publicado; sem migration
data_ultima_modificacao: 2026-11-13
sistemas_envolvidos:
  - Orçamentos (04-Sistemas/gestao-financeira-clone-544cb (1))
---

# SPEC-303

**Origem:** pedido do usuário em 13/11/2026: orçamento de empréstimo não tem forma de pagamento e, ao enviar para o cliente, trava; "preciso que passe para frente".

## Causa
Pela SPEC-223 o empréstimo nunca vai para o cliente (gatilho `orcamento_emprestimo_guard` barra; fluxo = "Confirmar empréstimo" dentro do orçamento). A aba Rascunho já mostrava "Confirmar empréstimo", mas a linha da lista geral (`BudgetTableRow`) ainda mostrava "Enviar para o Cliente", que chama `enviar_orcamento_para_cliente` e trava (exige forma de pagamento; e o gatilho barra mesmo assim).

## Mudança
- `BudgetTableRow.tsx`: rascunho de empréstimo mostra "Confirmar empréstimo" (abre o orçamento no quadro do empréstimo); os demais mantêm "Enviar para o Cliente".
- Migration 360 (afrouxar a função) foi ensaiada, barrada pelo gatilho e DESCARTADA; nada alterado no banco.

## Pendente
- [ ] Commit/publicação do Orçamentos e teste do usuário (ORC-0070 é o empréstimo em rascunho).
