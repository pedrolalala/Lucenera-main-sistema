# SPEC-278 — Revisão financeira pode trocar o Tipo de Operação do orçamento

**Data:** 11/11/2026 · **Origem:** Reunião 49 (Carol) — `02-Reunioes/49. Lucenera (Carol) - 11.11.2026_ Questões relacionada ao orçamento`.

## Problema
O time envia como *venda* um orçamento que na prática abate crédito de cliente interno e deveria ser *Outros / BONIFICACAO* (sem cobrança). Caso: ORC-0008 de 09/11 (equipe Marina), R$ 490,69, em Aprovação Financeira. O Tipo de Operação trava depois da criação (SPEC-071) e o financeiro não consegue corrigir.

## Decisão (11/11)
Só a **revisão financeira** pode trocar o Tipo de Operação. A empresa já era editável.

## Achado
A trava é só de tela (`disabled={isEditing}` em `BudgetFormPage.tsx`). O salvamento já grava `natureza_operacao` e `subgrupo` na edição, e o banco só barra empréstimo confirmado (`trg_2_orcamento_emprestimo_guard`). Sem mudança de banco.

## Entregue (código local, não publicado)
- `podeTrocarOperacao`: orçamento em "Aprovação Financeira", usuário com `usePodeRevisaoFinanceira` (admin, gerente ou acesso `financeiro`), natureza atual Venda/Outros/SAC, sem vínculo Connect e que não seja empréstimo.
- Libera os botões Venda, Outros e SAC e o campo Tipo nesse caso. Devolução, empréstimo (some da lista na edição) e vínculo Connect continuam travados. Fora da revisão financeira nada muda.

## Pendente
- Publicar o Orçamentos; a Carol abrir o ORC-0008 e trocar para Outros / BONIFICACAO.
- Conferir após a troca que a aprovação não gera parcelas (regra de Outros/BONIFICACAO, SPEC-234) e que o orçamento só aparece na Revisão Financeira pendente.
- Não troquei nenhum dado: a troca é da Carol.

## Rollback
Reverter o commit no Orçamentos e republicar.
