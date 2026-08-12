# SPEC-079: Múltiplos Ls por peça no orçamento + remoção do botão "Adicionar Item"

**Data:** 2026-08-12
**Sistema:** Orçamentos (`gestao-financeira-clone-544cb`, Skip projectId `32554`)
**Status:** Investigação concluída, implementação em andamento — **Skip MCP ainda desconectado** (mesma situação da SPEC-078): editar local → verificar local → publicar quando o Skip reconectar.

## Contexto

Tarefa formal do usuário pedindo suporte a múltiplos códigos "L" (identificador de luminária/circuito no projeto) por peça, com quantidade própria por L, e a remoção do botão redundante "Adicionar Item". Traz 5 perguntas obrigatórias antes de implementar.

## Respostas às perguntas obrigatórias

**1. Códigos de L são livres ou vêm de lista pré-definida?**
Livres (texto), formatados automaticamente pro padrão `L{NN}` por `formatCircuitId()` (`src/lib/utils.ts`) — aceita `"1"`, `"l1"`, `"L1"` etc. e normaliza pra `"L01"`. Não existe lista/tabela de Ls pré-cadastrados.

**2. A quantidade total da peça é a soma dos Ls, ou cada L é item independente no cálculo?**
**Achado decisivo, confirmado direto no schema do banco**: cada L **já é, e precisa continuar sendo**, um item independente. `projeto_itens` (criado a partir de `orcamento_itens` na aprovação financeira) tem as colunas `orcamento_item_id` (FK pra uma linha específica de `orcamento_itens`) e `l_fixo` (o código do L, gravado por linha) — ou seja, todo o pipeline de estoque/logística (`estoque_saldos_projeto_item`, reserva de `estoque_itens.quantidade_reservada`, "Necessidade de Compra por Item de Orçamento", entrega futura) já rastreia e reserva estoque **por linha/por L**, não por peça agregada. O sistema já tem inclusive um campo `sub_ordem` pra ordenar múltiplas linhas que compartilham o mesmo L. Migrar pra uma estrutura aninhada (1 peça com array de Ls) quebraria ou exigiria reescrever esse pipeline inteiro — fora do escopo pedido e desnecessário, já que o modelo atual (linhas independentes) já resolve o problema. **Decisão (confirmada com o usuário): manter linhas independentes, sem mudança de schema** — "múltiplos Ls por peça" na prática significa "várias linhas com o mesmo `produto_id`, cada uma com seu `custom_id` (L) e `quantidade` próprios", só que agora adicionadas de forma guiada em um único fluxo em vez de manualmente uma a uma.

**3. Preço unitário é igual entre Ls da mesma peça, ou pode variar?**
Ao adicionar, todas as linhas geradas para a mesma peça herdam o mesmo preço inicial (do catálogo, ou digitado uma vez no caso de item manual) — mas cada linha continua editável individualmente depois, exatamente como qualquer item hoje. Nada muda aqui: já era assim para itens de peças diferentes, continua sendo para múltiplas linhas da mesma peça.

**4. PDF: linhas separadas ou concatenadas?**
Confirmado com o usuário: **uma linha por L** — natural com a decisão da pergunta 2 (linhas independentes), não exige nenhuma mudança no template do PDF (`generate-report/index.ts` já imprime uma linha por item de `orcamento_itens`).

**5. "Buscar Produtos" já cobre o que "Adicionar Item" fazia?**
Investigação direta do código: `"Adicionar Item"` e `"Adicionar Item não Cadastrado"` são **o mesmo `onClick`, literalmente o mesmo objeto passado pra `append()`** (`custom_id: '', produto_id: '', descricao: '', quantidade: 1, preco_unitario: 0, desconto: 0`) — 100% redundantes, confirmado por leitura de código, não só pela palavra do usuário. `"Buscar Produtos"` é um terceiro fluxo, distinto (abre modal de busca no catálogo) — não é substituto de nenhum dos dois, continua existindo sem alteração.

## Decisão de arquitetura (confirmada com o usuário)

- **Sem migration, sem tabela nova, sem RPC nova.** `replace_orcamento_itens`, `aprovar_orcamento_financeiro` e o PDF continuam operando sobre a lista flat de `orcamento_itens`, sem saber que várias linhas "pertencem" à mesma peça — exatamente como já operam hoje.
- Tabela de itens na tela de edição: **lista normal, uma linha por L** (sem agrupamento visual/colapsável) — confirmado com o usuário, menor esforço de UI.
- Novo componente `LQuantityRepeater` (lista repetível de `{custom_id, quantidade}`, com adicionar/remover linha e soma em tempo real) usado dentro de um novo modal `MultiLAddDialog`, acionado em 2 pontos:
  - **"Buscar Produtos"**, quando exatamente 1 produto é selecionado pra adicionar (não pra trocar o produto de uma linha existente — esse fluxo de troca pontual continua 1:1, sem o repetidor). Seleção de vários produtos diferentes ao mesmo tempo continua como hoje (1 linha cada, sem repetidor) — pedir a quebra de Ls pra N produtos diferentes de uma vez não fazia parte do pedido nem do exemplo do usuário (que era sobre 1 peça só).
  - **"Adicionar Item não Cadastrado"** (a que sobra depois da remoção de "Adicionar Item") — mesmo repetidor, mas com campos de Descrição e Preço Unitário editáveis uma vez (em vez de vir do catálogo), aplicados a todas as linhas geradas.
- Validação: nenhum L pode ficar com código vazio ou quantidade ≤ 0 ao confirmar (linhas inválidas são descartadas silenciosamente, com aviso se nenhuma sobrar).

## Mudança 2 — Remover "Adicionar Item"

- Removidos os 2 botões `"Adicionar Item"` (`variant="outline"`/`"secondary"`, redundantes, código idêntico ao de "Adicionar Item não Cadastrado") — um no header da seção de itens (linha ~2141), outro no estado vazio (linha ~2214).
- Nenhum código morto adicional encontrado ligado especificamente a esse botão (era só o `onClick` inline, sem função/rota dedicada).
- Nenhuma referência em seeds/testes/i18n ao texto "Adicionar Item" (busca não encontrou nada fora do próprio `BudgetFormPage.tsx`).

## Arquivos a criar/modificar

| Arquivo | Descrição |
| --- | --- |
| `src/components/budgets/LQuantityRepeater.tsx` (novo) | Lista repetível de `{custom_id, quantidade}` — inputs, adicionar/remover linha, soma em tempo real. |
| `src/components/budgets/MultiLAddDialog.tsx` (novo) | Modal que embrulha o `LQuantityRepeater`; modo "produto cadastrado" (nome/preço fixos, vindos do catálogo) ou "item manual" (descrição/preço editáveis uma vez). |
| `src/pages/BudgetFormPage.tsx` | Remove os 2 botões "Adicionar Item"; troca o clique de "Adicionar Item não Cadastrado" e a confirmação de "Buscar Produtos" (caso de 1 produto só) pra abrir o `MultiLAddDialog` em vez de criar 1 linha direto. |

## Verificação planejada

1. `npx tsc --noEmit` + `npx oxlint` + `npm run build`, local, antes de publicar.
2. Sem migration de banco (confirmado — nada muda no schema).
3. Skip desconectado — publicação/commit ficam pendentes até reconexão, seguindo o mesmo protocolo da SPEC-078.
4. Sem teste de UI ao vivo via browser — validação por build + leitura de código.
