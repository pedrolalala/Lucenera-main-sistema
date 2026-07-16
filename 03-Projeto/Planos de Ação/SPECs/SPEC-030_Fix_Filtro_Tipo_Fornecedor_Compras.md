---
titulo: "SPEC-030 — Fix filtro tipo fornecedor + Pedido em Lote por Fornecedor + Busca Fuzzy (compras)"
status: pendente
data_ultima_modificacao: 2026-07-16
sistemas_envolvidos:
  - compras-lucenera-3o23t98ee
---

# SPEC-030 — Fix filtro tipo fornecedor + Pedido em Lote por Fornecedor + Busca Fuzzy (compras)

Esta SPEC tem duas partes. A **Parte 1** (abaixo) é o fix original, já implementado e aguardando só teste manual/publish. A **Parte 2** (mais abaixo, seção "Parte 2") é uma expansão de escopo pedida por Pedro em 2026-07-16: consolidar Necessidade de Compra por fornecedor, criar um fluxo de "Pedido em Lote" e tornar a busca de fornecedor tolerante a erro de digitação. A Parte 2 já está **implementada em código** (migrations em rascunho + frontend, ver "Realizado (Parte 2)") — falta aplicar as migrations no Supabase real, fazer o backfill de `marcas.fornecedor_id`, testar manualmente e publicar (ver "Passos manuais do usuário (Parte 2)").

## Parte 1 — Fix filtro de tipo (já implementado)

### Checklist de Ação

- [x] Diagnosticar a causa raiz em `services/pedido-compra.ts`
- [x] Corrigir `getFornecedores()` em `04-Sistemas/compras-lucenera-3o23t98ee/src/services/pedido-compra.ts` para filtrar por tipo `fornecedor` via `contato_tipos`
- [x] Remover a função duplicada `getFornecedores()` em `services/compras.ts` (código morto, não importado por nenhuma tela) e o mock associado (`mockFornecedores`, `FornecedorOption`)
- [x] Rodar `oxlint`/`oxfmt` e `vite build` do sistema após a correção — todos limpos (único warning pré-existente em `Cotacoes.tsx`, não relacionado)
- [x] Commit + push do fix em `compras-lucenera-3o23t98ee` (`55fd80e`) e atualização do ponteiro do submodule no repo central (`6ca80f2`)
- [x] Revisão final pelo agente `revisor` no commit pushado — sem achado crítico/aviso, lint/build limpos
- [x] ~~Publicar a mudança no Skip via MCP~~ — **abandonado por decisão de Pedro em 2026-07-16**: o MCP do Skip apresentou bug/instabilidade de autenticação nesta sessão (servidor ficou preso em "Needs authentication" mesmo após `claude mcp add` + tentativa de reconexão via `/mcp reconnect skip`). Pedro decidiu não depender do MCP — o código já está commitado e pushado no GitHub (`d1a2a7e`), e a sincronização/publicação no Skip será feita por ele diretamente pela plataforma Skip.
- [ ] Testar manualmente: abrir "Registrar Pedido de Compra" e confirmar que só aparecem contatos com tipo `fornecedor`

### Passos manuais do usuário

- [ ] Pedro sincroniza/publica o app diretamente pela plataforma Skip (decisão de 2026-07-16 — não depender mais do MCP nesta máquina para publish)
- [ ] Pedro testa no navegador (golden path) **depois de publicado**: abrir modal de Registrar Pedido de Compra, buscar por um nome que hoje aparece errado (ex. um arquiteto/cliente conhecido) e confirmar que não aparece mais na lista
- [ ] Pedro confirma se algum contato que É fornecedor mas nunca teve `contato_tipos.tipo = 'fornecedor'` gravado precisa de backfill manual (ver Pendências)

### Objetivo

O campo "Marca / Fornecedor" no modal de registrar pedido de compra (`ModalRegistrarCompra.tsx`, sistema `compras-lucenera`) está retornando contatos de qualquer tipo (arquitetos, clientes) em vez de apenas fornecedores, porque a query que alimenta esse autocomplete busca em `contatos` sem filtrar pelo tipo do contato.

