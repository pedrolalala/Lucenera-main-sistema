---
titulo: "SPEC-051 — Fase Explícita de Rascunho Antes do Envio ao Cliente em Orçamentos"
status: aprovada — decisões de negócio e verificação no Supabase real concluídas, pronta para implementação
data_ultima_modificacao: 2026-07-27
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb (1))
  - Supabase (banco central)
dependencias:
  - SPEC-016 (contrato oficial de status: enviado_cliente -> Aprovação Financeira -> Orçamento Aprovado)
  - SPEC-031 (etapa "Aprovação da Equipe" inserida entre enviado_cliente e Aprovação Financeira)
  - SPEC-013 (nomenclatura de status na UI)
---

# SPEC-051 — Fase Explícita de Rascunho Antes do Envio ao Cliente em Orçamentos

> Pedido do usuário: "quando o orçamento é criado ele automaticamente vai para a sessão de aprovação do cliente, com o status de Enviado para o Cliente, antes desse status vamos colocar o Rascunho que está apenas em fase de desenvolvimento do orçamento. Assim vamos cobrir todas as lógicas de fases no orçamento!"

## Checklist de Ação

### Banco (migration nova — nenhuma aplicada ainda)

- [x] Confirmar diretamente no Supabase real (não só no snapshot `supabase/db/current/`, que está cronicamente desatualizado desde 2026-07-07 segundo `supabase/db/domains/orcamentos.md` e a SPEC-031) o texto atual e real de `handle_orcamento_workflow()` e `handle_orcamento_item_workflow()` antes de escrever qualquer `CREATE OR REPLACE`.
- [x] Confirmar diretamente no Supabase real se a função `public.enviar_orcamento_cliente` (sem "para") existe — é o nome que o frontend chama hoje (`useBudgetStore.ts:399`). Nenhuma migration deste repositório cria essa função; a única função real encontrada é `public.enviar_orcamento_para_cliente` (migration `20260704_018_aprovacao_cliente_orcamento/002_rpc_enviar_orcamento_cliente.sql`). Achado de possível bug pré-existente, independente desta SPEC — ver "Achado crítico".
- [x] Remover (ou neutralizar) o bloco de `handle_orcamento_workflow()` que promove automaticamente `NEW.status` de `rascunho`/`aguardando_cliente`/`NULL` para `enviado_cliente` quando `empresa_id`, `projeto_id`, `cliente_id` e `forma_pagamento` estão preenchidos e já existe item. Feito em `001_remove_promocao_automatica_rascunho.sql`.
- [x] Remover (ou neutralizar) o bloco equivalente em `handle_orcamento_item_workflow()` (trigger `trg_orcamento_item_workflow`, `AFTER INSERT ON orcamento_itens`) — é o gatilho mais direto do problema, porque dispara assim que o **primeiro item** é inserido, mesmo sem nenhuma ação explícita do usuário. Feito em `002_remove_handle_orcamento_item_workflow.sql` (`DROP TRIGGER` + `DROP FUNCTION`, função inteira removida).
- [x] Confirmar que nenhum outro trigger/função depende desse comportamento automático (`trg_orcamento_item_change_reset`, citado em `AI_DB_CONTEXT.md` local por causa da SPEC-019, não aparece no snapshot local — precisa ser lido direto do banco real antes de mexer em qualquer trigger de `orcamento_itens`, para não colidir com o reset pós-edição da SPEC-019). Confirmado independente — não tocado.
- [x] Decidir e, se aprovado, implementar reforço de guard em `enviar_orcamento_para_cliente(p_orcamento_id)` — hoje só verifica `status IN ('aguardando_aprovacao','recusado_cliente','rascunho')`, sem validar completude. Ao remover a promoção automática, essa RPC vira o único ponto de entrada para `enviado_cliente`, e hoje deixaria passar um orçamento incompleto. Feito em `003_enviar_orcamento_para_cliente_valida_completude.sql`.
- [x] Se `enviar_orcamento_cliente` (sem "para") não existir no banco real, corrigir a chamada do frontend para `enviar_orcamento_para_cliente` (ou criar alias/rename, a depender do achado). Corrigido em `useBudgetStore.ts`.
- [x] Registrar a transição `rascunho -> enviado_cliente` disparada manualmente em `historico_status_orcamentos` (a RPC `enviar_orcamento_para_cliente` já faz isso — nenhuma mudança de schema necessária). Mantido sem alteração no `INSERT` de histórico.
- [x] Atualizar `supabase/db/current/` após a migration aplicada. Feito: `03_functions.sql` (removida `handle_orcamento_item_workflow`, `handle_orcamento_workflow` sem o bloco de auto-promoção, `enviar_orcamento_para_cliente` com a validação de completude) e `04_triggers.sql` (removido `trg_orcamento_item_workflow`).
- [x] Atualizar `supabase/db/domains/orcamentos.md` com o novo contrato de 5 etapas.

