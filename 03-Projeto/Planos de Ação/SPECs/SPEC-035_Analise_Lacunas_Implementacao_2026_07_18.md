---
titulo: "SPEC-035 — Análise de Lacunas de Implementação (atualização 2026-07-18)"
status: "concluído — relatório de investigação; prioridade de execução pendente de decisão do usuário"
data_ultima_modificacao: 2026-07-18
sistemas_envolvidos:
  - CRM
  - Orçamentos
  - Financeiro / Retorno Bancário
  - Cadastro
  - Estoque/Compras
  - Logística
  - RH
  - Hub/TI
  - Ubiqua
dependencias:
  - 03-Projeto/07_ANALISE_LACUNAS_IMPLEMENTACAO_2026_07_07.md (relatório anterior, base de comparação)
---

# SPEC-035 — Análise de Lacunas de Implementação (atualização 2026-07-18)

> Esta SPEC é um **relatório de investigação**, não uma feature. Ela não decide
> prioridade, não decide regra de negócio, não implementa nada e não altera
> código/banco. É a atualização do relatório de 07/07/2026
> (`03-Projeto/07_ANALISE_LACUNAS_IMPLEMENTACAO_2026_07_07.md`), cobrindo o que
> mudou entre 07/07 e 18/07/2026 (SPECs 020 a 034, 11 dias de trabalho intenso
> em Estoque/Compras e Orçamentos) e o que continua igual. Itens já resolvidos
> nesse intervalo não são repetidos aqui — só o que segue em aberto ou que
> surgiu de novo.

---

## Checklist de Ação

Não há implementação nesta SPEC — o "checklist" abaixo é o que foi investigado, não o que foi construído.

- [x] Ler `03-Projeto/07_ANALISE_LACUNAS_IMPLEMENTACAO_2026_07_07.md` por completo (base de comparação)
- [x] Ler `README.md`, `AGENTS.md`, `00-Contexto/COMO_CRIAR_SPEC.md`, `_TEMPLATE_SPEC.md`
- [x] Ler as 9 reuniões em `02-Reunioes/` (ata + decisões/pendências de cada uma), com ênfase nas reuniões 07 (09/06), 08 (06/07) e 09 (13/07 — sem ata processada, mas totalmente absorvida pelas SPEC-026/SPEC-027)
- [x] Ler `02-Reunioes/00_FLUXOS_CONSOLIDADOS.md` e `00_INDICE_REUNIOES.md`
- [x] Ler frontmatter, Objetivo, Pendências e Passos manuais das ~35 SPECs em `03-Projeto/Planos de Ação/SPECs/` — leitura **integral** das SPECs 019 a 034 (período não coberto pelo relatório de 07/07)
- [x] Ler `CHANGELOG.md` completo, com ênfase em 2026-07-16/17/18
- [x] Ler `03-Projeto/00_INDICE.md` e `03-Projeto/Planos de Ação/00_TASKS_GERAIS_ECOSSISTEMA.md`
- [x] Ler os Escopos em `03-Projeto/Escopos/` (todos os 10 arquivos) para cruzar as SPEC-XXX-NN planejadas por domínio contra o que de fato foi implementado via SPEC-0XX sequencial
- [x] Ler `supabase/db/current/00_manifest.md` para confirmar a data real da última reextração do snapshot
- [x] Verificar por leitura direta de código (não é "achar bug novo", é confirmar status declarado) se telas marcadas como `[x]` em checklists de SPEC realmente existem em produção — achado: `compras-lucenera-3o23t98ee/src/App.tsx` tem 3 rotas (`/solicitacoes`, `/pedidos`, `/recebimento`) apontando para um componente placeholder `EmBreve.tsx` ("Em desenvolvimento e estará disponível em breve"), apesar de a SPEC-021 marcar `[x] Tela de listagem de pedidos de compra` como pendência resolvida

### Passos manuais do usuário

- [ ] Decidir quais das lacunas listadas abaixo (seção "Ordem sugerida") autorizar como próximas SPECs de implementação, e em que ordem
- [ ] Decidir se algum item de dívida técnica (seção 4, faixa P0) deve ser tratado antes de qualquer nova feature de negócio

---

## Objetivo

Dar a Pedro uma visão atualizada e citável do que já foi decidido/pedido (em
reunião ou em SPEC) mas continua sem SPEC formal, sem implementação, ou com
pendência aberta há muito tempo — para que ele decida o que autorizar a
seguir. Não é uma repetição do relatório de 07/07: só entra aqui o que
continua em aberto hoje ou o que surgiu de novo nesse intervalo.

---

## Definição da SPEC

### 1. Lacunas por sistema

