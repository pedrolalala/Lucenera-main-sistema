---
titulo: "SPEC-199 — Orçamento: quantidade com vírgula e destaque de peça por metro"
status: pendente
data_ultima_modificacao: 2026-10-14
sistemas_envolvidos:
  - Orçamentos Lucenera (gestao-financeira-clone-544cb)
---

# SPEC-199 — Orçamento: quantidade com vírgula e destaque de peça por metro

## Checklist de Ação

- [x] Formulário do orçamento: parar de arredondar a quantidade ao abrir um orçamento existente (`Math.floor` no carregamento).
- [x] Validação do formulário: quantidade aceita até 3 casas decimais, mínimo 0,001 (era inteiro ≥ 1).
- [x] Campo Qtd do item (BudgetItemCard e EditableItemCard): aceitar vírgula/ponto, até 3 casas.
- [x] Adicionar peça pela busca / vários L's (LQuantityRepeater): aceitar quantidade com vírgula.
- [x] Destaque "por metro" no item: campo Qtd em cor âmbar + selo "m" quando a peça for por metro.
- [x] Unidade da peça (`produtos.unidade`) carregada para os itens do formulário.

### Passos manuais do usuário

- [ ] Testar: importar XML com item de 4,5 m, abrir e salvar o orçamento — continua 4,5 e aparece destacado.
- [ ] Testar: adicionar peça por metro pela busca com quantidade 2,5.

## Objetivo

Peças vendidas por metro (fita LED, perfil, cabo) vêm com quantidade quebrada (ex.: 4,5 m). Hoje o import do XML
grava 4,5 certo, mas ao abrir o orçamento para editar a tela arredonda para 4 e salva assim; adicionar peça à mão só
aceita número inteiro. O orçamento deve aceitar a quantidade quebrada e mostrar claramente que a peça é por metro.

## Decisões aprovadas

- (14/10) Peça "por metro" = unidade `MT` no cadastro (vem da Connect) **ou** quantidade não inteira no item.
  Não usa o nome da peça (fitas "5 METROS" são vendidas por unidade).
- (14/10) Quantidade com vírgula liberada para **qualquer** peça (não só MT) — evita travar o import do XML.
- Destaque por cor (âmbar) no campo de quantidade + selo "m".

## Definição da SPEC

Estado atual (14/10): `orcamento_itens.quantidade` é `numeric(10,3)`; reserva/saldos de estoque são `numeric` — banco
já aceita fração, nenhuma migration. Na base: 50 peças `MT`; ~290 com "METRO" no nome cadastradas como `UN` na Connect
(continuam sem destaque, salvo quantidade quebrada — corrigir a unidade na Connect se quiser destaque sempre).

| Onde | Antes | Depois |
|---|---|---|
| `BudgetFormPage` carregar orçamento | `Math.max(1, Math.floor(q))` | mantém o valor (arredonda a 3 casas) |
| schema zod `itens.quantidade` | `.int().min(1)` | `.min(0.001)`, 3 casas |
| `BudgetItemCard` / `EditableItemCard` Qtd | `step=1`, `Math.floor` | `step=0.001`, 3 casas, aceita vírgula |
| `LQuantityRepeater` | `parseInt` | número com até 3 casas |

`produtos.unidade` já é legível por `authenticated` (conferido 14/10).

## Realizado

### 2026-10-14

- Orçamentos `0c8822d` (no ar em financeiro-lucenera.pages.dev, conferido no bundle): componente
  `QuantidadeInput` (aceita "4,5", até 3 casas, guarda o texto durante a digitação; âmbar + selo "m" se por metro),
  usado no item do formulário, na edição da Aprovação Financeira e na lista de L's. Carregar orçamento não arredonda
  mais; validação aceita fração. Unidade das peças buscada em `produtos(id, unidade)` para os itens do formulário.
  Regra em `src/lib/numeros.ts` (`ehPorMetro`). Sem migration.

## Pendências

- [ ] PDF do orçamento (Edge Function `generate-report`) mostra a quantidade com ponto ("4.5") e sem "m" — ajuste fica para depois (função tem duas cópias divergentes; publicar exige cuidado).
- [ ] Separação Parcial / Logística: conferir se aceitam quantidade quebrada ao separar peça por metro.
