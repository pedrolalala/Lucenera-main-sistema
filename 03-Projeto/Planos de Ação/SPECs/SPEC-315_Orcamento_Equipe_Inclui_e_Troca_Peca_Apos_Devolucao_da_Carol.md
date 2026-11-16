# SPEC-315 — Orçamento: a equipe inclui/troca peça quando a Carol devolve (preço de tabela)

**Data:** 2026-11-16 | **Status:** implementada em código local e migration 376 ensaiada em ROLLBACK (**NÃO aplicada**, **não publicada**) | **Sistema:** Orçamentos (`gestao-financeira-clone-544cb (1)`: `BudgetFormPage.tsx`, `BudgetItemCard.tsx`) + banco (`replace_orcamento_itens`)
**Origem:** caso real ORC-0081 (16/11/2026): peças 12131 (L19 e L22) faltando; Helena e Carol não conseguiam incluir. Pedido do usuário: "a Carol volta o orçamento errado e o pessoal da equipe edita — é um caso que acontece".

## Problema
`replace_orcamento_itens` (SPEC-108/116, depois SPEC-281/285) só aceita linha **nova** ou com produto/valor trocado de: admin, ou quem tem acesso `financeiro` com o orçamento em `Aprovação Financeira`. Quando a Carol devolve o orçamento a `Aprovação da Equipe` ("ajustes no orçamento"), ela perde a permissão e a equipe (funcionário sem `financeiro`, ex.: Helena) nunca teve. O banco negava com "Permissao negada: alterar valor ou produto de item do orcamento requer perfil administrador…". Também negava em `rascunho` e `enviado_cliente` (testado em ROLLBACK em 16/11).

Linha do tempo do ORC-0081 no `auditoria.eventos`: Helena envia (12:25) → Carol devolve duas vezes (14:46, 14:53) → equipe sem como incluir. O admin incluiu 2 itens às 15:15 e destravou o caso.

## Decisão (usuário, 16/11/2026)
A regra da SPEC-108 (só admin mexe em valor/produto de orçamento salvo) continua, com uma exceção estreita:
- **Quem:** usuário com permissão de editar Orçamentos (`hub_pode_executar(..., 'orcamentos', NULL, 'editar')`).
- **Quando:** orçamento em `rascunho` ou `Aprovação da Equipe`.
- **O quê:** incluir peça nova ou trocar o produto de uma linha, **somente** com produto cadastrado e `preco_unitario` igual ao de tabela (`COALESCE(NULLIF(produtos.preco_venda,0), produtos.valor_venda)`).
- **Continua só admin (ou financeiro na Aprovação Financeira, SPEC-285):** preço digitado à mão, item sem cadastro/especial, qualquer alteração em `Aprovação Financeira`, `enviado_cliente`, `Orçamento Aprovado`.

## Mudança
- **Banco:** migration `20261116_376_spec315_equipe_inclui_troca_peca_preco_tabela` = mesma função da 338 (assinatura e GRANTs iguais) com a exceção acima. Mensagem de erro atualizada.
- **Tela:** `canTrocarProduto` (admin, criação, ou status rascunho/Aprovação da Equipe) libera "Buscar Produtos", o botão do produto da linha e "Buscar produto cadastrado". `canEditValorProduto` segue travando preço, "Adicionar Item não Cadastrado" e criar produto.

## Ensaio (transação com ROLLBACK, ORC-0081, 16/11)
| Quem / status / item | Antes | Com a 376 |
|---|---|---|
| Helena, Aprovação da Equipe, 12131 a preço de tabela (708,91) | negado | **permitido** |
| Helena, rascunho, 12131 a preço de tabela | negado | **permitido** |
| Helena, Aprovação da Equipe, 12131 com preço digitado (100) | negado | negado |
| Helena, Aprovação da Equipe, item sem cadastro | negado | negado |
| Helena, Aprovação Financeira / enviado_cliente | negado | negado |
| Carol, Aprovação Financeira, item sem cadastro (SPEC-285) | permitido | permitido |

## Risco
Quem edita Orçamentos passa a incluir/trocar peça em rascunho e Aprovação da Equipe. Preço fica preso ao de tabela; a auditoria `auditoria_itens_*` continua registrando. Desconto não é afetado.

## Rollback
`rollback.sql` da migration (restaura a definição da 338). Tela: reverter o commit.

## Pendente
Aplicar a 376 em SP (aguarda ok do usuário), atualizar `supabase/db/current/03_functions.sql`, publicar Orçamentos, commit no repo do sistema + ponteiro do submódulo, teste com Helena e Carol.
