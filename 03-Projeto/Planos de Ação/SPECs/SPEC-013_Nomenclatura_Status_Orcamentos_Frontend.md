---
titulo: "SPEC-013 — Nomenclatura de Status e Campos Obrigatórios no Módulo de Orçamentos"
status: concluído
data_ultima_modificacao: 2026-07-08
sistemas_envolvidos:
  - gestao-financeira-clone-544cb (1) (React/TypeScript)
---

# SPEC-013 — Nomenclatura de Status e Campos Obrigatórios no Módulo de Orçamentos

## Checklist de Ação

- [ ] Atualizar labels de status em `src/lib/budget-status.ts`
- [ ] Renomear tab "Aprovação Financeira" → "Revisão Financeira Pendente" em `Budgets.tsx`
- [ ] Atualizar `STATUS_OPTIONS` nos dropdowns de filtro e de edição
- [ ] Tornar campo **Vendedor** obrigatório no formulário (`BudgetFormPage.tsx`)
- [ ] Remover badge secundário "Revisão Financeira Pendente" de `BudgetTableRow.tsx`
- [ ] Atualizar textos internos de `FinancialApprovalTab.tsx`

### Passos manuais do usuário

- [ ] Testar formulário de criação de orçamento — verificar que Vendedor bloqueia o submit sem seleção.
- [ ] Verificar aba "Revisão Financeira Pendente" exibe apenas orçamentos com status `Aprovação Financeira`.
- [ ] Confirmar que a badge laranja não aparece mais na aba "Todos".

## Objetivo

1. **Nomenclatura**: o fluxo tem 3 status principais com nomes inconsistentes entre o banco e o que o usuário vê. O usuário quer nomes mais claros e padronizados na interface:
   - "Enviado ao Cliente" → **"Enviado para o Cliente"**
   - "Aprovação Financeira" → **"Revisão Financeira Pendente"**
   - "Orçamento Aprovado" → permanece igual

2. **Vendedor obrigatório**: ao criar um orçamento, os campos Empresa, Código do Projeto, Cliente e Vendedor devem ser todos obrigatórios. Atualmente o Vendedor é opcional.

3. **Remover badge secundária**: a tabela "Todos" exibe uma segunda badge laranja "Revisão Financeira Pendente" em orçamentos com itens não cadastrados. Esse badge usa exatamente o mesmo nome do tab de aprovação financeira, causando confusão. O badge deve ser removido.

## Decisões aprovadas

- Os **valores armazenados no banco de dados NÃO mudam** — apenas os rótulos exibidos na interface mudam.
  - `enviado_cliente` continua sendo o valor no banco; exibe "Enviado para o Cliente"
  - `Aprovação Financeira` continua sendo o valor no banco; exibe "Revisão Financeira Pendente"
  - `Orçamento Aprovado` continua sendo o valor no banco; exibe "Orçamento Aprovado"
- `vendedor_id` passa a ser campo obrigatório no formulário (novo orçamento e edição)
- A opção "Nenhum" no select de Vendedor é removida

## Definição da SPEC

### Mapeamento de labels

| Status (DB) | Label antigo | Label novo |
|---|---|---|
| `enviado_cliente` | Enviado ao Cliente | **Enviado para o Cliente** |
| `recusado_cliente` | Recusado pelo Cliente | Recusado pelo Cliente (sem mudança) |
| `aprovado` | Aprovado pelo Cliente | Aprovado pelo Cliente (sem mudança) |
| `Aprovação Financeira` | Aprovação Financeira | **Revisão Financeira Pendente** |
| `Orçamento Aprovado` | Orçamento Aprovado | Orçamento Aprovado (sem mudança) |
| `rascunho` | Rascunho | Rascunho (sem mudança) |

### Alterações por arquivo

#### `src/lib/budget-status.ts`

```typescript
// getStatusLabel() — mudar:
enviado_cliente: 'Enviado para o Cliente',   // era: 'Enviado ao Cliente'
'Aprovação Financeira': 'Revisão Financeira Pendente',  // era: 'Aprovação Financeira'
```

#### `src/pages/Budgets.tsx`

```typescript
// Tab trigger — mudar:
<TabsTrigger value="aprovacao-financeira">
  Revisão Financeira Pendente   {/* era: Aprovação Financeira */}
</TabsTrigger>

// STATUS_OPTIONS — mudar labels:
{ label: 'Enviado para o Cliente', value: 'enviado_cliente' },   // era: 'Enviado ao Cliente'
{ label: 'Revisão Financeira Pendente', value: 'Aprovação Financeira' }, // era: 'Aprovação Financeira'
```

