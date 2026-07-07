---
titulo: "SPEC-017 — Modal Unificado da Aprovação Financeira em Orçamentos"
status: implementado em homologacao
data_ultima_modificacao: 2026-07-06
sistemas_envolvidos:
  - Orçamentos
---

# SPEC-017 — Modal Unificado da Aprovação Financeira em Orçamentos

> Dependência: requer a decisão da [SPEC-016](SPEC-016_Normalizacao_Aprovacao_Financeira_Orcamento.md). A aba financeira deve trabalhar por `orcamento_id`, não por `project_id`.

## Checklist de Ação

- [x] Refatorar `FinancialApprovalTab` para listar orçamentos em `Aprovação Financeira`.
- [x] Remover o fluxo visual baseado em projeto da aprovação financeira.
- [x] Fazer os botões Ver/Editar abrirem a mesma experiência usada para editar orçamento nos demais fluxos.
- [x] Reaproveitar `BudgetFormPage`/store de orçamento para edição, sem editor paralelo de projeto.
- [x] Usar `FinancialApprovalDialog` apenas como confirmação final de aprovação financeira.
- [x] Descontinuar `ProjectFinancialReviewDialog`, `FinancialApprovalEditDialog`, `ProjectOrcamentoList`, `projectFinancialApprovalService` e `financialApprovalEditService` no fluxo principal.
- [x] Garantir que salvar edição financeira não aprove o orçamento automaticamente.
- [x] Atualizar testes/QA do sistema de Orçamentos.

### Passos manuais do usuário

- [ ] Homologar com quem aprova financeiramente se a tela deve abrir em modo leitura primeiro ou direto em edição.
- [ ] Validar visualmente que o modal/tela é igual ao fluxo de edição já conhecido pelo time.

## Objetivo

Quando o Financeiro clica para ver ou editar um orçamento pendente, ele deve enxergar a mesma interface de orçamento usada nos outros lugares do sistema.

Hoje a aprovação financeira abre um fluxo diferente, baseado em projeto, com componentes próprios. Isso cria comportamento visual e técnico inconsistente com:

- editar orçamento na aprovação do cliente;
- editar orçamento criado sem aprovação do cliente;
- criar/editar orçamento normal.

## Decisões aprovadas

- A fila financeira é de orçamentos, não de projetos.
- Ver/editar na aprovação financeira deve reaproveitar o mesmo formulário/modal de orçamento.
- A aprovação final continua exigindo confirmação explícita do Financeiro.
- Editar dados financeiros do orçamento não pode, sozinho, marcar status como `Orçamento Aprovado`.
- O modal/editor financeiro paralelo deve sair do fluxo principal.

## Estado Antes da Implementação

Arquivos mapeados no app de Orçamentos antes da implementação:

| Arquivo | Uso anterior | Problema identificado |
|---|---|---|
| `src/components/budgets/ClientApprovalTab.tsx` | Edita orçamento com `navigate('/budgets/:id')` | Fluxo desejado para reaproveitar. |
| `src/pages/BudgetFormPage.tsx` | Formulário completo de criar/editar orçamento | Deve ser a base também para aprovação financeira. |
| `src/components/budgets/FinancialApprovalTab.tsx` | Lista projetos em `Aprovação Financeira` | Deveria listar orçamentos. |
| `src/components/budgets/ProjectFinancialReviewDialog.tsx` | Modal de revisão por projeto | Diverge do formulário de orçamento. |
| `src/components/budgets/FinancialApprovalEditDialog.tsx` | Editor próprio de validação financeira | Duplica regra de edição e aprova de forma paralela. |
| `src/services/projectFinancialApprovalService.ts` | Busca/aprova projeto | Não deve dirigir o fluxo de orçamento aprovado. |
| `src/services/financialApprovalEditService.ts` | Edita projeto/orçamentos e retorna status aprovado | Mistura edição com aprovação. |

## Definição da SPEC

### Experiência esperada

Na aba "Aprovação Financeira":

1. listar uma linha por orçamento com `orcamentos.status = 'Aprovação Financeira'`;
2. mostrar dados principais: emissão, empresa, projeto, cliente, arquiteto, valor, pendências;
3. botão Ver abre o orçamento na mesma interface de orçamento em modo leitura/revisão;
4. botão Editar abre o orçamento na mesma interface de edição usada por `/budgets/:id`;
5. botão Aprovar abre confirmação financeira (`FinancialApprovalDialog`) depois que o usuário revisou o orçamento;
6. confirmar chama a RPC oficial da SPEC-016 por `orcamento_id`;
7. ao voltar, a lista recarrega e o orçamento aprovado desaparece da fila.

