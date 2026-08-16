---
titulo: "SPEC-103 — Necessidade de Compra: unificar visão por L + mostrar empresa de origem"
status: concluído
data_ultima_modificacao: 2026-08-15
sistemas_envolvidos:
  - Compras (compras-lucenera-3o23t98ee, Skip 40326) — `NecessidadeCompra.tsx`, `NecessidadeDetailsPanel.tsx`
  - Supabase (banco central) — `vw_necessidade_compra`, `vw_necessidade_compra_pedido_detalhe`
dependencias:
  - SPEC-040 (aba "Por Item de Orçamento", Fluxo B)
  - SPEC-057 (empresa por pedido, já existe no cadastro do pedido — não na visualização de necessidade)
---

# SPEC-103 — Necessidade de Compra: unificar visão por L + mostrar empresa de origem

> Origem: reunião Vinícius 14/08/2026 ([79:04]-[85:25]).

## Objetivo

Duas mudanças na tela "Necessidade de Compra":

1. Poder comprar por "L" (item específico de orçamento) individualmente dentro da própria aba "Por Produto" — sem precisar entrar na aba separada "Por Item de Orçamento" (SPEC-040), que deixa de ser necessária como aba própria.
2. Mostrar de qual(is) empresa(s) veio a venda que gerou aquela necessidade — hoje a tela agrega tudo por produto, sem nenhuma quebra por empresa.

## Decisões aprovadas

Regra de negócio pra exceção de empresa ([78:25]-[78:43], citação literal):

> "E se esse material foi vendido... vou dar um exemplo: eu tenho 50 vendidos na Manuela e 1 vendido na Foco. Eu não vou comprar esse item pela Foco, vou acabar comprando tudo pela Manuela."

Ou seja: a regra não é "sempre comprar pela empresa que vendeu mais" de forma automática — é dar **visibilidade** da quebra por empresa pra quem monta o pedido decidir, sem forçar uma regra fixa. Confirmado também ([80:48]-[81:20]): deve ser possível juntar itens de empresas/clientes diferentes num mesmo pedido, com a exceção sendo possível (comprar pela empresa B algo vendido pela empresa A), não a regra.

