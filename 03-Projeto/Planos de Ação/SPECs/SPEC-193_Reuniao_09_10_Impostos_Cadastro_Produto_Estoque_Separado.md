---
titulo: "SPEC-193 — Reunião 09/10 (Vinícius e Filippo): impostos no custo, limpeza do cadastro de produto e estoque separado"
status: em implementação — passos 1 a 4 (C2, A1/B4, B1, B3 etapa 1, B2, C1/C3/C4) feitos em 12/10; falta B3 etapa 2
data_ultima_modificacao: 2026-10-12
origem: "02-Reunioes/29. Lucenera (Vinicius e Filippo) - 09.10.2026_ Imposto e Regras/Reunião.01"
sistemas_envolvidos:
  - Cadastro Lucenera — Cadastro e Consulta de Produtos (cadastro-lucenera-b86fe, Skip 36668)
  - Orçamentos (consulta de peça na hora de orçar)
  - scripts/importar_produtos_estoque.py (planilha diária de produtos da Connect, enviada pelo Sérgio)
  - Supabase (produtos, categorias_produto, marcas, contatos, estoque_itens, vw_cadastro_produto_setores)
  - Administração Bancária (só registro — vira SPEC própria)
---

# SPEC-193 — Reunião 09/10 (Vinícius e Filippo): impostos, cadastro de produto e estoque

> **Fora do escopo e intocável:** a regra de custo e venda da SPEC-190 continua valendo do jeito que está:
> Preço de Custo − % Desconto = Custo c/ Desconto; + BDI (% Frete + % ST + % IPI + % Outras Despesas, calculados
> sobre o custo c/ desconto) = Custo Total; × (1 + % Lucro) = Preço de Venda. Esta SPEC não muda essa conta.

## Decisão da reunião (Filippo)

Não vamos montar agora um motor de regras fiscais (ST calculada por NCM × regime do fornecedor × empresa que fatura ×
estado). Filippo: *"é extremamente complexo… não basta IA"* e *"ter o preço certo do produto é já 90%, 95% do que
precisamos"*. Continua **como está hoje**: cada produto já vem com os seus impostos (% ST, % IPI, % Outras
Despesas), que o fornecedor informa, e o sistema só faz a conta da SPEC-190. A apuração fiscal fica com o Marcos
(contador), que trabalha pelos XML das notas.

O que muda é **deixar o cadastro de produto limpo e certo** e **separar o estoque** da planilha de produto.

## Checklist de Ação

### Bloco A — Impostos no custo (registro e uso)

- [x] **A1. Registrar o que cada coluna de imposto quer dizer** no cadastro (texto de ajuda nos campos, sem mudar a
  conta). **Decidido 09/10: o nome "% Outras Despesas" NÃO muda** (fica igual à Connect); entra só o texto de ajuda:
  - **% ST**: substituição tributária destacada na nota. O fornecedor recolhe antes e a Lucenera paga junto com a nota.
  - **% Outras Despesas**: na prática é o **ICMS que a Lucenera recolhe por fora no fim do mês** (não vem destacado na
    nota). Exemplo da Stella (SC → SP): crédito de 4% na compra e 18% na venda em SP, o que dá ~14% embutidos no custo.
  - **% IPI** e **% Frete**: como vêm do fornecedor.
- [ ] **A2. Exceção Interlight (só registrar, não implementar).** O mesmo NCM tem ST de **25,38% faturado para a
  ISLIGHT** e **15,48% para Manoella/Foco**. Hoje o cadastro usa sempre a maior. Há duas ideias, ambas para depois:
  1. vender certas marcas só por uma empresa;
  2. um orçamento único que gera **duas notas fiscais**, uma por empresa.
  O preço por empresa (dois preços de venda para a mesma peça) **não** entra agora.
- [ ] **A3. Reunião com o Marcos** (Vinícius marca) para "pôr o ponto no i" das regras fiscais. Pedir a ele a
  **memória de cálculo** que ele já manda ao Vinícius, para no futuro o sistema conferir a apuração dele. Esse item
  depende de outra pessoa; não há código nesta SPEC.

### Bloco B — Cadastro de produto: dados faltando e colunas duplicadas

