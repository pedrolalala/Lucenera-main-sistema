---
titulo: "SPEC-212 — Compras: tirar peça no Fechar pedido de compra (Necessidade de Compra)"
status: pendente
data_ultima_modificacao: 2026-10-20
sistemas_envolvidos:
  - Compras (compras-lucenera-3o23t98ee, compras-lucenera.pages.dev)
---

# SPEC-212 — Compras: tirar peça no Fechar pedido de compra

## Checklist de Ação

- [x] Coluna **Tirar** (caixa de marcar) na janela "Fechar pedido de compra", igual à do Editar pedido
- [x] Linha tirada fica riscada, com quantidade e preço travados, e não entra no pedido, nos totais nem na validação
- [x] Coluna **Total do item (R$)** (quantidade × total por unidade), igual ao Editar pedido (SPEC-211)
- [x] Botão mostra quantos itens vão no pedido: "Confirmar pedido (N itens)"; sem nenhum item, fica desativado
- [x] `vite build` ok e publicado

### Passos manuais do usuário

- [ ] Montar um pedido com uma peça a mais, abrir "Fechar pedido", marcar Tirar nela e confirmar: o pedido sai sem ela

## Objetivo

Pedido do usuário em 20/10/2026: no "Fechar pedido de compra" da Necessidade de Compra dava para mudar a quantidade,
mas não para excluir uma peça selecionada a mais. Deixar igual ao Editar pedido, que tem a coluna Tirar.

## Definição da SPEC

- `ModalGerarCompraItemOrcamento.tsx`: campo `remover` por linha; o pedido (`criar_pedido_compra_lote`) e o vínculo
  de origem por índice usam só as linhas não tiradas (`ativas`), na mesma ordem.
- A peça tirada não vira pedido e continua na Necessidade de Compra. Ao confirmar, o "pedido em montagem" é
  esvaziado como antes; se fechar a janela sem confirmar, a peça continua marcada no pedido em montagem.
- Sem migration.

## Realizado

### 2026-10-20

- Compras 3c367e9, no ar.
