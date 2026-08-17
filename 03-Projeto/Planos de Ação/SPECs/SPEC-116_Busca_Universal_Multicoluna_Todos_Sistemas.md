---
titulo: "SPEC-116 — Busca universal, multi-coluna e estilo Google em todos os sistemas"
status: pendente
data_ultima_modificacao: 2026-08-17
sistemas_envolvidos:
  - Cadastro (cadastro-lucenera-b86fe, Skip 36668) — piloto 1
  - CRM (lucenera-crm-3bd29, Skip 24580) — piloto 2
  - Orçamentos (gestao-financeira-clone-544cb, Skip 32554)
  - Estoque/Compras (compras-lucenera-3o23t98ee, Skip 40326)
  - Logística (lucenera-logistics-b7cd1, Skip 24039)
  - Admin Bancária/Financeiro (retorno-bancario-bradesco-5392a, Skip 36395)
  - RH (dashboard-rh-lucenera-5fe9c)
  - Hub/TI (central-lucenera-dashboard-1c9ba)
  - Ubiqua (catalogo-pecas-ubiqua-e6fa0) — baixa prioridade, ver Pendências
  - Dashboard Financeiro satélite (dashboard-lucenera-b02z85wa3) — ver Pendências
dependencias:
  - SPEC-100 (RPC buscar_produtos_fuzzy — padrão técnico de referência)
  - SPEC-030/034 (RPC buscar_fornecedores_fuzzy — padrão técnico de referência, unaccent+pg_trgm)
  - SPEC-114 (busca client-side em boletos/NF — padrão de referência para telas com dataset pequeno já carregado)
---

# SPEC-116 — Busca universal, multi-coluna e estilo Google em todos os sistemas

> Origem: pedido direto do usuário (17/08/2026) — busca "de alta abrangência" em todo campo de busca/filtro de todos os módulos, "sem exceção". Não veio de reunião registrada em `02-Reunioes/`.

## Checklist de Ação

- [ ] Confirmar com o usuário o escopo desta rodada: todos os sistemas de uma vez (alto risco, alto esforço de QA) ou rollout faseado por prioridade (recomendado — ver ordem de implementação)
- [ ] Documentar o "padrão Lucenera de busca" como referência escrita (client-side multi-termo normalizado vs RPC fuzzy server-side) — critério de quando usar cada um
- [x] **Piloto 1 (server-side) — Cadastro `Pecas.tsx`**: RPC `buscar_produtos_fuzzy` estendida (migration `20260817_119_spec116_busca_universal_produtos_fuzzy`, aplicada no Supabase real) para multi-termo AND + `descricao_tecnica`; `getProdutosEstoqueFiltradoBatched()` trocado para consumir a RPC. Publicado Skip 36668, testado via psql (não via navegador — ver pendência abaixo).
- [x] **Piloto 2 (client-side) — CRM `Clientes.tsx`/`Projetos.tsx`**: busca multi-termo normalizada contra todos os campos relevantes da linha. Publicado Skip 24580. `Engenheiros.tsx`/`Arquitetos.tsx`/`Eletricistas.tsx` ficaram fora deste piloto (não abertos nesta rodada) — tratar no rollout do CRM.
- [x] Validar os 2 pilotos ao vivo no navegador (golden path) — feito 2026-08-17; achou e corrigiu 2 bugs reais só visíveis ao vivo (ver Realizado)
- [x] Rollout Orçamentos (Skip 32554, v0.0.347): `devolucoesService.ts` (usado por `DevolucaoItemSearchModal.tsx`) — multi-termo AND no nome do produto via `.ilike()` encadeado. `budget-search.ts` (usado por `DraftBudgetsTab.tsx`/`ClientApprovalTab.tsx`/`projectFinancialApprovalService.ts`) — multi-termo + accent-insensitive, e passou a checar `arquiteto.nome` (já existia no tipo, nunca era comparado). `BudgetItemCard.tsx` não tinha busca própria — delega pro `ProductSearchModal.tsx`, que já usa `buscar_produtos_fuzzy` (SPEC-100), já beneficiado pela extensão da SPEC-116 no piloto 1.
- [x] Rollout Estoque/Compras (Skip 40326, v0.0.69): `estoque-produtos.ts` (EstoqueProdutos.tsx) multi-termo + categoria; `necessidade-compra.ts` (NecessidadeCompra.tsx + Cotacoes.tsx, mesmo service) multi-termo preservando o cuidado com `produto_codigo` integer (sem ilike); `notas-fiscais-compra.ts` multi-termo + sku na busca leve de produto; `pedido-compra.ts` (PedidosCompra.tsx) passa a casar por número OU fornecedor (client-side — PostgREST não aceita OR entre coluna própria e coluna de resource embutido no mesmo `.or()`, confirmado contra a API real). `Marcas.tsx` e `ModalRegistrarCompra.tsx` já usavam `buscar_fornecedores_fuzzy` (SPEC-030) — sem mudança necessária (entidade de campo único, não multi-atributo).
- [x] Rollout Logística (Skip 24039, v0.0.91): `SeparacaoPage.tsx`, `PendentesPage.tsx`, `EntregasFinalizadasPage.tsx` — multi-termo + accent-insensitive em cliente/obra/endereço/responsável/telefone/motivo. Achado: submodule local tinha uma feature (duplo-clique abre edição, commit `485a5e8`) publicada só no Skip? não — commitada localmente mas não publicada no Skip ainda; escrevi no Skip preservando o comportamento de produção atual (sem o duplo-clique) e reapliquei minhas mudanças em cima do local real (com duplo-clique) separadamente, pra não misturar as duas mudanças num commit só.
- [x] Rollout Admin Bancária (Skip 36395, v0.0.65): `ConsultarDuplicatas.tsx` — campo "Pessoa" multi-termo + accent-insensitive. Achado: `TransactionFilters.tsx` do checklist original não fica neste sistema — está em Orçamentos (Skip 32554, `src/components/transactions/TransactionFilters.tsx` + `transactionService.ts`), corrigido junto com o rollout de Orçamentos (multi-termo na descrição da transação).
- [x] Rollout RH (Skip 23919, v0.0.222): `Funcionarios.tsx` multi-termo (nome/cargo/e-mail/CPF/empresa), `Avaliacoes.tsx` multi-termo no nome do funcionário, `Cargos.tsx` multi-termo (título/departamento) — todos accent-insensitive.
- [x] Rollout Hub/TI (Skip 37750, v0.0.39): `LogsTab.tsx` multi-termo (tabela/operação/observação). `UsersTab.tsx` e demais abas admin não têm campo de busca (listas completas sem filtro) — fora do escopo desta SPEC.
- [ ] Avaliar Ubiqua e Dashboard Financeiro satélite (ver Pendências) antes de incluir no rollout
- [ ] Atualizar `AI_DB_CONTEXT.md` de cada sistema alterado que envolver RPC/schema nova
- [ ] Atualizar `supabase/db/domains/estoque_compras.md` (extensão da RPC `buscar_produtos_fuzzy`) e `CHANGELOG.md`

