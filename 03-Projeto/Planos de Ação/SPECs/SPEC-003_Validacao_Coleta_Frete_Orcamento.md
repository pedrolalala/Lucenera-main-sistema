---
titulo: "SPEC-003 — Validação e Coleta de Frete no Orçamento"
status: parcial
data_ultima_modificacao: 2026-06-26
sistemas_envolvidos:
  - Orçamentos
  - Administração Bancária / Financeiro
  - Supabase / Banco
---

# SPEC-003 — Validação e Coleta de Frete no Orçamento

## Checklist de Ação

- [x] Definir os valores persistidos de `orcamentos.frete_tipo` para "Com Frete" e "Sem Frete" (`com_frete` / `sem_frete`).
- [x] Criar migration com regra validável para `frete_tipo` e `frete_valor`.
- [x] Adicionar captura de frete em `BudgetFormPage.tsx`, com campo sempre visível.
- [x] Persistir `frete_tipo` e `frete_valor` ao criar/editar orçamento e pré-carregar os campos na edição.
- [x] Atualizar `useBudgetStore.ts` (`src/lib/supabase/types.ts` já tinha os campos desde a SPEC-001).
- [x] Validar frete em `aprovar_orcamento_financeiro_base_spec001` antes de alterar status ou gerar itens/parcelas/boletos.
- [x] Adicionar mensagens amigáveis no fluxo de aprovação/sincronização quando o orçamento não tiver frete estruturado.
- [x] Rodar build/type-check do sistema de Orçamentos.
- [x] Aplicar a migration no banco remoto compartilhado.

### Passos manuais do usuário

- [x] Reextrair `supabase/db/current/01_schema_full.sql` após aplicar a migration.
- [x] Homologar pelo menos um orçamento "Com Frete" e um orçamento "Sem Frete" contra a regra usada no Connect.
- [x] Editar orçamentos antigos sem frete estruturado antes de tentar aprová-los.

## Objetivo

A SPEC-001 exige que o frete seja conferido antes de transformar um orçamento em itens do projeto, parcelas e boletos. O banco já possui `orcamentos.frete_tipo` e `orcamentos.frete_valor`, mas o sistema de Orçamentos não captura esses campos e a RPC `aprovar_orcamento_financeiro` não os lê nem valida.

Esta SPEC fecha essa lacuna: todo orçamento deve registrar se é "Com Frete" ou "Sem Frete" e a aprovação deve bloquear qualquer orçamento sem frete estruturado.

## Decisões aprovadas

- Frete é dado estruturado do orçamento, não observação livre.
- O usuário deve escolher "Com Frete" ou "Sem Frete" antes de salvar o orçamento.
- A RPC deve validar frete no banco; validação apenas no frontend não é suficiente.
- Orçamentos antigos sem frete estruturado continuam bloqueados na aprovação até edição manual.
- O valor de frete deve ficar coerente com o tipo escolhido: "Sem Frete" não deve carregar valor positivo; "Com Frete" deve ter valor informado, salvo se uma exceção operacional futura criar um tipo específico de frete incluso.

## Definição da SPEC

### Estado atual verificado

| Evidência | Situação |
|---|---|
| `supabase/db/current/01_schema_full.sql` | `orcamentos` possui `frete_tipo text` e `frete_valor numeric(12,2) DEFAULT 0`. |
| `Sistema/gestao-financeira-clone-544cb (1)/src/lib/supabase/types.ts` | Tipos gerados já expõem `frete_tipo` e `frete_valor`. |
| `Sistema/gestao-financeira-clone-544cb (1)/src/pages/BudgetFormPage.tsx` | Formulário, `formSchema`, `defaultValues`, `form.reset` e `payload` não possuem frete. |
| `supabase/db/current/01_schema_full.sql` | `aprovar_orcamento_financeiro_base_spec001` valida prazo, forma de pagamento, itens e valor total, mas não valida `frete_tipo` nem `frete_valor`. |

### Regra de frete

- `frete_tipo` deve ser obrigatório para aprovação.
- A UI pode exibir os rótulos "Com Frete" e "Sem Frete", mas o banco deve usar valores normalizados.
- Se `frete_tipo = sem_frete`, gravar `frete_valor = 0`.
- Se `frete_tipo = com_frete`, exigir `frete_valor > 0`.
- Se a operação precisar representar "frete incluso", isso deve virar valor/tipo explícito antes da implementação, não uma exceção silenciosa.

