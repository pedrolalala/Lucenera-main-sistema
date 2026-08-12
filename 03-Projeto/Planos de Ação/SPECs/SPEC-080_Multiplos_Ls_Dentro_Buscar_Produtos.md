# SPEC-080: Múltiplos L's dentro do modal "Buscar Produtos"

**Data:** 2026-08-12
**Sistema:** Orçamentos (`gestao-financeira-clone-544cb`, Skip projectId `32554`)
**Status:** Implementado, aguardando publicação no Skip

## Contexto e conflito com a SPEC-079

A tarefa formal pedia explicitamente uma **peça com um array de L's** (`{codigo_l, quantidade}[]`), com migration convertendo o L antigo em "array com 1 item" — exatamente a arquitetura que havia sido **rejeitada** na SPEC-079 (turno anterior, mesmo dia), quando o usuário confirmou "linhas separadas sem mudar o banco" depois de eu apontar que o pipeline de estoque/entrega futura/necessidade de compra já rastreia cada L como linha independente (`projeto_itens.orcamento_item_id` + `l_fixo`).

Antes de implementar, apontei o conflito ao usuário: tudo que os critérios de aceitação pediam (painel expansível, múltiplos L's por peça, várias peças ao mesmo tempo, validações, soma em tempo real) dava pra entregar **sem** mudar o banco — só levando a experiência de múltiplos L's que já existia (desde a SPEC-079, num diálogo separado) pra **dentro do próprio modal "Buscar Produtos"**, inline por peça selecionada. Usuário confirmou: manter linhas separadas, só mover a UI.

Por isso, esta SPEC é puramente de **UX/frontend** — nenhuma migration, nenhuma mudança de schema, nenhum RPC novo.

## O que mudou de fato (vs. SPEC-079)

Na SPEC-079, o fluxo "Buscar Produtos" com 1 produto selecionado abria um diálogo separado (`MultiLAddDialog`) depois de fechar o modal de busca. Essa SPEC-080:

- Move o painel de L's (`LQuantityRepeater`, já existente desde a SPEC-079 — reaproveitado sem mudanças) **pra dentro do próprio `ProductSearchModal`**, como uma linha extra da tabela que expande logo abaixo da linha da peça marcada.
- Passa a suportar **múltiplas peças com L's ao mesmo tempo** numa única sessão de busca (a SPEC-079 só cobria 1 peça por vez; selecionar várias peças diferentes pulava direto pro modelo antigo de 1 linha cada).
- `ProductSearchModal.onConfirm` muda de assinatura: em vez de `(produtos: ProductSearchItem[]) => void` (lista achatada, 1 entrada por linha), agora é `(selections: ProductSelectionEntry[]) => void`, onde cada seleção carrega `{ product, entries: LEntry[] }` — a peça e seus L's.
- O diálogo separado `MultiLAddDialog` (SPEC-079) **continua existindo**, mas passa a ser usado só pelo fluxo "Adicionar Item não Cadastrado" (que não passa pelo `ProductSearchModal`).

## Validações

Implementadas em `validarEntries()` (novo, em `ProductSearchModal.tsx`), rodadas por peça selecionada antes de habilitar/aceitar o "Confirmar Seleção":

- Peça selecionada sem nenhum L → bloqueia.
- L com código vazio → bloqueia.
- L com quantidade ≤ 0 → bloqueia.
- Dois L's com o mesmo código **na mesma peça** → bloqueia.
- O mesmo L em peças **diferentes** → permitido (validação é por peça, não global).

O botão "Confirmar Seleção" fica desabilitado enquanto houver qualquer pendência; ao tentar confirmar mesmo assim (ex.: nenhuma peça marcada), mostra toast identificando a peça e o problema.

## Comportamento por fluxo

- **Adicionar peça nova** (`productSearchRowIndex === null`): cada `{product, entries}` vira N linhas independentes em `itens` — mesmo produto, mesmo preço, cada uma com seu `custom_id`/`quantidade` próprios (idêntico ao que a SPEC-079 já fazia, só que agora orquestrado para várias peças de uma vez).
- **Trocar produto de uma linha existente** (ícone de busca dentro de uma linha já criada, `productSearchRowIndex !== null`): continua 1:1 direto, sem passar pelo painel de L's — mantém o L/quantidade que já estavam naquela linha, só troca o produto. Não fazia parte do pedido e mudar isso adicionaria fricção a um ajuste pontual.
- **Tela de Edição de Itens na Aprovação Financeira** (`EditableBudgetItemsTable.tsx`, componente separado que também usa `ProductSearchModal`): só precisou de um ajuste de tipo pra continuar compilando — mantém o comportamento pré-existente de usar só a primeira peça selecionada (já ignorava peças extras antes; agora ignora os L's coletados também). Essa tela não fazia parte do pedido ("Buscar Produtos" e "Adicionar Item não Cadastrado" foram os 2 pontos citados) e tem um modelo de dados de itens diferente (`EditableOrcamentoData`) — estender L's múltiplos ali é um escopo maior, não solicitado.

## PDF e migração de dados

Nenhuma mudança — o PDF já imprime uma linha por L desde a SPEC-078/079 (arquitetura de linhas independentes), e como o modelo de dados não mudou, não há orçamento antigo pra migrar.

## Arquivos modificados

| Arquivo | Mudança |
| --- | --- |
| `src/components/budgets/ProductSearchModal.tsx` | Painel inline de L's por peça (reaproveita `LQuantityRepeater`), nova validação, `onConfirm` com assinatura rica (`ProductSelectionEntry[]`) |
| `src/pages/BudgetFormPage.tsx` | `handleProductSearchConfirm` reescrito pra consumir a nova assinatura e gerar N linhas por peça; removida a lógica da SPEC-079 que abria `MultiLAddDialog` pra seleção de 1 produto só (agora resolvido inline no próprio modal) |
| `src/components/budgets/EditableBudgetItemsTable.tsx` | Ajuste mínimo de tipo pra continuar compilando com a nova assinatura, sem mudança de comportamento |

## Verificação

- `npx tsc --noEmit` + `npx oxlint` + `npm run build` limpos.
- Sem migration de banco.
- Sem teste de UI ao vivo via browser — validação por build + leitura de código.
