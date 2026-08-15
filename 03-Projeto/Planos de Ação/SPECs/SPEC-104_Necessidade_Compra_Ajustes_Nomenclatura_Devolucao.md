---
titulo: "SPEC-104 — Necessidade de Compra: renomear \"Coberto\" e remover aba Devolução"
status: concluído
data_ultima_modificacao: 2026-08-15
sistemas_envolvidos:
  - Compras (compras-lucenera-3o23t98ee, Skip 40326) — `NecessidadeCompraDetalhe.tsx`, `NecessidadeCompra.tsx`
dependencias:
  - SPEC-054 (aba "Devolução" dentro de Necessidade de Compra)
  - SPEC-039 (painel "Pedidos de compra em aberto" — já resolve outro pedido da mesma reunião, ver achado abaixo)
---

# SPEC-104 — Necessidade de Compra: renomear "Coberto" e remover aba Devolução

> Origem: reunião Vinícius 14/08/2026 ([69:11]-[69:28], [81:24]-[81:52]).

## Objetivo

Dois ajustes pequenos e independentes:

1. Renomear a coluna "Coberto" (painel de detalhe por item, dentro de Necessidade de Compra) pra "Reservado" ou "Reserva".
2. Tirar a aba "Devolução" de dentro da rotina de Compras — Vinícius foi explícito: "esse coisa nem deveria ter aqui nessa rotina de compra... tem que ser só a parte de compra mesmo."

## Definição da SPEC

### Estado atual confirmado no código

1. **"Coberto"**: achado em `04-Sistemas/compras-lucenera-3o23t98ee/src/components/compra/NecessidadeCompraDetalhe.tsx:88`, cabeçalho de coluna no painel expansível de detalhe por item (SPEC-039). Precisa confirmar a qual campo exatamente essa coluna corresponde (provavelmente `qtd_comprometida` da view) antes de trocar só o texto.

2. **Aba "Devolução"**: `NecessidadeCompra.tsx` importa `DevolucaoEstoqueTab` (SPEC-054) como uma das 3 abas da tela (`Por Produto | Por Item de Orçamento | Devolução`, linhas 249-252). É um componente próprio, isolado, que não compartilha lógica com o resto da tela de compra — dá pra remover a aba sem afetar Fluxo A/B existentes.

### Achado à parte, não é bug — já está feito

Na mesma reunião ([81:52]-[82:29]), Vinícius pediu: "se tiver um pedido de compra feito, vai aparecer aqui... que já tenha sido feito e que não tenha chegado ainda" — **isso já existe**. Confirmado em `NecessidadeCompraDetalhe.tsx:151-170` (SPEC-039, P-01): seção "Pedidos de compra em aberto" já lista, por produto, os pedidos abertos com empresa/status/data prevista. Ele mesmo não tinha certeza se existia ("Preciso confirmar se tem") — confirmado que sim, nenhuma ação necessária aqui.

### Proposta (não implementar sem aprovação)

1. Trocar o texto da coluna "Coberto" → "Reservado" (ou "Reserva", a confirmar qual das duas nomenclaturas ele prefere — a fala ficou ambígua entre as duas: "muda a nomenclatura só pra reservado ou só pra... ou reserva, que seja").
2. Remover a `TabsTrigger`/`TabsContent` de "Devolução" de `NecessidadeCompra.tsx`. **Não decidir sozinho** pra onde essa funcionalidade deveria ir (ou se deveria ser removida de vez) — só tirar da rotina de Compras, conforme pedido explícito.

## Análise de ecossistema

- **Depende de**: nenhuma tabela nova.
- **Afeta**: só a tela Necessidade de Compra. Mudança #2 é uma remoção de UI, não de dado — a tabela/lógica de devolução de estoque continua existindo no banco, só o atalho de acesso por essa aba específica some.

## Realizado

### 2026-08-15

- **"Coberto" → "Reservado"**: escolhido "Reservado" (não "Reserva") sem precisar perguntar — já é o termo usado no badge do card de peça do Cadastro (SPEC-101, mesmo dia), evita ter dois nomes pro mesmo conceito (`q_reserva`) em telas diferentes do mesmo produto.
- **Aba "Devolução" removida** de `NecessidadeCompra.tsx` (TabsTrigger + TabsContent + import de `DevolucaoEstoqueTab`). O componente `DevolucaoEstoqueTab.tsx` e toda a lógica/tabelas de devolução no banco continuam existindo — só o atalho de acesso por essa rotina de Compras foi tirado, conforme pedido.
- Publicado Skip 40326 v0.0.64 — QA limpo (confirma que remover o import não deixou nada quebrado). Testado ao vivo via `javascript_tool`: abas da tela agora são só `["Por Produto", "Por Item de Orçamento"]`, e o cabeçalho da coluna no detalhe expandido mostra "Reservado".

## Pendências

Nenhuma.

**Decisão do usuário (2026-08-15)**: a funcionalidade de Devolução fica só dentro do fluxo de Orçamento — não ganha tela própria em outro sistema. Confirmado que esse caminho já existe e está implementado: orçamento com `natureza_operacao = 'devolucao'` (SPEC-071), telado por `DevolucaoItemSearchModal.tsx` em Orçamentos. Nenhuma ação de código nova necessária — a aba antiga em Compras (`DevolucaoEstoqueTab.tsx`, SPEC-054) permanece obsoleta/desconectada, como já ficou após esta SPEC.