### Alterações no banco

- Adicionar constraint de domínio para os valores aceitos em `orcamentos.frete_tipo`.
- Adicionar constraint de coerência entre `frete_tipo` e `frete_valor`.
- Atualizar `aprovar_orcamento_financeiro_base_spec001` para validar frete antes do `UPDATE public.orcamentos SET status = 'aprovado'`.
- Retornar erro claro, por exemplo: `Orçamento % não possui frete estruturado. Edite o orçamento e informe "Com Frete" ou "Sem Frete".`

### Alterações no sistema de Orçamentos

| Arquivo | Mudança |
|---|---|
| `Sistema/gestao-financeira-clone-544cb (1)/src/pages/BudgetFormPage.tsx` | Incluir campos de frete no schema, defaults, edição, payload e UI. |
| `Sistema/gestao-financeira-clone-544cb (1)/src/stores/useBudgetStore.ts` | Garantir que a interface `Budget` carregue e envie `frete_tipo` e `frete_valor`. |
| `Sistema/gestao-financeira-clone-544cb (1)/src/components/budgets/BudgetTableRow.tsx` | Bloquear aprovação localmente com mensagem amigável quando o orçamento não tiver frete interpretável. |
| `Sistema/gestao-financeira-clone-544cb (1)/src/components/budgets/ApprovalsTab.tsx` | Na sincronização em massa, pular orçamentos sem frete e reportar quantos foram pulados. |

### Critérios de aceite

- Orçamento "Sem Frete" salva `frete_tipo = sem_frete`, `frete_valor = 0` e aprova com sucesso quando os demais campos estão válidos.
- Orçamento "Com Frete" com `frete_valor > 0` salva os dois campos e aprova com sucesso quando os demais campos estão válidos.
- Orçamento "Com Frete" sem valor positivo não pode ser salvo ou aprovado.
- Orçamento sem `frete_tipo` não pode ser aprovado pela RPC, mesmo que a UI tenha sido contornada.
- A sincronização em massa não aborta o lote inteiro por um orçamento sem frete; ela pula o orçamento inválido e informa o usuário.

## Realizado

### 2026-06-25

- Migration `20260625200000_spec003_validacao_frete.sql` criada e aplicada no banco remoto: constraints `orcamentos_frete_tipo_check` (domínio `com_frete`/`sem_frete`) e `orcamentos_frete_coerencia_check` (sem_frete ⇒ valor 0; com_frete ⇒ valor > 0). Confirmado: todos os 8 orçamentos existentes tinham `frete_tipo` nulo e `frete_valor = 0`, então a constraint não quebrou dados atuais.
- `aprovar_orcamento_financeiro_base_spec001` passou a validar `frete_tipo IS NOT NULL` antes de aprovar, com a mensagem combinada na SPEC.
- Campo "Frete" (Select Com Frete/Sem Frete) e "Valor do Frete" (condicional) implementados em `BudgetFormPage.tsx`, com `superRefine` exigindo valor > 0 quando "Com Frete".
- `useBudgetStore.ts` atualizado com `frete_tipo`/`frete_valor` na interface `Budget`.
- Aviso amigável adicionado em `BudgetTableRow.tsx` (aprovar/sincronizar) e `ApprovalsTab.tsx` (sincronização em massa, conta separada de "sem frete").
- Build e type-check do sistema de Orçamentos executados com sucesso.

### 2026-06-26

- Confirmado que o snapshot central de 2026-06-25 já reflete `frete_tipo`, `frete_valor` e as constraints de coerência.
- Confirmado que a SPEC-005 removeu os triggers legados que ainda bloqueavam a aprovação mesmo com frete válido.

## Pendências

- [x] Homologar pelo menos um orçamento real "Com Frete" e um "Sem Frete" contra a regra usada no Connect antes de considerar esta SPEC totalmente fechada.
- [x] Orçamentos existentes (todos sem frete estruturado hoje) precisam ser editados manualmente antes de serem aprovados.