Números conferidos no banco em 09/10 (4.537 produtos ativos):

| Coluna | Situação hoje | O que fazer |
|---|---|---|
| `categoria` (texto) | **0 preenchidos**; `categoria_id` está em 4.536 | Na tela e nas exportações, mostrar o nome vindo de `categoria_id` (a reunião viu a coluna vazia). Avaliar remover `categoria` texto. A categoria é **essencial porque a RT é calculada em cima de "Luminária"**. |
| `fornecedor_principal_id` | **1 preenchido** | A planilha da Connect traz `CodFornecedor`/`nmFornecedor`: o import passa a gravar o fornecedor (casando com `contatos` tipo fornecedor). Hoje há fornecedor via marca em 4.029 produtos. |
| `referencia` | 4.502 preenchidos | Conferir os 35 que estão vazios (a 10539 tem referência no banco; na reunião não apareceu, ver se é só a tela). |
| `codigo_legado` × `codigo_produto` | **iguais em 4.352** | Coluna duplicada. Manter `codigo_produto`, parar de exibir `codigo_legado` e avaliar a remoção depois de conferir quem lê a coluna. |
| `sku` × `referencia` | **iguais em 4.317 de 4.318** | Também duplicada. Mesmo tratamento. |
| `percentual_lucro` × `margem_lucro` | **mesmo dado** (coluna `Lucro` da planilha): `percentual_lucro` é numeric(9,2) e `margem_lucro` tem 4 casas, por isso "nunca iguais"; arredondando, batem em 4.531 de 4.537 | Fica só `margem_lucro` (a usada na conta da SPEC-190). `percentual_lucro` sai. |
| `descricao_tecnica` | 2 preenchidos | Fica como está. Ideia para depois (Pedro/Vinícius): usar como descrição curta para o cliente. |
| `multiplo_compra` | tudo = 1 | Fica (é configuração da Connect, necessária para emitir nota). Ver Bloco D. |

- [x] **B1.** Categoria visível pelo `categoria_id` em todo lugar que mostra produto. Conferir as categorias erradas:
  na reunião a "Fly arandela indireta" apareceu com categoria duvidosa.
- [x] **B2. A marca manda no fornecedor (decidido 09/10).** O fornecedor do produto é sempre o `marcas.fornecedor_id`
  da marca dele (4.526 produtos têm marca). O import **não** grava fornecedor por produto; usa `CodFornecedor`/
  `nmFornecedor` da planilha só para gerar uma lista de conferência: (a) marcas sem fornecedor cadastrado, com o
  fornecedor que a planilha sugere; (b) produtos onde a planilha diz outro fornecedor que o da marca. Nada é gravado
  automaticamente. `fornecedor_principal_id` (1 preenchido) entra no levantamento do B3 como coluna a remover.