### Passos manuais do usuário

- [x] Aprovar o escopo faseado (pilotos primeiro) em vez de todos os ~11 apps simultaneamente — aprovado 2026-08-17
- [x] Confirmar os 2 sistemas piloto propostos (Cadastro + CRM) — aprovado 2026-08-17
- [ ] Rodar `SELECT count(*)` nas tabelas grandes candidatas a índice GIN (`contatos`, `orcamentos`, `boletos`, `projeto_itens`) antes de decidir se cada uma precisa de índice trgm dedicado (produtos não precisou, com ~4,7k linhas — ver SPEC-100)
- [ ] Homologar cada sistema no navegador após publicação (não há suíte de testes automatizada em nenhum dos 8 sistemas)
- [ ] Decidir se vale investir em algo além de "replicar o padrão por repositório" — os 10 sistemas são repositórios/projetos Skip independentes, sem monorepo ou pacote npm compartilhado hoje; não existe mecanismo técnico para um "utilitário compartilhado" real entre eles sem trabalho de infraestrutura à parte (fora do escopo desta SPEC)

## Objetivo

Hoje cada tela de listagem/filtro do ecossistema Lucenera implementa sua própria lógica de busca, de forma inconsistente: algumas já usam RPC fuzzy tolerante a erro de digitação e acento (Orçamentos → `ProductSearchModal.tsx`, via SPEC-100), outras usam `.or(ilike)` simples sem acento nem múltiplas colunas (Cadastro → `Pecas.tsx`), outras filtram só client-side sobre um array já carregado com 1-2 campos fixos (CRM → `Projetos.tsx`, RH → `Funcionarios.tsx`, Logística → `SeparacaoPage.tsx`), e uma parte já resolve bem via filtro client-side simples porque o dataset é pequeno e já está todo carregado (Admin Bancária → `NotasFiscais.tsx`, SPEC-114).

O objetivo é levar todo campo de busca do ecossistema ao mesmo padrão: multi-coluna (varre todos os campos relevantes da tela, não só 1), parcial, case-insensitive, sem distinção de acento, aceitando múltiplos termos em qualquer ordem, sem latência perceptível ao digitar — generalizando o padrão técnico já aprovado e validado em produção nas SPEC-030/100/114, não inventando um novo do zero.

