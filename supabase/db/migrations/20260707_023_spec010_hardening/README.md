# Migration 20260707_023 - Hardening da SPEC-010

## Contexto

A SPEC-010 ja esta aplicada no Supabase real: existem `estoque_saldos_projeto_item`, `estoque_movimentos_projeto_item`, `vw_estoque_saldos_projeto_item`, `vw_estoque_por_produto_projeto` e `vw_estoque_resumo`.

Esta migration nao recria a SPEC-010. Ela corrige tres achados da revisao:

- as views da SPEC-010 expunham linhas para `anon`/`authenticated` porque foram criadas sem `security_invoker`;
- quatro produtos estavam com divergencia entre saldos abertos e `estoque_itens.quantidade_reservada`;
- `trigger_fechar_projeto` ainda entregava saldo de `q_entrega_futura` e baixava reserva pela quantidade original do item.

## Arquivos

| Arquivo | Funcao |
|---|---|
| `001_fix_views_rls.sql` | Recria as views com `security_invoker = true` e revoga acesso de `anon`/`authenticated` enquanto nao houver policy de negocio. |
| `002_reconcile_quantidade_reservada.sql` | Reconciliacao controlada dos quatro produtos divergentes encontrados em 2026-07-07. Falha se o conjunto mudar. |
| `003_harden_entrega_backfill.sql` | Atualiza `trigger_fechar_projeto` para bloquear `q_entrega_futura` e entregar apenas saldo coberto aberto; valida duplicidade de movimentos de backfill. |

## Ordem de aplicacao

Aplicar no Supabase SQL Editor, um arquivo por vez, apos revisao:

```sql
\i 001_fix_views_rls.sql
\i 002_reconcile_quantidade_reservada.sql
\i 003_harden_entrega_backfill.sql
```

## Historico de migrations

A verificacao de 07/07/2026 indicou que a SPEC-010 estava aplicada no banco
real, mas a tabela `supabase_migrations.schema_migrations` podia nao conter a
entrada `20260706_022`, provavelmente por aplicacao manual via SQL Editor.
Nao inserir linhas nessa tabela silenciosamente durante o hardening. Se a
equipe quiser paridade com o CLI, registrar isso em uma etapa administrativa
separada, depois de confirmar a politica de versionamento do projeto.

## Verificacoes obrigatorias apos aplicar

### Views nao podem vazar saldo por RLS

```sql
BEGIN;
SET LOCAL ROLE anon;
SELECT count(*) FROM public.vw_estoque_saldos_projeto_item;
SELECT count(*) FROM public.vw_estoque_por_produto_projeto;
SELECT count(*) FROM public.vw_estoque_resumo;
ROLLBACK;
```

Resultado aceito: erro de permissao ou zero linhas para as leituras dependentes de saldos da SPEC-010.

### Reconciliacao deve retornar zero linhas

```sql
WITH open_saldos AS (
  SELECT
    pi.produto_id,
    SUM(esp.q_reserva + esp.q_entrega_futura + esp.q_ag_separar + esp.q_separado) AS qtd_aberta
  FROM public.estoque_saldos_projeto_item esp
  JOIN public.projeto_itens pi ON pi.id = esp.projeto_item_id
  WHERE esp.status_operacional = 'ativo'
  GROUP BY pi.produto_id
),
recon AS (
  SELECT
    coalesce(os.produto_id, ei.produto_id) AS produto_id,
    coalesce(os.qtd_aberta, 0) AS qtd_aberta,
    coalesce(ei.quantidade_reservada, 0) AS quantidade_reservada
  FROM open_saldos os
  FULL JOIN public.estoque_itens ei
    ON ei.produto_id = os.produto_id
   AND ei.local = 'Estoque'::public.estoque_local
)
SELECT p.codigo_produto, p.nome, recon.qtd_aberta, recon.quantidade_reservada
FROM recon
JOIN public.produtos p ON p.id = recon.produto_id
WHERE abs(recon.qtd_aberta - recon.quantidade_reservada) > 0.001;
```

### Trigger de entrega deve bloquear entrega futura

Testar em transacao com projeto/orcamento de homologacao que possua `q_entrega_futura > 0`.

```sql
BEGIN;
-- Atualizar o projeto de teste para Entrega materiais.
-- Esperado: erro controlado informando entrega futura pendente.
ROLLBACK;
```

## Depois da aplicacao

- Reextrair `supabase/db/current/`.
- Atualizar `CHANGELOG.md` com os resultados das verificacoes.
- Atualizar `SPEC-010` para marcar o hardening como aplicado.
- Definir em etapa separada a policy de negocio para leitura/escrita dessas tabelas.
