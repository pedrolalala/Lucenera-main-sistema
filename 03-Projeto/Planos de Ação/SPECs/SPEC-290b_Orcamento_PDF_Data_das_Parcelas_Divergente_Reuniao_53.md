# SPEC-290b — Orçamento: PDF exportado mostra data de parcela diferente da escolhida (Reunião 53, Helena, 12/11/2026)

## Problema
Helena salvou o ORC-0052 com início do pagamento em 20/11 (boleto sempre dia 20). O PDF saiu com 28/11 em todas as vias (cliente, interna, etc.).

## Causa (verificada no banco)
- `orcamentos.data_inicio_pagamento` = 2026-11-20; `plano_parcelas.dias_offset` = 8/38/69/100.
- O formulário (`BudgetFormPage.tsx`) grava os offsets em dias **a partir do dia do salvamento** (12/11).
- A Edge Function `generate-report` (`calcularParcelasPdf`) somava os offsets a `data_inicio_pagamento` (20/11 + 8 = 28/11). Dado no banco correto; erro só no PDF.

## Correção
`supabase/functions/generate-report/index.ts`: parcela 1 = `data_inicio_pagamento`; demais = início + (offset_i − offset_1). Vale para `plano_parcelas` e para `prazo_pagamento_dias`. Sem mudança de banco.

## Critério de aceite
PDF do ORC-0052 mostra 20/11, 20/12, 20/01, 20/02.

## Risco em aberto (decisão do usuário)
`aprovar_orcamento_financeiro` usa `v_data_base := current_date` + offsets. Se a aprovação ocorrer em dia diferente do salvamento, as parcelas do financeiro (e o PDF pós-aprovação, que lê o financeiro) deslocam. Correção possível: a RPC calcular o vencimento a partir de `data_inicio_pagamento` (mesma regra acima). Migration `20261112_344_spec290_aprovacao_vencimento_parte_da_data_inicio` (up/rollback/dry_run) redigida e ensaiada em ROLLBACK, **APLICADA em SP em 12/11/2026**: a função passa a usar `v_data_base := data_inicio_pagamento − offset[1]` quando há data de início; sem data, comportamento antigo. Só vale para aprovações futuras (parcelas já geradas não mudam).

## Publicação
Deploy da Edge Function `generate-report` (SP `bgtfrcbipuxnsexbppsh`). Rollback: reverter o arquivo e publicar de novo.
