---
titulo: "SPEC-317 — Compras: escolher o fornecedor por produto no pedido em montagem (Necessidade de Compra)"
status: concluida
data_ultima_modificacao: 2026-11-16
sistemas_envolvidos:
  - Compras (compras-lucenera-3o23t98ee) — Necessidade de Compra
---

# SPEC-317 — Escolher o fornecedor por produto no pedido em montagem

## Origem
Central de Solicitações (Débora, 12/11): "colocar mais de um fornecedor no mesmo pedido". A SPEC-316 liberou juntar fornecedores diferentes, mas a Débora respondeu (16/11) que a opção só existia no Pedido Avulso: na Necessidade de Compra o fornecedor vinha fixo do cadastro e não dava para trocar. Decisão do usuário (16/11): seguir com seletor por item.

## Checklist de Ação
- [x] Banner "Pedido em montagem": botão "Fornecedor por produto" lista os produtos do pedido, cada um com seletor de fornecedor (busca por nome, como no Pedido Avulso); troca vale para todas as linhas do produto.
- [x] Produto/marca sem fornecedor cadastrado deixa de ficar desabilitado: entra no pedido marcado em vermelho ("Escolher fornecedor"); "Fechar pedido" só libera com todos os fornecedores definidos.
- [x] Ao fechar continua saindo um pedido de compra por fornecedor (SPEC-316). Sem mudança de banco, PDF, financeiro ou NF.
- [x] Commit 8f1f4d6 (Compras), publicado em compras-lucenera por wrangler, só com esta mudança (código da SPEC-299 segue sem commit).
- [ ] Teste da Débora (trocar fornecedor de um item; item sem fornecedor).

## Fora do escopo
Um único pedido de compra com vários fornecedores (exigiria mudança de banco, PDF, financeiro e NF).

## Rollback
Reverter o commit 8f1f4d6 do Compras (nenhuma migration).
