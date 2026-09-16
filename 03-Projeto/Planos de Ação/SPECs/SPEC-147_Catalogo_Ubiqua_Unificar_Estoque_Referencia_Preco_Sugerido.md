---
titulo: "SPEC-147 — Catálogo Ubiqua: unificar estoque por referência entre empresas, remover peças órfãs e exibir preço sugerido"
status: em andamento
data_ultima_modificacao: 2026-09-15
sistemas_envolvidos:
  - Catálogo Ubiqua (catalogo-pecas-ubiqua-e6fa0)
  - Supabase (banco, só leitura nesta SPEC)
---

# SPEC-147 — Catálogo Ubiqua: unificar estoque por referência entre empresas, remover peças órfãs e exibir preço sugerido

> Toda vez que a SPEC for editada, atualizar `data_ultima_modificacao`.

## Checklist de Ação

- [x] Trocar a chave de agrupamento em `groupCatalogItems()` (`src/hooks/use-parts.ts`) de `descrição+preço` para `referência normalizada` (referência sem o sufixo `-IS`, case/trim-insensitive) — faz a mesma peça vendida pela Manoella e pela Islight aparecer como um card só, com estoque somado
- [x] Adicionar, na mesma função, o filtro que remove do catálogo linhas sem sufixo `-IS` **e** sem estoque (`disponivel <= 0` ou nulo) **e** sem nenhuma irmã `-IS` no mesmo grupo de referência — são as 11 peças órfãs da primeira importação da Manoela que nunca mais tiveram estoque (lista levantada abaixo)
- [x] Adicionar campo de "preço sugerido" (`vl_venda_produto`, já existe na tabela e já é buscado por `select('*')`, só não é usado em lugar nenhum do front hoje) ao tipo `GroupedPart` e exibir como texto pequeno ao lado do preço de revenda em `PartCard.tsx`, `ProductDetail.tsx` e `PartDetailSheet.tsx`
- [x] ~~Confirmar com o Vinicius, antes de publicar, se `vl_venda_produto` é de fato o campo certo para "preço sugerido"~~ — **confirmado em 2026-09-15** por cruzamento de dados com a tabela central `produtos.valor_venda` (ver "Realizado"/"Pendências")

### Passos manuais do usuário

- [x] Aprovar o escopo desta SPEC
- [ ] Decidir o que fazer com os 3 pares de referência que têm `valor_revenda` divergente entre as duas empresas antes de publicar a unificação (ver "Achado — preços divergentes" abaixo)
- [ ] Passar a planilha nova do Sérgio (ou confirmar o nome da coluna de "ativo/inativo") para virar uma SPEC de acompanhamento — sem isso não dá pra implementar o filtro de produto inativo

## Objetivo

Reunião com o Vinicius (15/09) sobre o site do catálogo Ubiqua (`catalogo-pecas-ubiqua-e6fa0`), usado pelos representantes para montar orçamento. Três pedidos:

1. Quando a mesma peça (mesma referência) tem estoque tanto pela empresa Manoella quanto pela Islight, mostrar como **um card só**, com estoque somado — hoje aparecem dois cards separados e confunde o representante. Peça com variante V2 (dimerizável, cor de LED a mais) continua separada, nunca junta com a versão normal.
2. Peça com referência que nunca teve o sufixo `-IS` (ou seja, só veio da primeira importação pela Manoela) e está com estoque zerado pode sumir do site — não vai ser reposta.
3. Mostrar um "preço sugerido" pequeno ao lado do preço, pra o representante não vender abaixo do valor mínimo combinado em contrato (não é bloqueio no sistema, é só informativo — o Vinicius foi claro que não dá pra travar por margem porque o imposto muda conforme o destino).

O fechamento do pedido em si (decidir de qual empresa sai o estoque na hora da venda) já é resolvido "por fora" segundo o Vinicius — e o código já faz isso hoje (ver "Achado — já implementado" abaixo), não faz parte do escopo desta SPEC.

## Decisões aprovadas