### Decisões aprovadas

- A fonte de verdade para "este contato é fornecedor" é a tabela de junção `contato_tipos` (par `contato_id` + `tipo`, `tipo` restrito a `cliente|arquiteto|engenheiro|fornecedor|funcionario|outro`), **não** apenas a coluna única `contatos.tipo`. Um contato pode ter mais de um tipo ao longo do tempo (ex.: virou cliente depois de já ter sido fornecedor), e `contatos.tipo` reflete só a classificação mais recente aplicada pelo trigger `handle_contato_tipo()`. Buscar em `contato_tipos` é a forma correta de não perder fornecedores cuja `contatos.tipo` atual foi sobrescrito para outra coisa.
- Correção fica isolada em `compras-lucenera-3o23t98ee` — é o único sistema com esse ponto de busca de fornecedor incorreto.
- Não altera schema nem cria migration — é puramente um filtro ausente no frontend, não um problema de dado ou de banco.

### Definição da SPEC

#### Causa raiz

`services/pedido-compra.ts:42-48`, função usada por `ModalRegistrarCompra.tsx` (o campo "Marca / Fornecedor" do formulário de Registrar Pedido de Compra):

```ts
export async function getFornecedores(search?: string): Promise<Fornecedor[]> {
  let query = (supabase as any).from('contatos').select('id, nome').eq('ativo', true)
  if (search && search.trim()) query = query.ilike('nome', `%${search.trim()}%`)
  const { data, error } = await query.order('nome').limit(50)
  if (error) throw error
  return (data ?? []) as Fornecedor[]
}
```

Não há nenhum filtro por tipo de contato — qualquer `contato` ativo (arquiteto, cliente, engenheiro etc.) aparece na busca de fornecedor.

Existe uma segunda função com o mesmo nome e o mesmo bug em `services/compras.ts:223-231`, mas ela **não é importada por nenhuma tela** (confirmado via busca de `services/compras'` em todo o `src/` — nenhum resultado). É código morto do mesmo problema, não a causa do bug relatado.

#### Correção proposta

Filtrar por `contato_tipos.tipo = 'fornecedor'` via inner join, usando o relacionamento já existente (`contato_tipos.contato_id -> contatos.id`, ver `supabase/db/current/01_schema_full.sql` linha ~4479):

```ts
export async function getFornecedores(search?: string): Promise<Fornecedor[]> {
  let query = (supabase as any)
    .from('contatos')
    .select('id, nome, contato_tipos!inner(tipo)')
    .eq('ativo', true)
    .eq('contato_tipos.tipo', 'fornecedor')
  if (search && search.trim()) query = query.ilike('nome', `%${search.trim()}%`)
  const { data, error } = await query.order('nome').limit(50)
  if (error) throw error
  return (data ?? []).map((d: any) => ({ id: d.id, nome: d.nome })) as Fornecedor[]
}
```

A função duplicada em `services/compras.ts` deve ser removida (é código morto) em vez de corrigida, para não manter duas implementações divergentes do mesmo conceito.

#### Critério de aceite

- Buscar no campo "Marca / Fornecedor" não retorna mais contatos cujo único tipo registrado seja `cliente`, `arquiteto`, `engenheiro` ou `funcionario`.
- Um contato que tenha tanto `fornecedor` quanto outro tipo em `contato_tipos` continua aparecendo (comportamento correto — ele é fornecedor também).
- Lint (`oxlint`/`oxfmt`) e `vite build` passam sem novo erro.

### Realizado (Parte 1)

#### 2026-07-16