## Decisões aprovadas

- Escopo é todo campo de busca/filtro de todos os sistemas em `04-Sistemas/`, sem exceção declarada pelo usuário.
- Busca deve varrer todas as colunas relevantes da tabela, não só uma (ex.: "Interlight" deve casar em marca, mesmo vindo de JOIN).
- Estilo Google: termos parciais, case-insensitive, sem distinção de acento, múltiplos termos em qualquer ordem.
- Sem latência perceptível ao digitar.
- Critério de aceite: em qualquer tela de listagem, o campo de busca aceita qualquer informação presente na base e atualiza o resultado dinamicamente ou por comando de busca.
- Não inventar um padrão técnico novo — generalizar o que já foi aprovado e está em produção (RPC fuzzy `unaccent`+`pg_trgm`, SPEC-030/100).
- 2026-08-17: usuário aprovou seguir com a recomendação do planner — rollout faseado, começando pelos 2 pilotos (Cadastro server-side / CRM client-side), sem confirmar explicitamente Ubiqua e Dashboard Financeiro satélite (tratados como fora do escopo desta rodada por já estarem marcados como baixa prioridade/dados desconectados na SPEC; reabrir se o usuário pedir).

## Definição da SPEC

### Estado atual por sistema (amostragem confirmada em código — não é inventário exaustivo)

| Sistema | Tela(s) amostradas | Abordagem atual | Colunas cobertas hoje | Lacuna |
|---|---|---|---|---|
| Orçamentos | `ProductSearchModal.tsx` | RPC `buscar_produtos_fuzzy` (server, `unaccent`+`word_similarity`) | nome, sku, referência, código, marca, categoria | Falta `descricao_tecnica`; falta multi-termo AND explícito (hoje é 1 termo contra várias colunas, não N termos obrigatórios) |
| Orçamentos | `DevolucaoItemSearchModal.tsx`, `BudgetItemCard.tsx` | `.ilike()`/`.or()` direto, não usa a RPC | parcial, não confirmado em detalhe | Não usa o padrão fuzzy já aprovado no mesmo sistema |
| Cadastro | `Pecas.tsx` → `getProdutosEstoqueFiltradoBatched()` | PostgREST `.or(ilike)` client-driven, debounce 400ms local | nome, sku, referência, código (exato), descrição técnica (só no fallback "contém") | Marca/categoria fora do texto livre (mesmo bug já corrigido em Orçamentos pela SPEC-100); sem acento-insensitivo; sem multi-termo |
| CRM | `Clientes.tsx` | Client-side, array já carregado, `normalize()` (accent-strip) por campo (`searchName` só nome/empresa) | nome, empresa (campos separados, não 1 caixa) | Não é 1 caixa multi-coluna; sem multi-termo AND |
| CRM | `Projetos.tsx` | Client-side, `.includes(term.toLowerCase())` simples | código, nome | Sem accent-strip; sem multi-termo; sem outras colunas (cliente, cidade) |
| CRM | `Engenheiros.tsx`, `Arquitetos.tsx`, `Eletricistas.tsx`, `Fornecedores.tsx` | Não auditado em detalhe nesta rodada | — | Confirmar antes do rollout |
| Estoque/Compras | `EstoqueProdutos.tsx` | Client-side `.filter()` sobre `rows` já carregado | não detalhado | Confirmar antes do rollout |
| Estoque/Compras | `NecessidadeCompra.tsx` | Client-side `.filter()` por `marca_id`/seleção, não por texto livre visível | — | Confirmar se há campo de busca textual nesta tela |
| Estoque/Compras | `necessidade-compra.ts` (`applySearchFilter`) | Server `.ilike('produto', ...)`/`.or()` com fallback numérico | produto (nome), código exato | Sem marca/acento/multi-termo |
| Logística | `SeparacaoPage.tsx` | Client-side `.filter()` sobre `separacoes` já carregado | cliente | Confirmar demais colunas (produto, código) |
| RH | `Funcionarios.tsx` | Client-side `.filter()` | não detalhado | Confirmar colunas |
| Admin Bancária | `NotasFiscais.tsx` | Client-side, `Input` livre (SPEC-114, já corrigido) | nome_pagador, nosso_numero, numero_documento | Já no padrão desejado — referência de "boa prática" para telas com dataset pequeno |
| Admin Bancária | `ConsultarDuplicatas.tsx` | Client-side `.filter()` | não detalhado | Confirmar colunas |
| Hub/TI | `LogsTab.tsx` | Não detalhado nesta rodada | — | Confirmar antes do rollout |
| Ubiqua | `CustomersPage.tsx`, `NewQuote.tsx`, `AdminCatalog.tsx` | Não auditado | — | Sistema em baixa prioridade desde a consolidação (`03-Projeto/00_INDICE.md`) — ver Pendências |

