---
titulo: "SPEC-136 — Número da venda, distinto do número do orçamento"
status: "APLICADO em produção (2026-09-14)"
data_ultima_modificacao: 2026-09-14
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb) — schema `orcamentos`, RPC `aprovar_orcamento_financeiro`
  - Separação (separacao-parcial) — `SeparacaoParcialPage.tsx`, `separacaoParcialService.ts`
dependencias:
  - SPEC-135 (esta migration é superset da versão de `aprovar_orcamento_financeiro` corrigida lá — pode ser aplicada sozinha)
---

# SPEC-136 — Número da venda, distinto do número do orçamento

> Origem: usuário testando a rotina de Separação — a tela mostra "Venda: ORC-0032", usando o número do orçamento como se fosse o número da venda, sem nenhum identificador próprio pra diferenciar as duas coisas.

## Checklist de Ação

- [x] Adicionar coluna `orcamentos.numero_venda text`.
- [x] Gerar `numero_venda` dentro de `aprovar_orcamento_financeiro`, só no ramo venda, no momento em que o status vira `Orçamento Aprovado`.
- [x] Expor `numero_venda` em `vw_estoque_saldos_projeto_item` (coluna `venda_numero`).
- [x] Atualizar `separacaoParcialService.ts`/`SeparacaoParcialPage.tsx`: mostrar orçamento e venda como campos distintos; busca aceita os dois números.
- [x] Atualizar `useBudgetStore.ts` (`Budget`, `ApprovalResult`) e `FinanceResultModal.tsx` (mostra o número da venda no resultado da aprovação).
- [x] Escrever migration em `supabase/db/migrations/20260911_136_orcamento_numero_venda/` e copiar para o submodule.
- [x] Atualizar `AI_DB_CONTEXT.md` do sistema de Orçamentos.
- [x] **Aplicar a migration no Supabase real** — aplicada em 2026-09-14 pelo usuário (comando `psql` rodado via `!` no chat), após dry-run (`BEGIN; ...; ROLLBACK;`) confirmando sucesso sem erros. Confirmado via `information_schema.columns` que `orcamentos.numero_venda` e `vw_estoque_saldos_projeto_item.venda_numero` existem, e via `pg_get_functiondef` que `aprovar_orcamento_financeiro` tem `v_numero_venda`.
- [ ] Rodar `pnpm run lint`/`pnpm run build` nos dois sistemas após aplicar (typecheck e lint locais já rodados e limpos nesta sessão).
- [ ] Teste ao vivo: aprovar um orçamento novo e conferir que aparece `numero_venda` no resultado e na Separação; abrir a Separação de um orçamento aprovado ANTES desta SPEC e confirmar que mostra "Venda: —" sem quebrar nada.
- [ ] Decidir e implementar, em SPEC futura, os itens ainda pendentes de propagação (ver "Pendências").

## Objetivo

Hoje, em qualquer lugar do ecossistema que mostra um orçamento já aprovado (a começar pela rotina de Separação), o único identificador disponível é o número do orçamento (`ORC-0032`) — usado inclusive como rótulo "Venda" na tela de Separação, apesar de ser, na origem, o número do orçamento/proposta, não da venda em si. O usuário pediu um número de venda de verdade, sequencial, para diferenciar claramente as duas coisas.

## Decisões aprovadas (usuário, 2026-09-11)

