# Migration 20260707_024 - RLS de leitura para SPEC-010

## Contexto

O hardening `20260707_023` corrigiu as views da SPEC-010 para `security_invoker`
e revogou todo acesso de `anon`/`authenticated` nas tabelas
`estoque_saldos_projeto_item`/`estoque_movimentos_projeto_item` e nas 3 views,
porque a policy de negocio de leitura ainda nao tinha sido definida
(`pending_decisions.md`, secao "Saldos de estoque por item de projeto").

Esta migration define essa policy: leitura ampla para qualquer usuario
`authenticated`, no mesmo padrao ja usado em `projeto_itens`
(`pi_select ... FOR SELECT TO authenticated USING (true)`). Escrita continua
exclusiva das RPCs `SECURITY DEFINER` (`aprovar_orcamento_financeiro` e as
novas RPCs das SPEC-011/012/015) — nao existe policy de INSERT/UPDATE/DELETE
para `authenticated` nestas tabelas.

Permissao granular por modulo/acao (Hub/SPEC-006, com UI propria de
configuracao de role) fica para quando esse sistema existir; esta migration
nao antecipa isso, so destrava a leitura que a SPEC-010/011/012/015 precisam
para funcionar.

## Arquivos

| Arquivo | Funcao |
|---|---|
| `001_grant_select_authenticated.sql` | `GRANT SELECT` + `CREATE POLICY` de leitura para `authenticated` nas 2 tabelas e 3 views da SPEC-010. |

## Aplicado em

2026-07-07, via `psql "$SUPABASE_DB_URL" -f 001_grant_select_authenticated.sql`
(conexao de `Lucenera - ADAPTA PASS/.env`).

## Verificacao pos-aplicacao

```sql
BEGIN; SET LOCAL ROLE anon;
SELECT count(*) FROM public.estoque_saldos_projeto_item; -- erro de permissao esperado
ROLLBACK;

BEGIN; SET LOCAL ROLE authenticated;
SELECT count(*) FROM public.estoque_saldos_projeto_item; -- deve retornar linhas
ROLLBACK;
```

Confirmado: `anon` recebe `permission denied`; `authenticated` le as 9 linhas
existentes via tabela e via `vw_estoque_saldos_projeto_item`.