- Diagnóstico completo: causa raiz identificada em `services/pedido-compra.ts` (função ativa) e código morto duplicado identificado em `services/compras.ts`.
- Implementado: `getFornecedores()` em `pedido-compra.ts` agora filtra por `contato_tipos!inner(tipo)` + `.eq('contato_tipos.tipo', 'fornecedor')`; removidos `getFornecedores()`/`FornecedorOption` (código morto) de `compras.ts` e `mockFornecedores` de `compras-mock.ts`.
- Revisado: sem achado crítico/aviso. Único ponto de atenção (info) — `ModalRegistrarCompra.tsx` engole erro de busca silenciosamente (comportamento pré-existente); recomendo testar com console do navegador aberto.
- Verificado: `oxlint` limpo, `vite build` limpo, `oxfmt` sem alterações além do diff pretendido.
- Descoberto durante teste do Pedro no app publicado pelo Skip: o bug ainda aparecia porque o fix nunca foi publicado (só existia local, sem commit/push, e o MCP do Skip não estava conectado nesta sessão para acionar o build). Documentado o fluxo de conexão do MCP do Skip em `.claude/agents/revisor.md` — a partir de agora, publicar via Skip é parte do gate do agente `revisor`, depois da revisão fechar sem crítico.
- 2026-07-16 (sessão seguinte): commit `55fd80e` (compras-lucenera) + push para o GitHub; ponteiro do submodule atualizado no repo central (`6ca80f2`). Agente `revisor` confirmou que o diff pushado bate exatamente com o descrito acima, sem achado crítico/aviso, lint/build limpos. Publicação via Skip **ainda não ocorreu**: o servidor MCP `skip` está registrado nesta máquina mas com status "Needs authentication" (falta concluir OAuth) — nenhuma ferramenta `mcp__skip__*` ficou disponível para o `revisor` chamar. Ver Pendências.

### Pendências (Parte 1)

- [ ] Confirmar com Pedro/Filippo se existem fornecedores reais no banco que **nunca** tiveram `contato_tipos.tipo = 'fornecedor'` gravado (ex.: cadastrados antes do trigger `handle_contato_tipo()` existir, ou só com `contatos.tipo` preenchido sem o backfill correspondente na tabela de junção) — se existirem, precisam de um `INSERT` de backfill em `contato_tipos`, o que é uma decisão de dado, não algo que este fix de frontend resolve sozinho.
- [x] ~~Completar autenticação OAuth do MCP `skip`~~ — abandonado (ver Checklist acima); Pedro publica direto pela plataforma Skip.

---

## Parte 2 — Pedido em Lote por Fornecedor + Busca Fuzzy (planejamento, não implementado)

### Checklist de Ação (Parte 2)

- [ ] Reextrair o snapshot `supabase/db/current/` (está desatualizado desde 2026-07-07 — não reflete `pedidos_compra`, `pedido_compra_itens`, `produto_fornecedores`, `produtos.fornecedor_principal_id`/`marca_id` nem as reescritas de `vw_necessidade_compra*`). Pode rodar em paralelo, não bloqueia o resto. **Não feito nesta sessão** (fora do escopo de implementação de código; requer acesso ao Supabase real, que o agente implementador não aciona).
- [x] Migration (rascunho, não aplicada): `ALTER TABLE marcas ADD COLUMN fornecedor_id uuid REFERENCES contatos(id)` — vínculo explícito marca -> fornecedor (novo, não existe hoje).
- [x] Migration (rascunho, não aplicada): estende `vw_necessidade_compra` (mesmo nome, `CREATE OR REPLACE VIEW`) com `marca_id`, `marca_nome`, `fornecedor_id` e `fornecedor_nome`, via `LEFT JOIN produtos.marca_id -> marcas` + `COALESCE(produtos.fornecedor_principal_id, marcas.fornecedor_id)` resolvido para nome via `contatos`. Base usada foi a versão real e mais recente da view (migration `20260713_036`, que já inclui `preco_custo` — não a versão desatualizada de `db/current/05_views.sql`).
- [x] Migration (rascunho, não aplicada): nova RPC `criar_pedido_compra_lote` recebendo `fornecedor_id` único + array de itens (`produto_id, quantidade, custo_unitario`), criando 1 `pedidos_compra` + N `solicitacoes_compra` + N `pedido_compra_itens` numa transação — generalização da RPC singular `criar_pedido_compra_de_necessidade` (`20260710_032`).
- [x] Migration (rascunho, não aplicada): novo índice `idx_contatos_nome_unaccent_trgm` (`gin (unaccent(lower(nome)) extensions.gin_trgm_ops)`) em `contatos`.
- [x] Frontend: corrigido `getFornecedores()` (`services/pedido-compra.ts`) para busca fuzzy via nova RPC auxiliar `buscar_fornecedores_fuzzy` (`similarity(unaccent(lower(nome)), unaccent(lower($termo))) > 0.3`), mantendo o filtro `contato_tipos.tipo = 'fornecedor'` já corrigido na Parte 1.
- [x] Frontend: `NecessidadeCompra.tsx` — adicionado filtro "Marca" (dropdown derivado de `rows`), coluna "Marca" na tabela e seleção múltipla (checkbox) de linhas restrita a um único fornecedor resolvido por vez.
- [x] Frontend: modal "Pedido em Lote" (`components/compra/ModalPedidoLote.tsx`) — lista os itens selecionados, quantidade/custo editável por linha, um único número de pedido, chama a nova RPC `criar_pedido_compra_lote` via `services/pedido-compra.ts`.
- [x] Rodado `oxlint`/`oxfmt`/`vite build` do sistema após a implementação — ver Realizado (Parte 2).
- [ ] Testar manualmente e publicar via Skip (mesmo gate da Parte 1) — pendente do usuário (ver Passos manuais).

