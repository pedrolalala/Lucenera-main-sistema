---
titulo: "SPEC-127 — Dashboard: enxugar cards de Estoque, Ponto de Equilíbrio, Investimento destacado, filtro de mês e aba 31/12 (reunião Vinícius 03/09)"
status: pendente
data_criacao: 2026-09-03
data_ultima_modificacao: 2026-09-03
sistemas_envolvidos:
  - Dashboard Financeiro — 04-Sistemas/dashboard-lucenera-b02z85wa3 (Skip projeto 41135, host dashboard-empresa-40d7d.goskip.app)
  - Banco central (Supabase) — v_financeiro_realizado, v_estoque_produtos, plano_de_contas / hierarquia (leitura + 1 migration de view para tipo_custo)
  - Connect / planilhas — nomenclatura de sub-grupo, datas 31/12 das pendências, setor showroom das peças (limpeza feita pela equipe, fora deste repo)
referencias:
  - SPEC-126 (Dashboard 100%: filtro por data, confiabilidade, Estoque bloco Reservado, Investimento, natureza) — base direta; esta SPEC continua os Escopos 5, 6 e 7 dela
  - SPEC-125 (site showroom / vitrine) — a nova aba "Showroom" do Dashboard é só leitura de v_estoque_produtos, não se confunde com o site público
  - SPEC-041 (Realizado × Previsto, card Necessidade de Compra, Ponto de Equilíbrio simplificado)
  - SPEC-064 (transacoes.perfil / filtro Ribeirão/São Paulo)
  - Reunião 03/09/2026 — Vinícius, "Dash e KPIS", Reunião 01 (02-Reunioes/22.Lucenera (Vinicius) - 03.09.2026_ Dash e KPIS/Reunião 01)
---

# SPEC-127 — Dashboard: cards de Estoque, Ponto de Equilíbrio, Investimento, filtro de mês e aba 31/12

> Sessão de trabalho ao vivo de 03/09 com o Vinícius, passando tela por tela do
> Dashboard. Quase tudo é **ajuste de visualização + revisão de classificação**,
> não feature nova. O objetivo continua sendo o mesmo da SPEC-126: o Filippo e
> o Vinícius baterem o olho e confiarem no número, sem "ficar lendo card".
>
> **⚠️ RESSALVA ESTOQUE — ver a seção "## Ressalva — Estoque" no fim.** As
> mudanças de card de Estoque são decisão de *layout* tomada ao vivo; elas
> **não corrigem** a causa da confusão (produto vendido-não-entregue aparece em
> "estoque geral" **e** em "reserva" no Connect). O número de Estoque só fecha
> depois da limpeza no Connect + export novo do Sérgio + SPEC-126 Escopo 5.

## Checklist de Ação

### Escopo 1 — Estoque: enxugar os cards (LIBERADO, mas ver ressalva)

Estado atual (`src/pages/Estoque.tsx`, 11 cards, nesta ordem): `Valor de Estoque (Custo)`, `Valor de Estoque (Venda)`, `Custo Disponível`, `Venda Disponível`, `Custo em Déficit (a comprar)`, `Venda em Déficit`, `De Cliente / Reservado (Custo)`, `De Cliente / Reservado (Venda)`, `Showroom (Custo)`, `Showroom (Venda)`, `Marcas no filtro`.

- [ ] **Remover** `Valor de Estoque (Custo)` e `Valor de Estoque (Venda)` — Vinícius passou ~30 min tentando reconciliar e concluiu "não faz sentido nenhum" (soma estoque geral que inclui peça vendida-reservada, dá a impressão de "isso + isso" que não fecha com nada). Decisão explícita: *"no estoque, os 2 primeiros cards eu vou retirar"*.
- [ ] **Remover** `Venda em Déficit` — *"a venda em déficit não faz sentido"* (o que falta comprar só interessa ao custo; a "venda" do que ainda nem se tem não representa nada).
- [ ] **Remover** `Showroom (Custo)` e `Showroom (Venda)` do topo — vão para a nova aba Showroom (Escopo 1B).
- [ ] **Reordenar** os cards que ficam, da esquerda para a direita por prioridade de leitura (*"a nossa primeira visão é da esquerda para direita"*):
  1. `Custo Disponível`
  2. `Custo em Déficit (a comprar)` — Vinícius quer o "número que importa mesmo" (o que precisa comprar) logo no começo; considerar trocar a ordem para deixar déficit à esquerda do disponível ("de repente pode até fazer ao contrário").
  3. `Venda Disponível`
  4. `De Cliente / Reservado (Custo)`
  5. `De Cliente / Reservado (Venda)`
  - Os "3 principais" para o Vinícius são `Custo Disponível`, `Venda Disponível`, `Custo em Déficit`. Os 2 de `Reservado` ficam, mas visualmente secundários (linha de baixo, ou estilo mais discreto) — *não* podem competir de igual pra igual com os 3 de cima.