#### CRM

Nenhuma entrada no `CHANGELOG.md` toca o CRM entre 07/07 e 18/07/2026 — os
gaps abaixo são exatamente os do relatório de 07/07, sem nenhuma mudança
registrada:

- Fluxo configurável (`crm_fluxos`/`crm_etapas`/`crm_substatus`) nunca
  implementado. O escopo (`03-Projeto/Escopos/03_ESCOPO_CRM.md`) lista
  `SPEC-CRM-01` a `SPEC-CRM-09` (definição visual do fluxo, versionamento,
  migração manual entre versões, execução de etapas/sub-status, checklists,
  paralelismo/bloqueio, responsáveis configuráveis, SLA, exceções por
  projeto) — nenhuma virou uma SPEC-0XX numerada até hoje. Fonte:
  `03_ESCOPO_CRM.md` linhas 38-152; `07_ANALISE_LACUNAS...` §4.
- Timeline única com eventos vindos de Orçamentos/Estoque/Financeiro/
  Logística (`SPEC-CRM-10`) — não implementada. Fonte: `03_ESCOPO_CRM.md`
  linhas 164-177.
- Gate manual de aceite/documento + plano futuro DocuSign (`SPEC-CRM-12`) —
  mantido explicitamente como baixa prioridade em `03-Projeto/00_INDICE.md`
  ("Decisões consolidadas"), não descartado, mas nunca iniciado.