### Passos manuais do usuário (Parte 2)

- [ ] Aplicar as 5 migrations em `supabase/db/migrations/20260716_049_spec030_pedido_lote_marca_fornecedor/` no Supabase real (na ordem `001` a `005`) — este agente redige `.sql`, nunca aplica.
- [ ] Fazer o backfill de `marcas.fornecedor_id` (mapear cada marca cadastrada ao fornecedor/contato correspondente) — sem isso, nenhum item aparece selecionável para Pedido em Lote na tela.
- [ ] Reextrair o snapshot `supabase/db/current/` depois de aplicar as migrations, para não deixar o próximo agente consultando um schema desatualizado.
- [ ] Testar manualmente no navegador (golden path): filtrar Necessidade de Compra por uma marca com fornecedor já mapeado, marcar 2+ itens, abrir "Fechar pedido em lote", editar quantidade/custo e confirmar — checar que 1 `pedidos_compra` + N `pedido_compra_itens` foram criados. Testar também o caso de bloqueio (tentar marcar item de fornecedor diferente) e a busca fuzzy de fornecedor (digitar nome com erro de digitação/sem acento).
- [ ] Pedro publica direto pela plataforma Skip (não mais via MCP — ver decisão na Parte 1) e repete o teste no app publicado.

### Objetivo (Parte 2)

Hoje o registro de pedido de compra é 1 produto + 1 fornecedor por chamada (RPC `criar_pedido_compra_de_necessidade`), forçando o usuário a repetir o modal manualmente para cada item quando quer fechar várias compras de uma vez (ex.: todos os produtos da marca Stella). Além disso, a busca de fornecedor (`getFornecedores`) usa `ilike` puro e não tolera erro de digitação/variação de nome. Esta parte da SPEC cobre: (1) consolidar/filtrar a Necessidade de Compra por **marca** (não por fornecedor direto — ver Decisões), (2) criar um fluxo de "Pedido em Lote" que gera um único pedido por fornecedor com múltiplos itens numa só operação, e (3) tornar a busca de fornecedor tolerante a typo/variação via `pg_trgm` + `unaccent`.

### Decisões aprovadas (Parte 2)

