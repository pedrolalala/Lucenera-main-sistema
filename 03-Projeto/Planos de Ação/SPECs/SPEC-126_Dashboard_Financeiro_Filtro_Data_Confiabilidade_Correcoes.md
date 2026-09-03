---
titulo: "SPEC-126 — Dashboard Financeiro 100%: Filtro por Data, Confiabilidade e Correções da Reunião 31/08"
status: pendente
data_ultima_modificacao: 2026-09-02
sistemas_envolvidos:
  - Dashboard Financeiro — 04-Sistemas/dashboard-lucenera-b02z85wa3 (Skip projeto 41135, host dashboard-empresa-40d7d.goskip.app)
  - Administração Bancária — 04-Sistemas/"gestao-financeira-clone-544cb (1)" (Escopo 4, Receita de Serviço)
  - Banco central (Supabase) — v_financeiro_realizado, v_estoque_produtos, vw_necessidade_compra, transacoes, plano_de_contas (leitura + 2 migrations de view)
referencias:
  - SPEC-041 (Dashboard: nomenclatura Realizado × Previsto, card Necessidade de Compra) — base direta
  - SPEC-025 (implementação original do Dashboard Financeiro Cash Flow)
  - SPEC-064 (coluna transacoes.perfil, filtro Ribeirão/São Paulo)
  - SPEC-039/040 (vw_necessidade_compra)
  - Reuniões 31/08/2026 — Vinícius, "Contas a receber e a pagar" partes 1 e 2 (02-Reunioes/21. Lucenera (Vinicius) - 31.08.2026_ Contas a receber/)
  - Documento de análise: artefato "Dashboard Financeiro — Estrutura Revisada" (conferência KPI a KPI)
---

# SPEC-126 — Dashboard Financeiro 100%: Filtro por Data, Confiabilidade e Correções da Reunião 31/08

> Guarda-chuva das duas reuniões de 31/08 com o Vinícius. O objetivo final é o
> Dashboard bater 100% com a planilha do Sérgio e a Connect. O **Escopo 1
> (Filtro por Data)** está liberado para começar; os demais escopos estão
> definidos mas alguns dependem de decisão do Vinícius (marcados como
> `BLOQUEADO`).

## Checklist de Ação

### Escopo 1 — Filtro por Data (LIBERADO)

- [x] `src/services/cash-flow.ts` — `filterFinanceiro` passa a receber `Periodo { de, ate, campo }`; `distinctAnos`/`MESES` removidos; adicionados `rangePreset` (mes-atual/mes-passado/ano-atual/tudo) e `periodoAnterior` (janela de mesmo tamanho antes do intervalo)
- [x] `src/components/PeriodFilter.tsx` — componente novo: ToggleGroup Pagamento/Vencimento + Popover com presets + `Calendar mode="range"` (2 meses)
- [x] `src/pages/Index.tsx` — troca Select Ano/Mês por `<PeriodFilter>`; `periodoAnterior` local removido; Δ agora é "vs período anterior"; `<h1>` "(Mês Atual)" → "Fluxo de Caixa Realizado"
- [x] `src/pages/ContasReceberFoco.tsx` — troca Select Ano/Mês por `<PeriodFilter>` (Select de Perfil mantido)
- [x] `src/pages/ContasPagarFoco.tsx` — idem + "Previsto em Aberto por Vencimento" passa a usar um recorte próprio filtrado por `dt_vencimento` no intervalo (não some quando o toggle está em "pagamento")
- [x] "Em Aberto (Pagar/Receber)" continua no total acumulado, não muda com o intervalo
- [x] `src/services/cash-flow.ts` — `FinanceiroRow` + `COLUNAS` ganham `id`, `dt_emissao` e `cod_duplicata` (chave de match com a planilha do Connect)
- [x] `src/components/PlanilhaTabela.tsx` (novo) — tabela genérica ordenável + export CSV (`;` + BOM, todo o conjunto filtrado; render limitado a 500 linhas)
- [x] `src/components/colunasFinanceiro.ts` (novo) — colunas da planilha das 3 abas financeiras (Duplicata, Tipo, Descrição, Sub-grupo, Natureza, Status, Emissão, Vencimento, Pagamento, Parcela, Desconto, Pago, Perfil)
- [x] `Index.tsx` / `ContasReceberFoco.tsx` / `ContasPagarFoco.tsx` — "Planilha do período" no fim de cada aba (Receber só receita, Pagar só despesa), respeitando intervalo + perfil + cross-filter
- [x] `Estoque.tsx` — "Planilha — produtos" no fim da aba (Código, Produto, Marca, Estoque total, Disponível, Showroom, Custo/Venda un., Custo/Venda disp., Custo total, MKP), respeitando o filtro de marca
- [x] `src/lib/utils.ts` — helper `formatarData` (ISO → dd/mm/aaaa)
- [x] `oxlint` + `tsc --noEmit` + `vite build` limpos
- [x] Publicado no Skip 41135 — versão **0.0.32** (`c5a8441`, 2026-09-01), QA (setup/static/build/integrations/test) tudo verde
- [ ] Teste no navegador em produção com o intervalo 01/02 → 28/02 por pagamento (Fluxo/Receber/Pagar) + export CSV