Esta tabela **não é um inventário exaustivo** (45+ arquivos batem em `placeholder="Buscar..."` nos 10 sistemas). Ela cobre as telas mais relevantes por sistema, amostradas via grep + leitura direta do código. O item "Auditoria completa" nas Pendências é pré-requisito antes de declarar qualquer sistema "concluído" nesta SPEC.

### Abordagem técnica recomendada

Duas variantes já validadas em produção no próprio ecossistema — a SPEC não cria uma terceira, escolhe entre as duas por critério objetivo:

**A) RPC fuzzy server-side** (padrão `buscar_produtos_fuzzy`/`buscar_fornecedores_fuzzy`, SPEC-030/100):
- Usa `public.immutable_unaccent(lower(texto))` (wrapper IMMUTABLE já existente, necessário porque `unaccent()` puro é só STABLE) + `pg_trgm` (`word_similarity`/`similarity`, threshold `> 0.3`, mesmo já usado) + `ilike` de substring para match exato de código/SKU.
- `SECURITY INVOKER`, respeita RLS existente, sem tabela nova.
- **Quando usar**: tabela paginada no servidor, com potencial de crescer (produtos, contatos, orçamentos, boletos, projetos) ou quando a busca precisa varrer colunas de tabelas relacionadas via JOIN (marca, categoria, cliente) que o `.or()` do PostgREST não alcança.
- Índice GIN de expressão (`idx_contatos_nome_unaccent_trgm` é o precedente) só é necessário quando a tabela crescer o suficiente para o scan sequencial deixar de ser sub-ms — produtos com ~4,7k linhas não precisou; decisão de criar índice em cada tabela nova fica condicionada a medir o tamanho real antes (não travar isso agora).

**B) Filtro client-side multi-termo normalizado** (padrão embrionário em `Clientes.tsx`, consolidado pela SPEC-114 em `NotasFiscais.tsx`):
- Função utilitária: `normalize(texto) = texto.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase()`, aplicada tanto ao termo de busca quanto à concatenação dos campos relevantes de cada linha; depois `termos.split(/\s+/).every(t => textoNormalizado.includes(t))` para multi-termo AND em qualquer ordem.
- **Quando usar**: tela já carrega o dataset inteiro em memória (sem paginação server-side) e o volume é pequeno/limitado por natureza do negócio (funcionários, separações do dia, notas fiscais de um orçamento, boletos de um cliente) — não precisa ida ao banco a cada tecla, zero latência por definição.
- **Não usar** em tabelas grandes/crescentes carregadas por completo no cliente (ex.: se algum dia `EstoqueProdutos.tsx` carregar produtos sem paginação — precisa confirmar, ver tabela acima).

Critério de decisão por tela: se a tela já pagina/busca no servidor → variante A; se a tela já carrega tudo em memória e o tamanho é estruturalmente pequeno → variante B (mais simples, sem migration).

### Extensão necessária na RPC `buscar_produtos_fuzzy` (pré-requisito do Piloto 1)

A função já existe (`supabase/db/migrations/20260815_113_spec100_busca_produtos_fuzzy/001_rpc_buscar_produtos_fuzzy.sql`) e cobre nome/sku/referência/código/marca/categoria. Para servir também o Cadastro (`Pecas.tsx`), falta:
- Incluir `descricao_tecnica` no `ilike` e no `word_similarity` (hoje ausente; `getProdutosEstoqueFiltradoBatched()` já cobre esse campo no fallback atual, então é regressão se a RPC não cobrir).
- Confirmar suporte a multi-termo AND (hoje a RPC compara 1 `p_termo` inteiro contra cada coluna — "Lâmpada LED 10W" busca a frase inteira, não garante que os 3 termos apareçam em qualquer ordem/campo). Precisa de `unnest(string_to_array(...))` com `AND` entre termos, mantendo compatibilidade com quem já chama a função (Orçamentos).
- `ativoFilter` de `Pecas.tsx` é compatível (RPC já fixa `p.ativo = true`, igual ao `applyCommonFilters()` do Cadastro) — sem gap aqui.

Isso é alteração de função existente (`CREATE OR REPLACE FUNCTION`), não tabela/coluna nova.

### Ordem de implementação recomendada

