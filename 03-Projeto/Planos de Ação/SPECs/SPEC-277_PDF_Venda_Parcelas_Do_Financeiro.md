# SPEC-277 — PDF da venda: parcelas vêm do financeiro, não do plano do orçamento

**Data:** 11/11/2026 · **Origem:** Central de Solicitações / Caroline (bug "Datas de vencimento na exportação PDF com divergência", VENDA-8508).

## Problema
Depois de corrigir a condição de pagamento da venda (datas e valores), o Contas a Receber fica certo, mas o PDF impresso continua com as datas antigas.

## Causa
A Edge Function `generate-report` monta "Condições de Pagamento" com `orcamentos.plano_parcelas` + `data_inicio_pagamento` (SPEC-152). Esse plano é gravado na aprovação e não acompanha as correções feitas na venda/financeiro.

Caso VENDA-8508 (ORC-0002): plano do orçamento = 16/11 + 5/29/60 dias → PDF 21/11, 15/12, 15/01. Financeiro real (`financeiro_titulos`/`financeiro_parcelas`, origem `orcamento`) = 16/11, 10/12, 10/01. Os valores (3 × R$ 2.088,00) batiam.

## Entregue (código na main, ainda não publicado)
- `generate-report`: nova `buscarParcelasFinanceiro`. Se o orçamento já tem título a receber ativo (`origem_tipo='orcamento'`, sem `cancelado_em`), o PDF lista as parcelas dele (exclui cancelada/substituída/renegociada). Sem título (orçamento não aprovado) continua o cálculo pelo plano.
- Sem mudança de banco. Consulta testada em SP: devolve 16/11, 10/12, 10/01.

## Pendente
- Publicar a função em SP (autorização do Filippo; sai da main) e a Caroline reimprimir a VENDA-8508.
- Decisão: antecipação/renegociação gera outro título; hoje só vale título de origem `orcamento`.

## Rollback
Reverter o commit e republicar a função anterior (versão 5 no ar).
