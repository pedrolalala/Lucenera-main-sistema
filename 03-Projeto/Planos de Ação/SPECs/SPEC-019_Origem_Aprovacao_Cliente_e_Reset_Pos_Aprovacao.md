---
titulo: "SPEC-019 — Origem da aprovação do cliente, reset pós-aprovação e correção de RPCs públicas ausentes"
status: concluído
data_ultima_modificacao: 2026-07-07
sistemas_envolvidos:
  - Orçamentos
  - Supabase (banco central)
---

# SPEC-019 — Origem da aprovação do cliente, reset pós-aprovação e correção de RPCs públicas ausentes

> Esta SPEC estende a SPEC-016 (contrato oficial de status já implantado:
> `enviado_cliente -> Aprovação Financeira -> Orçamento Aprovado`). Não
> substitui a SPEC-016 nem renomeia os status oficiais — foi exatamente
> o erro cometido e corrigido durante esta sessão (ver "Realizado").

## Checklist de Ação

- [x] Adicionar coluna `orcamentos.aprovado_cliente_origem` (`'manual'|'token'`) para distinguir como o cliente aprovou, sem duplicar o status
- [x] Endurecer `aprovar_orcamento_cliente_manual` para validar frete/forma de pagamento/prazo/item especial antes de mudar o status (alinhado à SPEC-ORC-05 do sistema de Orçamentos)
- [x] Trigger de reset: editar valor/frete/forma de pagamento/prazo/itens de um orçamento já em `Aprovação Financeira` ou `Orçamento Aprovado` volta o status para `enviado_cliente`, invalida a aprovação anterior e gera novo token
- [x] Mecanismo de bypass do reset (`app.skip_approval_reset`) + RPC `financeiro_editar_orcamento` + modal de confirmação, para a tela de Aprovação Financeira poder corrigir valores sem reiniciar a aprovação do cliente, quando o financeiro escolher isso explicitamente
- [x] Corrigir bug: modal de criar cliente/projeto dentro do formulário de orçamento mostrava sucesso sem persistir nada (evento de submit borbulhando por portal React até o form pai) — `stopPropagation` adicionado
- [x] Criar `buscar_orcamento_para_aprovacao(p_orcamento_id, p_token)` e `recusar_orcamento_cliente_publico(p_orcamento_id, p_token, p_motivo)` — nunca existiam no banco; o frontend (`ClientApproval.tsx`) já as chamava, causando "Link Inválido" para qualquer cliente que abrisse o link de aprovação

### Passos manuais do usuário

- [ ] Homologar o fluxo completo do link público (`buscar` → aprovar/recusar) com um orçamento real
- [ ] Confirmar se o token deve expirar por tempo (SPEC-009 P-01 continua em aberto; esta SPEC não implementou TTL, por decisão explícita)

## Objetivo

Durante uma sessão de correção de bugs no sistema de Orçamentos, foi necessário:
1. distinguir aprovação manual (vendedor) de aprovação por token (cliente), sem quebrar o contrato de status já oficial;
2. impedir que uma edição comercial pós-aprovação passe despercebida, exigindo reaprovação;
3. permitir que o Financeiro corrija valores sem forçar sempre uma nova aprovação do cliente;
4. corrigir dois bugs de frontend/backend não relacionados ao ponto acima, encontrados no caminho.

## Decisões aprovadas

- O contrato de status da SPEC-016 (`Aprovação Financeira` / `Orçamento Aprovado`, em português) é definitivo e não deve ser renomeado por nenhuma SPEC futura sem descontinuar esta explicitamente.
- Distinguir origem da aprovação do cliente via coluna nova (`aprovado_cliente_origem`), não via novo valor de status.
- Editar orçamento já aprovado pelo cliente reinicia o ciclo (cliente + financeiro) por padrão.
- Exceção: a tela de Aprovação Financeira pode optar, por escolha explícita do usuário via modal, por **não** reiniciar a aprovação do cliente ao corrigir valores — para não quebrar o fluxo de revisão financeira que já existia.
- Expiração de token por tempo (TTL) fica fora de escopo desta SPEC.

## Definição da SPEC

### Erro cometido e corrigido durante a implementação

A implementação inicial desta sessão **não consultou este repositório central antes de alterar o banco** e concluiu (a partir apenas do escopo local do sistema de Orçamentos, desatualizado) que os status em português eram dado legado a normalizar. Isso reverteu, sem saber, o contrato já decidido e testado pela SPEC-016 — e quebrou, de forma independente, o link público de aprovação (RPCs `buscar_orcamento_para_aprovacao`/`recusar_orcamento_cliente_publico` nunca existiam, e só apareceram como erro quando o usuário testou o link durante a sessão). Após identificar a SPEC-016 neste repositório, a normalização foi revertida e as funcionalidades novas foram reconstruídas em cima do contrato oficial. Ver "Realizado" para a sequência completa.

**Lição registrada:** qualquer alteração em `orcamentos.status` deve, primeiro, ler a SPEC relacionada neste repositório central (`AGENTS.md`, passo "Antes de alterar banco") — o escopo local de um sistema (`Escopos/`) pode estar desatualizado em relação a uma SPEC já aplicada.