1. Escrever/consolidar o "padrão Lucenera de busca" como referência (sem código ainda).
2. Piloto 1 (server-side): Cadastro `Pecas.tsx` reutilizando `buscar_produtos_fuzzy` estendida.
3. Piloto 2 (client-side): CRM `Clientes.tsx`/`Projetos.tsx` com helper `normalize()` + multi-termo AND.
4. Homologação manual dos 2 pilotos.
5. Rollout por sistema, sistema a sistema, seguindo a ordem do Checklist de Ação — cada sistema é um item de checklist próprio, publicado e homologado antes de passar para o próximo.
6. Ubiqua e Dashboard Financeiro satélite entram por último (ou ficam fora), conforme decisão em Pendências.

### Critério de aceite por sistema

Para cada tela migrada:
- Buscar por um termo presente em qualquer coluna relevante (não só a coluna "nome") retorna o resultado esperado.
- Buscar com acento errado ou ausente (ex.: "Interlight" sem acentuação especial, ou termo com erro de digitação leve) ainda retorna o resultado.
- Buscar 2+ termos em ordem trocada (ex.: "LED Lâmpada") retorna o mesmo resultado que a ordem original.
- Digitação não trava a UI nem gera requisição por tecla sem debounce (variante A) ou não gera latência perceptível (variante B).
- Sem regressão: casos que já funcionavam antes (busca por SKU/código exato, filtros de `<Select>` combinados) continuam funcionando.
- Verificação manual no navegador (golden path) — não há suíte de testes automatizada em nenhum dos 8 sistemas; não exigir "rodar testes" como critério.

### Plano de rollback

- **Variante A (RPC)**: `CREATE OR REPLACE FUNCTION` é reversível — manter a versão anterior da RPC documentada na migration anterior (SPEC-100) para reverter com outro `CREATE OR REPLACE` caso a extensão quebre algum consumidor existente (Orçamentos). Sem `DROP` de função, sem exclusão de dado.
- **Variante B (client-side)**: reverter o componente para a versão anterior via git no repositório do sistema (Skip); sem impacto em banco.
- Nenhuma migration desta SPEC deve envolver `DROP`/`DELETE`/dado — é só leitura reformulada.

## Realizado

### 2026-08-17

- Piloto 1 (Cadastro, server-side): migration `20260817_119_spec116_busca_universal_produtos_fuzzy` aplicada no Supabase real — `buscar_produtos_fuzzy` agora aceita múltiplos termos em qualquer ordem (cada termo precisa casar em algum campo, não necessariamente o mesmo) e cobre `descricao_tecnica`. `src/services/produtos.ts` (`getProdutosEstoqueFiltradoBatched`) trocado para consumir a RPC em vez do fallback ilike exato/parcial. Testado via psql: "interlight" (só na marca, via join) e "led plafon" (2 termos em ordens diferentes) retornam certo. Publicado em produção (Skip 36668, `cadastro-lucenera-b86fe.goskip.app`). Commit local `9949f82` (cadastro-lucenera).
- Piloto 2 (CRM, client-side): `Clientes.tsx` e `Projetos.tsx` com busca multi-termo normalizada (accent-strip) contra todos os campos relevantes da linha. Publicado em produção (Skip 24580, `lucenera-crm-3bd29.goskip.app`). `Clientes.tsx` sincronizado no submodule local (commit `39c4e3e`, lucenera-crm); `Projetos.tsx` só ficou no Skip — submodule local estava numa versão pré-SPEC-043/044 (Sheet lateral, `getProjetos()`), escrever a mudança em cima dela teria regredido esse refactor.
- Testado ao vivo no navegador (2026-08-17) — achou e corrigiu 2 bugs reais que o QA automático do Skip e o smoke-test via psql não pegaram:
  1. **URL gigante em termo genérico**: buscar "spot"/"interlight" no Cadastro casava 500-2000 produtos, e mandar todos os ids de uma vez via `.in('id', ids)` gerava uma URL de ~40-70KB — estourava limite de tamanho de URL do servidor e a busca falhava ("Falha ao carregar as peças"). Corrigido buscando os dados de estoque em lotes de 150 ids por vez (migration 002 não foi necessária pra esse — só mudança em `produtos.ts`, Skip 36668 v0.0.70).
  2. **Bug de NULL na RPC (lógica de 3 valores do SQL)**: `p.sku ilike '%termo%'` retorna NULL (não `false`) quando `sku` é NULL, e isso quebrava o `NOT EXISTS` do multi-termo — um termo que não casava em nenhum campo era silenciosamente ignorado em vez de reprovar o produto, então "led plafon" trazia produtos sem nenhum "led". Corrigido envolvendo toda coluna nullable com `coalesce(coluna, '')` antes do `ilike` (migration `002_fix_null_propagation_multitermo.sql`, aplicada no Supabase real). Contagem de falsos positivos: 2000 (capped) → 168 resultados reais para "led plafon".
