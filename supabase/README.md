# Supabase Lucenera — fonte de verdade do banco

Esta pasta é a referência central do banco de dados do ecossistema Lucenera.

O objetivo é simples: quando uma IA, uma IDE ou uma pessoa for mexer em qualquer sistema, ela deve entender o banco a partir daqui — e não a partir das migrations espalhadas dentro dos projetos.

## Regra principal

O banco Supabase atual é a fonte de verdade operacional.

As migrations antigas dentro de `Sistema/*/supabase/migrations` ajudam a entender histórico e intenção, mas não devem ser tratadas como verdade final, porque existem divergências entre projetos.

## Como usar esta pasta

1. Consultar `db/current/` para entender o estado consolidado do banco.
2. Consultar `db/domains/` para entender a lógica de cada área do negócio.
3. Criar novas alterações sempre em `db/migrations/`, agrupadas por objetivo.
4. Atualizar `docs/ai_context_global.md` quando uma decisão estrutural mudar.
5. Atualizar o `AI_DB_CONTEXT.md` do sistema afetado para manter a IA bem orientada sem duplicar o banco inteiro.

## Estado operacional atual

- Snapshot em `db/current/`: reextraído em **2026-07-07** via `pg_dump`/`psql` (`libpq` do Homebrew) e `information_schema`/`pg_catalog`, já refletindo a SPEC-005, `20260703_017_razao_social_clientes`, `20260704_018_aprovacao_cliente_orcamento`, `20260706_020` (SPEC-016), `20260706_021` (SPEC-018), `20260706_022` (SPEC-010) e o hardening `20260707_023`.
- Estado confirmado em 06/07/2026: a SPEC-016 foi aplicada no Supabase real e normalizou o fluxo oficial `enviado_cliente -> Aprovação Financeira -> Orçamento Aprovado`; `aprovado_cliente`, `aprovado` e `aprovado_financeiro` permanecem apenas como legados/compatibilidade.
- Estado confirmado em 06/07/2026: a SPEC-018 criou `public.criar_produto_orcamento(p_payload jsonb)` para o modal de Orçamentos gravar no cadastro canônico `produtos`, sem catálogo paralelo.
- Estado confirmado em 07/07/2026: a SPEC-010 está aplicada no Supabase real com `estoque_saldos_projeto_item`, `estoque_movimentos_projeto_item` e as views `vw_estoque_por_produto_projeto`, `vw_estoque_resumo`, `vw_estoque_saldos_projeto_item`, `vw_orcamentos_aprovacao_financeira_auditoria`. O hardening `20260707_023` já aplicou `security_invoker=true` nas views de estoque; `db/current/` foi reextraído e reflete esse estado.
- Achado na reextração de 07/07/2026: `04_triggers.sql` e `07_rls_policies.sql` cobriam apenas o schema `public` desde 26/06/2026, mesmo o manifesto sempre tendo declarado cobertura de `public`+`auth`+`storage`. A lacuna foi corrigida — foram adicionados 5 triggers reais (`auth.users`, `storage.buckets`, `storage.objects`) e 15 policies de `storage.objects` que estavam ausentes. Não é efeito de migration recente, é correção de uma extração incompleta anterior.
- Edge Functions: baixadas do projeto remoto em 2026-06-26. `sync-fechamentos-automatica` não aparece mais no remoto. `process-billing-automation` foi removida do remoto em 2026-06-26 após confirmação de que não tinha chamador (ver `functions/process-billing-automation/README.md`).

## Estrutura

```text
supabase/
  db/
    current/      Snapshot documentado do banco atual.
    domains/      Explicação por domínio de negócio.
    migrations/   Migrations centrais e agrupadas por objetivo.
  functions/      Edge functions / funções de integração planejadas ou existentes.
  docs/           Contexto global para IA, relações e decisões pendentes.
```

Leia também `docs/system_context_strategy.md` para entender como uma IA deve usar o contexto central quando estiver trabalhando dentro de um sistema específico.

## O que os sistemas devem conter

Cada sistema em `Sistema/` pode ter sua própria pasta `supabase`, mas ela deve funcionar como contexto local e ponte para esta pasta central.

O ideal é que cada sistema tenha:

- `supabase/README.md`: explica que a fonte de verdade está nesta pasta central.
- `supabase/AI_DB_CONTEXT.md`: resumo do que aquele sistema precisa saber do banco.
- migrations locais apenas quando forem temporárias, legadas ou explicitamente necessárias para o projeto.

## Fluxo recomendado para novas mudanças de banco

1. Descrever a necessidade em uma SPEC `Planos de Ação/SPECs/`.
2. Criar uma migration central em `supabase/db/migrations/YYYYMMDD_NNN_nome_do_grupo/`.
3. Aplicar a migration no Supabase real.
4. Atualizar o snapshot em `supabase/db/current/`.
5. Atualizar o domínio afetado em `supabase/db/domains/`.
6. Atualizar o contexto do sistema afetado em `Sistema/<sistema>/supabase/AI_DB_CONTEXT.md`.

## Decisões estruturais já aplicadas

- Boletos ficam vinculados por `orcamento_id`; `boletos.projeto_id` foi removido porque o projeto é derivado de `orcamentos.projeto_id`.
- `projeto_parcelas.venda_id` foi removido do fluxo novo; parcelas de orçamento aprovado usam `orcamento_id`.
- `projetos.valor_total` é mantido por `public.sync_projeto_valor_total()` a partir de `projeto_itens.subtotal`.
- `orcamentos.prazo_inicio_cobranca_dias` guarda o prazo bruto digitado; `orcamentos.prazo_pagamento_dias` guarda os vencimentos calculados.
- Frete é dado estruturado em `orcamentos.frete_tipo` (`com_frete` / `sem_frete`) e `orcamentos.frete_valor`.
- Histórico de aprovação do fluxo Lucenera usa `historico_status_orcamentos`; `historico_status_orcamento` permanece ligado à família Ubiqua/revenda.
- Parcelas do fluxo novo têm unicidade parcial por `(orcamento_id, numero_parcela)`; parcelas legadas sem orçamento mantêm unicidade por `(projeto_id, numero_parcela)`.
- A aprovação transacional deve usar `public.aprovar_orcamento_financeiro(p_orcamento_id uuid)`, não trigger legado nem Edge Function de billing.

## Observação sobre segurança

As políticas de segurança, RLS, permissões de anon/authenticated e exposição pública devem ser revisadas em uma etapa própria depois da consolidação funcional do banco.
