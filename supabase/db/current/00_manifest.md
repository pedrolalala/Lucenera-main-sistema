# Manifesto do snapshot atual

Status: snapshot reextraído do Supabase real em **2026-06-26**, já refletindo a SPEC-005.

Histórico: o snapshot anterior (2026-06-25) cobria as SPECs 001-004. A SPEC-005 foi aplicada no remoto em 2026-06-26, e duas tentativas de reextração falharam por falta de `pg_dump`/Docker no ambiente local (a `supabase` CLI v2.72.7 não tem modo "schema only" sem esses binários). O bloqueio foi resolvido instalando o cliente Postgres via Homebrew: `libpq` (versão 18.4) já estava instalado mas não estava no `PATH` — `pg_dump`/`psql` foram chamados diretamente de `$(brew --prefix libpq)/bin`, usando a conexão já configurada em `SUPABASE_DB_URL` (no `.env` da raiz do projeto). `03_functions.sql`, `04_triggers.sql`, `05_views.sql` e `07_rls_policies.sql` foram gerados por queries SQL (`pg_get_functiondef`, `pg_get_triggerdef`, `pg_views`, `pg_policies`) executadas via `psql`, não por `pg_dump`.

## Fonte de verdade

Os arquivos desta pasta foram gerados a partir da conexão Postgres real configurada em `SUPABASE_DB_URL`.

As migrations dos sistemas em `Sistema/*/supabase/migrations` não são fonte de verdade final. Elas servem como histórico, referência e apoio para entender como certas partes nasceram.

## Arquivos gerados

- `01_schema_full.sql`: dump `pg_dump --schema=public --schema-only`.
- `02_auth_users_minimal.sql`: dump `pg_dump --schema=auth --schema-only`.
- `03_functions.sql`: funções/RPCs do schema `public`, extraídas por `pg_get_functiondef`.
- `04_triggers.sql`: triggers de `public`, `auth` e `storage`, extraídas por `pg_get_triggerdef`.
- `05_views.sql`: views de `public`, `auth` e `storage`, extraídas de `pg_views`.
- `06_storage.sql`: dump `pg_dump --schema=storage --schema-only`.
- `07_rls_policies.sql`: tabelas com RLS e policies de `public`, `auth` e `storage`.
- `08_seed_minimo.sql`: pendente; não foi extraído dado de produção.
- `09_schema_inventory.md`: inventário legível de tabelas, views, colunas e foreign keys.

## Resumo extraído (26/06/2026)

- Banco: PostgreSQL 17.6.
- Schema `public`: 72 tabelas base, 37 views e 55 funções.
- Triggers em `public`, `auth` e `storage`: 47.
- Tabelas com RLS em `public`, `auth` e `storage`: 89 (confirmado por query direta, igual ao snapshot anterior).
- Policies em `public`, `auth` e `storage`: 275 (igual ao snapshot anterior).
- `09_schema_inventory.md` ainda não foi regenerado nesta rodada (mantém a versão de 25/06; ver pendência abaixo).

## Observações da reextração (26/06/2026)

- **Confirmado**: `public.fn_aprovar_orcamento()` e `public.orcamentos.trg_aprovar_orcamento` **não aparecem mais** em `03_functions.sql`/`04_triggers.sql` — a remoção da SPEC-005 está refletida no banco real.
- **Confirmado**: `boletos.projeto_id` não existe na definição atual da tabela `boletos` em `01_schema_full.sql`.
- `historico_status_orcamento` permanece como tabela da família Ubiqua/revenda; o fluxo novo usa `historico_status_orcamentos`.
- Não há nenhuma trigger, função ou view em `public`/`auth`/`storage` referenciando `net.http`, `pg_net` ou `process-billing-automation` — consistente com a confirmação registrada em `supabase/functions/process-billing-automation/README.md`.

## Próximos passos

1. ~~Reextrair `db/current/` assim que houver `pg_dump` local ou Docker disponível~~ — feito em 26/06/2026 via `libpq`/`psql` direto.
2. Regenerar `09_schema_inventory.md` (inventário legível de tabelas/colunas/FKs) a partir deste novo snapshot — ainda pendente.
3. Atualizar os contextos locais dos sistemas quando novas decisões estruturais forem feitas.
4. Fazer análise de segurança/RLS em etapa própria depois da consolidação funcional do banco.