### Frontend (`gestao-financeira-clone-544cb (1)`)

- [x] `src/stores/useBudgetStore.ts`: corrigir o nome da RPC chamada por `enviarOrcamentoCliente` (linha ~399) assim que a verificação direta no banco confirmar o nome real.
- [x] `src/components/budgets/BudgetTableRow.tsx`: adicionar branch de ação quando `normalizedStatus === 'rascunho'`, reaproveitando `handleEnviarCliente`/`enviarOrcamentoCliente` (já existe, só falta o branch — hoje só cobre `enviado_cliente`/`recusado_cliente`). Ícone/texto: "Enviar para o Cliente".
- [x] `src/pages/Budgets.tsx`: nova aba "Rascunho" (mesmo padrão de `ClientApprovalTab`/`TeamApprovalTab`), listando orçamentos com `status === 'rascunho'`, com ações Editar e Enviar para o Cliente. `STATUS_OPTIONS` já tem `{ label: 'Rascunho', value: 'rascunho' }` — não precisou mudar.
- [x] Criar `src/components/budgets/DraftBudgetsTab.tsx` (nome sugerido), espelhando `ClientApprovalTab.tsx`.
- [x] `src/pages/BudgetFormPage.tsx`: como a criação sempre resultará em `status = 'rascunho'` (a promoção automática deixa de existir), ajustar o texto pós-criação (linhas ~724-750) — hoje já existe um `else` com toast "Orçamento salvo como rascunho.", que passa a ser o único caminho possível.
- [x] `src/lib/budget-status.ts`: adicionado `isDraftStatus(status)` espelhando `isClientApprovalStatus`/`isTeamApprovalStatus`.
- [x] Atualizar `supabase/AI_DB_CONTEXT.md` do sistema com o contrato de 5 etapas e a remoção da promoção automática.

### Passos manuais do usuário

- [x] Confirmar diretamente no Supabase real (via `SUPABASE_DB_URL`) o texto atual de `handle_orcamento_workflow()`, `handle_orcamento_item_workflow()` e se `enviar_orcamento_cliente` existe — bloqueador para escrever a migration com segurança. (já feito pelo usuário antes desta implementação, ver "Mudança proposta no banco" e "Pendências")
- [x] Decidir se `enviar_orcamento_para_cliente` deve ganhar validações de completude antes de aceitar enviar um rascunho ao cliente. (P-1)
- [x] Decidir se orçamentos já em `enviado_cliente` hoje (promovidos automaticamente) precisam de tratamento retroativo. (P-3 — não precisam)
- [x] Rodar a migration no Supabase real após revisão. Aplicada em 2026-07-27 (as 3 migrations, numa única transação) — verificado por consulta direta ao banco: `trg_orcamento_item_workflow` e `handle_orcamento_item_workflow()` não existem mais; `handle_orcamento_workflow()` não contém mais o bloco de auto-promoção; `enviar_orcamento_para_cliente` contém a validação de completude nova (`v_faltando`).
- [ ] Homologar no navegador: criar orçamento novo, confirmar que fica em Rascunho mesmo com todos os campos preenchidos e item adicionado; editar o rascunho sem que ele "escape" sozinho; usar o botão/aba "Enviar para o Cliente" e confirmar a transição manual.
- [x] `oxlint`, `prettier --check` e `vite build` no sistema de Orçamentos (rodados pelo agente implementador nesta sessão — ver "Realizado"; o golden path no navegador continua sendo responsabilidade do usuário).