- [ ] `Marcas no filtro` — card de contagem, baixo valor. Manter pequeno no fim, ou virar texto ("N marcas no filtro") no cabeçalho. Decidir na implementação (não foi citado, é limpeza óbvia).
- [ ] **Opcional (Vinícius indeciso, tende a NÃO):** um card `Custo Disponível + Reservado` (disponível + o que está separado pra cliente) — *"numa possível merda, pra gente saber"*. Ele mesmo disse *"aqui a gente faz na mão"* / *"isso aqui nem precisa ter"*. Deixar como sugestão, não implementar sem confirmar.
- [ ] `oxlint` + `tsc --noEmit` + `vite build` limpos; publicar no Skip 41135.

### Escopo 1B — Estoque: nova aba "Showroom" (LIBERADO)

- [ ] Nova rota `/showroom` no Dashboard, item no grupo **Operações** do menu lateral (ao lado de "Estoque"). *"vou tirar o showroom e deixar em operações aqui uma aba de showroom"*.
- [ ] Conteúdo: **lista de todas as peças que estão no setor showroom** (`estoque_showroom > 0` em `v_estoque_produtos`), com Código, Produto, Marca, Qtd showroom, Custo un., Venda un., Custo total (showroom), Venda total (showroom) — reaproveitar `PlanilhaTabela` + export CSV.
- [ ] KPIs da aba: `Showroom (Custo)` e `Showroom (Venda)` (os 2 cards que saíram do Estoque) + contagem de peças. Filtro de marca igual ao do Estoque.
- [ ] Sem gráfico obrigatório — Vinícius quer "praticidade, bater o olho".

### Escopo 1C — Estoque: filtro de marca múltiplo (LIBERADO)

- [ ] Trocar o `Select` de marca por **multi-seleção** (ex.: `command`/checkbox list ou `Select` múltiplo) no Estoque e na aba Showroom. Caso de uso do Vinícius: "ver tudo que tem de decorativo disponível" → hoje teria que abrir marca por marca (Bertolucci, Floss, Estúdio Della Cruz…).
- [ ] `filterByMarca(rows, marca: string | null)` → `filterByMarcas(rows, marcas: string[])` (vazio = todas). Ajustar `distinctMarcas`, gráficos e tabelas que hoje assumem 1 marca.
- [ ] **Nota:** o ideal seria um filtro por **categoria/sub-grupo** ("decorativo" × "luminária"), mas hoje as peças não têm essa distinção (todas entram como "luminária"). Isso é trabalho de dado (classificar peça por peça) — fica como item futuro, não bloqueia o multi-marca.

### Escopo 2 — Ponto de Equilíbrio: revisar a classificação fixo/variável (BLOQUEADO — depende de Filippo + Vinícius)

Contexto: no card "Ponto de Equilíbrio (Custo Fixo)" da tela *Fluxo de Caixa Realizado*, `Resultado = Receita Realizada − Custo Fixo`. **Custo Fixo** = soma de `vl_pago` das despesas realizadas com `natureza = 'despesa_operacional'` e `tipo_custo = 'fixo'`. `tipo_custo` é atribuído por **sub-grupo** (`desc_sub_grupo`) na view `v_financeiro_realizado` — hoje é um *default proposto* na reunião 13/07, nunca validado.

Reclamação do Vinícius: o PE varia demais de mês a mês (abril R$ 1.066 mil, maio R$ 831,8 mil) — *"não pode ter uma variação muito grande de um mês para o outro"*. Critério dele para "fixo": **"vendeu ou não vendeu, tem que pagar"**.

