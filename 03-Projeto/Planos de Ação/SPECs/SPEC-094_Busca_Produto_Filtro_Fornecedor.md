---
titulo: "SPEC-094 — Adicionar fornecedor como filtro na busca de produto"
status: concluído
data_ultima_modificacao: 2026-08-13
sistemas_envolvidos:
  - Orçamentos
dependencias:
  - 03-Projeto/Planos de Ação/SPECs/SPEC-086_Analise_Reunioes_Vinicius_11_08_2026.md (item 2.8, corrigido em 2026-08-13)
---

# SPEC-094 — Adicionar fornecedor como filtro na busca de produto

> Origem: reunião com Vinícius, 11/08/2026 (`02-Reunioes/17. Lucenera
> (vinicius) - 11.08.2026_ estruturas falhas do sistema/Reunião.03`,
> [46:23]-[48:48]). Escopo reduzido em relação ao item 2.8 original da
> SPEC-086 — ver correção de 2026-08-13 nela.

## Checklist de Ação

- [ ] `ProductSearchModal.tsx`: adicionar dropdown "Fornecedor" ao lado dos
      já existentes de Marca/Categoria
- [ ] Query: `produto_fornecedores WHERE fornecedor_id = ...` pra filtrar
      `produtos.id IN (...)`, seguindo o mesmo padrão dos filtros de marca
      e categoria já implementados

### Passos manuais do usuário

- [ ] Nenhum — mudança só de frontend/query, sem migration

## Objetivo

Na reunião, o Vinícius pediu que a busca de produto funcionasse "tipo
pesquisa do Google", cobrindo nome, SKU, marca, fornecedor e categoria ao
mesmo tempo. Investigação em 2026-08-13 confirmou que `ProductSearchModal.tsx`
(Orçamentos) já cobre nome/SKU/referência/código (busca livre) e marca/
categoria (filtros dedicados) — só **fornecedor** ficou de fora, apesar de a
relação produto↔fornecedor já existir no banco (`produto_fornecedores`,
N:N, com `fornecedor_id` apontando pra `contatos`).

## Definição da SPEC

Mesmo padrão dos filtros de marca/categoria já existentes no componente
(dropdown populado via `SearchableSelect`/`Select`, aplicado como
`.in('id', produtoIdsDoFornecedor)` na query de produtos, usando
`produto_fornecedores` como tabela ponte).

## Realizado

### 2026-08-13

- `ProductSearchModal.tsx`: dropdown "Fornecedor" (lista de
  `contatos WHERE tipo='fornecedor'`) ao lado de Marca/Categoria; filtra
  produtos via `produto_fornecedores`. `revenda_ubiqua` (sem conceito de
  fornecedor) some da lista quando o filtro está ativo, pra não misturar
  resultado fora do filtro.
- Publicado Skip 32554, v0.0.327, QA limpo.

## Pendências

Nenhuma.
