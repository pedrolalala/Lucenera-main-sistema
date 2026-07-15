---
titulo: "SPEC-016 — Normalização da Aprovação Financeira de Orçamentos"
status: implementado em homologacao
data_ultima_modificacao: 2026-07-06
sistemas_envolvidos:
  - Supabase (banco central)
  - Orçamentos
  - Administração Bancária / Financeiro
  - CRM
  - Estoque
---

# SPEC-016 — Normalização da Aprovação Financeira de Orçamentos

## Checklist de Ação

- [x] Criar migration central `supabase/db/migrations/20260706_020_normalizacao_aprovacao_financeira_orcamento/`.
- [x] Definir `Aprovação Financeira` como único status intermediário depois da aprovação do cliente.
- [x] Definir `Orçamento Aprovado` como único status final depois da aprovação financeira.
- [x] Atualizar `aprovar_orcamento_financeiro(p_orcamento_id)` para aceitar apenas orçamento em `Aprovação Financeira`.
- [x] Garantir que `aprovar_orcamento_financeiro` gere itens de projeto, parcelas, boletos e reserva de estoque por `orcamento_id`, sem aprovar o projeto inteiro.
- [x] Tornar `aprovar_orcamento_financeiro_base_spec001` wrapper interno ou função obsoleta, sem contrato divergente.
- [x] Remover tolerância operacional a `aprovado_cliente`, `aprovado` e `aprovado_financeiro` como entrada de aprovação financeira.
- [x] Atualizar triggers/funções de normalização de status para não mascararem erro de fluxo.
- [x] Atualizar o frontend de Orçamentos para chamar só a RPC oficial na etapa financeira.
- [x] Atualizar `supabase/db/current/` depois da migration aplicada.

### Passos manuais do usuário

- [x] Executar a migration no Supabase real após revisão.
- [x] Homologar um orçamento real no fluxo completo: criar/enviar ao cliente, cliente aprovar, financeiro aprovar.
- [x] Confirmar com Financeiro se o status visível final deve permanecer literalmente `Orçamento Aprovado`.

## Objetivo

Corrigir a inconsistência atual em que um orçamento pode parecer aprovado antes da aprovação financeira, ou ser aprovado por funções diferentes com status finais diferentes.

A regra oficial passa a ser:

```text
rascunho / aguardando_aprovacao
  -> enviado_cliente
  -> Aprovação Financeira
  -> Orçamento Aprovado
```

O disparo para Financeiro, Administração Bancária, itens aprovados do projeto, reserva de estoque e boletos só acontece na transição `Aprovação Financeira -> Orçamento Aprovado`.

## Decisões aprovadas

- Aprovação do cliente não aprova operacionalmente o orçamento; ela apenas coloca o orçamento em `Aprovação Financeira`.
- Aprovação financeira é obrigatória para disparar geração de `projeto_itens`, `projeto_parcelas`, `boletos` e reserva agregada de estoque.
- A chave do fluxo aprovado continua sendo `orcamento_id`.
- O sistema não deve aprovar todos os orçamentos de um projeto só porque o projeto está em `Aprovação Financeira`.
- `aprovado_cliente`, `aprovado` e `aprovado_financeiro` passam a ser valores legados/compatibilidade, não estados oficiais para novas transições.

## Estado Antes da Normalização

### Banco central

Snapshot inicial de 06/07/2026 mostrava contratos concorrentes:

| Objeto | Estado atual | Problema |
|---|---|---|
| `aprovar_orcamento_cliente*` | Move para `Aprovação Financeira` | Correto para a regra nova. |
| `aprovar_orcamento_financeiro` | Aceita `Aprovação Financeira`, `aprovado` e `aprovado_cliente`; retorna `aprovado_financeiro` | Aceita atalhos e usa status final divergente. |
| `aprovar_orcamento_financeiro_base_spec001` | Exige `aprovado_cliente`/`aprovado` e escreve `aprovado` | Conflita com aprovação financeira obrigatória. |
| `aprovar_projeto_financeiro` | Aprova por `project_id` e altera projeto para `Orçamento Aprovado` | Pode aprovar escopo amplo demais quando um cliente/projeto tem mais de um orçamento. |
| `finalizar_validacao_financeira` | Edita projeto/orçamentos e marca todos do projeto como `Orçamento Aprovado` | Mistura edição com aprovação final. |
| `normalize_orcamento_status` | Converte `aprovado_financeiro` em `Orçamento Aprovado` | Esconde divergência em vez de corrigir origem. |

