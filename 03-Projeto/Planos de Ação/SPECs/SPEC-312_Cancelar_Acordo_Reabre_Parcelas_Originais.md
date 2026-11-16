---
titulo: "SPEC-312 — Cancelar acordo reabre as parcelas originais"
status: concluído
data_ultima_modificacao: 2026-11-16
sistemas_envolvidos:
  - Retorno Bancario (Contas a Pagar / Contas a Receber)
  - Supabase (financeiro)
---

# SPEC-312 — Cancelar acordo reabre as parcelas originais

## Checklist de Ação

- [x] Diagnosticar o caso da Carol (ORC-0042 −123,23 + VENDA-8522 369,23 = 246,00, venc. 11/11/2026, acordo 3)
- [x] Corrigir o dado: ACORDO-3 reativado (título sem cancelamento, parcela `firme` R$ 246,00)
- [x] Migration 372: gatilho `trg_financeiro_acordo_cancelado` (ensaiada em ROLLBACK e aplicada; rollback.sql pronto)
- [x] Reuniao 60 (16/11): originais do acordo ficam como Pago, valor pago 0, data = data do acordo; diferenca na conta ACORDO-n; acordos antigos corrigidos (migration 374, so a view `vw_financeiro_duplicatas`, aplicada)
- [x] Tela: Estornar em conta de acordo avisa para cancelar a ACORDO-n (codigo local, ainda sem commit/deploy)
- [x] CHANGELOG

### Passos manuais do usuário

- [x] Carol conferiu as 3 linhas (ORC-0042, VENDA-8522 pagas 0 em 13/11 + ACORDO-3 R$ 246,00 em aberto) em 16/11

## Objetivo

Cancelar o título/parcela de um acordo deixava as parcelas originais "renegociadas" para sempre (sem saldo, fora da lista, fora de um novo acordo: "Só parcela firme entra em acordo"). Agora, ao cancelar a última parcela aberta de um acordo, as originais voltam a `firme` e as baixas do acordo (renegociação/abatimento) são estornadas (a baixa é imutável: o histórico fica).

## Decisões aprovadas

- Regra do acordo não muda: originais ficam baixadas (`renegociacao`) e nasce o título ACORDO-n com o valor restante.
- A lista já recarrega após "Confirmar acordo" (`onSuccess → fetchData`); sem mudança de tela.
- Reunião 60 (decisão do usuário 16/11): parcela negativa entra no acordo e fica Paga com 0; a diferença vira conta nova ACORDO-n; acordo zero a zero segue como está (sem título novo), só que as duas originais aparecem como Pagas 0 na data do acordo; acordos existentes (2, 3, 4) corrigidos.
- Acordo de compensação (total zero, sem parcela nova) não é desfeito por este gatilho.

## Rollback

`supabase/db/migrations/20261116_372_spec312_cancelar_acordo_reabre_originais/rollback.sql` (remove o gatilho).
