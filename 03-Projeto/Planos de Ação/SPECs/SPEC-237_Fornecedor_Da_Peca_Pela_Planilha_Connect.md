---
titulo: "SPEC-237 — Fornecedor da peça a partir da planilha da Connect (vínculo produto-fornecedor + fornecedor principal)"
status: no ar
data_ultima_modificacao: 2026-10-28
sistemas_envolvidos:
  - Banco (Supabase SP) — produto_fornecedores, produtos.fornecedor_principal_id, contatos (fornecedor)
  - Cadastro (cadastro-lucenera-b86fe) — edição de peça (PecaForm) mostra o fornecedor
---

# SPEC-237 — Fornecedor da peça a partir da planilha da Connect

> Origem: pedido do usuário em 28/10/2026 ("Fornecedor ausente na edição de produto + popular vínculo
> produto-fornecedor"). Relacionadas: SPEC-235 E (fornecedor na consulta, pela marca), SPEC-094 (filtro por fornecedor
> no Orçamento lê `produto_fornecedores`).

## Checklist de Ação

- [x] Levantar o schema real e casar os fornecedores da planilha com o cadastro.
- [x] Migration 257: vínculos em `produto_fornecedores` + `produtos.fornecedor_principal_id` onde vazio + gatilho.
- [x] Edição de peça carregando o fornecedor no campo.
- [x] Aplicar a migration 257 — aplicada 28/10 (4.303 vínculos, 4.305 principais, gatilho ativo).
- [x] Publicar o Cadastro (`55cc11a`). Falta conferir a edição de uma peça na tela.
- [ ] Cadastrar TARGETTI e MUNDIAL LUX (com CNPJ) e escolher a filial da NORTEL — depois rodar o vínculo das 39 peças.

## Estado encontrado (28/10)

- Os nomes do pedido não existem: no banco são `produtos`, `contatos` (tipo `fornecedor`, 357) e `produto_fornecedores`.
  A tabela `fornecedores` existe mas está vazia e não é usada.
- `produto_fornecedores` (id, produto_id → produtos, fornecedor_id → **contatos**, codigo_fornecedor, custo_unitario,
  prazo_entrega_dias, qtd_minima, unidade, ativo, observacao, criado_em, atualizado_em; único por produto+fornecedor):
  **vazia**, **sem marca de "principal"**. Só o filtro de fornecedor da busca de peças do Orçamento e o Compras a leem.
- O "fornecedor principal" é a coluna que já existe `produtos.fornecedor_principal_id` (→ contatos). É ela que a
  **edição de peça** (Cadastro, `PecaForm`) mostra e grava — vazia em 4.916 de 4.918 peças. Só preencher o vínculo não
  faria o fornecedor aparecer na edição.
- Fornecedores do banco não têm o código da Connect (`codigo_legado` vazio) → casamento por nome.
- Vários fornecedores estão cadastrados mais de uma vez com CNPJs diferentes (filiais / empresas com o mesmo nome
  fantasia): Stella, Acend, Swell (3), Tensoflex, La Lampe, Klaxon, Figueiredo Nunes, Martinkoski, Nortel, Bella.

## Decisões aprovadas (usuário, 28/10)

- Gravar o vínculo em `produto_fornecedores` **e** o principal em `produtos.fornecedor_principal_id` (coluna que já
  existe; nenhuma coluna nova).
- Filiais: escolher o fornecedor da marca da peça; senão o cadastro com pedido/NF; senão a matriz (/0001); senão o
  único com CNPJ. O que não resolver fica sem.
- TARGETTI e MUNDIAL LUX (sem cadastro): deixar sem e reportar.

## Definição

- Planilha: `01-Documento/01 - Planilhas/Produtos__2026-10-14.xlsx`, colunas CodProduto e nmFornecedor.
- Casamento: nome sem acento/pontuação e sem LTDA/ME/EPP/EIRELI/SA/COMERCIO/DE..., contra nome, razão social e nome
  fantasia do contato.
- Resultado: **4.303 peças** (3.601 pelo nome, 627 pela marca, 75 pela matriz). Ficam sem: 201 sem fornecedor na
  planilha, 38 com fornecedor não cadastrado (TARGETTI 36, MUNDIAL LUX 2), 1 NORTEL (duas filiais sem matriz),
  1 código da planilha que não existe no banco. Nenhum principal já preenchido diverge da planilha.
- **Migration 257** `20261028_257_spec237_produto_fornecedor_planilha`:
  1. `produto_fornecedores`: 1 vínculo por peça (`ON CONFLICT DO NOTHING`), `observacao` = "SPEC-237: planilha
     Produtos da Connect (14/10/2026), nmFornecedor" (o rollback apaga por ela).
  2. `produtos.fornecedor_principal_id` só onde está vazio.
  3. Gatilho `trg_produto_fornecedor_principal_vinculo`: trocar o fornecedor principal na edição cria o vínculo.
  - Risco conferido: o UPDATE em `produtos` dispara `trg_calculo_preco_venda` (recalcula preço em todo UPDATE). No
    dry-run nenhuma coluna além de fornecedor/updated_at mudou nas 4.305 peças.
- **Cadastro** `src/components/forms/PecaForm.tsx`: o fornecedor entra no mesmo `setTimeout` que já reaplicava marca e
  categoria depois do `reset` (o SelectField ficava em branco; com o fornecedor sempre vazio isso nunca aparecia).

## Critérios de aceite

- Editar a 13442 (ou qualquer peça da lista) mostra o fornecedor no campo; salvar sem mexer não muda nada.
- `produto_fornecedores` com 4.303 linhas da carga; filtro "Fornecedor" da busca de peças do Orçamento passa a achar peças.
- Trocar o fornecedor na edição cria o vínculo novo.

## Realizado

- 28/10/2026: levantamento, casamento (scripts no scratchpad: casar_fornec2.py), migration 257 escrita e testada em
  dry-run (4.303 vínculos, 0 preço alterado, gatilho ok), PecaForm ajustado (build ok). Lista das peças que ficam sem
  fornecedor: `pecas_sem_fornecedor.csv` (241).

## Pendências

- [ ] Cadastrar TARGETTI e MUNDIAL LUX como fornecedor (com CNPJ) e vincular as 38 peças.
- [ ] NORTEL SUPRIMENTOS INDUSTRIAIS SA: 2 filiais (0012-68 e 0088-66), sem matriz — escolher qual (1 peça).
- [ ] Fornecedores duplicados no cadastro (mesmo nome, CNPJ diferente): revisar se são filiais reais ou cadastro em dobro.
- [ ] Import da Connect (`scripts/importar_produtos_estoque.py`) não traz o fornecedor: decidir se a carga vira rotina.