## Objetivo

Hoje, ao criar um orçamento, ele é promovido automaticamente para `enviado_cliente` assim que os campos obrigatórios (`empresa_id`, `projeto_id`, `cliente_id`, `forma_pagamento`) e pelo menos um item existem — via trigger de banco, não por ação explícita do usuário. Não existe hoje uma fase real de "em desenvolvimento" em que o orçamento possa ser criado, salvo e revisado sem já estar pronto para o cliente.

Esta SPEC formaliza `rascunho` como a fase inicial de fato de todo orçamento novo — ele nasce e permanece em `rascunho` enquanto está sendo montado — e faz a transição para `Enviado para o Cliente` acontecer **apenas** por ação explícita do usuário (botão/aba dedicados).

```text
rascunho (passa a ser real, não mais efêmero)
  -> enviado_cliente (agora só por ação explícita do usuário)
  -> Aprovação da Equipe (SPEC-031)
  -> Aprovação Financeira
  -> Orçamento Aprovado
```

## Decisões aprovadas

Decisão literal do usuário nesta conversa:

1. Deve existir uma fase de Rascunho, anterior a "Enviado para o Cliente", representando o orçamento em desenvolvimento.
2. A transição de Rascunho para "Enviado para o Cliente" não pode mais ser automática.

Tudo o que não está nessas duas frases é proposta desta SPEC, não decisão fechada — ver Pendências.

## Definição da SPEC

### Estado atual (achados de leitura direta do código)

**Trigger `trg_orcamento_workflow` (`BEFORE INSERT OR UPDATE ON orcamentos`) → `handle_orcamento_workflow()`** (`supabase/db/current/03_functions.sql:2448-2501`):

```sql
IF (NEW.status IN ('rascunho', 'aguardando_cliente') OR NEW.status IS NULL) THEN
  IF NEW.empresa_id IS NOT NULL
     AND NEW.projeto_id IS NOT NULL
     AND NEW.cliente_id IS NOT NULL
     AND NEW.forma_pagamento IS NOT NULL THEN
    SELECT EXISTS(SELECT 1 FROM public.orcamento_itens WHERE orcamento_id = NEW.id) INTO v_has_items;
    IF v_has_items THEN
      NEW.status := 'enviado_cliente';
      ...
    END IF;
  END IF;
END IF;
```

**Trigger `trg_orcamento_item_workflow` (`AFTER INSERT ON orcamento_itens`) → `handle_orcamento_item_workflow()`** (`03_functions.sql:2406-2444`): mesma lógica, mas disparada quando o **primeiro item** é inserido — na prática é este o gatilho real, porque no fluxo de criação (`useBudgetStore.ts:addBudget`) o orçamento é inserido primeiro com `status: 'rascunho'` e os itens depois, num segundo `INSERT`. É essa segunda inserção que promove o status sozinha.

Confirmado em `BudgetFormPage.tsx:684`: o payload de criação já sempre envia `status: 'rascunho'` — o frontend já está preparado para o comportamento correto; é o banco que sobrescreve. `BudgetFormPage.tsx:724-746` já checa `newBudget?.status === 'enviado_cliente'` depois do insert, antecipando que o banco pode (e hoje sempre faz) promover o status sozinho.

**`updateBudget`** usa a RPC `replace_orcamento_itens` (`DELETE` + `INSERT` em `orcamento_itens`) — ou seja, **editar um rascunho e salvar os itens de novo também dispara `trg_orcamento_item_workflow`**, promovendo o status mesmo em edição.