- Validação final ao vivo: Cadastro (`interlight`→500 sem erro, `led plafon`→168 corretos), CRM Clientes (`vinicius ribeirao` casa cliente com nome+cidade em campos diferentes), CRM Projetos (`sao paulo` sem acento casa "São Paulo" com acento). Sem regressão visível nos golden paths testados.

### 2026-08-17 (teste ao vivo do rollout completo)

- **Bug real achado e corrigido — Orçamentos, aba "Todos"**: essa aba usa uma implementação de busca própria (`useBudgetStore.ts`), separada de `budget-search.ts` (que eu já tinha corrigido) — nunca checava arquiteto (embora o `select` já trouxesse o dado), 1 termo contra a frase inteira, sensível a acento. "ribeiro" (nome de um arquiteto visível na tela) retornava 0 resultados antes da correção. Corrigido com o mesmo padrão multi-termo + accent-insensitive; testado ao vivo: "ribeiro sweep" (arquiteto+cliente, campos diferentes, ordem trocada) agora acha o orçamento certo. Publicado Skip 32554 v0.0.349.
- Aba "Rascunho" (`budget-search.ts`) testada ao vivo: "resorts hemisferio" (sem acento em "Hemisfério") funciona corretamente.
- **Achado (não é bug, é escopo)**: `TransactionFilters.tsx`/`transactionService.ts`, corrigidos no rollout anterior, são código morto — as rotas `/transactions` e `/transacoes` só redirecionam para `/budgets` (confirmado em `App.tsx`). Não há como testar ao vivo porque a tela nunca é renderizada; a correção fica registrada mas sem risco (nada quebra, só não é exercitada).
- `DevolucaoItemSearchModal.tsx`/`devolucoesService.ts` não testado ao vivo (exigiria montar um orçamento de devolução de teste) — mudança pequena e isolada (`.ilike()` numa única coluna), risco baixo.

### 2026-08-17 (rollout completo, mesmo dia)

Rollout dos 6 sistemas restantes concluído no mesmo dia dos pilotos, todos publicados em produção:

- **Orçamentos** (Skip 32554, v0.0.347/v0.0.348): `devolucoesService.ts` (multi-termo no nome do produto), `budget-search.ts` (multi-termo + accent-insensitive na lista de orçamentos, agora também checa arquiteto), `transactionService.ts` (multi-termo na descrição de transações — achado: `TransactionFilters.tsx` do checklist original estava aqui, não em Admin Bancária).
- **Estoque/Compras** (Skip 40326, v0.0.69): `estoque-produtos.ts`, `necessidade-compra.ts` (preservando o cuidado com `produto_codigo` integer/sem ilike), `notas-fiscais-compra.ts`, `pedido-compra.ts` (busca por número OU fornecedor, resolvida client-side — achado: PostgREST não aceita `.or()` entre coluna própria e coluna de resource embutido, confirmado contra a API real).
- **Logística** (Skip 24039, v0.0.91): `SeparacaoPage.tsx`, `PendentesPage.tsx`, `EntregasFinalizadasPage.tsx` — achado: submodule local tinha feature não publicada (duplo-clique, commit `485a5e8`), preservada separada da mudança de busca.
- **Admin Bancária** (Skip 36395, v0.0.65): `ConsultarDuplicatas.tsx` (campo Pessoa).
- **RH** (Skip 23919, v0.0.222): `Funcionarios.tsx`, `Avaliacoes.tsx`, `Cargos.tsx`.
- **Hub/TI** (Skip 37750, v0.0.39): `LogsTab.tsx`.

Todos os sistemas passaram no QA automático do Skip (build/lint/test) antes de publicar. Não testado ao vivo no navegador ainda para estes 6 sistemas (só os 2 pilotos foram testados ao vivo) — ver Pendências.

**Padrão técnico usado no rollout**: telas client-side (array já carregado) usaram `normalize()` (accent-strip) + multi-termo AND, mesmo padrão dos pilotos. Telas server-side usaram `.or()` encadeado por termo (mesma coluna) — PostgREST soma automaticamente como AND entre grupos; confirmado empiricamente que isso NÃO funciona quando um dos lados é uma coluna de tabela relacionada (embedded resource) — nesse caso, filtrar client-side é a solução segura.

### 2026-08-17 (teste ao vivo: Estoque/Compras e Logística)