### Frontend de Orçamentos antes da SPEC-017

Arquivos relevantes:

- `04-Sistemas/gestao-financeira-clone-544cb (1)/src/stores/useBudgetStore.ts`
- `04-Sistemas/gestao-financeira-clone-544cb (1)/src/services/budgetApprovalService.ts`
- `04-Sistemas/gestao-financeira-clone-544cb (1)/src/services/projectFinancialApprovalService.ts`
- `04-Sistemas/gestao-financeira-clone-544cb (1)/src/services/financialApprovalEditService.ts`
- `04-Sistemas/gestao-financeira-clone-544cb (1)/src/components/budgets/BudgetTableRow.tsx`
- `04-Sistemas/gestao-financeira-clone-544cb (1)/src/components/budgets/FinancialApprovalTab.tsx`

Antes da implementação da SPEC-017, o app ainda possuía caminhos que chamavam aprovação financeira a partir de orçamento com status normalizado como `aprovado`, e outro caminho que aprovava projeto por `project_id`.

## Definição da SPEC

### Contrato oficial de status

| Etapa | Status oficial | Quem dispara | Efeito |
|---|---|---|---|
| Orçamento pronto para cliente | `enviado_cliente` | Orçamentos | Token/link de aprovação. |
| Cliente aprovou | `Aprovação Financeira` | Cliente público ou aprovação manual interna | Fila de validação financeira. |
| Financeiro aprovou | `Orçamento Aprovado` | Financeiro/admin/gerente autorizado | Gera itens, parcelas, boletos, reserva e libera integrações. |
| Cliente recusou | `recusado_cliente` | Cliente público | Permite editar e reenviar. |
| Cancelado | `cancelado` | Usuário autorizado | Reverte efeitos conforme `cancelar_orcamento`. |

Valores legados:

- `aprovado_cliente`: migrar para `Aprovação Financeira` quando ainda não tiver efeitos financeiros gerados.
- `aprovado`: migrar para `Orçamento Aprovado` apenas quando já existirem efeitos financeiros completos; caso contrário, revisar manualmente.
- `aprovado_financeiro`: normalizar para `Orçamento Aprovado`.

### RPC oficial: `aprovar_orcamento_financeiro`

Entrada:

```sql
public.aprovar_orcamento_financeiro(p_orcamento_id uuid)
```

Guards obrigatórios:

- orçamento existe e trava com `FOR UPDATE`;
- `orcamentos.status = 'Aprovação Financeira'`;
- `orcamento_id` tem projeto, empresa, cliente, itens, forma de pagamento, frete estruturado e prazo interpretável;
- não existe processamento parcial inconsistente em `projeto_itens`, `projeto_parcelas` ou `boletos` para o mesmo `orcamento_id`;
- usuário atual tem permissão financeira conforme regra provisória por `usuarios.role` até o Hub/TI substituir por permissão granular.

Efeitos obrigatórios, todos na mesma transação:

1. cria `projeto_itens` a partir de `orcamento_itens`, com `orcamento_id`;
2. cria `projeto_parcelas` com `orcamento_id`;
3. cria `boletos` com `orcamento_id`;
4. incrementa `estoque_itens.quantidade_reservada` como ponte até a SPEC-010;
5. atualiza `orcamentos.status = 'Orçamento Aprovado'`;
6. atualiza `orcamentos.requer_revisao_financeira = false`;
7. registra `historico_status_orcamentos`;
8. retorna payload com `status = 'Orçamento Aprovado'`, contadores e `ja_processado`.

