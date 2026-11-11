# SPEC-280 — Reajuste de preços de peças (em massa e por peça)

**Data:** 11/11/2026 · **Status:** RASCUNHO — aguarda respostas do usuário (seção 6). Nada implementado.
**Origem:** diferença de valor entre orçamento e Connect (peça 11412).

## 1. Problema
- Peça 11412: Connect e cadastro = R$ 184,49; orçamento ORC-0012 (rascunho) = R$ 182,47. O orçamento grava o preço **no momento em que a peça entra** e não acompanha o cadastro. O cadastro foi reajustado depois (ST/custo) e o orçamento ficou velho.
- Hoje não existe como reajustar várias peças de uma vez, nem registro de **quem mudou o preço, quando e de quanto**.
- Fotografia do banco em 11/11: itens com preço diferente do cadastro — rascunho 17 itens (10 peças), Aprovação Financeira 6 (6 peças), enviado ao cliente 24 (19 peças). Em orçamento aprovado a diferença é esperada (preço congelado).
- 348 peças alteradas em 04/11 (carga Connect), 80 em 05/11, 57 em 09/11.

## 2. O que o sistema deve fazer
**Escopo do reajuste (combináveis):** uma peça · uma marca inteira · marca + categoria (ex.: só LUMINARIA) · fornecedor · lista de peças colada/planilha.
**O que se reajusta:** % ST · % IPI · % frete · % desconto do fornecedor · preço de custo (% ou valor novo) · % de lucro · preço de venda direto (% sobre o atual).
**Fluxo seguro:**
1. Escolhe escopo e regra → **pré-visualização** (peça, valor antes → depois, quantas peças, total de impacto). Nada grava ainda.
2. Confirma → grava tudo numa transação, num **lote** com número, autor, data e motivo.
3. **Histórico** por peça e por lote; **desfazer o lote** (volta aos valores anteriores, se a peça não foi alterada depois).
Usa a mesma conta do Cadastro (custo − desconto + BDI; venda = custo total × (1+lucro)), arredondando como a tela hoje.

## 3. Permissão
Ação nova `reajustar_precos` no Hub: **Vinicius** (todas as opções, em massa e por peça) e quem o usuário indicar. Quem só tem custo restrito não vê custo (AGENTS.md, SPEC-193). Funções `SECURITY DEFINER`, `REVOKE FROM PUBLIC, anon`.

## 4. Efeito nos orçamentos (decidir)
- Aprovado / enviado ao cliente: **nunca muda** sozinho.
- Rascunho e Aprovação da Equipe: opção A) atualiza para o preço novo ao reabrir, com aviso "preço mudou de X para Y"; opção B) só avisa e o vendedor clica em "atualizar".
- Lista "orçamentos afetados pelo lote" para o comercial conferir.

## 5. Banco / sistemas
Tabelas novas: `produto_reajuste_lote` (id, autor, motivo, escopo jsonb, regra jsonb, criado_em, desfeito_em) e `produto_reajuste_item` (lote, produto, valores antes/depois dos campos). RLS ligada, sem `anon`. Funções: `reajuste_previa(escopo, regra)`, `reajuste_aplicar(...)`, `reajuste_desfazer(lote)`. Trigger de histórico também para edição manual de peça (hoje sem registro).
Sistemas: **Cadastro** (tela nova "Reajuste de preços" + histórico na peça); **Orçamentos** (aviso/atualização conforme seção 4); migration em `supabase/db/migrations/`.
Cuidado: a carga/sync da Connect não pode desfazer um reajuste do sistema (ver SPEC-244: Connect é herança).

## 6. Perguntas ao usuário
1. A fonte da verdade do preço é o sistema novo ou a Connect? Se o Vinicius reajustar aqui, alguém replica na Connect, ou a Connect vai ser reajustada primeiro e o sistema importa?
2. Orçamento em rascunho: opção A ou B (seção 4)?
3. Além de Vinicius, quem mais pode reajustar?
4. Reajuste de custo deve recalcular o preço de venda mantendo o % de lucro (padrão) ou manter o preço de venda?
5. Desfazer lote: basta até a primeira edição posterior da peça?

## 7. Critérios de aceite
Prévia confere com a aplicação; marca+categoria só altera as peças da categoria; histórico mostra autor/data/antes/depois; desfazer devolve valores; usuário sem permissão não executa (testado em ROLLBACK como `authenticated`); aprovado/enviado intactos.

## 8. Rollback
Desfazer por lote; migration com `rollback.sql` (drop das tabelas/funções novas).
