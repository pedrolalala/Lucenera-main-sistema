---
titulo: "SPEC-122 — Busca de peças 'elimina por palavra' + ordenação por coluna prioritária em Peças e Produtos"
status: concluído
data_ultima_modificacao: 2026-08-27 (implementado e publicado — "Fora de Linha" fica de fora por decisão do usuário)
sistemas_envolvidos:
  - Cadastro (cadastro-lucenera-b86fe, Skip 36668) — tela "Peças e Produtos" (`Pecas.tsx`), foco principal
  - Orçamentos (gestao-financeira-clone-544cb, Skip 32554) — `ProductSearchModal.tsx` ("Buscar Produtos"), consumidor da mesma RPC
  - Banco compartilhado — RPC `public.buscar_produtos_fuzzy`
dependencias:
  - SPEC-100 (criação da RPC `buscar_produtos_fuzzy`)
  - SPEC-116 (extensão multi-termo da mesma RPC — "busca universal, multi-coluna e estilo Google")
---

# SPEC-122 — Busca de peças "elimina por palavra" + ordenação por coluna prioritária em Peças e Produtos

> `status` aceita apenas: `não iniciado`, `pendente`, `concluído`.
> Toda vez que a SPEC for editada, atualizar `data_ultima_modificacao`.

## Origem

Reunião Mariane + Pedro (+ Filipe, entra a partir de [04:32]) em 27/08/2026 — transcrição em `02-Reunioes/20. Lucenera (Mariane) - 27.08.2026_ busca de produtos, melhorias/Reunnião.01`. Mariane comparou ao vivo a busca de peças do sistema atual com a busca do sistema antigo (Connect) e com o "Consultar Produto", pedindo uma busca mais focada; Pedro confirmou que vai atacar a busca "nos dois casos: resultado de produto e na parte do orçamento" ([09:41]).

## Contexto (investigado em código antes de propor)

Hoje **as duas telas de busca de produto do ecossistema já compartilham a mesma RPC** — `public.buscar_produtos_fuzzy` (criada na SPEC-100, estendida na SPEC-116 para multi-termo):

- Orçamentos → `ProductSearchModal.tsx` ("Buscar Produtos", chamado de dentro do orçamento) chama a RPC diretamente.
- Cadastro → `Pecas.tsx` ("Peças e Produtos") chama via `getProdutosEstoqueFiltradoBatched()` (`src/services/produtos.ts`), que também usa a RPC quando há termo de busca.

Ou seja: o problema relatado na reunião ("mesmo filtrando pela marca, ele me dá muitas opções", "não elimina o que não tem aquela palavra") tem uma **causa raiz única e compartilhada**, não é bug isolado de uma tela.

### Causa raiz confirmada na RPC

A versão atual de `buscar_produtos_fuzzy` (migration `20260817_119_spec116_busca_universal_produtos_fuzzy/002_fix_null_propagation_multitermo.sql`) já faz multi-termo AND — cada palavra digitada precisa "passar" em pelo menos um campo para a linha sobreviver — mas o critério de "passar" inclui, além do `ilike '%termo%'` (contém literalmente), uma cláusula de tolerância:

```sql
OR word_similarity(unaccent(lower(t.termo)), unaccent(lower(p.nome))) > 0.3
OR word_similarity(... m.nome ...) > 0.3
OR word_similarity(... c.nome ...) > 0.3
OR word_similarity(... p.descricao_tecnica ...) > 0.3
```

`word_similarity > 0.3` é um limiar permissivo o suficiente para muitos produtos "parecidos" (mas que **não contêm** a palavra digitada) passarem no filtro de cada termo — isso é o oposto do que a reunião pediu explicitamente:

> [07:44–07:51] "A cada palavra que acrescenta, ele tem que eliminar o que não tem nessa palavra." / "Sim, ele tem que ir filtrando mesmo."

