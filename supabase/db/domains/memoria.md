# Domínio: Memória Lucenera (schema `memoria`)

> Origem: SPEC-129. Sistema de memória institucional criado pelo Filippo
> (`github.com/filippogiorgibrasil/memoria-lucenera`), trazido para o ecossistema
> como sistema interno (Skip projectId 57204 → `memoria-lucenera-2e074.goskip.app`,
> tile `slug='memoria'` em `public.systems`).

## Papel no ecossistema

Base de conhecimento institucional: entidades, conhecimentos, experiências,
decisões, projetos, fontes, relações e citações da empresa — mais uma camada de
"caixa de entrada" (voz / documento) e uma camada de regras de organização
aprendidas.

Não guarda dado operacional em tempo real (estoque, preço, disponibilidade). A
integração com dados de `public` será feita depois por uma função de consulta
restrita (RPC/Edge Function com whitelist), nunca acesso SQL direto — ver SPEC-129
e o aviso do `INSTALACAO-LUCENERA.md` do repo.

## Isolamento

- Tudo vive no schema **`memoria`**, criado por `supabase.sql`. **Nada** é criado
  em `public`.
- `revoke all on schema memoria from public, anon` + `grant usage ... to
  authenticated, service_role`. O `anon` **não** enxerga nada — o app exige login.
- RLS por `owner_id` em todas as tabelas (cada usuário só vê o que criou).
- Storage: bucket privado **`lucenera-memory-files`**, policies por `owner_id`.
- Exposto à API via `authenticator.pgrst.db_schemas = 'public, graphql_public,
  memoria'` (SPEC-129; equivalente ao campo "Exposed schemas" do painel).

## Tabelas (núcleo — `supabase.sql`, aplicado)

`entities`, `knowledge_items`, `projects`, `experiences`, `decisions`, `sources`,
`relations`, `citations`, `files`, `record_versions`, `inbox_items`, `domains`.

Triggers: `touch_updated_at`, `archive_version` (versiona antes de alterar),
`keep_original_transcription`.

## Tabelas (fase 2 — NÃO aplicadas)

- `memory-organization.sql` → `memory_organization_rules` / `_feedback` /
  `_rule_evidence` / `_rule_versions` / `_settings` / `_conflicts`.
- `document-ingestion.sql` → RPC `save_document_analysis`.
- `long-document-ingestion.sql` → `document_ingestion_runs`, `document_sections`,
  RPC `save_long_document_analysis`.

Enquanto não aplicadas, o app degrada de forma graciosa (o adapter faz `try/catch`
por tabela opcional) e os menus/telas correspondentes ficam fora.

## Edge Functions (fase 2 — NÃO deployadas)

`interpret-memory`, `process-document`, `process-document-section`,
`consolidate-document-run`. No repo do Filippo chamam a OpenAI; a decisão da
SPEC-129 é adaptá-las para **Gemini** (`GEMINI_API_KEY`).

## Relação com outros domínios

- **Hub/TI:** `public.systems` (`slug='memoria'`) + RBAC (`hub_sistemas_permitidos`).
  Login único via `exchange-cross-system-code` (mesmo projeto Supabase; o app
  consome `?sso_code=` em `public/app/sso.js`).
- **Auth:** `memoria.*.owner_id -> auth.users(id)`. A troca de SSO resolve o
  usuário pelo `public.usuarios` (e-mail) e devolve sessão.
- Nenhuma FK cruza de `memoria` para `public`.
