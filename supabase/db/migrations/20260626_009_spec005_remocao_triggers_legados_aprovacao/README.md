# Migration: SPEC-005 remocao de triggers legados de aprovacao

Espelho central das migrations do sistema de Orcamentos:

- `Sistema/gestao-financeira-clone-544cb (1)/supabase/migrations/20260626090000_spec005_remove_triggers_legados_aprovacao.sql`
- `Sistema/gestao-financeira-clone-544cb (1)/supabase/migrations/20260626093000_spec005_fix_subtotal_coluna_gerada.sql`

## Objetivo

Remover automacoes antigas que bloqueavam a aprovacao real de orcamentos no fluxo novo da SPEC-001.

## Mudancas

- Remove `public.orcamentos.trg_aprovar_orcamento`.
- Remove `public.fn_aprovar_orcamento()`.
- Ajusta `public.trigger_proteger_parcelas()` para liberar parcelas com `orcamento_id IS NOT NULL`.
- Ajusta `public.aprovar_orcamento_financeiro_base_spec001(...)` para nao inserir valor explicito em `projeto_itens.subtotal`, que passou a ser coluna `GENERATED ALWAYS`.

## Estado

Aplicada no banco remoto em 2026-06-26 e validada com teste transacional de aprovacao real com `ROLLBACK`.

Atencao: `db/current/` ainda nao foi reextraido depois desta SPEC. Enquanto o novo snapshot nao existir, esta pasta de migration e a SPEC-005 sao a referencia para a remocao do trigger/função legados.