- [ ] **B3. Colunas duplicadas saem do banco (decidido 09/10)**, em duas etapas:
  1. **Front-end primeiro:** tudo que hoje mostra/busca/ordena por `produtos.codigo_legado` passa a usar
     **`referencia`** (pedido do usuário). O mesmo para `sku` → `referencia`, `percentual_lucro` → `margem_lucro` e
     `categoria` texto → nome de `categoria_id`. Publicar todos os sistemas afetados.
  2. **Banco depois:** recriar as views/funções que ainda leem as colunas e só então `DROP COLUMN` (migration com
     dry-run e rollback, aplicada com aprovação).
  Atenção: `contatos`, `funcionarios` e `marcas` também têm `codigo_legado` — esses **não** entram; só `produtos`.

  Levantamento feito em 09/10 (só `produtos`):

  | Coluna | Front-end | Banco |
  |---|---|---|
  | `codigo_legado` (= `codigo_produto` em todos os 4.352 preenchidos; 185 nulos) | Cadastro: `Pecas.tsx` (fallback do código), `PecaDetailsPanel.tsx`, `services/produtos.ts`; Showroom: `FotosEstoqueTab.tsx` ("Cód. legado"), `curadoria.ts`, `curadoriaEstoque.ts`, `ComposicaoConjuntoModal.tsx`; Orçamento: `useBudgetStore.ts`, `use-options.ts` (lista de produtos) | funções `showroom_buscar_produto`, `showroom_listar_produtos_estoque`, `showroom_obter_composicao` |
  | `sku` (= `referencia`) | Orçamento (`AsyncProductSelect`, `ProductSearchModal`, `BudgetFormPage`, `productCatalogService`…), Cadastro (`PecaForm`, `GlobalSearch`), Compras (`estoque-produtos.ts`, `notas-fiscais-compra.ts`), Vendas (`Vendas.tsx`, DANFE, payload da NF-e), Garantia | views `vw_estoque_liquido`, `vw_estoque_produtos`, `vw_produtos_estoque_detalhado`, `vw_vendas_loja`, `vw_vendas_produtos`; funções `buscar_produtos_fuzzy`, `garantia_buscar_produtos`, `get_next_sku`, `criar_produto_orcamento` |
  | `percentual_lucro` | — | `scripts/importar_produtos_*.py`; fallback em `criar_produto_orcamento` |
  | `categoria` texto (0 preenchidos) | a conferir | views `vw_estoque_liquido`, `vw_showroom_publico`, `vw_vendas_loja`, `vw_vendas_produtos` |

  O `sku` aparece na **nota fiscal** (Focus NFe, código do produto) — trocar por `referencia` só depois de conferir
  que a referência nunca vem vazia nesses itens (hoje 35 produtos estão sem referência; ver linha `referencia`).
- [x] **B4. Lucro fica em % como hoje (decidido 09/10).** É o "Lucro" da Connect aplicado sobre o custo total
  (`valor_venda = custo_total × (1 + Lucro%)`, ex. 46,46 × 2,5209 = 117,12). Sem campo de markup a mais. Só ajustar o
  rótulo/ajuda para "% Lucro (sobre o custo total)".

### Bloco C — Estoque separado do cadastro de produto

O pedido do Filippo e do Vinícius: a consulta de estoque não pode "ler tudo" do produto (impostos, fiscal etc.). Ela
precisa de uma estrutura enxuta, mais rápida e com menos chance de erro.

- [x] **C1. Estrutura só de estoque**: id do produto, estoque total, showroom, disponível e os setores (reserva,
  separação, entrega futura…). Entram **só as peças com saldo diferente de zero**. No banco isso já existe em parte
  (`estoque_itens`, `vw_cadastro_produto_setores`); o trabalho é ter **uma view única de consulta** que junte
  isso com código, referência, descrição e preço de venda, e mais nada.
- [x] **C2. Duas formas de ver o produto:**
  - **Consulta de Produtos** (as meninas, na hora de orçar): código, referência, descrição, preço de venda e
    setores/disponível. **Sem impostos.**
  - **Cadastro de Produto** — **decidido 09/10: só a Administração vê custo e impostos: Lana, Débora, Carol, Matheus e
    Vinícius** (+ Pedro/Filippo como suporte do sistema, igual à Produção). Quem não está na lista vê só a Consulta.
    Mesmo modelo da SPEC-191: tabela por e-mail + função `SECURITY DEFINER`; os campos de custo/imposto não podem
    sair do banco para quem não está na lista (não basta esconder na tela).
- [x] **C3.** Medir o tempo de carregar a Consulta antes e depois. Hoje ela busca a tabela `produtos` inteira em lotes
  de 500 com o estoque embutido.
- [x] **C4.** Usar a estrutura nova na Consulta do Cadastro e na busca de peça do Orçamento.

### Bloco D — Caixa fechada / múltiplo de compra (levantamento)

- [ ] **D1.** Levantar quais fornecedores só vendem em caixa fechada, com qual quantidade e qual desconto. A reunião
  citou **Stella** (lâmpada só em caixa fechada), **LED Vance/Brilia** e o desconto de caixa fechada da
  **Interlight (25%)**. Fonte: fornecedores e a Carol. Depois disso, preencher `multiplo_compra`.
  - O "50%" visto na planilha é da **Cris Bertolucci** (50% sobre a tabela); não é caixa fechada.

### Bloco E — Rotinas de conferência (processo, sem código agora)