Essa é exatamente a regra que **este pedido do usuário** reforça: *"lembrando que cada palavra deve filtrar ou seja eliminar opções"*. Hoje a RPC não garante isso — uma palavra pode "combinar por semelhança" com um produto que nem contém aquela palavra em campo nenhum, e o produto não é eliminado.

### Causa raiz confirmada da falta de ordenação por coluna

Em Orçamentos, `ProductSearchModal.tsx` já tem exatamente o recurso que a reunião pede para Peças/Produtos: colunas clicáveis (`COLS` + `SortKey`/`SortDir`/`handleSort`, linhas 89-135 e 683-711) que deixam o usuário escolher qual coluna manda na ordenação (Código, SKU/Referência, Nome, Marca, Categoria, Preço, Estoque, Disponível, Setor) — é a isso que Mariane se refere em [00:00]: *"aqui no orçamento, a vantagem é que eu consigo direcionar aqui o que eu quero primeiro. Se eu quero o nome, se eu quero a referência."*

Em Cadastro, `Pecas.tsx` **não tem nenhum controle de ordenação** — os cabeçalhos de coluna (`Código`, `Referência`, `Descrição`, `Marca`, `Preço Venda`, `Estoque Total`, `Disponível`) são texto estático, sem `onClick`. Pior: quando há busca por texto, `getProdutosEstoqueFiltradoBatched()` **ignora a ordenação por relevância que a própria RPC calcula** e reordena tudo no client por `estoque_disponivel desc, nome asc` (fim do arquivo `produtos.ts`) — a relevância do termo buscado nem chega a influenciar a ordem exibida.

### Achado adicional: "Fora de Linha" já tem coluna no banco, só não é populada nem exibida

Mariane perguntou onde veria produtos fora de linha (marcados com "FL" no sistema antigo). Investigação direta no banco:

```
produtos.status_comercial → 998 NULL, 1 'Fora de Linha', 1 'Normal' (de 4.726 produtos ativos)
```

A coluna **já existe** e já aceita exatamente o valor `'Fora de Linha'` — não é preciso migration nova. O gap é 100% de dado (pipeline de importação do Connect, responsabilidade do Sérgio — Pedro já confirmou na reunião que vai conferir com Vinícius/Sérgio) e de exibição (nenhuma tela hoje mostra `status_comercial`: nem `Pecas.tsx`, nem `PecaDetailsPanel.tsx`, nem `ProductSearchModal.tsx`). Mariane já sugeriu a solução visual: *"deixar em vermelho... fora de linha já fica meio que visível pra todo mundo, sem ter que olhar EFL"* ([02:52]) — em vez de reintroduzir o prefixo "FL" no nome/código.

### Achado colateral (fora do escopo desta SPEC, registrado para não se perder)

`src/components/GlobalSearchModal.tsx` + `src/lib/store.tsx` no Cadastro (busca via `Cmd+K`, se houver atalho ativo) ainda roda 100% sobre dado mockado do scaffold original (contatos "João Silva"/"Maria Souza", peças "Engrenagem 40D"/"Eixo Transmissão") — nunca foi conectado ao Supabase real. Não parece ser a tela "Consultar Produto" citada na reunião (ver Pendências), mas é um componente morto/enganoso que caso seja acionado por engano mostra dado fake. Não mexer nesta SPEC — registrar como achado para decisão futura (remover ou conectar).

## Decisões já tomadas (a partir da reunião + pedido do usuário)

- Escopo confirmado por Pedro na reunião: atacar a busca "nos dois casos: resultado de produto e na parte do orçamento" — como os dois já usam a mesma RPC, uma correção no banco atende ambos.
- Regra explícita (reforçada pelo pedido atual do usuário): busca multi-termo deve **eliminar**, não apenas ranquear — cada palavra adicionada estreita o resultado, nunca o mantém só por "parecer" com algo.
- Ordenação por coluna prioritária deve existir em Peças e Produtos (Cadastro), no mesmo padrão já aprovado e em produção em Orçamentos → Buscar Produtos — não inventar um controle novo.
- "Fora de Linha" fica registrado como pendência de dado (depende de Sérgio/Vinícius) + pendência de exibição (baixo esforço, sem migration) — não é bloqueante para o restante da SPEC.