- **SPEC-014** (badges ricos de estoque no card "Itens Aprovados do
  Projeto") segue com o mesmo status de 07/07: `implementado no CRM,
  pendente badges ricos de estoque`. A SPEC-022 (13/07) já expõe
  `vw_necessidade_compra_detalhe`, que poderia alimentar esses badges, mas
  ninguém conectou o CRM a essa view ainda. Fonte:
  `SPEC-014_Aba_Itens_Aprovados_CRM.md` frontmatter; `SPEC-022...md`.
- Homologação do SSO (`sso_code`) recebido pelo login próprio do CRM — a
  SPEC-007 segue com status `aplicado/publicado no remoto; homologação
  ponta-a-ponta pendente`, sem novidade desde 07/07.

#### Orçamentos

- **SPEC-031** (Aprovação da Equipe, 18/07): o módulo `aprovacao_equipe` foi
  cadastrado em `modulos`, mas **nenhum papel recebeu a permissão** — só
  `admin`/`gerente` conseguem agir na nova etapa hoje. O golden path
  completo (cliente aprova → equipe decide → financeiro aprova) **nunca foi
  testado no navegador**, só a QA automática de build do Skip. Fonte:
  `SPEC-031_Etapa_Aprovacao_Equipe_Orcamentos.md`, Pendências.
- **SPEC-032** (cabeçalho único, 18/07): conferência visual real (desktop +
  mobile) no app publicado nunca foi feita — só QA de build.
- Divergência Skip × GitHub, achada nas SPEC-031/032: o campo
  `prazo_entrega_dias` existe em `useBudgetStore.ts`/`BudgetFormPage.tsx` no
  projeto Skip, mas **não existe em nenhum commit do GitHub** — origem não
  investigada (alguém editou direto pela UI do Skip? Foi removido do GitHub
  sem propagar a remoção?). Registrado como risco em duas SPECs seguidas,
  ainda sem decisão.
- CHECK constraint de `modulo_acoes`/`papel_permissoes` (Hub, SPEC-006) não
  tem a ação `'aprovar'` — a SPEC-031 reaproveitou `'editar'` como solução
  provisória; decidir se vale estender o CHECK constraint continua em
  aberto.
- Geração automática de apresentação (PowerPoint) a partir do orçamento
  aprovado — pedido explícito de Filippo na reunião de 13/07 (SPEC-026 item
  12): "não iniciado, ferramenta fica fora deste repositório", sem avanço
  desde então.
- `fn_add_dias_uteis()` (SPEC-026) não exclui feriados — não existe tabela
  de feriados compartilhada no banco central; `prazo_entrega_dias` do
  orçamento pode ficar otimista perto de feriados prolongados.
- `prazo_entrega_dias`/`multiplo_compra`/`estoque_minimo` de produto/marca
  existem no schema desde 15/07 (SPEC-026) mas seguem **vazios/com default**
  — não há tela de edição nem alerta de reposição implementado.

#### Financeiro / Retorno Bancário

Sem nenhuma entrada no CHANGELOG entre 07/07 e 18/07 sobre CNAB/NF/CP-CR
histórico — os 3 bloqueios críticos do `00_TASKS_GERAIS_ECOSSISTEMA.md`
(seção 5) seguem exatamente como estavam:

1. Emissão de Nota Fiscal — provedor/API nunca decidido (`00_TASKS` item 1).
2. Homologação bancária do CNAB (agência/conta/carteira/convênio/sequencial
   oficiais com o Bradesco) — nunca feita (`00_TASKS` item 2).
3. Migração de PDFs/comprovantes para OneDrive/SharePoint — não iniciada
   (`00_TASKS` item 3).
4. Promoção de `staging_conta_pagar`/`staging_conta_receber` para tabelas
   operacionais — não feita (Connect, sem mudança desde 07/07).

Novidades desde 07/07 (Dashboard Financeiro, SPEC-025/028), ainda com
pendências abertas:

- Fórmula de "Valor_Showroom" continua **15× menor** que a imagem de
  referência do Power BI, mesmo após a sincronização de dados de 16/07 —
  única pendência funcional restante do dashboard de Estoque. Fonte:
  `SPEC-028...md`, Pendências.
- Fórmulas de "Custo Operacional" vs. "Despesa Operacional Total" e de
  "Despesas com Material" (hoje um `ILIKE` aproximado em `descricao`) nunca
  confirmadas contra o `.pbix` original. Fonte: `SPEC-025...md`, Pendências.
- Mapeamento completo `descricao → DescSubGrupo` (Página 2) é só um rascunho
  de amostra de 500 transações de 6.543 — não completado.
- Classificação Fixo×Variável (P-01) e fórmula exata do Ponto de Equilíbrio
  (P-03) implementadas com valor padrão, **nunca confirmadas por Filippo**.
  Fonte: `SPEC-026...md`, "Perguntas em aberto".
- Rotinas administrativas Lana/Caroline (tarifas, impostos, transferências,
  DDA, contabilidade, folha/comissões — `SPEC-FIN-13`) seguem sem nenhum
  trabalho.

#### Cadastro

Nenhuma entrada no CHANGELOG entre 07/07 e 18/07 toca o sistema
`cadastro-lucenera-b86fe` diretamente. Os gaps de 07/07 permanecem:
deduplicação de contatos, fornecedores canônicos, origem/última importação,
remoção de mocks/código morto em `Clientes`/`Projetos`. Um dado novo: a tela
de gestão de "Marcas → Fornecedor" (SPEC-033) nasceu em
`compras-lucenera-3o23t98ee`, não em Cadastro, por decisão explícita
registrada ali ("Cadastro hoje não tem nenhuma tela de gestão de `marcas` —
só um dropdown somente-leitura") — ou seja, Cadastro segue sem dono de tela
para esse dado mestre.

#### Estoque / Compras

Este é o sistema que mais avançou desde 07/07 (SPECs 020, 021, 022, 023,
026 parcial, 030, 033, 034) — grande parte do gap "não existe app próprio"
do relatório anterior está fechada. O que continua aberto:

- **Achado desta análise (grounded em código)**: as rotas `/solicitacoes`,
  `/pedidos` e `/recebimento` do sistema `compras-lucenera-3o23t98ee`
  (`src/App.tsx` linhas 39/41/42) apontam para `EmBreve.tsx`, um componente
  placeholder ("Esta funcionalidade está em desenvolvimento") — **em
  produção**, mesmo com o backend (`solicitacoes_compra`, `pedidos_compra`,
  `pedido_compra_itens`, RPC `registrar_recebimento_compra`) pronto desde a
  SPEC-020 (10/07). A SPEC-021 marca `[x] Tela de listagem de pedidos de
  compra` como item resolvido em "Pendências pós-implementação", o que não
  corresponde ao estado real do código. Fonte:
  `04-Sistemas/compras-lucenera-3o23t98ee/src/App.tsx`;
  `SPEC-021_Registrar_Pedido_Compra_Frontend_e_RPC.md`.
- `SPEC-EST-10` (aprovação do pedido + previsão financeira), `SPEC-EST-11`
  (prazos e acompanhamento) e `SPEC-EST-13` (confirmação de conta a pagar)
  — marcadas "fora de escopo" em SPEC-020/021, nunca endereçadas desde
  então. Fonte: `03-Projeto/Escopos/05_ESCOPO_ESTOQUE_COMPRAS.md` linhas
  173-217.
- `SPEC-EST-14` (liberação para Logística) — nunca implementada; é o mesmo
  buraco citado do lado Logística como `SPEC-LOG-01` (ver abaixo) — os dois
  lados estão bloqueados um pelo outro.
- Reunião com Débora sobre o fluxo real de Pedido de Compra — pedida
  explicitamente por Filippo em 13/07 (SPEC-026), **nunca agendada**. Sem
  isso, `pedido_compra_item`/`cotacao_fornecedor` (no sentido do fluxo real
  de Débora, distinto do que a SPEC-020 já construiu) seguem bloqueados.
- Backfill de `marcas.fornecedor_id`: 62 de 109 marcas já vinculadas
  (SPEC-034, 18/07), restam ~47 sem candidato confiável (score < 0.6,
  inclui marcas internacionais: OSRAM, FOSCARINI, VIBIA, LOUIS POULSEN,
  TARGETTI, MITSUBISHI, JIELDE) — trabalho manual de Pedro/Filippo.
- 2 casos sinalizados como possível falso-positivo de sugestão automática
  ("LIGHT LIGHT"→"OMEGA LIGHT" e "OUTROS"→"OUTROS") aguardam decisão manual
  antes de vincular ou descartar definitivamente.
- Threshold de `buscar_fornecedores_fuzzy`/`sugerir_fornecedores_marcas`
  (0.3) nunca validado empiricamente com um usuário real digitando após a
  correção de algoritmo da SPEC-034 (troca de `similarity()` para
  `word_similarity()`).
- SPEC-022 (destino da necessidade de compra): 2 itens de teste do
  checklist nunca marcados (`[ ] Testar: expandir linha com 1/vários
  projetos`, `[ ] Testar: produto sem estoque_saldos_projeto_item`), e 3
  pendências pós-implementação seguem abertas: validar com Débora se o
  detalhe cobre a necessidade operacional, verificar backfill de
  `estoque_saldos_projeto_item` para aprovações anteriores a 06/07/2026, e
  a proposta de sugestão automática de re-reserva (que a própria SPEC
  registra como "possível SPEC-023" — nunca virou uma).
- `supabase/db/domains/estoque_compras.md` está desatualizado desde antes
  da SPEC-030 — não reflete `marcas.fornecedor_id`, `vw_necessidade_compra`
  atual nem as RPCs novas. Não existe `AI_DB_CONTEXT.md` neste sistema.
- Importação dos movimentos históricos não-`VENDAS` do Connect — nunca
  feita (gap de 07/07, sem mudança).

#### Logística

Nenhuma entrada no `CHANGELOG.md` entre 07/07 e 18/07 toca qualquer sistema
de Logística — todos os gaps de 07/07 seguem idênticos: origem estruturada
no Estoque/Compras (`SPEC-LOG-01`, bloqueado mutuamente com `SPEC-EST-14`
acima), evidências via OneDrive/SharePoint em vez de Supabase Storage,
estados canônicos entre banco/app/processo, rota real (hoje só simulação
visual), devolução/garantia como tipos operacionais, eventos para a
timeline do CRM, configurações/acessos via Sistema de TI, e o plano de
corte entre `lucenera-logistica-atual-backup` e `lucenera-logistics-b7cd1`
(decidido em 26/06 — "desligado quando o novo replicar tudo", sem data).
Dois itens antigos de reunião nunca viraram SPEC:

- "Definir critérios de otimização de rota: horários, urgência, capacidade
  e confirmação" — reunião 02 (28/01/2026), nunca endereçado.
- "Separar o que fica em Teams, WhatsApp e banco de dados" — mesma reunião,
  mesmo status.

#### RH

- **SPEC-023** (filtro VT por empresa, implementada 14/07): item de
  melhoria estrutural ainda aberto — `[ ] Tornar empresa_id NOT NULL após
  validação em produção`.
- **SPEC-024** (comissão × equipe, 14/07, status ainda `pendente`): 45% dos
  projetos (1.659 de 3.694) continuam fora do cálculo de comissão porque 11
  responsáveis reais não têm equipe cadastrada (Angélica, Rianne, Ligia,
  Vilber, Bender, Filippo, Mary, Eduardo, Terezinha, Maria, João) — decisão
  de negócio de Pedro/Filippo, explicitamente registrada como não sendo
  algo que a IA deva decidir. Casos parcialmente decididos: **Mariane**
  (virou gerente de projetos, falta decidir se ainda entra no cálculo) e
  **Ricardo/Amanda** (não trabalham mais, projetos ficam no banco mas sem
  gerar comissão nova). `equipe_responsavel_obra_id` redundante com
  `equipe_id` — motivo de manter as duas colunas nunca documentado. Decisão
  sobre remover `MOCK_DATA` por completo ou manter atrás de flag de
  ambiente nunca tomada.
- Migration com 4 funcionários fictícios condicionados
  (`20260629120922_vw_funcionarios_completo.sql`) — decisão de
  remover/isolar antes da carga real nunca tomada (`00_TASKS` item 12, sem
  mudança desde 03/07).
- Consolidação funcionário/usuário (`SPEC-RH-01`/`SPEC-RH-02`) e
  eventos/saúde publicados no Hub (`SPEC-RH-07`) — sem trabalho desde
  07/07.

#### Hub / TI

- Matriz de papéis/módulos/ações/exceções/auditoria (SPEC-006) ainda não
  homologada com dados reais de operação — mesmo status desde 07/07.
- SSO por `sso_code` (SPEC-007) nunca homologado ponta a ponta com um login
  real — o próprio manifesto do snapshot (`00_manifest.md`, "Próximos
  passos" item 2, ainda datado de 07/07) registra isso como pendente, e
  nada no CHANGELOG desde então mostra homologação real.
- Histórico de acesso/atividade (`HUB-06`/`TI-12`) e saúde de
  sistemas/integrações (`TI-05`/`TI-07`) — nunca viraram SPEC numerada.
- **SPEC-031**: módulo `aprovacao_equipe` cadastrado no Hub, mas nenhum
  papel recebeu a permissão ainda (mesmo item já citado em Orçamentos
  acima — é uma pendência do Hub tanto quanto de Orçamentos).
- CHECK constraint sem ação `'aprovar'` — mesma pendência já citada.
- (Não é gap, é decisão fechada, registrado por contexto): SPEC-027
  confirmou, por decisão explícita de Pedro em 15/07, manter o bypass de
  `role='admin'` para o Dashboard Financeiro sem restrição adicional — não
  precisa de nova SPEC a menos que a política mude.

---

### 2. SPECs com pendências nunca fechadas

| SPEC | Título | Item pendente exato | Em aberto desde |
|---|---|---|---|
| SPEC-006 | Permissões Granulares no Hub | Homologar com dados reais de papel/módulo/ação com a operação | 07/07/2026 (11 dias) |
| SPEC-007 | Token de Acesso Compartilhado | Homologação ponta a ponta com login real (Hub→sistema, CRM→Orçamentos, Orçamentos→Financeiro) | 07/07/2026 |
| SPEC-008 | Conciliação de Retorno Bancário | Homologação com arquivo `.RET` real e CNAB Bradesco oficial | 07/07/2026 (herdado, sem mudança) |
| SPEC-014 | Itens Aprovados do Projeto no CRM | Badges ricos de estoque (dado já existe via SPEC-022, ninguém conectou) | 07/07/2026 |
| SPEC-019 | Origem Aprovação Cliente | Reextrair `supabase/db/current/` — item marcado `[x]` mas o snapshot ainda está datado de 07/07 (11 dias depois) | 07/07/2026 |
| SPEC-021 | Registrar Pedido de Compra | `[x] Tela de listagem de pedidos de compra` — marcado feito, mas a rota `/pedidos` em produção é `EmBreve.tsx` (achado desta análise) | 10/07/2026 |
| SPEC-022 | Destino da Necessidade de Compra | 2 itens de teste do checklist nunca marcados; validar com Débora se cobre a operação; backfill de saldos para aprovações < 06/07 | 13/07/2026 |
| SPEC-023 | Filtro Empresa VT | `[ ] Tornar empresa_id NOT NULL após validação em produção` | 14/07/2026 |
| SPEC-024 | Comissão × Equipe | Decisão de negócio sobre 11 responsáveis sem equipe (45% dos projetos fora do cálculo) | 14/07/2026 |
| SPEC-025 | Dashboard Financeiro | Fórmulas de "Custo Operacional"/"Despesas com Material" e mapeamento `DescSubGrupo` não confirmados | 14/07/2026 |
| SPEC-026 | Melhorias reunião 13/07 | Reunião com Débora sobre Pedido de Compra nunca agendada; classificação Fixo×Variável/Ponto de Equilíbrio não confirmadas | 13/07/2026 (5 dias) |
| SPEC-028 | Dashboard Interativo/Estoque | Fórmula de "Valor_Showroom" ainda 15× divergente | 16/07/2026 (2 dias) |
| SPEC-029 | Subagentes de IA | Validar os 4 prompts em mais casos reais além da SPEC-030 | 16/07/2026 |
| SPEC-030 | Fix Filtro Fornecedor / Pedido em Lote | Risco documentado: sync/publish do Skip já reverteu código commitado do GitHub uma vez — pode se repetir | 16-17/07/2026 |
| SPEC-031 | Aprovação da Equipe (Orçamentos) | Conceder permissão do módulo a algum papel no Hub; homologar golden path no navegador | 18/07/2026 (hoje) |
| SPEC-032 | Cabeçalho Único Itens Orçamento | Conferir visualmente no app publicado; investigar origem do campo `prazo_entrega_dias` só no Skip | 18/07/2026 |
| SPEC-033 | Fornecedor por Marca | Confirmar se "Disponível" e "Necessidade" devem coexistir; local definitivo da tela "Marcas" (Compras vs. Cadastro) | 18/07/2026 |
| SPEC-034 | Sugestão Automática de Fornecedor | Validar threshold empírico; decidir os 2 casos suspeitos (LIGHT LIGHT, OUTROS); completar backfill das ~47 marcas restantes | 18/07/2026 |

*(SPECs 001-005, 009-013, 015-018 mantêm exatamente o status de pendência já
detalhado no relatório de 07/07 — nenhuma entrada de CHANGELOG desde então
as toca; não repetidas aqui para não duplicar o relatório anterior. Ver
`03-Projeto/07_ANALISE_LACUNAS_IMPLEMENTACAO_2026_07_07.md` para o detalhe
original de cada uma.)*

---

### 3. Temas de reunião que nunca viraram SPEC

| Tema | Reunião de origem | Situação |
|---|---|---|
| Portal do cliente (o que o cliente vê, quais status/pendências) | 03. Lucenera (Filippo) — 24/03/2026, `04_decisoes_pendencias.md` | Nunca virou SPEC. Citado como baixa prioridade em `03-Projeto/Escopos/03_ESCOPO_CRM.md` ("fora de escopo" desta rodada), sem SPEC nem como pendência formal em nenhuma SPEC existente. |
| Mapear automações de WhatsApp/e-mail/status com maior impacto | 03. Lucenera (Filippo) — 24/03/2026 | Nunca virou SPEC. |
| Definir critérios de otimização de rota (horários, urgência, capacidade, confirmação) | 02. Lucenera (Filippo) — 28/01/2026, `04_decisoes_pendencias.md` | Nunca virou SPEC — Logística segue com "rota real, não só simulação visual" como gap (07/07). |
| Separar o que fica em Teams, WhatsApp e banco de dados (Logística) | 02. Lucenera (Filippo) — 28/01/2026 | Nunca virou SPEC. |
| Pesquisar automação de fichas técnicas/apresentações a partir de CAD/orçamento | 01. Lucenera (Filippo) — 03/12/2025, `04_decisoes_pendencias.md` | Parcialmente retomado como "geração de PowerPoint" na reunião de 13/07 (SPEC-026 item 12), mas segue "não iniciado". |
| Documentar fluxo de projeto fechado (orçamento, parcelas, estoque, financeiro) de ponta a ponta | 06. Lucenera (Filippo) — 13/05/2026, `04_decisoes_pendencias.md` | Não existe um documento único consolidando isso; a informação está espalhada entre `supabase/docs/domains/` (parcialmente desatualizados) e SPECs individuais. |
| Conferir arquitetos duplicados (ex.: caso "André Calil") e relacionar projetos sem arquiteto/responsável correto | 06. Lucenera (Filippo) — 13/05/2026 | Nunca virou SPEC dedicada de limpeza de dados; a lacuna geral de deduplicação de Cadastro segue aberta desde 07/07. |
| Definir regra de linkagem entre contas a pagar/receber e projeto | 06. Lucenera (Filippo) — 13/05/2026 | Corresponde à `SPEC-FIN-12` (Visão financeira por projeto), listada no Escopo Financeiro mas nunca implementada. |

---

### 4. Riscos / dívidas técnicas conhecidas e não resolvidas

- **`supabase/db/current/` desatualizado desde 2026-07-07** (confirmado no
  próprio `00_manifest.md`, ainda datado da "terceira rodada" de 07/07).
  Não reflete nenhuma das migrations de 14 a 18/07 (SPEC-025 a SPEC-034),
  incluindo `marcas.fornecedor_id`, `sugerir_fornecedores_marcas()`, o
  contrato de 4 etapas de status de orçamento (SPEC-031), `v_estoque_produtos`,
  `v_financeiro_realizado` etc. Já quase causou um retrabalho real na
  SPEC-031, que precisou confirmar por query direta no Postgres que objetos
  da SPEC-019 existiam, porque o snapshot local dizia que não. Mencionado
  como pendência aberta em pelo menos 6 SPECs seguidas (019, 030, 031, 032,
  033, 034).
- **Divergência Skip × GitHub, com pelo menos um caso confirmado de perda de
  código**: durante a SPEC-030, o mecanismo de sync/publish do Skip
  sobrescreveu código já commitado no GitHub (`NecessidadeCompra.tsx`
  revertido, `AppNav` duplicado de volta) sem que Pedro tivesse editado
  nada manualmente — restaurado manualmente, mas o risco de repetição
  "continua existindo" (palavras da própria SPEC-030). Casos adicionais de
  campos existentes só no Skip e não no GitHub (`prazo_entrega_dias`) nas
  SPEC-031/032, nunca investigados.
- **Credencial em texto plano commitada ao GitHub** (`Skip@Pass` de
  `pedro@lucenera.com.br`, em 3 migrations de CRM/Hub/RH) — achado em
  03/07/2026, registrado como pendência crítica nº 11 do
  `00_TASKS_GERAIS_ECOSSISTEMA.md`, **sem nenhuma menção de rotação em
  qualquer entrada do CHANGELOG desde então**.
- **RLS com `USING (true)` em tabelas novas** (RH: 4 tabelas de
  funcionário; CRM: `projetos`; Logística: `separacoes`/
  `separacao_arquivos`/`entregas_finalizadas`; Orçamentos: `logs_auditoria`)
  — apontado como pendência crítica nº 7 do `00_TASKS`, sem confirmação de
  correção em nenhuma SPEC posterior.
- **Threshold de busca fuzzy nunca validado com usuário real**: mesmo após
  a correção de algoritmo da SPEC-034 (`similarity()` → `word_similarity()`),
  o valor `0.3` continua sendo "herdado" e não testado empiricamente com
  digitação real de usuário — pendência explícita da própria SPEC-034.
- **`oxfmt --check` falha em ~115-120 arquivos de `compras-lucenera-3o23t98ee`**
  — condição pré-existente (provável mismatch de CRLF/LF no checkout
  Windows), confirmada via `git stash` em pelo menos 3 SPECs seguidas
  (030, 033, 034), nunca corrigida na raiz, só contornada arquivo a arquivo.
- **Zero testes automatizados reais em qualquer um dos 8 sistemas** — todos
  usam `"test": "echo \"there are no tests...\" && exit 0"`. Mesmo estado
  de 07/07, agora também documentado como decisão consciente na SPEC-029
  ("nenhum agente pode exigir suíte de testes como critério de aceite —
  não existe teste real em nenhum dos 8 sistemas").
- **Migration de RH com 4 funcionários fictícios condicionados**
  (`20260629120922_vw_funcionarios_completo.sql`) — decisão de
  remover/isolar antes da carga real de colaboradores nunca tomada.
- **`equipe_responsavel_obra_id` redundante com `equipe_id`** em `projetos`
  — as duas colunas são gravadas de forma idêntica pelo mesmo trigger, e o
  motivo de manter as duas nunca foi documentado (achado da SPEC-024).
- **CHECK constraint do Hub sem ação `'aprovar'`** — `modulo_acoes`/
  `papel_permissoes` só aceitam `criar|editar|deletar|visualizar`; a
  SPEC-031 reaproveitou `'editar'` por não poder estender o constraint sem
  decisão explícita.
- **Documentos de coordenação desatualizados**: `03-Projeto/00_INDICE.md`
  só lista SPECs até a 019 (não foi atualizado desde 07/07); `00_TASKS_
  GERAIS_ECOSSISTEMA.md` não foi atualizado desde 03/07;
  `supabase/db/domains/estoque_compras.md`, `orcamentos.md` e `rh.md` estão
  desatualizados em relação ao schema real (apontado repetidamente nas
  SPECs 024, 031, 033, 034). Isso viola a própria "Regra de ouro" do
  `README.md` (toda alteração relevante precisa deixar rastro no repo
  central).
- **Não existe `AI_DB_CONTEXT.md`** em `compras-lucenera-3o23t98ee` — o
  sistema que mais cresceu desde 07/07 nunca ganhou esse arquivo.
- **Importação histórica do Connect (M01-M04) totalmente parada**: nenhuma
  entrada do CHANGELOG entre 07/07 e 18/07 toca `staging_*`, promoção de
  `VENDAS` para `vendas`/`projeto_itens`, ou conciliação dos 706 códigos
  sem correspondência — mesmo estado exato de 07/07.

---

### 5. Ordem sugerida (não obrigatória — decisão final é do usuário)

Critério: o que já foi pedido explicitamente por Pedro/Filippo em reunião
ou sessão recente e ainda não foi fechado, vs. dívida técnica estrutural
sem pedido explícito de prazo.

**P0 — Segurança e verdade documental** (sem prazo pedido, mas risco
concreto e crescente a cada dia sem ação):
1. Rotacionar a credencial exposta (`00_TASKS` item 11) — aberta desde
   03/07/2026, 15 dias sem ação registrada.
2. Reextrair `supabase/db/current/` — 11 dias de defasagem, já quase gerou
   erro em produção (SPEC-031).
3. Atualizar `00_INDICE.md` e `00_TASKS_GERAIS_ECOSSISTEMA.md`.

**P1 — Pedido explícito recente, ainda não fechado**:
4. Conceder a permissão do módulo `aprovacao_equipe` a um papel no Hub
   (bloqueia o uso da SPEC-031 por qualquer pessoa fora de admin/gerente —
   pedida por Pedro em 18/07, mesmo dia).
5. Backfill final de `marcas.fornecedor_id` (~47 restantes) + decisão sobre
   "LIGHT LIGHT"/"OUTROS" — Pedro já está ativamente fazendo esse trabalho.
6. Agendar a reunião com Débora sobre o fluxo real de Pedido de Compra —
   pedida por Filippo em 13/07, 5 dias sem ser marcada.
7. Confirmar com Filippo as fórmulas do Dashboard Financeiro em aberto
   (Valor_Showroom, Custo Operacional, Despesas com Material,
   Fixo×Variável/Ponto de Equilíbrio).

**P2 — Backend já pronto, falta só UI/decisão**:
8. Construir as telas reais de Solicitações/Pedidos/Recebimento em
   `compras-lucenera-3o23t98ee` (hoje placeholder "Em breve", mas o backend
   existe desde a SPEC-020, 10/07).
9. UI para editar `prazo_entrega_dias`/`multiplo_compra`/`estoque_minimo`
   por produto + alerta de reposição (colunas prontas desde 15/07).
10. Decisão de negócio sobre os 11 responsáveis órfãos de comissão no RH
    (SPEC-024) — 45% dos projetos fora do cálculo hoje.
11. Conectar os badges ricos de estoque no CRM (SPEC-014) usando a view que
    a SPEC-022 já expõe.

**P3 — Dívida estrutural grande, sem pedido explícito de prazo** (herdada
do relatório de 07/07, sem mudança):
12. Homologação SSO ponta a ponta e da matriz de papéis/módulos do Hub.
13. CRM configurável (fluxo/etapas/sub-status).
14. Importação histórica do Connect (M01-M04).
15. Financeiro completo (CNAB homologado, NF real, CP/CR histórico).
16. Logística integrada com Estoque/OneDrive/CRM (bloqueada mutuamente com
    `SPEC-EST-14`).
17. Portal do cliente.
18. Hardening de RLS (`USING (true)`).

---

## Realizado

### 2026-07-18

- Leitura completa do relatório de 07/07/2026, das 9 reuniões, das ~35
  SPECs (integral para as SPECs 019-034), do `CHANGELOG.md`, dos Escopos,
  do `00_INDICE.md`, do `00_TASKS_GERAIS_ECOSSISTEMA.md` e do manifesto do
  snapshot Supabase.
- Cruzamento das SPEC-XXX-NN planejadas em cada Escopo (`SPEC-CRM-01..13`,
  `SPEC-EST-01..16`, `SPEC-FIN-01..14`, `SPEC-RH-01..07`,
  `SPEC-LOG-01..11`) contra o que de fato foi entregue via as SPECs
  sequenciais 001-034, para identificar o que ainda não tem nenhuma SPEC
  numerada cobrindo.
- Verificação direta de código (`compras-lucenera-3o23t98ee/src/App.tsx`) que
  encontrou uma contradição entre o checklist da SPEC-021 (marcado `[x]`)
  e o estado real de produção (rotas `/solicitacoes`, `/pedidos`,
  `/recebimento` ainda são placeholder) — registrado na seção 1 (Estoque/
  Compras) e na seção 2 (SPECs com pendências nunca fechadas).
- Consolidação de riscos técnicos espalhados por várias SPECs (divergência
  Skip×GitHub, snapshot desatualizado, threshold de busca fuzzy, RLS
  permissiva, credencial exposta) em uma única seção.

---

## Pendências

- [ ] Pedro decide quais itens da seção "Ordem sugerida" autorizar como
  próximas SPECs de implementação — nenhuma decisão de prioridade foi
  tomada nesta SPEC, só o levantamento.
- [ ] Se autorizada, a P0 (segurança/verdade documental) provavelmente
  precisa de uma sessão dedicada de reextração de `supabase/db/current/` e
  rotação de credencial antes de qualquer outra SPEC nova ser planejada com
  segurança sobre o schema real.
- [ ] Este relatório deve ser revisitado na próxima janela de trabalho
  relevante (sugestão: quando o backlog de SPECs 035+ acumular ~10-15 SPECs
  novas, mesmo padrão desta atualização em relação ao relatório de 07/07).


