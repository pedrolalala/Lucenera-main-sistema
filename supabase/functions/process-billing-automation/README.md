# Function: process-billing-automation

## Status

**Removida do projeto remoto em 2026-06-26** (`supabase functions delete process-billing-automation --project-ref vcvcwzmbiftcawncibke`). Este README fica como registro histórico.

### Confirmação de 2026-06-26 (antes da remoção)

Revisão do snapshot real do banco (`db/current/03_functions.sql`, `db/current/04_triggers.sql`) e grep em todo o código frontend dos 9 sistemas, mais consulta direta ao banco via `psql`:

- Nenhuma trigger ou função no banco real continha `net.http`, `pg_net` ou qualquer chamada HTTP para esta function.
- `fn_aprovar_orcamento()` (a trigger legada real, removida pela SPEC-005) fazia apenas `INSERT` direto em `projetos`/`projeto_itens` — nunca chamou esta Edge Function.
- Nenhuma chamada `functions.invoke('process-billing-automation')` (ou equivalente) existia em nenhum sistema em `Sistema/`.
- **Confirmado via `psql` direto**: a extensão `pg_cron` não está instalada neste banco (`SELECT extname FROM pg_extension` não lista `pg_cron`), e a tabela `cron.job` não existe. A extensão `pg_net` também não está instalada, e `supabase_functions.hooks` (database webhooks) não existe. Ou seja: não havia nenhum mecanismo possível — nem cron, nem webhook, nem chamada de banco — capaz de invocar esta function.

**Conclusão**: function 100% órfã, sem nenhum chamador possível. Removida com segurança.

## Decisao atual

O fluxo operacional novo e:

```text
Orcamento aprovado
  -> public.aprovar_orcamento_financeiro(p_orcamento_id uuid)
  -> projeto_itens / projeto_parcelas / boletos por orcamento_id
  -> Administracao Bancaria
```

Esta Edge Function e mantida aqui apenas porque ainda existe publicada remotamente. Antes de qualquer limpeza definitiva, confirmar se nao ha scheduler/webhook externo chamando a funcao e entao remover do projeto remoto.

## Regra

Nao reativar, chamar ou evoluir esta funcao para o fluxo novo. Qualquer regra transacional de aprovacao deve ficar na RPC do banco.
