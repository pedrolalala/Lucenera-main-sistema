---
titulo: "SPEC-167 — Campo Previsão de Entrega no orçamento"
status: pendente
data_ultima_modificacao: 2026-09-28
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb, Skip 32554)
---

# SPEC-167 — Campo Previsão de Entrega no orçamento

## Checklist de Ação

- [x] Coluna `orcamentos.previsao_entrega date` (nullable)
- [x] Formulário do orçamento: campo "Previsão de Entrega" (calendário + "Limpar") ao lado de Validade
- [x] Lista de orçamentos (abas Todos e Aprovados): coluna "Previsão Entrega"
- [ ] Publicar o Orçamentos no Skip (projectId 32554)

### Passos manuais do usuário

- [x] Autorizar a publicação no Skip (28/09)
- [ ] Aplicar e publicar no Skip 32554 (apply bloqueado pelo classificador de permissões do Claude Code — o usuário precisa rodar ou liberar)
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

## Pendências

- [ ] Publicar o Orçamentos no Skip 32554 (apply + publish) — mudanças já estão no working tree do Skip, sem commit; o `skip_project_apply_changes` foi negado pelo classificador de permissões do Claude Code em 28/09. O apply também vai registrar a remoção das 3 migrations legadas da SPEC-165.
