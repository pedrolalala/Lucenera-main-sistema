---
titulo: "SPEC-028 — Dashboard mais interativo + novo Dashboard de Estoque"
status: concluído (Fase 1 + Fase 2 publicadas) — pendente apenas confirmação manual de Valor_Showroom
data_ultima_modificacao: 2026-07-16
sistemas_envolvidos:
  - Dashboard Lucenera / Dashboard Financeiro (Skip id 41135)
  - Banco central (Supabase) — produtos, marcas, estoque_itens
dependencias:
  - SPEC-025 (Dashboard Financeiro Lucenera) — base do dashboard existente
  - SPEC-026 (Melhorias diversas) — Custo Fixo × Variável, Ponto de Equilíbrio
---

# SPEC-028 — Dashboard mais interativo + novo Dashboard de Estoque

> Duas frentes, a partir de 4 imagens de referência de um relatório Power BI
> de Estoque: (1) tornar o dashboard financeiro atual mais interativo
> (filtro por Marca, cruzamento entre gráfico e tabela); (2) criar uma nova
> página/dashboard de Estoque a partir de `produtos`, recriando os
> KPIs/gráficos das imagens.

---

## Checklist de Ação

### Interatividade no Dashboard existente
- [x] Filtro global por Marca (equivalente ao slicer "Marca" das imagens) — implementado na nova página de Estoque via `<Select>` no topo; não estendido às páginas financeiras (ver Pendências, decisão em aberto).
- [x] Clique num gráfico (barra/donut) filtra a tabela/demais gráficos da mesma página (cross-filtering) — implementado na página de Estoque: clicar numa barra do gráfico "Estoque por Marca" ou numa fatia do donut seleciona a marca (mesmo estado `marcaSelecionada` do filtro superior); clicar numa linha da tabela "Marca × Valor Disponível" faz o mesmo.
- [x] Tabela com ordenação por coluna (clicável no cabeçalho), como nas imagens — implementado com o helper genérico `sortRows()` e componente `SortableHead` (ícone de ordenação, alterna asc/desc) na tabela "Marca × Valor Disponível".

### Fase 2 — Cross-filtering em toda a página (pedido pelo usuário em 16/07)

> Prompt original do usuário: *"vamos realmente deixar o Dashboard
> interativo, então um exemplo quando o meu chefe clicar em uma marca ou em
> algum gasto quero que aquele lugar seja aplicado para toda a página,
> exemplo: se ele clicar em contas fixas na visão geral deve filtrar os
> campos superiores com somente as informações das contas fixas!"*

A Fase 1 já implementou cross-filtering, mas só dentro da página de Estoque
(clicar numa marca no gráfico filtra a tabela de marcas da mesma página). O
pedido agora é mais amplo: **qualquer clique numa categoria (marca, tipo de
gasto, grupo de despesa) deve filtrar TODOS os elementos da página** — KPIs
do topo incluídos, não só gráficos/tabelas auxiliares. Exemplo concreto dado
pelo usuário: clicar na fatia "Fixo" do donut Custo Fixo × Variável (Visão
Geral) deve recalcular os KPI cards do topo (Receitas Realizadas, Despesa
Operacional Total, Distribuição de Lucro, Resultado Operacional) para
refletir só as Contas Fixas.