### Escopo 2 — Confiabilidade: reverter orçamentos de teste + separar dado de teste

**2A — Reverter os orçamentos de teste — FEITO 01/09/2026**

Critério (usuário): todo orçamento criado dentro do sistema e aprovado é teste; o resto vem do import das planilhas. Medido: só existiam **22 orçamentos** (19 `'Orçamento Aprovado'` + 3 rascunho).

- [x] Script `scripts/reverter_orcamentos_teste.py` (dry-run padrão, `--aplicar` grava). Replica os passos do RPC `cancelar_orcamento` (que não roda aqui porque o status é `'Orçamento Aprovado'`, não `'aprovado'`) + a parte de separação/logística que o RPC não cobre. Cancela, não apaga.
- [x] Aplicado: **19 orçamentos → cancelado** (+ 19 em `historico_status_orcamentos`); 36 boletos → cancelado (incl. 1 "Pago", 9 "Remessa Enviada"); 41 parcelas → cancelada (incl. 5 "paga"); 40 `projeto_itens.validado` → false; 32 `estoque_saldos_projeto_item` → cancelado + 30 movimentos 'cancelamento'; 13 linhas de `estoque_itens.quantidade_reservada` liberadas (64 un.); 18 `separacao_itens` estornados; 11 separações → Cancelado; 2 entregas → Cancelado; 6 `entregas_pendentes` removidas. 3 rascunhos intactos.
- [x] Achado: a CHECK `orcamentos_data_inicio_pagamento_check` (NOT VALID) rejeita qualquer UPDATE quando `data_inicio_pagamento` < hoje — resolvido zerando `data_inicio_pagamento` junto no cancelamento (inócuo num orçamento de teste cancelado).
- [x] Boletos NÃO têm FK para `negociacoes`/`transacoes` — a "relação bancária" desses orçamentos é a própria tabela `boletos`, já coberta. O Dashboard financeiro lê `transacoes` (import do Connect), não boletos.
- [x] Conferido pós-reversão: 0 orçamento aprovado, todos boletos/parcelas/saldos cancelados, `vw_necessidade_compra` 232→230 linhas / Gasto Futuro R$811k→R$802k.

**2B — Marca de origem (evita recontaminar) — BLOQUEADO, decisão de abordagem**

- [ ] Definir mecanismo de marca de origem (`connect` | `sistema` | `teste`) em `transacoes` / `negociacoes`
- [ ] `v_financeiro_realizado` expõe a origem
- [ ] Dashboard: filtro/switch "Somente Connect" (default ligado) em todas as telas

### Escopo 3 — Classificação `natureza` na view (migration REDIGIDA, aguarda Vinícius + apply)

