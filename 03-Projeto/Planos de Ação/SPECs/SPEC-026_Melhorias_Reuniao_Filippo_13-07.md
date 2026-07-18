---
titulo: "SPEC-026 — Melhorias diversas (reunião Filippo/Pedro 13-07-2026)"
status: pendente
data_ultima_modificacao: 2026-07-15
sistemas_envolvidos:
  - Dashboard Lucenera (Skip, id 41135)
  - Central Lucenera (hub de sistemas)
  - compras-lucenera-3o23t98ee (Necessidade de Compra / Pedido de Compra)
  - Orçamentos (aprovação, prazo de entrega, geração de PowerPoint)
  - Lucenera Sistema de Entregas
dependencias:
  - SPEC-025 (Dashboard Financeiro Lucenera) — base do que este documento estende
  - SPEC-022 (Destino da Necessidade de Compra por Projeto e Cliente) — já cobre "para quem vai" o item
  - SPEC-021 (Registrar Pedido de Compra Frontend e RPC)
---

# SPEC-026 — Melhorias diversas (reunião Filippo/Pedro 13-07-2026)

> Consolidação de tudo que foi discutido na reunião de 2026-07-13 entre Filippo
> e Pedro (transcrição em `02-Reunioes/09. lucenera (Filippo) - 06.07.2026_...
> /00_original/Reniao com o Filippo e Pedro 13-07.txt`). A transcrição é de
> áudio automático, com trechos truncados/ambíguos — vários itens aqui exigem
> confirmação antes de virar trabalho, conforme o próprio Filippo pede no fim
> da reunião ("antes de criar qualquer coisa, eu peço pra ele criar uma spec").

---

## Checklist de Ação

### Dashboard Financeiro — melhorias de conteúdo
- [x] Gráfico Custo Fixo × Custo Variável — implementado em `v_financeiro_realizado.tipo_custo` (migration `20260715_045`) + `Index.tsx` (Dashboard Lucenera, Skip id 41135). Classificação por `desc_sub_grupo` é um **default proposto**, pendente de validação (ver P-01/P-03).
- [x] KPI "Ponto de Equilíbrio" (breakeven simplificado = Receita Realizada × Custo Fixo do período), com indicador visual verde/vermelho — mesma página.
- [x] "Contas a Pagar Foco" confirmado como já implementado (SPEC-025).

### Central Lucenera (hub) — quick win
- [x] Sistemas internos abrem em nova aba — `SystemCard.tsx`, `Dashboard.tsx` e `cross-system-auth.ts` (Skip id 37750), publicado.

### Necessidade de Compra / Orçamento — prazo e reposição
- [x] "Dias em aberto" (aging) adicionado a `vw_entrega_futura_projeto_item` (migration `20260715_044`) e exibido em `NecessidadeDetailsPanel.tsx` (Skip id 40326) — badge colorido (cinza/âmbar/vermelho conforme idade).
- [x] `orcamentos.prazo_entrega_dias` criado e calculado automaticamente via `fn_add_dias_uteis` + `vw_orcamentos_prazo_entrega` (migration `20260715_042`), campo exposto em `BudgetFormPage.tsx` (Skip id 32554, sistema `gestao-financeira-clone-544cb`). **Correção de grounding**: a coluna `prazo_entrega` citada abaixo (item 6) pertencia a `orcamentos_revenda_ubiqua`, tabela não relacionada — a real precisou ser criada do zero.
- [x] `produtos.prazo_entrega_dias` e `marcas.prazo_entrega_dias` criados (migration `20260715_041`) — valores ficam `NULL` até serem preenchidos manualmente (prazos reais não estavam disponíveis).
- [x] `produtos.multiplo_compra` criado, default 1 (migration `20260715_041`).
- [x] `produtos.estoque_minimo` criado, default 0 (migration `20260715_041`).
- [ ] UI para editar `prazo_entrega_dias`/`multiplo_compra`/`estoque_minimo` por produto — colunas existem no banco mas ainda não têm tela de edição.
- [ ] Alerta de reposição quando `estoque_disponivel < estoque_minimo` (regra ainda não implementada — colunas prontas, falta a lógica).

