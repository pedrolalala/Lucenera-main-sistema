---
titulo: "SPEC-316 — Compras: pedido em montagem com itens de vários fornecedores (gera um pedido de compra por fornecedor)"
status: 16/11 — implementado no Compras (sem mudança de banco); ver Realizado
data_ultima_modificacao: 2026-11-16
sistemas_envolvidos:
  - Compras (04-Sistemas/compras-lucenera-3o23t98ee) — Necessidade de Compra, pedido em montagem
---

# SPEC-316

## Origem
Central de Solicitações, Débora, 12/11/2026: "PEDIDO DE PRODUÇÃO LUCENERA - COLOCAR MAIS DE UM FORNECEDOR NO MESMO PEDIDO" (id `073a9cc7-c8cc-41a0-bcab-6b8139d565b9`). Esclarecimento do usuário (16/11): há marcas específicas cujos itens vêm de vários fornecedores, por vários motivos; é preciso habilitar isso.

## Checklist de Ação
- [x] Necessidade de Compra aceita juntar no pedido em montagem itens de fornecedores diferentes (antes: bloqueava com "Fornecedor diferente").
- [x] "Selecionar todos os filtrados" traz todos os fornecedores da marca (antes: deixava de fora os de outro fornecedor).
- [x] "Fechar pedido" gera um pedido de compra por fornecedor, em sequência (a tela de fechamento abre para o 1º fornecedor e, ao confirmar, para o próximo).
- [ ] Teste da Débora com uma marca de vários fornecedores.

## Decisão
O pedido de compra continua com **um fornecedor** (PDF enviado, contas a pagar, entrada de NF, prazo e antecipação dependem disso). O que muda é a montagem: o carrinho aceita vários fornecedores e, ao fechar, o sistema separa em um pedido por fornecedor. Sem mudança de banco.

## Comportamento
- Banner "Pedido em montagem" lista os fornecedores (A + B) e o botão vira "Fechar N pedidos (linhas)".
- Cada fechamento grava só as linhas do fornecedor da vez e as tira do carrinho; sobrando outro fornecedor, avisa e já mostra o próximo. Cancelar no meio mantém as linhas restantes no carrinho (rascunho de 24 h, SPEC-271).
- O Pedido Avulso (fornecedor escolhido antes) não muda.

## Fora do escopo
Número-mãe ligando os pedidos do mesmo fechamento; item com fornecedor diferente do cadastrado na marca/produto (o fornecedor de cada linha continua vindo do cadastro). Se a Débora precisar trocar o fornecedor de um item no ato, vira SPEC própria.

## Rollback
Reverter o commit do Compras (nenhuma migration).

## Realizado
Código no Compras (`NecessidadeCompra.tsx`); `tsc` ok.

## Pendências
- [ ] Débora confirmar que o fornecedor de cada item (vindo do cadastro) é o que ela quer, ou pedir troca de fornecedor por item.

## Decisão final (16/11)
Um único pedido de compra com vários fornecedores NÃO será feito: o pedido segue com um fornecedor só e o caso de peças produzidas por demanda na Lucenera ("pedido de produção") é lançado pelo Pedido Avulso. Vale o que está nas SPEC-316 e SPEC-317 (um pedido por fornecedor ao fechar; fornecedor trocável por produto).
