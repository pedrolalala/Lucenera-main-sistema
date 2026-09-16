---
titulo: "SPEC-128 — Dashboard Fluxo Futuro: desmembrar em Contas a Pagar, Pedidos de Compra e Previsões"
status: não iniciado
data_ultima_modificacao: 2026-09-04
sistemas_envolvidos:
  - Dashboard Financeiro — 04-Sistemas/dashboard-lucenera-b02z85wa3 (Skip projeto 41135, host dashboard-empresa-40d7d.goskip.app)
referencias:
  - SPEC-126 Escopo 8 (03-Projeto/Planos de Ação/SPECs/SPEC-126_Dashboard_Financeiro_Filtro_Data_Confiabilidade_Correcoes.md) — implementação original da aba "Fluxo Futuro (Projeção)", linhas 97-112
  - SPEC-020/021 (pedidos_compra, pedido_compra_itens — fluxo operacional de Compras)
  - SPEC-038 (pedido_compra_parcelas, gerar_parcelas_pedido_compra, atualizar_parcela_pedido_compra)
  - SPEC-039/041 (vw_necessidade_compra, vw_necessidade_compra_pedidos_abertos — outro consumidor de pedidos_compra, domínio Compras)
  - SPEC-060 (cancelar_pedido_compra — cascata para pedido_compra_parcelas)
  - SPEC-081 (paginação obrigatória via `.range()`, `.limit()` trunca em 1000 silenciosamente)
  - SPEC-039, achado 22/07/2026 (`pedido_compra`/`staging_pedido_compra` órfãs + 51 pedidos legado recriados em `pedidos_compra` como `PC-LEGADO-*`)
  - `scripts/importar_pedido_compra.py` (import da planilha `01-Documento/01 - Planilhas/PedidoCompra_2026-09-02.xlsx`, Connect, aba "Financeiro")
  - Pedido do usuário, 2026-09-04 (conversa direta, sem ata de reunião — corrigiu a fonte de "Previsões" depois do primeiro rascunho desta SPEC)
---

# SPEC-128 — Dashboard Fluxo Futuro: desmembrar em Contas a Pagar, Pedidos de Compra e Previsões

