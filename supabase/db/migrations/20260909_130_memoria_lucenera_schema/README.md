# 20260909_130_memoria_lucenera_schema

Schema **isolado `memoria`** da "Memória Lucenera" (SPEC-129). Nenhum objeto é
criado em `public`. Scripts recebidos do repo do Filippo
(`github.com/filippogiorgibrasil/memoria-lucenera`) **sem edição de regra de
negócio** — só renomeados com prefixo de ordem.

## Ordem de aplicação

| Arquivo | Origem | O que cria | Estado no Supabase real |
|---|---|---|---|
| `01_supabase.sql` | `supabase.sql` | núcleo: 12 tabelas (`entities`, `knowledge_items`, `projects`, `experiences`, `decisions`, `sources`, `relations`, `citations`, `files`, `record_versions`, `inbox_items`, `domains`), enums, RLS por `owner_id` (12 policies), triggers `archive_version`/`keep_original_transcription`/`touch_updated_at`, bucket privado `lucenera-memory-files` | ✅ **APLICADO pelo usuário (verificado 2026-09-09)** |
| `02_memory-organization.sql` | `memory-organization.sql` | tabelas `memory_organization_*` (regras/feedback/evidência/versões/settings/conflitos) | ❌ pendente |
| `03_document-ingestion.sql` | `document-ingestion.sql` | RPC transacional `save_document_analysis` | ❌ pendente |
| `04_long-document-ingestion.sql` | `long-document-ingestion.sql` | tabelas `document_ingestion_runs`/`document_sections`, RPC `save_long_document_analysis` | ❌ pendente |
| `99_verify-isolation.sql` | `verify-isolation.sql` | **só leitura** — resume tabelas em `memoria`, RLS e privacidade do bucket | rodar depois de 02–04 |

Scripts são repetíveis (`if not exists`, recriam só policies/triggers da própria
memória). Aplicar 02–04 só com autorização explícita do usuário, um a um.

## Exposição à API

O schema existe, mas **não está nos Exposed schemas** do PostgREST
(`pgrst.db_schemas` sem `memoria` em 2026-09-09). Até isso ser resolvido o
frontend não alcança as tabelas. Opções:

1. Painel: **Project Settings → API → Exposed schemas** → acrescentar `memoria`
   (campo de texto; só expõe o schema já existente, não cria nada).
2. SQL: `ALTER ROLE authenticator SET pgrst.db_schemas = 'public, graphql_public, memoria';`
   seguido de `NOTIFY pgrst, 'reload config';` (a opção 1 do painel tem precedência
   e pode reverter isto num futuro save de config).

## Rollback

`DROP SCHEMA memoria CASCADE;` + remover o bucket `lucenera-memory-files`.
Não afeta `public`.