## Definição da SPEC

### 1) Tornar a busca estritamente eliminatória por palavra (RPC `buscar_produtos_fuzzy`)

Abordagem recomendada — a decidir/validar antes de codar (ver Checklist):

- Remover a cláusula `OR word_similarity(...) > 0.3` do bloco de **eliminação** (`WHERE ... NOT EXISTS (... WHERE NOT (...))`) — cada termo passa a exigir contenção literal (`ilike '%termo%'`, já com `coalesce` para colunas nulas — não mexer nessa parte, já corrigida na SPEC-116) ou código exato (`codigo_produto = termo::int`) em nome, sku, referência, descrição técnica, marca ou categoria.
- **Manter** `word_similarity` só dentro do cálculo de `relevancia` (usado apenas para `ORDER BY`, já existe e não participa da eliminação) — preserva alguma tolerância de ordenação (ex.: erro de digitação leve não derruba o produto para o fim da lista) sem violar a regra de eliminação.
- Validar com os exemplos reais citados na própria reunião antes de publicar (mesmo padrão de rigor já usado nas SPEC-100/116 — testar via psql contra o banco real, não só QA automático do Skip):
  - `KPF12` → deve retornar só o(s) produto(s) que contêm literalmente "KPF12" em algum campo, não a família inteira "EKPF" genérica.
  - `dicroica geo10 6w` (3 termos) → cada termo elimina; resultado deve encolher a cada palavra adicionada, mesmo já filtrando por marca.
  - `lâmpada` (sem acento, sem caixa alta: `lampada`) → ainda precisa achar "Lâmpada" (isso já funciona hoje via `unaccent`+`lower` na comparação — não é regressão, é confirmação).
- **Risco a verificar antes de publicar**: como Orçamentos (`ProductSearchModal.tsx`) e Cadastro (`Pecas.tsx`) usam a mesma RPC, testar os dois consumidores após a mudança — não só o que motivou o pedido. Se a tela de Orçamentos hoje depende do fallback fuzzy para algum caso real em uso (não identificado nesta investigação), documentar antes de remover.

### 2) Ordenação por coluna prioritária em Peças e Produtos (Cadastro `Pecas.tsx`)

Replicar o padrão já validado em produção em `ProductSearchModal.tsx` (Orçamentos), sem inventar mecanismo novo:

- Adicionar `SortKey`/`SortDir`/`handleSort()`/`sortData()` (mesmo shape do componente de referência) ao estado de `Pecas.tsx`.
- Tornar os cabeçalhos de coluna existentes clicáveis (Código, Referência, Descrição/Nome, Marca, Preço Venda, Estoque Total, Disponível), com indicador visual de direção (seta), igual ao componente de referência.
- A ordenação por coluna é aplicada **depois** de `getProdutosEstoqueFiltradoBatched()` retornar os dados (client-side, sobre o array já carregado) — não precisa de mudança na RPC nem no service para este item.
- Default inicial mantém o comportamento atual (estoque disponível desc, depois nome) quando nenhuma coluna foi clicada — não é regressão do que já existe, só passa a ser **substituível** pelo usuário.

### 3) "Fora de Linha" — dado + exibição (dependente de terceiro)

- **Pendência externa (fora do controle desta implementação)**: Sérgio precisa passar a exportar o campo de "fora de linha" do Connect para popular `produtos.status_comercial = 'Fora de Linha'`. Pedro já sinalizou que vai confirmar com Vinícius/Sérgio ([02:41], [09:41]) — tratar como bloqueante só desta sub-parte, não do restante da SPEC.
- Quando o dado estiver chegando: exibir destaque visual (ex.: texto/badge vermelho, sem precisar reintroduzir prefixo "FL") em `Pecas.tsx` (linha da tabela) e em `PecaDetailsPanel.tsx` (card lateral) quando `status_comercial = 'Fora de Linha'`. Reaproveitar a coluna já existente — sem migration.
- Avaliar se `ProductSearchModal.tsx` (Orçamentos) também deve mostrar o mesmo destaque, já que é onde as vendedoras montam orçamento e mais precisam saber que uma peça está descontinuada antes de vender.

