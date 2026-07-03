---
titulo: "SPEC-002 — Prazo para Início da Cobrança no Orçamento"
status: parcial
data_ultima_modificacao: 2026-06-26
sistemas_envolvidos:
  - Orçamentos
  - Administração Bancária / Financeiro
---

# SPEC-002 — Prazo para Início da Cobrança no Orçamento

## Checklist de Ação

- [x] Adicionar `orcamentos.prazo_inicio_cobranca_dias` (inteiro, com check `>= 0`).
- [x] Melhorar a mensagem de erro de `aprovar_orcamento_financeiro` para orientar a correção.
- [x] Adicionar campo "Prazo para Início da Cobrança (dias)" em `BudgetFormPage.tsx`, sempre visível.
- [x] Calcular `prazo_pagamento_dias` (array) e `condicoes_pagamento` (texto) a partir do prazo digitado e da quantidade de parcelas.
- [x] Pré-carregar o campo de prazo ao editar um orçamento existente.
- [x] Atualizar a interface `Budget` em `useBudgetStore.ts` com os novos campos.
- [x] Atualizar `src/lib/supabase/types.ts` com a coluna nova.
- [x] Adicionar aviso amigável em `BudgetTableRow.tsx` (aprovar e sincronizar) quando o orçamento não tem prazo interpretável.
- [x] Ajustar `ApprovalsTab.tsx` para pular (em vez de abortar o lote) orçamentos sem prazo na sincronização em massa.
- [x] Rodar build/type-check do sistema de Orçamentos.
- [x] Separar os desdobramentos de frete, histórico e parcelas legadas em SPECs próprias, mantendo esta SPEC focada em prazo de cobrança.

### Passos manuais do usuário

- [x] Aplicar a migration `20260625120000_spec002_prazo_inicio_cobranca.sql` no banco remoto compartilhado (`vcvcwzmbiftcawncibke`), via SQL Editor do Supabase Studio ou CLI própria.
- [x] Após aplicar, reextrair o snapshot `supabase/db/current/01_schema_full.sql` para refletir `orcamentos.prazo_inicio_cobranca_dias`.
- [ ] Editar manualmente os orçamentos já existentes (criados antes desta SPEC) para preencher o novo campo antes de tentar aprová-los.

## Objetivo

A SPEC-001 passou a calcular parcelas/vencimentos automaticamente a partir de `orcamentos.condicoes_pagamento` / `orcamentos.prazo_pagamento_dias`, mas a tela de Orçamentos nunca ganhou um campo para o usuário informar esse prazo. Resultado: a aprovação de qualquer orçamento falha com `Orçamento % não possui prazo de pagamento interpretável`, independente da forma de pagamento escolhida.

Esta SPEC adiciona o campo que faltava: **um único número, "Prazo para Início da Cobrança (dias)"** — não é prazo por parcela, é quantos dias após a aprovação a primeira cobrança vence. As parcelas seguintes (quando existirem) vencem em múltiplos desse mesmo intervalo, reproduzindo o padrão observado no vídeo do Connect (prazo negociado de 30 dias → vencimentos 23/07, 23/08, 23/09, ou seja, 30/60/90).

### Escopo desta SPEC

Esta SPEC trata somente da captura, persistência e uso do prazo de início de cobrança do orçamento.

Ficam fora desta SPEC, para evitar misturar problemas diferentes no mesmo plano:

- validação e coleta de frete do orçamento — tratada na `SPEC-003_Validacao_Coleta_Frete_Orcamento.md`;
- auditoria de aprovação e proteção de parcelas geradas por orçamento — tratadas na `SPEC-004_Auditoria_Parcelas_Orcamento_Aprovado.md`.

## Decisões aprovadas

- O prazo é um único valor em dias, não um valor por parcela.
- O intervalo entre parcelas é o próprio prazo informado (prazo, prazo×2, prazo×3, ...), igual ao padrão "30/60/90" já manual no Connect.
- O campo é sempre obrigatório e sempre visível, independente da forma de pagamento (a RPC exige prazo interpretável em qualquer caso, inclusive Pix/Dinheiro).
- Não alterar a lógica de cálculo de `aprovar_orcamento_financeiro` nem de `_lucenera_parse_prazo_pagamento` — ambas já priorizam o array `prazo_pagamento_dias` quando preenchido; só faltava o frontend preenchê-lo.
- Orçamentos já existentes (criados antes desta SPEC) continuam bloqueados na aprovação até serem editados manualmente — não é tratado como regressão.
- A aplicação da migration no banco remoto é feita pelo usuário, não pela IA, nesta etapa.

## Definição da SPEC

### Causa raiz

A tela só enviava:

- `forma_pagamento = 'boleto' | 'cartao'` → `condicoes_pagamento = "{parcelas}x"` (ex.: `"3x"`), uma string sem dias, que o parser da RPC rejeita por não ter base de cálculo.
- `forma_pagamento = 'pix' | 'dinheiro'` → `condicoes_pagamento = null`.

A coluna `orcamentos.prazo_pagamento_dias` (criada na SPEC-001) nunca era preenchida por nenhuma tela.

### Regra de cálculo no frontend

