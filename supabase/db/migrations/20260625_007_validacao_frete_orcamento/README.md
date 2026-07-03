# Migration group 20260625_007 — Validação de frete do orçamento

## Decisão

Orçamentos precisam registrar frete estruturado antes da aprovação financeira.

Valores persistidos em `orcamentos.frete_tipo`:

- `com_frete`
- `sem_frete`

## Alteração

- Adiciona constraints para validar `frete_tipo` e coerência entre `frete_tipo` e `frete_valor`.
- Atualiza `public.aprovar_orcamento_financeiro_base_spec001(...)` para bloquear aprovação sem frete estruturado.

## Observação

Esta migration corresponde à SPEC-003 e foi espelhada da migration aplicada no sistema de Orçamentos.
