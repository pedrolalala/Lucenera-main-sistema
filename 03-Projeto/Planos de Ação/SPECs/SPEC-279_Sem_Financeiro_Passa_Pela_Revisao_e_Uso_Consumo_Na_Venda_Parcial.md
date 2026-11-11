# SPEC-279 — Operação sem financeiro passa pela Revisão Financeira Pendente; uso e consumo na Venda Parcial

**Data:** 11/11/2026 · **Origem:** Reunião 49 (Carol) + pedido do usuário no mesmo dia.

## Problema
Garantia, uso e consumo, bonificação e demais operações sem cobrança sumiam da Revisão Financeira Pendente: a regra SPEC-255 A aprovava tudo no mesmo segundo em que a equipe aprovava (ORC-0012: 13:19:43 nos dois passos). O financeiro não tinha controle. O uso e consumo (baixa direta do Estoque Geral) também não aparece na Venda Parcial, porque a lista só enxerga orçamentos com itens de projeto.

## Decisões (11/11)
1. **Esperar o financeiro aprovar:** essas operações ficam em "Aprovação Financeira" até alguém aprovar. Garantia, baixa de estoque e entrega só andam depois do clique.
2. **Uso e consumo entra na Venda Parcial como registro** (baixa direta, sem separação).

## Entregue (rascunho local, nada aplicado nem publicado)
- Migration `20261111_329_spec279_sem_financeiro_na_revisao` (up, rollback, dry_run):
  - `equipe_aprovar_orcamento` deixa de chamar a aprovação automática. `aprovar_orcamento_financeiro` já encaminha Outros/SAC para a aprovação sem financeiro (sem parcela, boleto ou nº de venda; empréstimo continua fora).
  - `vw_venda_parcial_lista` ganha uma segunda parte (UNION ALL) com orçamentos aprovados de regra `baixa_direta` (USO E CONSUMO, DESCARTE) sem projeto_itens: `q_venda` = soma das peças, `q_entregue` = `q_venda`, demais zero. Mesmas colunas e tipos, `security_invoker` mantido.
- Dry-run em ROLLBACK em SP: lista 333 → 334 linhas (entra o ORC-0012), sem duplicados, `anon` sem acesso, função sem a chamada automática, produção intacta.
- Orçamentos: diálogo de aprovação financeira de Outros/SAC não mostra parcelas nem diz que vai gerar boletos; mensagem de sucesso própria, sem a tela de boletos/nota (`FinancialApprovalDialog.tsx`, `FinancialApprovalTab.tsx`; comentário em `TeamApprovalTab.tsx`).

## Atenção
- Os 12 já aprovados (10 garantias, 1 uso e consumo, 1 bonificação) **continuam aprovados**; a regra vale dali em diante. Se for preciso levá-los à revisão, é decisão à parte.
- Reverte a decisão da SPEC-255 A (06/11, Filippo): garantia agora espera o financeiro. O pessoal que lança garantia (ex.: Matheus) vai notar o atraso.
- Venda Parcial: a linha do uso e consumo não tem separação. Conferir como a tela se comporta ao abrir essa linha.
- Numeração: a migration 327 `spec277_codigo_produto…` (outra sessão) colide com a SPEC-277 deste dia (PDF da venda). Renumerar uma delas.

## Pendente
- Aplicar a migration 329 em SP (autorização) e publicar o Orçamentos e a Separação Parcial.
- Teste: lançar garantia e uso e consumo, aprovar na equipe, ver cair na Revisão Financeira Pendente, aprovar e conferir estoque, histórico e a linha na Venda Parcial.

## Rollback
`rollback.sql` da migration (restaura a função e a view anteriores) e reverter o commit do Orçamentos.
