---
titulo: "SPEC-208 — Cadastro: cabeçalho da lista de peças fixo ao rolar"
status: pendente
data_ultima_modificacao: 2026-10-19
sistemas_envolvidos:
  - Cadastro
---

# SPEC-208 — Cadastro: cabeçalho da lista de peças fixo ao rolar

## Checklist de Ação

- [x] `ui/table.tsx`: `Table` aceita `containerClassName` para trocar o `overflow-auto` do invólucro
- [x] `Pecas.tsx`: invólucro com `overflow-visible` e cada coluna do cabeçalho `sticky top-0` com fundo e linhas pretas (sombra)
- [x] Publicar (Cloudflare `cadastro-lucenera.pages.dev`)

### Passos manuais do usuário

- [ ] Rolar a lista de peças e conferir que o cabeçalho fica parado, como "congelar painéis" no Excel

## Objetivo

Na consulta de produtos (Cadastro › Peças e Produtos), o cabeçalho com Código, Referência, Descrição, Marca, Categoria,
Preço Venda, Estoque Total e Disponível sumia ao rolar a lista. Ele precisa ficar fixo no topo.

## Decisões aprovadas

- Pedido do usuário em 19/10/2026: "esse cabeçalho tem que manter ele fixo conforme rola a lista de produtos, tipo congelar no excel".

## Definição da SPEC

- Causa: o cabeçalho já tinha `sticky top-0`, mas o componente `Table` (shadcn) põe a tabela numa div com `overflow-auto`.
  O sticky gruda nessa div, que não rola, e não na div de fora que rola a lista.
- Com `border-collapse`, a borda não acompanha a célula fixa, então as linhas pretas do cabeçalho são desenhadas com `box-shadow` inset.

## Realizado

### 2026-10-19

- Implementado; `vite build` ok.

## Pendências

- [ ] Conferência do usuário no Cadastro rolando a lista de peças.
