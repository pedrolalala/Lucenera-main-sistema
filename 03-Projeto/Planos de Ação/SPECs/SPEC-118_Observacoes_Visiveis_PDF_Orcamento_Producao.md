---
titulo: "SPEC-118 — Observações do orçamento visíveis no PDF enviado para produção/separação"
status: proposta
data_ultima_modificacao: 2026-08-21
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb, Skip 32554) — Edge Function `generate-report` (reportType 'orcamento')
dependencias:
  - SPEC-112 (destaque visual de observações — já concluída, mas cobre só as *listagens* internas do Orçamentos, não o PDF que sai do sistema)
---

# SPEC-118 — Observações do orçamento visíveis no PDF enviado para produção/separação

> Origem: reunião Vinícius 21/08/2026 ("Venda Real e aplicações no sistema"), [00:04]-[01:38].

## Objetivo

Fazer o campo "Observações" do orçamento aparecer de forma destacada no PDF gerado pelo sistema (o mesmo documento usado hoje, no sistema legado, para instruir a produção) — para que informações operacionais críticas (ex.: "L5 e L6 fixado na laje") não se percam entre a venda e quem fabrica a peça.

## Contexto (por que isso importa)

Vinícius mostrou, ao vivo, uma venda real no sistema legado (Connect/Citel): o orçamento que a Thaís recebeu do cliente tinha uma observação de instalação ("L5 e L6 fixado na laje") — informação necessária pra Débora montar o pedido de produção e o Cláudio fabricar a peça corretamente. Citação ([00:04]): *"se a gente vai automatizar e, na teoria, evitar diminuir a comunicação, tentar fazer algo bem elaborado para que isso seja visível e que não esqueçam de colocar."*

Isso é diferente do que a SPEC-112 já resolveu: aquela SPEC destacou `observacoes` nas **listagens internas** do Orçamentos Lucenera (`BudgetTableRow.tsx` e `ProjectOrcamentoList.tsx`) — bom para o vendedor não esquecer de olhar a própria observação. Mas o documento que efetivamente **sai do sistema** e chega em quem produz é o PDF gerado por `generate-report` (reportType `'orcamento'`) — e esse PDF nunca leu `observacoes`.

## Estado atual confirmado no código

- `orcamentos.observacoes` existe (text, opcional) e é gravado normalmente pelo formulário (`BudgetFormPage.tsx`).
- `supabase/functions/generate-report/index.ts`, query da linha ~114-127, usa `select('*, ...')` no `orcamentos` — ou seja, `budget.observacoes` **já chega** na função, só nunca é desenhado no PDF.
- Busca por `observacoes`/`observação` em todo `generate-report/index.ts`: **zero ocorrências**. O campo é buscado do banco e descartado.
- `FiscalSummaryDialog.tsx` ("Resumo Fiscal", ícone ao lado do orçamento) é uma tela **diferente**, focada em CFOP/valores pra emissão fiscal — não é o documento de produção/separação e também não mostra `observacoes`, mas não é o alvo principal desta SPEC (ver "Fora de escopo").

## Proposta (não implementar sem aprovação)

1. Em `generate-report/index.ts`, no fluxo `reportType === 'orcamento'`, adicionar uma seção visível no PDF quando `budget.observacoes` for não-vazio — por exemplo, um bloco com fundo destacado (cor sólida, não só uma linha de texto perdida) logo após os dados do cliente/itens, com um rótulo claro tipo "OBSERVAÇÕES / ATENÇÃO PRODUÇÃO".
2. Quando `observacoes` estiver vazio, a seção simplesmente não aparece (sem espaço em branco desnecessário).
3. Não alterar o campo em si nem sua edição — só a renderização no PDF.

## Fora de escopo

- `FiscalSummaryDialog.tsx` ("Resumo Fiscal") — é outro documento, com outra finalidade (fiscal/CFOP). Se o usuário quiser observações lá também, é uma extensão separada, a confirmar.
- Qualquer alteração de regra de negócio sobre quando uma observação é obrigatória — este SPEC é só sobre visibilidade do que já existe.

## Análise de ecossistema

- **Depende de**: `orcamentos.observacoes` (já existe, já é buscado pela Edge Function).
- **Afeta**: só o layout do PDF gerado (`generate-report`). Zero risco de regra de negócio, zero migration.

## Pendências

- [ ] Confirmar com o usuário se o rótulo/estilo proposto ("OBSERVAÇÕES / ATENÇÃO PRODUÇÃO", bloco destacado) atende, ou se ele quer algo mais próximo do padrão visual já aprovado na SPEC-112 (borda laranja).
