---
titulo: "SPEC-113 — Mostrar setor de estoque ao selecionar produto dentro do orçamento"
status: concluído
data_ultima_modificacao: 2026-08-15
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb, Skip 32554) — `ProductSearchModal.tsx`
dependencias: []
---

# SPEC-113 — Mostrar setor de estoque ao selecionar produto dentro do orçamento

> Origem: reunião Vinícius 14/08/2026 ([32:45]-[33:54]).

## Objetivo

Ao selecionar um produto dentro do orçamento (`ProductSearchModal.tsx`), mostrar o **setor** onde a peça está fisicamente estocada — pedido pendente de uma reunião anterior, ainda não implementado. Citação: *"Pôr os setores na hora que vai selecionar o produto lá dentro do orçamento."* Resposta do Filipe: *"Eu vou ter que mudar um pouco da visualização ali do orçamento, de como fica a peça. Mas dá pra colocar sim. Vou colocar no canto inferior direito."*

## Estado atual confirmado no código

- Existe a view `vw_produtos_estoque_por_local`, que já expõe `setor: estoque_local` (enum) junto com `codigo_produto`, `nome`, `sku`, `quantidade`, `quantidade_reservada`, `preco_venda` — ou seja, o dado já existe pronto pra consulta, view por view de produto+local.
- `ProductSearchModal.tsx` (a tela de busca/seleção de produto dentro do orçamento) **não referencia** essa view nem o campo `setor` em nenhum lugar — confirmado via busca no arquivo inteiro, zero ocorrências.
- Isso é coerente com a fala do usuário: é um pedido antigo (de reunião anterior) que nunca chegou a ser implementado.

## Proposta (não implementar sem aprovação)

1. Trocar (ou complementar) a fonte de dados do `ProductSearchModal.tsx` pra incluir `setor` — usando `vw_produtos_estoque_por_local` no lugar da view/tabela atual, ou fazendo um join adicional, a decidir conforme o que a modal já consulta hoje (não confirmado nesta investigação qual é a fonte atual exata — precisa reler o restante do arquivo, essa investigação só confirmou a ausência do campo).
2. Exibir o `setor` no canto inferior direito do card/linha de cada produto na lista de resultados, conforme já combinado na reunião.
3. Se um produto existir em mais de um setor (múltiplas linhas em `vw_produtos_estoque_por_local` pro mesmo `codigo_produto`), definir critério de exibição (todos os setores? só o de maior quantidade disponível?) — pendência.

## Análise de ecossistema

- **Depende de**: `vw_produtos_estoque_por_local`, enum `estoque_local`.
- **Afeta**: só a modal de busca de produto no orçamento. Puramente informativo, não muda regra de negócio nem cálculo.

## Realizado

### 2026-08-15

- **P-1 resolvida**: a fonte de dados mudou desde a investigação original da SPEC (SPEC-100, mesmo dia, trocou pra RPC `buscar_produtos_fuzzy`). Em vez de `vw_produtos_estoque_por_local` (que a SPEC cogitou), usada direto `estoque_itens` (produto_id, local, quantidade, quantidade_reservada) — a mesma tabela que já alimenta o `StockPopover` existente (hover "Distribuição por Local"), só buscada em lote pra todos os produtos da página de uma vez, em vez de um-a-um sob demanda.
- **P-2 resolvida**: confirmado que só existem 2 valores possíveis de `local` no banco (`Estoque`, `Showroom`) — critério simples: mostra os setores com saldo disponível (`quantidade - quantidade_reservada > 0`), juntos com " + " se o produto tiver saldo nos dois; "-" se não tiver saldo disponível em nenhum.
- Nova coluna "Setor" na tabela de busca de produto, ordenável como as demais.
- Publicado Skip 32554 v0.0.341 — QA limpo. Testado ao vivo: produtos Interlight com estoque real mostram "Estoque" na coluna nova; produtos sem saldo mostram "-".

## Pendências

Nenhuma.
