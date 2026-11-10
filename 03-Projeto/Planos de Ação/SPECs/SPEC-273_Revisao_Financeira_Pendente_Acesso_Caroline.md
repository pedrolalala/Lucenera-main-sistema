---
titulo: "SPEC-273 — Revisão Financeira Pendente: acesso, edição e aprovação para quem trabalha no financeiro (Caroline)"
status: concluído (falta teste da Caroline em tela)
data_ultima_modificacao: 2026-11-10
sistemas_envolvidos:
  - Orçamentos (04-Sistemas/gestao-financeira-clone-544cb (1)) — aba "Revisão Financeira Pendente" e botão "Aprovar Financeiro" no orçamento
---

# SPEC-273 — Revisão Financeira Pendente para o financeiro

## Checklist de Ação
- [x] Diagnóstico: por que a Caroline não via a aba (10/11)
- [x] Hook `usePodeRevisaoFinanceira` (admin/gerente **ou** acesso `financeiro`) e troca nos 3 pontos de tela
- [x] Teste no banco real como a Caroline, em transação revertida
- [x] Commit ae17dee pushado; NO AR em financeiro-lucenera.pages.dev (deploy 17f3f563 automático do Cloudflare Pages a partir do GitHub; bundle em São Paulo e hook conferidos em produção)
- [ ] Teste da Caroline em tela (abrir a aba, editar um orçamento, aprovar e devolver)

## Objetivo
A Caroline (assistente administrativa) deve ver a aba **Revisão Financeira Pendente**, **editar** e **aprovar** o que está lá. Hoje a conta dela não via a aba.

## Causa (verificada)
- **Tela:** a aba, o botão "Ver/Editar"/"Aprovar" e o botão "Aprovar Financeiro" do orçamento só apareciam para `usuarios.role` = `admin`/`gerente`. A Caroline é `funcionario`, então caía na aba "No financeiro" (só consulta).
- **Banco:** já liberava. Como a Caroline (testado, ROLLBACK): `aprovar_orcamento_financeiro` roda completo; `financeiro_devolver_orcamento_equipe` funciona; update de `orcamento_itens` passa; `orcamentos_equipe_restrita()` é nula (vê os 371 orçamentos). Nada de banco precisou mudar.

## Decisões
- Regra nova na tela: **admin, gerente ou quem tem o acesso `financeiro`** (Acesso a Sistemas) vê a aba e aprova. Não usei `can_approve_quotes`, porque esse flag também libera aprovar nas etapas de cliente e equipe (BudgetTableRow, ClientApprovalTab), que não é o pedido.
- Quem não tem o acesso (nem é admin/gerente) continua com a aba "No financeiro" só de consulta (SPEC-272).
- Hoje têm `financeiro`: Pedro, Filippo, Vinicius, financeiro@ e Caroline. A Mariane (gerente) segue por `role`.

## Alterações (só front)
- `src/hooks/use-revisao-financeira.ts` (novo): `pode_acessar_sistema('financeiro')` via RPC.
- `src/pages/Budgets.tsx`: aba/conteúdo "Revisão Financeira Pendente" x "No financeiro".
- `src/components/budgets/FinancialApprovalTab.tsx`: `canManage` (aprovar, devolver à equipe).
- `src/pages/BudgetFormPage.tsx`: botão "Aprovar Financeiro".

## Não muda / observações
- `financeiro_editar_orcamento` (função do banco) segue só para admin/gerente/operador: as telas que a usam (`FinancialApprovalEditDialog`) não estão ligadas a nenhuma rota. O "Ver/Editar" abre o formulário normal, que a Caroline já edita.
- Editar o **valor do produto** no orçamento continua só para admin (`canEditValorProduto`), como já era.
- A função `aprovar_orcamento_financeiro` libera por `hub_pode_executar('orcamentos','aprovar')`, que também é verdadeiro para outros papéis (ex.: `funcionario`): quem trava hoje é só a tela. Fora do escopo; vale uma revisão de segurança à parte.

## Rollback
Reverter o commit do front (3 arquivos + hook). Sem migration.

## Pendências
- Atenção: o Cloudflare Pages deste sistema publica sozinho a cada push no GitHub (a partir do commit, não do working tree). O repositório ainda tem alterações soltas de outras sessões em `App.tsx`, `Login.tsx` e `devolucoesService.ts` e um `public/_headers` não versionado; quando forem commitadas e pushadas, vão ao ar sozinhas.
- [ ] Teste da Caroline em tela.
