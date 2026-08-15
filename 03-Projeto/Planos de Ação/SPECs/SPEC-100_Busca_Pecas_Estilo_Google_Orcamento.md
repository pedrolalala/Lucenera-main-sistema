---
titulo: "SPEC-100 — Busca de peças estilo Google no orçamento (marca, descrição, código, SKU)"
status: concluído
data_ultima_modificacao: 2026-08-15
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb, Skip 32554) — `ProductSearchModal.tsx`
dependencias:
  - SPEC-094 (adicionou filtro de fornecedor à busca — mesma área de código)
  - SPEC-080 (múltiplos L's dentro do Buscar Produtos)
---

# SPEC-100 — Busca de peças estilo Google no orçamento

> Origem: reunião Vinícius 14/08/2026 ([13:52]-[14:18]) — "Aqui você conseguiu mudar a busca? ... A busca eu não mexi ... Aqui pra poder digitar interlight, poder digitar tudo." Ponto destacado pelo usuário como prioridade antes mesmo de eu ler a reunião inteira.

## Objetivo

A busca de peças ao montar um orçamento (`ProductSearchModal.tsx`) deve funcionar como o Google: o usuário digita qualquer termo (marca, descrição, código, SKU) num único campo e o sistema busca em todos os campos relevantes ao mesmo tempo — sem precisar saber de antemão em qual campo a informação está.

## Definição da SPEC

### Estado atual confirmado no código

`04-Sistemas/gestao-financeira-clone-544cb (1)/src/components/budgets/ProductSearchModal.tsx`:

- O campo de texto livre (`placeholder="Buscar por nome, SKU ou referência..."`, linha 598) já busca em **nome, sku, referência e código** (linhas 283-286):
  ```js
  prodQuery = prodQuery.or(
    `nome.ilike.%${t}%,sku.ilike.%${t}%,referencia.ilike.%${t}%,codigo_produto.eq.${numericTerm}`,
  )
  ```
- **Marca não entra nessa busca** — hoje é um `<Select>` separado (`brandFilter`, linha 299: `prodQuery.eq('marca_id', brandFilter)`), não texto livre. É exatamente por isso que digitar "interlight" na caixa de busca não encontra nada: o termo nunca é comparado contra o nome da marca.
- Comentário já existente no código (linha 199-200, da SPEC-094) confirma o histórico: "filtro de fornecedor — o único que faltava na busca (marca, categoria e nome/SKU/referência já existiam)" — ou seja, **marca e categoria são filtros à parte desde sempre**, nunca foram integrados ao texto livre.
- Causa técnica: `marca_nome` vem de um JOIN (`marca:marcas(nome)`, linha 267) — o PostgREST `.or()` usado hoje só filtra colunas da própria tabela `produtos`, não alcança colunas de tabela relacionada.

### Proposta (não implementar sem aprovação)

Duas opções técnicas, mesma experiência final pro usuário:

- **Opção A — resolver marca(s) que casam com o termo antes da query principal**: buscar em `marcas` por nome parecido com o termo digitado, pegar os `marca_id` que baterem, e incluir `marca_id.in.(...)` no mesmo `.or()` já existente. Simples, reaproveita a estrutura atual, sem criar função nova no banco.
- **Opção B — RPC de busca fuzzy única**, no mesmo padrão de `buscar_fornecedores_fuzzy` (já existe em Compras, usa `pg_trgm`+`unaccent`, SPEC-030): criar uma RPC `buscar_produtos_fuzzy(p_termo)` que já faz o JOIN com marcas/categorias internamente e retorna tudo ordenado por similaridade. Mais robusto (tolera erro de digitação, ordena por relevância), mas é escopo maior — cria função nova no banco.

Recomendação técnica (não decide sozinho): Opção A resolve o pedido específico do Vinícius rápido; Opção B é o "de verdade estilo Google" (tolerante a erro de digitação, como já existe em Compras) — vale perguntar se ele quer só destravar marca na busca ou já upar pra fuzzy search de verdade.

## Análise de ecossistema

- **Depende de**: `produtos`, `marcas`, `categorias_produto` — mesmas tabelas já usadas pela busca atual, sem tabela nova.
- **Afeta**: só `ProductSearchModal.tsx` (usado ao montar orçamento). Não mexe em Necessidade de Compra nem em outros sistemas.
- **Padrão já usado no ecossistema**: `buscar_fornecedores_fuzzy` (Compras, SPEC-030) é o precedente direto pra Opção B.

## Realizado

### 2026-08-15

- Confirmado com o usuário: Opção B (RPC fuzzy completa) + categoria incluída na busca livre (resolve P-1 e P-2).
- Migration `supabase/db/migrations/20260815_113_spec100_busca_produtos_fuzzy/001_rpc_buscar_produtos_fuzzy.sql` — RPC `buscar_produtos_fuzzy(p_termo, p_marca_id, p_categoria_id, p_produto_ids, p_offset, p_limit)`, aplicada no Supabase real. Testada via psql: termo "interlight" e "interligth" (com erro de digitação) retornam produtos da marca Interlight; sem termo, mantém paginação normal.
- `ProductSearchModal.tsx` trocado para chamar a RPC via `supabase.rpc('buscar_produtos_fuzzy', ...)` em vez do `.or()` direto em `produtos` — mantém os filtros `<Select>` de marca/categoria e o filtro de fornecedor (resolvido client-side) como parâmetros da RPC. `revenda_ubiqua` não foi alterado (fora do escopo da SPEC).
- Publicado no Skip (Orçamentos, projectId 32554) — QA pipeline (setup/static/build/test) passou limpo, v0.0.337, publicado em produção.
- Testado ao vivo no navegador: abri um orçamento em rascunho, digitei "interlight" no campo de busca — antes da SPEC não retornava nada (marca não entrava na busca), agora retorna corretamente as peças da marca Interlight.

## Pendências

Nenhuma.
