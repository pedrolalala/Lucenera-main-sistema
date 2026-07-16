---
titulo: "SPEC-030 — Fix filtro tipo fornecedor + Pedido em Lote por Fornecedor + Busca Fuzzy (compras)"
status: pendente
data_ultima_modificacao: 2026-07-16
sistemas_envolvidos:
  - compras-lucenera-3o23t98ee
---

# SPEC-030 — Fix filtro tipo fornecedor + Pedido em Lote por Fornecedor + Busca Fuzzy (compras)

Esta SPEC tem duas partes. A **Parte 1** (abaixo) é o fix original, já implementado e aguardando só teste manual/publish. A **Parte 2** (mais abaixo, seção "Parte 2") é uma expansão de escopo pedida por Pedro em 2026-07-16: consolidar Necessidade de Compra por fornecedor, criar um fluxo de "Pedido em Lote" e tornar a busca de fornecedor tolerante a erro de digitação. A Parte 2 ainda **não foi implementada** — é só planejamento nesta etapa.

## Parte 1 — Fix filtro de tipo (já implementado)

### Checklist de Ação

- [x] Diagnosticar a causa raiz em `services/pedido-compra.ts`
- [x] Corrigir `getFornecedores()` em `04-Sistemas/compras-lucenera-3o23t98ee/src/services/pedido-compra.ts` para filtrar por tipo `fornecedor` via `contato_tipos`
- [x] Remover a função duplicada `getFornecedores()` em `services/compras.ts` (código morto, não importado por nenhuma tela) e o mock associado (`mockFornecedores`, `FornecedorOption`)
- [x] Rodar `oxlint`/`oxfmt` e `vite build` do sistema após a correção — todos limpos (único warning pré-existente em `Cotacoes.tsx`, não relacionado)
- [x] Commit + push do fix em `compras-lucenera-3o23t98ee` (`55fd80e`) e atualização do ponteiro do submodule no repo central (`6ca80f2`)
- [x] Revisão final pelo agente `revisor` no commit pushado — sem achado crítico/aviso, lint/build limpos
- [ ] Publicar a mudança no Skip (MCP do Skip) — **bloqueado**: o servidor MCP `skip` (`claude mcp add --transport http skip ...`) está registrado mas com status "Needs authentication"; falta completar o OAuth. Sem isso, nenhuma ferramenta `mcp__skip__*` fica disponível para publicar.
- [ ] Testar manualmente: abrir "Registrar Pedido de Compra" e confirmar que só aparecem contatos com tipo `fornecedor`

### Passos manuais do usuário

- [ ] Completar a autenticação do MCP do Skip nesta máquina — o servidor já está registrado (`claude mcp add --transport http skip https://api.goskip.dev/mcp` já rodou), mas falta concluir o fluxo OAuth (normalmente abre o navegador) e reiniciar a sessão do Claude Code para as ferramentas `mcp__skip__*` ficarem disponíveis
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
- [ ] Completar autenticação OAuth do MCP `skip` (registrado, mas "Needs authentication") e então publicar esta correção no Skip, e só então repetir o teste manual no app publicado.

---

## Parte 2 — Pedido em Lote por Fornecedor + Busca Fuzzy (planejamento, não implementado)

### Checklist de Ação (Parte 2)