- [x] Levantar `plano_de_contas.codigo_connect` de retirada/lucro distribuído (9 códigos, ver migration) — feito por consulta ao Supabase real
- [x] Migration `20260901_129_spec126_natureza_por_codigo_connect/001_natureza_allowlist.sql` — `hierarquia` expõe `codigo_connect`; `CASE` de `natureza` passa a usar allowlist de `codigo_connect` no lugar de `ILIKE '%FILIPPO%'/'%MANOELLA%'`
- [ ] Vinícius confirmar o balde de `ESCOLA` / `CLUBE MAIS VIAGENS` (com a migration, viram `despesa_operacional`)
- [ ] Revisor + aplicar no Supabase real

### Escopo 4 — Receita de Serviço / Representação (BLOQUEADO — decisão de fluxo)

- [ ] Definir com o Vinícius: onde lança (Adm. Bancária), campos, % por pessoa, tratamento de imposto da NF de serviço
- [ ] Tela/campo de lançamento "Recebimento de Serviço" (venda → comissões por % → líquido)
- [ ] Líquido entra na Receita do `v_financeiro_realizado` (ou view irmã somada no dashboard)
- [ ] Comissão vira despesa no pagamento (confirmar se já cobre)
- [ ] Migration/estrutura conforme a decisão

### Escopo 5 — Estoque: bloco Reservado + padronização

- [x] `src/services/estoque.ts` — `computeKpisEstoque` ganha `valorCustoReservado`, `valorVendaReservado`, `valorVendaShowroom`; helper `reservadoQtd` (= `max(0, estoque_total + estoque_showroom − estoque_disponivel)`, cálculo client-side enquanto a view não expõe)
- [x] `src/pages/Estoque.tsx` — cards "De Cliente / Reservado (Custo)" e "(Venda)" + "Showroom (Venda)" + aviso "Disponível já inclui Showroom, não somar"
- [ ] Migration (opcional, deixa a view como fonte de verdade): `v_estoque_produtos` expõe `estoque_reservado`, `valor_custo_reservado`, `valor_venda_reservado`, `valor_venda_showroom` a partir de `vw_detalhe_produto_estoque`

### Escopo 6 — Recorte "Investimento" em Contas a Pagar

- [x] `src/services/cash-flow.ts` — `filterByDescGrupo` + `distinctGrupos` (auto-descobre os grupos, sem hardcode)
- [x] `src/pages/ContasPagarFoco.tsx` — Select "Grupo" no cabeçalho; filtra KPIs + gráficos + a planilha do fim da aba (que serve de drill-down)

### Escopo 7 — Ajustes menores

- [x] Rótulo "Em Aberto (Pagar/Receber)" ganhou legenda visível "Total acumulado — não muda com o filtro de período" (além do tooltip da SPEC-041)
- [x] `vw_necessidade_compra` verificada no Supabase real: 232 produtos com `pendente`/`preco_custo`, card mostraria ~R$ 811 mil — está pegando; a divergência do Vinícius é na tela de Compras / no Excel dele, não no card
- [ ] "Receita por Apropriação" — a planilha do fim da aba já lista todas as apropriações; avaliar se ainda vale expandir a rosca além do top-10
- [ ] Definir com o Filippo a lista de sub-grupos que contam como "custo fixo" no Ponto de Equilíbrio

### Escopo 8 — Aba "Fluxo Futuro (Projeção)" — FEITO 2026-09-02

Pedido do usuário: "criar no Dash dentro do dash a visualização dos dados futuros para o chefe e o Vinícius verem", com "a planilha com os dados e com o que vai gastar, quais os grupos".

