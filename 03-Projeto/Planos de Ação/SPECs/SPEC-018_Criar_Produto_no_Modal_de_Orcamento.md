---
titulo: "SPEC-018 — Criar Produto Dentro do Modal de Orçamento"
status: implementado em homologacao
data_ultima_modificacao: 2026-07-06
sistemas_envolvidos:
  - Orçamentos
  - Cadastro
  - Supabase (banco central)
---

# SPEC-018 — Criar Produto Dentro do Modal de Orçamento

## Checklist de Ação

- [x] Adicionar botão "Criar novo produto" no modal de busca de produtos do Orçamentos.
- [x] Criar modal/formulário de produto dentro do sistema de Orçamentos, inspirado no modal de peça do Cadastro.
- [x] Reaproveitar campos, validações e serviços equivalentes aos de `PecaForm`.
- [x] Ao salvar produto, selecionar automaticamente o novo produto no item do orçamento.
- [x] Atualizar busca/lista de produtos sem trocar de sistema nem recarregar a página.
- [x] Garantir que produtos criados entrem em `public.produtos` com `ativo = true`.
- [x] Respeitar validação de `codigo_produto` e `sku` únicos.
- [x] Atualizar contexto do sistema de Orçamentos se novos serviços/componentes forem criados.

### Passos manuais do usuário

- [ ] Homologar quais campos do Cadastro são obrigatórios também no Orçamentos.
- [ ] Confirmar se o botão deve aparecer sempre no topo ou também no estado "Nenhum produto encontrado".

## Objetivo

Permitir que o usuário crie um produto novo enquanto cria ou edita um orçamento, sem sair do sistema de Orçamentos.

Hoje, quando o produto não existe, o usuário precisa trocar para o sistema de Cadastro, criar a peça/produto e depois voltar ao orçamento. A experiência esperada é abrir um modal igual ao do Cadastro dentro do próprio fluxo de orçamento.

## Decisões aprovadas

- O produto novo deve ser criado no cadastro central `public.produtos`.
- O usuário não deve trocar de sistema para cadastrar produto durante o orçamento.
- O modal do Orçamentos deve seguir o comportamento do modal do Cadastro.
- Após salvar, o produto criado deve ficar selecionado no item do orçamento.
- `revenda_ubiqua` continua sendo fonte de consulta/importação, mas criação nova entra em `produtos`.

## Estado Antes da Implementação

### Orçamentos

Arquivos relevantes:

- `04-Sistemas/gestao-financeira-clone-544cb (1)/src/pages/BudgetFormPage.tsx`
- `04-Sistemas/gestao-financeira-clone-544cb (1)/src/components/budgets/ProductSearchModal.tsx`
- `04-Sistemas/gestao-financeira-clone-544cb (1)/src/components/AsyncProductSelect.tsx`
- `04-Sistemas/gestao-financeira-clone-544cb (1)/src/components/budgets/EditableBudgetItemsTable.tsx`
- `04-Sistemas/gestao-financeira-clone-544cb (1)/src/components/budgets/EditableItemCard.tsx`

Antes da implementação, `ProductSearchModal` já buscava em:

- `public.produtos`;
- `public.revenda_ubiqua`.

Mas ainda não possuía ação de criação.

### Cadastro

Referência visual/funcional:

- `04-Sistemas/cadastro-lucenera-b86fe/src/components/modals/PecaModal.tsx`
- `04-Sistemas/cadastro-lucenera-b86fe/src/components/forms/PecaForm.tsx`
- `04-Sistemas/cadastro-lucenera-b86fe/src/services/produtos.ts`

O Cadastro já possui:

- `createProduto`;
- `updateProduto`;
- `checkCodigoExists`;
- `checkSkuExists`;
- `getMarcas`;
- `getCategoriasProduto`;
- `getFornecedores`;
- `getNextSku`.

## Definição da SPEC

### Experiência esperada

No modal `Buscar Produtos`:

1. botão "Criar novo produto" fica visível no cabeçalho ou rodapé;
2. quando a busca não encontra produto, o estado vazio também mostra "Criar novo produto";
3. clicar abre modal interno de produto, sem mudar rota e sem abrir o Cadastro em outra aba;
4. se houver texto de busca, o modal novo pode pré-preencher `nome`, `referencia` ou `sku` conforme melhor inferência;
5. salvar produto fecha o modal de criação;
6. produto criado entra na seleção atual;
7. confirmar seleção adiciona o produto ao orçamento com `produto_id`, `preco_unitario`, `codigo_produto`, `sku` e `referencia`.

### Novo componente sugerido

Criar no Orçamentos:

```text
src/components/products/ProductCreateDialog.tsx
src/services/productCatalogService.ts
```

O componente deve seguir a estrutura do Cadastro:

- `DialogContent` amplo;
- seções de dados básicos, custos, fiscal e estoque;
- campos compactos;
- cálculo de `preco_venda` compatível com `PecaForm`;
- botão "Salvar Produto".

### Campos mínimos

Obrigatórios para salvar:

| Campo | Origem/Regra |
|---|---|
| `codigo_produto` | Obrigatório e único. |
| `nome` | Obrigatório. |
| `marca_id` | Obrigatório. |
| `categoria_id` | Obrigatório. |
| `unidade` | Default `UN`. |
| `preco_custo` | Pode ser `0`, mas deve existir. |
| `preco_venda` | Calculado ou preenchido. |
| `ativo` | `true`. |

