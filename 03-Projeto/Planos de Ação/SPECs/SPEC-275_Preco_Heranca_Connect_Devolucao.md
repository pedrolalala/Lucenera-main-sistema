---
titulo: "SPEC-275 — Preço da herança Connect para a devolução sair com valor"
status: pendente
data_ultima_modificacao: 2026-11-06
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone)
  - Banco (projeto_itens)
---

# SPEC-275 — Preço da herança Connect para a devolução sair com valor

## Checklist de Ação

- [x] Diagnosticar por que a devolução sai com valor R$ 0 (06/11)
- [x] Redigir migration 326 (up, dry_run, rollback) — só copia preço/desconto
- [x] Dry-run em transação com ROLLBACK (3.719 de 3.720 itens recebem preço; 1 fica sem)
- [x] Aplicar migration 326 no Supabase real (07/11)
- [x] Ajustar `devolucoesService.ts` (feito no código, NÃO publicado): para venda `origem = 'connect'`, converter o desconto global (R$) em % usando o subtotal de `orcamento_itens` (e não o de `projeto_itens`)
- [ ] Testar uma devolução de venda CNX com a Giovanna e publicar o sistema Orçamentos

### Passos manuais do usuário

- [ ] Autorizar a aplicação da migration 326
- [ ] Informar a venda/peça que a Giovanna tentou devolver, para o teste real

## Objetivo

A devolução usa o preço de `projeto_itens`. As vendas da Connect (CNX-xxxx, 314 vendas, 3.720 itens) foram carregadas pela SPEC-243 com `preco_unitario = 0` e `desconto = 0` — o valor ficou só em `orcamento_itens`. Como não haverá mais importação, o preço passa a valer também em `projeto_itens`.

## Decisões aprovadas

- Não haverá mais importação da Connect (usuário, 06/11/2026) — o preço pode ser gravado em `projeto_itens`.
- Herança continua sem mexer em quantidade, saldos, estoque e financeiro.

## Definição da SPEC

- Vínculo: `projeto_itens.orcamento_item_id → orcamento_itens.id` (preenchido nos 3.719 itens da herança).
- Migration copia `preco_unitario` e `desconto` só onde o preço atual é 0 e o do orçamento é > 0. Desliga na transação `trg_sync_valor_total` e `trg_set_projeto_itens_descricao`; aborta se `projetos.valor_total`, quantidades ou descrições mudarem.
- Ponto de atenção: em 46 itens a quantidade de `projeto_itens` difere de `orcamento_itens`. Isso muda o subtotal usado para converter o desconto global (R$) em %: ex. CNX-4865, desconto R$ 60.154,82 = 19,5% sobre `orcamento_itens`, mas 21,6% sobre `projeto_itens`. Por isso o ajuste do serviço de devolução acima.

## Realizado

### 2026-11-06

- Diagnóstico, migration 326 redigida e dry-run feito (rollback confirmado, banco intacto). Nada aplicado.

## Pendências

- [ ] Aplicar a migration 326 depois da autorização do usuário.
- [ ] Ajustar o cálculo do desconto no serviço de devolução (venda Connect) e publicar.
- [ ] 1 item da herança continua com preço 0 (sem preço no orçamento de origem) — conferir se importa.