- [ ] **E1.** Chegou nota fiscal: a **Vitória confere o NCM** do produto. Regra do Vinícius por pelo menos 6 meses,
  porque houve várias mudanças de NCM de agosto para cá.
- [ ] **E2.** Chegou nota fiscal: a **Débora confere o preço de custo e os impostos**.
- [ ] **E3. (ideia)** O sistema pode ajudar comparando, na entrada da nota, o NCM e os percentuais da nota com os do
  cadastro e avisando a diferença. Só depois do Bloco B.

### Bloco F — Administração Bancária (próximo assunto; vira SPEC própria)

- [ ] **F1.** O Vinícius vai mandar um áudio ou vídeo com o passo a passo do contas a pagar/receber. Dor já citada:
  **baixar 3 contas juntas e precisar estornar uma só**. Na Connect, o estorno desfaz as três; no sistema, tem que dar
  para estornar só aquela. Também falta mapear os campos que não estavam nas fotos da Lana. Primeiro a estrutura
  principal, depois os ajustes.

## Respostas do usuário (09/10)

1. **Nome de "% Outras Despesas":** não muda. Só texto de ajuda (A1).
2. **Colunas duplicadas:** saem do banco, mas antes tudo no front-end que usa `codigo_legado` passa para `referencia`
   (B3).
3. **Lucro:** fica em % como está (B4).
4. **Quem vê impostos:** só a Administração: Lana, Débora, Carol, Matheus e Vinícius (C2).
5. **Fornecedor:** a marca sempre manda (B2).

## Ordem de implementação proposta

1. C2 (permissão de custo/impostos) + A1/B4 (textos de ajuda): Cadastro.
2. B1 (categoria por `categoria_id`) + B3 etapa 1 (front-end → `referencia`/`margem_lucro`): Cadastro, Orçamento,
   Showroom, Compras, Vendas, Garantia.
3. B2 (lista de conferência marca × planilha) no import.
4. C1/C3/C4 (view enxuta de estoque, medir tempo, usar no Orçamento).
5. B3 etapa 2 (views/funções + `DROP COLUMN`), com aprovação.

## Realizado

SPEC criada em 09/10/2026 a partir da transcrição (números do Bloco B conferidos no banco no mesmo dia).

### 12/10/2026 — Passo 1: C2 (custo/impostos só para a Administração) + A1/B4 (textos de ajuda)

- **Banco, migration 202** (`20261012_202_spec193_custo_produto_visao_restrita`, só acrescenta): tabela
  `produto_custo_visualizadores` (Lana/financeiro@, Débora, Carol, Matheus, Vinícius, Pedro nos 2 e-mails, Filippo),
  função `pode_ver_custo_produto()` (SECURITY DEFINER; sem JWT/service_role = true), view `vw_produtos_custo` (id + 13
  colunas de custo/imposto, vazia para quem não está na lista) e coluna gerada `produtos.tem_st` (porc_st > 0).
- **Sistemas publicados** antes de fechar o banco (nenhuma Edge Function redeployada, conferido antes/depois):
  - Cadastro 36668 v0.0.102: `produtos` lido com lista de colunas (sem `*`); custo do Editar vem de
    `vw_produtos_custo`; quem não é da Administração vê só o Preço de Venda e o aviso "Custo e impostos ficam visíveis
    só para a Administração", e o Salvar não envia custo/impostos/preço (não zera o que a Administração gravou).
    A1/B4: (i) com texto de ajuda em % Frete, % ST, % IPI, % Outras Despesas (= ICMS recolhido por fora no fim do
    mês, exemplo da Stella) e rótulo "% Lucro (sobre o custo total)". Nome "% Outras Despesas" mantido.
  - Orçamentos 32554 v0.0.386: Gerenciamento lê custo por `vw_produtos_custo` (aviso para quem não é da
    Administração, ex.: Mariane); resumo fiscal usa `tem_st`.
  - Vendas 59346 v0.0.20: CFOP do espelho da DANFE usa `tem_st`. A emissão real (Edge Function, service_role) não muda.
  - Compras 40326 v0.0.83: custo/ICMS/IPI/ST do pedido por `vw_produtos_custo` (todos os usuários de Compras estão
    na lista).