- [x] `src/services/cash-flow.ts` — `janelaFuturo(meses)`, `computeFluxoFuturoPorMes` (Em Aberto por mês de `dt_vencimento`, balde "Vencido" primeiro, saldo do mês + saldo acumulado a partir de zero), `computeGastoFuturoPorGrupo` (despesa em aberto por grupo+sub-grupo), `computeTotaisFluxoFuturo` (a receber/a pagar/saldo + recorte vencido). Reusam `aberto()` e `valorAberto()` (`vl_parcela − vl_desconto`) — mesma conta do "Em Aberto" das outras abas.
- [x] `src/pages/FluxoFuturo.tsx` (novo) — 4 KPIs (A Receber / A Pagar / Saldo Projetado / Vencido líquido), gráfico `ComposedChart` (barras Receber verde × Pagar vermelho + linha Saldo acumulado), tabela "Projeção mês a mês" (Mês · A Receber · A Pagar · Saldo do mês · Saldo acumulado + total), tabela "O que vai gastar — por grupo" (Grupo · Sub-grupo · Parcelas · Total · % do total + total), e `<PlanilhaTabela>` com cada parcela em aberto (colunas incluem **Grupo**, que as planilhas das outras abas não têm). Filtros: Horizonte (6/12/24 meses/Tudo, default Tudo), Perfil (Ribeirão/SP), switch "Incluir vencidos" (default ligado).
- [x] `src/App.tsx` — rota `/fluxo-futuro` (lazy). `src/components/app-sidebar.tsx` — item "Fluxo Futuro (Projeção)" no grupo Financeiro, após "Agenda de Pagamentos".
- [x] Publicado no Skip 41135 — versão **0.0.33** (`d319d45`, 2026-09-02), QA (setup/static/build/integrations/test) tudo verde.
- [x] Números conferidos contra a planilha `_2026-09-02.xlsx` no ciclo de import: A Pagar em aberto R$ 5.479.292,14 e A Receber R$ 3.104.418,35, batendo mês a mês por vencimento (Vencido + Set/2026 em diante).
- [x] **Cross-filter por mês (v0.0.34, `4b99af0`, 2026-09-02):** clicar numa barra do gráfico (ou numa linha da tabela "Projeção mês a mês") seleciona aquele mês e filtra os 4 KPIs, a tabela "o que vai gastar — por grupo" e a planilha do fim da aba. `FilterChip` "Mês: …" no cabeçalho para limpar. Helper `baldeVencimento(dt)` (`'vencido'` | `'AAAA-MM'`) extraído em `cash-flow.ts` e reusado no agregador e no filtro de clique.
- [x] **Drill de 2 níveis no gráfico (v0.0.35, `5846bdc`, 2026-09-02):** com um mês selecionado o próprio gráfico troca de "por mês" para **"Composição de \<mês\> — por grupo"** (barras horizontais A Receber × A Pagar por `desc_grupo`). Clicar numa barra de grupo desce o nível 2 (`grupoSelecionado`) e filtra KPIs + tabela + planilha por mês **e** grupo; chip "Grupo: …". A tabela "o que vai gastar" também é clicável por linha. Helper novo `computeAbertoPorGrupo` em `cash-flow.ts`. A linha do saldo acumulado só existe na visão por mês (horizonte inteiro, não muda com clique).
- [x] **Filtro por mês + pizza das despesas + correção do drill (v0.0.36, `32990c4`, 2026-09-03):**
  - **Filtro "Mês" (Select)** no cabeçalho, ao lado de Perfil/Horizonte — lista os meses de `porMes` ("Vencido", set/2026, …). Compartilha estado com o clique no gráfico.
  - **Bug do chefe:** clicar numa despesa (barra de grupo / linha) abria a planilha "buscando do lugar errado" — trazia receita junto (ex.: "VENDAS A PRAZO" sob "ADMINISTRATIVAS") e todos os sub-grupos do grupo, não só o clicado. Causa: `abertasDoRecorte` filtrava só por `desc_grupo` e **sem filtrar `tipo`**. Correção: o recorte de grupo/sub-grupo agora é **sempre `tipo = 'despesa'`** e leva `desc_sub_grupo` junto (`grupoSelecionado` + `subGrupoSelecionado`). Os 4 KPIs voltaram a ser sempre do nível do mês (referência estável) — só pizza/tabela/planilha seguem o recorte de grupo.
  - **Gráfico de pizza "Repartição das despesas em aberto"** (pedido do chefe): rosca da despesa em aberto por `desc_grupo` (top-8 + "Outros"), com legenda + tabelinha de % ao lado. Clicar numa fatia abre o grupo nos **sub-grupos** dele (2º nível), com chip para voltar. A barra "Composição por grupo" da v0.0.35 saiu (mostrava receita junto, era o que confundia) — o gráfico por mês voltou a ser fixo (barras A Receber × A Pagar + linha do saldo).
  - Helper novo `computeDespesaAbertoPorDimensao(rows, 'grupo' | 'sub_grupo')` em `cash-flow.ts`.