- [x] **Visão Geral (`Index.tsx`)**: clicar numa fatia do donut "Custo Operacional: Fixo × Variável" filtra o KPI "Despesa Operacional Total" (renomeado dinamicamente para "Despesa Operacional (Fixo/Variável/Outro)" quando filtrado) e os gráficos "Saldo Acumulado"/"Resultado Diário" — nestes últimos, só a série de Despesa é recortada por `tipo_custo`, a série de Receita por dia continua somando o total (ver decisão abaixo). Chip "Filtrado por: Fixo ✕" no cabeçalho da página, mesmo padrão visual de `Estoque.tsx`. "Receitas Realizadas", "Distribuição de Lucro", "Resultado Operacional" e o card de Ponto de Equilíbrio permanecem sempre no total geral (não reagem ao clique) — ver decisão do usuário abaixo.
- [x] **Contas a Pagar Foco (`ContasPagarFoco.tsx`)**: clicar numa barra do gráfico "Despesa Operacional por Centro de Custo" (ou numa linha da tabela "Centros de custo") filtra os 3 KPIs (Despesas com Material, Custo Operacional, Em Aberto) e o gráfico "Previsto em Aberto" para aquele `desc_sub_grupo`. O próprio gráfico de origem continua mostrando todos os subgrupos (só filtrado por Ano/Mês) para permanecer clicável; a barra/linha selecionada fica destacada, as demais com opacidade reduzida.
- [x] **Contas a Receber Foco (`ContasReceberFoco.tsx`)**: clicar numa fatia do donut "Receita Realizada por Descrição Apropriação" filtra os 4 KPIs (Vendas à Vista/Prazo, Recebimentos, Em Aberto) para aquela `descricao`. A fatia agregada "Outros" (soma de categorias menores) não é clicável — não corresponde a um valor exato de `descricao` no banco, filtrar por ela daria sempre vazio.
- [x] **Estoque (`Estoque.tsx`)**: já funcionava para Marca (Fase 1) — nenhuma alteração nesta rodada, conforme planejado.
- [x] Padronizado: cada página tem seu próprio estado de filtro por categoria (`tipoCustoSelecionado` / `subGrupoSelecionado` / `apropriacaoSelecionada`), aplicado com 3 novos helpers em `cash-flow.ts` (`filterByTipoCusto`, `filterByDescSubGrupo`, `filterByDescricao`) sobre o resultado de `filterFinanceiro()` (Ano/Mês) — os dois filtros convivem, categoria é aplicado por cima do Ano/Mês. Componente compartilhado `src/components/FilterChip.tsx` padroniza o chip nas 3 páginas.
- [x] Chip "Filtrado por: {label} ✕" no cabeçalho, ao lado dos selects de Ano/Mês, nas 3 páginas — clicável para limpar o filtro de categoria.

### Novo Dashboard de Estoque (nova página, mesmo sistema Skip id 41135)
- [x] 4 KPIs: Custo/Venda × Disponível/Negativos (déficit) — ver fórmulas e ressalva de validação abaixo.
- [x] 2 KPIs: Valor de Estoque Total (Custo/Venda).
- [x] Gráfico de barras: Estoque por Marca (Valor Disponível, top 15) — clicável para cross-filter.
- [x] Donut: Valor Disponível por Marca (top 10) — clicável para cross-filter.
- [x] Gráfico de barras + tabela: Valor de Showroom por Marca (top 10 por valor).
- [x] Tabela: Marca × Valor Disponível (Custo/Venda), ordenável, com linha de Total.
- [x] Gráfico de barras + tabela: Produtos com maior "a comprar" (déficit), custo × produto (top 15).
- [x] Tabela/visão de Markup (MKP = preço de venda ÷ custo) — tabela ordenável "Markup (MKP) por Marca" (MKP médio/mínimo/máximo, nº de produtos com MKP calculado), agregada a partir do `mkp` por produto exposto em `v_estoque_produtos`.
- [x] Filtro por Marca aplicado a toda a página — todos os KPIs, gráficos e tabelas reagem ao mesmo estado `marcaSelecionada`.

### Sincronização de dados (pré-requisito, concluído)
- [x] Sincronizar `produtos` e `estoque_itens` com a planilha `Produtos__2026-07-15.xlsx` — 4.352 produtos atualizados, 3.077 linhas de `estoque_itens` upsertadas, 0 erros pendentes (`scripts/importar_produtos_estoque.py`, ver "Realizado").

### Passos manuais do usuário

- [ ] **Confirmar a fórmula de "Valor_Showroom"** — `estoque_showroom × custo_total` dá R$82,6 mil, a imagem mostra R$1,27 Mi (15× mais). Não é mais bloqueante para o resto da página, mas esse KPI específico fica pendente até confirmar.
- [x] **Confirmar o comportamento do cross-filtering na Visão Geral quando a categoria clicada é só de despesa (ex. "Contas Fixas")** — resolvido em 16/07: usuário confirmou a opção 2 (Receitas Realizadas e Resultado Operacional continuam no total geral; só os KPIs/gráficos de despesa filtram). Implementado exatamente assim.

---

## Objetivo

Deixar o Dashboard Lucenera com o mesmo nível de exploração visual do Power
BI de referência (filtro por marca, cruzamento entre visual e tabela) e
adicionar uma visão de Estoque que hoje só existe no Power BI, usando dados
reais e atualizados de `produtos`.

---

## Definição da SPEC

### Estado real do schema (grounded)

`public.produtos` — colunas relevantes:

| Coluna | Tipo | Significado |
|---|---|---|
| `marca_id` | uuid → `marcas.id` | Marca do produto (110 marcas distintas, 4.725 produtos ativos) |
| `estoque_total` | numeric | Quantidade total em estoque |
| `estoque_disponivel` | numeric | Quantidade disponível para venda (pode ser negativa — indica déficit) |
| `estoque_showroom` | integer | Quantidade em exposição/showroom |
| `custo_total` | numeric | **Custo unitário** do produto (confirmado: não é o custo total do estoque — ex. produto com `estoque_total=1317` tem `custo_total=131.51`, claramente um valor por unidade) |
| `preco_venda` | numeric | Preço de venda unitário |
| `preco_custo` | numeric | Idêntico a `custo_total` na amostra verificada |

`public.marcas` — `id`, `nome`, `ativo`, `codigo_legado`.

**Achado importante (resolvido em 2026-07-16)**: a coluna `valor_venda` de
`produtos` estava zerada em 100% dos produtos porque **nunca tinha sido
sincronizada** — a migration `037` (13/07) só atualizava
`estoque_total`/`estoque_showroom`/`estoque_disponivel`/`custo_total`. A
planilha `Produtos__2026-07-15.xlsx` traz uma coluna `ValorVenda` própria
(preço unitário de venda, não uma coluna calculada) — sincronizada agora via
`scripts/importar_produtos_estoque.py` (ver "Realizado" abaixo).

### Fórmulas propostas — validadas contra o banco após a sincronização de 16/07

| Métrica (imagem) | Fórmula | Antes da planilha nova | Depois (16/07) | Imagem de referência |
|---|---|---|---|---|
| Valor_Estoque_Custo | `SUM(estoque_total × custo_total)` | R$3,88 Mi | R$3,88 Mi | R$4,17 Mi (-7%) |
| Valor_Estoque_Venda | `SUM(estoque_total × valor_venda)` | R$9,68 Mi | **R$10,34 Mi** | R$10,21 Mi (**+1,3%** ✅) |
| CMV "Disponível" | `SUM(estoque_disponivel × custo_total)` onde `estoque_disponivel > 0` | R$4,16 Mi (quase o total — errado) | **R$1,39 Mi** | R$1,99 Mi (-30%) |
| Venda "Disponível" | idem, com `valor_venda` | — | **R$4,97 Mi** | R$5,06 Mi (**-1,8%** ✅) |
| CMV "Negativos" | `ABS(SUM(estoque_disponivel × custo_total))` onde `estoque_disponivel < 0` | R$4,9 mil (180× menor — errado) | **R$760,7 mil** | R$890,94 mil (-14,6%) |
| Venda "Negativos" | idem, com `valor_venda` | — | **R$2,05 Mi** | R$2,30 Mi (-10,6%) |
| Valor_Showroom_Custo | `SUM(estoque_showroom × custo_total)` onde `estoque_showroom > 0` | — | R$82,6 mil | R$1,27 Mi (**ainda não bate**, 15× menor) |
| MKP (Markup) | `valor_venda ÷ custo_total` | — | Validado (faixa 2,5×–4,5×) | Consistente com a imagem 3 |

A sincronização da planilha nova resolveu a maior parte da divergência —
Venda Disponível e Venda Total agora batem dentro de 2%. `Valor_Showroom`
continua sem bater (15× menor) — a hipótese de `estoque_showroom × custo_total`
provavelmente está errada; pode ser um valor de reposição/avaliação que não
existe no schema atual, não um cálculo derivado do estoque físico de
showroom. Fica como pendência, não é mais prioridade zero como "Negativos"
era antes da sincronização.

### Página de Interatividade — o que "mais interativo" significa aqui

As imagens mostram 3 padrões de interação do Power BI que o dashboard atual
(Recharts/React) não tem:
1. **Slicer de Marca** — um filtro global que afeta todos os visuais da página de uma vez. Implementável com um `<Select>` no topo da página, igual ao filtro Ano/Mês já usado em `Index.tsx`/`ContasPagarFoco.tsx` (SPEC-025).
2. **Cruzamento gráfico → tabela** (clicar numa marca no gráfico filtra a tabela abaixo) — implementável com estado local (`marcaSelecionada`) compartilhado entre os componentes da página.
3. **Árvore de decomposição do MKP** (imagem 3) — recurso nativo do Power BI sem equivalente direto em bibliotecas de gráfico React comuns; a proposta é substituir por uma **tabela ordenável/expansível** (marca → produtos) em vez de tentar replicar a árvore interativa.

