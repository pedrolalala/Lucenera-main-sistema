---
titulo: "SPEC-193 — Reunião 09/10 (Vinícius e Filippo): impostos no custo, limpeza do cadastro de produto e estoque separado"
status: aprovada com respostas (09/10) — aguardando início da implementação
data_ultima_modificacao: 2026-10-09
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

- [ ] **A1. Registrar o que cada coluna de imposto quer dizer** no cadastro (texto de ajuda nos campos, sem mudar a
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

- [ ] **B1.** Categoria visível pelo `categoria_id` em todo lugar que mostra produto. Conferir as categorias erradas:
  na reunião a "Fly arandela indireta" apareceu com categoria duvidosa.
- [ ] **B2. A marca manda no fornecedor (decidido 09/10).** O fornecedor do produto é sempre o `marcas.fornecedor_id`
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
- [ ] **B4. Lucro fica em % como hoje (decidido 09/10).** É o "Lucro" da Connect aplicado sobre o custo total
  (`valor_venda = custo_total × (1 + Lucro%)`, ex. 46,46 × 2,5209 = 117,12). Sem campo de markup a mais. Só ajustar o
  rótulo/ajuda para "% Lucro (sobre o custo total)".

### Bloco C — Estoque separado do cadastro de produto

O pedido do Filippo e do Vinícius: a consulta de estoque não pode "ler tudo" do produto (impostos, fiscal etc.). Ela
precisa de uma estrutura enxuta, mais rápida e com menos chance de erro.

- [ ] **C1. Estrutura só de estoque**: id do produto, estoque total, showroom, disponível e os setores (reserva,
  separação, entrega futura…). Entram **só as peças com saldo diferente de zero**. No banco isso já existe em parte
  (`estoque_itens`, `vw_cadastro_produto_setores`); o trabalho é ter **uma view única de consulta** que junte
  isso com código, referência, descrição e preço de venda, e mais nada.
- [ ] **C2. Duas formas de ver o produto:**
  - **Consulta de Produtos** (as meninas, na hora de orçar): código, referência, descrição, preço de venda e
    setores/disponível. **Sem impostos.**
  - **Cadastro de Produto** — **decidido 09/10: só a Administração vê custo e impostos: Lana, Débora, Carol, Matheus e
    Vinícius** (+ Pedro/Filippo como suporte do sistema, igual à Produção). Quem não está na lista vê só a Consulta.
    Mesmo modelo da SPEC-191: tabela por e-mail + função `SECURITY DEFINER`; os campos de custo/imposto não podem
    sair do banco para quem não está na lista (não basta esconder na tela).
- [ ] **C3.** Medir o tempo de carregar a Consulta antes e depois. Hoje ela busca a tabela `produtos` inteira em lotes
  de 500 com o estoque embutido.
- [ ] **C4.** Usar a estrutura nova na Consulta do Cadastro e na busca de peça do Orçamento.

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

(nada ainda — SPEC criada em 09/10/2026 a partir da transcrição. Os números da tabela do Bloco B foram conferidos no
banco no mesmo dia.)