### Pedido de Compra — revisão de fluxo (bloqueado)
- [ ] Reunião com Débora para mapear o fluxo real antes de mexer em `pedido_compra` — **não implementado, aguardando reunião**.
- [ ] Definir tabela de item de pedido (`pedido_compra_item` não existe hoje no schema central) — **bloqueado**.

### Sistema de Entregas — baixa prioridade
- [x] Busca por cliente **já existia** em `SeparacaoPage.tsx`, `PendentesPage.tsx` e `EntregasFinalizadasPage.tsx` (Skip id 24039) — verificado, nenhuma mudança necessária.

### Orçamento → Geração de Apresentação (PowerPoint)
- [ ] Investigar o sistema Python/IA separado que gera o PowerPoint a partir do XML do orçamento — **não iniciado**, ferramenta fica fora deste repositório.

### Passos manuais do usuário

- [ ] Confirmar com Filippo os itens ambíguos da transcrição marcados como "Pergunta em aberto" abaixo, principalmente a fórmula exata do Ponto de Equilíbrio (P-03) e a classificação Fixo×Variável (P-01) — implementadas com valores padrão, mas não confirmadas.
- [ ] Agendar a conversa com Débora sobre o fluxo real de pedido de compra (mencionada na reunião, ainda não marcada).
- [ ] Preencher `prazo_entrega_dias`, `multiplo_compra` e `estoque_minimo` reais por produto/marca (colunas criadas vazias/com default).

---

## Objetivo

Registrar, de forma estruturada e verificável, tudo que foi discutido na
reunião de 13/07 para servir de base às próximas SPECs — sem implementar nada
ainda, conforme o processo que o próprio Filippo valida na reunião (spec →
revisão → aprovação → implementação).

---

## Definição da SPEC

### 1. Dashboard Financeiro — validação do que já existe

Filippo demonstrou ao vivo o Power BI atual, incluindo a aba "Contas a Pagar
Foco" com filtro Ano/Mês/Dia e segmentação por `DescSubGrupo`
(administrativas, bancárias, com pessoal, com vendas, Filippo, fixas) — **isso
já está implementado no SPEC-025** (`ContasPagarFoco.tsx`, filtro Ano/Mês,
`groupDespesaPorSubGrupo`). Vale conferir com Filippo se o layout atual do
Skip cobre o que ele mostrou, já que a reunião aconteceu antes da SPEC-025
estar pronta.

### 2. Custo Fixo × Custo Variável (novo conceito de negócio)

Trecho-chave da reunião:

> "O custo fixo, mesmo que, por exemplo, energia elétrica é fixo, não importa
> que não seja sempre o mesmo valor, mas é o custo fixo. Salários são custos
> fixos. [...] Agora, comissões não é custo fixo, é custo variável. de
> arquitetos, [comissão] de [...] tudo que é relativo ao vendido. Se eu não
> vendo, não tenho aquele custo. Se eu vendo, tenho aquele custo."

Isso é uma dimensão **diferente** da `Natureza` (Despesa Operacional ×
Distribuição de Lucro) já implementada na SPEC-025 — é um corte adicional
sobre a própria Despesa Operacional.

**Estado real do schema**: a hierarquia `plano_de_contas` (usada por
`v_financeiro_realizado.desc_sub_grupo`) já tem um nível "FIXAS"
(`codigo_connect=2030000`), mas não tem um nó "VARIÁVEL" equivalente — os
demais subgrupos (COM VENDAS, COM PESSOAL, ADMINISTRATIVAS, VEICULOS,
BANCARIAS, PRODUTOS) não estão rotulados como fixo/variável. **Não dá para
derivar Fixo×Variável automaticamente do que já existe** — precisa de uma
regra explícita (provavelmente um mapeamento manual `desc_sub_grupo →
fixo|variável`, já que "COM VENDAS" mistura comissão (variável) com compra de
material (nem fixo nem variável no sentido clássico)).

**Proposta a validar com Filippo**: criar uma tabela pequena
`classificacao_custo (desc_sub_grupo text, tipo_custo text CHECK IN
('fixo','variavel'))` e um gráfico novo "Custo Fixo × Variável por mês" na
Visão Geral ou em página própria.

