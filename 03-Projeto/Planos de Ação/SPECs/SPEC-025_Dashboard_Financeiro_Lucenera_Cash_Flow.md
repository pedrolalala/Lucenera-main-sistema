---
titulo: "SPEC-025 — Dashboard Financeiro Lucenera (recriação do relatório Power BI)"
status: pendente
data_ultima_modificacao: 2026-07-14
sistemas_envolvidos:
  - Skip Cloud — "Dashboard Lucenera" (projeto id 41135, host dashboard-empresa-40d7d.goskip.app)
  - Banco central (Supabase) — transacoes, negociacoes, plano_de_contas, empresas, v_financeiro_realizado, stg_duplicatas_vigentes
dependencias:
  - Skip Cloud — "Central Lucenera" (projeto id 37750) — paleta de cores base
  - Skip Cloud — "Fluxo de Caixa Lucenera" (id 33151) e "Dashboard Lucenera" (id 33127) — protótipos anteriores com mock data, não publicados, servem de referência de layout
---

# SPEC-025 — Dashboard Financeiro Lucenera (recriação do relatório Power BI)

> Recriar como sistema web (Skip Cloud) o relatório Power BI de fluxo de caixa da
> Lucenera, usando dados reais do Supabase em vez de export estático, com a
> identidade visual da Central Lucenera (fundo azul-marinho escuro + dourado).

---

## Checklist de Ação

### Backend — Supabase (fonte única de verdade, tudo que o Skip consome)
- [x] Tabela `stg_duplicatas_vigentes` — chaves `(cod_duplicata,tipo)` do export mais recente, repovoada a cada rodada de `scripts/importar_contas_pagar_receber.py`.
- [x] View `v_financeiro_realizado` — join `transacoes → negociacoes → plano_de_contas`, com `desc_sub_grupo`/`desc_grupo`/`natureza` calculados no banco (nenhuma classificação de negócio no frontend).
- [x] Regra de Natureza (Distribuição de Lucro × Despesa Operacional) implementada exatamente como validado pelo usuário no Power Query.
- [x] Empresa "LUCE NERA" (grupo/holding, `empresas.codigo=4`) criada para as 2.868 duplicatas sem empresa identificável na planilha.

### Página 1 — Visão Geral
- [x] Projeto Skip "Dashboard Lucenera" (id 41135) — conteúdo substituído (era scaffold genérico de sync, sem relação com o objetivo).
- [x] 5 KPI cards: Receitas Realizadas, Despesas Realizadas, Despesa Operacional Total, Distribuição de Lucro, Resultado Operacional (destacado).
- [x] Gráfico de área: Saldo Acumulado Realizado (Operacional).
- [x] Gráfico de área: Resultado Diário (Receita − Despesa Operacional).
- [ ] Filtro Ano/Mês/Dia (removido nesta rodada — a versão anterior com filtro foi substituída; reavaliar se falta fazer falta).

### Página 4 — Contas a Receber Foco
- [x] KPIs: Vendas à Vista, Vendas a Prazo, Recebimentos Venda a Prazo, Em Aberto (Receber).
- [x] Donut: Receita Realizada por Descrição Apropriação.

### Página 5 — Contas a Pagar Foco
- [x] KPIs: Despesas com Material, Custo Operacional, Em Aberto (Pagar).
- [x] Gráfico de barras + tabela: Despesa Operacional por DescSubGrupo (centro de custo).
- [x] Gráfico de linha: Previsto em Aberto por data de vencimento.

### Passos manuais do usuário

- [ ] Revisar os KPIs cuja diferença ficou acima de 5% frente ao Power BI (Distribuição de Lucro -5,1%, Recebimentos Venda a Prazo -19,5%) — ver tabela de validação abaixo. Provavelmente exige acesso ao `.pbix` original ou a uma fonte que diferencie empresa por transação para zerar.
- [ ] Confirmar se a empresa "LUCE NERA" (grupo) deve ganhar tratamento especial em outras telas do ecossistema (ex.: RH, orçamentos) ou se fica restrita ao domínio financeiro.

---

## Objetivo

Substituir o relatório Power BI (estático, exige exportação manual) por um dashboard
web publicado no Skip, lendo dados ao vivo do Supabase (`transacoes` /
`v_cash_flow_lucenera`), com a mesma identidade visual da Central Lucenera, para
que o financeiro acompanhe receita/despesa/comissão sem depender de atualização
manual de arquivo `.pbix`.