### Componentes a preservar

- `BudgetFormPage.tsx` como superfície principal de criação/edição.
- `useBudgetStore.updateBudget` para salvar alterações.
- `FinancialApprovalDialog.tsx` como confirmação final, desde que receba um `Budget` e chame a RPC oficial.
- `budget-status.ts` como fonte de labels/badges.

### Componentes a remover do fluxo principal

Não precisam ser apagados na primeira implementação, mas não podem mais ser chamados pela aba financeira:

- `ProjectFinancialReviewDialog.tsx`
- `FinancialApprovalEditDialog.tsx`
- `ProjectOrcamentoList.tsx`
- `projectFinancialApprovalService.ts`
- `financialApprovalEditService.ts`

### Regras de edição

- Edição de orçamento em `Aprovação Financeira` continua permitida para perfil financeiro/autorizado.
- Ao salvar, o status permanece `Aprovação Financeira`.
- Campos alteráveis devem ser os mesmos do formulário normal, respeitando validações de frete, forma de pagamento, prazo e itens.
- Remover item, trocar produto ou alterar preço em orçamento financeiro pendente deve recalcular `valor_total` como no fluxo normal.
- Aprovação final deve ocorrer em ação separada.

### Permissões

Provisório:

- `admin` e `gerente` podem aprovar financeiramente.
- `operador` pode editar/ver somente se já tiver permissão no fluxo atual.

Futuro:

- substituir por permissão granular do Hub/TI quando disponível.

### Não fazer

- Não abrir modal especial de projeto para editar orçamento.
- Não aprovar por `project_id`.
- Não marcar todos os orçamentos de um projeto como aprovados ao editar um deles.
- Não duplicar lógica de cálculo fora de `BudgetFormPage`/store.

## Critérios de aceite

- [x] A aba financeira lista orçamentos, não projetos.
- [x] Ver/Editar abre a mesma interface de orçamento usada no fluxo comum.
- [x] O modal/editor antigo de validação financeira por projeto não aparece mais no fluxo principal.
- [x] Salvar edição financeira mantém status `Aprovação Financeira`.
- [x] Aprovar financeiramente exige confirmação explícita.
- [x] Aprovação final chama `aprovar_orcamento_financeiro(p_orcamento_id)`.
- [x] Aprovar um orçamento remove apenas aquele orçamento da fila.
- [x] Projeto com mais de um orçamento pendente mostra mais de uma linha, uma por orçamento.

## Testes obrigatórios

- Abrir aba financeira sem pendências: estado vazio correto.
- Criar orçamento, enviar ao cliente, aprovar cliente e confirmar que ele aparece na aba financeira.
- Clicar Ver/Editar e confirmar que o layout e campos batem com `/budgets/:id`.
- Editar item/preço/frete/pagamento e salvar; status continua `Aprovação Financeira`.
- Aprovar financeiramente e confirmar status final `Orçamento Aprovado`.
- Projeto com dois orçamentos: aprovar um não aprova o outro.
- Usuário sem permissão não consegue confirmar aprovação financeira.

## Realizado

### 2026-07-06

- SPEC criada a partir da inconsistência visual reportada pelo usuário.
- Mapeado que o fluxo financeiro atual usa projeto/modal próprio, enquanto aprovação do cliente usa edição normal do orçamento.
- Dependência de banco da SPEC-016 implementada no Supabase real: a aprovação financeira oficial agora é por `orcamento_id` e as RPCs por projeto foram descontinuadas.
- Etapa anterior não alterou frontend, conforme orientação do usuário para aguardar aceite antes de usar o MCP do Skip nos sistemas.
- Após aceite, implementado no sistema de Orçamentos local e no projeto Skip da org Lucenera (`Orçamentos Aprovação`, projeto `32554`).
- `FinancialApprovalTab` passou a listar `orcamentos.status = 'Aprovação Financeira'`, navegar para `/budgets/:id` em Ver/Editar e aprovar apenas por `orcamento_id`.
- `BudgetFormPage`, `BudgetTableRow`, `budgetApprovalService` e `useBudgetStore` foram ajustados para o contrato oficial `Aprovação Financeira -> Orçamento Aprovado`, sem chamada de aprovação financeira por projeto.
- QA técnico: `pnpm run lint`, `pnpm run build` e `skip_project_apply_changes` em modo development passaram sem erros. Versão Skip final: `0.0.273` / `dcd3442`.

## Pendências

- [ ] Validar com usuário a preferência final entre abrir em modo leitura primeiro ou edição direta.
- [ ] Homologar visualmente com o usuário no preview do Skip.