### 3. Markup / Ponto de Equilíbrio (tela nova)

> "Tem uma tela de markup importantíssima que é quanto eu preciso vender para
> eu sustentar como está indo cada mês. Se eu vender menos de um milhão, eu
> perco dinheiro. Se eu vendo mais, eu ganho nessa medida."

Isso é uma análise de **ponto de equilíbrio (breakeven)**: `Receita mínima
mensal = Custo Fixo do mês` (aproximadamente — depende de como definirem
margem/contribuição). Depende diretamente do item 2 acima (não dá pra
calcular breakeven sem primeiro separar custo fixo de variável).

**Proposta**: KPI "Ponto de Equilíbrio do Mês" + indicador visual (verde/
vermelho) comparando `Receitas Realizadas` do mês contra o breakeven
calculado, na Visão Geral.

### 4. Central Lucenera — abrir sistemas em nova aba

> "Quando eu clico em qualquer uma dos sistemas internos, abre uma nova
> janela automaticamente [...] que aí fica a aba dos sistemas internos sempre
> aberta e vai abrindo uma nova. [...] até para apresentar muito melhor."

**Grounded**: `04-Sistemas/central-lucenera-dashboard-1c9ba` (Skip id 37750),
`src/components/SystemCard.tsx` — hoje renderiza `<a href={url}>` sem
`target="_blank"`, navegando na mesma aba. Fix simples: adicionar
`target="_blank" rel="noopener noreferrer"` no `<a>` (e, se o card usa o
caminho `onOpen` com cross-system auth, abrir a nova aba manualmente via
`window.open` antes/depois do redirecionamento). **Item de baixo risco,
pronto para implementar assim que aprovado.**

### 5. Necessidade de Compra — prazo em aberto (aging)

> "O número de dias de pedido deve aparecer o mais antigo, 13 dias [...] as
> pessoas devem ver que tem um pedido daquilo há 13 dias."

Hoje a tela de Necessidade de Compra (SPEC-012/SPEC-022) não expõe há quantos
dias um item está em déficit. Proposta: computar `dias_em_aberto` a partir da
data mais antiga de `orcamentos`/`projeto_itens` que gerou aquele déficit
ainda não coberto, e exibir como badge (ex.: "13 dias", "1 semana").

### 6. Prazo de entrega no orçamento

> "O prazo de entrega em que nós comprometemos [n]enhum orçamento é
> importante colocar [...] Hoje nós não fazemos isso [...] Tecnicamente, se o
> orçamento é dado, o prazo é dado em dias úteis. A data vem
> automaticamente [...] A média é uns 25, 30 dias úteis."

**Grounded (corrigido durante a implementação)**: a coluna `prazo_entrega`
que parecia já existir pertence a `orcamentos_revenda_ubiqua` — uma tabela de
um fluxo não relacionado (catálogo Ubiqua). A tabela `orcamentos` real (usada
pelo fluxo de aprovação em `gestao-financeira-clone-544cb`, Skip id 32554)
**não tinha** nenhum campo de prazo de entrega. Implementado: coluna
`orcamentos.prazo_entrega_dias` (default 27 dias úteis, meio-termo do range
25-30 citado na reunião), função `fn_add_dias_uteis()` (soma dias úteis
seg-sex, **sem excluir feriados** — não existe tabela de feriados
compartilhada no banco central) e view `vw_orcamentos_prazo_entrega`
(calcula a data a partir de `aprovado_cliente_em`, com fallback para
`data_emissao`). Campo exposto no formulário de orçamento.

### 7. Prazo de entrega por produto/marca (fornecedor)

> "Dá pra fazer a partir da marca [...] já linkar com todos os produtos.
> Aquela marca demora uma média de 20 a 25 dias [...] A outra marca te dá uma
> planilha de quanto demora por peça."

**Grounded**: `produtos` não tem coluna de prazo de entrega/lead time hoje
(confirmado no schema atual). Precisa de uma coluna nova, possivelmente em
dois níveis: prazo padrão por `marca_id`, com override por `produto_id`
quando o fornecedor fornece prazo por peça.