### Passos manuais do usuário

- [ ] **Vinícius** — reverter todos os lançamentos de teste no sistema e zerar o estoque de teste
- [ ] **Vinícius** — conferência dashboard × planilha do Sérgio em **fevereiro/2026** (mês sem teste) usando o novo filtro por data, por data de pagamento
- [ ] **Vinícius** — confirmar conta a conta o balde (lucro distribuído × despesa operacional) de `ESCOLA`, `CLUBE MAIS VIAGENS` e demais contas da subárvore RETIRADAS LUCRO (Escopo 3)
- [ ] **Vinícius** — definir fluxo, campos e % da Receita de Serviço / Representação (Escopo 4)
- [ ] **Filippo** — validar a lista de "custo fixo" do Ponto de Equilíbrio (Escopo 7)
- [ ] Aplicar as migrations dos Escopos 3 e 5 no Supabase real após revisão
- [ ] Publicar no Skip (projeto 41135) após QA

## Objetivo

O Dashboard Financeiro precisa ser confiável o suficiente para o chefe e o
Vinícius tomarem decisão em cima dele. Hoje alguns KPIs batem com a planilha e a
maioria não. As duas reuniões de 31/08 mapearam por quê. Esta SPEC organiza a
correção em escopos, começando pelo que o Vinícius mais pediu: **poder filtrar
por intervalo de datas (não só por mês) e ver a data de cada transação**, que é o
que torna possível provar qual KPI está certo.

## Decisões aprovadas

- Escopo 1 (Filtro por Data) começa agora.
- O filtro por data é **frontend apenas** — a view `v_financeiro_realizado` já
  devolve `dt_emissao`, `dt_vencimento` e `dt_pagamento`. Sem migration.
- Realizado sempre filtra por **data de pagamento**; previsto/em aberto por
  **data de vencimento**. O toggle deixa isso explícito para conferência.
- "Em Aberto (Pagar/Receber)" continua sendo foto do momento (não some com o
  intervalo); o intervalo passa a filtrar "Previsto por vencimento" e as listas.
- Pedido de Compra continua fora do Dashboard (só Produtos, Contas a Receber,
  Contas a Pagar, Caixa e — novo — Receita de Serviço).
- Aba **Estoque não recebe filtro por data** (decisão do usuário, 01/09): é foto
  do momento, `v_estoque_produtos` não tem dimensão temporal e não há tabela de
  histórico de estoque. O `<PeriodFilter>` fica só nas 3 abas financeiras.
- Aprovar orçamento **não** conta como realizado (só a baixa em Adm. Bancária) —
  comportamento atual está correto; o problema é a parcela em aberto de teste
  inflando o acumulado (Escopo 2).

## Definição da SPEC

### Estado atual (medido no código e no Supabase real, 31/08/2026)

| Área | Hoje |
| --- | --- |
| Filtro de período | Só `Select` Ano + `Select` Mês em `Index.tsx` / `ContasReceberFoco.tsx` / `ContasPagarFoco.tsx`. `filterFinanceiro` usa `r.dt_pagamento ?? r.dt_vencimento`. Sem dia, sem intervalo, sem escolha de coluna. |
| Data na tela | Nenhuma lista mostra a data da transação. |
| `natureza` na view | `CASE ... WHEN despesa AND (desc_sub_grupo ILIKE '%FILIPPO%' OR ILIKE '%MANOELLA%' OR descricao ILIKE '%RETIRADA (DE) LUCRO%' OR '%LUCRO DISTRIB%') THEN 'distribuicao_lucro'`. Varre a subárvore inteira de RETIRADAS LUCRO → `ESCOLA` (R$91.688) e `CLUBE MAIS VIAGENS` (R$49.841) caem como lucro. `DESP. OPERAC. FILIPPO/MANOELLA` já caem certo em `despesa_operacional` (o pai na árvore é "OPERACIONAL"). |
| Receita de Serviço | Não existe. Vinícius controla numa planilha à parte (~R$200k/ano, ~R$18k em agosto) e repassa à contabilidade a cada ~6 meses. |
| Estoque | `v_estoque_produtos` expõe total / disponível / showroom (só custo). Não expõe `estoque_reservado`. |
| Investimento | Sem recorte. O dado está em `desc_grupo`. |
| Dado de teste | `transacoes` não distingue Connect × sistema × teste. Orçamento de teste aprovado cria parcela → aparece em "Em Aberto". |

