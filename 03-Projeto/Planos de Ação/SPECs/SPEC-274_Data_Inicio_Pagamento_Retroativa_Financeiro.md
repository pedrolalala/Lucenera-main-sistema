---
titulo: "SPEC-274 — Data de início do pagamento retroativa na Revisão Financeira Pendente"
status: publicado (falta teste em tela pelo financeiro)
data_ultima_modificacao: 2026-11-10
sistemas_envolvidos:
  - Orçamentos (04-Sistemas/gestao-financeira-clone-544cb (1)) — formulário do orçamento (BudgetFormPage.tsx)
---

# SPEC-274 — Data de início do pagamento retroativa

## Checklist de Ação
- [x] Diagnóstico: o formulário barrava data anterior a hoje (calendário desabilitado + validação ao salvar)
- [x] Conferir o banco: offset de parcela negativo é aceito
- [x] Liberar a data retroativa para quem revisa no financeiro
- [x] Typecheck sem erro em BudgetFormPage.tsx
- [x] Commit e push (Cloudflare Pages publica sozinho)
- [ ] Teste em tela pelo financeiro (data passada → aprovar → conferir vencimentos das parcelas)

## Objetivo
Na área **Revisão Financeira Pendente**, o financeiro precisa alterar a **Data de Início do Pagamento** para uma data **passada** (negócio fechado antes de entrar no sistema, pagamento já iniciado). Antes, só era possível hoje ou futuro, o que travava o fluxo.

## Causa (verificada)
- `BudgetFormPage.tsx`: `desabilitarDia` do campo `data_inicio_pagamento` bloqueava dias < hoje e o submit retornava erro "A data de início deve ser hoje ou uma data futura".
- Banco **não** barra: `aprovar_orcamento_financeiro` calcula `vencimento = data_base + dias_offset` (inteiro), e `dias_offset` negativo gera data passada. O front já calculava o offset sem limitar (`prazoPagamentoDias`).
- Única coluna com limite: `orcamentos.prazo_inicio_cobranca_dias` tem `CHECK (>= 0)`. O front já grava `Math.max(0, …)` nela; o vencimento real vem de `plano_parcelas`/`prazo_pagamento_dias`.

## Decisão
Regra de tela: quem passa em `usePodeRevisaoFinanceira` (admin, gerente **ou** acesso `financeiro`, SPEC-273) pode escolher data retroativa. Os demais (equipe/vendedor) continuam só com hoje ou futuro.

## Alterações (só front)
- `src/pages/BudgetFormPage.tsx`: calendário e validação ao salvar respeitam `podeRevisaoFinanceira`; dica "No financeiro é permitida data retroativa." no campo.

## Não muda / observações
- Sem migration. Sem mudança de RLS.
- Parcelas vencidas já nascem em atraso nos relatórios de contas a receber (esperado para retroativo).
- Datas das demais parcelas continuam com mínimo = data de início (podem ser passadas também).

## Rollback
Reverter o commit do front. Sem migration.

## Documentos atualizados
CHANGELOG.md, esta SPEC.