### 8. Múltiplo de compra (MOQ / "caixa fechada")

> "A coluna dos múltiplos que podemos comprar [...] terá um que é 1 [...]
> outro item 5, outro item 8 [...] ele deve respeitar, toda vez que faz o
> pedido, a compra da caixa fechada."

**Grounded**: não existe coluna de múltiplo/MOQ em `produtos` hoje. Precisa
de coluna nova (`multiplo_compra integer default 1`) e validação no fluxo de
pedido de compra para arredondar a quantidade sugerida para o múltiplo mais
próximo.

### 9. Estoque mínimo / ponto de reposição

> "Tenho alguns itens que tem que ter [...] a quantidade que sempre deve
> permanecer. Tipo eu, em determinados [produtos] quando chega abaixo de 80
> compro de novo."

**Grounded**: não existe coluna de estoque mínimo em `produtos`/
`estoque_itens` hoje. Precisa de coluna nova e de uma regra que gere alerta
de reposição quando `quantidade < estoque_minimo`, independente de haver
venda pendente ou não (hoje a necessidade de compra só é gerada por
déficit de venda aprovada, não por ponto de reposição).

### 10. Pedido de Compra — fluxo real ainda não mapeado

> "Isso é criado pelo [Skip], mas não tem muita ligação com a nossa
> realidade. Por isso que não está funcionando [...] Vou ter que ver, vou
> sentar um dia com a Débora só pra conversar como que é feito, como que
> funciona, porque é ela que mexe com o pedido."

**Grounded**: `pedido_compra` existe no schema central (tabela plana:
`codigo_pedido`, `cod_fornecedor`, `nome_fornecedor`, `valor_nota`,
`data_emissao`, `data_vencimento`, `status`), mas **não existe**
`pedido_compra_item` nem `cotacao_fornecedor` no schema central — são
tabelas que só existiam num protótipo Skip/Lovable anterior, desconectadas
do modelo real (`projeto_itens` → `estoque_saldos_projeto_item` →
`vw_necessidade_compra_detalhe`, da SPEC-022). **Bloqueado** até a conversa
com Débora sobre o fluxo real de "dar baixa" num pedido.

### 11. Sistema de Entregas — busca por cliente em "Pendentes"

> "Essa busca por [cliente] poderia ser colocada nas coisas que estão
> pendentes? [...] mas tudo bem, não é urgente essa coisa, não é importante."

Já existe busca por cliente na aba "Finalizadas" do sistema de entregas
(feito em outra stack, "lovable"). Pedido de baixa prioridade — replicar a
mesma busca na aba de itens em andamento.

### 12. Orçamento → geração automática de apresentação (PowerPoint)

> "Atualmente, elas fazem [...] pegam o XML, levam para o sistema que eu fiz
> e dentro do sistema elas colocam o XML. E aí gera o PowerPoint [...] No
> caso do nosso sistema, a gente vai fazer tudo integrado. Orçamento
> aprovado. Aí fica separado lá para o pessoal conseguir fazer o download."

Hoje esse processo roda **fora** do ecossistema Lucenera (ferramenta Python/
IA separada de Filippo, fora deste repositório). Proposta de longo prazo:
quando o orçamento for aprovado, gerar automaticamente a apresentação e
disponibilizar para download dentro do sistema, para quem estiver
responsável pelo projeto (ex.: Marina, Isabela) — sem copiar/colar XML.
**Precisa primeiro entender o formato/lógica do gerador atual antes de
integrar.**

---

## Realizado

### 2026-07-15