Não fazer:

- não aceitar `aprovado_cliente` como entrada normal;
- não aceitar `aprovado` como entrada normal;
- não retornar `aprovado_financeiro`;
- não aprovar por `projeto_id`;
- não gerar itens/parcelas/boletos buscando por projeto inteiro.

### Funções a reconciliar

| Objeto | Decisão |
|---|---|
| `aprovar_orcamento_cliente_publico` | Manter; deve terminar em `Aprovação Financeira`. |
| `aprovar_orcamento_cliente_manual` | Manter; deve terminar em `Aprovação Financeira`. |
| `aprovar_orcamento_cliente` | Manter só se o frontend usar fluxo interno; mesmo contrato: `Aprovação Financeira`. |
| `cliente_aprovar_orcamento` / `adm_aprovar_pelo_cliente` | Deprecar ou transformar em wrappers para o contrato oficial; não podem terminar em `aprovado_cliente`. |
| `aprovar_orcamento_financeiro_base_spec001` | Reconciliar com a RPC oficial ou deixar como helper interno; não pode escrever `aprovado`. |
| `aprovar_projeto_financeiro` | Remover do fluxo de Orçamentos; se permanecer, documentar como legado e não chamar no app. |
| `finalizar_validacao_financeira` | Não pode aprovar; edição financeira deve salvar orçamento e depois chamar `aprovar_orcamento_financeiro` por `orcamento_id`. |
| `normalize_orcamento_status` | Pode normalizar legado, mas não deve esconder retorno errado da RPC. |

### Frontend

Alterações obrigatórias:

- `BudgetTableRow.tsx`: remover aprovação financeira direta de status `aprovado`; esse status não é mais etapa oficial.
- `useBudgetStore.ts`: `approveBudgetAndMigrate` e `financialApprove` devem chamar a mesma RPC oficial e esperar retorno `Orçamento Aprovado`.
- `budget-status.ts`: `aprovado` deve aparecer como legado/cliente aprovado apenas durante migração; `Aprovação Financeira` é fila financeira; `Orçamento Aprovado` é aprovado final.
- `FinancialApprovalTab.tsx`: listar orçamentos em `Aprovação Financeira`, não projetos.

### Migração de dados legados

Antes de atualizar dados em massa, gerar relatório:

```text
status atual
tem projeto_itens por orcamento_id?
tem projeto_parcelas por orcamento_id?
tem boletos por orcamento_id?
requer_revisao_financeira
```

Regras sugeridas:

- `aprovado_financeiro` -> `Orçamento Aprovado`;
- `aprovado_cliente` sem efeitos financeiros -> `Aprovação Financeira`;
- `aprovado` com efeitos completos -> `Orçamento Aprovado`;
- `aprovado` sem efeitos completos -> relatório manual antes de mudar.

## Critérios de aceite

- [x] Aprovação do cliente pública deixa o orçamento em `Aprovação Financeira` e não gera itens/parcelas/boletos.
- [x] Aprovação manual do cliente deixa o orçamento em `Aprovação Financeira` e não gera itens/parcelas/boletos.
- [x] `aprovar_orcamento_financeiro` falha se o status não for `Aprovação Financeira`.
- [x] `aprovar_orcamento_financeiro` termina com `orcamentos.status = 'Orçamento Aprovado'`.
- [x] Reexecutar `aprovar_orcamento_financeiro` em orçamento já aprovado não duplica `projeto_itens`, `projeto_parcelas`, `boletos` nem reserva.
- [x] Aprovar um orçamento de um projeto não aprova automaticamente outros orçamentos do mesmo projeto.
- [x] O frontend não exibe ação de aprovação financeira fora da fila `Aprovação Financeira`.
- [x] `historico_status_orcamentos` registra as transições `enviado_cliente -> Aprovação Financeira` e `Aprovação Financeira -> Orçamento Aprovado`.

