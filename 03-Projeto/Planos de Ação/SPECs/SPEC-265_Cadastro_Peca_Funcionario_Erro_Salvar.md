---
titulo: "SPEC-265 — Débora não consegue cadastrar peça nova (Falha ao salvar): trigger de estoque_itens bloqueado pela RLS"
status: migration 318 APLICADA em SP (09/11)
data_ultima_modificacao: 2026-11-09
sistemas_envolvidos:
  - Banco (produtos, estoque_itens, trigger fn_sync_estoque_itens_from_produtos)
  - Cadastro (cadastro-lucenera-b86fe, PecaForm.tsx)
---

# SPEC-265 — Nova peça: "Falha ao salvar"

> Relato (09/11): a Débora copiou uma peça, completou os dados, clicou em Salvar e apareceu só "erro ao salvar".

## Causa (reproduzida no banco, em ROLLBACK, com o usuário da Débora)
- Débora = papel `funcionario`. O INSERT em `produtos` dispara o trigger `fn_sync_estoque_itens_from_produtos`, que insere a linha
  `Estoque` em `estoque_itens`. A função é SECURITY INVOKER; a política `estoque_insert` só aceita `admin/gerente/operador`.
- Erro: `new row violates row-level security policy for table "estoque_itens"` → o INSERT da peça inteira é desfeito.
- O formulário esconde o erro (`catch` mostra só "Falha ao salvar").
- Quem é admin/gerente/operador cadastra normalmente (por isso ninguém tinha notado). Nada foi gravado.

## Definição
1. Migration 318: `fn_sync_estoque_itens_from_produtos` passa a SECURITY DEFINER (search_path fixo, `REVOKE` de PUBLIC/anon). Só roda
   pelo trigger e só escreve a partir da linha NEW. Rollback: `ALTER FUNCTION ... SECURITY INVOKER`.
2. (opcional) PecaForm mostrar a mensagem real do erro junto de "Falha ao salvar".

## Checklist
- [x] Reproduzido como Débora; dry-run da 318: INSERT OK e linha em estoque_itens criada
- [x] Aplicar a 318 (INSERT da Débora testado em ROLLBACK)
- [ ] Débora refazer o cadastro