- [x] **Custos fixos de maio/2026 levantados** (pedido do Vinícius na reunião): total **R$ 330.902,76**, dominado por `COM PESSOAL` R$ 282.716,80 (85%), depois `ADMINISTRATIVAS` R$ 28.874,21, `FIXAS` R$ 9.752,73, `VEÍCULOS` R$ 6.857,94, `BANCÁRIAS` R$ 2.701,08. Receita realizada maio R$ 1.136.379,45 → Resultado PE +R$ 805.476,69. (Enviado ao Vinícius; ver detalhamento no anexo desta SPEC / conversa do Teams.)
- [ ] **Filippo + Vinícius:** revisar sub-grupo por sub-grupo e marcar `fixo` / `variável` / `outro` com o critério "vendeu ou não, tem que pagar". Itens que já pularam à vista como duvidosos:
  - `PRÊMIO DE VENDAS` (R$ 114 mil em maio, dentro de `COM PESSOAL` → hoje conta como fixo) — é comissão sobre venda, tem cara de **variável**.
  - `EMPRÉSTIMO` (dentro de `ADMINISTRATIVAS`) — pagamento de dívida, não é custo operacional fixo (talvez nem `despesa_operacional`).
  - `COMBUSTÍVEL` / `MULTAS` / `PEDÁGIOS` (`VEÍCULOS`) — variam com a operação.
- [ ] **Rever a nomenclatura de sub-grupo** (`desc_sub_grupo` / `desc_grupo`) — o Filippo mandou mensagem sobre isso; Vinícius: *"a gente precisava realmente sentar e bater todas as descrições de subgrupo"*. Pode ter nomenclatura errada vinda da importação da planilha (não é bug do Dashboard, é dado). Reconciliar com `plano_de_contas` / `hierarquia`. Ver também SPEC-126 Escopo 3 (allowlist de `codigo_connect` para `natureza`) — mesma árvore, fazer junto.
- [ ] Depois de decidido: **migration em `v_financeiro_realizado`** — o `CASE` de `tipo_custo` passa a usar uma allowlist explícita de `codigo_connect` (ou uma tabela de-para `sub_grupo → tipo_custo`) no lugar do default por texto de `desc_sub_grupo`. Redigir, revisar, aplicar no Supabase real.
- [ ] Dashboard: no card do Ponto de Equilíbrio, deixar visível **de quê** é composto o Custo Fixo (link/hover para a quebra por sub-grupo, ou reaproveitar a planilha da aba). *"depois você me passa o que que tá sendo feito esse cálculo"*.

### Escopo 3 — Investimento destacado (não como card do topo) (LIBERADO)

- [ ] Na tela *Fluxo de Caixa Realizado*, **abaixo** do gráfico "Custo Operacional: Fixo × Variável", adicionar um bloco/linha destacada **"Investimento"** com o total gasto em investimento no período. *"abaixo do custo operacional fixo, variável, eu colocaria investimento, que aí fica separado"*.
- [ ] **NÃO** é card no topo (*"se colocar mais um card aqui, cada vez mais ele vai ter que ficar lendo… fica mais poluído"*) e **NÃO** precisa de gráfico (*"eu acho que o gráfico não precisa. É só trazer destacado"*).
- [ ] Fonte: mesmo recorte da SPEC-126 Escopo 6 — `filterByDescGrupo(rows, 'INVESTIMENTO')` sobre despesa realizada no período (`distinctGrupos` já descobre o grupo sem hardcode). Não somar no Resultado Operacional / Ponto de Equilíbrio (é gasto à parte, igual Necessidade de Compra).

### Escopo 4 — Filtro de mês nas telas financeiras + bug do calendário (LIBERADO)

- [ ] **Levar o Select "Mês"** (o que já existe no Fluxo Futuro, SPEC-126 E8) também para *Fluxo de Caixa Realizado*, *Agenda de Recebimentos* e *Agenda de Pagamentos*. *"trazer para cá também então a seleção de mês"*. Deve conviver com o `<PeriodFilter>` (De/Até) — escolher um mês preenche o intervalo daquele mês.
- [ ] **Bug do calendário `range`** (`src/components/PeriodFilter.tsx`, `<Calendar mode="range">`): ao clicar num dia (ex.: julho) *"ele seleciona tudo para frente"* e só fecha o intervalo com **dois cliques no dia 1º**. Reproduzir e corrigir o comportamento do range (provável: `onSelect` não está tratando o segundo clique / `defaultMonth` empurrando a seleção). Objetivo: 1º clique = início, 2º clique = fim, sem "selecionar tudo pra frente".
- [x] **Conferência A Receber / A Pagar até maio** — validada pelo Vinícius na reunião: *"conferi o a receber e o a pagar até maio e bateu"*, *"a pagar tava batendo, o que tava errado mesmo era a receber"* (corrigido na SPEC-126 / import — duplicatas ambíguas → MANOELLA). Sem ação, só registro.