### Escopo 1 — Filtro por Data (detalhado)

**`src/services/cash-flow.ts`**

- Nova assinatura: `filterFinanceiro(rows, { de?: string, ate?: string, campo?: 'dt_pagamento' | 'dt_vencimento' })`.
  - `de`/`ate` no formato `AAAA-MM-DD`. Ambos opcionais (sem filtro = tudo).
  - `campo` default `'dt_pagamento'`.
  - Uma linha entra se `campo` da linha está em `[de, ate]` (inclusivo). Linha sem valor no `campo` escolhido não entra quando há intervalo.
- `computeFluxoDiario` já usa `dt_pagamento` — manter.
- `computeKpisContasReceber` / `computeKpisContasPagar`: os KPIs "Em Aberto" continuam a ser calculados sobre o conjunto **não filtrado por data** (igual hoje). O "Previsto por vencimento" passa a respeitar o intervalo com `campo = 'dt_vencimento'`.

**`Index.tsx` / `ContasReceberFoco.tsx` / `ContasPagarFoco.tsx`**

- Substituir os dois `Select` por um componente de intervalo **De / Até** (dois `input[type=date]` ou date-range popover) + um grupo de presets:
  - Mês atual (default), Mês passado, Ano atual, Personalizado.
- Toggle **"Por data de pagamento" / "Por vencimento"** ao lado do intervalo.
- Manter o filtro de Perfil (SPEC-064) e os cross-filtros de clique.
- Estado default: Mês atual, por pagamento (mantém o comportamento "Fluxo de Caixa Realizado (Mês Atual)" da SPEC-041).

**Drill-down com data**

- Tabela "Centros de custo" (Pagar), lista de "Receita por Apropriação" (Receber) e qualquer lista nova: colunas `Emissão` / `Vencimento` / `Pagamento`.
- Fonte: campos já presentes em `v_financeiro_realizado` (`dt_emissao` adicionado na migration 20260819_121).

**Critérios de aceite (Escopo 1)**

- [ ] Selecionar `01/02/2026` a `28/02/2026`, "por pagamento" → Receita Realizada e Despesa Operacional reproduzem exatamente o mês de fevereiro que o Vinícius bate com a planilha do Sérgio.
- [ ] Trocar para "por vencimento" muda os números de forma coerente (parcelas com vencimento no intervalo, pagas ou não).
- [ ] Nenhum KPI "Em Aberto" muda ao mexer no intervalo.
- [ ] Toda lista drill-down mostra as três datas por linha.
- [ ] `oxlint` / `tsc` / `vite build` limpos.

### Escopo 3 — `natureza` (rascunho da migration)

Substituir o `CASE` por classificação via `codigo_connect` (confirmar a lista com o Vinícius):

```
distribuicao_lucro  ← codigo_connect ∈ {6000000, 6010000, 6020000, 6010006, 6020003,
                                         9900001, 9999003, 9999004, 10000005}
                       (retiradas de lucro + lucro distribuído mensal)
despesa_operacional ← qualquer outra despesa
```

`ESCOLA`, `CLUBE MAIS VIAGENS` e afins: **decisão do Vinícius** — a R2 trata "clube mais" como investimento (despesa). Se forem despesa, saem da allowlist acima automaticamente.

### Análise obrigatória de ecossistema