---

## Decisões aprovadas

- Fonte de dados: view `public.v_cash_flow_lucenera` (já existe, ver definição abaixo) como base; pode ser estendida com uma nova view/coluna se o mapeamento de `DescSubGrupo` for aprovado.
- Paleta de cores: extraída do projeto Skip "Central Lucenera" (id 37750) — fundo `hsl(222 47% 11%)` (azul-marinho escuro), primária/destaque `hsl(45 93% 47%)` (dourado), bordas/superfícies `hsl(217 32% 17%)`. Os gráficos usam tons de azul (como no Power BI original) sobre esse fundo escuro, com o dourado reservado para destaque/KPIs.
- "Descrição Apropriação" (Página 2) = coluna `transacoes.descricao`, sem transformação — confirmado por amostragem (`DARE-ICMS`, `RETIRADA DE LUCRO FILIPPO`, `COMPRAS - REVENDA` aparecem literalmente na tabela).

---

## Definição da SPEC

### Estado atual (grounded no schema real)

**View existente**, `public.v_cash_flow_lucenera` (sem migration local — foi criada direto em produção, mesmo padrão da `vw_comissao_mensal`):

```sql
CREATE OR REPLACE VIEW public.v_cash_flow_lucenera AS
SELECT
  dt_pagamento,
  dt_vencimento,
  tipo::text AS tipo,
  CASE
    WHEN (descricao ILIKE '%LUCRO%' OR descricao ILIKE '%RETIRADA%') AND tipo = 'despesa'
      THEN 'distribuicao_lucro'
    ELSE tipo::text
  END AS categoria_fluxo,
  vl_pago,
  descricao,
  status_pago
FROM transacoes
WHERE status_pago = 1 AND dt_pagamento IS NOT NULL;
```

- 6.543 linhas em produção hoje.
- `tipo`: `despesa` | `receita`.
- `categoria_fluxo`: `despesa` | `receita` | `distribuicao_lucro` (subconjunto de despesa cujo texto contém "LUCRO" ou "RETIRADA" — cobre exatamente os casos `RETIRADA LUCRO MANOELLA` / `RETIRADA DE LUCRO FILIPPO` encontrados na amostra).
- Tabela-fonte `public.transacoes` tem `empresa_id` (FK, não usado pela view) e `funcionario_id` — dá para segmentar por empresa (ISLIGHT, FOCO ILUMINACAO, MANOELLA) se precisar no futuro, mas as imagens de referência não mostram esse filtro.

**Tabela `categorias_financeiras`** existe mas **não** corresponde às categorias do Power BI (tem "Aluguel", "Energia Elétrica", "Folha de Pagamento" etc. — taxonomia seed genérica, não usada pelos lançamentos reais amostrados). Não usar como fonte do `DescSubGrupo`.

### Definição de métricas — Página 1

| KPI/gráfico (Power BI) | Fonte proposta |
|---|---|
| Receitas Realizadas | `SUM(vl_pago) WHERE tipo = 'receita'` |
| Despesa Operacional Total | `SUM(vl_pago) WHERE categoria_fluxo = 'despesa'` (exclui `distribuicao_lucro`) |
| Distribuição de Lucro | `SUM(vl_pago) WHERE categoria_fluxo = 'distribuicao_lucro'` |
| Despesas com Material | `SUM(vl_pago) WHERE descricao ILIKE '%COMPRA%' OR descricao ILIKE '%MATERIAL%' OR descricao ILIKE '%INDUSTRIALIZA%'` — **aproximação**, não confirmada; ver Pendências |
| Custo Operacional | Mesma base de "Despesa Operacional Total" nas imagens — os dois cards mostram valores diferentes (R$529,68 Mil vs R$1,05 Mi), então não são a mesma métrica; **definição exata não confirmada**, ver Pendências |
| Despesa/Receita por dia (linha) | `GROUP BY dt_pagamento` dentro do filtro ativo |
| Despesa/Receita por ano (barras) | `GROUP BY EXTRACT(year FROM dt_pagamento)` |
| Donut Despesas × Receitas | `SUM(vl_pago) GROUP BY tipo` |