## Checklist de Ação

- [ ] Confirmar com Mariane, com print/gravação em mãos, exatamente qual tela é "Consultar Produto" citada em [06:41]/[06:48] — não foi localizada em nenhum dos 10 sistemas via grep de código (`Pecas.tsx` do Cadastro é a única tela de listagem de produtos com esse escopo encontrada); pode ser uma tela do Estoque/Compras (`EstoqueProdutos.tsx`, ainda não auditada em detalhe) ou simplesmente como Mariane se refere à própria tela de Peças quando só está consultando. Sem essa confirmação, o item 2 desta SPEC assume que "Peças e Produtos" (`Pecas.tsx`) é a tela relevante.
- [ ] Decidir/validar a remoção do fallback `word_similarity > 0.3` da eliminação (ver seção 1) — testar via psql com os termos reais da reunião antes de aplicar a migration em produção.
- [ ] Aplicar migration (`CREATE OR REPLACE FUNCTION`, reversível, sem `DROP`) e testar os dois consumidores (Cadastro e Orçamentos) antes de publicar qualquer frontend.
- [ ] Implementar ordenação por coluna em `Pecas.tsx` (Cadastro), publicar Skip 36668, testar ao vivo no navegador.
- [ ] Registrar pendência externa do "Fora de Linha" (Sérgio/Connect) — sem ação de código até o dado chegar.
- [ ] Atualizar `supabase/db/domains/estoque_compras.md` (nova versão da RPC) e `CHANGELOG.md`.

## Critérios de aceite

- Buscar `KPF12` em Peças e Produtos e em Buscar Produtos (Orçamentos) retorna só produtos que contêm "KPF12" literalmente em algum campo — não a família "EKPF" inteira.
- Buscar 2-3 termos (ex.: "dicroica geo10 6w") faz o resultado encolher a cada termo adicionado, mesmo com marca já filtrada — nenhum resultado sem o termo aparece.
- Busca sem acento/maiúscula continua funcionando (não é regressão da SPEC-100/116).
- Em Peças e Produtos, clicar em qualquer cabeçalho de coluna reordena a lista por aquela coluna, com alternância asc/desc, igual ao comportamento já existente em Buscar Produtos (Orçamentos).
- Sem regressão nos golden paths já cobertos pela SPEC-116 (multi-termo, accent-insensitive) nos dois sistemas.

## Plano de rollback

- RPC: `CREATE OR REPLACE FUNCTION` mantendo a versão anterior documentada nesta SPEC — reverter com outro `CREATE OR REPLACE` se algum consumidor regredir.
- Ordenação por coluna: mudança client-side isolada em `Pecas.tsx` — reverter via git no submodule Skip 36668, sem impacto em banco.
- "Fora de Linha": sem `DROP`/mudança destrutiva — reaproveita coluna já existente.

## Realizado

### 2026-08-27