### Escopo 5 — Fluxo Futuro: regra do 31/12 e aba "31-12 / Pendências" (LIBERADO em parte, depende de limpeza)

O Connect usa **31/12 (de qualquer ano)** como "data-lixo" para títulos em aberto sem vencimento real definido (*"é tudo do dia 31, vai tudo para o dia 31/12"*). No *Fluxo de Caixa Realizado* isso não aparece (filtra por `dt_pagamento`, e não foram pagos); no **Fluxo Futuro** (que mostra o em aberto por `dt_vencimento`) esse monte entra e infla o gasto futuro — Devolução ~R$ 423 mil em 31/12/2026, RT já lançado como previsão, impostos/13º/salário provisionados 4 meses pra frente.

- [ ] **Nova aba "31-12 / Pendências"** (`/pendencias-31-12` ou similar), item no menu Financeiro. Lista **todos os títulos em aberto com `dt_vencimento` = 31/12 de qualquer ano** (2025, 2026, 2027…), a receber e a pagar, com a planilha detalhada + total por ano. *"31 do 12 barra pendências… independente do ano"*.
- [ ] **Fluxo Futuro passa a EXCLUIR** os títulos com `dt_vencimento` = 31/12 (qualquer ano) do gráfico, dos KPIs, da tabela mês a mês, da pizza e da planilha — eles vivem só na aba de pendências. *"eu paro de considerar na visualização 31 do 12 e só vai ficar como pendência"*. Adicionar um aviso/rodapé "N títulos em 31/12 movidos para a aba Pendências (R$ X)".
- [ ] Confirmar **como a regra do 31/12 foi resolvida no Fluxo de Caixa** (Pedro tem no histórico do Teams) e reaproveitar a mesma lógica — a mais provável é simplesmente "ignora `dt_vencimento` = 31/12".
- [ ] **Filtro De/Até retroativo no Fluxo Futuro:** hoje o horizonte só vai pra frente. Vinícius quer poder pôr *"de 1 de janeiro até 30/12"* para naturalmente cortar o 31/12 sem conta de padaria. Adicionar um `<PeriodFilter>`-like (ou dois `input date`) por `dt_vencimento`, **permitindo data inicial no passado** (para recortar a fatia "Vencido"). O horizonte 6/12/24/Tudo continua como atalho.
- [ ] Registrar (rodapé/tooltip): o fluxo muito à frente (2027-2030) é **previsão provisionada** (salário, imposto, 13º) — é real, não é erro; a empresa "tem que ter previsão". Não remover, só contextualizar.
- [x] Feedback positivo do Vinícius mantido: os **chips de filtro** ("Mês", "Grupo") e o drill de despesa por sub-grupo com % (SPEC-126 E8 v0.0.36) — *"achei que ficou legal… você consegue ver o que você fez aqui em cima"*. Sem ação.

### Escopo 6 — (PROPOSTA / provável SPEC própria) data de baixa estimada para cheque/RT de arquiteto

- [ ] Cheque/RT entregue ao arquiteto: ele dá baixa em **até 6 meses**, e hoje não há como "estipular que cai em 6 meses" — fica em aberto sem vencimento realista e vira pendência 31/12. Pedro: *"eu posso criar isso a partir do que a gente determinar"*.
- [ ] Definir com Vinícius/Filippo: no lançamento do cheque/RT, gravar uma **data de vencimento estimada** (default +6 meses da entrega) para o título entrar no fluxo no mês certo em vez de 31/12.
- [ ] Provavelmente mexe no **Connect / Administração Bancária**, não só no Dashboard → avaliar SPEC dedicada.

### Passos manuais da equipe (dependências, fora deste repo)