### Mapeamento proposto — validar (Página 2, `DescSubGrupo`)

Baseado nos valores de `descricao` mais frequentes encontrados em `transacoes`
(amostra de 500 linhas), proposta inicial de agrupamento — **não implementar sem
confirmação**, pois é uma inferência sobre nomenclatura contábil, não um dado
existente no banco:

| DescSubGrupo (Power BI) | `descricao` que provavelmente pertencem (amostra) |
|---|---|
| COM VENDAS | COMPRAS - REVENDA, INDUSTRIALIZAÇÃO, FRETE ENTRADA, DEVOLUÇÃO, DEV TROCA |
| COM PESSOAL | (folha/pró-labore — não apareceu nos 500 registros amostrados; precisa de amostra maior) |
| MANOELLA | RETIRADA LUCRO MANOELLA |
| FILIPPO | RETIRADA DE LUCRO FILIPPO |
| ADMINISTRATIVAS | COPA E COZINHA, PAPELARIA, LANCHES E REFEIÇÕES, DIVERSO ADM, TAXIS/FRETES ADM, UNIFORMES, BOLO FUNCIONARIOS |
| BANCARIAS | (tarifas bancárias — não identificado na amostra) |
| FIXAS | CONTABILIDADE, DARF/GPS, DARE-ICMS, ISSQN |
| INVESTIMENTOS | MAQUINAS E EQUIPAMENTOS, NOVO SHOWROOM |
| MELHORIAS | (reformas — não identificado na amostra) |
| OPERAC. FILIPPO / OPERAC. MANOELLA | (não identificado — possivelmente despesas operacionais atribuídas a cada sócio, diferente da retirada de lucro) |

### Regras de negócio

| # | Regra |
|---|---|
| RN-01 | Todo cálculo do dashboard usa `status_pago = 1 AND dt_pagamento IS NOT NULL` (já garantido pela view) — apenas transações efetivamente pagas entram no fluxo de caixa. |
| RN-02 | `distribuicao_lucro` nunca deve ser somado dentro de "Despesa Operacional Total" — é uma categoria separada (retirada de sócio, não custo do negócio). |
| RN-03 | O filtro Ano/Mês/Dia opera sobre `dt_pagamento`, não `dt_vencimento` (fluxo de caixa é sobre o que foi efetivamente pago). |

### Critérios de aceite

- [ ] Os 4 KPIs da Página 1 carregam com dado real do Supabase, sem mock.
- [ ] Gráfico de linha e gráfico de barras respeitam o filtro Ano/Mês/Dia selecionado.
- [ ] Paleta de cores visualmente consistente com a Central Lucenera (fundo escuro, dourado de destaque).
- [ ] Página 2 só é publicada depois de o mapeamento `DescSubGrupo` ser confirmado pelo usuário.
- [ ] Projeto Skip 41135 publicado com o novo conteúdo, substituindo o scaffold genérico de sincronização.

---

## Realizado

### 2026-07-14