- **Filtro principal passa a ser por Marca, não por fornecedor direto** (mudança de decisão em 2026-07-16, a pedido de Pedro): a tela filtra por `produtos.marca_id -> marcas.nome` — é o relacionamento que já existe e já é exibido/buscável hoje em `vw_estoque_produtos`. Pedro confirmou que, na prática, **marca equivale a fornecedor** (ex.: marca Stella = fornecedor Stella).
- **Vínculo marca -> fornecedor real (novo)**: hoje `public.marcas` não tem nenhuma coluna ligando a um fornecedor/contato — só `id, nome, ativo, created_at, codigo_legado`. Para o Pedido em Lote precisar de um `fornecedor_id` real (a tabela `pedidos_compra.fornecedor_id` é `NOT NULL REFERENCES contatos(id)`), é necessária uma migration nova: `ALTER TABLE marcas ADD COLUMN fornecedor_id uuid REFERENCES contatos(id)`. Casar por nome (`contatos.nome` = `marcas.nome`) não é confiável (é exatamente o tipo de inconsistência de nome que a Parte 1 desta SPEC já teve que corrigir) — precisa ser um FK explícito, preenchido manualmente por Pedro/Filippo (ver Pendências).
- **Resolução do fornecedor de um produto passa a ser em cascata**, seguindo o mesmo padrão já usado em `produtos.prazo_entrega_dias`/`marcas.prazo_entrega_dias` (SPEC-026: produto sobrescreve, marca é o fallback): `COALESCE(produtos.fornecedor_principal_id, marcas.fornecedor_id)` — um produto pode ter um fornecedor específico diferente do fornecedor padrão da marca (exceção), mas na maioria dos casos herda da marca. `produtos.fornecedor_principal_id` continua existindo e sendo validado como `contato_tipos.tipo = 'fornecedor'`, só deixa de ser a única fonte.
- **Modelo do lote**: 1 pedido = 1 fornecedor, fixo. O comprador filtra a Necessidade de Compra por um fornecedor, seleciona os itens daquele fornecedor e fecha 1 pedido. Não haverá split automático de seleção multi-fornecedor em sub-pedidos nesta versão.
- **Produto sem fornecedor cadastrado**: fica **fora do lote**. É pré-requisito ter `fornecedor_principal_id` preenchido para o item entrar em um Pedido em Lote — sem fornecedor cadastrado, a compra desse item continua pelo fluxo atual (1 produto por vez, escolhendo o fornecedor manualmente no modal).
- Extensões `pg_trgm` e `unaccent` já estão habilitadas no banco (evidência: índice `idx_contatos_nome_trgm` e uso de `unaccent()` em `fn_sync_equipe_por_responsavel()`) — não é necessário `CREATE EXTENSION`, só o novo índice expression e a nova query.

### Definição da SPEC (Parte 2)

#### Tabelas e views envolvidas

- `public.pedidos_compra` (`supabase/db/migrations/20260710_031_spec020_operacionalizacao_compras/004_pedidos_compra.sql`): `fornecedor_id uuid NOT NULL REFERENCES contatos(id)`, `numero`, `status`, `valor_total`. Já modela "1 pedido = 1 fornecedor" — não precisa de alteração de schema.
- `public.pedido_compra_itens`: `pedido_id, solicitacao_id, produto_id, quantidade, custo_unitario, qtd_recebida`. Já suporta N linhas por `pedido_id` — não precisa de alteração de schema.
- `public.produtos.fornecedor_principal_id` (FK `contatos.id`, `01_schema_full.sql:11312`) e `public.produtos.marca_id` (FK `marcas.id`, `01_schema_full.sql:11320`) — as duas pontas da resolução em cascata (ver Decisões).
- `public.marcas` (`01_schema_full.sql:5218`): hoje só `id, nome, ativo, created_at, codigo_legado`. Precisa da coluna nova `fornecedor_id` (ver Decisões e Checklist).
- `vw_necessidade_compra` (definição real e atual em `supabase/db/migrations/20260713_035_fix_necessidade_compra_fonte_estoque_itens/001_fix_vw_necessidade_compra.sql`, não a de `05_views.sql` que está desatualizada): hoje não tem coluna de marca nem de fornecedor — precisa do `LEFT JOIN` novo com `produtos.marca_id -> marcas` e `COALESCE(produtos.fornecedor_principal_id, marcas.fornecedor_id)`.
- `vw_necessidade_compra_detalhe` (`20260715_043_necessidade_compra_dias_em_aberto/001_dias_em_aberto.sql`, SPEC-022/026): agrupa por projeto/cliente, não por fornecedor — não é a base certa para o agrupamento por fornecedor, mas pode ganhar a mesma coluna de fornecedor por consistência.
- `criar_pedido_compra_de_necessidade` (`20260710_032_spec021_registrar_pedido_compra/001_rpc_criar_pedido.sql`): RPC singular existente, modelo de referência para a nova RPC em lote — mesma lógica transacional, generalizada para array de itens.
- `contato_tipos` (`tipo = 'fornecedor'`): continua a fonte de verdade de "quem é fornecedor", já usada na Parte 1.

