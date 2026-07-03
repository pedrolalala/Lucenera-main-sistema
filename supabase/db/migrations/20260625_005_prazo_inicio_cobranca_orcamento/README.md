# Migration: SPEC-002 prazo de inicio de cobranca do orcamento

Espelho central da migration do sistema de Orcamentos:

`Sistema/gestao-financeira-clone-544cb (1)/supabase/migrations/20260625120000_spec002_prazo_inicio_cobranca.sql`

## Objetivo

Adicionar `orcamentos.prazo_inicio_cobranca_dias` para guardar o numero bruto digitado no formulario de orcamento.

Esse campo complementa `orcamentos.prazo_pagamento_dias`, que guarda o array calculado de vencimentos. Exemplo: prazo inicial 30 dias e 3 parcelas gera `[30, 60, 90]`.

## Regras

- `prazo_inicio_cobranca_dias` pode ser nulo para dados antigos.
- Quando preenchido, precisa ser `>= 0`.
- A RPC `public.aprovar_orcamento_financeiro` continua usando `_lucenera_parse_prazo_pagamento(...)`; a preferencia operacional e usar o array `prazo_pagamento_dias`.
- Orcamentos antigos sem prazo interpretavel precisam ser editados antes de aprovar.

## Estado

Aplicada no banco remoto antes do snapshot de 2026-06-25. O snapshot em `db/current/` ja reflete esta migration.