- Unificar por **referência** (não por descrição+preço, que é a chave usada hoje) — mesma referência sem o sufixo `-IS` = mesma peça física, soma estoque das duas empresas.
- Variante **V2** sempre fica separada — na prática já fica automaticamente: toda peça V2 no banco tem um código numérico de referência totalmente diferente da versão normal (ex.: `339104` vs `339204-V2-IS`), não é só um sufixo em cima do mesmo número. Então tirar só o `-IS` (sem mexer no `-V2`) já resolve sozinho, sem precisar de tratamento especial.
- Peça sem `-IS` e sem estoque, sem nenhuma irmã com `-IS` no mesmo grupo de referência, pode sumir do catálogo (11 peças hoje, listadas abaixo).
- Preço sugerido é só informativo (texto pequeno), sem bloqueio no formulário de orçamento — o controle de preço mínimo é contratual com o representante, não do sistema.

## Definição da SPEC

### Estado atual (levantado no Supabase real em 2026-09-15, tabela `revenda_ubiqua`)

| Métrica | Valor |
|---|---|
| Total de linhas em `revenda_ubiqua` | 87 |
| Empresas (`empresas`) que alimentam o catálogo | `MANOELLA` (id `9c877812-...`) e `ISLIGHT` (id `d8602441-...`) |
| Grupos distintos por referência (sem sufixo `-IS`) | 74 |
| Grupos com linha em **ambas** as empresas (candidatos a unificar) | 13 |
| Desses 13, com `valor_revenda` idêntico | 10 |
| Desses 13, com `valor_revenda` **divergente** | 3 (ver achado abaixo) |
| Linhas com variante V2 (`-V2-IS`) | 14, todas só do lado Islight, nenhuma com referência-base colidindo com peça não-V2 |
| Linhas sem `-IS` e sem estoque (`disponivel` nulo ou `<=0`) | 19 |
| Dessas 19, sem nenhuma irmã `-IS` (órfã completa — candidata a sumir) | **11** |
| Dessas 19, com irmã `-IS` no grupo (some sozinha ao entrar no card unificado, sem ação extra) | 8 |
| Coluna de "produto ativo/inativo" em `revenda_ubiqua` | **não existe hoje** |

**As 11 peças órfãs (sem `-IS`, sem estoque, sem irmã `-IS`) — candidatas a sumir do catálogo:**

`321401`, `321402`, `321304`, `322106`, `323201`, `323203`, `367101`, `611302`, `189203`, `189306`, `189343`

### Achado — mecanismo de agrupamento manual já existe, mas por descrição+preço

O front-end já tenta resolver isso hoje, mas de dois jeitos que não cobrem o caso da reunião:

1. **`vw_catalogo_unificado`** (view já criada em `20260526145009_vw_catalogo_unificado.sql`, existe no banco real hoje) agrupa por referência sem `-IS`, soma `disponivel`, usa `MIN(valor_revenda)` — é literalmente o que a reunião pediu. **Mas não é usada em lugar nenhum do front-end** (grep confirmou zero referências a ela em `src/`), e não serve pro carrinho de qualquer forma porque não expõe `id`/`empresa_id` linha a linha.
2. **`groupCatalogItems()`** (`src/hooks/use-parts.ts:63`), que é o agrupamento realmente usado por `useParts()`/`useProductDetail()`, agrupa por `descrição + preço` (`` `${desc.toLowerCase()}_${price.toFixed(2)}` ``) — não olha `referencia` nem `empresa_id`. Duas linhas da mesma peça em empresas diferentes só caem no mesmo card hoje se a descrição E o preço baterem exatamente, o que raramente acontece porque a descrição às vezes vem com o nome da empresa embutido (`"... - MANOELLA"` / `"... - ISLIGHT"`) — daí os cards duplicados que o Vinicius mostrou na reunião.
3. Existe também um agrupamento **manual** no admin (`AdminCatalog.tsx`, drag-and-drop "Modo Agrupar" → `updateCatalogItemsGroup()`), que reescreve `desc_produto` das duas linhas pra ficarem iguais e caírem na mesma chave do item 2. É o que o Vinicius estava fazendo peça por peça na reunião. Continua útil depois desta SPEC para casos que não batem por referência (erro de cadastro, etc.), não precisa ser removido.