- **Depende de** `v_financeiro_realizado` (→ `transacoes`, `negociacoes`, `plano_de_contas`), `v_estoque_produtos` (→ `produtos`, `estoque_itens`), `vw_necessidade_compra`. Não toca em `orcamentos`/`projetos`/`boletos` diretamente.
- **Afeta** o domínio Financeiro (Dashboard) e, no Escopo 4, Administração Bancária. Estoque no Escopo 5 (leitura).
- **Dado duplicado?** `estoque_reservado` deve ser derivado de `estoque_itens.quantidade_reservada` via view, nunca copiado para `produtos`.
- **Migration antiga conflitante?** A última definição real de `v_financeiro_realizado` é `20260819_121`; de `v_estoque_produtos` é `20260716_047`. As migrations dos Escopos 3 e 5 partem dessas.
- **`AI_DB_CONTEXT.md`?** Atualizar o do `dashboard-lucenera-b02z85wa3` se os Escopos 3/5 mudarem as views.

### Fluxo de trabalho

1. Escopo 1 no submodule `04-Sistemas/dashboard-lucenera-b02z85wa3` — checar o estado do Skip (projeto 41135) antes de escrever, o submodule pode estar atrás da produção.
2. QA local (`oxlint` / `tsc` / `vite build`) + teste no navegador (não há suíte automatizada).
3. Publicar no Skip 41135; confirmar com o usuário.
4. Escopos 2–7 conforme as decisões do Vinícius forem chegando.

## Realizado

### 2026-08-31

- **Escopo 1 (Filtro por Data) implementado no submódulo** `04-Sistemas/dashboard-lucenera-b02z85wa3` — local, ainda não commitado nem publicado no Skip.
- `src/services/cash-flow.ts`: `filterFinanceiro(rows, ano, mes)` → `filterFinanceiro(rows, Periodo)`, `Periodo = { de: string|null, ate: string|null, campo: 'dt_pagamento'|'dt_vencimento' }`. Comparação lexical `AAAA-MM-DD`, limites inclusivos, linha sem valor na coluna escolhida fica de fora quando há intervalo. Novos `rangePreset()` e `periodoAnterior()`. Removidos `distinctAnos` e `MESES`.
- `src/components/PeriodFilter.tsx` (novo): ToggleGroup Pagamento/Vencimento + Popover com presets (Mês atual, Mês passado, Este ano, Tudo) + `Calendar mode="range"` de 2 meses.
- `Index.tsx` / `ContasReceberFoco.tsx` / `ContasPagarFoco.tsx`: Selects Ano/Mês → `<PeriodFilter>`; estado `periodo` default = mês atual, por pagamento. Perfil e cross-filtros de clique mantidos.
- `ContasPagarFoco.tsx`: "Previsto em Aberto por Vencimento" ganhou recorte próprio (`abertasPorVencimento`) sempre por `dt_vencimento`.
- `Index.tsx`: Δ "vs mês anterior" → "vs período anterior"; `<h1>` sem "(Mês Atual)".
- **"Planilha no fim de cada aba"** (pedido da 2ª conversa continuada): `PlanilhaTabela.tsx` genérico (ordenável + export CSV `;`/BOM do conjunto inteiro, render limitado a 500) + `colunasFinanceiro.ts`. Adicionada em Fluxo de Caixa, Recebimentos, Pagamentos (com `cod_duplicata` como chave de match) e Estoque. `FinanceiroRow`/`COLUNAS` passaram a trazer `id`, `dt_emissao`, `cod_duplicata`. Helper `formatarData` em `lib/utils.ts`.
- QA local: `tsc --noEmit` ok · `oxlint src` ok · `vite build` ok.

### 2026-09-01

- **Escopos 5, 6 e 7 (parte)** implementados no submódulo `dashboard-lucenera-b02z85wa3` (local).
  - E5: `estoque.ts` `computeKpisEstoque` + helper `reservadoQtd`; `Estoque.tsx` com cards "De Cliente / Reservado (Custo/Venda)" e "Showroom (Venda)" + aviso. Cálculo client-side (`total + showroom − disponível`), sem depender de migration.
  - E6: `cash-flow.ts` `filterByDescGrupo` + `distinctGrupos`; `ContasPagarFoco.tsx` com Select "Grupo" (auto-descobre "INVESTIMENTO" e os demais) filtrando KPIs, gráficos e a planilha do fim da aba.
  - E7: cards "Em Aberto (Pagar/Receber)" com legenda "Total acumulado — não muda com o filtro"; `vw_necessidade_compra` verificada (232 linhas, ~R$ 811 mil — o card está OK).
