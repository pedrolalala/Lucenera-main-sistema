---
titulo: "SPEC-295 — Matheus efetiva Garantia, Uso e Consumo e Descarte sem esperar o financeiro"
status: banco APLICADO 13/11/2026 (migrations 349 e 350); front Orçamentos buildado, deploy pendente
---
# SPEC-295
Problema: desde a SPEC-279 (11/11) garantia, uso e consumo e descarte esperam a Revisão Financeira, atrasando o Matheus. Decisão do usuário (13/11): **o Matheus efetiva**, mantendo a passagem pela revisão (o financeiro continua vendo o registro).

- Migration 349: exceção individual do Matheus — criar/editar em Controle de Produção e Controle de Garantia (antes só ver).
- Migration 350: acesso-chave sem card `orcamentos-efetivar-sem-cobranca` (como `financeiro-rt-comissao`, SPEC-269) concedido ao Matheus; `aprovar_orcamento_financeiro` aceita quem tem essa chave **só** para natureza `outros`/`sac` exceto EMPRESTIMO. Venda/devolução continuam exigindo `orcamentos` aprovar. (Módulo de papel não serve: valeria para todo mundo com Orçamentos editar.)
- Orçamentos (front): hook `usePodeEfetivarSemCobranca`; aba "Revisão Financeira Pendente" abre para quem tem a chave, listando e aprovando só tipos sem cobrança; sem "Devolver para Equipe".
- Dry-run em ROLLBACK: Matheus negado em venda (ORC-0043), aprova bonificação (ORC-0053, voltou a pendente).
- Para dar a mesma chave a outra pessoa (ex.: Vitória): inserir em `user_system_access`.
- Pendente: deploy do Orçamentos (`financeiro-lucenera`), teste real do Matheus, CHANGELOG. Rollback: `rollback.sql` de cada migration + reverter o commit do front.
