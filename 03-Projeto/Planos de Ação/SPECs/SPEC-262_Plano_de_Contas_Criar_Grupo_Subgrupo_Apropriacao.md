---
titulo: "SPEC-262 — Criar Grupo / Subgrupo / Apropriação do plano de contas pela tela"
status: aplicada
---

# SPEC-262 — Criar Grupo, Subgrupo e Apropriação

> Pedido da Central (05/11/2026), "Criação de Nomenclatura em Apropriação/Grupo/Subgrupo": "tem que ter algum lugar para criar uma apropriação, grupo ou subgrupo. Ex.: lançar conta da obra de São Paulo → criar o subgrupo Obra São Paulo".

## Achado
- `plano_de_contas` é uma árvore de 3 níveis (Grupo → Subgrupo → Apropriação; hoje 5 / 16 / 138). A tela só selecionava. Escrita só para `service_role` (carga da Connect); `codigo_connect` é obrigatório e único por nível+pai.
- Quem referencia: `financeiro_titulos.plano_contas_id`, `notas_fiscais_compra`, `negociacoes`, `boletos.apropriacao_id`.

## Feito
- [x] Migration 312 **APLICADA** (08/11, dry-run com ROLLBACK testado como Caroline, Débora e anon): função `plano_contas_criar(nome, nivel, parent_id, tipo)` SECURITY DEFINER. Exige login + permissão `criar` no financeiro (`hub_pode_executar`); nome em MAIÚSCULAS; sem duplicar no mesmo pai; pai um nível acima e ativo; grupo exige tipo existente, os demais herdam o tipo do pai; `codigo_connect` na faixa 800.000.001+ (Connect vai até 90.000.035). anon sem execução; insert direto continua bloqueado por RLS.
- [x] Front (Contas a Pagar/Receber, `CadastrarDuplicata`): botão "+ Novo" em Grupo, Sub grupo e Apropriação (os dois últimos só depois de escolher o pai); janela pede o nome (e o tipo, no grupo); recarrega a lista e já seleciona o item criado. Commit local, `tsc` 41 erros antes e depois (dívida antiga).
- [x] Contas a Pagar publicado 08/11 (wrangler, deploy 001665da, bundle em São Paulo; commit 1f39da1 pushado junto com a Fase 5 da SPEC-258).
- [ ] Teste em tela pela Caroline (criar "Obra São Paulo" como subgrupo de Despesas).

## Observações
- Não há tela para renomear/desativar itens do plano; só criar (como pedido). Se errarem o nome, hoje só por SQL.
- Mesmo código no Contas a Receber; só passa a valer lá no próximo deploy dele.
- Importadores da Connect usam `codigo_connect` próprio: os códigos 8xx não colidem.

## Rollback
`supabase/db/migrations/20261108_312_spec262_plano_contas_criar/rollback.sql` (remove a função; itens criados ficam) + reverter o commit do front.