**Decisão de implementação:** trocar a chave de `groupCatalogItems()` para referência normalizada (`referencia.trim().toUpperCase().replace(/-IS$/i, '')`), mesma regra já usada pela view (que fica sem uso — pode continuar existindo, não faz mal, fora do escopo desta SPEC decidir se remove).

### Achado — preços divergentes entre empresas (precisa decisão antes de publicar)

Dos 13 pares que vão unificar, **3** têm `valor_revenda` diferente entre Manoella e Islight:

| Referência | Manoella | Islight | Diferença |
|---|---|---|---|
| `321404` | R$ 434,36 | R$ 434,35 | R$ 0,01 (arredondamento, ignorável) |
| `321403` | R$ 434,36 | R$ 434,35 | R$ 0,01 (arredondamento, ignorável) |
| `332109` | R$ 734,27 | R$ 624,91 | **R$ 109,36** — divergência real, não é arredondamento |

O card unificado só pode mostrar um preço. A função `AdminCatalog.tsx` já trava o agrupamento manual quando os preços divergem ("Produtos com preços diferentes não podem ser agrupados") — ou seja, hoje o sistema explicitamente evita esse cenário; esta SPEC está pedindo pra unificar mesmo assim. Proposta (mesmo critério que `vw_catalogo_unificado` já usa): mostrar o **menor** valor (`MIN`), evitando cobrar a mais do cliente. **Mas a divergência de R$109 em `332109` parece erro de cadastro, não decisão de preço — vale o Vinicius confirmar antes de publicar**, listado em Pendências.

### Achado — resolução de empresa na hora do pedido já está implementada

O que o Vinicius descreveu como "isso quem vai resolver depois é a gente por fora" já existe no código, sem precisar de mudança:

- `fetchQuotes()` (`src/lib/api-admin.ts:235`) já calcula, por item do orçamento, qual empresa fatura (`empName = referencia.endsWith('-IS') ? 'Islight' : 'Manoella'`, com fallback pro relacionamento `revenda_ubiqua → empresas`) e mostra a lista de empresas envolvidas no campo "Faturamento" da tela de orçamentos do admin.
- Um único orçamento já pode ter itens de referências de empresas diferentes — não há bloqueio nenhum nesse sentido hoje.

Ou seja, o pedido 3 da reunião ("pode montar o pedido junto, resolve por fora depois") **não precisa de mudança de código** — só precisa que o card fique unificado na hora da busca (que é o resto desta SPEC).

### Achado — seleção de cor/empresa no card já funciona com múltiplas linhas por cor

`PartCard.tsx` já lida com o caso de duas linhas (empresas diferentes) tendo a mesma cor dentro do mesmo grupo: `selectedVariant` escolhe a linha com **maior** `disponivel` entre as da cor selecionada (`PartCard.tsx:49`), e o badge de estoque mostra a **soma** das duas (`getVariantStockForColor`, `PartCard.tsx:68`). `QuantityModal.tsx` limita a quantidade pedida ao estoque da linha escolhida (não da soma) — ou seja, um pedido nunca passa do estoque de uma única empresa numa linha de pedido, o que é compatível com "decide depois qual empresa fatura". **Não precisa mexer em `PartCard.tsx` nem `QuantityModal.tsx`** — só a chave de agrupamento em `use-parts.ts` já é suficiente pra esse comportamento entrar em ação para os 13 pares.

### Impacto no banco

Nenhum nesta SPEC — tudo é mudança de lógica de agrupamento no front-end (`use-parts.ts`), lendo colunas que já existem (`referencia`, `disponivel`, `vl_venda_produto`). Sem migration.

O filtro de "produto ativo/inativo" (pedido 5, ver Pendências) vai precisar de coluna nova em `revenda_ubiqua` quando a planilha do Sérgio for confirmada — fica de fora desta SPEC.