### Coluna nova

```sql
ALTER TABLE public.orcamentos
  ADD COLUMN IF NOT EXISTS aprovado_cliente_origem text
  CHECK (aprovado_cliente_origem IS NULL OR aprovado_cliente_origem IN ('manual', 'token'));
```

Preenchida por `aprovar_orcamento_cliente` (manual, interno), `aprovar_orcamento_cliente_manual` (manual, vendedor em nome do cliente) e `aprovar_orcamento_cliente_publico` (token).

### Reset ao editar após aprovação

Trigger `handle_orcamento_workflow` (BEFORE UPDATE em `orcamentos`) e `handle_orcamento_item_change_reset` (AFTER INSERT/UPDATE/DELETE em `orcamento_itens`): se o orçamento está em `Aprovação Financeira` ou `Orçamento Aprovado` e `valor_total`/`forma_pagamento`/`frete_tipo`/`frete_valor`/`condicoes_pagamento`/`prazo_pagamento_dias`/`desconto_global` mudam (ou os itens mudam), o status volta para `enviado_cliente`, limpa `aprovado_cliente_em`/`aprovado_cliente_origem`/`requer_revisao_financeira`, gera novo token e registra em `historico_status_orcamentos`.

Bypass: `set_config('app.skip_approval_reset', 'true', true)` (escopo de transação) — usado apenas pela RPC `financeiro_editar_orcamento` quando o usuário explicitamente escolhe não reiniciar.

### RPC nova: `financeiro_editar_orcamento`

```sql
public.financeiro_editar_orcamento(
  p_orcamento_id uuid,
  p_forma_pagamento text,
  p_valor_total numeric,
  p_itens jsonb,
  p_reiniciar_aprovacao boolean
)
```

Substitui os `UPDATE`/`upsert` diretos que a tela de Aprovação Financeira fazia via cliente Supabase. Exige `orcamentos.status IN ('Aprovação Financeira', 'Orçamento Aprovado')` e role `admin`/`gerente`/`operador`. Frontend (`FinancialApprovalEditDialog.tsx`) pergunta ao usuário via modal antes de chamar, com `p_reiniciar_aprovacao` refletindo a escolha.

### RPCs públicas criadas (ausentes antes desta SPEC)

| RPC | Uso | Observação |
|---|---|---|
| `buscar_orcamento_para_aprovacao(p_orcamento_id, p_token)` | `ClientApproval.tsx` carrega os dados do orçamento antes do cliente decidir | Valida token; retorna `numero, valor_total, data_emissao, cliente_nome, status, condicoes_pagamento, forma_pagamento` |
| `recusar_orcamento_cliente_publico(p_orcamento_id, p_token, p_motivo)` | Cliente recusa pelo link público | Espelha `aprovar_orcamento_cliente_publico`; status final `recusado_cliente` |

Ambas `GRANT EXECUTE ... TO anon, authenticated` (mesmo padrão de `aprovar_orcamento_cliente_publico`, já existente).

### Migrations aplicadas (sistema de Orçamentos)

```
04-Sistemas/gestao-financeira-clone-544cb (1)/supabase/migrations/
  20260707150000_orcamento_status_event_engine.sql        — tentativa inicial (revertida)
  20260707160000_orcamento_reset_bypass_and_finance_edit_rpc.sql — tentativa inicial (revertida)
  20260707161500_finance_edit_rpc_status_guard.sql         — tentativa inicial (revertida)
  20260707170000_revert_to_spec016_status_contract.sql     — correção final: reverte para o contrato SPEC-016 e cria as RPCs públicas ausentes
```

As três primeiras migrations usaram valores `snake_case` (`pendente_aprovacao_financeira`, `aprovado`) que **não são o contrato oficial**. A quarta migration reverte tudo para `Aprovação Financeira`/`Orçamento Aprovado`, mantendo `aprovado_cliente_origem`, o reset pós-aprovação e o bypass do financeiro. **A migration 170000 é a versão final/correta; as três primeiras ficam no histórico apenas como registro do erro cometido e corrigido.**

### Análise de ecossistema (obrigatória por `COMO_CRIAR_SPEC.md`)

- Depende de `orcamentos`, `orcamento_itens`, `historico_status_orcamentos`, `usuarios`. Não depende de `projetos`, `contatos`, `produtos`, `boletos`, `projeto_itens`, `projeto_parcelas` diretamente (só lidos por FK em `aprovar_orcamento_financeiro`, que não mudou de contrato aqui).
- Afeta apenas o sistema de Orçamentos. Verificado por busca direta nos repositórios locais dos outros 8 sistemas do ecossistema (Cadastro, Catálogo Peças Ubiqua, Central Dashboard, Dashboard RH, CRM, Logística, Gestão Financeira): nenhum lê ou escreve `orcamentos.status` diretamente nem chama as RPCs alteradas. Gestão Financeira só faz `SELECT` em `orcamentos` sem tocar `.status`. CRM referencia um enum diferente (`projeto_status`, tabela `projetos`, não tocado). Catálogo Ubiqua usa uma tabela própria (`orcamentos_revenda_ubiqua`), sem relação com `orcamentos`.
- Não há dado duplicado novo — `aprovado_cliente_origem` é informação nova, não derivável de outra coluna existente.
- `AI_DB_CONTEXT.md` do sistema de Orçamentos deveria ser atualizado para citar `aprovado_cliente_origem`, o reset pós-aprovação e as duas RPCs novas — ver Pendências.