Campos opcionais:

- `sku`;
- `referencia`;
- `fornecedor_principal_id`;
- `descricao_tecnica`;
- `ncm`;
- `tipo_fiscal`;
- `cst`;
- `cest`;
- `status_comercial`;
- percentuais de ST, IPI, frete, despesas e margem.

### Serviço de produto no Orçamentos

O Orçamentos deve criar serviço próprio equivalente ao Cadastro, usando as mesmas tabelas centrais:

- `produtos`;
- `marcas`;
- `categorias_produto`;
- `contatos` com `tipo = fornecedor`;
- RPC `get_next_sku`.

Não duplicar tabela nem criar produto em tabela local do app.

### Integração com `ProductSearchModal`

Adicionar props:

```ts
onProductCreated?: (product: ProductSearchItem) => void
initialCreateSearch?: string
```

Ou manter estado interno, desde que:

- o produto criado seja convertido para `ProductSearchItem`;
- `source = 'produtos'`;
- `id` seja UUID válido;
- `preco_venda` e `valor_venda` venham preenchidos quando disponíveis;
- `selected` receba o produto com quantidade 1;
- a lista seja atualizada para exibir o novo produto.

### Integração com `BudgetFormPage`

Quando o produto é criado a partir do modal de busca:

- em adição de item, criar uma linha com `produto_id = produto.id`;
- em troca de produto de uma linha existente, substituir o produto da linha;
- preencher `preco_unitario` com `preco_venda || valor_venda || 0`;
- limpar `descricao` quando houver `produto_id`;
- atualizar `productMetaMap` com `codigo_produto`, `referencia`, `nome` e `sku`.

### Integração com aprovação financeira

Depois da SPEC-017, o mesmo `ProductSearchModal` deve ser usado em edição financeira. Portanto o botão "Criar novo produto" também deve funcionar quando o orçamento estiver em `Aprovação Financeira`.

### Permissões

Provisório:

- mesmos usuários que podem criar/editar orçamento podem abrir o modal;
- se Supabase/RLS bloquear insert em `produtos`, mostrar erro claro.

Futuro:

- substituir por permissão granular do Hub/TI para criação de produto.

## Critérios de aceite

- [x] No modal de busca de produtos existe botão visível "Criar novo produto".
- [x] Estado vazio de busca permite criar produto sem trocar de sistema.
- [x] O modal de criação replica a experiência essencial do Cadastro.
- [x] Salvar cria linha em `public.produtos` com `ativo = true`.
- [x] Código de produto duplicado bloqueia salvamento.
- [x] SKU duplicado bloqueia salvamento quando preenchido.
- [x] Produto salvo aparece/é selecionado imediatamente no orçamento.
- [x] O item do orçamento fica com `produto_id` válido e preço preenchido.
- [x] Funciona no criar orçamento, editar orçamento e editar orçamento em `Aprovação Financeira`.

## Testes obrigatórios

- Buscar produto inexistente e clicar "Criar novo produto".
- Criar produto com campos mínimos e confirmar que ele é selecionado no orçamento.
- Criar produto com `codigo_produto` duplicado e confirmar erro.
- Criar produto com `sku` duplicado e confirmar erro.
- Cancelar criação e confirmar que a busca/seleção anterior não se perde.
- Criar produto durante edição de orçamento existente e salvar orçamento.
- Criar produto durante edição de orçamento em `Aprovação Financeira` e salvar sem aprovar.

## Realizado

### 2026-07-06

- SPEC criada a partir da solicitação do usuário para criar produto dentro do modal de orçamento, sem trocar para Cadastro.
- Referência do Cadastro mapeada em `PecaModal`, `PecaForm` e `produtos.ts`.
- Migration `20260706_021_criar_produto_orcamento` criada, validada em transação com `ROLLBACK` e aplicada no Supabase real.
- Criada RPC `criar_produto_orcamento(p_payload jsonb)`, gravando sempre em `public.produtos`, com `ativo = true`, validação de permissão provisória por `usuarios.role`, `codigo_produto` único, `sku` único quando preenchido, `marca_id`, `categoria_id` e fornecedor quando informado.
- Teste transacional com `ROLLBACK`: criação de produto canônico funcionou e retornou `source = 'produtos'`.
- Após aceite, implementado no sistema de Orçamentos local e no projeto Skip da org Lucenera (`Orçamentos Aprovação`, projeto `32554`).
- Criado `src/services/productCatalogService.ts` para opções de catálogo, sugestão de SKU e chamada da RPC `criar_produto_orcamento`.
- Criado `src/components/budgets/ProductCreateModal.tsx` com campos básicos, custos/preço e dados fiscal/comercial.
- `ProductSearchModal`, `BudgetFormPage`, `BudgetItemCard`, `EditableBudgetItemsTable` e `EditableItemCard` foram integrados ao cadastro direto de produto.
- QA técnico: `pnpm run lint`, `pnpm run build` e `skip_project_apply_changes` em modo development passaram sem erros. Versão Skip final: `0.0.273` / `dcd3442`.

## Pendências

- [ ] Confirmar obrigatoriedade final de marca/categoria quando o produto é criado durante orçamento.
- [ ] Homologar visualmente a criação de produto no preview do Skip, incluindo orçamento novo, orçamento existente e orçamento em `Aprovação Financeira`.
