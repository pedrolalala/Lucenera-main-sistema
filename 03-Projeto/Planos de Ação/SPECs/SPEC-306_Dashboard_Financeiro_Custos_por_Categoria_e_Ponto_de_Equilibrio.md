# SPEC-306 — Dashboard Financeiro: custos por categoria e Ponto de Equilíbrio real

> Nota de numeração: o Filippo chamou este trabalho de "SPEC-286" no PDF/patch (o commit do dashboard diz SPEC-286). O número 286 já pertence à SPEC de Compras (condição de pagamento); esta é a SPEC-306.

- Data: 14/11/2026
- Autor da mudança: Filippo (conta `filippogiorgibrasil`), aprovada por ele na tela
- Sistema: `04-Sistemas/dashboard-lucenera-b02z85wa3` (tela "Fluxo de Caixa Realizado")
- Commit: `18b37ba` (main, pushado em 14/11, base `d062586`)

## O que muda
- **Ponto de Equilíbrio**: quanto receber por mês para ficar no zero = (custos fixos + distribuição de lucro) ÷ margem de contribuição, sobre os últimos 12 meses fechados. Antes era só receita − custo fixo.
- **Custo Operacional**: pizzas maiores (nome e % fora da fatia, legenda ao lado), pizza nova "Por categoria" e lista das categorias com valor, % do custo, % da receita e o que compõe cada uma.
- **Fixo × Variável**: classificação feita na tela, pela apropriação. Prêmio de vendas vira variável; aluguel e despesas dos sócios deixam de cair em "outro".
- **Saldo Acumulado e Resultado Diário**: eixo de valores da esquerda não corta mais os números (formato curto: "250 mil", "1,2 mi").

## O que não muda
Nada no banco (sem migration, view ou função). Nenhuma dependência nova. Só `src/pages/Index.tsx` e `src/services/cash-flow.ts`.

## Verificação
- `npm run build` sem erro (14/11). `tsc` acusa erros antigos em `src/services/estoque.ts` (view `v_estoque_produtos`), fora do patch.
- Segundo o Filippo: categorias somam a Despesa Operacional jan–out/2026 (R$ 11.710.593); ponto de equilíbrio nov/2025–out/2026 ≈ R$ 1,43 mi/mês contra R$ 1,24 mi recebido.
- Pendente: conferência visual do usuário em dashboard-lucenera.pages.dev após o deploy do Cloudflare Pages.

## Acesso
`filippogiorgibrasil` convidado como colaborador (write) do repositório do dashboard em 14/11; convite pendente de aceite.
