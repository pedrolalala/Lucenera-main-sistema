# Migration group 20260625_001 — Snapshot do DB atual

Objetivo: criar uma base central organizada do banco real atual.

Este grupo não deve ser montado copiando cegamente migrations antigas dos sistemas. Ele deve ser preenchido a partir do Supabase real, já considerando as correções aplicadas.

## Ordem proposta

1. `001_auth_users_base.sql`
2. `002_core_cadastros.sql`
3. `003_orcamentos.sql`
4. `004_financeiro.sql`
5. `005_estoque_compras.sql`
6. `006_logistica.sql`
7. `007_rh.sql`
8. `008_hub_ti.sql`
9. `009_functions.sql`
10. `010_views_triggers_storage.sql`

## Ação a ser realizada

Depois de extrair o schema real, dividir o SQL por domínio nesta pasta e conferir se a ordem de execução recria o banco de forma limpa.