### Impacto em telas, relatórios ou automações

- **Vitrine pública do catálogo** (`/`, `Index.tsx` via `useParts()`): cards das 13 peças hoje duplicadas passam a aparecer unificados; 11 peças órfãs somem da listagem.
- **Página de produto** (`/produto/:slug`, `ProductDetail.tsx` via `useProductDetail()`): mesma mudança de agrupamento — atenção que o `slug` é gerado a partir da descrição+preço hoje (`use-parts.ts:78`); ao trocar a chave para referência, o `slug` também deve passar a derivar da referência normalizada, senão duas peças que deveriam unificar continuam gerando slugs diferentes e a página de produto quebra esse fluxo. Conferir links/favoritos antigos que apontem pro slug antigo (provavelmente não há, é catálogo interno sem SEO externo).
- **Admin — Catálogo** (`AdminCatalog.tsx`): os 13 pares deixam de precisar do agrupamento manual por drag-and-drop; a função continua disponível para os demais casos.
- **Admin — Orçamentos**: nenhuma mudança, já mostra o "Faturamento" corretamente (achado acima).

### Regras de permissão

Sem mudança — vitrine pública e área logada continuam com as mesmas regras de hoje.

### Critérios de aceite

- [x] Os 13 pares de referência aparecem como 1 card cada na vitrine, com estoque = soma das duas empresas. (testado ao vivo em 2 pares, batendo com o banco)
- [x] As 14 peças V2 continuam aparecendo separadas da versão normal. (confirmado ao vivo)
- [x] As 11 peças órfãs (lista acima) não aparecem mais na vitrine. (confirmado ao vivo — 0 dos 11 códigos aparecem)
- [x] As 8 peças sem `-IS`/sem estoque que têm irmã `-IS` continuam contribuindo 0 ao estoque do grupo, sem aparecer como card próprio. (confirmado indiretamente pela contagem exata de 63 cards)
- [x] Preço sugerido aparece nos 3 lugares (`PartCard`, `ProductDetail`, `PartDetailSheet`) quando `vl_venda_produto` estiver preenchido; não quebra quando nulo. (confirmado ao vivo, `PartDetailSheet` conferido pelo revisor no código)
- [x] Nenhuma mudança de comportamento no fluxo de adicionar ao orçamento / carrinho / checkout. (testado ao vivo: modal de quantidade trava corretamente no estoque da linha escolhida)
- [ ] `AdminCatalog.tsx` continua funcionando para agrupar manualmente peças que não batem por referência. (não testado ao vivo nesta rodada — revisor confirmou só que o código não foi alterado)

### Testes/verificações obrigatórias

1. [x] Testar ao vivo a vitrine (`catalogo-pecas-ubiqua-e6fa0`) antes/depois: contar quantos cards existem hoje vs. depois da mudança — **63 cards, bate exatamente com 74 grupos − 11 órfãs.**
2. [x] Conferir visualmente pelo menos 2 dos 13 pares mostrando estoque somado — testado `332109`/`332109-IS` (28, preço MIN R$624,91) e `339104`/`339104-IS` (14), ambos conferidos contra o banco real. (Nota: o exemplo original `339101`/`339104-IS` citado aqui estava incorreto — são referências diferentes, produtos distintos, não um par; corrigido para `339104`/`339104-IS`.)
3. [x] Conferir que as peças V2 continuam com card próprio — confirmado, todas separadas.
4. [x] Simular pedido de quantidade maior que o estoque de uma única empresa — testado ao vivo no par `339104` (soma 14): trava em 11 (estoque da linha Islight), não regrediu.
5. [x] Conferir que o `slug` da página de produto segue funcionando para os pares unificados — `/produto/332109` e `/produto/339104` resolvem corretamente.

### Análise obrigatória de ecossistema (checklist do `COMO_CRIAR_SPEC.md`)

