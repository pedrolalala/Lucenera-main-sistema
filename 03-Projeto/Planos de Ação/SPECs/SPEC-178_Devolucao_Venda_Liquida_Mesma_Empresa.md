---
titulo: "SPEC-178 — Devolução: colunas na ordem certa, valor líquido da venda, mesma empresa e vínculo com venda efetivada"
status: publicada (Orçamentos 32554 v0.0.379 — 02/10), aguardando teste
data_ultima_modificacao: 2026-10-02
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb) — rotina de devolução (natureza_operacao = 'devolucao')
dependencias:
  - SPEC-071 (devolução a partir de venda de origem — projeto_item_origem_id)
  - SPEC-105 (busca da venda de origem por cliente OU projeto)
  - SPEC-068 / SPEC-078 (desconto global % ou R$, aplicado após o sinal)
  - SPEC-136 (número da venda)
  - SPEC-177 (formulário em abas)
---

# SPEC-178 — Devolução: valor líquido, mesma empresa e vínculo com venda efetivada

Pedido do administrador repassado pelo usuário em 02/10/2026.

## Achados no banco (02/10)

- VENDA-0001 (ORC-0032, FOCO ILUMINACAO): subtotal R$ 17.686,30, `desconto_global` 8 (`percentual`), total
  R$ 16.271,40. Os itens (`projeto_itens.desconto`) têm desconto 0 — o desconto está só no orçamento.
- A devolução copiava `projeto_itens.preco_unitario` e `projeto_itens.desconto` (0) → valor cheio (R$ 4.031,21).
- ORC-0036 é devolução da MANOELLA com item da VENDA-0001 (FOCO) — combinação proibida, já gravada.

## Alterações

1. **Tela "Buscar Venda de Origem"** (`src/components/budgets/DevolucaoItemSearchModal.tsx`): colunas
   L / Código / Referência / Descrição / Nº da Venda / Qtd. da Venda / A Devolver. "A Devolver" é a quantidade
   digitada (última coluna); maior que zero seleciona a linha e não passa do disponível (mostrado sob a Qtd. da
   Venda). Mostra o número da VENDA, não o do orçamento. Abaixo da descrição: preço, desconto da venda e valor
   líquido unitário.
2. **Valor líquido** (`src/services/devolucoesService.ts` + `applyDevolucaoSelection` em `BudgetFormPage.tsx`):
   preço da linha de devolução = preço × (1 − desconto do item) × (1 − desconto global da venda), em centavos;
   desconto da linha = 0. Desconto global em R$ vira % sobre (subtotal − sinal), igual ao formulário.
   Ex.: R$ 4.031,21 com 8% → R$ 3.708,71.
3. **A venda dita a empresa** (decisão do usuário, 02/10: "a devolução deve buscar uma venda ... tudo atrelado
   àquela venda é vinculado"): na primeira seleção a devolução copia da venda de origem a **empresa**, o
   **vendedor** e os **arquitetos**; depois disso o campo Empresa fica travado ("Definida pela venda de origem")
   e o modal só deixa escolher itens de vendas da mesma empresa (os de outra empresa aparecem bloqueados).
4. **Só venda efetivada**: a busca descarta linhas sem número de venda.
5. **Conferência ao salvar** (`validarItensDevolucao`): toda linha precisa vir de venda com número, da mesma
   empresa da devolução e sem passar do disponível. Se falhar, não salva e mostra o motivo.

Sem migration. Sem mudança em venda, aprovação, nota fiscal ou boleto.

## Decisões do usuário (02/10)

- Sem trava no banco: a regra vem do próprio fluxo (a devolução nasce da venda e herda empresa/equipe).
- ORC-0036 era teste: **cancelado** (status `cancelado`, dry-run com ROLLBACK antes; sem boletos nem projeto_itens).

## Pontos em aberto

- Devolução já lançada antes desta SPEC mantém o valor cheio até os itens serem lançados de novo (hoje não há
  nenhuma ativa — a única, ORC-0036, foi cancelada).