- **Identidade da tela "Consultar Produto" confirmada**: é o próprio sistema Cadastro — o `SystemSwitcher` (usado em todos os 10 sistemas) exibe esse sistema com o rótulo **"Consultar Produtos"**, não "Cadastro" nem "Peças e Produtos". Confirmado via `read_page` ao vivo no navegador, dentro de Orçamentos. Ou seja, o item 2 desta SPEC (ordenação por coluna) já foi implementado na tela certa.
- **Item 1 (busca eliminatória por palavra) — RPC `public.buscar_produtos_fuzzy` corrigida em produção**, migration `20260827_125_spec122_busca_elimina_por_palavra` (2 arquivos, aplicados direto no banco real via psycopg2, com aprovação explícita do usuário para cada `CREATE OR REPLACE FUNCTION` — política de auto mode para DDL sensível):
  - `001_remove_fuzzy_da_eliminacao.sql`: tira a cláusula `word_similarity(...) > 0.3` do bloco de eliminação (`NOT EXISTS`), mantendo-a só no cálculo de `relevancia` (ORDER BY). **Medido antes do fix**: os termos "KPF12", "dicroica geo10 6w" e "lampada led" retornavam 4356-4384 produtos de 4726 ativos — o filtro multi-termo não eliminava quase nada.
  - **Bug achado testando ao vivo logo depois do fix 001**: "lampada led" (sem acento) achava 126 produtos, "lâmpada" (com acento) achava 0 — a troca pra `ilike` puro quebrou a insensibilidade a acento que a SPEC-116 já garantia. Corrigido em `002_fix_acento_na_eliminacao.sql`: `immutable_unaccent(lower(...))` nos dois lados do `ilike` (continua sendo comparação de substring literal, não de similaridade).
  - **Resultado final medido** (após 001+002): `KPF12` → 11 (era 4356); `dicroica gu10 6w` → 7 (era 4356, e a transcrição da reunião tinha "Geo10" — confirmado que era erro de transcrição de fala pra "GU10", o soquete real da lâmpada dicroica); `lâmpada`/`lampada led` → 426/126, idêntico com ou sem acento; `dicroica` + filtro de marca ILUMINAR → 542 → 32 → 18 → 0 conforme cada termo é adicionado (exatamente o comportamento "cada palavra elimina" pedido na reunião).
  - Testado ao vivo nos dois consumidores da RPC após a correção: Cadastro → Peças e Produtos ("Consultar Produtos") e Orçamentos → "Buscar Produtos" (dentro de ORC-0029) — mesma busca, mesmos 7 resultados precisos nos dois, sem regressão.
- **Item 2 (ordenação por coluna) — implementado em `Pecas.tsx`** (Cadastro, Skip 36668, v0.0.77): mesmo padrão já em produção em `ProductSearchModal.tsx` (Orçamentos) — cabeçalhos clicáveis (Código, Referência, Descrição, Marca, Preço Venda, Estoque Total, Disponível) com indicador de direção (seta) e alternância asc/desc; ordenação aplicada client-side sobre o array já carregado, sem mudança na RPC nem no service. Default (sem coluna clicada) mantém o comportamento anterior. Publicado em produção (`cadastro-lucenera-b86fe.goskip.app`) e testado ao vivo: clique em "Preço Venda" ordenou 7 resultados corretamente crescente e depois decrescente.
- **Item 3 (Fora de Linha) explicitamente adiado pelo usuário** ("a única coisa que as peças fora de linha não estão sendo exportadas já confirmei isso, vamos seguir sem isso por enquanto") — nenhuma ação de código feita para esse item nesta rodada; achado técnico (coluna `status_comercial` já existe, só falta o dado do Connect) continua registrado acima para quando for retomado.
- `GlobalSearchModal.tsx`/`store.tsx` (Cadastro) seguem rodando sobre dado mockado do scaffold original — não mexido nesta SPEC, fora do escopo confirmado pelo usuário.

## Pendências

- [ ] Sérgio/Vinícius: exportar "fora de linha" do Connect para `produtos.status_comercial` — item 3 desta SPEC, retomar quando o dado chegar.
- [ ] Decidir se o destaque visual de "Fora de Linha" entra também em `ProductSearchModal.tsx` (Orçamentos) na mesma rodada ou depois (só relevante quando o item acima for retomado).
- [ ] `GlobalSearchModal.tsx`/`store.tsx` (Cadastro) rodando sobre dado mockado do scaffold original — fora do escopo desta SPEC, decidir depois se remove ou conecta ao dado real.
- [ ] Atualizar `CHANGELOG.md` (fazer junto com o fechamento desta SPEC).
