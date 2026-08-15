---
titulo: "SPEC-107 — Formas de pagamento: liberar Cheque na UI e adicionar Permuta"
status: concluído
data_ultima_modificacao: 2026-08-15
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb, Skip 32554) — `BudgetFormPage.tsx`
  - Supabase (banco central) — ENUM `pagamento_forma`
---

# SPEC-107 — Formas de pagamento: liberar Cheque na UI e adicionar Permuta

> Origem: reunião Vinícius 14/08/2026 ([22:28]-[23:16]) — *"Cheque, vou colocar o cheque... Vou te pedir outra: Permuta."*

## Objetivo

Cheque e Permuta precisam estar disponíveis como forma de pagamento no orçamento.

## Definição da SPEC

### Estado atual confirmado

- **Banco**: `ENUM pagamento_forma` já tem `'cheque'` (confirmado via `SELECT unnest(enum_range(NULL::pagamento_forma))`: `pix, cartao, boleto, transferencia, cheque, dinheiro`). `'permuta'` **não existe**.
- **Frontend** (`BudgetFormPage.tsx:2560-2563`): o `<Select>` de forma de pagamento só lista 4 opções — `dinheiro`, `pix`, `cartao`, `boleto`. **Cheque e transferência já existem no banco mas não aparecem na tela.**
- `BudgetFormPage.tsx:1526`: `const validFormas = ['pix', 'cartao', 'boleto', 'dinheiro']` — lista de validação separada, também sem cheque/transferência.

### Proposta (não implementar sem aprovação)

1. Adicionar `<SelectItem value="cheque">Cheque</SelectItem>` no Select (já é valor válido no banco, é só liberar na UI) + incluir `'cheque'` em `validFormas`.
2. Migration: `ALTER TYPE pagamento_forma ADD VALUE 'permuta'` + mesmo tratamento de UI que o cheque.
3. Confirmar se "transferência" (já existe no enum, também não aparece na UI) deveria ser liberada junto, já que está na mesma situação do cheque — não foi pedido na reunião, mas é uma inconsistência parecida.

## Análise de ecossistema

- **Depende de**: `orcamentos.forma_pagamento` (ou campo equivalente de parcelas, a confirmar exatamente qual usa esse enum).
- **Afeta**: só o formulário de orçamento. Baixo risco — só adiciona opções, não remove nem muda comportamento existente.

## Realizado

### 2026-08-15

- Confirmado com o usuário: liberar "Transferência" junto (mesma inconsistência de "já existe no banco, nunca apareceu na tela").
- Migration `20260815_115_spec107_forma_pagamento_permuta` — `ALTER TYPE pagamento_forma ADD VALUE 'permuta'`, aplicada isolada no Supabase real (confirmado via `SELECT unnest(enum_range(...))`).
- `BudgetFormPage.tsx`: `<SelectItem>` de cheque/transferência/permuta adicionados; `validFormas` passou a incluir os 3. Achado extra durante a implementação: a normalização de forma de pagamento vinda de importação de XML (Connect) tinha um fallback explícito `if (formaPgto.includes('transferencia')) formaPgto = 'pix'` — como "transferência" nunca foi opção válida na UI, XMLs importados com essa forma eram silenciosamente recodificados como "pix". Removido junto, já que "transferencia" agora é um valor válido de verdade.
- Publicado Skip 32554 v0.0.338 — QA limpo. Testado ao vivo via `javascript_tool`: as 7 opções (Dinheiro, Pix, Cartão, Boleto, Cheque, Transferência, Permuta) aparecem corretamente no `<Select>`.

## Pendências

Nenhuma.