#### Fluxo proposto

1. `NecessidadeCompra.tsx` passa a exibir a coluna "Marca" e um filtro (dropdown) por marca, vindos do novo join com `produtos.marca_id -> marcas.nome`.
2. O comprador filtra por uma marca (ex.: Stella), vê só os itens em déficit daquela marca.
3. Seleção múltipla (checkbox) das linhas desejadas — todas da mesma marca, pela própria natureza do filtro.
4. Botão "Fechar pedido em lote" abre um modal listando os itens selecionados, com quantidade/custo editável por linha e um único número de pedido. O fornecedor do pedido é resolvido automaticamente por `COALESCE(produtos.fornecedor_principal_id, marcas.fornecedor_id)` — se os itens selecionados resolverem para fornecedores diferentes (produto com override específico divergente do fornecedor da marca), a UI deve avisar em vez de gerar um pedido com fornecedor errado (ver Critério de aceite).
5. Confirmar chama a nova RPC `criar_pedido_compra_lote`, que cria 1 `pedidos_compra` + N `solicitacoes_compra` + N `pedido_compra_itens` numa transação.
6. Itens cuja marca não tem `fornecedor_id` preenchido (e que também não têm `fornecedor_principal_id` próprio) não aparecem como selecionáveis para lote (ver Decisões) — continuam compráveis individualmente pelo fluxo atual, escolhendo o fornecedor manualmente no modal.

#### Requisitos técnicos de busca (fuzzy/tolerante a erro de digitação)

- Extensões `pg_trgm` e `unaccent` já habilitadas — não precisa `CREATE EXTENSION`.
- Novo índice expression (não existe hoje): `CREATE INDEX idx_contatos_nome_unaccent_trgm ON contatos USING gin (unaccent(lower(nome)) gin_trgm_ops);`
- Query fuzzy sugerida em `getFornecedores()`: filtrar por `similarity(unaccent(lower(nome)), unaccent(lower($termo))) > 0.3` (threshold inicial 0.3, ajustável depois de testar com nomes reais de fornecedores), combinado com o filtro já existente `contato_tipos.tipo = 'fornecedor'`.
- Escopo da busca nesta versão: só `contatos.nome`. Não inclui `nome_empresa` — se um fornecedor for cadastrado com nome de pessoa diferente do nome fantasia da empresa, a busca por um não encontra pelo outro; ver Pendências.

### Critério de aceite (Parte 2)

- Filtrar a Necessidade de Compra por uma marca mostra só os itens cujo `produtos.marca_id` aponta para aquela marca.
- Selecionar N itens da mesma marca e confirmar "Pedido em Lote" cria exatamente 1 `pedidos_compra` (com `fornecedor_id` resolvido via `COALESCE(produtos.fornecedor_principal_id, marcas.fornecedor_id)`) com N `pedido_compra_itens`, em uma única transação (tudo ou nada).
- Se os itens selecionados resolverem para mais de um fornecedor diferente (produto com override específico), a UI bloqueia o fechamento do lote com um aviso claro em vez de silenciosamente escolher um dos dois.
- Itens cuja marca (e produto) não têm fornecedor resolvido não podem ser incluídos em um pedido em lote.
- Buscar "Stela" encontra fornecedores cadastrados como "Stella" (e variações de acento/caixa), respeitando o filtro de `contato_tipos.tipo = 'fornecedor'` já existente.
- Lint e `vite build` passam sem novo erro.