- [ ] **Carol** — dar baixa em tudo que já foi pago e ficou pendente pós-incidente de segurança de 2ª feira (perdeu-se sáb/dom/seg; terça sem baixar) → re-exportar o relatório.
- [ ] **Carol** — padronizar o ano das pendências antigas: `31/12/2024` → `31/12/2025` (a Connect só puxa de 2025 pra cá; 2024 era a troca de sistema).
- [ ] **Carol / Vinícius** — pente fino no 31/12: o que **não** é pendência real (MedSet, MED-7, imposto provisionado) vai para **30/12**; o que **é** pendência real fica no 31/12. Parcelas do **Rafael** (recuperação judicial, sem entrega, sem protesto) → 30/12.
- [ ] **Sérgio** — export novo (~10h da manhã); reconciliação de Estoque/31-12 só com a planilha atualizada.
- [ ] **Vinícius** — no Connect, mover para o setor *showroom* as peças que estão como "disponível / estoque geral" mas fisicamente estão no showroom (balanço junto com o app da Lana). Enquanto isso, os cards de Estoque não fecham 100% (ver ressalva).
- [ ] **Filippo + Vinícius** — sentar e bater **todas** as descrições de sub-grupo (fixo/variável e nomenclatura) — insumo do Escopo 2 e da SPEC-126 Escopo 3.

## Objetivo

Depois da reunião de 31/08 (SPEC-126) o Dashboard já bate com a planilha no
realizado e no em aberto. A reunião de 03/09 foi "passar o pente fino" na
visualização: **menos card, na ordem certa, sem número que não fecha com nada**,
e resolver os dois pontos que ainda confundem — o **Ponto de Equilíbrio** (que
varia demais porque a classificação fixo/variável nunca foi validada) e o
**31/12** (data-lixo das pendências que infla o Fluxo Futuro).

## Decisões aprovadas na reunião

- Estoque: **fora** os cards `Valor de Estoque (Custo/Venda)` e `Venda em Déficit`. Showroom vira **aba própria**. Cards principais (`Custo Disponível`, `Venda Disponível`, `Custo em Déficit`) sobem e vão para a esquerda.
- Filtro de marca do Estoque passa a aceitar **múltiplas marcas**.
- Investimento entra **destacado abaixo** do gráfico fixo/variável, **sem card no topo e sem gráfico**.
- Ponto de Equilíbrio: a fórmula está certa (`receita realizada − custo fixo`); o que falta é **validar o que é "custo fixo"** sub-grupo por sub-grupo (critério: "vendeu ou não, tem que pagar").
- 31/12 de qualquer ano vira **aba "31-12 / Pendências"** e **sai** da visualização do Fluxo Futuro.
- Fluxo Futuro ganha **filtro De/Até por vencimento com data retroativa permitida**.
- O fluxo provisionado longe (2027+) **continua aparecendo** — é previsão real, não erro.

## Definição da SPEC

### Estado atual medido (código lido em 03/09)

| Tela | Hoje |
| --- | --- |
| `Estoque.tsx` | 11 cards (lista acima). Filtro de marca `Select` único. Showroom são 2 cards + 1 gráfico + tabela, na mesma aba. `computeKpisEstoque` soma todos os campos de `v_estoque_produtos`; `reservadoQtd = max(0, total + showroom − disponivel)` (client-side, SPEC-126 E5 pendente). |
| `Index.tsx` (Fluxo de Caixa Realizado) | Filtro `<PeriodFilter>` (De/Até + Pagamento/Vencimento). Card "Ponto de Equilíbrio (Custo Fixo)" = `computePontoEquilibrio(filtradas)`. Gráfico "Custo Operacional: Fixo × Variável" (pizza). Sem bloco de Investimento. Sem Select de mês. |
| `FluxoFuturo.tsx` | Select "Mês", Perfil, Horizonte (6/12/24/Tudo), switch "Incluir vencidos". Pizza de despesa por grupo (SPEC-126 E8 v0.0.36). **Sem** regra de 31/12. **Sem** filtro De/Até retroativo. |
| `PeriodFilter.tsx` | `<Calendar mode="range">` com bug: 1 clique "seleciona tudo pra frente", fecha só com 2 cliques no dia 1º. |
| `v_financeiro_realizado` | `tipo_custo` (fixo/variável/outro) por `desc_sub_grupo`, default proposto 13/07 nunca validado. |

### Análise de ecossistema

- **Depende de** `v_estoque_produtos` (→ `produtos`, `estoque_itens`) e `v_financeiro_realizado` (→ `transacoes`, `negociacoes`, `plano_de_contas`/`hierarquia`). Nenhuma tela nova toca em `orcamentos`/`boletos`.
- **Migration** só no Escopo 2 (redefinição do `CASE` de `tipo_custo` em `v_financeiro_realizado`) — parte da mesma árvore da SPEC-126 Escopo 3 (`natureza` por `codigo_connect`); fazer as duas juntas para não reescrever a view duas vezes.
- **Dado duplicado?** Não criar coluna nova em `produtos`/`transacoes`. `estoque_reservado` continua devendo vir da view (SPEC-126 E5).
- **`AI_DB_CONTEXT.md`** do `dashboard-lucenera-b02z85wa3`: atualizar se a migration do Escopo 2 sair.