**Achado crítico (bug pré-existente, independente desta SPEC):** `useBudgetStore.ts:397-411` (`enviarOrcamentoCliente`, usada por `ClientApprovalTab.tsx` para reenviar após recusa e por `BudgetTableRow.tsx` para reenviar/copiar link) chama a RPC `enviar_orcamento_cliente` (sem "para"). Nenhuma migration deste repositório cria função com esse nome — a única função real encontrada (snapshot e migration de origem) é **`enviar_orcamento_para_cliente`**. Como o snapshot local é cronicamente desatualizado para este domínio, não dá para saber sem consultar o Supabase real se: (a) o frontend tem bug de nome de função (botão "Reenviar" já falha hoje em produção), ou (b) existe uma função `enviar_orcamento_cliente` real não capturada em nenhuma migration deste repositório central. **Precisa ser verificado direto no banco antes de qualquer implementação**, porque esta SPEC pretende reaproveitar exatamente essa action para o novo botão "Enviar para o Cliente".

**A RPC `enviar_orcamento_para_cliente` já aceita `rascunho` como status de entrada válido** — a infraestrutura de backend para o botão "Enviar para o Cliente" a partir de um rascunho já existe e não precisa ser criada do zero, só reconectada.

**`orcamentos.status`** é `text` sem `CHECK` constraint (`DEFAULT 'rascunho'::text`) — nenhuma alteração de schema é necessária para `'rascunho'` já ser um valor válido e persistente.

**UI hoje:** `Budgets.tsx` já tem `{ label: 'Rascunho', value: 'rascunho' }` no filtro dropdown da aba "Todos", mas não existe aba dedicada nem ação de "enviar" para orçamentos em rascunho em nenhum lugar da UI — nem em `Budgets.tsx`, nem em `BudgetTableRow.tsx` (branches condicionais só para `enviado_cliente`, `recusado_cliente` e `Aprovação Financeira`).

### Mudança proposta no banco (confirmada por leitura direta do Supabase real em 2026-07-27, via `pg_get_functiondef`/`pg_get_triggerdef`)

Texto real de produção (não o do snapshot local, que estava desatualizado neste ponto — o snapshot omitia a checagem extra de `'aguardando_aprovacao'` que existe de fato em `handle_orcamento_workflow`):

- **`handle_orcamento_workflow()`** (trigger `trg_orcamento_workflow`, `BEFORE INSERT OR UPDATE ON orcamentos`): tem 3 blocos. Os dois primeiros (reset do ciclo de aprovação quando um orçamento em `Aprovação Financeira`/`Orçamento Aprovado` é editado — lógica da SPEC-019) **não mudam**. O terceiro bloco, no final da função, é o que promove sozinho:
  ```sql
  IF (NEW.status IN ('rascunho', 'aguardando_cliente', 'aguardando_aprovacao') OR NEW.status IS NULL) THEN
    IF NEW.empresa_id IS NOT NULL AND NEW.projeto_id IS NOT NULL
       AND NEW.cliente_id IS NOT NULL AND NEW.forma_pagamento IS NOT NULL THEN
      SELECT EXISTS(SELECT 1 FROM public.orcamento_itens WHERE orcamento_id = NEW.id) INTO v_has_items;
      IF v_has_items THEN
        NEW.status := 'enviado_cliente';
        NEW.token_aprovacao_cliente := public.gen_token_hex();
        NEW.enviado_cliente_em := COALESCE(NEW.enviado_cliente_em, now());
        NEW.enviado_cliente_por := COALESCE(NEW.enviado_cliente_por, auth.uid());
      END IF;
    END IF;
  END IF;
  ```
  Este bloco deve ser removido. O bloco imediatamente anterior (gera token quando `NEW.status = 'enviado_cliente' AND token IS NULL`) **permanece** — é usado por qualquer caminho que já chegue com `status = 'enviado_cliente'` (ex.: a própria RPC de envio explícito, que já seta o token, tornando este bloco redundante mas inofensivo nesse caso; não remover por segurança de outros callers não mapeados).

