---
titulo: "SPEC-310 — Estoque lido do local certo (estoque_itens) e coluna antiga alinhada"
status: pendente
data_ultima_modificacao: 2026-11-16
sistemas_envolvidos:
  - Banco (função ubiqua_estoque_atual, produtos.estoque_total/estoque_disponivel)
  - Catálogo Ubiqua (consome a função)
---

# SPEC-310 — Estoque lido do local certo (estoque_itens) e coluna antiga alinhada

## Checklist de Ação

- [x] Conferência Connect x sistema (planilha Produtos 16/11): estoque geral bate em 4.559 de 4.574 produtos (relatório PDF/Excel em `03-Projeto/Auditoria/2026-11-16_relatorio_estoque_Connect_x_sistema.*`).
- [x] Varredura de quem lê a coluna antiga: telas Cadastro (Consulta), Dashboard, Compras e Catálogo leem views que já usam `estoque_itens`; o trigger `trg_sync_estoque_itens_from_produtos` só dispara em INSERT (editar produto não sobrescreve estoque).
- [x] Migration 370 escrita (up/rollback) e ensaiada em ROLLBACK: 47 produtos alinhados, preço/custo, `estoque_itens` e kardex inalterados, rollback.sql restaura tudo.
- [x] Migration 370 APLICADA em 16/11/2026 (47 produtos alinhados, 0 divergentes, função do Ubiqua lendo estoque_itens).
- [ ] Decidir as 15 diferenças de estoque geral e 1 de showroom contra a Connect (ajuste real de saldo, decisão do usuário).

## Objetivo

O saldo real do sistema mora em `estoque_itens` (local Estoque) e em `produtos.estoque_showroom`. A coluna antiga `produtos.estoque_total/estoque_disponivel` ficou parada em 47 produtos (entrada de NF e venda atualizam `estoque_itens`, não ela). Tudo que lê estoque deve ler do local certo.

## O que a migration 370 faz

1. `ubiqua_estoque_atual()` passa a ler `estoque_itens` (geral + showroom − reservado, a mesma conta da Connect) em vez de `produtos.estoque_disponivel`. No ensaio nenhuma das 77 referências mudou de valor hoje.
2. Alinha `produtos.estoque_total` e `estoque_disponivel` dos 47 produtos desatualizados ao `estoque_itens`. Backup em `backup._bkp_spec310_produtos_estoque_antigo`.

## Fora do escopo (decisão do usuário)

Ajustar o saldo real dos 15 produtos que divergem da Connect (ex.: 7449-S-PM com 46 a menos) e o showroom do 321403-IS.

## Rollback

`supabase/db/migrations/20261116_370_spec310_estoque_ler_do_local_certo/rollback.sql`.