- **Banco, migration 203** (`20261012_203_spec193_fechar_custo_produto`, gerada das definições reais, com rollback):
  `REVOKE SELECT ON produtos FROM authenticated` + `GRANT SELECT (33 colunas sem custo)`; nova
  `vw_produtos_custo_restrito` (todas as colunas, custo nulo fora da lista, filtro por sistema) usada pelas 8 views que
  liam custo: `v_estoque_produtos`, `vw_estoque_liquido`, `vw_estoque_produtos`, `vw_necessidade_compra`,
  `vw_necessidade_compra_item_orcamento`, `vw_produtos_estoque_por_local`, `vw_vendas_loja`, `vw_vendas_produtos`.
- **Teste (ROLLBACK e depois real)**: Débora/Vinícius continuam com 245/245 custos na Necessidade de Compra e o
  valor de estoque no Dashboard (R$ 4,2 mi); Mariane, Marina e João veem as mesmas linhas com custo vazio; leitura
  direta de `preco_custo` ou `*` em `produtos` = negada para todos os logins; atualizar peça continua funcionando;
  sem login = 401; Showroom público intacto. Views em 0,14–0,28 s.
- **Fica para os próximos passos**: B1, B3 (o campo "Referência" do Editar ainda grava em `sku`), B2, C1/C3/C4 e B3
  etapa 2. Não verificado na tela (extensão do navegador fora); conferir com login da Administração e de uma
  projetista.

### 12/10/2026 — Passo 2: B1 (categoria por `categoria_id`) + B3 etapa 1 (telas usam `referencia`)

- **Cadastro 36668 v0.0.103**: o campo "Referência" do Editar/Nova peça agora grava em `referencia` (antes gravava em
  `sku`; quem editava a referência mudava só a cópia). A checagem "Em uso" passa a ser pela referência. Até a etapa 2,
  o Salvar também copia a referência para `sku`, para a cópia não ficar desatualizada. Lista e painel da peça sem
  fallback para `codigo_legado`/`sku`; categoria sempre o nome de `categoria_id`. Busca sem `sku`.
- **Orçamentos 32554 v0.0.387**: nenhuma leitura de `produtos.sku`/`codigo_legado`; os rótulos "SKU: …" saíram (fica
  "Ref: …"); "Código de Referência" do item e a coluna "Referência" da busca vêm de `referencia`; import de planilha
  casa só pela referência.
- **Showroom 54698 v0.0.20**: "Cód. legado" saiu do /admin (era igual ao código da peça); fica "Ref.".
- **Compras 40326 v0.0.84**: "SKU:" virou "Ref:" no estoque; buscas sem `sku`.
- **Garantia 60545 v0.0.13**: a busca de peça mostra a referência.
- **Vendas 59346 v0.0.21**: o espelho da nota usa referência → código (sem `sku`).
- Nenhuma Edge Function redeployada (conferido antes/depois). Dados: `referencia` cobre tudo o que `sku` tinha (0
  peças com `sku` e sem referência; 184 recentes com referência e `sku` vazio); 1 referência repetida
  (`3651-FE-S-PX`, a peça "EMBUTIDO de teste").
- **Ainda leem as colunas (etapa 2, no banco)**: funções `buscar_produtos_fuzzy`, `garantia_buscar_produtos`,
  `get_next_sku`, `criar_produto_orcamento` (grava `sku`/`percentual_lucro`), `showroom_*` (devolvem `codigo_legado`);
  views `vw_estoque_liquido`, `vw_estoque_produtos`, `vw_produtos_estoque_detalhado`, `vw_vendas_loja`,
  `vw_vendas_produtos` (essas 3 últimas + `vw_estoque_liquido` ainda mostram `categoria` texto, sempre vazia — trocar
  pelo nome de `categoria_id`); Edge Function `emitir-nota-fiscal` (lê `sku`, mas usa referência antes) e os scripts
  `importar_produtos_*.py`.
