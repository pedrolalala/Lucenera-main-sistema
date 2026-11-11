---
titulo: "SPEC-263 — Compras: incluir itens ao editar pedido, valor final negociado e ST/IPI em lote por marca"
status: aplicada
---

# SPEC-263 — Necessidade de Compra: 3 pedidos da Central (06/11/2026)

> (A) "Comando para ajustar ST e IPI de uma global — por marca/fornecedor": mudança tributária, hoje peça por peça; precisa ser por marca (cada uma tem a sua porcentagem).
> (B) "Inclusão de itens na edição dos pedidos de compras": editar só mexia nos itens que já existem; novo item só pela Necessidade ou por pedido avulso.
> (C) "Visualização dos valores negociados dos pedidos": onde informar o valor final aprovado, com desconto, do pedido.

## Decisões de desenho
- **A. Por marca** (não por fornecedor: a marca já tem fornecedor padrão e o pedido fala "por marca"). Colunas `produtos.porc_st` (ST) e `produtos.ipi_entrada` (IPI), as que o pedido de compra lê; `icms_entrada` não é tocado (a `fn_atualizar_preco_venda` chama de "ST" a conta do ICMS: é legado, fora do escopo). Padrão **só em peças que já têm o imposto** (>0) para não inventar ST onde não existe; opção para todas. **Prévia obrigatória** (quantas peças, antes→depois) e só então grava. Trava = mesma lista de quem vê custo (`pode_ver_custo_produto`) + editar em Necessidade de Compra. Efeito colateral conhecido: gravar em `produtos` roda a `fn_atualizar_preco_venda`, que só muda o preço de venda das peças **sem `valor_venda`** (custo total × 2,5); a prévia informa quantas são. Não há trigger externo em `produtos` (conferido). O log de auditoria de `produtos` registra cada linha.
- **B. Item novo** entra na própria `editar_pedido_compra` (elemento de `p_itens` com `produto_id` e sem `pedido_item_id`), com o mesmo par solicitação + item do pedido avulso, sem vínculo com venda. Peça repetida é recusada (altera-se a quantidade da linha). Custo, ST, IPI, despesas e caixa fechada (arredonda e aplica desconto) vêm do cadastro/fornecedor. Só pedido "Aguardando aprovar" (regra que já existia).
- **C. `pedidos_compra.valor_negociado` + `valor_tabela`**. Com valor negociado o total do pedido é **exatamente** ele (`desconto_percentual` só tem 2 casas, por isso coluna própria) e o desconto vira só a informação equivalente; não pode passar do total sem desconto. As parcelas são refeitas com o total novo (já era assim). Lista de pedidos mostra "negociado · tabela R$ X" (ou "com desconto") quando houve redução. Pedidos antigos não têm `valor_tabela` (só aparece depois da próxima edição).
- `editar_pedido_compra` ganhou 1 parâmetro com DEFAULT: DROP + CREATE na mesma migration (sem sobrecarga, aprendido na SPEC-155).

## Feito
- [x] Migration 313 (`20261108_313_spec263_compras_itens_negociado_impostos_marca`): rascunho **testado em dry-run com ROLLBACK** como Débora e Thais: item novo cria solicitação + item, total 800→749,63 com negociado, negociado acima do bruto recusado, peça repetida recusada, volta ao desconto % ao apagar o negociado; impostos: prévia não grava, Thais barrada, aplicar na Dessine → 160 peças com ST, 161 com IPI, peça sem ST preservada. rollback.sql incluso (recria a função de 8 parâmetros).
- [x] Front Compras (commit local): janela Editar pedido com busca "Incluir peça", selo "Nova", campo "Valor final negociado (R$)"; lista de pedidos com tabela × negociado; página Marcas com botão **Impostos** (janela com prévia e confirmação). `tsc` 6 erros antes e depois (dívida antiga); build só com São Paulo.
- [x] Migration 313 APLICADA 08/11 (conferido: 1 versão de cada função, anon sem execução, colunas criadas, sem sobra do pedido de teste).
- [x] Compras publicado 08/11 (wrangler, deploy 571497d2, bundle em São Paulo).
- [ ] Teste em tela: incluir peça num pedido aguardando aprovar; preencher o valor negociado; ajustar uma marca pequena.

## Observações
- Hoje nenhum pedido "Aguardando aprovar" tem itens: os importados da Connect (ex.: 1952 CONNECT) vêm sem itens. Com a inclusão dá para montar os itens à mão num deles; o import do PDF da Connect continua sendo outra solicitação (em desenvolvimento).
- Ajuste por **fornecedor** (além da marca) não foi feito; se precisarem, vira filtro extra na mesma função.

## Rollback
`supabase/db/migrations/20261108_313_spec263_compras_itens_negociado_impostos_marca/rollback.sql` + reverter o commit do front. Impostos já gravados não voltam sozinhos (o log de auditoria de `produtos` tem os valores antigos).