## Critérios de aceite

- [x] `orcamentos.status` permanece em `Aprovação Financeira`/`Orçamento Aprovado` (contrato SPEC-016), sem novos valores concorrentes
- [x] Aprovação do cliente (manual ou token) registra `aprovado_cliente_origem` corretamente
- [x] Editar valor/frete/forma de pagamento/prazo/itens de um orçamento em `Aprovação Financeira` ou `Orçamento Aprovado` volta o status para `enviado_cliente` (verificado por leitura do trigger; não testado em homologação)
- [x] Tela de Aprovação Financeira consegue corrigir valores sem reiniciar a aprovação, quando o usuário escolhe essa opção no modal
- [x] Link público de aprovação (`buscar_orcamento_para_aprovacao`) responde corretamente — testado contra um orçamento real (`ORC` numero 418807) após a migration, retornando os dados esperados
- [ ] Fluxo completo homologado com um orçamento real (criar → enviar → cliente aprova/recusa → financeiro corrige/aprova)

## Testes obrigatórios

- Banco: reaplicar a migration `20260707170000` em ambiente de teste e confirmar que os 20 orçamentos reais mantêm a distribuição `Orçamento Aprovado (12) / enviado_cliente (5) / Aprovação Financeira (3)`.
- Banco: chamar `buscar_orcamento_para_aprovacao` com token real e token inválido, confirmar sucesso/erro esperado.
- Frontend: abrir um orçamento já aprovado pelo cliente, editar o valor, confirmar que o status volta para "Enviado para o Cliente" na tela.
- Frontend: na tela de Aprovação Financeira, editar um orçamento e escolher "Manter aprovação do cliente" no modal — confirmar que o status não reinicia.

## Realizado

### 2026-07-07

- Implementadas as funcionalidades novas (origem da aprovação, reset pós-edição, bypass do financeiro) usando por engano valores `snake_case` em vez do contrato oficial da SPEC-016, por não ter consultado este repositório central antes de alterar o banco.
- Normalizados 20 orçamentos reais (12 `Orçamento Aprovado`, 3 `Aprovação Financeira`) para os valores `snake_case` incorretos.
- Usuário reportou "Link Inválido" no link de aprovação pública — investigação revelou que `buscar_orcamento_para_aprovacao` e `recusar_orcamento_cliente_publico` nunca existiram no banco (gap pré-existente, não causado por esta sessão).
- Identificada a SPEC-016 neste repositório central, confirmando o contrato oficial já testado e implantado.
- Migration `20260707170000` aplicada: reverteu os 20 orçamentos para os valores oficiais, recriou as 6 funções/triggers usando o contrato SPEC-016, e criou as 2 RPCs públicas ausentes.
- Frontend do sistema de Orçamentos revertido para usar as strings oficiais em todos os pontos (`budget-status.ts`, `BudgetFormPage.tsx`, `Budgets.tsx`, `ClientApproval.tsx`, `budgetApprovalService.ts`, `useBudgetStore.ts`).
- Corrigido também, na mesma sessão, um bug não relacionado: modal de criar cliente/projeto no formulário de orçamento mostrava sucesso sem persistir nada (submit borbulhando por portal React) — `stopPropagation` adicionado em `ClientCreateModal.tsx`/`ProjectCreateModal.tsx`.
- Verificado com `pnpm build`, `pnpm tsc --noEmit` (sem regressões) e teste direto contra o Supabase real (RPC `buscar_orcamento_para_aprovacao` retornando dados corretos para um orçamento com token ativo).
- Commits no sistema de Orçamentos (`Lucenera---Gest-o-Financeira` no GitHub): correção de status engine + revert SPEC-016 + reaplicação do fix de stopPropagation perdido em merge concorrente do Skip.

## Pendências

- [ ] Atualizar `04-Sistemas/gestao-financeira-clone-544cb (1)/supabase/AI_DB_CONTEXT.md` citando `aprovado_cliente_origem`, o reset pós-aprovação e as RPCs `buscar_orcamento_para_aprovacao`/`recusar_orcamento_cliente_publico`.
- [ ] Homologar o fluxo completo ponta a ponta com um orçamento real (criar → enviar → cliente decide → financeiro corrige/aprova).
- [ ] Decidir se o token de aprovação deve expirar por tempo (P-01 da SPEC-009 continua em aberto; esta SPEC não implementou TTL).
- [ ] Reextrair `supabase/db/current/` deste repositório central para refletir `aprovado_cliente_origem`, as novas funções e triggers (mesma pendência já registrada na SPEC-016 para outras mudanças, ainda não fechada).
