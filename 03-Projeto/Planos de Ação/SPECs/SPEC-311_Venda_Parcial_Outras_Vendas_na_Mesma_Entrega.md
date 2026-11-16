---
titulo: "SPEC-311 — Venda Parcial: outras vendas na mesma entrega"
status: concluida
data_ultima_modificacao: 2026-11-16
sistemas_envolvidos:
  - Separação Parcial (separacao-parcial)
  - Logística (lucenera-logistics-b7cd1)
  - Banco (separacoes.outras_vendas)
---

# SPEC-311 — Venda Parcial: outras vendas na mesma entrega

## Checklist de Ação

- [x] Decisão do usuário (16/11): só vincular números; a parcial continua sendo de uma venda (sem juntar peças/reserva de várias vendas).
- [x] Migration 371 APLICADA em 16/11/2026.
- [x] Modal "Nova Separação" da Venda Parcial: campo "Outras vendas na mesma entrega" (várias, com Enter).
- [x] Grava em `separacoes.outras_vendas`; Logística (card, detalhes, impressão) mostra "Vendas: X, Y".
- [x] Publicados (separacao-parcial aa9ae12, logística 6a194dc) e CHANGELOG.
- [ ] Teste da Isa.

## Objetivo

A Isa precisava atrelar mais de um número de venda a uma só entrega (outra parcial do mesmo cliente no mesmo dia) para unificar e não confundir a Logística.

## Regra

`numero_venda` não muda (é o vínculo da parcial com o orçamento). `outras_vendas` é só texto informativo, vírgula entre números.

## Rollback

`supabase/db/migrations/20261116_371_spec311_separacao_outras_vendas_mesma_entrega/rollback.sql` (e reverter os commits dos sistemas).