1. **Quando gerar**: no momento da aprovação financeira (`aprovar_orcamento_financeiro`), quando o orçamento de fato vira uma venda.
2. **Escopo da sequência**: global — uma única sequência pra toda a Lucenera, mesmo padrão do `ORC-0001`/`ORC-0002` já usado hoje.
3. **Formato**: `VENDA-0001`.
4. **Onde deve aparecer**: em todo lugar que hoje mostra o orçamento já aprovado (não só na Separação) — implementado nesta SPEC para Separação e Orçamentos; CRM/Logística/Dashboard ficam como pendência explícita (ver abaixo).
5. **Relação com a tabela legada `vendas`**: são coisas **diferentes**, por escolha do usuário. Achado durante a investigação: existe uma tabela `public.vendas` (com `cod_venda`, `num_nota`) que é a numeração legada do Connect, usada por 3 views de dashboard (`vw_financeiro_projetos`, `vw_projetos_pipeline`, `vw_projetos_resumo`) — mas `aprovar_orcamento_financeiro` nunca insere nada ali, então essas views provavelmente não recebem nenhuma venda nova desde que o sistema de Orçamentos entrou em produção. O usuário decidiu **não** mexer nisso agora — `numero_venda` é um campo novo, independente, só em `orcamentos`. Esse gap das 3 views fica documentado, não corrigido, fora do escopo desta SPEC.
6. **Devolução não gera número de venda** (decisão minha, não re-confirmada explicitamente com o usuário — assunção de baixo risco, fácil de reverter): natureza_operacao='devolucao' é um crédito sobre uma venda já existente, não uma venda nova, então não teria sentido gerar outro número de venda pra ela.

## Investigação

- `orcamentos.numero` (formato `ORC-0001`) é gerado por `set_orcamento_numero()` — trigger `BEFORE INSERT`, `MAX(SUBSTRING(numero FROM 5))+1`. Usei o mesmo padrão pra `numero_venda`.
- `vw_estoque_saldos_projeto_item` (a view usada pela Separação) já fazia `LEFT JOIN orcamentos o` — só faltava expor a coluna nova.
- `separacaoParcialService.ts` trata `orcamento_numero` como "número da venda" em vários pontos (`VendaInfo.orcamentoNumero`, comentário SPEC-072: "replica a tela antiga do Connect, campo 'Venda'") — confirma que esse apelido já vinha de antes, sem um número de venda real por trás.
- Tabela `public.vendas` (achado, ver decisão 5 acima): schema com `cod_venda integer`, `num_nota text`, `projeto_id`, `valor_total`, `valor_pago`, `status_pagamento`, `historico_legado boolean` — não tem `orcamento_id`, não é alimentada por nenhuma RPC do fluxo atual.

## Implementação

### Banco (migration `supabase/db/migrations/20260911_136_orcamento_numero_venda/001_numero_venda.sql`)

- `ALTER TABLE orcamentos ADD COLUMN IF NOT EXISTS numero_venda text;`
- `aprovar_orcamento_financeiro`: no ramo venda, logo antes do `UPDATE ... SET status = 'Orçamento Aprovado'`, gera `numero_venda` (se ainda não existir) com `MAX(...)+1` sobre `numero_venda LIKE 'VENDA-%'`, e grava junto no mesmo `UPDATE`. Devolve `numero_venda` no `jsonb` de retorno (tanto no caminho "já processado" quanto no de aprovação nova). Ramo devolução não é alterado.
- `vw_estoque_saldos_projeto_item`: `CREATE OR REPLACE VIEW` adicionando `o.numero_venda AS venda_numero` ao final da lista de colunas (mantém ordem/nome de todas as colunas existentes).
- Migration é **superset** da versão de `aprovar_orcamento_financeiro` corrigida pela SPEC-135 (já inclui o bloqueio de peça sem cadastro) — pode ser aplicada sozinha, mesmo sem aplicar a 135 antes.

### Frontend

