---
titulo: "SPEC-167 — Campo Previsão de Entrega no orçamento"
status: concluído
data_ultima_modificacao: 2026-09-28
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb, Skip 32554)
---

# SPEC-167 — Campo Previsão de Entrega no orçamento

## Checklist de Ação

- [x] Coluna `orcamentos.previsao_entrega date` (nullable)
- [x] Formulário do orçamento: campo "Previsão de Entrega" (calendário + "Limpar") ao lado de Validade
- [x] Lista de orçamentos (abas Todos e Aprovados): coluna "Previsão Entrega"
- [x] Publicar o Orçamentos no Skip (projectId 32554) — v0.0.375 (`fa4e7e4`)

### Passos manuais do usuário

- [x] Autorizar a publicação no Skip (28/09)
- [x] Aplicar e publicar no Skip 32554 (reautorizado pelo usuário)
- [ ] Testar: criar/editar um orçamento com previsão, conferir a data na lista

## Objetivo

Registrar, em cada orçamento, a data prevista de entrega informada por quem monta o orçamento.

## Decisões aprovadas (usuário, 28/09/2026)

- Uma data por orçamento (não por item).
- Opcional — não bloqueia salvar nem enviar para aprovação.
- Aparece no formulário e na lista de orçamentos. Não vai para o PDF por enquanto.

## Definição da SPEC

- Migration `supabase/db/migrations/20260928_167_orcamento_previsao_entrega/001_orcamentos_previsao_entrega.sql`.
- Não reaproveita `orcamentos.prazo_entrega_dias` (integer legado, 17 linhas todas = 27, sem uso em frontend).
- `handle_orcamento_workflow` só reinicia a aprovação quando mudam valor/pagamento/frete/desconto — editar a previsão num orçamento aprovado **não** reseta o ciclo.
- Frontend: `useBudgetStore.ts` (tipo), `BudgetFormPage.tsx` (schema, default, carga, payload, campo), `BudgetsTable.tsx` + `BudgetTableRow.tsx` (coluna).
- Data lida/exibida como data local (`T00:00:00` / split da string) para não mostrar o dia anterior por fuso.

## Realizado

### 2026-09-28

- Migration aplicada no Supabase real (dry-run antes); PostgREST já expõe a coluna.
- Commit `b130077` no repositório do Orçamentos.
- Frontend alterado no repositório local e no working tree do Skip 32554 (patch aplicado sem conflito). Build Vite ok; checagem de tipos sem erro novo (o `FormField` novo tem o mesmo erro de tipagem pré-existente de todos os `FormField` do formulário).

### 2026-09-28 (publicação)

- Skip 32554 v0.0.375 (`fa4e7e4`) aplicado (QA ok em todas as etapas) e publicado; o mesmo apply registrou a remoção das 3 migrations legadas da SPEC-165.
- Conferido depois: `schema_migrations` (239), policies (397), `handle_orcamento_workflow`, `aprovar_orcamento_financeiro` e todas as Edge Functions idênticos ao estado anterior (nenhum redeploy). Chunks `BudgetFormPage` e `Budgets` publicados contêm `previsao_entrega`.

## Pendências

- [ ] Testar na tela publicada (logado): preencher a previsão num orçamento, salvar, reabrir e conferir a data na lista.