## Testes obrigatórios

### Banco

- Testar `enviar_orcamento_cliente` em orçamento válido.
- Testar `aprovar_orcamento_cliente_publico` e confirmar ausência de itens/parcelas/boletos.
- Testar `aprovar_orcamento_financeiro` em status `Aprovação Financeira`.
- Testar bloqueio de `aprovar_orcamento_financeiro` em `enviado_cliente`, `recusado_cliente`, `aprovado_cliente`, `aprovado` e `Orçamento Aprovado`.
- Testar idempotência com orçamento que já tem efeitos completos por `orcamento_id`.
- Testar projeto com dois orçamentos: aprovar um não altera o outro.

### Frontend

- `04-Sistemas/gestao-financeira-clone-544cb (1)/src/stores/useBudgetStore.ts`: chamada única de RPC e payload final coerente.
- `04-Sistemas/gestao-financeira-clone-544cb (1)/src/components/budgets/BudgetTableRow.tsx`: não existe botão de aprovação financeira fora da fila.
- `04-Sistemas/gestao-financeira-clone-544cb (1)/src/lib/budget-status.ts`: badges distinguem cliente aprovado/financeiro pendente/aprovado final.

## Realizado

### 2026-07-06

- SPEC criada a partir da decisão do usuário de exigir aprovação financeira antes de disparar integrações.
- Inconsistência atual mapeada entre `aprovado_cliente`, `aprovado`, `Aprovação Financeira`, `aprovado_financeiro` e `Orçamento Aprovado`.
- Migration `20260706_020_normalizacao_aprovacao_financeira_orcamento` criada, validada em transação com `ROLLBACK` e aplicada no Supabase real.
- `aprovar_orcamento_financeiro(p_orcamento_id)` passou a exigir `Aprovação Financeira`, finalizar em `Orçamento Aprovado`, gerar artefatos por `orcamento_id` e não aprovar projeto inteiro.
- `aprovar_orcamento_financeiro_base_spec001` virou wrapper da RPC oficial.
- `aprovar_projeto_financeiro` e `finalizar_validacao_financeira` foram descontinuadas com erro claro para evitar aprovação por `project_id`.
- `adm_aprovar_pelo_cliente`, `cliente_aprovar_orcamento` e a família `aprovar_orcamento_cliente*` foram normalizadas para terminar em `Aprovação Financeira`.
- `cancelar_orcamento` foi ajustada para reverter efeitos também quando o status final for `Orçamento Aprovado`.
- Criada view `vw_orcamentos_aprovacao_financeira_auditoria`.
- Verificação pós-aplicação: funções/view existem; status atuais agregados são `Orçamento Aprovado` (7), `enviado_cliente` (6) e `Aprovação Financeira` (2). Backfills seguros de `aprovado_financeiro`/`aprovado_cliente` não alteraram linhas.
- Testes transacionais com `ROLLBACK`: aprovação financeira bloqueia `enviado_cliente`; `aprovar_projeto_financeiro` bloqueia por estar descontinuada.
- Após aceite, frontend implementado no sistema de Orçamentos local e no projeto Skip da org Lucenera (`Orçamentos Aprovação`, projeto `32554`).
- `FinancialApprovalTab`, `BudgetFormPage`, `BudgetTableRow`, `budgetApprovalService` e `useBudgetStore` passaram a respeitar o contrato oficial por `orcamento_id`, sem aprovação por `project_id`.
- QA técnico do sistema: `pnpm run lint`, `pnpm run build` e `skip_project_apply_changes` em modo development passaram sem erros. Versão Skip final: `0.0.273` / `dcd3442`.
- `AI_DB_CONTEXT.md` local do sistema de Orçamentos foi atualizado com o contrato oficial de status e RPCs.

## Pendências

- [x] Reextrair/atualizar `supabase/db/current/` com as novas funções/view sem sobrescrever alterações locais pendentes.
- [x] Homologar aprovação financeira real de um orçamento em `Aprovação Financeira`.
