---
titulo: "SPEC-039 — Necessidade de Compra: Layout Full-Screen, Colunas de Fornecedor/Empresa/Status/Entrega e Fix de Busca"
status: implementado, aplicado e publicado em produção (Skip v0.0.45)
data_ultima_modificacao: 2026-07-21
sistemas_envolvidos:
  - Supabase (banco central)
  - compras-lucenera-3o23t98ee (Necessidade de Compra)
referencias:
  - SPEC-020/021 (solicitacoes_compra, pedidos_compra, pedido_compra_itens, cotacoes_compra)
  - SPEC-022 (vw_necessidade_compra_detalhe — vínculo informativo projeto/orçamento)
  - SPEC-030/033/034 (marca → fornecedor, vw_necessidade_compra com fornecedor_id/fornecedor_nome)
  - SPEC-038 (impostos, numeração automática, parcelas de pedido_compra — mesmo domínio, achado crítico de pedidos_compra ausente no banco real corrigido em 21/07)
  - supabase/db/domains/estoque_compras.md (decisão da reunião 08/06/2026: necessidade de compra é agregada por produto, não por cliente)
---

# SPEC-039 — Necessidade de Compra: Layout Full-Screen, Colunas de Fornecedor/Empresa/Status/Entrega e Fix de Busca

