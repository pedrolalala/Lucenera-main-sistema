# Migration group 20260706_021 - Criar produto pelo Orcamentos

## SPEC

- `SPEC-018_Criar_Produto_no_Modal_de_Orcamento.md`

## Objetivo

Expor uma RPC central para criar produto canonico em `public.produtos` a partir do sistema de Orçamentos, sem criar catalogo paralelo e sem depender de troca manual para o sistema de Cadastro.

## Principais alteracoes

- Cria `public.criar_produto_orcamento(jsonb)`.
- Valida permissao provisoria por `usuarios.role`.
- Valida `codigo_produto`, `sku`, `marca_id`, `categoria_id` e fornecedor quando informado.
- Garante `ativo = true`.
- Retorna o produto criado como JSON, com `source = 'produtos'`.

## Impacto esperado

- Orçamentos pode usar a RPC no modal de busca/criacao de produto.
- Cadastro continua podendo criar produtos pelo fluxo atual direto em `public.produtos`.
- Estoque/Compras nao recebe novos dados operacionais nesta etapa.

## Rollback

Remover a funcao `public.criar_produto_orcamento(jsonb)`. Nenhuma tabela ou coluna nova e criada nesta migration.