- **Central Lucenera** (Skip id 37750): `SystemCard.tsx`, `Dashboard.tsx`, `cross-system-auth.ts` — sistemas internos agora abrem em nova aba (`window.open`/`target="_blank"`). Publicado.
- **Migrations aplicadas em produção**: `20260715_041` (prazo_entrega_dias/multiplo_compra/estoque_minimo em produtos e marcas), `20260715_042` (prazo_entrega_dias em orcamentos + fn_add_dias_uteis + vw_orcamentos_prazo_entrega), `20260715_043` (dias_em_aberto em vw_necessidade_compra_detalhe — view que acabou não sendo a usada pelo frontend, ver abaixo), `20260715_044` (dias_em_aberto na vw_entrega_futura_projeto_item — a view real), `20260715_045` (tipo_custo em v_financeiro_realizado).
- **Descoberta durante a implementação**: `vw_necessidade_compra_detalhe` (documentada na SPEC-022) existe no banco mas **não é a view consultada pelo frontend** — `src/services/necessidade-compra.ts` usa `vw_entrega_futura_projeto_item`, uma view diferente com estrutura semelhante. O `dias_em_aberto` foi adicionado nas duas por segurança, mas só a segunda está de fato em produção no app.
- **Orçamento** (Skip id 32554, `gestao-financeira-clone-544cb`): campo "Prazo de Entrega (dias úteis)" adicionado ao formulário (`BudgetFormPage.tsx`, `useBudgetStore.ts`), default 27 dias. Publicado.
- **Necessidade de Compra** (Skip id 40326): badge "Em Aberto" com dias desde a aprovação do orçamento, cor conforme urgência (cinza <7 dias, âmbar 7-20, vermelho ≥21). Publicado.
- **Dashboard Lucenera** (Skip id 41135): gráfico donut Custo Fixo × Variável + card "Ponto de Equilíbrio" (verde/vermelho conforme Receita Realizada vs. Custo Fixo do período). Publicado.
- **Sistema de Entregas**: verificado que a busca por cliente já existia nas 3 telas relevantes — nenhuma mudança necessária.
- **Não implementado, propositalmente**: Pedido de Compra (bloqueado — precisa da conversa com Débora) e integração do gerador de PowerPoint (fora do repositório, precisa investigação separada).

## Perguntas em aberto (transcrição ambígua — confirmar com Filippo)

| # | Trecho | Dúvida |
|---|---|---|
| P-01 | "Custo relativo" / comissão de "arquitetos, pontuação de crudimais" | Palavra "crudimais" não faz sentido em português — provavelmente erro de transcrição de áudio. Pode ser "corretagem" ou termo específico do setor. Confirmar antes de nomear a categoria no gráfico Fixo×Variável. |
| P-02 | "A questão do markado? De tentar trazer o dashboard para dentro do SQL. É do dia 8." | Trecho truncado/confuso — não ficou claro o que exatamente precisa ir "para dentro do SQL" nem o que significa "é do dia 8". |
| P-03 | Tela de Markup | Fórmula exata do ponto de equilíbrio não foi detalhada (é `Custo Fixo` puro, ou `Custo Fixo + margem mínima desejada`?). |
| P-04 | Múltiplo de compra | Confirmar se o múltiplo é sempre por produto individual ou pode variar por fornecedor do mesmo produto. |
| P-05 | Prazo de entrega por marca vs por peça | "A outra marca te dá uma planilha de quanto demora por peça" — significa que o prazo por produto individual tem prioridade sobre o prazo da marca quando ambos existem? |

---

## Pendências

- [ ] Validar com Filippo a classificação Fixo×Variável por `desc_sub_grupo` e a fórmula do Ponto de Equilíbrio — implementadas com default razoável, mas não confirmadas (P-01/P-03).
- [ ] Agendar reunião com Débora sobre o fluxo real de Pedido de Compra — bloqueia `pedido_compra_item`/`cotacao_fornecedor`.
- [ ] Levantar o formato do gerador de PowerPoint (Python/IA, fora do repo) antes de desenhar a integração do item 12.
- [ ] Preencher `prazo_entrega_dias` real por marca/produto (hoje `NULL`) — colunas prontas, faltam os valores e uma tela de edição.
- [ ] Preencher `multiplo_compra` e `estoque_minimo` reais por produto (hoje default 1/0) e implementar o alerta de reposição por ponto mínimo.
- [ ] `fn_add_dias_uteis()` não exclui feriados (não há tabela de feriados compartilhada no banco central) — `prazo_entrega_dias` do orçamento pode ficar levemente otimista perto de feriados prolongados.