### Pendências (Parte 2)

- [ ] **Backfill de `marcas.fornecedor_id`**: é uma decisão de dado, não de código — Pedro/Filippo precisam mapear qual fornecedor (contato) corresponde a cada marca já cadastrada. Sem isso preenchido, nenhum item fica selecionável para Pedido em Lote.
- [ ] Definir o threshold de `similarity()` com dados reais de fornecedores (0.3 é ponto de partida, não validado com nomes reais).
- [ ] Decidir se a busca fuzzy deve considerar também `nome_empresa` (nome fantasia), não só `nome` — hoje o rascunho cobre só `nome`.
- [ ] Reextrair `supabase/db/current/` (desatualizado desde 2026-07-07) — não bloqueia esta SPEC, mas deve ser feito para não confundir o próximo agente que consultar o snapshot em vez das migrations reais.
- [x] **"Cabeçalho duplicado" — causa raiz confirmada, já corrigida em código, só falta publicar.** Pedro mandou print do app publicado mostrando a barra de navegação (Necessidade de Compra / Estoque / Solicitações / Cotações / Pedidos / Recebimento) duplicada. Investigação: no commit atualmente publicado no Skip (`fc3b3c7`, ver `.skip.config.json` do sistema), `src/App.tsx` renderizava `<AppNav />` diretamente dentro de `AppShell` **além** de `ProtectedRoute` também renderizar `<AppNav />` — daí a barra aparecer duas vezes. Essa duplicação **já não existe no HEAD atual** (commit `d1a2a7e`, pushado): `App.tsx` só renderiza `<AppHeader />` em `AppShell`, e `AppNav` é renderizado uma única vez, dentro de `ProtectedRoute`. Ou seja, o print de Pedro reflete uma versão do app anterior até ao fix original da Parte 1 desta SPEC — nunca foi um bug pendente de investigação, só nunca foi publicado. Resolve junto com a publicação pendente (ver Passos manuais).

### Realizado (Parte 2)

#### 2026-07-16

- **Migrations (rascunho, `supabase/db/migrations/20260716_049_spec030_pedido_lote_marca_fornecedor/`, NÃO aplicadas no Supabase real)**:
  - `001_marcas_fornecedor_id.sql`: `ALTER TABLE marcas ADD COLUMN IF NOT EXISTS fornecedor_id uuid REFERENCES contatos(id)` (nullable, com índice) + comentário deixando explícito que o backfill é manual/futuro.
  - `002_vw_necessidade_compra_marca_fornecedor.sql`: `CREATE OR REPLACE VIEW vw_necessidade_compra` com `marca_id`, `marca_nome`, `fornecedor_id`, `fornecedor_nome` adicionados via `LEFT JOIN marcas` + `LEFT JOIN contatos` sobre `COALESCE(produtos.fornecedor_principal_id, marcas.fornecedor_id)`. Base real usada: a definição da migration `20260713_036` (última a reescrever a view, inclui `preco_custo`), não a de `20260713_035` nem a desatualizada de `db/current/05_views.sql` — todas as colunas pré-existentes (SPEC-013/022/026/036) foram preservadas, `security_invoker = true` e `GRANT SELECT` mantidos.
  - `003_rpc_criar_pedido_compra_lote.sql`: nova RPC `criar_pedido_compra_lote(p_fornecedor_id uuid, p_itens jsonb, p_numero text, p_data_prevista_entrega date, p_condicoes_pagamento text, p_observacao text)`, generalização transacional de `criar_pedido_compra_de_necessidade` (`20260710_032`). Valida cabeçalho e cada item do array **antes** de criar qualquer registro; cria 1 `pedidos_compra` (status `enviado`, mesmo status inicial da RPC singular) + N `solicitacoes_compra` (`pedido_gerado`) + N `pedido_compra_itens`. Nenhuma exceção é capturada — qualquer erro reverte a transação inteira (comportamento padrão de função plpgsql).
  - `004_idx_contatos_nome_unaccent_trgm.sql`: índice `gin (unaccent(lower(nome)) extensions.gin_trgm_ops)` em `contatos` — o op class foi qualificado com o schema `extensions` (em vez do `gin_trgm_ops` sem schema sugerido no plano) para bater com o padrão já usado por `idx_contatos_nome_trgm` no banco real, evidência de que a extensão `pg_trgm` está instalada nesse schema.
  - `005_rpc_buscar_fornecedores_fuzzy.sql`: RPC auxiliar `buscar_fornecedores_fuzzy(p_termo text)` (`SECURITY INVOKER`, `SET search_path = public, extensions`) — necessária porque supabase-js não expõe `similarity()` em `.from().select()`. Sem termo, mantém o comportamento anterior (lista completa de fornecedores ativos, ordenada por nome); com termo, filtra por `similarity(unaccent(lower(nome)), unaccent(lower($termo))) > 0.3` e ordena por similaridade desc.
