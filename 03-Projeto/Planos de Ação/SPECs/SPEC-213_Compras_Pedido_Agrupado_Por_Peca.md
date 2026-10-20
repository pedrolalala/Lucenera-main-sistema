---
titulo: "SPEC-213 — Compras: mesma peça de vários L numa linha só (Editar pedido e PDF do fornecedor)"
status: pendente
data_ultima_modificacao: 2026-10-20
sistemas_envolvidos:
  - Compras (compras-lucenera-3o23t98ee, compras-lucenera.pages.dev)
---

# SPEC-213 — Compras: pedido agrupado por peça no Editar e no PDF

## Checklist de Ação

- [x] Editar pedido: a mesma peça (vários L) aparece numa linha só, com quantidade e total somados
- [x] Embaixo do nome da peça, de quais L vem a quantidade (ex.: "L14: 30 · L35: 6 · L15: 4")
- [x] PDF do fornecedor: a mesma peça numa linha só (quantidade e subtotal somados)
- [x] `vite build` ok; PDF do pedido real 1783 conferido (peça 12822: 30 + 6 + 4 = 40 numa linha)
- [x] Publicar

### Passos manuais do usuário

- [ ] Abrir Editar no pedido 1783 e conferir a peça 12822 numa linha com 40
- [ ] Baixar o PDF e conferir que não há peça repetida

## Objetivo

Pedido do usuário em 20/10/2026: no Editar pedido, o pedido feito por L vinha separado por L; quando é a mesma peça,
precisa ficar tudo junto, com a soma total daquela peça. No PDF para o fornecedor, a mesma lógica: a mesma peça não
pode aparecer em várias linhas.

## Definição da SPEC

- No banco nada muda: cada L continua sendo um item do pedido (o vínculo com a venda, `pedido_compra_item_origem`,
  é por item). O agrupamento é só na tela e no PDF. Sem migration.
- Editar pedido (`EditarPedidoDialog.tsx`):
  - agrupa por `produto_id`, na ordem do pedido; preço de custo, ST, IPI e outras despesas vêm da primeira linha e,
    ao salvar, valem para todas as linhas da peça;
  - a quantidade digitada é o total da peça. Ao salvar ela é redistribuída: o que **aumentar** vai para a primeira
    linha; o que **diminuir** sai das últimas linhas da lista. Linha que zera é tirada do pedido, e a necessidade
    daquele L volta a aparecer (a RPC `editar_pedido_compra` já devolve à necessidade o que for reduzido);
  - "Tirar" tira todas as linhas da peça.
- `getItensDoPedido` passa a trazer o L de cada linha (`pedido_compra_item_origem → projeto_itens.l_fixo`);
  leitura conferida como a Débora.
- PDF (`pdf-pedido-fornecedor-desenho.ts`): agrupa por `produto_id`; Qtd. = soma, Subtotal = soma, Vl. Unit. =
  subtotal ÷ quantidade (igual ao preço quando as linhas têm o mesmo preço).

## Realizado

### 2026-10-20

- Compras 11331fc.