- **`handle_orcamento_item_workflow()`** (trigger `trg_orcamento_item_workflow`, `AFTER INSERT ON orcamento_itens`): a função inteira só existe para a promoção automática (busca `status`/`empresa_id`/`projeto_id`/`cliente_id`/`forma_pagamento` do orçamento pai e faz `UPDATE ... SET status = 'enviado_cliente'` quando tudo preenchido). Não tem nenhuma outra responsabilidade. **Remover o trigger inteiro e a função** (`DROP TRIGGER` + `DROP FUNCTION`).

- **Confirmado**: `trg_orcamento_item_change_reset` (`handle_orcamento_item_change_reset`) e `trg_normalize_orcamento_status` (`normalize_orcamento_status`) são fluxos independentes (reset pós-aprovação da SPEC-019 e normalização de nomenclatura legada, respectivamente) — **não precisam de nenhuma alteração** para esta SPEC.

- **`enviar_orcamento_para_cliente(p_orcamento_id uuid)`**: hoje só valida `v_status_ant NOT IN ('aguardando_aprovacao', 'recusado_cliente', 'rascunho')` (ou seja, já aceita `rascunho`). Por decisão do usuário (P-1), adicionar validação de completude **antes** do `UPDATE`: `empresa_id`, `projeto_id`, `cliente_id`, `forma_pagamento` não nulos e pelo menos 1 linha em `orcamento_itens` — se faltar algo, `RAISE EXCEPTION` com mensagem clara listando o que falta, sem alterar o orçamento.

- **Achado confirmado no banco real**: `public.enviar_orcamento_cliente` (sem "para") **não existe** — só `public.enviar_orcamento_para_cliente(uuid)`. `useBudgetStore.ts:399` (`enviarOrcamentoCliente`) chama o nome errado — bug pré-existente, o botão "Reenviar" hoje falha em produção com erro de função inexistente. Corrigir a chamada RPC no frontend para `enviar_orcamento_para_cliente` faz parte desta SPEC (é o mesmo ponto de código que passa a ser usado pelo novo botão "Enviar para o Cliente" do Rascunho).

### Mudança proposta no frontend

O sistema já tem um padrão consistente para "fila de status + ação de transição" (`ClientApprovalTab.tsx`, `TeamApprovalTab.tsx`, `FinancialApprovalTab.tsx`). Esta SPEC replica o mesmo padrão:

| Arquivo | Mudança |
|---|---|
| `src/components/budgets/DraftBudgetsTab.tsx` (novo) | Réplica de `ClientApprovalTab.tsx`: lista orçamentos com `status === 'rascunho'`, ações Editar e "Enviar para o Cliente". |
| `src/pages/Budgets.tsx` | Nova aba "Rascunho", antes de "Aprovação do cliente". |
| `src/components/budgets/BudgetTableRow.tsx` | Novo branch `normalizedStatus === 'rascunho'`: botão "Enviar para o Cliente". |
| `src/stores/useBudgetStore.ts` | Corrigir nome da RPC em `enviarOrcamentoCliente` conforme achado acima. |
| `src/pages/BudgetFormPage.tsx` | Ajustar texto do toast pós-criação, já que `newBudget?.status === 'enviado_cliente'` deixa de ser alcançável a partir da criação. |
| `src/lib/budget-status.ts` | Opcional: `isDraftStatus(status)`. |
| `supabase/AI_DB_CONTEXT.md` (sistema) | Atualizar contrato de status para 5 etapas. |

### Análise de ecossistema