- **B1, conferência de dados** (não alterado, decisão de negócio): 6 peças sem categoria (4 lâmpadas Philips e 2
  cadastros de carro: BMW 320i e Outlander); 83 peças em LUMINARIA cujo nome começa com PERFIL (73), DRIVER, LAMPADA ou
  FONTE — como a RT é calculada sobre Luminária, vale revisar. A "Fly arandela indireta" da reunião não foi achada
  pelo nome (há "TORUS FLY" e "FLYING", todas LUMINARIA).

### 12/10/2026 — Passo 3: B2 (lista de conferência marca × fornecedor)

- Script novo `scripts/conferencia_marca_fornecedor.py`, que roda sozinho e também no fim de
  `importar_produtos_estoque.py` (se falhar, não afeta o import). Só lê a planilha e o banco (conexão somente
  leitura); nada é gravado. Gera `scripts/logs/conferencia_fornecedor/conferencia_marca_fornecedor_<data>.xlsx`
  com as abas Resumo, Marcas sem fornecedor, Marca x planilha e Peças com outro fornecedor.
- `contatos` não tem o código da Connect: o fornecedor da planilha é casado pelo nome (sem acento/LTDA/EPP/ME);
  contatos duplicados com o mesmo nome contam como o mesmo fornecedor (há vários: STELLA, ACEND, TENSOFLEX, LA LAMPE,
  KLAXON, NORTEL, SWELL, FIGUEIREDO NUNES).
- Resultado da planilha de 07/10:
  - **45 marcas sem fornecedor** no sistema; 37 têm peças na planilha, com sugestão (ex.: DSGNSELO → Design Selo,
    BRILIA → Swell, ZAFFERANO → Zaff Light, EXPORLUX → Lunarte, ARTEMIDE → Figueiredo Nunes, PIULUCE → Boseli).
    TARGETTI e MUNDIAL LUX: fornecedor sugerido não está cadastrado.
  - **9 marcas** em que o fornecedor da planilha é outro: EKLART (sistema "EKLART 2", planilha LHP Distribuidora,
    225 peças), LUCENERA (planilha FM Indústria, 168 de 293), BERTOLLUCI (C Bertolucci × Cristiana Bertolucci),
    LEMCA (dois nomes), METALSPOT (Bella Luce × Emmetre), ACCORD (Fábrica Accord × LC Martinkoski), FLOS (Flos SpA ×
    Lucenera), NEW LINE (× GNL), WENTZ (× Luxion).
  - **944 peças** com fornecedor diferente do da marca — quase todas dessas 9 marcas. A marca LUCENERA (peças de
    fabricação própria) tem peças de vários fornecedores de matéria-prima (FM, Agmatec, Ribertubo, Dimetal...): a regra
    "a marca manda" talvez não sirva para ela — decidir com o Vinícius.

### 12/10/2026 — Passo 4: C1/C3/C4 (consulta de estoque enxuta)

- **Banco, migration 204** (`20261012_204_spec193_vw_consulta_estoque`, só acrescenta; rollback = `DROP VIEW`):
  view `vw_consulta_estoque` (security_invoker, sem anon) com uma linha por peça: código, referência, descrição,
  ativo, preço de venda, marca/categoria (nome e id, para filtro) e os saldos já calculados — Geral, reserva e
  separação do sistema, reserva da Connect, comprometido (o maior dos dois), Disponível, Showroom, `tem_saldo`.
  Nada de custo, imposto ou fiscal. Conferida peça a peça contra a conta da tela (`calcularDisponivel`): 4.911 peças,
  0 diferenças; 2.008 com saldo. Por login (Débora, Mariane, Marina, Vitória): mesmas linhas, 0,15–0,34 s no banco;
  sem login = negado.
- **C3, tempo de carregar a Consulta** (mesmas chamadas da tela pela API, mediana de 3):
  | | Antes (tabela `produtos` + estoque embutido, conta na tela) | Depois (`vw_consulta_estoque`) |
  |---|---|---|
  | Abrir a Consulta ("Só com estoque", padrão) | 6,1 s, 2,2 MB (baixava as 4.911 e filtrava na tela) | **1,7 s**, 0,8 MB (2.008 peças, filtro no banco) |
  | Desligar "Só com estoque" (todas) | 6,1 s | **2,6 s**, 1,9 MB |
  | Busca do Orçamento ("spot", 50 peças) | 1,05 s | 0,93 s (o peso é a busca por texto) |
