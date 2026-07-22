---
titulo: "SPEC-041 — Dashboard Financeiro: Nomenclatura Realizado × Previsto e Campo de Necessidade de Compra"
status: implementado e publicado (Skip 41135, versão a47805c)
data_ultima_modificacao: 2026-07-22
sistemas_envolvidos:
  - Skip Cloud — "Dashboard Lucenera" (projeto id 41135, host dashboard-empresa-40d7d.goskip.app) — espelhado localmente em 04-Sistemas/dashboard-lucenera-b02z85wa3
  - Banco central (Supabase, leitura apenas) — v_financeiro_realizado, vw_necessidade_compra
referencias:
  - SPEC-025 (Dashboard Financeiro Lucenera Cash Flow — implementação original de Visão Geral, Contas a Receber Foco, Contas a Pagar Foco)
  - SPEC-039/040 (Necessidade de Compra — mesma view vw_necessidade_compra consumida hoje pelo sistema compras-lucenera-3o23t98ee)
  - Reunião 21/07/2026 — Filippo, "Visualização do dashboard" (02-Reunioes/11.Lucenera (Filippo) - 21.07.2026_Reunião sobre a Visualizacao do dashboard/Dashboard.txt)
---

# SPEC-041 — Dashboard Financeiro: Nomenclatura Realizado × Previsto e Campo de Necessidade de Compra

