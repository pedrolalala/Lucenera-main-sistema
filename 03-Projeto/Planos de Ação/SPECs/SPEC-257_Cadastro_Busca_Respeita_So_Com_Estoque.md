---
titulo: "SPEC-257 — Cadastro (Peças e Produtos): a busca respeita o filtro \"Só com estoque\""
status: pendente
data_ultima_modificacao: 2026-11-06
sistemas_envolvidos:
  - Cadastro (04-Sistemas/cadastro-lucenera-b86fe) — tela Peças e Produtos
---

# SPEC-257 — A busca respeita o "Só com estoque"

> Pedido do usuário (06/11/2026), com a imagem da tela Peças e Produtos (busca "arandela", botão "Só com estoque" ligado e o aviso "na busca aparecem também as peças sem estoque"): **"a busca tem que respeitar o 'Só com estoque'"**.

## Checklist de Ação

- [x] A. Com "Só com estoque" ligado, a busca por texto passa a mostrar **só as peças com estoque** (antes ignorava o filtro).
- [x] B. Tirar o aviso "(na busca aparecem também as peças sem estoque)", que deixa de ser verdade.
- [x] C. Se a busca não achar nada com estoque, a tela explica e oferece **"Mostrar também as sem estoque"** (desliga o filtro), para a peça não "sumir" sem explicação.
- [x] D. Cadastro publicado (06/11, deploy 7b75d58f; commit 75ac9bf pushado).

### Passos manuais do usuário

- [ ] Avisar o Filippo: a decisão dele de 30/10 ("quando eu busco tem que aparecer") foi **invertida** a pedido do usuário; o botão da tela cobre o caso de querer ver as sem estoque.
- [ ] Testar na tela: buscar uma peça sem estoque com o filtro ligado (deve aparecer o aviso e o botão) e com o filtro desligado (aparece normal).

## Objetivo

Com "Só com estoque" ligado, quem busca uma peça espera ver só o que tem estoque. A regra anterior (SPEC-193 C1, a pedido do Filippo) mostrava também as sem estoque quando havia texto de busca, o que confundia: o botão ligado e a lista com peças sem saldo.

## Decisões aprovadas (06/11/2026)

- A busca **respeita** o "Só com estoque" (opção 1 escolhida pelo usuário, entre "respeitar" e "só deixar o aviso mais claro").
- Para não esconder peça sem explicação, o estado vazio da busca diz que há o filtro ligado e oferece desligá-lo.

## Definição da SPEC

- `src/pages/Pecas.tsx`: `filtroEstoqueAtivo = soComEstoque` (antes `soComEstoque && !buscando`). O filtro continua no lado da tela sobre `tem_saldo` (a consulta por busca já traz esse campo); a consulta em lotes sem busca continua filtrando no banco (`soComSaldo`).
- Rodapé da lista: "N de M registros com estoque" sempre que o filtro está ligado; o aviso antigo sai.
- Estado vazio com filtro ligado e busca: "Nenhuma peça com estoque para essa busca. Desligue 'Só com estoque' para ver as peças sem estoque." + botão "Mostrar também as sem estoque".
- Sem mudança de banco, serviço nem outros sistemas (o Orçamento usa a busca por outra rota).

## Critérios de aceite

- Filtro ligado + busca "arandela": só aparecem peças com estoque; o rodapé diz "com estoque".
- Filtro ligado + busca de peça sem estoque: lista vazia com o aviso e o botão; ao clicar, a peça aparece.
- Filtro desligado: tudo igual a antes.

## Realizado

### 2026-11-06

- Código alterado em `Pecas.tsx` (A, B e C). `tsc`: 16 erros antes e depois (dívida antiga; checagem numa cópia do tsconfig sem o padrão inválido); `vite build` conferido só com São Paulo (ver CHANGELOG).

## Pendências

- [ ] Avisar o Filippo da mudança de regra.