- **C4**: Cadastro 36668 v0.0.104 — a Consulta de Produtos lê a view (o filtro "Só com estoque" vai para o banco; com
  busca continua mostrando todas). Orçamentos 32554 v0.0.388 — a busca de peça lê Estoque/Disponível da view em vez
  de `vw_detalhe_produto_estoque`. **Muda número no Orçamento**: antes o Disponível da busca era só
  `quantidade − reserva da Connect`; agora é o mesmo do Cadastro (conta também a reserva/separação feitas no
  sistema). 292 peças mudam; em 250 o que aparecia disponível passa a zero ou negativo. Nenhuma Edge Function
  redeployada.
- Não verificado na tela (sem navegador): conferir a Consulta abrindo e o filtro "Só com estoque".

### 12/10/2026 — Passo 5 (preparado, NÃO aplicado): B3 etapa 2 — colunas duplicadas saem de `produtos`

- **Migration 205** (`20261012_205_spec193_colunas_duplicadas_produtos`, gerada das definições reais por script):
  - `001_redefinir_leitores.sql`: tudo que ainda lia as colunas passa a ler a que fica, **mantendo nomes e tipos**
    (nenhum sistema percebe): `buscar_produtos_fuzzy`, `garantia_buscar_produtos` (sku ← referencia),
    `showroom_listar_produtos_estoque`, `showroom_obter_composicao`, `showroom_buscar_produto` (codigo_legado ←
    codigo_produto), `criar_produto_orcamento` (não grava mais sku), views `vw_produtos_custo_restrito` (base das 8
    views de estoque/compra/vendas), `vw_produtos_custo`, `vw_showroom_publico`, `vw_produtos_estoque_detalhado`
    (categoria ← nome de categoria_id, percentual_lucro ← round(margem_lucro, 2)). `get_next_sku` sai.
  - `002_remover_colunas.sql`: cópia de segurança `_bkp_spec193_produtos_colunas`; `DROP COLUMN` de
    `codigo_legado`, `percentual_lucro` e `categoria`; **`sku` vira coluna gerada = referencia (só leitura)** —
    o PDF do orçamento (Edge Function `generate-report`, com cópia em 9 sistemas e rodando com o login do usuário) e a
    emissão de NF-e ainda pedem `sku`; assim continuam funcionando e ninguém consegue gravar valor diferente.
  - `rollback.sql`: devolve as 4 colunas com os dados da cópia, índices/constraints/grants e as definições originais.
  - **Fica para depois**: `fornecedor_principal_id` (o campo "Fornecedor" do Cadastro ainda grava nele — junto com a
    decisão do B2).
- **Ensaio (transação desfeita, 0,8 s)**: 24 views que dependem de `produtos` com as mesmas linhas e os mesmos
  valores fora das 4 colunas; funções com o mesmo número de resultados; PDF do orçamento (nome/referencia/sku) ok
  com login da Mariane; ler `codigo_legado` = erro (esperado); Salvar do Cadastro **de hoje** (envia sku) = erro →
  o Cadastro precisa ser publicado antes; Salvar sem sku = ok; criar peça pelo Orçamento ok (antes aceitava sku
  diferente da referência, depois sku = referência); `vw_vendas_produtos` passa a mostrar a categoria. Rollback
  rodado no mesmo ensaio: 0 peças diferentes do original e as 24 views idênticas.
- **Dados que se perdem**: nenhum. `codigo_legado` = `codigo_produto` em todas; `categoria` texto vazia;
  `percentual_lucro` difere de `margem_lucro` só por arredondamento (6) ou por estar zerado (369).
- **Fora do banco, já feito (funciona antes e depois)**: `importar_produtos_estoque.py` e `importar_produtos_novos.py`
  deixam de gravar `percentual_lucro` (o novo passa a gravar `margem_lucro`); dry-run do import ok.
- **Ordem para aplicar (com aprovação)**: (1) publicar o Cadastro sem enviar `sku` no Salvar; (2) aplicar 001 + 002
  numa transação; (3) recarregar o cache da API e conferir Consulta, busca do Orçamento, PDF e Showroom.