```text
prazo_inicio_cobranca_dias = valor digitado pelo usuário (>= 0)
quantidade_parcelas = 1 para pix/dinheiro; campo "Quantidade de Parcelas" para boleto/cartão
prazo_pagamento_dias[i] = prazo_inicio_cobranca_dias * (i + 1), para i = 0..quantidade_parcelas-1
condicoes_pagamento = prazo_pagamento_dias.join('/')  -- texto legível, ex.: "30/60/90"
```

O array `prazo_pagamento_dias` é enviado direto para `orcamentos.prazo_pagamento_dias`. O valor bruto digitado também é salvo em `orcamentos.prazo_inicio_cobranca_dias`, para reabrir a edição sem precisar reconstruir o número a partir do array.

### Alterações no banco

Migration: `Sistema/gestao-financeira-clone-544cb (1)/supabase/migrations/20260625120000_spec002_prazo_inicio_cobranca.sql` (espelho central em `supabase/db/migrations/20260625_005_prazo_inicio_cobranca_orcamento/`).

```sql
ALTER TABLE public.orcamentos
  ADD COLUMN IF NOT EXISTS prazo_inicio_cobranca_dias integer;

ALTER TABLE public.orcamentos
  ADD CONSTRAINT orcamentos_prazo_inicio_cobranca_dias_check
  CHECK (prazo_inicio_cobranca_dias IS NULL OR prazo_inicio_cobranca_dias >= 0);
```

Mensagem de erro de `aprovar_orcamento_financeiro` (não funcional, só clareza):

```text
Orçamento % não possui prazo de pagamento interpretável. Edite o orçamento e informe o "Prazo para Início da Cobrança (dias)".
```

### Alterações no sistema de Orçamentos

| Arquivo | Mudança |
|---|---|
| `src/pages/BudgetFormPage.tsx` | Novo campo obrigatório `prazo_inicio_cobranca_dias`, sempre visível; cálculo do array no submit; pré-carga na edição. |
| `src/stores/useBudgetStore.ts` | Interface `Budget` com `prazo_inicio_cobranca_dias` e `prazo_pagamento_dias`. |
| `src/lib/supabase/types.ts` | Tipagem da coluna nova. |
| `src/components/budgets/BudgetTableRow.tsx` | Aviso amigável antes de chamar a RPC (aprovar e sincronizar) se não houver prazo interpretável. |
| `src/components/budgets/ApprovalsTab.tsx` | "Sincronizar Pendências" pula orçamentos sem prazo em vez de abortar o lote inteiro; reporta quantos foram pulados/falharam. |

### Critérios de aceite

- Orçamento com forma de pagamento Boleto/Cartão, parcelas = 3 e prazo = 30 dias gera `prazo_pagamento_dias = [30, 60, 90]` e aprova com sucesso.
- Orçamento com forma de pagamento Pix/Dinheiro e prazo = 0 gera `prazo_pagamento_dias = [0]` e aprova com sucesso (cobrança imediata).
- Orçamento sem o campo de prazo preenchido não pode ser salvo (validação de formulário antes de chegar à RPC).
- "Sincronizar Pendências" não interrompe o lote inteiro quando um orçamento individual está sem prazo.

## Realizado

### 2026-06-25

- Migration `20260625120000_spec002_prazo_inicio_cobranca.sql` criada no sistema de Orçamentos (coluna + constraint + mensagem de erro mais clara na RPC).
- Migration espelhada em `supabase/db/migrations/20260625_005_prazo_inicio_cobranca_orcamento/`.
- Campo "Prazo para Início da Cobrança (dias)" implementado em `BudgetFormPage.tsx`, com preview ao vivo dos vencimentos calculados.
- `condicoes_pagamento` deixou de ser gerado como `"{parcelas}x"` e passou a ser o texto legível derivado do array de prazos (ex.: `"30/60/90"`).
- Tipagem atualizada em `useBudgetStore.ts` e `src/lib/supabase/types.ts`.
- Aviso amigável adicionado em `BudgetTableRow.tsx` (aprovar/sincronizar) e `ApprovalsTab.tsx` (sincronização em massa) para orçamentos sem prazo interpretável.
- Build e type-check (`npx tsc --noEmit`) do sistema de Orçamentos executados com sucesso.
- Desdobramentos fora do escopo de prazo separados em duas SPECs novas: frete estruturado (`SPEC-003`) e integridade/auditoria do fluxo aprovado (`SPEC-004`).

### 2026-06-26

- Confirmado pelo snapshot central de 2026-06-25 que a migration remota foi aplicada e `orcamentos.prazo_inicio_cobranca_dias` está no banco.
- Confirmado que as lacunas separadas em SPECs próprias avançaram: frete estruturado (`SPEC-003`), histórico/unicidade/remoção de `sync-fechamentos-automatica` (`SPEC-004`) e remoção dos triggers legados que bloqueavam aprovação (`SPEC-005`).

## Pendências

- [ ] Orçamentos criados antes desta SPEC continuam sem prazo interpretável e precisam ser editados manualmente um a um antes de aprovar.
- [ ] Homologar aprovações reais de orçamentos antigos após edição manual do prazo.