### Fase 2 — desenho técnico do cross-filtering completo

`v_financeiro_realizado` (fonte de `cash-flow.ts`) tem `tipo` (receita/despesa),
`natureza`, `tipo_custo` (só preenchido para despesa — `fixo`/`variavel`/`outro`,
migration `20260715_045`), `desc_sub_grupo`, `desc_grupo`. As páginas
financeiras já buscam essas colunas via `fetchFinanceiro()` e filtram em
memória com `filterFinanceiro()` (por ano/mês) — o padrão de clique é o
mesmo: acrescentar um filtro em memória por `tipo_custo`/`desc_sub_grupo`
antes de chamar `computeKpisVisaoGeral()`/`computeKpisContasPagar()`/etc.,
sem duplicar lógica nova nesses `compute*`.

**Questão em aberto (não decidir sozinho — confirmar com o usuário antes de
implementar)**: `tipo_custo` só existe em linhas de despesa; linhas de
receita têm `tipo_custo = NULL`. Se o clique em "Contas Fixas" filtrar a
fonte de dados inteira por `tipo_custo = 'fixo'`, o KPI "Receitas
Realizadas" zera (nenhuma receita tem `tipo_custo` preenchido) — o que pode
parecer um bug e não uma feature. Duas opções:
1. **Filtrar tudo literalmente** (inclusive Receitas, que zeram) — mais
   simples, mais fiel ao pedido literal ("aquele lugar aplicado para toda a
   página").
2. **Filtrar só os KPIs/gráficos de despesa**, mantendo Receitas e
   Resultado Operacional no agregado geral — evita a leitura de "sistema
   quebrado", mas contraria a frase "toda a página".

Fica como pendência para confirmação do usuário antes da implementação
(ver "Passos manuais do usuário").

### Critérios de aceite

- [x] Selecionar uma marca no filtro atualiza todos os cards/gráficos/tabelas da página de Estoque.
- [x] KPIs de Custo/Venda Total, Disponível, Negativos e Showroom carregam com dado real (fórmula confirmada — `Valor_Showroom` ainda com divergência conhecida, ver Pendências).
- [x] Gráfico de barras e donut por marca refletem os mesmos números da tabela (mesma fonte `v_estoque_produtos`, sem duplicar lógica — todos os componentes consomem `groupByMarca()`/`computeKpisEstoque()` do mesmo `estoque.ts`).
- [x] Tabela de produtos com maior déficit ("a comprar") ordenada do maior custo para o menor.
- [x] Nenhum valor hardcoded/mock — tudo vem de `produtos`/`marcas` via Supabase (view `v_estoque_produtos`).

**Fase 2 (cross-filtering em toda a página):**
- [x] Clicar numa categoria em qualquer gráfico das páginas Visão Geral / Contas a Pagar Foco / Contas a Receber Foco filtra também os KPI cards do topo da mesma página (não só gráficos/tabelas auxiliares) — respeitando a exceção confirmada de Receitas/Resultado Operacional na Visão Geral.
- [x] Existe um indicador visual (chip/badge) mostrando o filtro de clique ativo, com opção de limpar — `FilterChip` compartilhado nas 3 páginas.
- [x] O filtro de clique convive com o filtro Ano/Mês já existente (os dois se combinam, não se substituem) — categoria aplicada sobre `filterFinanceiro()`.
- [x] Nenhuma página quebra/mostra erro quando o filtro resulta em conjunto vazio (ex. combinação ano+mês+categoria sem dados) — estados vazios tratados com mensagem ("Sem dados para este período.", "Nenhum valor em aberto nesta seleção.") nos 3 gráficos de origem do clique; QA (`skip_project_apply_changes`) passou limpo.

---

## Realizado

### 2026-07-16

- Criado `scripts/importar_produtos_estoque.py` (padrão dry-run + diff, igual ao script de Contas a Pagar/Receber) para sincronizar `produtos`/`estoque_itens` a partir de `01-Documento/01 - Planilhas/Produtos__2026-07-15.xlsx`.
- Descoberta: a coluna `produtos.valor_venda` nunca tinha sido sincronizada (100% zerada) — a migration `037` anterior não a incluía. A planilha nova tem uma coluna `ValorVenda` própria (preço unitário), agora sincronizada.
- Sincronização aplicada em produção: 4.352 produtos atualizados (2 exigiram correção manual — `percentual_lucro` de dois produtos excedia o limite da coluna `numeric(5,2)`, capado em 999,99%), 3.077 linhas de `estoque_itens` (locais `Estoque`/`Showroom`) upsertadas, 0 erros finais. `quantidade_reservada` não foi tocada (dado operacional vivo, fora do escopo da planilha).
- Refeita a validação das fórmulas de Disponível/Negativos/Venda com o dado fresco — a maioria caiu para uma divergência de 1-15% (antes era até 180×). `Valor_Showroom` continua sem bater, isolado como pendência específica.
- **Link permanente `produtos` ↔ `estoque_itens`** (pedido do usuário): migration `20260716_046_link_produtos_estoque_itens` criou o trigger `trg_sync_estoque_itens_from_produtos` (`AFTER INSERT OR UPDATE OF estoque_total, estoque_disponivel ON produtos`) que mantém `estoque_itens` (`local='Estoque'`) sempre com `quantidade = estoque_total` e `quantidade - quantidade_reservada = estoque_disponivel`, de forma automática e permanente — não depende mais de rodar um script toda vez. Causa raiz do desalinhamento anterior: `vw_necessidade_compra` soma `quantidade` de todos os locais por produto, e a linha de `Showroom` ficava desatualizada quando o showroom zerava, inflando a soma acima do `estoque_total` real. O trigger agora zera a linha de `Showroom` sempre que sincroniza, e consolida tudo em `Estoque`. Validado: 0 divergências em 4.725 produtos (inclusive 266 casos onde a planilha de origem tem `Disponível > Total` — permiti `quantidade_reservada` negativa nesses casos específicos para manter a igualdade exata, já que não há constraint proibindo). `scripts/importar_produtos_estoque.py` foi simplificado — não mexe mais em `estoque_itens` diretamente, o trigger cuida disso.

### 2026-07-16 (continuação — dashboard e interatividade)

- Criada migration `20260716_047_view_estoque_produtos` — view `v_estoque_produtos` (uma linha por produto ativo, com valores de custo/venda já calculados: total, disponível, negativo/déficit, showroom, e MKP). Fonte única das fórmulas validadas na SPEC; o frontend só agrega/exibe. Validado por query direta no banco: `valor_estoque_custo=R$3.879.831,37`, `valor_estoque_venda=R$10.344.144,76`, `cmv_disponivel=R$1.392.296,23`, `venda_disponivel=R$4.974.853,53`, `cmv_negativos=R$760.665,09`, `venda_negativos=R$2.053.870,60`, `showroom_custo=R$82.574,96`, `total_produtos=4725` — bate exatamente com os números "Depois (16/07)" da tabela de fórmulas acima.
- Criado `src/services/estoque.ts` no projeto Skip "Dashboard Lucenera" (id 41135): `fetchEstoque()` paginado (`.range()`, evita o limite de 1000 linhas do PostgREST), `computeKpisEstoque()`, `groupByMarca()`, `topDeficit()`, `groupMkpByMarca()` e o helper genérico `sortRows()` reusado em todas as tabelas ordenáveis.
- Criada `src/pages/Estoque.tsx` — nova página com: filtro global de Marca (Select, sentinel `'todas'`); 8 KPI cards (Custo/Venda Total, Custo/Venda Disponível, Custo/Venda em Déficit, Showroom, contagem de marcas no filtro); gráfico de barras "Estoque Disponível por Marca" (top 15, clicável); donut "Valor Disponível por Marca" (top 10, clicável); tabela ordenável "Marca × Valor Disponível" com linha de Total; tabela ordenável "Markup (MKP) por Marca"; gráfico de barras "Showroom por Marca"; tabela "Produtos com maior déficit". Clique em qualquer gráfico/linha de tabela seleciona a marca (mesmo estado `marcaSelecionada` do filtro do topo) — implementa o cross-filtering pedido na SPEC.
- Adicionada rota `/estoque` em `App.tsx`, entrada "Estoque" (grupo "Operações") em `app-sidebar.tsx`, e breadcrumb em `app-header.tsx`.
- QA (`skip_project_apply_changes`) passou limpo (setup/staticAnalysis/build/integrations/test) e publicado em produção (`skip_project_publish`) — `productionUrl: https://dashboard-empresa-40d7d.goskip.app`, ref `980ec12`.
- Filtro de Marca e cross-filtering ficaram restritos à página de Estoque — não estendidos às páginas financeiras (Visão Geral, Contas a Pagar/Receber Foco) nesta rodada, ver Pendências.

### 2026-07-16 (continuação — correção do link produtos ↔ estoque_itens)

- **Bug encontrado**: o usuário reportou que a sincronização "não estava funcionando". Investigação mostrou que `estoque_itens.quantidade_disponivel` **não é uma coluna gerada/computada** — é uma coluna própria e independente. O trigger criado na migration `20260716_046` só setava `quantidade` e `quantidade_reservada`, nunca `quantidade_disponivel`, que ficou **NULL nas 4.725 linhas** de `local='Estoque'`. A validação anterior (registrada como "0 divergências") usava o operador `<>` para comparar `quantidade_disponivel` com `estoque_disponivel` — em SQL, comparação com `NULL` retorna `NULL` (nem verdadeiro nem falso), então a contagem de divergências deu 0 mesmo com a coluna inteira vazia. O bug ficou mascarado por um erro na própria checagem de validação.
- **Fix**: migration `20260716_048_fix_link_quantidade_disponivel` reescreve `fn_sync_estoque_itens_from_produtos()` para setar `quantidade_disponivel = produtos.estoque_disponivel` diretamente (fonte da verdade), com `quantidade_reservada` derivada como `quantidade - quantidade_disponivel` (garante consistência interna por construção). Backfill aplicado a todas as 4.725 linhas existentes; linhas de `Showroom` remanescentes (337) zeradas nas três colunas (`quantidade`, `quantidade_disponivel`, `quantidade_reservada`).
- **Validação correta** (com `IS DISTINCT FROM`, que trata NULL corretamente): `disp_null=0`, `disp_diff=0`, `qtd_diff=0`, `internal_inconsistente=0` em 4.725 linhas de `local='Estoque'`; 0 linhas de `Showroom` com qualquer coluna não-zerada. Link agora é permanente e verificado nos dois pares pedidos pelo usuário: `estoque_itens.quantidade = produtos.estoque_total` e `estoque_itens.quantidade_disponivel = produtos.estoque_disponivel`.

### 2026-07-16 (continuação — Fase 2, cross-filtering em toda a página)

- Implementado o cross-filtering pedido pelo usuário nas 3 páginas financeiras (`Index.tsx`, `ContasPagarFoco.tsx`, `ContasReceberFoco.tsx`), no projeto Skip "Dashboard Lucenera" (id 41135).
- `src/services/cash-flow.ts`: adicionados 3 helpers de filtro (`filterByTipoCusto`, `filterByDescSubGrupo`, `filterByDescricao`), aplicados em memória por cima do `filterFinanceiro()` (Ano/Mês) já existente, sem duplicar lógica nova nos `compute*`. `computeFluxoDiario()` ganhou um segundo parâmetro opcional `despesaRows` (default = mesmo array de `rows`) para permitir que Receita por dia sempre some o total geral enquanto Despesa por dia pode vir de um subconjunto filtrado por `tipo_custo` — sem essa separação, filtrar por categoria de despesa zeraria a Receita nos gráficos de área.
- Criado `src/components/FilterChip.tsx` — chip "Filtrado por: {label} ✕" reutilizado nas 3 páginas (mesmo padrão visual do botão "limpar filtro" de `Estoque.tsx`, mas como badge com o rótulo da categoria ativa).
- **`Index.tsx`**: clique numa fatia do donut "Custo Operacional: Fixo × Variável" seleciona `tipoCustoSelecionado`. KPI "Despesa Operacional Total" passa a exibir só a despesa do tipo de custo clicado (título muda dinamicamente); "Saldo Acumulado"/"Resultado Diário" recalculam a despesa diária filtrada mantendo a receita diária total. Por decisão do usuário (confirmada nesta sessão), "Receitas Realizadas", "Distribuição de Lucro", "Resultado Operacional" e o card de Ponto de Equilíbrio **não** filtram — continuam sempre no total geral, para não dar a impressão de sistema quebrado quando `tipo_custo` não se aplica a receita.
- **`ContasPagarFoco.tsx`**: clique numa barra do gráfico "Despesa Operacional por Centro de Custo" ou numa linha da tabela "Centros de custo" seleciona `subGrupoSelecionado`; os 3 KPIs e o gráfico "Previsto em Aberto" recalculam só para aquele `desc_sub_grupo`. O gráfico de origem continua mostrando todos os subgrupos (destacando o selecionado) para permitir trocar de seleção sem precisar limpar primeiro.
- **`ContasReceberFoco.tsx`**: clique numa fatia do donut "Receita Realizada por Descrição Apropriação" seleciona `apropriacaoSelecionada`; os 4 KPIs recalculam para aquela `descricao`. A fatia "Outros" (agregado de categorias menores no `groupReceitaPorApropriacao`) foi deliberadamente deixada não-clicável, pois não corresponde a um valor exato de `descricao` no banco.
- Polimento visual pedido pelo usuário ("muito mais atrativo"): hover com leve elevação/sombra nos KPI cards das 3 páginas, transições suaves de opacidade ao destacar/apagar fatias e barras selecionadas, animação de entrada nas áreas dos gráficos. Cores reaproveitam os tokens `--chart-1` a `--chart-5` já usados no projeto (paleta única, dark-only) — nenhuma paleta nova introduzida.
- QA (`skip_project_apply_changes`) passou limpo (setup/staticAnalysis/build/integrations/test) e publicado em produção (`skip_project_publish`) — `productionUrl: https://dashboard-empresa-40d7d.goskip.app`, ref `2155605`.

### 2026-07-16 (continuação — polish visual pedido pelo usuário, só dados reais)

- Usuário pediu um dashboard executivo "premium" com métricas técnicas de iluminação (UGR, lm/W, funil de orçamentos, margem por fornecedor de luminária) — checado o schema real (`supabase/db/domains/*`, `01_schema_full.sql`) e nenhuma dessas colunas/tabelas existe; a Lucenera não é modelada como escritório de light design neste schema (cor institucional é verde `#2E7D32`, domínios são financeiro/estoque_compras/crm/rh/orçamentos genéricos). Sinalizado ao usuário, que confirmou: desconsiderar as métricas técnicas fictícias e só melhorar a UI/hierarquia do dashboard existente com os dados reais já usados.
- **`Index.tsx`**: reordenada a hierarquia dos KPIs — "Resultado Operacional" virou um card "hero" no topo (maior, com fundo em gradiente da cor primária), já que é o número mais importante para a Diretoria. Adicionado `margemOperacional` (resultado ÷ receita) como estatística secundária no hero. Adicionado comparativo "vs mês anterior" (`DeltaBadge`, seta + variação percentual, verde/vermelho com semântica invertida para despesa) nos KPIs de Receita, Despesa e Distribuição de Lucro — só aparece quando Ano E Mês estão os dois selecionados (evita comparar um agregado "todos os meses" com um único mês).
- **`ContasPagarFoco.tsx`** / **`ContasReceberFoco.tsx`**: KPI "Em Aberto" (Pagar/Receber) ganhou um tom de atenção (âmbar) para se destacar como o número mais acionável da página.
- **`Estoque.tsx`**: alinhado o hover dos KPI cards (leve elevação + sombra) com o mesmo padrão das outras 3 páginas, por consistência visual.
- QA (`skip_project_apply_changes`) passou limpo e publicado em produção — `productionUrl: https://dashboard-empresa-40d7d.goskip.app`, ref `1c350b0`.

## Pendências

- [ ] **Confirmar a fórmula de "Valor_Showroom"** — ainda 15× menor que a imagem de referência mesmo com dado atualizado.
- [x] Confirmar se o corte "Disponível"/"Negativos" deve usar `estoque_disponivel` (coluna já sincronizada) ou recalcular a partir de `estoque_itens.quantidade - quantidade_reservada` — **resolvido em 2026-07-16**: com o fix da migration `048`, as duas fontes são garantidas idênticas por construção (`quantidade_disponivel` é setada diretamente a partir de `estoque_disponivel`, e `quantidade_reservada` é derivada para manter `quantidade - quantidade_reservada = quantidade_disponivel` sempre). Não há mais divergência possível entre as duas.
- [ ] Decidir se o filtro de Marca e o cruzamento gráfico↔tabela devem ser estendidos também às páginas financeiras existentes (Visão Geral, Contas a Pagar/Receber Foco) — não fazem sentido direto lá (não há coluna Marca no financeiro consolidado), ficou restrito à página de Estoque nesta rodada; reavaliar só se o usuário pedir.
- [x] Cross-filtering em toda a página (Visão Geral / Contas a Pagar Foco / Contas a Receber Foco) — **resolvido em 2026-07-16**, ver Fase 2 acima.