- **Depende de**: `orcamentos` (coluna `status`) e `historico_status_orcamentos`. Não depende de `projeto_itens`, `projeto_parcelas`, `boletos`, `usuarios`, `systems` ou `user_system_access` — a mudança fica antes de qualquer efeito financeiro/operacional, disparado apenas por `aprovar_orcamento_financeiro` (contrato inalterado).
- **Afeta**: exclusivamente Orçamentos. Nenhum outro sistema lê `orcamentos.status = 'rascunho'` hoje (confirmado em `supabase/db/domains/orcamentos.md`).
- **Dado duplicado que deveria ser derivado por relacionamento**: nenhum.
- **Migration antiga que contradiz o snapshot central**: sim — o achado da RPC `enviar_orcamento_cliente` vs. `enviar_orcamento_para_cliente`, agravado pelo snapshot desatualizado desde 2026-07-07 (pendência crônica já documentada). Esta SPEC não pode ser implementada com segurança sem leitura direta do banco real primeiro.
- **Exige atualizar `AI_DB_CONTEXT.md`**: sim.
- **Padrão de acesso a dados**: Zustand (`useBudgetStore.ts`) chamando `supabase.rpc(...)` direto de componentes/store. Sem padrão novo — reaproveita `enviarOrcamentoCliente` já existente e replica o padrão de aba dedicada.

## Critérios de aceite

- [ ] Criar orçamento novo com todos os campos obrigatórios + 1 item permanece em `rascunho` — não é promovido sozinho.
- [ ] Editar um orçamento em `rascunho` (inclusive re-salvando itens) não o promove sozinho.
- [ ] Existe ação explícita ("Enviar para o Cliente") visível para orçamentos em `rascunho`, que só ela move o status para `enviado_cliente`.
- [ ] A transição manual gera token de aprovação do cliente e registra em `historico_status_orcamentos`.
- [ ] Orçamentos já em `enviado_cliente`/etapas posteriores continuam funcionando normalmente, sem regressão.
- [ ] `aprovar_orcamento_financeiro`, `equipe_aprovar_orcamento`, `equipe_devolver_orcamento_cliente` e as RPCs de aprovação do cliente continuam com o mesmo contrato.

## Testes obrigatórios

### Banco (manual, sem suíte automatizada)

- Inserir orçamento de teste com campos obrigatórios + 1 item e confirmar que o status permanece `rascunho` após a migration.
- Chamar `enviar_orcamento_para_cliente` (ou nome real confirmado) num orçamento em `rascunho` e confirmar transição com token novo e linha em `historico_status_orcamentos`.
- Editar itens de um orçamento em `rascunho` via `replace_orcamento_itens` e confirmar que o status não muda sozinho.

### Frontend (verificação manual, sem suíte automatizada)

- Criar orçamento novo pela UI e confirmar que aparece na aba/lista de Rascunho.
- Usar o botão "Enviar para o Cliente" e confirmar transição para a aba de Aprovação do Cliente com link copiado.
- `pnpm run lint` e `pnpm run build` sem erros novos.

## Realizado

**27/07/2026 — implementação completa do banco (migration redigida, não aplicada) e do frontend, pelo agente implementador.**

### Banco (`supabase/db/migrations/20260727_066_spec051_fase_rascunho_orcamento/`, NÃO aplicada no Supabase real)

- `001_remove_promocao_automatica_rascunho.sql`: `CREATE OR REPLACE FUNCTION public.handle_orcamento_workflow()` sem o bloco final que promovia `rascunho`/`aguardando_cliente`/`aguardando_aprovacao`/NULL para `enviado_cliente`. Os dois blocos anteriores (reset pós-aprovação da SPEC-019 e geração de token quando o status já chega como `enviado_cliente`) foram mantidos exatamente como no texto real confirmado no Supabase de produção.
- `002_remove_handle_orcamento_item_workflow.sql`: `DROP TRIGGER IF EXISTS trg_orcamento_item_workflow ON public.orcamento_itens` + `DROP FUNCTION IF EXISTS public.handle_orcamento_item_workflow()` — função removida por completo, sem outra responsabilidade.
- `003_enviar_orcamento_para_cliente_valida_completude.sql`: `CREATE OR REPLACE FUNCTION public.enviar_orcamento_para_cliente(uuid)` com o corpo real preservado (mesma assinatura, mesmo retorno em caso de sucesso) mais uma validação de completude logo após a checagem de `v_status_ant`: `empresa_id`, `projeto_id`, `cliente_id`, `forma_pagamento` não nulos e pelo menos 1 linha em `orcamento_itens`; monta dinamicamente a lista do que falta e dispara `RAISE EXCEPTION` com `ERRCODE = 'P0003'` antes de qualquer `UPDATE`.