- Depende de `produtos`, `orcamentos`, `contatos`, `boletos`, `projeto_itens`, `projeto_parcelas`, `usuarios`, `systems` ou `user_system_access`? **Não.** O domínio Ubiqua é isolado (`revenda_ubiqua`, `empresas`, `orcamentos_revenda_ubiqua`, `itens_orcamento_ubiqua`), sem FK pro banco central (mesma decisão de isolamento da SPEC-036).
- Afeta CRM, Orçamentos, Financeiro, Cadastro, Estoque/Compras, Logística, RH ou Hub/TI (centrais)? **Não** — só o sistema-satélite Catálogo Ubiqua.
- Existe dado duplicado que deveria ser derivado por relacionamento? O estoque somado no card é derivado (calculado no front, não gravado); nenhuma coluna nova duplica dado existente.
- Existe migration antiga contradizendo o snapshot central? A `vw_catalogo_unificado`, criada por uma migration local do submodule (fora do fluxo central), já resolve o agrupamento em SQL mas está sem uso — não contradiz nada, só ficou obsoleta/esquecida.
- Exige atualizar `AI_DB_CONTEXT.md` do sistema? Sim — documentar que a chave de agrupamento do catálogo é `referencia` (não `descrição+preço`), e citar `vw_catalogo_unificado` como view existente mas não usada pelo front.

## Realizado

**2026-09-15** — Implementado no sistema `04-Sistemas/catalogo-pecas-ubiqua-e6fa0` (só front-end, sem migration, sem alteração no banco):

- `src/hooks/use-parts.ts`:
  - `groupCatalogItems()` agora agrupa por **referência normalizada** (`normalizeReferencia()`: `referencia.trim().toUpperCase().replace(/-IS$/i, '')`), não mais por `descrição+preço`. Peças V2 continuam separadas automaticamente (código numérico diferente, `-V2` preservado).
  - Filtro de órfãs adicionado: linhas sem sufixo `-IS`, sem estoque (`disponivel <= 0` ou nulo) e sem nenhuma irmã `-IS` no mesmo grupo de referência são removidas do array de itens antes do agrupamento (função calcula primeiro, por referência normalizada, se existe alguma linha `-IS` no grupo). As 8 linhas sem `-IS`/sem estoque que **têm** irmã `-IS` continuam entrando no grupo (contribuem 0 ao estoque somado), como pedia o critério de aceite.
  - Preço do card unificado (`valorRevenda`) e o novo `precoSugerido` (`GroupedPart.precoSugerido: number | null`, derivado de `vl_venda_produto`) agora usam **MIN** entre todas as linhas do grupo (calculado num passo final sobre `detalhesPorCor`, não mais "primeiro item vence") — mesmo critério que `vw_catalogo_unificado` já usa para `valor_revenda`. Isso vale inclusive para a divergência real de R$109,36 em `332109` (assume o menor valor, R$624,91, conforme proposta da SPEC — pendente de confirmação do Vinicius antes de publicar).
  - `slug` do grupo agora deriva da referência normalizada (ex.: `339104`, `339204-v2`), não mais de descrição+preço — evita quebrar `/produto/:slug` para os pares unificados.
  - Observação técnica não pedida pela SPEC, só registrada para conhecimento: a tabela `revenda_ubiqua` tem uma coluna real `slug` (populada por trigger `trigger_update_revenda_ubiqua_slug`, fórmula desc+preço, sem migration nesta SPEC). `useProductDetail()` tenta primeiro `.eq('slug', slug)` contra essa coluna real; como o slug do front mudou de fórmula, essa tentativa deixa de bater e o hook sempre cai no fallback já existente (busca todos os itens e re-agrupa em memória até achar o slug computado). Comportamento correto, só um pouco menos eficiente que antes — não é regressão funcional, não fixado por estar fora do escopo (exigiria mexer na coluna/trigger do banco).
