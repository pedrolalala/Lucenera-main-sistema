---
titulo: "SPEC-286 — Dashboard Financeiro: custos por categoria e ponto de equilíbrio real"
status: concluído
data_ultima_modificacao: 2026-11-14
sistemas_envolvidos:
  - Dashboard Financeiro (dashboard-lucenera-b02z85wa3)
---

# SPEC-286 — Dashboard Financeiro: custos por categoria e ponto de equilíbrio real

## Checklist de Ação

- [x] Classificar cada despesa em uma categoria de custo (`src/services/cash-flow.ts`)
- [x] Gráfico de pizza "Custos por categoria" no cartão Custo Operacional (`src/pages/Index.tsx`)
- [x] Lista das categorias abaixo do gráfico (valor, % do custo, % da receita, o que compõe)
- [x] Ponto de equilíbrio recalculado: receita necessária para cobrir custos fixos + distribuição de lucro
- [x] Pizza Fixo × Variável passa a usar a mesma classificação do ponto de equilíbrio
- [x] Eixo de valores dos gráficos Saldo Acumulado e Resultado Diário sem corte

### Passos manuais do usuário

- [x] Filippo confere a tela (exige login) — conferido e aprovado em 14/11
- [x] Autorizar a publicação — autorizado em 14/11
- [x] Pedro aplicou o commit na main do sistema: `18b37ba`, mesmo conteúdo do `f75cd26`. No ar pelo Cloudflare Pages (Filippo confirmou em 14/11).

## Objetivo

Pedido do Filippo em 13/11/2026, depois da análise financeira do ano:

1. Ver sempre, com dados ao vivo, os custos divididos por categoria (pizza + lista).
2. Corrigir o Ponto de Equilíbrio. O cálculo atual (reunião 13/07) é `receita − custo fixo`: diz só se a receita passou do custo fixo. Não é ponto de equilíbrio, porque ignora que de cada real recebido só uma parte sobra para pagar o custo fixo.
3. Os gráficos Saldo Acumulado e Resultado Diário cortam os números do eixo da esquerda.

## Decisões aprovadas

- Ponto de equilíbrio = quanto é preciso receber no período para ficar no zero, cobrindo **todos** os custos reais, inclusive a distribuição de lucro (é o que os sócios retiram para viver).
- A margem usada é a real do período, não uma margem teórica.
- Sem mudança no banco: tudo é calculado na tela a partir de `v_financeiro_realizado_novo`.
- (13/11, depois do primeiro teste do Filippo) O ponto de equilíbrio usa sempre os **últimos 12 meses fechados** e mostra o valor **por mês**; não segue o filtro de período. No mês em andamento a conta não fecha (em novembro/2026 parcial os custos variáveis passavam da receita e o cartão ficava em "—").

## Definição da SPEC

### Fórmula

```
margem de contribuição = (receita − custos variáveis) / receita
receita de equilíbrio  = (custos fixos + distribuição de lucro) / margem de contribuição
```

- Base caixa, como o resto da tela: receita = recebido no período; custo = pago no período.
- Distribuição de lucro só chega à tela para quem tem `pode_ver_distribuicao_lucro`. Para os demais o cartão calcula sem ela e avisa.
- Sem receita ou com margem ≤ 0 no período, o cartão mostra "—".

### Categorias (pela apropriação; o sub-grupo decide o que não está na lista)

| Categoria | Tipo | Apropriações |
| --- | --- | --- |
| Produtos | variável | COMPRAS - REVENDA, INDUSTRIALIZAÇÃO, IMPORTAÇÃO, SINAL DE COMPRA |
| Impostos sobre vendas | variável | DAS NACIONAL, DARE-ICMS, COFINS, PIS, IRPJ, CSLL, ISSQN |
| Comissões da equipe | variável | PRÊMIO DE VENDAS |
| RT e pontos de arquitetos | variável | RT, CLUBE MAIS PONTOS |
| Fretes | variável | FRETE ENTRADA, FRETE SAÍDA, CORREIOS, TAXIS / FRETES ADM |
| Pessoal | fixo | demais itens do sub-grupo COM PESSOAL |
| Estrutura | fixo | ALUGUEL e sub-grupos ADMINISTRATIVAS, FIXAS, BANCARIAS |
| Veículos | fixo | sub-grupo VEICULOS |
| Marketing | fixo | PUBLICIDADE, CLUBE MAIS MENSAL |
| Despesas dos sócios | fixo | sub-grupo OPERACIONAL (DESP. OPERAC. MANOELLA/FILIPPO) |
| Investimentos | fixo | grupo INVESTIMENTOS |
| Outros | fixo | o que não se encaixar |

Mudanças em relação à classificação antiga (`tipo_custo` da view, "pendente de validação"): PRÊMIO DE VENDAS deixa de ser fixo; ALUGUEL e despesas dos sócios deixam de ser "outro"; PUBLICIDADE e CLUBE MAIS MENSAL deixam de ser variáveis.

### Conferência (jan–out/2026, calculada no banco)

- Receita 11.728.517; variáveis 8.356.413; margem 28,8%.
- Fixos 3.354.180; distribuição 794.612.
- Receita de equilíbrio ≈ 14,43 milhões no período (≈ 1,44 milhão/mês) contra 1,17 milhão/mês recebido.

Com a janela de 12 meses (nov/2025–out/2026): receita 14.884.623; variáveis 9.743.115; margem 34,5%; fixos 4.078.345; distribuição 1.846.501; equilíbrio ≈ 1,43 milhão/mês contra 1,24 milhão/mês recebido.

### Critérios de aceite

- Soma das categorias = "Despesa Operacional Total" do período.
- Clique na pizza Fixo × Variável continua filtrando Despesa Operacional e fluxo diário.
- Eixo esquerdo dos dois gráficos mostra os valores inteiros (formato curto: "250 mil", "1,2 mi").
- `pnpm build` sem erros.

## Realizado

### 2026-11-13

- Código implementado no branch `spec/286-custos-categoria-ponto-equilibrio` do sistema; não publicado.
- Classificação conferida no banco: as categorias somam 11.710.593, igual à Despesa Operacional de jan–out/2026.
- Build rodou sem erro (Node baixado para pasta temporária). Os 6 erros de tipo que o `tsc` aponta são de outros arquivos e já existiam.

### 2026-11-14

- Pizzas maiores, com rótulo fora da fatia e legenda ao lado (pedido do Filippo). Tela conferida no navegador; build e lint sem erro.
- Commit local `f75cd26` no branch `spec/286-custos-categoria-ponto-equilibrio`. Push recusado por falta de permissão; não está no ar.

## Pendências

- [x] Publicar a SPEC-286: o Pedro aplicou o patch, commit `18b37ba` na `main` do sistema. Ponteiro do submodule atualizado no repo central.
- [ ] Permissão de escrita da conta `filippogiorgibrasil` nos repositórios dos sistemas, para as próximas publicações não dependerem do Pedro.
- [ ] Validar com o Filippo se Investimentos e Despesas dos sócios devem contar como custo fixo no ponto de equilíbrio (hoje contam).
- [ ] ALUGUEL mistura imóvel do estoque (M G Administradora) e veículos (Localiza): a view não traz o favorecido, então fica tudo em Estrutura.