#### `src/pages/BudgetFormPage.tsx`

```typescript
// Schema — mudar vendedor_id de optional para obrigatório:
vendedor_id: z.string({ required_error: 'Selecione um vendedor' })
  .min(1, 'Selecione um vendedor')
  .refine((v) => v !== 'none', { message: 'Selecione um vendedor' }),

// defaultValues — mudar:
vendedor_id: '',   // era: 'none'

// FormLabel do Vendedor — acrescentar asterisco:
Vendedor <span className="text-red-500">*</span>

// Select de Vendedor — remover opção "Nenhum":
// Remover: { value: 'none', label: 'Nenhum' }

// value do select — mudar:
value={field.value || ''}   // era: field.value || 'none'

// STATUS_OPTIONS — mudar labels:
{ value: 'enviado_cliente', label: 'Enviado para o Cliente' },
{ value: 'Aprovação Financeira', label: 'Revisão Financeira Pendente' },
```

#### `src/components/budgets/BudgetTableRow.tsx`

```tsx
// REMOVER este bloco inteiro (linhas ~261-268):
{needsFinancialReview && (
  <Badge variant="outline" className="bg-orange-50 text-orange-700 border-orange-200 text-[10px] whitespace-nowrap">
    <AlertTriangle className="w-3 h-3 mr-1" />
    Revisão Financeira Pendente
  </Badge>
)}
```

> Nota: `needsFinancialReview` ainda é usada no título do botão de aprovação financeira — manter a variável, apenas remover o badge.

#### `src/components/budgets/FinancialApprovalTab.tsx`

```tsx
// Cabeçalho da aba — mudar:
"Revisão Financeira de Orçamentos"   // era: "Aprovação Financeira de Orçamentos"

// Empty state — mudar:
'Orçamentos em "Revisão Financeira Pendente" aparecerão aqui.'  // era: 'Orçamentos em "Aprovação Financeira" aparecerão aqui.'
```

### Campos obrigatórios no formulário (novo orçamento)

| Campo | Antes | Depois |
|---|---|---|
| Empresa | Obrigatório ✅ | Obrigatório ✅ |
| Código do Projeto | Obrigatório ✅ | Obrigatório ✅ |
| Cliente | Obrigatório ✅ | Obrigatório ✅ |
| Vendedor | Opcional | **Obrigatório** |
| Arquiteto / Profissional | Opcional | Opcional (sem mudança) |

### Critérios de aceite

- [ ] Formulário de novo orçamento exibe asterisco `*` ao lado de "Vendedor"
- [ ] Formulário bloqueia submit sem Vendedor selecionado (mostra mensagem de erro)
- [ ] Tabela "Todos" não exibe mais a badge laranja "Revisão Financeira Pendente"
- [ ] Aba exibe "Revisão Financeira Pendente" (não mais "Aprovação Financeira")
- [ ] Badge de status na tabela exibe "Enviado para o Cliente" (não mais "Enviado ao Cliente")
- [ ] Badge de status exibe "Revisão Financeira Pendente" para o status `Aprovação Financeira`
- [ ] Filtro por status no dropdown inclui as novas nomenclaturas

## Realizado

### 2026-07-08

- `budget-status.ts`: labels atualizados — `enviado_cliente` → "Enviado para o Cliente", `Aprovação Financeira` → "Revisão Financeira Pendente".
- `Budgets.tsx`: tab "Aprovação Financeira" renomeada para "Revisão Financeira Pendente"; `STATUS_OPTIONS` atualizado.
- `BudgetFormPage.tsx`: `vendedor_id` tornado obrigatório no schema Zod (rejeita `''` e `'none'`); label com asterisco; opção "Nenhum" removida do select; `STATUS_OPTIONS` atualizado; default de `vendedor_id` alterado de `'none'` para `''`.
- `BudgetTableRow.tsx`: badge secundária laranja "Revisão Financeira Pendente" removida.
- `FinancialApprovalTab.tsx`: heading e empty state atualizados para "Revisão Financeira".

## Pendências

- [ ] Confirmar com o usuário se orçamentos existentes sem vendedor preenchido precisam de tratamento especial ao editar (atualmente o campo obrigatório blocará o save se não houver vendedor).
