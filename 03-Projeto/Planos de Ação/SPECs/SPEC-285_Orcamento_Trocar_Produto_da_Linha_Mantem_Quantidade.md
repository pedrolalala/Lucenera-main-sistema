# SPEC-285 — Orçamento: trocar o produto de uma linha não pode voltar a quantidade para 1

**Data:** 2026-11-12 | **Status:** implementada (código local, não publicada) | **Sistema:** Orçamentos (`gestao-financeira-clone-544cb (1)`, `BudgetFormPage.tsx`)
**Origem:** Reunião 50 (12/11/2026, Vinicius e Carol — "Bug dentro de orçamento").

## Problema
Orçamento com item especial: ao substituir o item pelo produto real (ícone de busca da linha → "Buscar Produtos"), o usuário digita o L e a quantidade do orçamento (ex.: 2) e clica em "Confirmar Seleção". A linha volta com **quantidade 1**. O Vinicius não sabia se acontecia só com item especial.

## Causa
`applyProductSelection` montava a linha nova com `buildNewItem`, que fixa `quantidade: 1`, e esse valor sobrescrevia a linha existente. O comentário do código dizia que a troca "mantém L/quantidade", mas só o L era mantido (`custom_id`). Vale para **qualquer** troca de produto numa linha, não só item especial; a quantidade digitada no modal também era descartada.

## Regra
Ao trocar o produto de uma linha existente:
1. a quantidade é a digitada no modal (primeiro L da peça), se houver e for > 0;
2. senão, mantém a quantidade que a linha já tinha;
3. senão, 1.
O L da linha continua o mesmo. Produtos extras escolhidos na mesma busca entram como linhas novas com a quantidade digitada (padrão 1).

## Mudança
- `applyProductSelection` ganha o parâmetro `quantidades` e `buildNewItem` recebe a quantidade.
- `handleProductSearchConfirm` passa a quantidade do primeiro L de cada peça.
- Não alterados: preço (continua o do produto novo), desconto (volta a 0, como antes) e a tela de Aprovação Financeira (`EditableBudgetItemsTable`), que já mantinha a quantidade ao trocar.

## Parte 2 — permissão da Carol (decisão do usuário em 12/11)
Na reunião o Vinicius pediu "habilitar para a Carol poder fazer essa troca". Hoje o banco recusa: `replace_orcamento_itens` só deixa **admin** salvar troca de produto/valor de item (a Carol é `funcionario`; a SPEC-271 liberou só ver/aprovar). Decisão: quem tem acesso `financeiro` pode **trocar produto e valor**, **somente** com o orçamento em `Aprovação Financeira`.
- Migration `20261112_338_spec285_revisao_financeira_troca_item_financeiro` (**APLICADA em SP em 12/11/2026**, após o ensaio): mesma função da 332 com a trava `admin OU (usuário ativo e logado + `pode_acessar_sistema('financeiro')` + orçamento em 'Aprovação Financeira')`. Assinatura e GRANTs iguais.
- Risco registrado: quem tem `financeiro` passa a poder alterar preço de item enquanto o orçamento está em revisão (trigger de auditoria `auditoria_itens_*` continua registrando).
- Ensaio em transação com ROLLBACK (12/11): antes Carol negada; depois Carol permitida em Revisão Financeira; negada em Orçamento Aprovado; funcionário sem `financeiro` negado nas duas etapas; `anon` sem execução.
- Rollback: `rollback.sql` (restaura a definição da 332).
- Snapshot `supabase/db/current/03_functions.sql` atualizado em 12/11 a partir da definição real do banco.
- Pendente: testar com a própria Carol.

## Banco
Parte 1 (quantidade): nenhuma mudança. Parte 2: migration 338 acima. Rollback da parte 1: reverter o commit.

## Aceite
- Item especial qtd 2 → trocar pelo produto real digitando qtd 2 → linha com 2.
- Trocar sem alterar o valor do modal → linha mantém a quantidade anterior quando o modal não trouxer quantidade válida.
- Adicionar produto novo (botão "Buscar Produtos" do topo) segue igual.

## Pendente
Publicar (deploy do sistema Orçamentos) e commit no repositório do sistema + ponteiro do submodule.
