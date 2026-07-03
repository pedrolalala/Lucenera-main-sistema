# Automações Supabase

Esta pasta centraliza a visão de automações Supabase do ecossistema Lucenera.

Ela contém:

- código das Edge Functions remotas;
- inventário das RPCs/funções Postgres;
- inventário de triggers/automações internas do banco;
- observações de funções obsoletas, duplicadas ou legadas.

Em 2026-06-26, as Edge Functions ativas foram conferidas e baixadas diretamente do projeto Supabase remoto `vcvcwzmbiftcawncibke` usando `supabase functions list` e `supabase functions download --use-api`.

## Fonte de verdade

Para Edge Functions, a referência operacional atual é:

1. Supabase remoto;
2. esta pasta central;
3. cópias dentro dos sistemas, apenas como histórico/local de desenvolvimento.

As pastas `Sistema/*/supabase/functions` podem ter duplicações ou variações antigas. Antes de promover qualquer alteração, conferir esta pasta central e a lista remota.

Para RPCs/funções Postgres e triggers, a referência operacional atual está nos snapshots:

- `supabase/db/current/03_functions.sql`
- `supabase/db/current/04_triggers.sql`

Atenção: o snapshot de `db/current/` é de 2026-06-25 e ainda não reflete a SPEC-005. Para `public.fn_aprovar_orcamento()`, `public.orcamentos.trg_aprovar_orcamento` e `public.trigger_proteger_parcelas()`, use a migration `db/migrations/20260626_009_spec005_remocao_triggers_legados_aprovacao/` até a próxima reextração.

## Funções remotas ativas em 2026-06-26

- `salvar-projeto`
- `update-project`
- `chat-consulta`
- `chat-agent`
- `welcome-email`
- `generate-report`
- `sync-sharepoint`
- `sync-teams`
- `enviar-confirmacao-email`
- `parse-budget-pdf`
- `process-budget-pdf`
- `process-remittance`
- `process-billing-automation` (legada; não usar no fluxo novo)

## Atenção

- `sync-fechamentos-automatica` não aparece mais no remoto e foi removida desta pasta central.
- `process-billing-automation` ainda aparece no remoto como função legada. Ela foi substituída funcionalmente pelo fluxo RPC `public.aprovar_orcamento_financeiro(p_orcamento_id uuid)` + Administração Bancária e deve ser removida depois de confirmar que não há scheduler/webhook externo chamando a função.
- `aprovar-orcamento-financeiro` nesta pasta não é uma Edge Function remota; é documentação do fluxo/RPC de banco `public.aprovar_orcamento_financeiro(p_orcamento_id uuid)`.
- Funções locais da Logística backup, como `create-user`, `migrate-helper`, `optimize-route`, `reset-user-password`, `sincronizar-fotos` e `sincronizar-materiais`, não aparecem no Supabase remoto porque esse sistema está fora do Supabase atual. Elas devem ser analisadas ao replicar o backup para o novo sistema de Logística.
- Funções locais encontradas no RH não são fonte de verdade.

## Regra

Antes de criar nova função, verificar se a regra deve estar:

1. na UI;
2. em uma RPC do banco;
3. em uma Edge Function;
4. em automação externa/API.

### Como definir o que deve estar em cada lugar

> Toca só pixel? UI. Toca só dado? RPC. Toca o mundo externo ou função complexa? Edge.
> Regra de ouro: Nunca confie no Frontend.

- Duplicação consciente: Duplicar uma validação na UI para UX (feedback imediato), desde que a verdade absoluta esteja na RPC ou no RLS. A UI valida para o usuário não esperar; o banco valida para o sistema não quebrar.
- Padrão de arquitetura sustentável: Para sistemas Supabase escaláveis, considere essa camada de organização:
  - RLS Policies -> autorização declarativa (quem vê o quê)
  - RPC Functions -> lógica de negócio transacional (o quê pode acontecer)
  - Triggers -> side effects internos ao banco (auditoria, denormalização)
  - Edge Functions -> integração com mundo externo (APIs, webhooks, jobs)
  - UI -> apresentação + UX + validação espelhada (nunca como verdade)

## Inventário

Para a visão completa de automações, veja `AUTOMATION_INVENTORY.md`.