- **Escopo 3**: migration `20260901_129_spec126_natureza_por_codigo_connect/001_natureza_allowlist.sql` **redigida** (allowlist de `codigo_connect` no lugar do `ILIKE '%FILIPPO%'`). **Não aplicada** — aguarda Vinícius confirmar ESCOLA / CLUBE MAIS VIAGENS.
- QA local: `tsc` · `oxlint` · `vite build` ok.
- **PUBLICADO no Skip 41135** (2026-09-01, 13:00 UTC): descoberto que a tela não mudava porque o Skip tem árvore própria (não lê do submódulo git — ver [[feedback_skip_deploy_separate_tree]]). Conferido que o Skip estava em sincronia com o submódulo antes de sobrescrever; escritos os 10 arquivos via `skip_file_write`; `apply_changes` (QA setup/static/build/integrations/test tudo verde) → versão **0.0.32** / `c5a8441`; `publish` → produção `dashboard-empresa-40d7d.goskip.app`.
- Commits git locais (sem push): submódulo `d79d704`, central `f2df5f0` — conteúdo bate com o Skip 0.0.32.
- Continuam bloqueados: E2 (marca de origem — mexe no import da Connect), E4 (Receita de Serviço — feature nova, vira SPEC própria), custo fixo do Ponto de Equilíbrio (Filippo).

### 2026-09-02

- **Escopo 8 — aba "Fluxo Futuro (Projeção)"** implementada e **PUBLICADA no Skip 41135** (versão **0.0.33** / `d319d45`, QA setup/static/build/integrations/test tudo verde).
  - `cash-flow.ts`: `janelaFuturo`, `computeFluxoFuturoPorMes`, `computeGastoFuturoPorGrupo`, `computeTotaisFluxoFuturo` (append no fim do arquivo, não mexem nas funções existentes).
  - `pages/FluxoFuturo.tsx` novo; rota `/fluxo-futuro` e item no menu lateral (grupo Financeiro).
  - Mostra: Em Aberto por mês de vencimento (Receber × Pagar × saldo acumulado), tabela mês a mês, "o que vai gastar por grupo" (grupo + sub-grupo + % + parcelas), e a planilha de cada parcela em aberto com a coluna Grupo.
  - Bate com a planilha `_2026-09-02.xlsx`: A Pagar R$ 5.479.292,14 / A Receber R$ 3.104.418,35, mês a mês por vencimento.
- **Submódulo `dashboard-lucenera-b02z85wa3` NÃO sincronizado** — o checkout local (`main` em `d79d704`) está várias SPECs atrás da produção do Skip (não tem code-splitting/SPEC-123, nem a página `/transacoes`/SPEC-064, nem SPEC-125). Escrever a aba nova só no submódulo local não a colocaria no ar e criaria conflito. A aba está no ar pelo Skip; o re-sync completo submódulo↔Skip continua como pendência de manutenção separada (ver [[feedback_skip_local_pode_ter_menos_que_producao]]).

## Pendências

- [ ] Escopo 2 — definir COMO marcar a origem (`connect`/`sistema`/`teste`) das transações sem quebrar o import da Connect.
- [ ] Escopo 3 — Vinícius precisa confirmar o balde (lucro × despesa) de `ESCOLA`, `CLUBE MAIS VIAGENS` e demais contas da subárvore RETIRADAS LUCRO antes de fechar a allowlist de `codigo_connect`.
- [ ] Escopo 4 — fluxo, campos e percentuais da Receita de Serviço / Representação não definidos; pode virar SPEC própria.
- [ ] Escopo 5 — depende do Escopo 1 entregue; confirmar que `vw_detalhe_produto_estoque.estoque_reservado` cobre reserva de Estoque + local "Reservado".
- [ ] Escopo 6 — confirmar o valor exato de `desc_grupo` usado para investimento.
- [ ] Escopo 7 — lista de "custo fixo" do Ponto de Equilíbrio depende do Filippo.
- [ ] Confirmar se o Dashboard ainda é publicado pelo Skip 41135 e se o submodule local está em sincronia com a produção.