- `src/components/PartCard.tsx`, `src/pages/ProductDetail.tsx`, `src/components/PartDetailSheet.tsx`: adicionado texto pequeno "Preço sugerido: R$ X" ao lado do preço de revenda, usando `vl_venda_produto` da linha selecionada (ou `precoSugerido` do grupo como fallback) — não aparece quando o valor é nulo ou 0, sem lançar erro.
- Não alterado: `PartCard.tsx`/`QuantityModal.tsx` (seleção de cor/quantidade), `AdminCatalog.tsx` (agrupamento manual continua funcionando para casos que não batem por referência), banco de dados (nenhuma migration criada ou aplicada).

**Verificação de build/lint** (`04-Sistemas/catalogo-pecas-ubiqua-e6fa0`): `npm run build` (vite build) passou sem erros; `npm run lint` (oxlint) não aponta nenhum problema nos 4 arquivos alterados (avisos pré-existentes em outros arquivos não tocados por esta SPEC continuam). `npm run format:check` (oxfmt) reporta divergência em ~105 dos 108 arquivos do projeto, incluindo os 4 alterados — confirmado que essa divergência já existia **antes** desta mudança (`git stash` + `format:check` na baseline reproduz o mesmo número), ou seja, é drift pré-existente de configuração/versão do oxfmt no ambiente, não introduzido por esta implementação. Não rodei `oxfmt` sem `--check` para não reformatar o repositório inteiro fora do escopo desta SPEC.

**Working tree do submodule**: alterações feitas, não commitadas (só implementação, sem commit/push, conforme instrução).

**Teste ao vivo (2026-09-15, `npm run dev` + Chrome, vitrine real com dados de produção):**

- Contagem de cards na vitrine: **63** — bate exatamente com a conta esperada (74 grupos por referência − 11 órfãs = 63). Nenhum dos 11 códigos órfãos (`321401, 321402, 321304, 322106, 323201, 323203, 367101, 611302, 189203, 189306, 189343`) aparece na vitrine.
- Par com preço divergente `332109`/`332109-IS`: card unificado mostra **R$ 624,91** (o menor valor, Islight) e **28 disponível** — conferido contra o banco real via REST (`332109` Manoella `disponivel: null`, `332109-IS` Islight `disponivel: 28`, soma bate). Preço sugerido R$1.282,31 exibido corretamente.
- Par `339104`/`339104-IS`: card unificado mostra **14 disponível em VERDE SALVIA** — conferido contra o banco (Manoella `disponivel: 3` + Islight `disponivel: 11` = 14, mesmo preço R$652,00 nas duas, sem divergência).
- Slugs `/produto/332109` e `/produto/339104` (referência normalizada, sem `-IS`) resolvem corretamente para os cards unificados — confirma que o fallback de `useProductDetail()` cobre a mudança de fórmula do slug.
- Peças V2 (`339204-V2-IS`, `321404-V2-IS`, `321403-V2-IS`, `360209-V2-IS`, etc.) aparecem todas como cards próprios, separadas da versão normal.
- Preço sugerido aparece nos cards da vitrine e na página de produto quando `vl_venda_produto` está preenchido; ausente sem erro nos itens que não têm o campo (ex.: cabos carregadores).
- **Limite de quantidade testado ao vivo**: no card unificado `339104` (soma 14), cliquei "+" 20 vezes no modal de quantidade — travou em **11** (estoque da linha Islight escolhida, a de maior `disponivel` entre as duas), nunca passou de uma única empresa mesmo com o card mostrando a soma de 14. Comportamento correto, sem regressão.
- Login na vitrine exigiu autenticação (tela "Acesso ao Catálogo") — sem relação com esta SPEC, sistema já exigia login antes.

