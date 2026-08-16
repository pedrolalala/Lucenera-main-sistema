---
titulo: "SPEC-110 — Sinal/Desconto: posição visual trocada + sinal pré-preenchido por cliente/projeto"
status: concluído
data_ultima_modificacao: 2026-08-15
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb, Skip 32554) — `BudgetFormPage.tsx`
dependencias:
  - SPEC-068 (sinal como valor fixo em R$)
  - SPEC-078 (ordem de cálculo subtotal→sinal→desconto)
---

# SPEC-110 — Sinal/Desconto: posição visual trocada + sinal pré-preenchido

> Origem: reunião Vinícius 14/08/2026 ([23:24]-[24:54]).

## Objetivo

1. Investigar/corrigir: campos "Sinal" e "Desconto" parecem estar na posição visual trocada na tela ("o sinal em cima e o desconto embaixo", ao contrário do esperado).
2. Quando houver um valor de sinal padrão vinculado ao cliente/projeto, o campo deveria vir pré-preenchido (mas continuar editável/opcional).

## Definição da SPEC

### Estado atual confirmado no código

`BudgetFormPage.tsx`:
- A **lógica de cálculo já está correta**, confirmada por comentário explícito da SPEC-078 (linha 693-699): ordem é subtotal → sinal → desconto (o desconto incide sobre o valor **já** descontado o sinal, `valorAposSinal = subtotal - sinal`). Não há bug de cálculo aqui — o cálculo bate com o que o próprio Vinícius validou como certo na reunião ("Não, pode deixar, não tem problema").
- **Não confirmado nesta investigação**: a ordem visual exata dos dois campos na tela (`valor_sinal` vs `desconto_global`) — não consegui achar o trecho de JSX que renderiza os dois lado a lado/um sobre o outro nesta busca. Precisa de leitura direcionada do formulário (provavelmente na seção de totais/pagamento) ou reprodução visual ao vivo pra confirmar exatamente qual campo está onde.
- **Sinal pré-preenchido por cliente/projeto**: não encontrei nenhum campo `sinal_padrao`/`valor_sinal_padrao` em `contatos` ou `projetos` nesta investigação — não existe hoje.

### Proposta (não implementar sem aprovação)

1. Confirmar ao vivo (não achei no código) qual campo está fisicamente acima do outro, e inverter a posição visual — sem mexer na lógica de cálculo, que já está certa.
2. Para o pré-preenchimento: adicionar um campo `valor_sinal_padrao` em `contatos` (cliente) ou `projetos` — a confirmar qual dos dois faz mais sentido (Vinícius mencionou os dois: "vinculado ao cliente e ao projeto"). Ao selecionar cliente/projeto no orçamento, se esse valor existir, pré-preencher `valor_sinal` (editável).

## Análise de ecossistema

- **Depende de**: `contatos` ou `projetos` (novo campo, a decidir), `orcamentos.valor_sinal`.
- **Afeta**: só o formulário de orçamento.

## Realizado

### 2026-08-15

- **P-1 resolvida**: existem DOIS pares Sinal/Desconto na tela — os campos editáveis (já mostravam Desconto Global antes de Sinal, ordem correta) e o resumo de totais à direita (mostrava Sinal antes de Desconto, seguindo a ordem do CÁLCULO por decisão da SPEC-078, não a ordem visual dos campos). Essa inconsistência entre os dois blocos era a real causa da confusão. Fix: resumo passou a mostrar Desconto antes de Sinal também, igual aos campos — o cálculo em si (sinal deduzido antes do desconto) não mudou, só a ordem das linhas exibidas.
- **P-2 resolvida (decisão própria)**: sinal padrão implementado a nível de CLIENTE (`contatos.valor_sinal_padrao`, migration aplicada), não por projeto — reutilizável entre todos os projetos do mesmo cliente. `BudgetFormPage.tsx`: ao selecionar um cliente numa criação de orçamento nova (não em edição), se o cliente tiver um valor cadastrado e o campo Sinal ainda estiver em zero, pré-preenche — continua 100% editável.
- **Achado/limite honesto**: não existe ainda campo na UI do CRM (Cadastro de Cliente) pra definir `valor_sinal_padrao` — por ora só é setável direto no banco. O pré-preenchimento já funciona ponta a ponta assim que o valor existir; adicionar o campo no formulário de cliente do CRM fica como próximo passo pequeno, não implementado nesta rodada (app CRM separado, escopo à parte).
- Publicado Skip 32554 v0.0.344. Testado ao vivo: setei `valor_sinal_padrao = 555.55` num cliente de teste (revertido em seguida), abri "Novo Orçamento" → selecionei o projeto desse cliente → campo Sinal veio preenchido com 555.55 automaticamente; resumo mostrou "Desconto global → Sinal" na ordem nova.

## Pendências

- [ ] Adicionar campo "Sinal padrão (R$)" na tela de Cadastro de Cliente do CRM — hoje só é setável direto no banco.