- [ ] Reextrair o snapshot `supabase/db/current/` (está desatualizado desde 2026-07-07 — não reflete `pedidos_compra`, `pedido_compra_itens`, `produto_fornecedores`, `produtos.fornecedor_principal_id`/`marca_id` nem as reescritas de `vw_necessidade_compra*`). Pode rodar em paralelo, não bloqueia o resto.
- [ ] Migration: estender `vw_necessidade_compra` (ou criar `vw_necessidade_compra_fornecedor`) com `fornecedor_id` e `fornecedor_nome`, via `LEFT JOIN produtos.fornecedor_principal_id -> contatos.id`.
- [ ] Migration: nova RPC `criar_pedido_compra_lote` recebendo `fornecedor_id` único + array de itens (`produto_id, quantidade, custo_unitario`), criando 1 `pedidos_compra` + N `solicitacoes_compra` + N `pedido_compra_itens` numa transação — generalização da RPC singular `criar_pedido_compra_de_necessidade` (`20260710_032`).
- [ ] Migration: novo índice `idx_contatos_nome_unaccent_trgm` (`gin (unaccent(lower(nome)) gin_trgm_ops)`) em `contatos`.
- [ ] Frontend: corrigir `getFornecedores()` (`services/pedido-compra.ts`) para busca fuzzy — `similarity(unaccent(lower(nome)), unaccent(lower($termo))) > 0.3`, mantendo o filtro `contato_tipos.tipo = 'fornecedor'` já corrigido na Parte 1.
- [ ] Frontend: `NecessidadeCompra.tsx` — adicionar coluna/filtro "Fornecedor" e seleção múltipla de linhas restrita a um único fornecedor por vez.
- [ ] Frontend: modal "Pedido em Lote" — lista os itens selecionados do fornecedor filtrado, quantidade/custo editável por linha, um único número de pedido, chama a nova RPC.
- [ ] Rodar `oxlint`/`oxfmt`/`vite build` do sistema após a implementação.
- [ ] Testar manualmente e publicar via Skip (mesmo gate da Parte 1).

### Objetivo (Parte 2)

Hoje o registro de pedido de compra é 1 produto + 1 fornecedor por chamada (RPC `criar_pedido_compra_de_necessidade`), forçando o usuário a repetir o modal manualmente para cada item quando quer fechar várias compras do mesmo fornecedor de uma vez (ex.: todos os produtos da Stella). Além disso, a busca de fornecedor (`getFornecedores`) usa `ilike` puro e não tolera erro de digitação/variação de nome. Esta parte da SPEC cobre: (1) consolidar/filtrar a Necessidade de Compra por fornecedor, (2) criar um fluxo de "Pedido em Lote" que gera um único pedido por fornecedor com múltiplos itens numa só operação, e (3) tornar a busca de fornecedor tolerante a typo/variação via `pg_trgm` + `unaccent`.

### Decisões aprovadas (Parte 2)

- **Fonte do fornecedor por produto**: `produtos.fornecedor_principal_id` (FK para `contatos.id`) — 1 fornecedor principal por produto, campo que já existe hoje. Não usar `produto_fornecedores` (que suporta múltiplos fornecedores por produto) nesta primeira versão, para manter a view e o fluxo simples. O contato apontado por `fornecedor_principal_id` deve continuar validado como `contato_tipos.tipo = 'fornecedor'` — mesma fonte de verdade já estabelecida na Parte 1 desta SPEC.
- **Modelo do lote**: 1 pedido = 1 fornecedor, fixo. O comprador filtra a Necessidade de Compra por um fornecedor, seleciona os itens daquele fornecedor e fecha 1 pedido. Não haverá split automático de seleção multi-fornecedor em sub-pedidos nesta versão.
- **Produto sem fornecedor cadastrado**: fica **fora do lote**. É pré-requisito ter `fornecedor_principal_id` preenchido para o item entrar em um Pedido em Lote — sem fornecedor cadastrado, a compra desse item continua pelo fluxo atual (1 produto por vez, escolhendo o fornecedor manualmente no modal).
- Extensões `pg_trgm` e `unaccent` já estão habilitadas no banco (evidência: índice `idx_contatos_nome_trgm` e uso de `unaccent()` em `fn_sync_equipe_por_responsavel()`) — não é necessário `CREATE EXTENSION`, só o novo índice expression e a nova query.

### Definição da SPEC (Parte 2)

#### Tabelas e views envolvidas