- **Separação** (`separacaoParcialService.ts`): `VendaInfo`, `VendaDisponivel` ganham `vendaNumero: string | null`. `listarVendasDisponiveis` e `buscarVendaPorNumero` passam a buscar/retornar `venda_numero`. A busca por número (`buscarVendaPorNumero`) agora aceita tanto o número do orçamento quanto o número da venda — feita como **duas queries `.eq()` separadas em paralelo** (não um `.or()` com o valor digitado interpolado na string do filtro, que arriscaria injeção via vírgula/parênteses no PostgREST).
- **Separação** (`SeparacaoParcialPage.tsx`): tela de detalhe agora mostra "Orçamento:" e "Venda:" como campos distintos (antes só existia um campo rotulado "Venda:" mostrando o número do orçamento); lista de busca ganhou coluna "Venda"; busca por texto passa a considerar `vendaNumero` também; impressão da lista de separação mostra os dois números.
- **Orçamentos** (`useBudgetStore.ts`): `Budget.numero_venda` e `ApprovalResult.numero_venda` adicionados à tipagem (o `select('*')` já traz a coluna nova automaticamente, sem mudar a query).
- **Orçamentos** (`FinanceResultModal.tsx`): modal exibido logo após a aprovação financeira agora mostra "Venda: VENDA-0001" junto com o número do orçamento.

## Backfill de orçamentos aprovados antes da migration (2026-09-14)

Pedido do usuário: orçamentos que já estavam em "Orçamento Aprovado" antes desta migration rodar não tinham `numero_venda` (só é gerado no momento da aprovação, não retroativo). Consulta direta no banco confirmou o que o usuário já esperava: **`ORC-0032` era o único caso** (`status = 'Orçamento Aprovado'`, `numero_venda IS NULL`, `natureza_operacao = 'venda'`). Migration `supabase/db/migrations/20260914_142_backfill_numero_venda_orc0032/001_backfill_numero_venda.sql` — genérica (cobre qualquer orçamento nessa mesma condição, não só o ORC-0032 nominalmente), mesma lógica de sequência global `VENDA-000N` da RPC. Testada com dry-run antes de aplicar. **Aplicada com sucesso em produção**: `ORC-0032` agora tem `numero_venda = VENDA-0001`.

## Pendências (fora do escopo implementado agora)

- [ ] Mostrar `numero_venda` em mais lugares do próprio sistema de Orçamentos (ex.: `BudgetTableRow.tsx`, `FinancialApprovalRow.tsx`) — não implementado nesta rodada por não haver um slot óbvio de UI pra isso sem redesenhar a linha da tabela; avaliar com o usuário onde encaixar.
- [ ] Propagar para CRM (`lucenera-crm-3bd29`), Logística (`lucenera-logistics-b7cd1`) e Dashboard (`dashboard-lucenera-b02z85wa3`) — nenhum desses sistemas foi tocado nesta SPEC. Decisão do usuário foi mostrar "em todo lugar que hoje mostra o orçamento aprovado", mas a extensão completa a todos os sistemas ficou pra uma rodada futura, pra não fazer mudanças amplas sem revisão em várias bases de código de uma vez.
- [ ] O achado da tabela `public.vendas` legada, aparentemente parada desde a entrada do sistema de Orçamentos em produção (3 views de dashboard financeiro sem vendas novas) — reportado, não corrigido; decisão explícita do usuário de tratar como fora de escopo desta SPEC.
- [ ] Confirmar com o usuário se devolução deveria mesmo ficar sem `numero_venda` (assunção feita sem pergunta explícita, por ser óbvia/baixo risco).

## Critérios de aceite

- [ ] Aprovar financeiramente um orçamento novo (ramo venda) grava `numero_venda` no formato `VENDA-000N`, sequencial e global.
- [ ] Aprovar um orçamento de devolução não grava `numero_venda`.
- [ ] Re-chamar a aprovação de um orçamento já processado (idempotência) retorna o mesmo `numero_venda` já gravado, sem gerar um novo.
- [ ] Tela de Separação mostra "Orçamento" e "Venda" como campos distintos; busca por qualquer um dos dois números encontra a mesma venda.
- [ ] Orçamentos aprovados antes desta SPEC continuam funcionando normalmente na Separação, mostrando "Venda: —" (sem erro).
- [ ] `pnpm run lint`/`pnpm run build` passam nos dois sistemas.

## Realizado

### 2026-09-11

