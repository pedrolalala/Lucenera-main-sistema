---
titulo: "SPEC-264 — Orçamento × Consulta com preço diferente de novo: importador da Connect deixava preco_venda para trás"
status: implementada (migration 317 aplicada 09/11)
data_ultima_modificacao: 2026-11-09
sistemas_envolvidos:
  - Banco (produtos.preco_venda / valor_venda)
  - scripts/importar_produtos_estoque.py
---

# SPEC-264 — Preço diferente entre Consulta e Orçamento (desdobramento da SPEC-230)

> Pedido (09/11): peça 11412 — Consulta 184,49, Orçamento 182,47. Varrer todas as peças e corrigir.

## Causa (conferida no banco)
- Consulta lê `valor_venda || preco_venda`; Orçamento lê `preco_venda || valor_venda`.
- A SPEC-230 (migration 246) fez o trigger `fn_atualizar_preco_venda` copiar `valor_venda` para `preco_venda`.
- Mas `importar_produtos_estoque.py` desliga os dois triggers de preço durante a gravação (incidente 10/09). Quando a Connect muda
  o preço, `valor_venda` atualiza e `preco_venda` fica parado. Lotes de 04/11 (52 peças) e 05/11 (4).

## Varredura (4.942 peças)
- 56 com `valor_venda > 0` e `preco_venda` diferente (ex.: 11412, 12690, 10173, 11900).
- 369 com `valor_venda = 0`: as duas telas caem em `preco_venda`, sem diferença visível. Não mexe.

## Definição
1. Importador: na mesma UPDATE, quando `valor_venda > 0`, grava `preco_venda = valor_venda` (triggers continuam desligados).
   A conferência final passa a esperar esse valor.
2. Migration 317: backup `backup._bkp_spec264_produtos_preco_venda` (56 linhas) + `preco_venda = valor_venda` onde diferente.
   Rollback em `rollback.sql`.
- Orçamentos já feitos não mudam sozinhos ("Atualizar preços" no orçamento).

## Checklist
- [x] Importador corrigido (py_compile ok)
- [x] Dry-run da 317 em ROLLBACK: 56 corrigidas, 0 restantes, 11412 → 184,49
- [x] Aplicar a 317 no banco (SP): 56 no backup, 0 divergentes, 11412 = 184,49
- [ ] Usuário conferir a 11412 em orçamento novo