> Reunião preliminar (21/07/2026): o próprio usuário afirmou que ainda vai mandar
> um áudio detalhando o que quer no Dash ("fluxo de caixa consolidado, fluxo
> previsto" ficam para depois). Esta SPEC cobre **apenas** os 4 ajustes pedidos
> agora — nomenclatura e estrutura visual — sem antecipar o fluxo consolidado/
> previsto completo.

## Checklist de Ação

### Frontend (`dashboard-lucenera-b02z85wa3` / Skip projeto 41135)

- [x] Renomear item de menu e `<h1>` de "Contas a Receber Foco" → "Agenda de Recebimentos"
- [x] Renomear item de menu e `<h1>` de "Contas a Pagar Foco" → "Agenda de Pagamentos"
- [x] Implementar a aba "Fluxo de Caixa Realizado (Mês Atual)" — renomeação de menu/`<h1>` + default de `ano`/`mes` para o mês atual em `Index.tsx` (Selects continuam editáveis)
- [x] Implementar o aviso visual sobre "Em Aberto" ser valor acumulado total, não do mês — `Info` + `Tooltip` ao lado do título dos KPIs `Em Aberto (Receber)`/`Em Aberto (Pagar)`
- [x] Implementar o campo/KPI "Necessidade de Compra (Gasto Futuro Inevitável)" — novo card em `Index.tsx`, tom violeta, `SUM(pendente × preco_custo)` via novo `src/services/necessidade-compra.ts`
- [x] Rodar `oxlint`/`tsc --noEmit`/`vite build` após as alterações — todos passaram sem erros

### Passos manuais do usuário

- [x] Decidir P-01 a P-05 (ver "Pendências") — todas respondidas com a opção recomendada
- [x] Confirmado no Supabase real que `vw_necessidade_compra.pendente` existe e tem `GRANT SELECT` para `anon`/`authenticated`/`service_role` — acessível sem mudança de RLS
- [ ] Verificar golden path no navegador em produção (não há suíte de testes automatizada neste sistema)
- [x] Publicado no Skip Cloud (projeto 41135) — QA (setup/lint/build/testes) passou limpo, publicação confirmada pelo usuário, produção em `dashboard-empresa-40d7d.goskip.app` (versão `a47805c`)

## Objetivo

Ajustar a nomenclatura e a estrutura visual do Dashboard Financeiro para refletir
a distinção pedida pelo usuário na reunião de 21/07/2026 entre **Realizado**
(o que já aconteceu — "se eu parar e mandar todo mundo pra casa, é isso que eu
tenho") e **valores em aberto/futuros**, evitando a sensação de que os números
"não batem" quando comparados a um período específico. Inclui também preparar
(não implementar por completo) um campo de "Necessidade de Compra" como gasto
futuro inevitável, categorizado à parte do fluxo de caixa realizado.

## Decisões aprovadas

- Renomear "Contas a Receber Foco" → **"Agenda de Recebimentos"** e "Contas a
  Pagar Foco" → **"Agenda de Pagamentos"** — troca de rótulo/label apenas
  (título do menu + `<h1>` da página); as **rotas** (`/contas-receber-foco`,
  `/contas-pagar-foco`) permanecem inalteradas para não quebrar links/bookmarks
  existentes, salvo objeção do usuário.
- "Fluxo de Caixa" (qualquer variação: Realizado, Previsto, Consolidado) fica
  reservado como conceito de **dados já efetivados** (`v_financeiro_realizado`,
  `status_pago = 1`) — a "necessidade de compra" nunca deve ser somada dentro
  dele, mesmo sendo "gasto futuro que necessariamente vai vir" (decisão do
  próprio usuário na reunião, ao se autocorrigir).
- Esta SPEC não implementa "fluxo consolidado"/"fluxo previsto" como conceito
  completo — só deixa a nomenclatura/estrutura preparada para isso no futuro,
  conforme a reunião.

## Análise de ecossistema

- **Depende de `projetos`/`orcamentos`/`contatos`/`produtos`/`boletos`/
  `projeto_itens`/`projeto_parcelas`/`usuarios`/`systems`/`user_system_access`?**
  Não diretamente. O sistema lê apenas `v_financeiro_realizado` (`transacoes`
  → `negociacoes` → `plano_de_contas`, já resolvida em view) e, para o item 4,
  `vw_necessidade_compra` (que por sua vez depende de `estoque_itens`/
  `produtos`/`marcas`, mas o dashboard só faz `SELECT` na view pronta, sem
  tocar nas tabelas-fonte).
- **Afeta CRM, Orçamentos, Financeiro, Cadastro, Estoque/Compras, Logística,
  RH ou Hub/TI?** Afeta apenas o domínio **Financeiro** (o próprio dashboard).
  Não há escopo dedicado a "Dashboard" em `03-Projeto/Escopos/` — o sistema é
  tratado dentro do guarda-chuva Financeiro desde a SPEC-025; `06_ESCOPO_FINANCEIRO.md`
  não menciona o dashboard, então não há contradição a resolver ali.
- **Dado duplicado que deveria ser derivado por relacionamento?** Não. O
  dashboard não grava nada — é 100% leitura de views já existentes. Nenhum
  cálculo de negócio deve ficar no frontend (regra já estabelecida pela
  SPEC-025 e reafirmada aqui): a soma de `necessidade_compra × preco_custo`
  proposta no item 4 é uma agregação simples de exibição, não uma nova regra
  de classificação de negócio.
- **Migration antiga que contradiz o snapshot central?** Não aplicável — esta
  SPEC não cria nem altera nenhuma tabela/view/função no Supabase.
- **Exige atualizar `AI_DB_CONTEXT.md` de algum sistema?** Não — nenhuma
  mudança de banco. Se o item 4 for implementado, vale registrar em
  `supabase/db/domains/estoque_compras.md` que `vw_necessidade_compra` passou
  a ter um segundo consumidor (o dashboard, além de `compras-lucenera-3o23t98ee`),
  para que futuras mudanças nessa view avaliem os dois sistemas antes de alterar
  colunas.
- **Padrão de acesso a dados já usado pelo sistema:** `src/services/<domain>.ts`
  com `supabase.from(...)` direto (sem hooks/stores intermediários — ver
  `cash-flow.ts`), consumido por página em `src/pages/`, com componente
  `KpiCard` local reaproveitado em cada página (`ContasReceberFoco.tsx`,
  `ContasPagarFoco.tsx` cada um define seu próprio `KpiCard`, não há um
  componente compartilhado global ainda). Qualquer novo código desta SPEC deve
  seguir esse mesmo padrão — não introduzir Redux/Zustand/React Query, nem um
  novo padrão de fetch.

## Definição da SPEC

### Estado atual (grounded no código real, lido nesta sessão)

**Achado importante — o código atual contradiz o "Realizado" registrado na
SPEC-025.** A SPEC-025 (`Realizado`, 2026-07-15) afirma que `src/pages/Index.tsx`
foi reescrita para mostrar Receita Realizada/Despesa Operacional/Resultado
Operacional a partir de `v_cash_flow_lucenera`/`v_financeiro_realizado`, com o
scaffold de sincronização removido. **O `Index.tsx` lido nesta sessão não
corresponde a essa descrição**: hoje ele busca `vw_projetos_dashboard`,
`vw_vendas_por_projeto` e `sync_history` (tabelas completamente diferentes,
sem relação com `v_financeiro_realizado`) e mostra 4 KPIs — "Projetos Ativos",
"Vendas Totais", "Última Sync", "Alertas (24h)" — mais um gráfico de
"Atividade Recente de Sincronização" e um botão "Sincronizar Tudo". A sidebar
(`app-sidebar.tsx`) também ainda lista o grupo "Sistema" com Sincronização/
Histórico/Configurações, que a SPEC-025 registrou como removido.

**ATUALIZAÇÃO (orquestrador, pós-planner): P-01 resolvida.** Consultei
diretamente o Skip Cloud (`mcp__skip__skip_file_read`) no projeto real —
confirmado **projeto 41135** ("Dashboard Lucenera", produção
`dashboard-empresa-40d7d.goskip.app`), não o 33127/33151 (outros projetos
Skip com nomes parecidos, não relacionados a este submodule). O `Index.tsx`
publicado em produção no Skip **já é** exatamente o que a SPEC-025 descreve:
título "Visão Geral Financeira", subtítulo "Fluxo de caixa realizado — dados
ao vivo do Supabase (v_financeiro_realizado)", KPIs de Receitas Realizadas /
Despesa Operacional Total / Distribuição de Lucro / Resultado Operacional,
Ponto de Equilíbrio, gráficos de saldo acumulado e resultado diário — tudo
usando `computeKpisVisaoGeral`/`computeFluxoDiario`/`computeCustoFixoVariavel`/
`computePontoEquilibrio` de `cash-flow.ts` (também confirmado no Skip, com
mais funções do que a cópia local).

**Causa confirmada: o espelho local deste submodule (`04-Sistemas/dashboard-lucenera-b02z85wa3`)
está desatualizado em relação ao Skip** — alguém implementou a SPEC-025
direto na plataforma Skip e publicou, mas isso nunca foi sincronizado de
volta para o git local (`Index.tsx` local ainda mostra o protótipo antigo de
sincronização; `cash-flow.ts` local não tem `computeKpisVisaoGeral` e as
demais funções de Visão Geral). **Ação técnica obrigatória antes de qualquer
edição desta SPEC**: puxar `Index.tsx`, `cash-flow.ts` (e conferir os demais
arquivos) do Skip 41135 para o git local, reconciliando o histórico, antes de
implementar qualquer item — do contrário corre-se o risco de editar a cópia
errada (desatualizada) e publicar um retrocesso ao aplicar `skip_project_apply_changes`.

Sidebar (`app-sidebar.tsx`) e rotas (`App.tsx`) já batem entre local e Skip —
"Visão Geral" (`/`), "Contas a Receber Foco" (`/contas-receber-foco`),
"Contas a Pagar Foco" (`/contas-pagar-foco"`) idênticos nos dois lados. O
grupo "Sistema" (Sincronização/Histórico/Configurações) **continua existindo**
no Skip real — a SPEC-025 registrar esse grupo como "removido" está incorreto
ou desatualizado; não é mais relevante corrigir isso agora, só não presumir
que ele sumiu.

Com isso, **P-01 está respondida**: a "aba principal" é a página `Index.tsx`
atual (rota `/`, já mostrando fluxo de caixa realizado de verdade) — basta
renomear o item de menu e o `<h1>`/subtítulo, e adicionar o filtro de mês
atual por padrão (ver Item 1 abaixo). Não é necessário redesenhar nem criar
rota nova.

Em contraste, `ContasReceberFoco.tsx` e `ContasPagarFoco.tsx` **batem
exatamente** com o que a SPEC-025 descreve como implementado em 2026-07-15
(KPIs de Vendas à Vista/a Prazo/Recebimentos/Em Aberto, donut de apropriação,
barras de centro de custo) — ou seja, a divergência é específica de `Index.tsx`
+ sidebar "Sistema", não do dashboard inteiro.

**O que existe hoje, por arquivo:**

| Arquivo | Conteúdo atual |
|---|---|
| `src/components/app-sidebar.tsx` (linhas 25-29) | Grupo "Financeiro": `Visão Geral` (`/`), `Contas a Receber Foco` (`/contas-receber-foco`), `Contas a Pagar Foco` (`/contas-pagar-foco`) |
| `src/pages/Index.tsx` | KPIs de sincronização (Projetos Ativos, Vendas Totais, Última Sync, Alertas), **não** relacionado a receita/despesa financeira |
| `src/pages/ContasReceberFoco.tsx` (linha 125-127) | `<h1>Contas a Receber Foco</h1>` + KPIs Vendas à Vista/a Prazo/Recebimentos/**Em Aberto (Receber)** |
| `src/pages/ContasPagarFoco.tsx` (linha 130-132) | `<h1>Contas a Pagar Foco</h1>` + KPIs Despesas com Material/Custo Operacional/**Em Aberto (Pagar)** |
| `src/services/cash-flow.ts` | Único serviço financeiro. `fetchFinanceiro()` pagina `v_financeiro_realizado` inteira (sem filtro de servidor); `filterFinanceiro(rows, ano, mes)` **já existe** e filtra em memória por `dt_pagamento ?? dt_vencimento`; `computeKpisContasReceber`/`computeKpisContasPagar` calculam "Em Aberto" somando **todas** as linhas com `status_pago IN (0,2)` do array recebido — sem filtro de mês embutido na função em si (o filtro, quando existe, já foi aplicado antes, pelo chamador) |

**Sobre o "Em Aberto" (item 3) — nuance técnica que muda o escopo do trabalho:**
`ContasReceberFoco.tsx`/`ContasPagarFoco.tsx` **já têm** seletores de Ano/Mês
(`Select` com opção "Todos os anos"/"Todos os meses") que, quando o usuário
escolhe um mês específico, filtram inclusive o "Em Aberto" (porque parcelas em
aberto não têm `dt_pagamento`, então caem no fallback `dt_vencimento` dentro de
`filterFinanceiro`). Ou seja, **o mecanismo para restringir "Em Aberto" a um
período já existe** — o problema relatado pelo usuário é que, por padrão
("Todos os meses" selecionado), o card mostra o total acumulado, e não há
nenhuma indicação visual de que esse é o comportamento padrão. Isso significa
que o item 3 é majoritariamente um ajuste de **UI/clareza**, não uma mudança
de cálculo — os valores citados pelo usuário (R$17M a pagar / R$726k a
receber) batem com a leitura sem filtro de mês, exatamente como a SPEC-025 já
validou (R$17,03M "Em Aberto (Pagar)" em 15/07/2026; o "Em Aberto (Receber)"
muda com o tempo por ser consulta ao vivo, R$726k é plausível como valor atual).

**Sobre "Necessidade de Compra" (item 4) — dados disponíveis:**

`vw_necessidade_compra` (conforme tipos gerados neste submodule, possivelmente
desatualizados — ver Checklist) expõe, por produto: `produto_id`, `produto`,
`produto_codigo`, `preco_custo`, `qtd_fisica`, `qtd_disponivel`,
`qtd_comprometida`, `projetos_com_entrega_futura`, `necessidade_compra`. **Não
existe** `preco_venda` nessa view (confirmado nos tipos) — a única base
monetária disponível é `preco_custo`. `supabase/db/domains/estoque_compras.md`
registra que a SPEC-039 (22/07/2026) acrescentou uma coluna `pendente`
(`GREATEST(0, necessidade_compra - qtd_em_pedidos_abertos)`) a essa mesma view
em produção — **essa coluna não aparece nos tipos gerados lidos nesta sessão**,
reforçando que os tipos deste submodule precisam ser conferidos/regenerados
contra o Supabase real antes de implementar o item 4. Nenhum arquivo `.tsx`
deste sistema hoje consome `vw_necessidade_compra`.

### Item 2 — Renomeação das abas "Foco" (fechado, pronto para implementar)

4 edições, sem ambiguidade:

1. `src/components/app-sidebar.tsx`, linha 27 — `title: 'Contas a Receber Foco'` → `title: 'Agenda de Recebimentos'`
2. `src/components/app-sidebar.tsx`, linha 28 — `title: 'Contas a Pagar Foco'` → `title: 'Agenda de Pagamentos'`
3. `src/pages/ContasReceberFoco.tsx`, linha ~126 — `<h1 ...>Contas a Receber Foco</h1>` → `Agenda de Recebimentos`
4. `src/pages/ContasPagarFoco.tsx`, linha ~131 — `<h1 ...>Contas a Pagar Foco</h1>` → `Agenda de Pagamentos`

O subtítulo (`<p>`) de cada página ("Segmentado por forma de recebimento...",
"Segmentado por centro de custo...") pode ser mantido, pois já descreve o
conteúdo real — nenhuma alteração de KPI, gráfico ou lógica nesses dois
arquivos.

### Item 1 — "Fluxo de Caixa Realizado (Mês Atual)" (P-01 resolvida; falta só P-02)

Já confirmado que a página certa é `Index.tsx` (rota `/`), já com todo o
conteúdo de fluxo de caixa realizado pronto no Skip. Falta apenas:

1. **Nomenclatura** (2 edições): item de menu em `app-sidebar.tsx`
   ("Visão Geral" → "Fluxo de Caixa Realizado (Mês Atual)") e título/subtítulo
   em `Index.tsx` (`<h1>Visão Geral Financeira</h1>` → "Fluxo de Caixa
   Realizado (Mês Atual)").
2. **Filtro de mês atual por padrão** (bloqueado por P-02): hoje `Index.tsx`
   inicia com `ano`/`mes` como `null` (equivalente a "Todos os anos"/"Todos os
   meses" nos `Select`s) — ou seja, mostra o acumulado geral por padrão, não
   o mês corrente. Para o rótulo "(Mês Atual)" fazer sentido, os `useState`
   iniciais de `ano`/`mes` precisam ser calculados a partir de `new Date()`
   (ano/mês corrente) em vez de `null`. Os `Select`s de Ano/Mês já existentes
   continuam funcionando normalmente para o usuário trocar o período depois
   — a única mudança é o valor inicial ao carregar a página.

### Item 3 — Aviso sobre "Em Aberto" ser total acumulado (bloqueado por P-03)

Três alternativas concretas, todas de baixo risco/baixo esforço, aplicáveis
em `ContasReceberFoco.tsx` e `ContasPagarFoco.tsx` (e na futura aba do item 1,
se ela também expuser algum "Em Aberto"):

- **Alternativa A — Tooltip/ícone de informação** ao lado do título do KPI
  `Em Aberto (Receber)`/`Em Aberto (Pagar)` (ex.: `<Info>` do lucide-react com
  `Tooltip` do Radix, já usado em outros pontos do ecossistema), texto fixo
  do tipo "Valor acumulado total em aberto, não filtrado pelo período
  selecionado acima."
- **Alternativa B — Badge/label fixo** ao lado do título do card, tipo "Total
  Acumulado" (chip pequeno, sempre visível, sem precisar de hover) — mais
  visível que a tooltip, porém ocupa mais espaço no card.
- **Alternativa C — Banner de aviso no topo da página**, uma única vez por
  página (ex.: `Alert` do shadcn), explicando que os cards marcados como "Em
  Aberto" mostram o passivo/ativo total acumulado, independente do filtro de
  Ano/Mês selecionado.

As alternativas não são mutuamente exclusivas (A+B é combinação razoável),
mas a escolha final é do usuário — ver P-03.

### Item 4 — Campo "Necessidade de Compra" (bloqueado por P-04/P-05)

Proposta técnica de métrica (não é decisão de negócio autônoma — está descrita
para o usuário validar em P-05): `SUM(necessidade_compra × preco_custo)` sobre
`vw_necessidade_compra`, que representa o custo de reposição do déficit bruto
atual de estoque. Alternativa mais estrita: `SUM(pendente × preco_custo)`
(descontando o que já está coberto por pedidos de compra em aberto, conforme
a coluna `pendente` adicionada na SPEC-039) — essa é provavelmente a leitura
mais fiel de "o que ainda falta comprar", mas depende de confirmar que a
coluna `pendente` está de fato disponível e exposta para leitura pública
(RLS) a este sistema. Rótulo sugerido, usando a frase literal da reunião:
"Necessidade de Compra — Gasto Futuro Inevitável" (ou variação mais curta:
"Gasto Futuro Inevitável (Compras)").

Onde exibir é pergunta aberta (P-04) — três alternativas:

- **Alternativa A** — novo KPI card na página que virar "Fluxo de Caixa
  Realizado (Mês Atual)" (item 1), como card **visualmente separado** dos
  demais (ex.: cor/tom diferente, para reforçar que não é "realizado").
- **Alternativa B** — nova aba própria "Necessidade de Compra" no menu,
  reaproveitando o padrão de página das abas "Agenda de..." (filtro
  Ano/Mês não se aplicaria da mesma forma, já que a view não tem data).
- **Alternativa C** — card lateral/informativo dentro de uma página já
  existente (ex.: um card fixo no rodapé da futura "Fluxo de Caixa Realizado",
  sem virar KPI de destaque).

## Pendências

- [x] **P-01 — Onde fica "a aba principal"?** RESOLVIDA por investigação direta
  no Skip Cloud (projeto 41135): é `Index.tsx` (rota `/`), que já mostra fluxo
  de caixa realizado de verdade em produção — o espelho local do submodule é
  que estava desatualizado (protótipo antigo de sync). Ver seção "Estado
  atual" acima para o achado completo.
- [x] **P-02 — Filtro fixo ou editável?** DECIDIDO: começa no mês/ano atual
  (`new Date()`) por padrão, mas continua editável pelos `Select`s de Ano/Mês
  já existentes em `Index.tsx` — sem travar a página.
- [x] **P-03 — Aviso visual do "Em Aberto"?** DECIDIDO: Alternativa A —
  tooltip/ícone de informação (`Info` do lucide-react + `Tooltip` do Radix,
  já usado no projeto via `TooltipProvider` em `App.tsx`) ao lado do título
  dos KPIs `Em Aberto (Receber)`/`Em Aberto (Pagar)`, texto: "Valor acumulado
  total em aberto, não filtrado pelo período selecionado acima."
- [x] **P-04 — Onde exibir "Necessidade de Compra"?** DECIDIDO: Alternativa A
  — novo KPI card na página "Fluxo de Caixa Realizado (Mês Atual)"
  (`Index.tsx`), com estilo visual distinto (tom "future", cor violeta) dos
  demais KPIs de realizado, para reforçar que não é dado realizado.
- [x] **P-05 — Métrica e rótulo?** DECIDIDO: `SUM(pendente × preco_custo)`
  sobre `vw_necessidade_compra` (déficit líquido, já descontando pedidos de
  compra em aberto — coluna `pendente` da SPEC-039). **Confirmado no Supabase
  real**: a coluna `pendente` existe e tem `GRANT SELECT` para `anon`/
  `authenticated`/`service_role` — acessível a este sistema sem nenhuma
  mudança de RLS. Amostra real (22/07/2026): `SUM(pendente × preco_custo)` ≈
  R$751.663,87 sobre 234 produtos (idêntico a `SUM(necessidade_compra ×
  preco_custo)` no momento da consulta, porque quase não há pedidos de compra
  em aberto ainda — os dois valores devem divergir conforme mais pedidos
  forem registrados). Rótulo: "Necessidade de Compra (Gasto Futuro
  Inevitável)".
- [x] Confirmado que os `types.ts` deste submodule estão desatualizados
  (não têm a coluna `pendente`, entre outras) — decisão: **não regenerar os
  tipos completos nesta SPEC** (fora de escopo, mudança grande e arriscada
  para um ajuste de nomenclatura/visualização); a nova consulta a
  `vw_necessidade_compra` usa `(supabase as any)` para essa chamada
  específica, mesmo padrão já usado em outros sistemas do ecossistema quando
  os tipos gerados ficam temporariamente atrás do schema real.
- [x] ~~Investigar se `Index.tsx`/sidebar divergem do Skip Cloud~~ — resolvido:
  confirmado que sim, o espelho local está desatualizado. Antes de editar,
  puxar `Index.tsx` e `cash-flow.ts` reais do Skip 41135 para o git local
  (reconciliar o histórico), para não editar/publicar por cima da versão
  errada.