- **Estoque/Compras testado ao vivo, sem bug novo**: Necessidade de Compra ("lucenera linea"→12 resultados), Estoque ("led plafon"→150), Entrada de NF (busca por produto e por fornecedor), Pedidos de Compra ("iluminar"→15, casando pelo nome do fornecedor via filtro client-side). Golden paths batendo com o esperado, sem regressão nos filtros de `<Select>` combinados.
- **Bug real achado e corrigido — Logística, Entregas Finalizadas**: a coluna de pessoa exibida na linha (`EntregaFinalizadaRow.tsx`) mostra `gestora_equipe`, não `recebido_por` — buscar "marina borgato" (gestora + sobrenome do cliente, campos diferentes) retornava 0 antes da correção porque só checava `recebido_por`. Corrigido incluindo `gestora_equipe`, `numero_pedido`, `numero_entrega` e `observacoes` no haystack; placeholder atualizado para "Buscar por cliente, obra, endereço, gestora...". Testado ao vivo pós-fix: "marina borgato" agora retorna 11 entregas corretas (cliente Borgato, gestora Marina Pousa).
- **Gap achado proativamente — Logística, Separação**: `SeparacaoPage.tsx` não checava `endereco_entrega` (fallback real de endereço) nem `gestora_equipe`, achado ao investigar o bug acima e confirmar contra `SeparacaoCard.tsx`. Corrigido; testado ao vivo: "bianchi 7151" (parte de um endereço) restringe corretamente para 1 resultado.
- **Gap achado proativamente — Logística, Pendentes**: aba "Resolvidas" não checava `resolved_by` no haystack. Corrigido; sem regressão observada na busca por cliente ("bug sweep"). Não foi possível diferenciar em teste ao vivo se especificamente `resolved_by` está casando (só existe 1 registro resolvido em produção no momento do teste, e a mesma pessoa registrou e resolveu) — mudança é de baixo risco (1 campo a mais no array), confiança vem da revisão de código, não de um teste ao vivo distintivo.
- Publicado Skip 24039 v0.0.92. Commit local `823d074` (lucenera-logistics-b7cd1).

### 2026-08-17 (teste ao vivo: RH)

- **RH testado ao vivo, sem bug novo**: `Funcionarios.tsx` — "gerente vinicius" (cargo+nome, ordem trocada, sem distinção de maiúscula) retorna corretamente só Vinicius Bortolin Costa (Gerente Administrativo). `Avaliacoes.tsx` e `Cargos.tsx` não têm nenhum registro cadastrado em produção no momento do teste (telas vazias) — não foi possível exercitar a busca ao vivo nelas; mudança é de baixo risco (mesmo padrão já validado em `Funcionarios.tsx`), confiança vem de revisão de código, não de teste ao vivo.

## Pendências