### Frontend (`04-Sistemas/gestao-financeira-clone-544cb (1)`)

- `src/stores/useBudgetStore.ts`: `enviarOrcamentoCliente` agora chama a RPC real `enviar_orcamento_para_cliente` (era `enviar_orcamento_cliente`, nome inexistente — bug pré-existente confirmado pela SPEC).
- `src/lib/budget-status.ts`: novo helper `isDraftStatus(status)` (`status === 'rascunho'`).
- `src/components/budgets/DraftBudgetsTab.tsx` (novo arquivo): réplica de `ClientApprovalTab.tsx` — busca/lista/loading no mesmo padrão, filtra `isDraftStatus`, ações "Editar" (navega para `/budgets/:id`) e "Enviar para o Cliente" (chama `enviarOrcamentoCliente`, copia link de aprovação, toast de sucesso/erro no mesmo padrão do arquivo espelhado). Sem restrição de papel no botão de envio, por decisão do usuário (P-2) — diferente de `ClientApprovalTab.tsx`, que restringe reenvio/aprovação manual a `admin`/`gerente`/`operador`.
- `src/pages/Budgets.tsx`: nova aba "Rascunho" (`TabsTrigger`/`TabsContent value="rascunho"`, usando `DraftBudgetsTab`), posicionada antes de "Aprovação do cliente".
- `src/components/budgets/BudgetTableRow.tsx`: novo branch `normalizedStatus === 'rascunho'` com botão "Enviar para o Cliente", reaproveitando `handleEnviarCliente`/`enviarOrcamentoCliente` já existentes no arquivo; toast de erro no mesmo padrão dos outros branches. Também sem restrição de papel, por P-2.
- `src/pages/BudgetFormPage.tsx`: texto do toast pós-criação (caminho `else`, agora o único alcançável a partir da criação) trocado de "Preencha a forma de pagamento e os campos obrigatórios para enviá-lo ao cliente." para orientar explicitamente o uso da aba "Rascunho" → botão "Enviar para o Cliente". O branch defensivo `newBudget?.status === 'enviado_cliente'` foi mantido como fallback, sem alteração de lógica. Nenhum botão "Salvar e Enviar" foi adicionado (decisão P-4).

### Documentação

- `04-Sistemas/gestao-financeira-clone-544cb (1)/supabase/AI_DB_CONTEXT.md`: contrato de status atualizado para as 5 etapas (`rascunho -> enviado_cliente -> Aprovação da Equipe -> Aprovação Financeira -> Orçamento Aprovado`), nova seção "SPEC-051" documentando a remoção da auto-transição, a remoção de `handle_orcamento_item_workflow`, a validação de completude na RPC e o achado do bug de nome de RPC.
- `supabase/db/domains/orcamentos.md` (repo central): nova seção "Fase explícita de Rascunho antes do envio ao cliente (SPEC-051, 27/07/2026)" com o mesmo contrato de 5 etapas, os achados de banco e a referência à migration; "Diretriz ativa" atualizada.
- `CHANGELOG.md` (repo central): entrada `## 2026-07-27 (6)` — resumo da implementação, migration nova, sistemas que precisam de commit, pendências.

### Verificações rodadas nesta sessão (`gestao-financeira-clone-544cb (1)`)