**Revisão (agente `revisor`, 2026-09-15):** nenhum achado crítico. Confirmou item a item: normalização de referência correta (`339204-V2-IS` → `339204-V2`), filtro de órfãs aplicado antes do agrupamento e order-independent (bate com a distribuição 19/11/8), MIN de preço calculado sobre o array completo do grupo (não par-a-par, não quebra com array vazio), `precoSugerido` null-safe nos 3 componentes, `PartCard.tsx`/`QuantityModal.tsx` sem mudança na lógica de seleção/estoque, build e lint limpos (rodados de novo pelo revisor). Achado 🟡: `supabase/AI_DB_CONTEXT.md` deste sistema tinha um guard-rail pré-existente ("não mexer em `groupCatalogItems()` sem decidir com o Vinicius qual fonte de planilha é autoritativa") que não tinha sido referenciado — a mudança desta SPEC é num eixo diferente (agrupamento por referência, decisão já tomada com o Vinicius na reunião de origem desta SPEC), então **não invalida a implementação**, mas o documento estava desatualizado. Corrigido: `AI_DB_CONTEXT.md` atualizado documentando a mudança de chave e deixando explícito que o conflito por `fonte_planilha1/2/3` (eixo do guard-rail original) continua em aberto, sem tratamento nesta SPEC.

## Pendências

- [ ] Confirmar com o Vinicius o que fazer com a divergência real de R$109,36 entre Manoella e Islight na referência `332109` antes de publicar a unificação (usar o menor valor é a proposta default, mas pode ser erro de cadastro).
- [ ] Obter a planilha nova do Sérgio (ou o nome exato da coluna de "produto ativo/inativo") para desenhar a SPEC de filtro de produto inativo — hoje `revenda_ubiqua` não tem nenhuma coluna equivalente, então esse pedido da reunião não está coberto por esta SPEC.
- [x] ~~Confirmar se `vl_venda_produto` é de fato o campo certo pra "preço sugerido"~~ — **CONFIRMADO em 2026-09-15** por cruzamento de dados: `revenda_ubiqua.vl_venda_produto` bate exatamente com `produtos.valor_venda` (tabela central) na mesma referência (ex.: `339104` → R$1.334,98 nas duas tabelas; `332109-IS` → R$1.282,31 nas duas). Isso confirma que é o campo que o Vinicius descreveu na reunião ("na tabela do sistema... valor total de venda"): a planilha que alimenta `revenda_ubiqua` já traz esse valor copiado da tabela `produtos` central no momento da importação. **Achado/risco não bloqueante:** essa cópia é estática — não existe trigger nem sync automático ligando as duas tabelas (`produtos` tem os triggers `trg_atualizar_preco_venda`/`trg_calculo_preco_venda` que recalculam `valor_venda` quando custo/margem mudam; `revenda_ubiqua.vl_venda_produto` não tem nada equivalente). Se o preço central mudar depois, o catálogo Ubiqua só vai refletir na próxima reimportação manual da planilha. Decisão do usuário: manter como está (usar `vl_venda_produto`), aceitando esse risco de desatualização entre importações — sem mudança de código.
- [x] **Lacuna achada e corrigida em 2026-09-15**: as 4 peças BLOK V2 (`100161-V2-IS`, `100162-V2-IS`, `100163-V2-IS`, `100164-V2-IS`) estavam com `vl_venda_produto` nulo em `revenda_ubiqua` — não é bug de código (o "não aparece quando nulo" é o comportamento correto), é lacuna de cadastro: o BLOK V2 nunca foi cadastrado na tabela central `produtos` (só existe lá o BLOK sem V2, `100161-IS` a `100164-IS`, com `valor_venda` de R$1.634,99 a R$1.788,24). Decisão do usuário: usar o preço do BLOK mais caro (R$1.788,24, acabamento mármore) como preço sugerido pras 4 linhas V2. Aplicado via `UPDATE` direto em `revenda_ubiqua.vl_venda_produto` (não dispara o trigger de slug, que só reage a `desc_produto`/`descricao`/`valor_revenda`). Não corrigido na tabela central `produtos` (ainda falta cadastrar o BLOK V2 lá — fora do escopo desta SPEC, fica como observação pro Sérgio/Vinicius).
- [ ] Decidir se as 11 peças órfãs (e as 8 que somem dentro do grupo) devem só sumir da vitrine (filtro de leitura) ou ser removidas fisicamente de `revenda_ubiqua` — esta SPEC assume filtro de leitura (mais seguro, reversível, não quebra FK de orçamentos antigos que referenciem essas linhas).