- [ ] Testar os 2 pilotos ao vivo no navegador (golden path) — até agora só QA automático do Skip (build/lint/test) e smoke-test via psql direto na RPC, ninguém clicou nas telas publicadas (`cadastro-lucenera-b86fe.goskip.app` / `lucenera-crm-3bd29.goskip.app`) ainda.
- [ ] Sincronizar `04-Sistemas/lucenera-crm-3bd29 (1)/src/pages/Projetos.tsx` local com o Skip (projectId 24580) — está numa versão anterior à SPEC-043/044 (usa `getProjetos()`/Sheet lateral em vez de `useProjectStore`); a mudança da SPEC-116 nesse arquivo só existe em produção (Skip), não no submodule local. Precisa de uma sincronização completa do arquivo (não incremental), não só desta mudança.
- [ ] `Engenheiros.tsx`/`Arquitetos.tsx`/`Eletricistas.tsx`/`Fornecedores.tsx` do CRM não entraram no piloto 2 — mesmo padrão de `Clientes.tsx` deve ser aplicado nesses arquivos no rollout do CRM.
- [x] Testar ao vivo: Orçamentos — achou e corrigiu 1 bug real (`useBudgetStore.ts` não checava arquiteto na aba Todos, ver Realizado).
- [x] Testar ao vivo: Estoque/Compras — sem bug novo.
- [x] Testar ao vivo: Logística — achou e corrigiu 3 gaps reais (`EntregasFinalizadasPage.tsx` campo errado; `SeparacaoPage.tsx`/`PendentesPage.tsx` campos faltando, ver Realizado).
- [x] Testar ao vivo: Admin Bancária — `ConsultarDuplicatas.tsx` (campo Pessoa), sem bug novo, multi-termo/ordem trocada confirmado ("interiores ribeiro" achou "CA & RIBEIRO INTERIORES LTDA").
- [x] Testar ao vivo: Hub/TI — `LogsTab.tsx`, sem bug novo, multi-termo + variante acentuada/sem acento confirmada ("financeira orcamentos" casou tanto "APROVACAO_FINANCEIRA" quanto "APROVAÇÃO_FINANCEIRA").
- [x] Testar ao vivo: RH — `Funcionarios.tsx` confirmado ao vivo, sem bug novo. `Avaliacoes.tsx`/`Cargos.tsx` sem dado em produção pra exercitar a busca (telas vazias) — mudança de baixo risco, não verificável ao vivo neste momento.
- [x] Push de `823d074` (lucenera-logistics-b7cd1) e `3a63a23` (gestao-financeira-clone-544cb) pro GitHub — travou por várias tentativas no prompt interativo do Git Credential Manager, resolvido 2026-08-17 depois que o usuário liberou o prompt.
- [ ] **Limitação PostgREST descoberta no rollout de Compras**: não dá pra combinar uma coluna da própria tabela com uma coluna de resource embutido (join) dentro do mesmo `.or()` — dá erro de parse (PGRST100), confirmado direto contra a API real. Quando a busca multi-termo precisar cruzar coluna própria + coluna de tabela relacionada (ex.: "número do pedido" + "nome do fornecedor"), a solução é filtrar client-side sobre os dados já carregados (funciona bem pra listas pequenas/bounded, tipo os 300 pedidos de PedidosCompra.tsx) — não tentar `!inner` + `.or()` combinando as duas.
- [ ] Aplicar a mesma lição do bug de NULL (coalesce antes de ilike em coluna nullable, dentro de qualquer OR-chain usado num filtro multi-termo) em qualquer RPC fuzzy nova do rollout — não é específico de `buscar_produtos_fuzzy`, é um risco genérico do padrão "variante A" sempre que a tabela tiver colunas nullable no meio do OR-chain.
- [ ] Achado colateral no rollout de Logística: o submodule local (`lucenera-logistics-b7cd1`) tem commit `485a5e8` ("duplo-clique abre edição/ação direto — padrão Cadastro" em Calendário/Separação/Pendências/Usuários) que nunca foi publicado no Skip (projectId 24039) — produção não tem esse comportamento ainda. Fora do escopo desta SPEC; alguém precisa decidir se publica.
- [ ] Confirmar se Ubiqua entra no escopo desta rodada — está marcado como baixa prioridade desde a consolidação de 24/06/2026 (`03-Projeto/00_INDICE.md`); aplicar o mesmo padrão lá custa esforço sem prioridade confirmada pelo usuário.
- [ ] Confirmar se o Dashboard Financeiro satélite (`dashboard-lucenera-b02z85wa3`) entra no escopo — ele roda sobre o livro-caixa `transacoes`, desconectado do resto do ecossistema (achado da SPEC-064); melhorar a busca ali não conecta os dados, só melhora a UX de uma fonte isolada.
- [ ] Confirmar se o dashboard Python (`dashboard/`) precisa de busca universal — os arquivos aparecem como deletados no working tree atual (`git status`), sugerindo descontinuação; se for esse o caso, remover da lista de sistemas afetados desta SPEC.
- [ ] Auditoria completa (não amostral) de campos de busca por sistema — este documento cobriu as telas mais relevantes via grep, não every screen; cada sistema pode ter telas adicionais com busca não mapeadas aqui (a lista de 45+ arquivos com `placeholder="Buscar..."` encontrada nesta investigação ainda não foi lida arquivo a arquivo).
- [x] Confirmar `projectId` real do CRM no Skip antes de publicar — corrigido 2026-08-17: Cadastro Lucenera = 36668 (não 24580 como o rascunho do planner indicava), CRM = 24580 (não 32554). O planner trocou os dois; confirmado contra `reference_skip_project_ids` na memória.
- [ ] Definir o threshold de linhas a partir do qual cada tabela grande (`contatos`, `orcamentos`, `boletos`, `projeto_itens`, `funcionarios`) precisa de índice GIN trgm dedicado — decisão técnica que depende de medir `SELECT count(*)` real antes de cada rollout, não decidida nesta SPEC.
- [ ] Decidir se algum dia vale investir em um pacote/utilitário de fato compartilhado entre os 10 repositórios Skip (hoje não existe mecanismo técnico para isso sem trabalho de infraestrutura à parte) — por ora, o plano assume replicar o padrão documentado, arquivo por arquivo, em cada repositório.
- [ ] Confirmar colunas de busca relevantes contra `supabase/db/current/` para cada tabela ainda não confirmada nesta rodada (Estoque/Compras, Logística, RH, Hub/TI) antes de implementar o rollout de cada sistema.