- `public.pedidos_compra` (`supabase/db/migrations/20260710_031_spec020_operacionalizacao_compras/004_pedidos_compra.sql`): `fornecedor_id uuid NOT NULL REFERENCES contatos(id)`, `numero`, `status`, `valor_total`. Já modela "1 pedido = 1 fornecedor" — não precisa de alteração de schema.
- `public.pedido_compra_itens`: `pedido_id, solicitacao_id, produto_id, quantidade, custo_unitario, qtd_recebida`. Já suporta N linhas por `pedido_id` — não precisa de alteração de schema.
- `public.produtos.fornecedor_principal_id` (FK `contatos.id`, `01_schema_full.sql:11312`) — fonte do fornecedor por produto (ver Decisões).
- `vw_necessidade_compra` (definição real e atual em `supabase/db/migrations/20260713_035_fix_necessidade_compra_fonte_estoque_itens/001_fix_vw_necessidade_compra.sql`, não a de `05_views.sql` que está desatualizada): hoje não tem coluna de fornecedor — precisa do `LEFT JOIN` novo.
- `vw_necessidade_compra_detalhe` (`20260715_043_necessidade_compra_dias_em_aberto/001_dias_em_aberto.sql`, SPEC-022/026): agrupa por projeto/cliente, não por fornecedor — não é a base certa para o agrupamento por fornecedor, mas pode ganhar a mesma coluna de fornecedor por consistência.
- `criar_pedido_compra_de_necessidade` (`20260710_032_spec021_registrar_pedido_compra/001_rpc_criar_pedido.sql`): RPC singular existente, modelo de referência para a nova RPC em lote — mesma lógica transacional, generalizada para array de itens.
- `contato_tipos` (`tipo = 'fornecedor'`): continua a fonte de verdade de "quem é fornecedor", já usada na Parte 1.

#### Fluxo proposto

1. `NecessidadeCompra.tsx` passa a exibir a coluna "Fornecedor" (vinda do novo join) e um filtro por fornecedor.
2. O comprador filtra por um fornecedor (ex.: Stella), vê só os itens em déficit daquele fornecedor.
3. Seleção múltipla (checkbox) das linhas desejadas — todas do mesmo fornecedor, pela própria natureza do filtro.
4. Botão "Fechar pedido em lote" abre um modal listando os itens selecionados, com quantidade/custo editável por linha e um único número de pedido.
5. Confirmar chama a nova RPC `criar_pedido_compra_lote`, que cria 1 `pedidos_compra` + N `solicitacoes_compra` + N `pedido_compra_itens` numa transação.
6. Itens sem `fornecedor_principal_id` preenchido não aparecem como selecionáveis para lote (ver Decisões) — continuam compráveis individualmente pelo fluxo atual.

#### Requisitos técnicos de busca (fuzzy/tolerante a erro de digitação)

- Extensões `pg_trgm` e `unaccent` já habilitadas — não precisa `CREATE EXTENSION`.
- Novo índice expression (não existe hoje): `CREATE INDEX idx_contatos_nome_unaccent_trgm ON contatos USING gin (unaccent(lower(nome)) gin_trgm_ops);`
- Query fuzzy sugerida em `getFornecedores()`: filtrar por `similarity(unaccent(lower(nome)), unaccent(lower($termo))) > 0.3` (threshold inicial 0.3, ajustável depois de testar com nomes reais de fornecedores), combinado com o filtro já existente `contato_tipos.tipo = 'fornecedor'`.
- Escopo da busca nesta versão: só `contatos.nome`. Não inclui `nome_empresa` — se um fornecedor for cadastrado com nome de pessoa diferente do nome fantasia da empresa, a busca por um não encontra pelo outro; ver Pendências.

### Critério de aceite (Parte 2)

- Filtrar a Necessidade de Compra por um fornecedor mostra só os itens cujo `fornecedor_principal_id` aponta para aquele fornecedor.
- Selecionar N itens do mesmo fornecedor e confirmar "Pedido em Lote" cria exatamente 1 `pedidos_compra` com N `pedido_compra_itens`, em uma única transação (tudo ou nada).
- Itens sem fornecedor cadastrado não podem ser incluídos em um pedido em lote.
- Buscar "Stela" encontra fornecedores cadastrados como "Stella" (e variações de acento/caixa), respeitando o filtro de `contato_tipos.tipo = 'fornecedor'` já existente.
- Lint e `vite build` passam sem novo erro.

### Pendências (Parte 2)

- [ ] Definir o threshold de `similarity()` com dados reais de fornecedores (0.3 é ponto de partida, não validado com nomes reais).
- [ ] Decidir se a busca fuzzy deve considerar também `nome_empresa` (nome fantasia), não só `nome` — hoje o rascunho cobre só `nome`.
- [ ] Reextrair `supabase/db/current/` (desatualizado desde 2026-07-07) — não bloqueia esta SPEC, mas deve ser feito para não confundir o próximo agente que consultar o snapshot em vez das migrations reais.