- **Frontend (`04-Sistemas/compras-lucenera-3o23t98ee/src`)**:
  - `services/pedido-compra.ts`: `getFornecedores()` agora chama `buscar_fornecedores_fuzzy` via `.rpc()` em vez de `ilike`; adicionados `ItemPedidoLote`, `CriarPedidoLoteInput`, `CriarPedidoLoteResult` e `criarPedidoCompraLote()`.
  - `services/necessidade-compra.ts`: `NecessidadeCompraRow` estendido com `marca_id`, `marca_nome`, `fornecedor_id`, `fornecedor_nome` (a função `getNecessidadeCompra` já usava `select('*')`, então nenhuma outra mudança de query foi necessária).
  - `pages/NecessidadeCompra.tsx`: adicionado filtro "Marca" (dropdown derivado de `rows`, sem query separada), coluna "Marca" na tabela, checkbox de seleção por linha (desabilitado quando `fornecedor_id` é nulo, com `title` explicando o motivo) e botão "Fechar pedido em lote" (aparece só quando há seleção). `toggleSelect()` bloqueia com toast destrutivo se o item selecionado resolver para um `fornecedor_id` diferente do já selecionado.
  - `components/compra/ModalPedidoLote.tsx` (novo, seguindo o padrão visual/estrutural de `ModalRegistrarCompra.tsx`): lista os itens selecionados com quantidade/custo unitário editáveis por linha (pré-preenchidos com `necessidade_compra`/`preco_custo`), um único número de pedido, e chama `criarPedidoCompraLote`.
- **Escolhas técnicas dentro do espaço já aprovado pela SPEC** (para confirmar com Pedro se necessário):
  - Formato do array de itens da RPC: `jsonb` (array de `{produto_id, quantidade, custo_unitario}`), conforme sugerido na SPEC como opção mais simples — não foi criado tipo composto novo no schema.
  - Foi necessária, sim, uma RPC auxiliar (`buscar_fornecedores_fuzzy`) para a busca fuzzy, pelo motivo já explicado (supabase-js não expõe `similarity()`).
  - O op class do índice fuzzy foi qualificado como `extensions.gin_trgm_ops` (em vez de `gin_trgm_ops` puro) para seguir o padrão já existente no banco.
- **Verificado**: `oxlint src` limpo (único warning é o pré-existente em `Cotacoes.tsx`, não relacionado); `vite build` limpo (únicos avisos são pré-existentes: classe Tailwind ambígua `duration-[800ms]` e aviso de chunk >500kB, ambos não relacionados a esta mudança); `oxfmt --check` reporta "Format issues" em ~113 arquivos do projeto, mas isso já ocorre **antes** desta mudança (confirmado via `git stash` — é uma condição pré-existente do repositório, provavelmente ligada a diferença de terminador de linha CRLF/LF no checkout Windows, não introduzida por esta implementação).
- **Não feito nesta sessão** (fora do escopo de um agente implementador, ou dependente de decisão/dado do usuário): reextração do snapshot `supabase/db/current/`; aplicação real da migration no Supabase; backfill de `marcas.fornecedor_id`; teste manual no navegador; publicação via Skip.
