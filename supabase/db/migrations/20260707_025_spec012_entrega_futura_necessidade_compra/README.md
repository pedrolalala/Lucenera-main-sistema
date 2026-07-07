# Migration 20260707_025 - SPEC-012 (Entrega Futura e Necessidade de Compra)

## Contexto

Ver `03-Projeto/Planos de Ação/SPECs/SPEC-012_Entrega_Futura_Necessidade_Compra.md`.
Duas views de leitura sobre `estoque_saldos_projeto_item` (SPEC-010), sem
tabela nova nem RPC.

Correcao em relacao ao desenho original da SPEC: a coluna real em `produtos`
e `codigo_produto`, nao `codigo`.

## Arquivos

| Arquivo | Funcao |
|---|---|
| `001_views.sql` | `vw_entrega_futura_projeto_item` e `vw_necessidade_compra`, `security_invoker = true`, com `GRANT SELECT` para `authenticated`. |

## Aplicado em

2026-07-07, via `psql "$SUPABASE_DB_URL" -f 001_views.sql`.

## Verificacao pos-aplicacao

```sql
BEGIN; SET LOCAL ROLE authenticated;
SELECT count(*) FROM public.vw_entrega_futura_projeto_item;
SELECT count(*) FROM public.vw_necessidade_compra;
ROLLBACK;
```

Ambas retornaram 0 linhas em 07/07/2026 — esperado, pois os 9 registros
existentes de `estoque_saldos_projeto_item` ainda nao tem `q_entrega_futura > 0`
(nenhum deficit de estoque no momento da aplicacao).

## Depois da aplicacao

- Reextrair `supabase/db/current/` (feito ao final do lote de migrations
  desta rodada, junto com SPEC-011/015/008).
- Marcar SPEC-012 como implementada em "Realizado".