- `npx oxlint src`: 0 erros, 14 avisos pré-existentes (não relacionados aos arquivos tocados nesta SPEC).
- `npx prettier --check` nos arquivos tocados: falhou na primeira rodada (3 arquivos com formatação divergente), corrigido com `npx prettier --write` nos mesmos 3 arquivos, segunda rodada de `--check` passou limpo.
- `npx vite build`: build de produção concluído com sucesso, sem erros novos (aviso pré-existente de chunk >500kB, não relacionado a esta mudança).

### Decisões de implementação tomadas por não estarem 100% explícitas na SPEC

- Mensagem de erro de `enviar_orcamento_para_cliente` é montada dinamicamente (só lista os campos realmente faltando), em vez de usar a string fixa dada como exemplo ilustrativo no texto da tarefa.
- Validação de completude na RPC inclui `projeto_id` além de `empresa_id`/`cliente_id`/`forma_pagamento` — consistente com a lista completa de campos citada na própria seção "Mudança proposta no banco" da SPEC (linha 135).
- `DraftBudgetsTab.tsx`: paleta cinza/slate e ícone `FileEdit` para o card de cabeçalho (cor não especificada pela SPEC; seguiu o padrão de diferenciação visual já usado pelas outras abas, cada uma com sua cor).
- Botão "Enviar para o Cliente" (tanto em `DraftBudgetsTab.tsx` quanto no novo branch de `BudgetTableRow.tsx`) foi implementado **sem** a checagem de papel (`admin`/`gerente`/`operador`) usada nas demais ações de aprovação/reenvio do sistema, para respeitar literalmente a decisão P-2 ("qualquer usuário autenticado... sem restrição extra de papel").

### Pendências que continuam com o usuário

- Aplicar a migration `20260727_066_spec051_fase_rascunho_orcamento` no Supabase real (nunca aplicada por este agente).
- Homologar no navegador: criar orçamento novo e confirmar que fica em Rascunho mesmo com todos os campos preenchidos e item adicionado; editar o rascunho (inclusive re-salvando itens) sem que ele "escape" sozinho; usar o botão/aba "Enviar para o Cliente" e confirmar a transição manual, o token novo e o registro em `historico_status_orcamentos`.
- Reextrair `supabase/db/current/` depois da migration aplicada.
- Rodar o agente `revisor` antes de qualquer commit.
- Publicar no Skip Cloud (fora do escopo deste agente).

## Pendências

- [x] **Bloqueador técnico resolvido (usuário autorizou, verificação feita em 2026-07-27)**: consultado o Supabase real via `SUPABASE_DB_URL`. Resultado registrado em "Mudança proposta no banco" — texto real de `handle_orcamento_workflow()`/`handle_orcamento_item_workflow()` obtido, e confirmado que `enviar_orcamento_cliente` (sem "para") não existe (só `enviar_orcamento_para_cliente`).
- [x] **P-1 resolvida (usuário, 2026-07-27)**: `enviar_orcamento_para_cliente` deve validar completude antes de aceitar enviar — implementar guard de campos obrigatórios (empresa, projeto, cliente, forma de pagamento, pelo menos 1 item) na RPC.
- [x] **P-2 resolvida (usuário, 2026-07-27)**: qualquer usuário autenticado pode acionar "Enviar para o Cliente" a partir do Rascunho — sem restrição extra de papel.
- [x] **P-3 resolvida (usuário, 2026-07-27)**: não tocar em orçamentos já existentes em `enviado_cliente`/etapas posteriores — a mudança vale só para orçamentos criados/editados a partir da implementação.
- [x] **P-4 resolvida (usuário, 2026-07-27)**: não criar botão "Salvar e Enviar" no formulário de criação — o envio acontece só pela aba/lista de Rascunho, como ação separada.
- [ ] Reextrair `supabase/db/current/` com o novo contrato de 5 etapas — só possível depois que o usuário aplicar a migration `20260727_066_spec051_fase_rascunho_orcamento` no Supabase real. `supabase/db/domains/orcamentos.md` já foi atualizado nesta sessão (documentação, não depende do snapshot).
