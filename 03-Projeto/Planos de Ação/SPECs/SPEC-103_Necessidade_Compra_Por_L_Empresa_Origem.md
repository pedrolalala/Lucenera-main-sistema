---
titulo: "SPEC-103 — Necessidade de Compra: unificar visão por L + mostrar empresa de origem"
status: pendente
data_ultima_modificacao: 2026-08-15
sistemas_envolvidos:
  - Compras (compras-lucenera-3o23t98ee, Skip 40326) — `NecessidadeCompra.tsx`, `NecessidadeCompraPorItemTab.tsx`
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
- **Parte 1 (fundir aba "Por Item de Orçamento" em "Por Produto", remover aba separada): não implementada** — layout não definido, fica pendente pra quando o usuário quiser detalhar o UX.

## Pendências

- [ ] **Parte 1**: confirmar layout exato da fusão das duas abas (expandir linha vs. nova coluna) antes de implementar — decisão de UX explicitamente adiada pelo usuário nesta rodada.
- [ ] Confirmar se "card de seleção por peça" (citado na reunião pra produtos sob medida) é uma tela nova ou um componente dentro do painel lateral que já existe — também faz parte do escopo adiado da parte 1.