> Desmembra o bloco único "A Pagar" da aba **Fluxo Futuro (Projeção)**
> (SPEC-126 Escopo 8) em **3 blocos separados, de 3 fontes diferentes**:
> **Contas a Pagar** (`transacoes`, já existe), **Pedidos de Compra**
> (`pedidos_compra`/`pedido_compra_parcelas`, app interno de Compras, novo)
> e **Previsões** (`pedido_compra`/`staging_pedido_compra`, export "Connect
> PedidoCompra", novo). É a primeira vez que o Dashboard lê qualquer uma
> dessas 4 tabelas de Compras — até aqui só lia `transacoes`/
> `v_financeiro_realizado` (domínio Financeiro/Connect) e
> `vw_necessidade_compra`.

## Checklist de Ação

- [x] Confirmar no Skip (projeto 41135, `skip_file_read`) o estado atual de `src/pages/FluxoFuturo.tsx` e `src/services/cash-flow.ts` **antes de editar** — o checkout local do submódulo está atrás da produção (não tem `FluxoFuturo.tsx` nem o `KpiCard` com `tone`/`caption`/`info` usado nas versões publicadas 0.0.32+); editar por cima do submódulo local sem ler o Skip primeiro reintroduziria regressão (ver `feedback_skip_local_pode_ter_menos_que_producao`).
- [x] Novo service — `src/services/pedidos-compra-futuro.ts`. Implementado como planejado, com 1 desvio técnico: **`pedidos_compra` e `pedido_compra_parcelas` não existem no `types.ts` gerado deste sistema** (só tem `pedido_compra` singular/`staging_pedido_compra`) — descoberto durante a implementação, não previsto na análise original. Resolvido com `.from(<nome> as any)` só nessas 2 chamadas; o resto do service usa o client tipado normalmente. Achado documentado no topo do arquivo.
  - `fetchPedidoCompraParcelasAbertas()` — implementada conforme o desenho (embed `pedidos_compra!inner(...,contatos!fornecedor_id(nome))`, filtro de status + `.neq('pedidos_compra.status','cancelado')`, paginação `.range()`). **Fonte: Bloco 2**.
  - Dedup P-03 implementada como função interna `fetchCodigosPedidoLegado()` (não exportada — só usada dentro do service).
  - `fetchPrevisoesCompra()` — lê `pedido_compra` (tipado nativamente) + `staging_pedido_compra` (tipado nativamente), aplica dedup P-03, parseia `DD/MM/AAAA` → ISO (`parseDataConnect`), gera 1 linha por parcela com vencimento real ou 1 linha por pedido estimado. **Fonte: Bloco 3**.
  - Agregadoras `computeTotalPedidosCompraAberto`, `computeTotalPrevisoes`, `computePedidosCompraAbertoPorMes`, `computePrevisoesPorBucket` — implementadas, reusando `baldeVencimento` de `cash-flow.ts` (import, não precisou exportar nada novo lá).
- [x] `src/pages/FluxoFuturo.tsx` — implementado com **1 simplificação deliberada de escopo** em relação ao desenho original: os 2 blocos novos **não foram mesclados no `ComposedChart`** "Entradas × Saídas por mês de vencimento" (que fica intocado, sem risco de regressão num gráfico já testado). Em vez disso, os 2 KPIs + banner + 2 tabelas novas (abaixo) cobrem o pedido central da SPEC (ver os 3 blocos, sem misturar valores) com risco bem menor — não há suíte de teste visual neste projeto (QA do Skip não cobre renderização), então mexer no gráfico existente sem poder validar visualmente foi avaliado como risco desnecessário para uma tela usada pela diretoria. Consequência: cross-filter por mês e drill por grupo **não afetam** as 2 tabelas novas (ficam com o dataset completo, sem recorte por mês/grupo). Se o usuário quiser o gráfico mesclado depois, é um incremento separado.
  - [x] 2 novos `KpiCard` ("Pedidos de Compra em Aberto", "Previsões de Compra (estimado)") — implementados, `tone="warning"`, `info` explicando a fonte e o filtro. Os 4 KPIs existentes não mudaram de fonte nem de cálculo.
  - [ ] ~~Extensão do gráfico~~ — não implementada, ver nota acima.
  - [x] Tabela "Pedidos de Compra em aberto" via `<PlanilhaTabela>` + `colunasPedidosCompra.ts` (novo).
  - [x] Tabela "Previsões de Compra" via `<PlanilhaTabela>` + `colunasPedidosCompra.ts`.
  - [x] Banner de aviso de sobreposição — sempre visível, acima dos KPIs (texto adaptado, ver "Aviso de sobreposição").
  - [x] Filtro Perfil filtra Pedidos de Compra (client-side, `pedidosCompraFiltrados`); Previsões não é afetado (nota na `descricao` da tabela e no `info` do KPI).
  - [ ] ~~Filtro Horizonte recortando os 2 blocos novos~~ — não implementado (consequência da simplificação do gráfico: sem recorte por mês, o horizonte também não se aplicou às tabelas novas, que mostram sempre o total). Pendência registrada abaixo.
  - [ ] ~~Switch "Incluir vencidos" afetando Pedidos de Compra~~ — não implementado, mesma razão.
  - [ ] ~~Cross-filter por mês / drill por grupo nas 2 tabelas novas~~ — não implementado, mesma razão.
  - [x] Export CSV — funciona nas 2 tabelas novas (herdado de `<PlanilhaTabela>`, sem código extra).
- [x] `oxlint` + `tsc --noEmit` + `vite build` — verdes via `skip_project_apply_changes` (QA setup/static/build/integrations/test, versão 0.0.40 / `70754b9`).
- [ ] Publicar no Skip (projeto 41135) — **QA aplicado, não publicado**. Aguardando confirmação do usuário antes de ir para produção.
- [ ] Atualizar/criar `04-Sistemas/dashboard-lucenera-b02z85wa3/supabase/AI_DB_CONTEXT.md` — hoje esse arquivo **não existe** neste sistema (confirmado por busca no repositório); esta é a primeira vez que o Dashboard lê `pedidos_compra`/`pedido_compra_parcelas`/`contatos`, então vale criar o arquivo (ou confirmar que o Skip já tem um) documentando essas 2 tabelas novas como fonte de leitura.
- [ ] Sincronizar o ponteiro do submódulo `dashboard-lucenera-b02z85wa3` no repo central após publicar (mesmo passo pendente desde a SPEC-126 — considerar resolver a dívida de sincronização geral junto, se o tempo permitir; não é bloqueante desta SPEC).

### Passos manuais do usuário

- [x] Reconferir a contagem real de pedidos/parcelas em `pedido_compra`/`staging_pedido_compra` antes de fechar o critério de aceite do Bloco 3 — confirmado 2026-09-04: 138 pedidos, 87 elegíveis após dedup, R$ 827.886,04.
- [x] Validar o texto do aviso de sobreposição (ver "Aviso de sobreposição — P-02") — implementado como banner permanente no topo da aba.
- [ ] Conferir ao vivo no navegador, em produção, que os 3 blocos aparecem sem misturar valores entre si (cada bloco com sua própria origem/cor/tabela) — só possível depois de publicar.
- [ ] Publicar no Skip (projeto 41135) após QA — **QA já passou (v0.0.40), aguardando você confirmar antes do publish.**

## Objetivo

A aba "Fluxo Futuro (Projeção)" (SPEC-126 Escopo 8) hoje mostra só "A Pagar" a
partir de `transacoes`/`v_financeiro_realizado` (o livro-caixa importado do
Connect). Isso ignora dois compromissos futuros que já estão registrados em
outras fontes: o que está comprometido no app interno de Compras
(`pedidos_compra`/`pedido_compra_parcelas`) e o que o Connect já projeta num
export próprio de pedido de compra (`pedido_compra`/`staging_pedido_compra`,
planilha PedidoCompra) — nenhum dos dois aparece hoje no Dashboard. Ou seja,
o chefe e o Vinícius não veem, na mesma tela, quanto já está comprometido no
app de Compras e quanto ainda é só previsão do Connect (com ou sem parcela
já lançada). Esta SPEC desmembra o bloco único em 3 blocos visualmente
separados — **Contas a Pagar**, **Pedidos de Compra** e **Previsões** — sem
fundir os valores, porque as 3 fontes (livro-caixa Connect × app de Compras
× export PedidoCompra do Connect) não têm vínculo completo entre si e podem
se sobrepor (ver P-02/P-03).

## Decisões aprovadas

- **P-01 (escopo de "Previsões") — REVISTO em 2026-09-04**: a primeira
  versão desta SPEC assumia "Previsões" = `pedidos_compra` sem
  `pedido_compra_parcelas`. **Corrigido pelo usuário**: "Previsões" é a
  planilha **PedidoCompra** (export do Connect, `01-Documento/01 -
  Planilhas/PedidoCompra_2026-09-02.xlsx`), que já é importada por
  `scripts/importar_pedido_compra.py` para 2 tabelas existentes no Supabase
  — `pedido_compra` (singular, 1 linha por pedido) e `staging_pedido_compra`
  (1 linha por parcela, com `dt_vencimento`/`vl_duplicata` reais quando a
  parcela já foi lançada no Connect). Confirmado populado no banco real em
  2026-09-04: **138 pedidos em `pedido_compra`, 314 linhas em
  `staging_pedido_compra`** (183 delas com `dt_vencimento` preenchido). Ver
  "Bloco 3 — Previsões" abaixo para o desenho completo.
- **P-02 (risco de dupla contagem Connect × Compras — não resolver aqui)**:
  `transacoes` (livro-caixa Connect) e `pedidos_compra`/`pedido_compra_
  parcelas` (app interno de Compras) **não têm nenhuma FK nem coluna de
  referência cruzada** entre si (confirmado em `supabase/db/current/*.sql` e
  `supabase/db/domains/financeiro.md`/`estoque_compras.md`). Quando o
  fornecedor emite a NF e ela é lançada no Connect, o mesmo valor pode
  acabar em `transacoes` sem que a `pedido_compra_parcelas`/`pedido_compra`
  (singular) de origem seja marcada como convertida — os blocos **podem se
  sobrepor**. Decisão: **mostrar os blocos separados, com aviso visível na
  tela**, sem tentar heurística de deduplicação nesta SPEC — vale tanto para
  Contas a Pagar × Pedidos de Compra quanto para Contas a Pagar × Previsões.
- **P-03 (dedup Pedidos de Compra × Previsões — CONFIRMADA, não é
  hipotética)**: 51 pedidos do export Connect (`pedido_compra`/`staging_
  pedido_compra`) já foram recriados manualmente dentro de `pedidos_compra`
  (plural, o app) como `numero = 'PC-LEGADO-<codigo_pedido>'`, com parcelas
  reais em `pedido_compra_parcelas` (achado da SPEC-039, 22/07/2026;
  reconfirmado ao vivo em 2026-09-04: 51 linhas `numero LIKE 'PC-LEGADO-%'`
  em `pedidos_compra`). Ao contrário de P-02 (sem chave de cruzamento),
  aqui a chave é exata (`codigo_pedido` embutido no `numero`). **Decisão do
  usuário: excluir de "Previsões" todo `codigo_pedido` que já tiver um
  `PC-LEGADO-<codigo_pedido>` em `pedidos_compra`** — evita duplicata certa
  sem inventar heurística.
- **Reversão explícita da SPEC-126** — a SPEC-126 registrou em "Decisões
  aprovadas": *"Pedido de Compra continua fora do Dashboard (só Produtos,
  Contas a Receber, Contas a Pagar, Caixa e — novo — Receita de Serviço)"*.
  Esta SPEC é a **exceção deliberada e de escopo restrito** a essa decisão:
  só a aba **Fluxo Futuro (Projeção)** passa a ler `pedidos_compra`/
  `pedido_compra_parcelas`, e só para fins de visualização de compromisso
  futuro. Isto **não** significa que "Pedido de Compra" vira uma aba própria
  do Dashboard, nem que as abas Contas a Pagar/Contas a Receber/Caixa/
  Estoque passam a considerar essas tabelas — elas continuam 100% baseadas
  em `v_financeiro_realizado`.
- Sem migration de escrita — leitura direta com a policy de `SELECT` já
  liberada para `authenticated` em `pedidos_compra` e `pedido_compra_parcelas`
  desde a criação das tabelas (SPEC-020/SPEC-038). Mesmo padrão já usado por
  `vw_necessidade_compra` (SPEC-039/041).

## Definição da SPEC

### Estado atual (SPEC-126 Escopo 8, publicado no Skip 41135 v0.0.36)

| Bloco hoje | Fonte | Comportamento |
| --- | --- | --- |
| "A Pagar" (único) | `transacoes` via `v_financeiro_realizado`, `tipo='despesa'`, `status_pago=0` (aberto) | Agrupado por `dt_vencimento` (helper `baldeVencimento`), balde "Vencido" primeiro. Alimenta 4 KPIs (A Receber / A Pagar / Saldo Projetado / Vencido líquido), gráfico `ComposedChart`, tabela mês a mês, tabela "por grupo" e `<PlanilhaTabela>` do fim da aba. |
| Pedidos de Compra | — | Não lido. |
| Previsões | — | Não lido. |

Fontes: `04-Sistemas/dashboard-lucenera-b02z85wa3/src/services/cash-flow.ts`
(`janelaFuturo`, `computeFluxoFuturoPorMes`, `computeGastoFuturoPorGrupo`,
`computeTotaisFluxoFuturo`, `computeDespesaAbertoPorDimensao`) e
`03-Projeto/Planos de Ação/SPECs/SPEC-126_Dashboard_Financeiro_Filtro_Data_
Confiabilidade_Correcoes.md`, seção "Escopo 8".

### Schema das 2 tabelas novas (confirmado em `supabase/db/current/` — não inventar coluna)

**`pedidos_compra`** (`supabase/db/migrations/20260710_031_spec020_operacionalizacao_compras/004_pedidos_compra.sql`, colunas adicionadas depois em SPEC-038/039/060/064):

| Coluna | Tipo | Observação |
| --- | --- | --- |
| `id` | uuid PK | |
| `numero` | text | formato `PC-<ano>-NNNN` |
| `fornecedor_id` | uuid → `contatos(id)` | join `contatos!fornecedor_id(nome)` (padrão já usado em `compras-lucenera-3o23t98ee/src/services/pedido-compra.ts:399`) |
| `status` | text CHECK | `'rascunho' \| 'aprovado' \| 'enviado' \| 'parcialmente_recebido' \| 'recebido' \| 'cancelado'` |
| `data_emissao` | date NOT NULL | |
| `data_prevista_entrega` | date | nullable |
| `valor_total` | numeric(12,2) | valor do pedido inteiro |
| `perfil` | text CHECK | `'ribeirao' \| 'sao_paulo'`, nullable (SPEC-064) |
| `cancelado_em`/`cancelado_por`/`motivo_cancelamento` | — | preenchidos por `cancelar_pedido_compra` (SPEC-060) |

**`pedido_compra_parcelas`** (`supabase/db/migrations/20260721_054_spec038_compras_melhorias/004_pedido_compra_parcelas.sql`):

| Coluna | Tipo | Observação |
| --- | --- | --- |
| `id` | uuid PK | |
| `pedido_id` | uuid → `pedidos_compra(id)` ON DELETE CASCADE | |
| `numero_parcela` | integer | |
| `valor` | numeric(12,2) CHECK > 0 | |
| `data_vencimento` | date NOT NULL | |
| `status` | text CHECK | `'pendente' \| 'pago' \| 'atrasado' \| 'cancelado'` |

**Achado confirmado via `cancelar_pedido_compra` (SPEC-060,
`supabase/db/migrations/20260805_076_spec060_cancelar_pedido_compra/
001_cancelar_pedido_compra.sql`):** cancelar um pedido já faz `UPDATE
pedido_compra_parcelas SET status='cancelado' WHERE pedido_id=... AND status
<> 'pago'`. Ou seja, filtrar `pedido_compra_parcelas.status IN ('pendente',
'atrasado')` já teria as parcelas de pedidos cancelados fora, **na maioria
dos casos** — mas o filtro explícito `pedidos_compra.status <> 'cancelado'`
no join continua sendo pedido pelo usuário como camada de segurança
redundante (cobre a borda: parcela `'pago'` de um pedido cancelado
continuaria com status `'pago'`, não `'cancelado'`, e não deve aparecer como
"em aberto" de qualquer forma porque o filtro de status da parcela já exige
`pendente`/`atrasado`).

**`pedido_compra`** (singular — `supabase/db/current/01_schema_full.sql:5497`, populada por `scripts/importar_pedido_compra.py`):

| Coluna | Tipo | Observação |
| --- | --- | --- |
| `id` | uuid PK | |
| `codigo_pedido` | integer | chave do Connect, **não confundir com `pedidos_compra.numero`** |
| `cod_fornecedor` | integer | código Connect do fornecedor (não é FK para `contatos`) |
| `nome_fornecedor` | text | nome cru do Connect (sem resolução para `contatos`) |
| `valor_nota` | numeric | valor total do pedido |
| `valor_duplicata` | numeric | nullable — só preenchido quando o pedido tem exatamente 1 parcela na planilha |
| `numero_parcela` | integer | idem |
| `data_emissao` | date | sempre preenchida |
| `data_vencimento` | date | nullable — mesma regra de `valor_duplicata` |
| `status` | text | hoje **sempre `'Pendente'`** nas 138 linhas atuais — campo nunca atualizado por nenhum fluxo (nenhum consumidor grava nele ainda); não usar como filtro de exclusão |
| RLS | — | `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` + policy `"Permitir leitura para autenticados" FOR SELECT USING (auth.role() = 'authenticated')` (`supabase/db/current/07_rls_policies.sql:710`) — **testado ao vivo com `SET ROLE authenticated` + JWT claim em 2026-09-04, retorna as 138 linhas** |

**`staging_pedido_compra`** (`supabase/db/current/01_schema_full.sql:6263`):

| Coluna | Tipo | Observação |
| --- | --- | --- |
| `codigo_pedido` | integer | mesma chave de `pedido_compra.codigo_pedido` — 1:N (1 linha por parcela do Excel) |
| `cod_fornecedor` / `nm_fornecedor` | integer / text | crus do Connect |
| `emissao_pedido` | **text** (não `date`) | formato `DD/MM/AAAA` — precisa parse no client, igual `to_iso_date()` do script Python |
| `vl_nota` | numeric | constante entre linhas do mesmo `codigo_pedido` |
| `num_parc` | numeric | nullable |
| `dt_vencimento` | **text** (não `date`) | formato `DD/MM/AAAA`, nullable — **183 de 314 linhas preenchidas hoje** |
| `vl_duplicata` | numeric | nullable, acompanha `dt_vencimento` |
| `processado` | boolean | sempre `true` nas linhas atuais |
| RLS | — | **tabela sem `ENABLE ROW LEVEL SECURITY` e sem nenhuma `CREATE POLICY`** (confirmado — nenhuma linha para `staging_pedido_compra` em `07_rls_policies.sql`) — mas **testado ao vivo com `SET ROLE authenticated` em 2026-09-04, retorna as 314 linhas normalmente** (grant padrão do schema `public`, RLS nunca foi ligado nesta tabela desde que foi criada). Achado informativo, fora do escopo desta SPEC corrigir: `staging_pedido_compra` é a única das tabelas envolvidas nesta SPEC sem RLS — não bloqueia a leitura pelo Dashboard, mas foge do padrão do resto do ecossistema (toda tabela nova desde SPEC-010 nasce com RLS + policy explícita) |

**Datas como `text`, não `date`** — diferente de `pedidos_compra`/`pedido_
compra_parcelas` (que usam `date` nativo), `staging_pedido_compra.emissao_
pedido`/`dt_vencimento` são `text` no formato `DD/MM/AAAA` (o script Python
usa `datetime.strptime(..., "%d/%m/%Y")` antes de gravar em `pedido_compra`,
mas grava a `staging_pedido_compra` sem conversão). O service novo do
frontend precisa fazer esse parse (`DD/MM/AAAA` → `Date`/ISO) antes de
qualquer bucket por mês — não é um formato ISO direto como o resto do
ecossistema.

### Bloco 1 — Contas a Pagar (não muda)

Continua exatamente como está: `transacoes` via `v_financeiro_realizado`,
`tipo='despesa'`, `aberto()` (`status_pago === 0`), agrupado por
`dt_vencimento`. Nenhuma função de `cash-flow.ts` relacionada a este bloco é
alterada.

### Bloco 2 — Pedidos de Compra (novo)

- **Query**: `pedido_compra_parcelas` com `status IN ('pendente','atrasado')`,
  JOIN `pedidos_compra` (excluir `pedidos_compra.status = 'cancelado'`).
- **Data de bucket**: `data_vencimento` da própria parcela (dado real, sem
  ambiguidade).
- **Valor**: `valor` da parcela (dado real).
- **Fornecedor**: `pedidos_compra.fornecedor_id → contatos.nome`.
- **Perfil**: `pedidos_compra.perfil` (nullable — mesmo comportamento do
  `filterByPerfil` existente: filtro ativo exclui linha com `perfil IS
  NULL`).
- Participa do switch "Incluir vencidos" via `status = 'atrasado'` ou
  `data_vencimento < hoje`.

### Bloco 3 — Previsões (novo, fonte corrigida em 2026-09-04)

- **Query**: `pedido_compra` (singular, cabeçalho) LEFT JOIN `staging_
  pedido_compra` por `codigo_pedido` — **ambas as tabelas, não só uma**,
  porque o cabeçalho perde granularidade de parcela quando o pedido tem 2+
  parcelas (`data_vencimento`/`valor_duplicata` ficam `NULL` no cabeçalho
  nesse caso — ver docstring de `scripts/importar_pedido_compra.py`).
- **Dedup obrigatória (P-03)**: excluir `codigo_pedido` que já aparece como
  `pedidos_compra.numero = 'PC-LEGADO-' || codigo_pedido` (51 casos hoje).
  Buscar os `numero LIKE 'PC-LEGADO-%'` de `pedidos_compra`, extrair o
  `codigo_pedido` (sufixo numérico após o prefixo) e remover do conjunto de
  `pedido_compra`/`staging_pedido_compra` antes de agregar.
- **Granularidade de exibição** (2 níveis, mesma lógica de "dado real >
  estimado" da versão anterior desta SPEC, só que a fonte do "real" mudou):
  - Quando existe pelo menos 1 linha de `staging_pedido_compra` para aquele
    `codigo_pedido` com `dt_vencimento` preenchido: 1 linha por parcela,
    valor = `vl_duplicata`, data = `dt_vencimento` (parseado de `DD/MM/AAAA`
    — ver nota de formato acima).
  - Quando **nenhuma** parcela daquele `codigo_pedido` tem `dt_vencimento`
    (hoje ~128 dos ~193 `codigo_pedido` distintos em `staging_pedido_
    compra` — **reconferir a contagem exata no momento da implementação**,
    o import roda periodicamente e o número muda): 1 linha para o pedido
    inteiro, valor = `pedido_compra.valor_nota`, data = `pedido_compra.
    data_emissao` (sempre preenchida). Marcar essa linha com um indicador
    de "estimado" (badge/coluna), igual ao desenho original.
- **Fornecedor**: `nome_fornecedor` (`pedido_compra`) / `nm_fornecedor`
  (`staging_pedido_compra`) — nome cru do Connect, **sem** resolução via
  `contatos` (`cod_fornecedor` não é FK, é só o código Connect). Não tentar
  cruzar com `contatos` nesta SPEC.
- **Perfil**: nenhuma das duas tabelas tem coluna `perfil` — Previsões
  **não participa** do filtro Perfil (Ribeirão/São Paulo) da aba. Deixar
  isso explícito na UI (ex. o Select de Perfil não afeta o card/tabela de
  Previsões, com nota visual).
- Não participa do switch "Incluir vencidos" — mistura linhas com
  vencimento real (já podem estar vencidas) e linhas estimadas por
  `data_emissao` (sem vencimento real); sempre visível, com texto auxiliar
  explicando por quê (mesmo critério do desenho original, mantido).

### Redesenho de KPIs / gráfico / tabelas

**KPIs (6 cards, 2 fileiras de 3 ou 1 fileira de 4+2 responsiva):**

| Card | Fonte | Muda com esta SPEC? |
| --- | --- | --- |
| A Receber | `v_financeiro_realizado` | Não |
| A Pagar (Contas a Pagar) | `v_financeiro_realizado` | Não |
| Saldo Projetado | A Receber − A Pagar (`v_financeiro_realizado`) | Não — continua sem somar os 2 blocos novos, para não inflar/deflar artificialmente por dupla contagem (P-02) |
| Vencido líquido | `v_financeiro_realizado` | Não |
| **Pedidos de Compra em Aberto** (novo) | `pedido_compra_parcelas` (app interno) | Novo — `tone="warning"`, `info` explicando a possível sobreposição |
| **Previsões de Compra (estimado)** (novo) | `pedido_compra`/`staging_pedido_compra` (export Connect, deduplicado contra `PC-LEGADO-*`) | Novo — `tone="warning"`, `info` explicando que mistura parcela real (vencimento conhecido) com estimativa por `data_emissao` quando o pedido não tem nenhuma parcela lançada |

**Gráfico "Projeção mês a mês"**: mantém o `ComposedChart` com as barras A
Receber (verde) / A Pagar (vermelho) e a linha de Saldo acumulado
inalteradas; adiciona 2 barras novas por mês — "Pedidos de Compra" (cor
distinta, ex. laranja) e "Previsões" (cor distinta, ex. cinza/hachurado, para
reforçar visualmente que é estimativa) — desenhadas ao lado das barras
existentes (agrupadas, não empilhadas — empilhar sugeriria que são somáveis,
o que contradiz P-02). Tooltip de cada barra nova reforça a fonte
("Pedidos de Compra — sistema de Compras" / "Previsões — pedido sem
parcelamento").

**Tabelas novas** (mesmo padrão `<PlanilhaTabela>` + arquivo `colunasX.ts`
já usado nas 3 abas financeiras e no bloco "por grupo" existente da própria
aba):

- "Pedidos de Compra em aberto": Pedido nº · Fornecedor · Parcela ·
  Valor · Vencimento · Status.
- "Previsões de Compra": Pedido (`codigo_pedido`) · Fornecedor (nome cru
  Connect) · Valor · Data · Origem da data (`vencimento real`/`estimado por
  emissão`).

Ambas exportáveis em CSV (reuso do `<PlanilhaTabela>`, sem componente novo).

### Aviso de sobreposição — P-02 (requisito de aceite explícito)

Banner sempre visível (não escondido atrás de tooltip/hover), no mesmo
espírito do texto já usado no card "Em Aberto (Pagar/Receber)" (`caption`
"Total acumulado — não muda com o filtro de período", SPEC-126 Escopo 7),
mas em formato de alerta mais destacado (ex. componente com `AlertTriangle`,
já importado em `ContasPagarFoco.tsx`), posicionado no topo da aba, acima
dos KPIs. Texto sugerido:

> **Atenção — fontes sem vínculo entre si.** "Contas a Pagar" vem do
> livro-caixa do Connect; "Pedidos de Compra" vem do sistema interno de
> Compras; "Previsões" vem de outro export do Connect (planilha
> PedidoCompra). Quando a nota fiscal de um pedido de compra é lançada no
> livro-caixa do Connect, o mesmo valor pode aparecer em mais de um bloco ao
> mesmo tempo — os 3 blocos **não devem ser somados** entre si até existir
> um jeito de cruzar as fontes. (Os 51 casos já identificados como
> duplicata certa entre Pedidos de Compra e Previsões já saem de Previsões
> automaticamente — ver P-03.)

Critério de aceite: o texto (ou equivalente aprovado pelo usuário) aparece
sempre que a aba é aberta, sem exigir clique/hover.

### Análise obrigatória de ecossistema

- **Depende de** `pedidos_compra`, `pedido_compra_parcelas`, `pedido_
  compra` (singular), `staging_pedido_compra`. `contatos` só é usado no
  Bloco 2 (Pedidos de Compra) — o Bloco 3 (Previsões) usa nome de fornecedor
  cru do Connect, sem join. Não depende de `projetos`, `orcamentos`,
  `boletos`, `projeto_itens`, `projeto_parcelas`, `usuarios`, `systems` nem
  `user_system_access`.
- **Afeta** o domínio Financeiro (Dashboard, leitura). Cruza pela primeira
  vez com o domínio Estoque/Compras — tanto o app (`pedidos_compra`/
  `pedido_compra_parcelas`) quanto o export cru do Connect (`pedido_compra`/
  `staging_pedido_compra`, que hoje **nenhum outro sistema lê** — confirmado
  em `supabase/db/domains/estoque_compras.md`, achado 22/07/2026) — sem
  alterar nada nesses domínios.
- **Não toca** em `vw_necessidade_compra`/`vw_necessidade_compra_pedidos_
  abertos`/`vw_necessidade_compra_pedido_detalhe` — são outro consumidor de
  `pedidos_compra` (plural), no sistema `compras-lucenera-3o23t98ee`, e
  continuam intactos (mesmo critério `status NOT IN ('recebido',
  'cancelado')` já usado lá, replicado aqui só para leitura, sem criar
  dependência entre os dois sistemas).
- **Dado duplicado que deveria ser derivado por relacionamento?** Dois casos
  distintos: (1) Contas a Pagar × Pedidos de Compra/Previsões — "dado
  duplicado" é uma **ausência de FK entre sistemas legados** (Connect ×
  Compras), não um campo redundante dentro de uma tabela; fora do escopo
  desta SPEC resolver (P-02), pode virar SPEC própria futura ("marca de
  origem"/cruzamento Connect ↔ Compras — mesmo tema já registrado como
  pendência na SPEC-126 Escopo 2B, mas para `transacoes` × orçamento de
  teste, não × pedido de compra). (2) Pedidos de Compra × Previsões — **este
  caso TEM chave exata** (`codigo_pedido` no `numero` `PC-LEGADO-*`) e por
  isso é resolvido nesta própria SPEC via exclusão determinística (P-03),
  não fica como dívida.
- **Migration antiga conflitante?** Nenhuma — `pedidos_compra`/`pedido_
  compra_parcelas` não tiveram alteração de shape desde SPEC-064 (coluna
  `perfil`); `pedido_compra`/`staging_pedido_compra` não têm migration
  própria documentada no repositório (tabelas pré-existentes, achado
  22/07/2026) mas o schema em `supabase/db/current/01_schema_full.sql`
  bate exatamente com o que o script de import grava. O snapshot em
  `supabase/db/current/` está alinhado com o que foi lido.
- **Exige migration ou `AI_DB_CONTEXT.md`?** Sem migration — leitura pura,
  e as 4 tabelas envolvidas já são legíveis por `authenticated` (testado ao
  vivo em 2026-09-04 via `SET ROLE authenticated` + JWT claim, não só
  service role — ver `feedback_rls_verification_authenticated_role`).
  Achado informativo sem ação nesta SPEC: `staging_pedido_compra` é a única
  das 4 sem RLS habilitado (nenhuma `ENABLE ROW LEVEL SECURITY`, nenhuma
  policy) — funciona hoje por causa do grant padrão do schema `public`, mas
  foge do padrão do resto do ecossistema (toda tabela desde SPEC-010 nasce
  com RLS + policy explícita); não é bloqueante, mas vale registrar como
  débito técnico separado. `AI_DB_CONTEXT.md` do `dashboard-lucenera-
  b02z85wa3` **não existe hoje** (confirmado por busca no repositório) —
  recomendado criar/atualizar ao publicar, já que é a primeira vez que este
  sistema lê tabelas de outro domínio.

### Fluxo de trabalho

1. `skip_file_read` do Skip 41135 para pegar o estado real de
   `FluxoFuturo.tsx` e `cash-flow.ts` — **não editar o checkout local do
   submódulo como se fosse a fonte da verdade** (está atrás da produção).
2. Implementar o service novo + as mudanças na página a partir do conteúdo
   lido do Skip.
3. QA local (`oxlint` / `tsc --noEmit` / `vite build`) — sem suíte de testes
   automatizada, critério de aceite é verificação manual.
4. Conferência manual no navegador + as queries SQL de conferência abaixo.
5. Publicar via `skip_file_write` → `apply_changes` (QA) → `publish`.
6. Sincronizar submódulo git local + ponteiro no repo central (dívida já
   registrada desde a SPEC-126, oportunidade de resolver junto).

### Critérios de aceite

- [ ] Rodar no Supabase real (implementador, via `SUPABASE_DB_URL`), como
  conferência do Bloco 2:
  ```sql
  SELECT count(*), sum(pcp.valor)
  FROM pedido_compra_parcelas pcp
  JOIN pedidos_compra pc ON pc.id = pcp.pedido_id
  WHERE pcp.status IN ('pendente','atrasado') AND pc.status <> 'cancelado';
  ```
  O KPI "Pedidos de Compra em Aberto" na tela deve bater exatamente com esse
  `sum`.
- [ ] Conferência do Bloco 3 (dedup P-03 incluída):
  ```sql
  WITH legado AS (
    SELECT (regexp_match(numero, 'PC-LEGADO-(\d+)'))[1]::int AS codigo_pedido
    FROM pedidos_compra
    WHERE numero LIKE 'PC-LEGADO-%'
  ),
  staging_com_venc AS (
    SELECT codigo_pedido, sum(vl_duplicata) AS total_parcelas
    FROM staging_pedido_compra
    WHERE dt_vencimento IS NOT NULL AND dt_vencimento <> ''
    GROUP BY codigo_pedido
  )
  SELECT
    count(*) FILTER (WHERE s.codigo_pedido IS NOT NULL) AS pedidos_com_parcela_real,
    count(*) FILTER (WHERE s.codigo_pedido IS NULL) AS pedidos_so_estimado,
    sum(COALESCE(s.total_parcelas, pc.valor_nota)) AS total_previsoes
  FROM pedido_compra pc
  LEFT JOIN staging_com_venc s ON s.codigo_pedido = pc.codigo_pedido
  WHERE pc.codigo_pedido NOT IN (SELECT codigo_pedido FROM legado);
  ```
  O KPI "Previsões de Compra (estimado)" deve bater com `total_previsoes`.
  Em 2026-09-04 (referência, vai mudar a cada import): 138 pedidos no
  total, 51 excluídos por P-03 → 87 elegíveis.
- [ ] Nenhum `codigo_pedido` com `PC-LEGADO-<codigo_pedido>` em
  `pedidos_compra` aparece na tabela "Previsões de Compra" (P-03).
- [ ] O pedido de teste revertido pela SPEC-060 (status `'cancelado'`,
  antigo `PC-...-1768`) **não aparece** no bloco Pedidos de Compra —
  confirma que o filtro de `status <> 'cancelado'` está correto (Previsões
  não tem esse conceito de status cancelável, ver schema de `pedido_
  compra`).
- [ ] Trocar o filtro Perfil (Ribeirão/São Paulo/Todos) recorta o bloco
  Pedidos de Compra junto com Contas a Pagar/Receber; o bloco Previsões
  **não muda** com esse filtro (sem coluna `perfil`) — conferir que a UI
  deixa isso claro em vez de parecer bug.
- [ ] Clicar num mês do gráfico filtra as 2 tabelas novas para aquele mês
  (Pedidos de Compra por `data_vencimento`; Previsões pelo bucket escolhido).
- [ ] O banner de aviso de sobreposição aparece sempre, sem precisar de
  clique/hover.
- [ ] Export CSV das 2 tabelas novas funciona (mesmo padrão `;`+BOM já usado
  no resto da aba).
- [ ] `oxlint` / `tsc --noEmit` / `vite build` limpos.
- [ ] QA do Skip (setup/static/build/integrations/test) tudo verde antes de
  publicar.
- [ ] Nenhum dos 4 KPIs existentes (A Receber, A Pagar, Saldo Projetado,
  Vencido líquido) muda de valor em relação à versão publicada antes desta
  SPEC (mesma fonte, sem soma com os blocos novos).

## Realizado

### 2026-09-04

- SPEC criada com Previsões = `pedidos_compra` sem parcela (P-01 original).
- **Corrigido pelo usuário no mesmo dia**: Previsões é o export Connect
  "PedidoCompra" (`pedido_compra` singular + `staging_pedido_compra`), não
  `pedidos_compra` (plural) sem parcela. Confirmado ao vivo no Supabase
  real: 138 pedidos / 314 parcelas (183 com `dt_vencimento`), ambas as
  tabelas legíveis por `authenticated` (testado com `SET ROLE authenticated`
  + JWT claim). Achado adicional do usuário/investigação: 51 desses pedidos
  já estão duplicados dentro de `pedidos_compra` (plural) como
  `PC-LEGADO-*` — decisão P-03 (excluir por `codigo_pedido`) tomada e já
  incorporada ao desenho acima. Nada implementado ainda — só a SPEC foi
  reescrita.
- **Implementado no Skip 41135** (`src/services/pedidos-compra-futuro.ts`
  novo, `src/components/colunasPedidosCompra.ts` novo, `src/pages/
  FluxoFuturo.tsx` editado) — versão **0.0.40** (`70754b9`), QA setup/
  static/build/integrations/test tudo verde. **Não publicado** — parado
  para o usuário confirmar antes de ir para produção.
  - Achado técnico não previsto na análise original: `pedidos_compra`/
    `pedido_compra_parcelas` **não existem** no `src/lib/supabase/types.ts`
    gerado deste sistema (só tem `pedido_compra` singular/`staging_pedido_
    compra`) — resolvido com `.from(<nome> as any)` só nessas 2 chamadas,
    documentado no topo do service e em `AI_DB_CONTEXT.md` (novo, criado
    localmente em `04-Sistemas/dashboard-lucenera-b02z85wa3/supabase/`,
    esse sistema não tinha nenhum ainda).
  - **Simplificação de escopo deliberada**: os 2 blocos novos não foram
    mesclados no `ComposedChart` "Entradas × Saídas por mês de vencimento"
    (ver desenho original em "Redesenho de KPIs / gráfico / tabelas") —
    ficaram como 2 KPIs + banner + 2 tabelas `<PlanilhaTabela>` à parte,
    sem participar do filtro Horizonte, do switch "Incluir vencidos" nem do
    cross-filter por mês/grupo. Razão: este projeto não tem suíte de teste
    visual (QA do Skip cobre setup/static/build/integrations/test, não
    renderização), e mexer num gráfico já testado sem poder validar
    visualmente foi avaliado como risco desnecessário numa tela usada pela
    diretoria. Consequência funcional: as 2 tabelas novas sempre mostram o
    conjunto completo (só o filtro Perfil afeta "Pedidos de Compra";
    "Previsões" não é afetado por nenhum filtro da página). Registrado como
    pendência abaixo para decisão do usuário.
  - Conferência contra o Supabase real (2026-09-04): Bloco 2 (Pedidos de
    Compra em Aberto) = 45 parcelas, **R$ 142.078,19**. Bloco 3 (Previsões)
    = 87 pedidos elegíveis após dedup P-03 (138 − 51 legado, bate com o
    número já previsto na SPEC), sendo 12 com parcela real (25 linhas) e 75
    só estimados (75 linhas) — **R$ 827.886,04**. Consultas completas na
    seção "Critérios de aceite".
  - `AI_DB_CONTEXT.md` criado no submódulo local (arquivo novo, não conflita
    com as mudanças não commitadas de SPEC-120 já presentes nesse checkout).

## Pendências

- [ ] **Publicar em produção** — QA aplicado (v0.0.40 / `70754b9`), aguardando
  confirmação do usuário para `skip_project_publish`.
- [ ] **Decidir se vale mesclar Pedidos de Compra/Previsões no gráfico
  "Entradas × Saídas por mês de vencimento"** (desenho original desta SPEC),
  dando a eles Horizonte/"Incluir vencidos"/cross-filter por mês — trimmed
  na implementação de 2026-09-04 por risco de regressão num gráfico sem
  cobertura de teste visual (ver "Realizado"). Se o usuário quiser, é um
  incremento à parte, não deveria exigir reabrir P-01/P-02/P-03.
- [ ] **Sobreposição Connect × Compras (P-02)** não é resolvida aqui — só
  mostrada com aviso (exceto o caso P-03, que tem chave exata e já é
  deduplicado). Cruzar Contas a Pagar com Pedidos de Compra/Previsões (ex.
  marcar a duplicata como "já lançada no livro-caixa") fica para SPEC
  futura, possivelmente junto com a pendência já registrada na SPEC-126
  Escopo 2B (marca de origem em `transacoes`).
- [ ] `staging_pedido_compra` sem RLS — não bloqueia esta SPEC (achado
  informativo na "Análise obrigatória de ecossistema"), mas é um débito de
  segurança leve que pode virar item de outra SPEC (padronizar RLS+policy
  como todas as demais tabelas do ecossistema).
- [ ] `pedidos_compra`/`pedido_compra_parcelas` ausentes do `types.ts`
  gerado deste sistema — os casts `as any` funcionam, mas se o types.ts for
  regenerado incluindo essas tabelas, `pedidos-compra-futuro.ts` pode ser
  simplificado removendo os casts.
- [ ] Sincronização geral do submódulo `dashboard-lucenera-b02z85wa3`
  (git local atrás do Skip desde pelo menos SPEC-126/127) continua em
  aberto — não é bloqueante desta SPEC, mas cada nova SPEC nesse sistema
  paga esse custo de "ler o Skip antes de editar". `AI_DB_CONTEXT.md` foi
  criado localmente nesta SPEC (novo, não existia); ainda falta commit/push
  do submódulo e atualização do ponteiro no repo central.