### Fluxo de trabalho

1. Escopos 1, 1B, 1C, 3, 4 e 5 são **frontend** no Skip 41135 — `skip_file_write` + `apply_changes` + `publish` (o submódulo git está atrás da produção; ver [[feedback_skip_local_pode_ter_menos_que_producao]]).
2. Escopo 2 espera a decisão do Filippo/Vinícius sobre a lista fixo/variável antes de qualquer migration.
3. Escopo 5 (aba 31/12 + exclusão no Fluxo Futuro) pode ir já; o pente fino da Carol/Sérgio só melhora os números, não bloqueia o código.
4. QA no navegador (não há suíte automatizada); publicar; registrar em SPEC + CHANGELOG + Central de Solicitações.

## Ressalva — Estoque

**As mudanças de card do Escopo 1 são decisão de layout, não correção de dado.**
O que o Vinícius passou meia hora tentando reconciliar tem causa no **modelo do
Connect**, não no Dashboard:

- Uma peça **vendida/reservada mas não entregue** fica com `disponível = 0` e
  aparece **ao mesmo tempo** em "estoque geral" **e** em "reserva". Por isso
  `Valor de Estoque (Custo/Venda)` (= `estoque_total × unitário`) parece
  "contar duas vezes" contra `De Cliente / Reservado`. A conta fecha
  internamente (`estoque geral + reserva` reconcilia — Vinícius chegou nos
  mesmos R$ 113.280 pelos dois caminhos na reunião), mas **visualmente
  confunde** — e é por isso que os 2 cards saem, não porque o número esteja
  "errado".
- A reconciliação de Estoque só fecha 100% depois de:
  1. **Vinícius mover no Connect** as peças que estão em "estoque geral" mas
     fisicamente são showroom (a diferença de R$ 731,22 que ele isolou na
     reunião era exatamente uma peça dessas);
  2. **Export novo do Sérgio** (~10h) e reimport;
  3. **SPEC-126 Escopo 5** — `v_estoque_produtos` expor `estoque_reservado`
     direto, para o "Reservado" parar de ser o cálculo de front
     `total + showroom − disponivel`, que hoje fica **inflado** pelo showroom
     (contado duas vezes) e pelas linhas em déficit.
- **Estoque não tem dimensão de tempo.** Todo card (e a nova aba Showroom) é
  foto do último import — não existe "estoque de maio". Não prometer histórico.
- O **multi-marca** (Escopo 1C) é paliativo. O filtro certo seria por
  **categoria/sub-grupo** ("decorativo" × "luminária"), mas as peças não têm
  essa marcação hoje (entram todas como "luminária") — classificar peça a peça
  é trabalho de dado à parte.

**Conclusão:** implementar os Escopos 1/1B/1C agora (é o que o Vinícius pediu e
destrava a leitura), mas **não** declarar "Estoque reconciliado" até a limpeza
no Connect + o Escopo 5 da SPEC-126. Os números da aba Estoque/Showroom seguem
aproximados até lá.

## Pendências

- [ ] Escopo 2 — Filippo/Vinícius validarem a lista fixo/variável e a nomenclatura de sub-grupo antes da migration.
- [ ] Escopo 5 — confirmar a lógica de 31/12 usada no Fluxo de Caixa (Pedro, histórico do Teams).
- [ ] Escopo 6 — decidir se a "data de baixa estimada de cheque/RT (+6 meses)" vira SPEC própria (mexe no Connect/Adm. Bancária).
- [ ] Limpeza da equipe (Carol/Sérgio/Vinícius) concluída antes de bater os números de Estoque e do 31/12.
- [ ] Re-sync do submódulo `dashboard-lucenera-b02z85wa3` com a produção do Skip (dívida de manutenção herdada da SPEC-126).

## Realizado

### 2026-09-03

- SPEC criada a partir da transcrição da reunião 03/09 (Reunião 01). Custos fixos de maio levantados e enviados ao Vinícius (R$ 330.902,76; 85% folha). Nenhuma alteração de código ainda.