Sobre o card de seleção por peça específica ([82:29]-[85:25]): pra produtos "sob medida" (ex.: Steca, citado como exemplo, vários L's/clientes diferentes pro mesmo produto), quer um "card de seleção" — mesmo padrão do card lateral que já existe hoje — pra escolher visualmente qual L/cliente está processando ao montar o pedido.

## Definição da SPEC

### Estado atual confirmado no código

- `NecessidadeCompraPorItemTab.tsx` já é keyed por `projeto_item_id` (granularidade de item de orçamento, inclui `l_fixo` — linha ~272) — ou seja, a capacidade técnica de "comprar por L individual" **já existe**, só está isolada numa aba separada em vez de estar dentro do fluxo principal "Por Produto".
- `vw_necessidade_compra` (a view que alimenta "Por Produto") é agregada só por `produto_id` — **nenhuma coluna de empresa** existe nela hoje. Confirmado por leitura completa da definição da view: não há JOIN com `orcamentos.empresa_id`/`empresas`.
- `necessidade-compra-detalhe.ts` (usado no painel lateral que já existe pra listar "de onde vem" a necessidade, por origem/projeto) **também não tem `empresa`** em nenhum campo — confirmado por busca no arquivo inteiro.

### Proposta (não implementar sem aprovação)

- Trazer a granularidade de "Por Item de Orçamento" (produto/marca/quantidade/L/empresa/cliente) pra dentro da aba "Por Produto", como uma expansão por linha (clicar no produto já mostra os L's que compõem aquela necessidade, cada um com sua empresa/cliente) — reaproveitando a query que já existe em `NecessidadeCompraPorItemTab.tsx`, sem duplicar lógica.
- Adicionar `empresa_id`/`empresa_nome` em `vw_necessidade_compra_pedido_detalhe` (ou view equivalente usada no detalhe), via JOIN com `orcamentos`.
- Remover a aba "Por Item de Orçamento" como opção separada, já que sua função passa a estar embutida em "Por Produto".
- Card de seleção por L: reaproveitar o padrão visual já usado noutro lugar do sistema (o próprio usuário comparou com um card lateral existente) — detalhamento de UI fica pra quando for implementar.

## Análise de ecossistema

- **Depende de**: `orcamentos` (`empresa_id`), `projeto_itens`, `produtos`.
- **Afeta**: só a tela "Necessidade de Compra". Precisa confirmar se a nova visualização por empresa não conflita com a lógica de agregação usada em "Fechar Pedido em Lote" (que hoje já aceita `empresa_id` opcional por pedido, SPEC-057).

## Realizado

### 2026-08-15

- **Parte 2 (mostrar empresa de origem): concluída**, com aprovação explícita do usuário pra separar do escopo da parte 1. Migration `20260815_114_spec103_empresa_origem_necessidade_compra` adiciona `empresa_id`/`empresa_nome` (via `orcamentos.empresa_id` → `empresas.nome`) à view `vw_necessidade_compra_detalhe`, aplicada no Supabase real. `NecessidadeCompraDetalhe.tsx` (linha inline expandida por produto) e `ModalRegistrarCompra.tsx` (lista "Itens de projeto que motivaram esta compra") atualizados pra exibir a coluna Empresa. Publicado Skip 40326 v0.0.63.
- Testado ao vivo (via `javascript_tool` pra contornar instabilidade do clique automatizado nesta tela específica — refs da árvore de acessibilidade ficavam dessincronizados do DOM real): produto 10289, expandido o detalhe por projeto — coluna "EMPRESA" mostra corretamente "FOCO ILUMINACAO" para as 4 linhas do orçamento ORC-0020/26.250.
### 2026-08-15 (parte 1)

- **Decisão do usuário**: o "card de seleção por L" segue o mesmo padrão visual do Card Lateral de Peça (SPEC-049) — painel lateral, mostrando a informação da peça, reaproveitado dentro da própria tela de Necessidade de Compra.
- A aba "Por Item de Orçamento" (SPEC-040) foi removida — não sobrou nenhuma aba (a tela virou visão única, já que "Por Produto" era a última restante depois da SPEC-104 remover "Devolução"). `NecessidadeCompraPorItemTab.tsx` foi apagado (funcionalidade absorvida, não duplicada).
- `NecessidadeDetailsPanel.tsx` (card lateral ao selecionar um produto em "Por Produto") passou a mostrar a lista de L's/orçamento/cliente/fornecedor/pendente daquele produto (nova função `getNecessidadeCompraItemPorProduto`, mesma view `vw_necessidade_compra_item_orcamento` que já alimentava a aba antiga, agora filtrada por produto em vez de busca livre), com checkbox por linha e botão "Gerar Compra (N)" — reaproveita o mesmo `ModalGerarCompraItemOrcamento.tsx` da aba antiga, nenhuma lógica de geração de pedido foi duplicada.
- **Achado que simplificou a implementação**: `fornecedor_id` é resolvido por produto/marca (mesma cascata de `vw_necessidade_compra`) — como o card lateral já é escopado a um único produto, todas as linhas sempre têm o mesmo fornecedor. A checagem de "fornecedor diferente" que existia na aba antiga (necessária lá porque misturava produtos diferentes) não se aplica aqui e foi removida.
- Cliente e "dias em aberto" (que só existiam na fonte antiga do painel, `vw_entrega_futura_projeto_item`) foram mantidos via merge client-side das duas queries por `projeto_item_id` — nenhuma view nova, nenhuma migration.
- Publicado Skip 40326 v0.0.66 — QA limpo (1ª tentativa quebrou o build por divs mal fechados após remover as abas; corrigido e republicado). Testado ao vivo: produto 10289 (Interlight) mostra 4 linhas (ORC-0020, L02/L05/L10/L11, cliente Terras Altas, fornecedor Interlight); selecionei 2, "Gerar Compra (2)" abriu o modal com as linhas certas e custo pré-preenchido (R$ 275,12); cancelado sem confirmar (não criei pedido real).

### 2026-08-16 — revisão: card lateral confundia, virou modal

- **Feedback direto do usuário ao testar ao vivo**: o card lateral (~320px de largura) era apertado demais pra escolher entre vários L's/clientes — "só ali na lateral vai confundir".
- Fix: extraída a lista de seleção pra um componente novo, `SelecionarLParaCompraModal.tsx` — modal de verdade, mesmo padrão visual do "Buscar Venda de Origem" da Devolução (`DevolucaoItemSearchModal.tsx`), com mais espaço pra Orçamento/L/Cliente/Fornecedor lado a lado numa tabela. `NecessidadeDetailsPanel.tsx` (o card lateral em si) ficou simples: resumo do produto + botão "Selecionar L's pra comprar" que abre o modal. Fluxo de geração de pedido (`ModalGerarCompraItemOrcamento.tsx`) não mudou, só quem abre ele.
- Publicado Skip 40326 v0.0.67. Testado ao vivo de novo com o mesmo produto 10289: modal abriu com as 4 linhas em tabela espaçosa, selecionei 2 (L02/L05), "Gerar Compra (2)" abriu o modal de pedido com os dados certos; cancelado sem confirmar.

## Pendências

Nenhuma.
