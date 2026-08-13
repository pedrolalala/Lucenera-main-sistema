---
titulo: "SPEC-093 — Layout de impressão da lista de entrega"
status: concluído
data_ultima_modificacao: 2026-08-13
sistemas_envolvidos:
  - Logística
dependencias:
  - 03-Projeto/Planos de Ação/SPECs/SPEC-086_Analise_Reunioes_Vinicius_11_08_2026.md (item 2.5)
  - 03-Projeto/Planos de Ação/SPECs/SPEC-091_PDF_Automatico_Ao_Separar.md
---

# SPEC-093 — Layout de impressão da lista de entrega

> Origem: reunião com Vinícius, 11/08/2026 (`02-Reunioes/17. Lucenera
> (vinicius) - 11.08.2026_ estruturas falhas do sistema/Reunião.01`,
> [10:38]-[10:47]). Catalogado como item 2.5 na SPEC-086.

## Checklist de Ação

- [ ] Confirmar com o usuário quais telas de Logística precisam desse
      layout (ver "Decisões pendentes")
- [ ] Definir conteúdo/campos da lista impressa
- [ ] Implementar (CSS `@media print` client-side, ou PDF via Edge Function
      — mesma decisão técnica da SPEC-091)

### Passos manuais do usuário

- [ ] Aprovar conteúdo/layout antes de implementar

## Objetivo

Pedido curto e direto na reunião: "Friar o layout, né? O layout da lista de
entrega pra poder imprimir?" — hoje não existe nenhum código de impressão em
`lucenera-logistics-b7cd1` (confirmado por busca no checkout local: zero
ocorrências de `print`/`impress`/`window.print` em todo o `src/`).

## Decisões pendentes

- Este item é sobre a mesma lista da SPEC-091 (documento gerado ao separar),
  ou uma tela diferente — a lista de entregas do dia/rota que o Matheus usa
  em campo (`PendentesPage`, `RouteOptimizerPage`)? A reunião fala dos dois
  contextos em momentos próximos (separação e depois rota de entrega), sem
  deixar claro se é o mesmo documento ou dois diferentes.
- Se for a lista de rota do dia: agrupar por rota/entregador, ou por
  cliente/venda?

## Definição da SPEC

Depende da decisão acima. Se confirmado que é o mesmo documento da SPEC-091,
esta SPEC pode ser absorvida por ela (adicionar layout de impressão no lugar
de gerar PDF, ou os dois); se for a lista de rota, é uma tela nova separada
em Logística.

## Decisão final (implementação, 2026-08-13)

Confirmado como o mesmo documento da SPEC-091 — absorvida por ela. A lista
de rota do dia (`PendentesPage`/`RouteOptimizerPage` em Logística) não foi
tocada nesta rodada; fica como possível item futuro se o usuário pedir
especificamente impressão da rota, separado da lista de separação.

## Realizado

### 2026-08-13

Implementado junto com a SPEC-091 (`imprimirListaSeparacao()` em
`SeparacaoParcialPage.tsx`) — ver detalhes lá. Publicado Skip 48801, v0.0.20.

## Pendências

Nenhuma.