- Investigação: `orcamentos.numero`/`set_orcamento_numero()` como padrão de referência; `vw_estoque_saldos_projeto_item` já teria o join necessário; achado da tabela legada `public.vendas`, aparentemente órfã desde a entrada do sistema de Orçamentos em produção.
- 5 decisões de design fechadas com o usuário (quando gerar, escopo da sequência, formato, onde mostrar, e a decisão de não reaproveitar `vendas`).
- Migration escrita (superset da SPEC-135), views e frontend de Separação + Orçamentos atualizados. Typecheck e lint limpos nos dois sistemas.
- **Não aplicado no Supabase real** — mesma restrição da SPEC-135 (classificador de modo automático).

### 2026-09-14

- **Bug encontrado antes de aplicar** (verificação prévia, não em produção): a migration original inseria `o.numero_venda AS venda_numero` no MEIO da lista de colunas de `vw_estoque_saldos_projeto_item` (entre `orcamento_numero` e `q_venda`). `CREATE OR REPLACE VIEW` no Postgres só aceita colunas novas no final da lista — a migration original teria falhado com `cannot change name of view column` ao ser aplicada. Corrigido nos dois arquivos (`supabase/db/migrations/20260911_136_.../001_numero_venda.sql` e a cópia em `04-Sistemas/gestao-financeira-clone-544cb (1)/supabase/migrations/`): `venda_numero` movida pro final da lista de colunas. Nenhum nome/posição de coluna existente muda; `separacaoParcialService.ts` já seleciona por nome (`venda_numero`), não por posição — zero impacto no frontend.
- Verificação prévia via `pg_get_functiondef` direto no Supabase real: `aprovar_orcamento_financeiro` e `replace_orcamento_itens` ao vivo batem byte a byte com a versão "antes do fix" assumida pela SPEC-135/136 (única diferença é exatamente o bloco que a migration pretende adicionar) — confirma que nada mudou nesses dois domínios desde 11/09, seguro aplicar. Confirmado também que `orcamentos.numero_venda` ainda não existe em produção.
- **Tentativa de aplicar a migration corrigida foi bloqueada pelo classificador de modo automático do Claude Code** (ação "Production Deploy") — testada com dry-run (`BEGIN; ...; ROLLBACK;`, sem erros) e depois rodada de verdade pelo usuário via `!` no chat. **APLICADA com sucesso.**
- **Correção do texto acima** ("não precisa rodar a 135 separadamente"): isso valia só pra função `aprovar_orcamento_financeiro` (bloqueio de peça sem cadastro) — essa parte é de fato superset. Mas a SPEC-135 tem uma SEGUNDA função, `replace_orcamento_itens` (o fix do "reset falso-positivo", Prompt 1 do documento), que esta migration **nunca tocava**. Só percebi isso depois de aplicar e conferir cada função separadamente no banco real. Corrigido com uma migration extra: `supabase/db/migrations/20260914_139_fix_replace_orcamento_itens_pos_136/001_replace_orcamento_itens_no_op.sql`, aplicando só `replace_orcamento_itens` sem tocar `aprovar_orcamento_financeiro` (reaplicar a versão da 135 nela reverteria `numero_venda`). Também testada com dry-run e aplicada com sucesso pelo usuário.
- Confirmado em produção via `information_schema.columns` (`orcamentos.numero_venda`, `vw_estoque_saldos_projeto_item.venda_numero`) e `pg_get_functiondef` (`aprovar_orcamento_financeiro` com `v_numero_venda`; `replace_orcamento_itens` com `v_itens_iguais`) — as duas funções e a coluna/view estão corretas em produção.

## Como aplicar (histórico — já aplicado em 2026-09-14)

```
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f "supabase/db/migrations/20260911_136_orcamento_numero_venda/001_numero_venda.sql"
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f "supabase/db/migrations/20260914_139_fix_replace_orcamento_itens_pos_136/001_replace_orcamento_itens_no_op.sql"
```

As duas já foram rodadas com sucesso — comando deixado aqui só como referência histórica/rollback de contexto, não é mais uma pendência.