- Projeto Skip "Dashboard Lucenera" (id 41135, https://dashboard-empresa-40d7d.goskip.app) identificado como a "página em branco" mencionada pelo usuário — confirmado pelo conteúdo genérico (scaffold de sync SharePoint/Teams sem relação com o pedido) e pela migration `20260714224500_init_dashboard.sql` datada do mesmo dia.
- Paleta de cores extraída do projeto Skip "Central Lucenera" (id 37750) e aplicada em `src/main.css` — fundo `hsl(222 47% 11%)`, dourado `hsl(45 93% 47%)`, tons de azul nas séries de gráfico (`--chart-1`..`--chart-5`).
- Página 1 (Visão Geral) implementada e publicada: `src/services/cash-flow.ts` (busca e agrega `v_cash_flow_lucenera` no client), `src/pages/Index.tsx` (KPIs + gráfico de linha por dia + donut + barras por ano + filtro Ano/Mês), sidebar/header simplificados (removidas as páginas Sync/Logs/Settings do scaffold anterior, sem relação com o dashboard financeiro).
- QA (setup/lint/build/integrations/test) passou; publicado em produção.
- Página 2 (Despesas Detalhadas / DescSubGrupo) **não implementada** — depende da decisão de negócio sobre o mapeamento `descricao → DescSubGrupo` (ver Pendências).

## Atualização 2026-07-15 — Regras de negócio confirmadas pelo usuário (Power Query)

O usuário validou as fórmulas exatas contra o `.pbix` original. Isso resolve as
pendências de mapeamento da Página 2 e define as Páginas 4 e 5.

### Modelo de dados criado no Supabase

- Tabela `public.stg_duplicatas_vigentes (cod_duplicata, tipo)` — chaves `(cod_duplicata,tipo)` presentes no export `ContaPagar/ContaReceber_2026-07-14.xlsx` mais recente. Repovoada a cada rodada de `scripts/importar_contas_pagar_receber.py`.
- View `public.v_financeiro_realizado` — uma linha por `transacao`, já filtrada para `negociacoes` vigentes (existentes no export atual, deduplicadas por `(cod_duplicata,tipo)` quando ambíguas entre empresas), com `desc_sub_grupo`/`desc_grupo` resolvidos via hierarquia `plano_de_contas` (nivel 3→2→1) e `natureza` calculada pela regra abaixo. **Esta é a fonte que o Skip deve consultar — nenhum cálculo de negócio deve ficar no frontend.**

### Regra de Natureza (Distribuição de Lucro vs Despesa Operacional)

```sql
CASE
  WHEN tipo='despesa' AND (
    desc_sub_grupo ILIKE '%FILIPPO%' OR desc_sub_grupo ILIKE '%MANOELLA%'
    OR descricao ILIKE '%RETIRADA LUCRO%' OR descricao ILIKE '%RETIRADA DE LUCRO%'
    OR descricao ILIKE '%LUCRO DISTRIB%'
  ) THEN 'distribuicao_lucro'
  WHEN tipo='despesa' THEN 'despesa_operacional'
END
```

### Fórmulas e validação contra o Power BI (2026-07-15)

| Medida | Fórmula sobre `v_financeiro_realizado` | Esperado (Power BI) | Obtido | Diferença |
|---|---|---|---|---|
| Receitas Realizadas | `sum(vl_pago) WHERE tipo='receita' AND status_pago=1` | R$23.070.282,37 | R$23.679.811,68 | +2,6% |
| Despesas Realizadas | `sum(vl_pago) WHERE tipo='despesa' AND status_pago=1` | R$24.653.791,56 | R$25.292.482,62 | +2,6% |
| Despesa Operacional Total | `sum(vl_pago) WHERE natureza='despesa_operacional' AND status_pago=1` | R$21.771.997,21 | R$22.556.220,81 | +3,6% |
| Distribuição de Lucro Total | `sum(vl_pago) WHERE natureza='distribuicao_lucro' AND status_pago=1` | R$2.881.794,35 | R$2.736.261,81 | -5,1% |
| Despesas com Material | `sum(vl_pago) WHERE natureza='despesa_operacional' AND desc_sub_grupo='COM VENDAS' AND status_pago=1` | R$5.349.668,81 | R$5.354.380,78 | +0,09% ✅ |
| Em Aberto (Pagar) | `sum(vl_parcela-vl_desconto) WHERE tipo='despesa' AND status_pago IN (0,2)` | R$17.073.333,11 | R$17.026.716,20 | -0,27% ✅ |
| Em Aberto (Receber) | `sum(vl_parcela-vl_desconto) WHERE tipo='receita' AND status_pago IN (0,2)` | R$3.488.177,93 | R$3.560.622,08 | +2,1% |
| Vendas à Vista | `sum(vl_pago) WHERE descricao='VENDAS A VISTA' AND status_pago=1` | R$5.343.121,44 | R$4.956.168,81 | -7,2% |
| Vendas a Prazo | `sum(vl_pago) WHERE descricao='VENDAS A PRAZO' AND status_pago=1` | R$17.049.159,22 | R$16.374.722,42 | -4,0% |
| Recebimentos Venda a Prazo | `sum(vl_pago) WHERE descricao='RECEBIMENTOS VENDA A PRAZO' AND status_pago=1` | R$671.066,67 | R$540.166,67 | -19,5% |
| Resultado Operacional | `Receitas Realizadas - Despesa Operacional Total` | +R$1.298.285,16 | +R$1.123.590,87 | — |

**Importante — descoberta crítica durante a implementação**: a base de `transacoes`/`negociacoes` que já existia em produção (8.080 linhas antes desta sessão) tinha registros que não correspondem ao export mais recente do Connect (`ContaPagar/ContaReceber_2026-07-14.xlsx`) e 402 pares `(cod_duplicata, tipo)` duplicados entre empresas (mesma duplicata cadastrada sob mais de uma empresa) — nenhum dos dois causado por esta sessão. Sem filtrar por isso, os totais realizados chegavam a **R$57,38 Mi**, quase R$10 Mi acima do correto. `v_financeiro_realizado` filtra por `stg_duplicatas_vigentes` e deduplica ambiguidades (mantém a negociação mais antiga por `cod_duplicata+tipo`) para se aproximar do Power BI — o resíduo de 2 a 20% que sobra não foi possível zerar sem acesso ao `.pbix` original ou a uma fonte que diferencie empresa por transação. Decisão do usuário: aceitar essa aproximação e seguir.

- 2.868 duplicatas que não existiam em nenhuma empresa foram cadastradas sob uma **4ª empresa "LUCE NERA" (grupo/holding)**, criada especificamente para isso (`empresas.codigo=4`) — decisão do usuário em 2026-07-15, pois a planilha não diferencia ISLIGHT/FOCO/MANOELLA.

### Página 4 — "Contas a Receber Foco" (nova)

Cards: Vendas à Vista, Vendas a Prazo, Recebimentos Venda a Prazo (fórmulas acima), Em Aberto (Receber). Segmentação por `descricao` (`v_financeiro_realizado.descricao`), não por `desc_sub_grupo`.

### Página 5 — "Contas a Pagar Foco" (nova)

Cards: Despesas com Material, Custo Operacional (= Despesa Operacional Total − Despesas com Material), Em Aberto (Pagar), Previsto por dia (agrupado por `dt_vencimento` onde `status_pago IN (0,2)`). Segmentação por `desc_sub_grupo` (COM VENDAS, COM PESSOAL, ADMINISTRATIVAS, VEICULOS, FIXAS, BANCARIAS, PRODUTOS).

## Realizado

### 2026-07-15

- Import de contas a pagar/receber estendido (`scripts/importar_contas_pagar_receber.py`) para criar `negociacoes` novas sob a empresa "LUCE NERA" quando a duplicata não existe em nenhuma empresa — 2.868 negociações + 5.549 transações criadas, 1.449 atualizadas.
- Descoberta e mitigada uma inconsistência na base pré-existente (8.080 transações de antes desta sessão, com registros fora do export atual e 402 pares `(cod_duplicata,tipo)` duplicados entre empresas) que inflava os totais em ~R$10 Mi — resolvida via `stg_duplicatas_vigentes` + dedupe na view, não via exclusão física dos dados.
- View `v_financeiro_realizado` criada e validada linha por linha contra os valores do Power BI fornecidos pelo usuário (tabela acima).
- `src/services/cash-flow.ts`, `src/pages/Index.tsx`, `src/pages/ContasReceberFoco.tsx` (nova) e `src/pages/ContasPagarFoco.tsx` (nova) publicados no Skip — https://dashboard-empresa-40d7d.goskip.app. Todo cálculo de negócio (Natureza, DescSubGrupo, Em Aberto) vem do Supabase; o frontend só agrega/exibe.

## Pendências

- [ ] Confirmar a fórmula exata de "Custo Operacional" vs "Despesa Operacional Total" — nas imagens são dois números diferentes (R$529,68 Mil e R$1,05 Mi) e a IA não tem certeza de qual filtro/agrupamento diferencia um do outro sem o arquivo `.pbix`.
- [ ] Confirmar a fórmula de "Despesas com Material" — proposta atual é uma busca por texto (`ILIKE`) em `descricao`, pode incluir ou excluir itens incorretamente.
- [ ] Confirmar/completar o mapeamento `descricao → DescSubGrupo` da Página 2 (tabela acima é só um rascunho a partir de uma amostra de 500 transações — o banco tem 6.543 no total).
- [ ] Definir se o dashboard deve permitir segmentar por empresa (`ISLIGHT`, `FOCO ILUMINACAO`, `MANOELLA`) via `transacoes.empresa_id`, já que a coluna existe mas não é usada pela view atual nem aparece como filtro nas imagens de referência.