> Esta SPEC cobre 4 pedidos do usuário na tela **Necessidade de Compra** do
> sistema `compras-lucenera-3o23t98ee`: (1) layout full-screen, (2) novas
> colunas no grid, (3) correção de um bug real e já confirmado na busca, e
> (4) recálculo do "Pendente" considerando pedidos de compra em aberto.
> Dois dos quatro pedidos (colunas "Empresa que comprou"/"Status do
> pedido"/"Data prevista de entrega") esbarram num conflito real de
> granularidade de dado — a view é 1 linha por produto, mas um produto pode
> ter 0, 1 ou N `pedidos_compra` em aberto — e por isso viram decisões em
> aberto (P-01 a P-04) em vez de suposições da minha parte.

## Checklist de Ação

### Backend

- [x] **Decisão do usuário necessária antes de escrever qualquer migration desta SPEC** — ver P-01, P-02, P-03, P-04 em "Pendências" (fechadas em 21/07/2026, ver "Decisões do usuário")
- [x] Corrigir `applySearchFilter` em `services/necessidade-compra.ts` (bug de busca)
- [x] (Após P-04) Adicionar coluna `pendente` a `vw_necessidade_compra` (déficit ainda não coberto por pedido de compra em aberto) — migration `004_vw_necessidade_compra_pendente_e_filtro.sql`
- [x] (Após P-01) Criar view de agregação por produto para "Empresa que comprou" / "Status do pedido" / "Data prevista de entrega" — migration `003_vw_necessidade_compra_pedido_resumo.sql` (`vw_necessidade_compra_pedidos_abertos` + `vw_necessidade_compra_pedido_detalhe`)
- [x] (Após P-03, Alternativa A) `ALTER TABLE pedidos_compra ADD COLUMN empresa_id uuid REFERENCES empresas(id)` + RPCs `criar_pedido_compra_de_necessidade`/`criar_pedido_compra_lote` recriadas para gravar esse valor — migrations `001_pedidos_compra_empresa_id.sql` + `002_criar_pedido_compra_empresa_automatica.sql`
- [x] **As 4 migrations aplicadas no Supabase real em 21/07/2026** (001→002→003→004, nesta ordem, todas commitadas com sucesso)
- [ ] Reextrair `supabase/db/current/` depois de aplicar (pendência crônica do domínio, reforçada por esta SPEC — ver `supabase/db/domains/estoque_compras.md`) — **passo manual do usuário**

### Frontend (`compras-lucenera-3o23t98ee`)

- [x] `App.tsx` (`AppShell`): `<main>` full-width/full-height para as rotas `/` e `/necessidade-compra` (condição `isFullWidthRoute`, mesmo padrão de `isLoginRoute`)
- [x] `NecessidadeCompra.tsx`: container raiz com `h-[calc(100vh-4rem)]` em todos os breakpoints e `pb-20 lg:pb-0` removido (confirmado: `AppNav` é nav superior renderizado via `ProtectedRoute`, não bottom-nav mobile; `Layout.tsx`/bottom-nav não é montado em `App.tsx`)
- [x] `NecessidadeCompra.tsx`: removidas as classes `hidden md/lg/xl:table-cell` — todas as colunas sempre no DOM, `<Table className="min-w-[1750px] ...">` para scroll horizontal via `overflow-auto` do container pai
- [x] `NecessidadeCompra.tsx`: coluna **Fornecedor** adicionada (`r.fornecedor_nome`)
- [x] Corrigir `services/necessidade-compra.ts::applySearchFilter` (bug de busca)
- [x] Adicionar coluna **Pendente** ao grid, ao lado de "Necessidade" (destaque com ícone; "Necessidade" mantida como coluna informativa)
- [x] Adicionar colunas **Empresa que comprou** (resumo — "N pedidos"), **Status do pedido** (resumo — status mais urgente traduzido), **Data prevista de entrega** (mais próxima); painel expansível (`NecessidadeCompraDetalhe.tsx`) estendido para listar cada pedido individualmente (número/status/empresa/data)
- [x] Rodar `oxlint`/`oxfmt`/`vite build` após as alterações — sem erros novos (só 2 warnings pré-existentes em `Cotacoes.tsx`, não relacionados a esta SPEC)
- [x] Atualizar `supabase/db/domains/estoque_compras.md` com os objetos desta SPEC

### Passos manuais do usuário

- [x] Decidir P-01 (granularidade produto × pedido para as 3 colunas novas)
- [x] Decidir P-02 (vocabulário de status a exibir)
- [x] Decidir P-03 (origem de "empresa que comprou")
- [x] Decidir P-04 (fórmula/comportamento do "Pendente")
- [x] Aplicar as migrations em `supabase/db/migrations/20260722_056_spec039_necessidade_compra_grid/` no Supabase real, em ordem (001 → 002 → 003 → 004) — `pg_get_viewdef` confirmado batendo com a base esperada antes de aplicar `004`
- [x] Rodar o agente `revisor` antes de aplicar/commitar — sem achados
- [x] Testado end-to-end via chamadas reais (RPC + REST): criação de pedido via `criar_pedido_compra_de_necessidade`, `vw_necessidade_compra_pedidos_abertos`/`vw_necessidade_compra_pedido_detalhe` retornando corretamente, busca por código exato e por nome (ambas sem erro `42883`), filtro `pendente > 0` confirmado (produto com déficit 100% coberto por pedido aberto de fato some da lista)
- [x] Frontend sincronizado com Skip (projeto 40326), QA completo, publicado em produção — versão `0.0.45`
- [ ] Reextrair `supabase/db/current/` depois de aplicar — pendência crônica ainda em aberto
- [ ] Testar golden path no navegador manualmente (o orquestrador validou via chamadas diretas à API, não clicando na UI)

### Achado durante o teste end-to-end (higiene de dados, não bug de código)

Um pedido de teste da sessão da SPEC-038 (`PC-2026-0001`, 3 unidades do mesmo produto usado como fixture de teste) **não havia sido limpo corretamente** — o script de cleanup daquela sessão apagava `pedido_compra_itens` antes de resolver `solicitacoes_compra` a partir dele, então a subquery de limpeza de `solicitacoes_compra` retornava vazia e o `DELETE FROM pedidos_compra` seguinte, embora não bloqueado por isso, deixou o pedido "vivo" o suficiente para aparecer nas contagens de `qtd_em_pedidos_abertos` desta SPEC. Identificado porque a query de teste desta SPEC-039 mostrou 2 pedidos abertos para um produto que deveria ter só 1 (o criado neste teste). Removido manualmente (produto/quantidade/custo conferidos batendo exatamente com os parâmetros do teste original antes da exclusão). Não afeta nenhuma migration ou código desta SPEC — é só um lembrete para scripts de teste futuros: apagar tabelas-filhas primeiro nunca é seguro se uma limpeza posterior depende de uma subquery sobre a mesma tabela já esvaziada.

## Objetivo

Pedro pediu 4 melhorias na tela **Necessidade de Compra**:

1. Layout full-screen (100% da viewport, sem paddings/margens excessivos, grid responsivo com scroll horizontal priorizando visibilidade total das colunas).
2. Novas colunas obrigatórias: Fornecedor; Empresa que comprou; Status do pedido; Data prevista de entrega.
3. Corrigir bug: busca por "Produto" não retorna resultado ao buscar pelo código do produto (numérico/SKU).
4. Regra de negócio: manter a exibição de déficit (Necessidade > Disponível, já existe) e recalcular "Pendente" dinamicamente considerando os novos status de pedido e quantidades já vinculadas.

Esta SPEC confirma o que é puramente técnico (1, 3, e a parte de "Fornecedor" do item 2), e levanta como perguntas abertas o que depende de decisão de negócio (as demais 3 colunas do item 2, e a fórmula exata do item 4).

## Decisões aprovadas

Decisões já fechadas em SPECs anteriores deste mesmo domínio, **reafirmadas, não reabertas** por esta SPEC:

- Necessidade de compra é agregada por produto, não por cliente/projeto (reunião 08/06/2026, `supabase/db/domains/estoque_compras.md`, SPEC-020/022/038). As colunas novas desta SPEC não podem transformar `vw_necessidade_compra` numa view por pedido — a granularidade continua 1 linha por produto; o que varia é como resumir os dados de `pedidos_compra` (N:1 com o produto) nessa única linha.
- `fornecedor_id`/`fornecedor_nome` já existem em `vw_necessidade_compra` desde a SPEC-030 (`COALESCE(produtos.fornecedor_principal_id, marcas.fornecedor_id)`) — não é preciso migration nenhuma para exibir a coluna Fornecedor no grid.
- Causa raiz do bug de busca confirmada pelo orquestrador via chamada HTTP direta ao PostgREST: `produtos.codigo_produto` é `integer`; `query.or('produto.ilike...,produto_codigo.ilike...')` gera `operator does not exist: integer ~~* unknown` (`42883`), e isso derruba a query inteira — **toda busca não vazia falha hoje**, não só a busca por código.
- `pedidos_compra` é uma tabela já aplicada e testada no Supabase real (achado crítico corrigido em 21/07/2026, migration `20260721_055_fix_pedidos_compra_base`) — as colunas/status usados por esta SPEC são reais, não hipotéticos.

## Análise de ecossistema

- **Depende de**: `produtos` (via `vw_necessidade_compra`), `contatos` (fornecedor), `pedidos_compra`/`pedido_compra_itens` (status, data prevista, quantidade recebida). Potencialmente `empresas` e `usuarios` (`usuarios.empresa_id` já existe hoje) se P-03 optar por vincular a empresa do usuário logado. **Não depende** de `projetos`, `orcamentos`, `boletos`, `projeto_parcelas` diretamente — a única ponte com projeto/orçamento já existe via `NecessidadeCompraDetalhe.tsx`/`vw_necessidade_compra_detalhe` (SPEC-022) e não muda nesta SPEC.
- **Sistemas afetados**: só Estoque/Compras (`compras-lucenera-3o23t98ee`). Não toca CRM, Orçamentos, Financeiro, Cadastro, Logística, RH ou Hub/TI.
- **Dado duplicado vs. derivado por relacionamento**: a proposta desta SPEC (item 4) deriva "Pendente" por `JOIN`/agregação em `pedido_compra_itens`/`pedidos_compra` a partir da view, sem duplicar nada em `produtos`. Se P-03 escolher Alternativa A (nova coluna `pedidos_compra.empresa_id`), essa é uma coluna nova legítima (FK direta), não duplicação — seguiria o mesmo padrão já usado por `orcamentos.empresa_id`, `projetos.empresa_id`, `boletos.empresa_id`, etc.
- **Migration antiga que contradiz o snapshot central**: nenhuma nova encontrada nesta investigação. `pedidos_compra` segue ausente de `supabase/db/current/` (pendência crônica já registrada em `supabase/db/domains/estoque_compras.md`) — reforça a necessidade de reextração após qualquer migration desta SPEC.
- **Exige atualizar `AI_DB_CONTEXT.md`**: só se P-01/P-02/P-03/P-04 resultarem em coluna/view nova — nesse caso, atualizar tanto `supabase/db/domains/estoque_compras.md` quanto o `AI_DB_CONTEXT.md` do sistema `compras-lucenera-3o23t98ee`, se existir.
- **Padrão de acesso a dados já usado pelo sistema**: `services/*.ts` fazem chamadas diretas `supabase.from(...)`/`supabase.rpc(...)` (sem camada de hooks/stores intermediária) — esta SPEC segue o mesmo padrão, sem introduzir nada novo.

## Definição da SPEC

### 1. Layout full-screen (técnico — não precisa de decisão do usuário)

**Estado atual (confirmado no código):**

- `App.tsx` (`AppShell`): `<main className="w-full max-w-[1600px] mx-auto px-4 md:px-6 py-4 md:py-6">` — limite de 1600px de largura e padding em **todas** as rotas do app, não só Necessidade de Compra.
- `AppHeader.tsx`: header fixo `sticky top-0 h-16` (64px).
- `NecessidadeCompra.tsx`: container raiz `flex flex-col space-y-4 w-full pb-20 lg:pb-0 xl:h-[calc(100vh-130px)]` — a altura de viewport só é calculada a partir do breakpoint `xl`; em telas menores a tabela cresce livremente (sem full-height).
- `AppNav.tsx` existe no código mas **não é renderizado** em `App.tsx`/`AppHeader.tsx` — não há bottom-nav mobile ativo hoje; o `pb-20 lg:pb-0` da página parece resíduo sem componente correspondente montado.

**Mudança proposta:**

- Em `App.tsx`, replicar o padrão que já existe para `isLoginRoute` (rota especial sem o shell padrão): criar `isFullWidthRoute` para `/` e `/necessidade-compra`, renderizando `<main>` sem `max-w-[1600px]`/padding para essas rotas, mantendo o padrão atual para as demais (Cotações, Estoque, Marcas, Pedidos).
- Em `NecessidadeCompra.tsx`, trocar a altura para `h-[calc(100vh-4rem)]` (4rem = 64px do `AppHeader`) em todos os breakpoints, não só `xl`, e remover `pb-20 lg:pb-0` (não há bottom-nav ativo para justificar esse espaço — confirmar visualmente no golden path antes de remover).
- Trocar `hidden md:table-cell`/`hidden lg:table-cell`/`hidden xl:table-cell` por **sempre visível** em todas as colunas, dando ao `<Table>` um `min-w-[...]` (a definir conforme número final de colunas) para que o `overflow-auto` do container pai (já existente) produza scroll horizontal em vez de esconder coluna.

**Critério de aceite**: em qualquer resolução (mobile, tablet, desktop), a tela ocupa 100% da largura/altura disponível abaixo do header, e todas as colunas do grid estão sempre presentes no DOM (visíveis via scroll horizontal quando a viewport for estreita).

### 2. Novas colunas do grid

| Coluna | Status | Origem do dado |
|---|---|---|
| **Fornecedor** | Pronta para implementar já, sem migration | `vw_necessidade_compra.fornecedor_nome` (SPEC-030), só falta renderizar em `NecessidadeCompra.tsx` |
| **Empresa que comprou** | Bloqueada — depende de P-01 e P-03 | Não existe hoje nenhuma coluna de empresa em `pedidos_compra`/`pedido_compra_itens` |
| **Status do pedido** | Bloqueada — depende de P-01 e P-02 | `pedidos_compra.status` existe, mas vocabulário não bate com o pedido do usuário, e granularidade é N pedidos por produto |
| **Data prevista de entrega** | Bloqueada — depende de P-01 | `pedidos_compra.data_prevista_entrega` já é capturada em `ModalRegistrarCompra.tsx`/`ModalPedidoLote.tsx`, mas é por pedido, não por produto |

### 3. Bug fix de busca

**Causa raiz** (confirmada): `produtos.codigo_produto` é `integer`; `applySearchFilter` faz `query.or('produto.ilike...,produto_codigo.ilike...')`, e o PostgreSQL rejeita `ilike` sobre `integer` (`42883`). Isso derruba a query inteira — hoje **qualquer** termo digitado na busca (não só números) falha silenciosamente, mascarado pelo toast genérico "Falha ao carregar necessidade de compra".

**Solução escolhida** (filtro separado por regex numérico, sem cast em runtime):

```ts
function applySearchFilter(query: any, searchTerm?: string) {
  if (!searchTerm) return query
  const trimmed = searchTerm.trim()
  if (!trimmed) return query

  const isNumeric = /^\d+$/.test(trimmed)
  if (isNumeric) {
    // produto_codigo é integer — comparação exata, sem CAST em runtime dentro
    // do .or() do PostgREST (sintaxe de cast tipo `coluna::text.ilike...` não
    // tem precedente testado neste codebase — evitar risco desnecessário).
    return query.or(`produto.ilike.%${trimmed}%,produto_codigo.eq.${parseInt(trimmed, 10)}`)
  }
  // Termo não numérico nunca poderia bater em produto_codigo (integer) mesmo
  // com cast — gerar só a condição que faz sentido.
  return query.ilike('produto', `%${trimmed}%`)
}
```

**Trade-off documentado**: essa correção resolve o bug relatado (buscar pelo código exato do produto volta a funcionar, e a busca por nome deixa de quebrar a query inteira). Ela faz correspondência **exata** para termos numéricos, não prefixo/substring (buscar "12" não encontra o código "1234"). Se no futuro for necessário busca parcial também sobre o código, a alternativa seria `produto_codigo::text.ilike.%X%` dentro do `.or()` — sintaticamente aceito pelo PostgREST em filtros (`coluna::tipo.operador.valor`), mas **sem precedente testado neste codebase**; deve ser validado manualmente antes de adotar (via chamada HTTP direta ao PostgREST, como o orquestrador já fez para diagnosticar o bug original) antes de trocar a Opção B pela Opção A.

**Critério de aceite**: buscar pelo nome do produto retorna resultados; buscar pelo código numérico exato retorna o produto correspondente; buscar um termo qualquer não gera mais erro `42883`/toast de falha genérica.

### 4. Regras de negócio — déficit e recálculo de "Pendente"

**Déficit (item já existente, não muda)**: `vw_necessidade_compra.necessidade_compra = GREATEST(0, qtd_comprometida - qtd_fisica)` (confirmado na última migration real que recria a view, `20260721_054_spec038_compras_melhorias/005_cotacoes_desconto_produto.sql`). Continua sendo exibido como está — coluna "Necessidade", com o ícone de alerta vermelho já usado hoje.

**Recálculo de "Pendente" (novo, proposta técnica concreta)**:

```sql
-- Rascunho conceitual — não bloqueado por P-01/P-02/P-03, usa apenas o enum
-- real já existente em pedidos_compra.status.
qtd_em_pedidos_abertos(produto_id) =
    SUM(pci.quantidade - pci.qtd_recebida)
    FROM pedido_compra_itens pci
    JOIN pedidos_compra pc ON pc.id = pci.pedido_id
    WHERE pci.produto_id = <produto_id>
      AND pc.status NOT IN ('recebido', 'cancelado')

pendente = GREATEST(0, necessidade_compra - qtd_em_pedidos_abertos)
```

Isso viraria uma coluna adicional em `vw_necessidade_compra` (derivada por `LEFT JOIN`/subquery, sem duplicar dado nenhum), não uma substituição da coluna `necessidade_compra` existente.

**Trade-off que precisa de confirmação (ver P-04)**: essa fórmula não altera o `WHERE` que hoje decide quais produtos aparecem na lista (`qtd_reservada > qtd_estoque`) — um produto que já tem pedido de compra aberto cobrindo 100% do déficit continuaria aparecendo na tela, só que com `pendente = 0` em vez de desaparecer da lista. Isso é proposital (mantém rastreabilidade até o recebimento efetivo), mas é uma escolha de produto, não só técnica — ver P-04.

## Migrations propostas (rascunho — bloqueadas por decisão do usuário, exceto onde indicado)

Pasta sugerida (a confirmar o próximo número livre no momento da implementação, depois de `20260721_055_fix_pedidos_compra_base`): `supabase/db/migrations/20260722_056_spec039_necessidade_compra_grid/`.

- `001_vw_necessidade_compra_pendente.sql` — coluna `pendente` (fórmula acima). **Não bloqueada** por P-01/P-02/P-03, só por P-04.
- `002_pedidos_compra_empresa_id.sql` — `ALTER TABLE pedidos_compra ADD COLUMN empresa_id uuid REFERENCES empresas(id)`. **Bloqueada por P-03.**
- `003_vw_necessidade_compra_pedido_resumo.sql` (ou equivalente) — view/subquery de resumo de status/empresa/data prevista por produto, formato dependente de P-01. **Bloqueada por P-01.**

Nenhuma dessas migrations foi escrita em SQL final nesta SPEC — o formato exato de `002`/`003` depende diretamente das respostas de P-01/P-02/P-03.

## Realizado

**22/07/2026** — Implementação completa (backend rascunhado, frontend aplicado):

- Migrations rascunhadas em `supabase/db/migrations/20260722_056_spec039_necessidade_compra_grid/` (001 a 004 + `README.md`), **não aplicadas no Supabase real** — aplicação é passo manual do usuário. Ver detalhes de cada arquivo no `README.md` da pasta.
- Frontend (`04-Sistemas/compras-lucenera-3o23t98ee`):
  - `src/services/necessidade-compra.ts`: `applySearchFilter` corrigida (busca numérica exata via `.eq()`, busca por nome via `.ilike()`, sem `ilike` sobre `produto_codigo`); tipo `NecessidadeCompraRow` estendido com `pendente`/`qtd_pedidos_abertos`/`proxima_data_prevista_entrega`/`status_mais_critico`; novo tipo `PedidoCompraAbertoRow`; nova função `getPedidosAbertosPorProduto`; dicionário `STATUS_PEDIDO_COMPRA_LABEL` + `traduzirStatusPedidoCompra` (P-02).
  - `src/pages/NecessidadeCompra.tsx`: container full-height (`h-[calc(100vh-4rem)]`, sem `pb-20 lg:pb-0`); grid com 15 colunas sempre visíveis (`hidden md/lg/xl:table-cell` removidas, `<Table min-w-[1750px]>` + scroll horizontal); colunas novas Fornecedor/Empresa que comprou (resumo)/Status do pedido (resumo)/Entrega prevista; métrica de destaque trocada de "Necessidade" para "Pendente" (Necessidade mantida como coluna informativa).
  - `src/App.tsx`: `AppShell` com `isFullWidthRoute` (`/` e `/necessidade-compra`) renderizando `<main>` sem `max-w-[1600px]`/padding, demais rotas inalteradas.
  - `src/components/compra/NecessidadeCompraDetalhe.tsx`: painel expansível estendido com uma segunda tabela ("Pedidos de compra em aberto") listando cada `pedidos_compra` individualmente (número/status traduzido/empresa/data prevista/qtd. pendente), ao lado da tabela de projetos já existente.
  - `supabase/db/domains/estoque_compras.md` atualizado com os objetos desta SPEC (P-01 a P-04).
- Verificação: `npx oxlint src` (sem erros novos — só 2 warnings pré-existentes em `Cotacoes.tsx`, não relacionados), `npx oxfmt --check` (100% formatado), `npm run build` (build ok).
- **Desvio da especificação técnica**: o container raiz de `NecessidadeCompra.tsx` recebeu `px-4 md:px-6 py-3` (padding próprio da página), em vez de ficar 100% sem padding como o texto literal da seção "Especificação técnica final" sugeria. Decisão técnica do implementador (não de negócio) para evitar conteúdo colado nas bordas do viewport — o objetivo de "ocupar 100% da largura/altura disponível abaixo do header" continua atendido (o `<main>` pai não tem mais `max-w-[1600px]`/padding para esta rota). Ajustar/remover se o golden path mostrar que não é o efeito desejado.
- Não testado no navegador (fora do escopo deste agente) — ver "Passos manuais do usuário".

## Decisões do usuário (21/07/2026)

- **P-01 — Granularidade produto × pedido**: **Alternativa A**. Linha principal mostra resumo agregado (ex.: "2 pedidos em aberto", `data_prevista_entrega` mais próxima, status mais crítico); expandir a linha (reaproveitando o painel já usado em `NecessidadeCompraDetalhe.tsx`) lista cada `pedidos_compra` individualmente com status/empresa/data.
- **P-02 — Vocabulário de status**: **Alternativa A**. Mapeamento 1:1 do enum real de `pedidos_compra.status` para rótulos em português, sem incluir o estágio de cotação (que segue órfão, fora do escopo desta SPEC):
  - `rascunho` → "Pendente"
  - `aprovado` → "Aprovado"
  - `enviado` → "Pedido Emitido"
  - `parcialmente_recebido` → "Em Trânsito"
  - `recebido` → "Recebido"
  - `cancelado` → "Cancelado"
- **P-03 — Origem de "Empresa que comprou"**: **Alternativa A**. Nova coluna `pedidos_compra.empresa_id uuid REFERENCES empresas(id)`, preenchida automaticamente dentro das RPCs `criar_pedido_compra_de_necessidade`/`criar_pedido_compra_lote` via `SELECT empresa_id FROM usuarios WHERE id = auth.uid()` — sem campo novo no formulário, sem input manual do usuário final. Confirmado no banco real: `usuarios.empresa_id` já existe como FK para `empresas(id)`, e `usuarios.id` corresponde ao mesmo UUID de `auth.uid()` (mesmo padrão já usado por `criado_por`/`aprovado_por` nas RPCs existentes).
- **P-04 — Comportamento do "Pendente"**: **decisão contrária à recomendação da SPEC** — quando `pendente` chega a 0 (déficit já 100% coberto por pedido de compra em aberto), o produto deve **sair da lista** de Necessidade de Compra. Isso muda o filtro `WHERE` da view: em vez de `qtd_reservada > qtd_estoque` (baseado só em estoque físico), a view passa a filtrar por `pendente > 0` (considerando também pedidos de compra já em aberto). A coluna "Necessidade" (déficit bruto, sem descontar pedidos) continua existindo e sendo exibida — o que muda é qual coluna decide a visibilidade da linha na lista.

## Especificação técnica final (para o implementador)

### Migration `20260722_056_spec039_necessidade_compra_grid` (4 arquivos)

- `001_pedidos_compra_empresa_id.sql`:
  ```sql
  ALTER TABLE public.pedidos_compra ADD COLUMN IF NOT EXISTS empresa_id uuid REFERENCES public.empresas(id);
  COMMENT ON COLUMN public.pedidos_compra.empresa_id IS
  'Empresa/filial que efetuou a compra — preenchida automaticamente pela RPC a partir de usuarios.empresa_id do usuário autenticado (SPEC-039, P-03).';
  ```
- `002_criar_pedido_compra_empresa_automatica.sql`: recriar `criar_pedido_compra_de_necessidade` e `criar_pedido_compra_lote` para gravar `empresa_id` no INSERT de `pedidos_compra`, resolvendo com:
  ```sql
  SELECT empresa_id INTO v_empresa_id FROM public.usuarios WHERE id = auth.uid();
  ```
  e incluindo `v_empresa_id` no INSERT. **Atenção**: `criar_pedido_compra_de_necessidade` já tem 12 parâmetros — como esta mudança NÃO adiciona parâmetro novo (o valor vem de `auth.uid()`, não de input do frontend), `CREATE OR REPLACE FUNCTION` funciona normalmente aqui, sem necessidade de `DROP FUNCTION` (lição da SPEC-038: só é preciso DROP quando a contagem de parâmetros muda).
- `003_vw_necessidade_compra_pedido_resumo.sql`: view auxiliar `vw_necessidade_compra_pedidos_abertos` (ou nome equivalente), agregada por `produto_id`, com pelo menos: `qtd_pedidos_abertos`, `qtd_em_pedidos_abertos` (soma de `quantidade - qtd_recebida` dos itens, considerando só pedidos com `status NOT IN ('recebido', 'cancelado')`), `proxima_data_prevista_entrega` (MIN da data entre os pedidos abertos), `status_mais_critico` (definir ordem de criticidade, ex. `enviado` > `aprovado` > `rascunho`, ou pelo pedido com entrega mais próxima). Também deve existir uma forma de listar o detalhe completo por produto (reaproveitando/estendendo o padrão de `NecessidadeCompraDetalhe.tsx`) com `numero`, `status` (já traduzido ou cru — decidir no código), `empresa_nome` (via join com `empresas`), `data_prevista_entrega` por pedido individual.
- `004_vw_necessidade_compra_pendente_e_filtro.sql`: `CREATE OR REPLACE VIEW vw_necessidade_compra` incluindo a coluna `pendente` (fórmula: `GREATEST(0, necessidade_compra - qtd_em_pedidos_abertos)`, reaproveitando a agregação de `003`) e **trocando o `WHERE`** de `qtd_reservada > qtd_estoque` para filtrar por `pendente > 0`. Confirmar antes a definição real aplicada (`SELECT pg_get_viewdef('public.vw_necessidade_compra', true)`) e preservar todas as colunas já existentes (incluindo as da SPEC-038: `percentual_desconto_compra`, `marca_id`, `marca_nome`, `fornecedor_id`, `fornecedor_nome`).

### Frontend

- `services/necessidade-compra.ts`: aplicar a correção de `applySearchFilter` já detalhada na seção "3. Bug fix de busca" acima; adicionar `fornecedor_nome`/`fornecedor_id` (já existem no tipo) às colunas renderizadas; adicionar `pendente`, `qtd_pedidos_abertos`, `proxima_data_prevista_entrega`, `status_mais_critico_label` (ou equivalente) ao tipo `NecessidadeCompraRow`; criar função de busca do detalhe por produto (pedidos abertos individuais) similar a `getEntregaFuturaPorProduto`.
- `NecessidadeCompra.tsx`: grid ganha colunas Fornecedor, Empresa que comprou (resumo), Status do pedido (resumo, rótulo traduzido conforme P-02), Data prevista de entrega (próxima); trocar `necessidade_compra`/déficit por `pendente` como coluna de destaque e como base do "0 resultados"; layout full-screen conforme seção 1; remover `hidden md/lg/xl:table-cell`, usar scroll horizontal.
- `App.tsx`: `<main>` full-width/full-height condicional por rota (`/` e `/necessidade-compra`), conforme seção 1.
- Estender `NecessidadeCompraDetalhe.tsx` (ou criar painel irmão) para listar os pedidos de compra abertos daquele produto (número, status traduzido, empresa, data prevista), ao lado do que já existe (projetos com entrega futura).
- Manter todo o restante do fluxo existente (seleção para pedido em lote, modais de registrar compra) sem alterações de contrato — só aditivo.

### Regra de negócio confirmada (reforça `supabase/db/domains/estoque_compras.md`)

A tela continua agregada por produto (não por cliente/projeto/pedido) — as novas colunas resumem dados de N pedidos numa única linha, sem transformar a granularidade da view. Documentar essa decisão P-04 (produto sai da lista quando "Pendente" chega a zero) no domínio ao final da implementação.
