---
titulo: "SPEC-013 — Complemento Absorvido pela SPEC-010"
status: absorvida pela SPEC-010
data_ultima_modificacao: 2026-07-06
sistemas_envolvidos:
  - Orçamentos
  - Cadastro
  - Supabase / Banco
---

# SPEC-013 — Complemento Absorvido pela SPEC-010

> Nota de origem: este documento era a SPEC-009 local escrita em 03/07/2026. Foi renumerado para SPEC-013 em 06/07/2026 para preservar a sequência `SPEC-009` a `SPEC-012` publicada no GitHub sem pular numeração.

## Decisão de consolidação

A reavaliação de 06/07/2026 concluiu que esta SPEC não deve criar tabela, migration, enum ou RPC próprios.

O conteúdo técnico útil foi absorvido pela [SPEC-010 — Saldos Operacionais de Estoque por Item de Projeto](SPEC-010_Saldos_Estoque_por_Item_de_Projeto.md):

- `projeto_item_id` é a chave operacional do estoque aprovado.
- Idempotência deve acontecer por `projeto_itens.id`.
- Cadastro/CRM devem ler a situação do item por views derivadas de `projeto_item_id`.
- Produto, projeto, orçamento e cliente não devem ser duplicados na tabela de saldo vivo; devem vir por `JOIN`.

## O que não fazer

- Não criar `estoque_reservas` como tabela concorrente.
- Não criar status paralelos de reserva fora da SPEC-010.
- Não usar cliente como chave operacional de saldo.
- Não duplicar `produto_id`, `projeto_id`, `orcamento_id` ou `cliente_id` na tabela de saldo vivo.

## Critério de aceite desta SPEC

Esta SPEC está concluída quando:

- [x] A SPEC-010 contém `projeto_item_id` como chave canônica.
- [x] A SPEC-010 absorve idempotência, backfill e leitura por Cadastro/CRM.
- [x] As SPECs 011/012/014/015 referenciam o contrato da SPEC-010, não um modelo separado desta SPEC.

## Realizado

### 2026-07-06

- SPEC-013 reduzida a registro histórico para eliminar inconsistência com a SPEC-010.
- O desenho implementável ficou concentrado na SPEC-010.

## Pendências

- Nenhuma pendência implementável nesta SPEC. Evoluções devem ser feitas diretamente na SPEC-010 ou nas SPECs dependentes.
