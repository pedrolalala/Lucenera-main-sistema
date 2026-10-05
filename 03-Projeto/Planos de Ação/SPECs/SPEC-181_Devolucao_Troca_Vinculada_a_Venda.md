---
titulo: "SPEC-181 — Devolução/Troca vinculada obrigatoriamente a UMA venda efetivada"
status: aplicada e publicada (migration 20261005_183, Orçamentos 32554 v0.0.381 — 05/10); testada na tela
data_ultima_modificacao: 2026-10-05
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb) — formulário de orçamento, tipo Devolução
  - Banco central — orcamentos.venda_origem_id, aprovar_orcamento_financeiro
dependencias:
  - SPEC-178 / SPEC-179 / SPEC-180 (rotina de devolução)
---

# SPEC-181 — Devolução/Troca vinculada a uma venda efetivada

Regra combinada com o administrador e repassada em 05/10/2026.

## Decisões do usuário (05/10)

- Empresa, Projeto e Cliente vêm da venda e ficam **travados** (substitui o "aviso sem trava" de 03/10 — SPEC-180).
- **Uma venda por devolução**: a busca de itens mostra só os itens da venda vinculada.
- Vale para os dois subtipos de Devolução: **TROCA DEV** e **CASA COR ENTRADA**.

## Como ficou

1. Ao escolher **Devolução**, abre na hora a janela **"Vincular venda de origem"** (vendas com número de venda),
   com busca por venda, orçamento, cliente, projeto e empresa. Na aba 1 aparece o quadro "Venda de origem *" com
   "Vincular venda" / "Trocar venda" (trocar remove os itens da venda anterior).
2. Ao vincular: preenche e **trava** Empresa, Código do Projeto e Cliente (botões "+" de criar projeto/cliente também
   travados); copia vendedor e arquitetos. O resumo do topo mostra "Venda de origem".
3. Aba Produtos: "Buscar itens da venda" fica **desabilitado** até vincular; sem venda, o botão leva à aba 1.
4. Salvar sem venda é bloqueado (validação do formulário + conferência ao salvar). Item de outra venda ou empresa
   diferente da venda também bloqueia.
5. Banco (migration `20261005_183_devolucao_venda_origem`): coluna `orcamentos.venda_origem_id` (sem FK, para não
   criar relação orcamentos→orcamentos que deixaria embeds do PostgREST ambíguos) e `aprovar_orcamento_financeiro`
   recusa devolução sem venda vinculada, com empresa/cliente/projeto diferentes da venda ou com item de outra venda.
   Dry-run (ROLLBACK): venda certa aprova; sem venda e empresa diferente são recusadas. `rollback.sql` na pasta.

Arquivos: `src/pages/BudgetFormPage.tsx`, `src/components/budgets/VendaOrigemDialog.tsx` (novo),
`src/components/budgets/DevolucaoItemSearchModal.tsx`, `src/services/devolucoesService.ts`.

## Teste na tela (05/10, sem salvar)

Escolher Devolução abriu a janela sozinha; sem venda o botão de itens ficou desabilitado e salvar foi bloqueado;
vincular VENDA-0001 preencheu e travou FOCO ILUMINACAO / 26.1109 / VINICIUS BORTOLIN (+ CACAU RIBEIRO e vendedor);
a busca de itens mostrou só os 11 itens da VENDA-0001. Nenhum orçamento gravado.

## Pontos em aberto

- Orçamento de devolução antigo sem `venda_origem_id` não aprova mais (hoje só existe o ORC-0036, cancelado).
- Ao salvar sem venda E sem Tipo, a primeira mensagem é "Selecione o Tipo"; a da venda aparece em seguida.
