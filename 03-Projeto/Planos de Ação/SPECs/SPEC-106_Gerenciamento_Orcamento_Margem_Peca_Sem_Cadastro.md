---
titulo: "SPEC-106 — Gerenciamento do Orçamento: margem padrão pra peça sem cadastro + campos novos (Imposto/RT/Comissão)"
status: parcial — falta definição de negócio
data_ultima_modificacao: 2026-08-15
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb, Skip 32554) — `GerenciamentoDialog.tsx`
dependencias:
  - SPEC-083 (criou esse painel admin — "Gerenciamento do Orçamento", custo/lucro por peça + desconto simulado)
---

# SPEC-106 — Gerenciamento do Orçamento: margem padrão pra peça sem cadastro + campos novos

> Origem: reunião Vinícius 14/08/2026 ([00:13]-[11:15]). Todos os pontos abaixo são sobre o mesmo painel: "Gerenciamento do Orçamento" (`GerenciamentoDialog.tsx`, aberto pelos "três pontinhos" no orçamento — confirmado que é exatamente o painel da SPEC-083).

## Objetivo

1. Quando uma peça sem cadastro (item avulso) não tem custo informado ainda, a % de lucro exibida deve começar em 50% (não 100%) — hoje o custo default é 0, o que faz `lucroPct = 100%` e "mascara" a leitura do orçamento.
2. Investigar suspeita de bug: dois produtos com custo bem diferente pareciam mostrar a mesma % de margem na tela — achado técnico abaixo aponta pra dado de custo faltando no cadastro, não bug de cálculo.
3. Não arredondar a % — usar valor exato.
4. Renomear "Total preço de custo" → "Lucro Bruto"; adicionar novos campos, visíveis só pra admin (Vinícius + Filipe): Imposto, RT, Comissões, calculados a partir do desconto definido.

## Definição da SPEC

### Estado atual confirmado no código

`04-Sistemas/gestao-financeira-clone-544cb (1)/src/components/budgets/GerenciamentoDialog.tsx` (SPEC-083):

- **Ponto 1 — confirmado, causa exata**: linha 98-100, `custoUnitario = isAvulso ? (custosManuais[key] ?? 0) : custosProdutos[...]`. Pra item avulso (sem `produto_id`), o custo começa em `0` até o usuário digitar manualmente na tabela desta tela. Com custo 0, `lucroPct = (vendaTotal - 0) / vendaTotal * 100 = 100%` (linha 106) — bate exatamente com a reclamação.
- **Ponto 2 — não é bug de cálculo**: cada linha calcula sua própria `lucroPct` individualmente a partir de `produtos.preco_custo` do respectivo `produto_id` (linha 81-90, busca em lote por `id, preco_custo`). Não há nenhum valor fixo compartilhado entre itens. A explicação mais provável pro que o Vinícius viu (duas peças bem diferentes com % parecida) é **dado de custo ausente ou igual por coincidência** em `produtos.preco_custo` pra aqueles produtos específicos — não uma fórmula errada. Precisa confirmar nos produtos específicos citados na reunião (lâmpada vs. luminária Interlight) se `preco_custo` está preenchido corretamente pra ambos.
- **Ponto 3 — já parcialmente atendido**: linha 221, `{l.lucroPct.toFixed(1)}%` — já mostra 1 casa decimal, não arredonda pro inteiro mais próximo. Se o usuário ainda vê "60%" redondo ao vivo, pode ser um valor genuinamente próximo de 60 (ex.: 59,95% → "60.0%") ou uma versão publicada antes desse comportamento — vale reconfirmar ao vivo antes de mexer.
- **Ponto 4**: o painel já é 100% admin-only por natureza (SPEC-083, "Gerenciamento do Orçamento"), já mostra Custo/Lucro/Lucro% por peça e tem desconto simulado. Faltam: renomear rótulo, e os 3 campos novos (Imposto, RT, Comissão) — nenhum desses 3 valores foi encontrado calculado em lugar nenhum do sistema nesta investigação; provavelmente são % fixas configuráveis (a confirmar de onde vêm).

### Proposta (não implementar sem aprovação)

1. Trocar o default de `custosManuais[key]` de `0` pra `vendaUnit * 0.5` quando ainda não há valor manual digitado (mantém editável).
2. Não mexer no cálculo do ponto 2 — só confirmar dado de cadastro dos produtos citados.
3. Manter `.toFixed(1)` (já correto) — reconfirmar ao vivo se ainda "parece" arredondar.
4. Renomear label + adicionar 3 campos novos (Imposto/RT/Comissão) na mesma tabela/resumo do diálogo — fórmula de cada um é pendência (ver abaixo).

## Análise de ecossistema

- **Depende de**: `produtos.preco_custo`, itens do orçamento (avulsos e cadastrados).
- **Afeta**: só este painel admin. Não muda nada visível pras vendedoras.

## Realizado

### 2026-08-15

- **Ponto 1 implementado**: item avulso sem custo digitado agora começa em 50% de margem (custo default = `vendaUnitComDesconto * 0.5`), não mais 0% de custo / 100% de lucro. Continua editável — assim que a pessoa digita um custo real, o padrão de 50% é substituído.
- **Ponto 3 confirmado por leitura de código, sem mudança necessária**: `l.lucroPct.toFixed(1)}%` já usa 1 casa decimal, não arredonda pro inteiro mais próximo — se ainda parecer arredondado ao vivo, é porque o valor real está genuinamente perto de um número redondo (ex.: 59,95% → "60.0%"), não um bug de arredondamento.
- Publicado Skip 32554 v0.0.346 — QA limpo. Não testado clicando de verdade: o painel só abre a partir de um orçamento real já em "Aprovação Financeira" (SPEC-083); é uma mudança de matemática pura e de baixo risco (custo = 50% da venda ⇒ lucro % = 50%, verificável por inspeção), risco de regressão mínimo.

## Pendências

- [ ] **Ponto 4 (Imposto/RT/Comissão) — não implementado, precisa de você**: não existe essas 3 fórmulas em nenhum lugar do sistema. Preciso que você defina o cálculo de cada uma (Imposto, RT, Comissão) antes de eu adicionar os campos — inventar uma fórmula aqui mostraria número financeiro errado pra quem usa o painel.
- [ ] Ponto 2 (dois produtos com % parecida): não é bug de cálculo (cada linha usa seu próprio `produtos.preco_custo`, sem valor compartilhado) — só falta confirmar se os produtos específicos citados na reunião (lâmpada vs. Interlight) têm `preco_custo` preenchido corretamente; não tenho os nomes exatos desses produtos pra investigar sem você.
