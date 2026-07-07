# Manifesto do snapshot atual

Status: snapshot reextraído do Supabase real em **2026-07-07 (segunda rodada)**, já refletindo as migrations `20260706_020_normalizacao_aprovacao_financeira_orcamento`, `20260706_021_criar_produto_orcamento`, `20260706_022_saldos_estoque_projeto_item`, o hardening `20260707_023_spec010_hardening`, a RLS de leitura `20260707_024_rls_leitura_estoque_projeto_item`, as SPECs `20260707_025_spec012_entrega_futura_necessidade_compra`, `20260707_026_spec011_transferencia_reserva`, `20260707_027_spec015_devolucao_estoque` e `20260707_028_spec008_conciliacao_retorno_bancario` (incluindo a remoção do trigger órfão `update_parcelas_updated_at` e o ajuste do índice de `retorno_bancario_arquivos.hash_conteudo`).

## Segunda rodada de reextração (2026-07-07)

`01_schema_full.sql` foi regerado por completo via `pg_dump --schema=public --schema-only --no-owner --no-privileges`. O diff contra a versão anterior confirmou que **só** os objetos novos desta rodada apareceram: tabelas `transferencias_estoque`, `devolucoes_estoque`, `retorno_bancario_arquivos`, `retorno_bancario_registros`; funções `solicitar_/aprovar_/cancelar_transferencia_estoque`, `registrar_devolucao_projeto_item`, `processar_retorno_bancario`; views `vw_entrega_futura_projeto_item`, `vw_necessidade_compra`, `vw_transferencias_estoque`; e as 6 novas policies de leitura para `authenticated`. `03_functions.sql`, `05_views.sql` e `07_rls_policies.sql` tiveram apenas os objetos novos **acrescentados** ao final (via `pg_get_functiondef`/`pg_views`/`pg_policies`), sem regerar o arquivo inteiro — o conteúdo pré-existente não foi tocado. `02_auth_users_minimal.sql`, `06_storage.sql` e `09_schema_inventory.md` **não foram reextraídos nesta rodada** (nenhuma mudança em `auth`/`storage`; `09` fica desatualizado quanto às 4 tabelas/3 views/5 funções novas até a próxima reextração completa).

Histórico: o snapshot anterior (2026-07-06) refletia a SPEC-005, `20260703_017_razao_social_clientes` e `20260704_018_aprovacao_cliente_orcamento`, mas ainda não a SPEC-010/018/020. Em 2026-07-07, `pg_dump`/`psql` foram chamados diretamente de `/opt/homebrew/opt/libpq/bin`, usando a conexão já configurada em `SUPABASE_DB_URL` (no `.env` da raiz do projeto). `01_schema_full.sql`, `02_auth_users_minimal.sql` e `06_storage.sql` foram reconferidos via `pg_dump --schema-only` (conteúdo idêntico ao snapshot de 06/07, apenas os tokens `\restrict`/`\unrestrict` mudam a cada dump). `03_functions.sql` e `05_views.sql` foram reconferidos via `pg_get_functiondef`/`pg_views` (conteúdo idêntico). `04_triggers.sql` e `07_rls_policies.sql` foram regenerados via `pg_get_triggerdef`/`pg_policies` e ganharam entradas que a extração anterior omitia por engano (triggers e policies dos schemas `auth`/`storage` que não são causados pelas migrations recentes). `09_schema_inventory.md` foi regenerado via `information_schema.columns`/`pg_constraint`/`pg_class`.

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

## Resumo extraído (07/07/2026)

- Banco: PostgreSQL 17.6.
- Schema `public`: 74 tabelas base, 42 views/materialized views e 79 funções.
- Triggers em `public`, `auth` e `storage`: 53.
- Tabelas com RLS em `public`, `auth` e `storage`: 92.
- Policies em `public`, `auth` e `storage`: 345 (330 em `public`, 15 em `storage`, 0 em `auth`).
- `09_schema_inventory.md` regenerado nesta rodada.

## Observações da reextração (07/07/2026)

- **Confirmado**: `estoque_saldos_projeto_item`, `estoque_movimentos_projeto_item` e as views `vw_estoque_por_produto_projeto`, `vw_estoque_resumo`, `vw_estoque_saldos_projeto_item`, `vw_orcamentos_aprovacao_financeira_auditoria` (SPEC-010/020) existem no banco real e agora estão refletidas no schema, no inventário e nos FKs.
- **Confirmado**: `public.criar_produto_orcamento(p_payload jsonb)` (SPEC-018) existe no banco real.
- **Confirmado**: views de estoque da SPEC-010 têm `security_invoker=true` — o hardening de `20260707_023` já foi aplicado.
- **Achado**: `04_triggers.sql` e `07_rls_policies.sql` cobriam apenas o schema `public` desde a extração de 26/06/2026, apesar deste manifesto sempre ter declarado cobertura de `public`+`auth`+`storage`. Nesta rodada foram adicionados os 5 triggers reais de `auth`/`storage` (`on_auth_user_created`, triggers de `storage.buckets`/`storage.objects`) e as 15 policies de `storage.objects` que estavam ausentes. Isso não é efeito das migrations recentes — é uma lacuna da extração anterior, agora corrigida.
- **Confirmado**: schema (`01_schema_full.sql`), funções (`03_functions.sql`) e views (`05_views.sql`) já estavam com o conteúdo correto desde 06/07/2026 (a nota "ainda precisa ser reextraído" estava desatualizada); a reextração de hoje confirma que não houve mudança de conteúdo além do já registrado acima.
- `historico_status_orcamento` permanece como tabela da família Ubiqua/revenda; o fluxo novo usa `historico_status_orcamentos`.

## Próximos passos

1. Atualizar os contextos locais dos sistemas quando novas decisões estruturais forem feitas.
2. Fazer análise de segurança/RLS em etapa própria depois da consolidação funcional do banco — agora com cobertura completa de `storage` no inventário de RLS.
