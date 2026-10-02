---
titulo: "SPEC-177 — Orçamento em 3 abas e destaque do que já está preenchido (arquiteto visível)"
status: publicado (Orçamentos Skip 32554 v0.0.378 — 02/10), aguardando teste
data_ultima_modificacao: 2026-10-02
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb) — formulário de orçamento (venda e devolução) e listagem
dependencias:
  - SPEC-077 (arquitetos múltiplos com percentual — orcamento_arquitetos)
  - SPEC-071 (devolução no mesmo formulário)
  - SPEC-110 (ordem das linhas do resumo de totais)
  - SPEC-174 N5/N6 (padrão visual do Cadastro: rótulo discreto, valor em destaque)
---

# SPEC-177 — Orçamento em 3 abas e destaque do que já está preenchido

Pedido do administrador repassado pelo usuário em 02/10/2026. Só exibição e usabilidade: sem mudança de banco,
RPC, cálculo, validação ou fluxo de aprovação.

## Problema

Ao simular uma devolução de venda (ORC-0036, arquiteta Cacau Ribeiro), o administrador não percebeu que a
arquiteta já estava vinculada. Causa: no `ArchitectSplitPicker` o campo vazio "Adicionar arquiteto..." aparece
primeiro, como caixa grande, e o arquiteto já vinculado fica embaixo em texto pequeno e comum. O mesmo padrão
(vazio chama atenção, preenchido não) se repete no resto da tela. Dados conferidos no banco: o vínculo existe.

## Decisões confirmadas com o usuário (02/10)

- Resumo de valores (subtotal, desconto, sinal, frete, valor total) vira **barra fixa no rodapé**, visível em todas
  as abas; os campos de pagamento ficam na aba 3. Cálculo e ordem das linhas (SPEC-110) não mudam.
- Referência visual: padrão do Cadastro (rótulo pequeno e discreto, valor preenchido em destaque, grupos em cards).

## Alterações (`src/pages/BudgetFormPage.tsx`, `src/components/ArchitectSplitPicker.tsx`, `src/index.css`,
`src/components/budgets/BudgetTableRow.tsx`)

1. **Resumo no topo** (acima das abas, visível sempre): Cliente, Projeto, Arquiteto(s) com %, Vendedor, Empresa e
   Previsão de entrega. Valor preenchido em negrito escuro; vazio em cinza claro "Não informado".
2. **3 abas**: "Dados do Cliente / Arquiteto" (tipo de operação, empresa, perfil, projeto, cliente, arquiteto,
   vendedor, datas), "Produtos" (itens) e "Condição de Pagamento" (forma, parcelas, frete, desconto, sinal,
   observações). Abas ficam montadas (só escondidas) para não perder estado; ao salvar com erro, abre a aba do
   primeiro campo com problema. Aba Produtos mostra a quantidade de itens.
3. **Destaque do preenchido** no formulário: campo com valor fica em negrito/escuro; campo vazio com placeholder
   cinza normal (CSS escopado à página, sem mudar componentes compartilhados).
4. **Arquiteto**: arquitetos vinculados aparecem primeiro, em destaque (card com nome em negrito e %); o campo de
   busca vem depois, discreto, como "Adicionar outro arquiteto...".
5. **Listagem**: coluna Arquiteto mostra todos os arquitetos da divisão (SPEC-077), não só o principal.

## Critério de aceite

- Abrir ORC-0036 (devolução) e ORC-0032: "CACAU RIBEIRO" aparece no resumo do topo e em destaque na aba 1.
- Salvar com campo obrigatório vazio em outra aba leva para a aba certa.
- Totais idênticos aos de antes, sempre visíveis.

## Rollback

Reverter o commit do sistema e republicar a versão anterior no Skip (32554).
