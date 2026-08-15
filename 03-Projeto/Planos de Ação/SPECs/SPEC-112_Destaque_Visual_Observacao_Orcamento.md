---
titulo: "SPEC-112 — Destaque visual (card laranja) quando o orçamento tem observação preenchida"
status: concluído
data_ultima_modificacao: 2026-08-15
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb, Skip 32554) — `ProjectOrcamentoList.tsx`, `BudgetFormPage.tsx`
dependencias:
  - SPEC-111 (mesmo bloco da reunião — reset de aprovação, [39:58]-[43:12])
---

# SPEC-112 — Destaque visual quando o orçamento tem observação preenchida

> Origem: reunião Vinícius 14/08/2026 ([44:52]-[46:46]).

## Objetivo

Quando um orçamento tem o campo "Observações" preenchido, destacar isso visualmente na listagem/card do orçamento — hoje a observação existe mas fica "escondida" dentro da edição, ninguém é avisado que precisa ler.

## Contexto (por que isso importa)

Vem na sequência direta da SPEC-111 (mesmo teste ao vivo): o caso concreto que motivou o pedido é comunicação de qual empresa faturar. Exemplo citado ([43:19]-[44:40]): o orçamento começou vinculado à empresa "Manoela" mas o Vinícius já tinha combinado verbalmente com o cliente que a venda seria faturada pela "Foco"/"e-Flight" — como ninguém atualizou o campo nem deixou registrado em lugar visível, a informação se perdeu e o orçamento saiu errado. Solução proposta pelo próprio Vinícius: usar o campo "Observações" pra registrar esse tipo de decisão, e fazer esse campo "saltar aos olhos" quando preenchido — citação ([45:38]-[46:09]): *"eu acho que eu vou colocar que todos que tiverem uma observação, ele fica igual... um cardzinho em volta, laranja... fica destacado quando tem alguma observação, porque a observação é... porque alguma coisa tem que ser levada em consideração."* Ele mesmo referencia o padrão visual que já existe no sistema de Logística (cards com borda colorida) como modelo a copiar.

## Estado atual confirmado no código

- `orcamentos.observacoes` já existe como campo (text, opcional) e já é editável em `BudgetFormPage.tsx` (linha 2937-2943, textarea "Observações").
- `ProjectOrcamentoList.tsx` (linha 28) já renderiza cada orçamento como um card (`rounded-lg border overflow-hidden`) dentro da tela do projeto/cliente — é o lugar natural pra aplicar o destaque condicional.
- Não encontrado, nesta investigação, nenhum destaque condicional hoje baseado em `observacoes` — o campo é 100% "silencioso" fora da tela de edição.
- Padrão de referência citado pelo usuário (card laranja de Logística) não foi confirmado nesta investigação (sistema diferente, não lido nesta rodada) — usar como inspiração de estilo, não copiar código diretamente.

## Proposta (não implementar sem aprovação)

1. Em `ProjectOrcamentoList.tsx` (e em qualquer outra listagem de orçamentos que exista, ex. dashboard/pipeline — a confirmar), quando `orc.observacoes` for não-vazio, aplicar destaque visual: borda laranja (`border-orange-400` ou similar) + ícone de alerta/observação no cabeçalho do card.
2. Opcional (não pedido explicitamente, mas coerente): tooltip ou preview do texto da observação ao passar o mouse no ícone, sem precisar abrir a edição completa.
3. Não alterar o comportamento do campo em si (continua opcional, continua editável por qualquer perfil com acesso ao orçamento) — só a visibilidade na listagem.

## Análise de ecossistema

- **Depende de**: `orcamentos.observacoes` (já existe).
- **Afeta**: só a camada visual de listagem de orçamentos. Zero risco de regra de negócio.

## Realizado

### 2026-08-15

- **P-1 resolvida sem precisar perguntar**: achado que ampliou o escopo original — além de `ProjectOrcamentoList.tsx` (proposto na SPEC), existe uma listagem principal muito mais visível, `BudgetsTable.tsx`/`BudgetTableRow.tsx` (a tela "Orçamentos" que todo mundo usa no dia a dia, era a mesma testada na SPEC-100). Como o objetivo do usuário é literalmente "não deixar passar batido", ficaria incompleto destacar só a lista secundária (dentro do detalhe de projeto) e deixar a lista principal sem nada — os dois lugares receberam o destaque.
- **P-2 resolvida**: destaque permanente enquanto `observacoes` estiver preenchido (leitura padrão da SPEC) — sem mecanismo de "marcar como lido", que exigiria campo novo no banco (mudança de escopo maior).
- `BudgetTableRow.tsx` (listagem principal): linha ganha `border-l-4 border-l-orange-400` + fundo `bg-orange-50/40`, e um ícone `MessageSquare` laranja ao lado do código com `title={observacoes}` (preview nativo no hover).
- `ProjectOrcamentoList.tsx` (dentro do projeto): card ganha borda laranja (`border-orange-400 border-2`) + mesmo ícone com preview. Precisou adicionar `observacoes` em `OrcamentoDetail`/`projectFinancialApprovalService.ts` (não vinha selecionado antes).
- Publicado Skip 32554 v0.0.340 — QA limpo. Testado ao vivo: setei uma observação de teste num orçamento real (revertido em seguida), confirmei via `javascript_tool` que a linha ganhou a borda laranja e o ícone com o texto certo no `title`, depois revertido pro estado original (`observacoes = NULL`).

## Pendências

Nenhuma.
