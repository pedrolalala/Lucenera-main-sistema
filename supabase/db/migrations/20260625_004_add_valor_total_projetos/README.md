# Migration group 20260625_004 — Adicionar `projetos.valor_total`

## Decisão

`projetos.valor_total` volta a existir como valor denormalizado do projeto.

A coluna é necessária porque `public.projeto_itens.trg_sync_valor_total` dispara `public.sync_projeto_valor_total()`, que soma `projeto_itens.subtotal` e grava o total em `projetos.valor_total`.

## Alteração

- Adiciona `public.projetos.valor_total numeric(15,2)`.
- Define `DEFAULT 0` e `NOT NULL`.
- Preenche projetos existentes com `0` quando estiverem nulos.
- Recalcula o valor dos projetos que já possuem itens em `public.projeto_itens`.
- Documenta a coluna com comentário SQL.

## Observação

Essa coluna mantém compatibilidade com a automação de itens do projeto. No fluxo novo de Administração Bancária, boletos e notas fiscais continuam rastreados por `orcamento_id`.
