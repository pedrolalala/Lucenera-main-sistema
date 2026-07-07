# Migration 20260706_022 — Saldos Operacionais de Estoque por Item de Projeto (SPEC-010)

## Estado

Aplicação da migration base `20260706_022_saldos_estoque_projeto_item`
confirmada no Supabase real em 07/07/2026.

A revisão posterior encontrou ajustes obrigatórios, registrados na migration
`../20260707_023_spec010_hardening/`: views precisam usar
`security_invoker`, `anon`/`authenticated` não devem ler saldos antes da policy
de negócio, o agregado `estoque_itens.quantidade_reservada` precisa ser
reconciliado com saldos abertos e `trigger_fechar_projeto` não pode entregar
diretamente itens em `q_entrega_futura`.

## Problema resolvido

`estoque_itens.quantidade_reservada` é um agregado total por produto: sabe
"quanto está reservado", mas não "de quais projetos/itens". A migration
`20260630_010` já cobria a reserva agregada; esta migration implementa a
[SPEC-010](../SPECs/SPEC-010_Saldos_Estoque_por_Item_de_Projeto.md), que cria
o saldo operacional por `projeto_item_id` — pré-requisito explícito das SPECs
011 (transferência), 012 (entrega futura/necessidade de compra), 014 (badges
ricos no CRM) e 015 (devolução).

## O que esta migration faz

### Arquivo 001 — Tabelas

Cria `estoque_saldos_projeto_item` (uma linha por `projeto_itens.id`, com
`q_reserva`, `q_entrega_futura`, `q_ag_separar`, `q_separado`, `q_entregue`,
`q_devolvida`, `q_transferida_saida` e `status_operacional`) e
`estoque_movimentos_projeto_item` (auditoria de cada operação). Não duplica
`produto_id`/`projeto_id`/`orcamento_id`/`cliente_id` — essas dimensões são
lidas por relacionamento (ver views no arquivo 003).

Cria dois triggers: `atualizado_em` automático, e uma validação
(`fn_validar_saldo_projeto_item`) que impede a soma dos saldos de ultrapassar
`projeto_itens.quantidade` (Q. Venda é imutável e é o teto de qualquer saldo).

Habilita RLS nas duas tabelas **sem criar policy**. A SPEC-010 deixa em
aberto se a visibilidade deve ser por vendedor/projeto ou visão completa de
estoque — sem essa decisão, criar `USING (true)` reproduziria o mesmo padrão
já registrado como achado de segurança recorrente no ecossistema (pendência
crítica 7 do `00_TASKS_GERAIS_ECOSSISTEMA.md`). Enquanto não houver policy,
só `service_role` lê/escreve nessas tabelas.

### Arquivo 002 — RPCs

- **`aprovar_orcamento_financeiro_base_spec001`**: o passo de criação de
  `projeto_itens` passa a rodar em loop (via `RETURNING`), item por item. Para
  cada item com produto, trava (`FOR UPDATE`) a linha de `estoque_itens` do
  produto, calcula a cobertura física disponível, divide a quantidade entre
  `q_reserva` (coberta) e `q_entrega_futura` (não coberta), atualiza
  `quantidade_reservada` e cria a linha de saldo. O lock por linha evita
  corrida quando o mesmo produto aparece em mais de um item do mesmo
  orçamento ou em aprovações concorrentes — risco que o desenho anterior (um
  único `INSERT` em lote) não cobria.
- **`cancelar_orcamento`**: a reversão de `quantidade_reservada` passa a usar
  o saldo aberto real do item (`q_reserva + q_entrega_futura + q_ag_separar +
  q_separado`), não mais a quantidade original do orçamento — evita reverter
  em dobro um item já parcialmente entregue/transferido. Encerra o saldo
  (`status_operacional = 'cancelado'`, zera as posições abertas) e registra o
  movimento de cancelamento.
- **`trigger_fechar_projeto`**: ao fechar o projeto, além do comportamento
  legado já existente, move apenas o saldo fisicamente coberto
  (`q_reserva + q_ag_separar + q_separado`) para `q_entregue`, ajustando o
  agregado `estoque_itens.quantidade_reservada` pela mesma quantidade. Itens
  com `q_entrega_futura` pendente bloqueiam a entrega do projeto até serem
  recebidos/reservados. A granularidade por etapa (exigir separação antes de
  entregar) fica para o futuro fluxo de Logística/Estoque (`EST-14`/`LOG-*`).

### Arquivo 003 — Views

`vw_estoque_saldos_projeto_item` (detalhada, para CRM/Estoque/Logística),
`vw_estoque_por_produto_projeto` (mesma leitura, filtrada a saldos ativos,
para abrir um produto) e `vw_estoque_resumo` (agregado por produto: total
físico, comprometido, disponível, entrega futura).

### Arquivo 004 — Backfill

Cria saldo para `projeto_itens` aprovados antes desta migration existir.
Decisão conservadora: 100% como `q_reserva` (ver comentário no arquivo — o
histórico de cobertura física real por item não é reconstruível com
precisão, e superestimar reserva é o lado seguro do erro). Critério:
`projeto_itens.validado = true`, não o texto de `orcamentos.status` — evita
depender dos valores legados/inconsistentes documentados em
`supabase/docs/status_enums.md`. Idempotente (`ON CONFLICT DO NOTHING`).

## Tabelas afetadas

| Tabela/View | Operação |
|---|---|
| `estoque_saldos_projeto_item` | CREATE |
| `estoque_movimentos_projeto_item` | CREATE |
| `vw_estoque_saldos_projeto_item` | CREATE |
| `vw_estoque_por_produto_projeto` | CREATE |
| `vw_estoque_resumo` | CREATE |
| `aprovar_orcamento_financeiro_base_spec001` | CREATE OR REPLACE |
| `cancelar_orcamento` | CREATE OR REPLACE |
| `trigger_fechar_projeto` | CREATE OR REPLACE |
| `estoque_itens` | sem mudança de estrutura (mesma coluna `quantidade_reservada`) |

## Como aplicar

Em ambiente novo, via Supabase SQL Editor, um arquivo por vez, na ordem
numérica:

```sql
\i 001_create_saldos_movimentos.sql
\i 002_atualizar_aprovacao_cancelamento_entrega.sql
\i 003_views_saldos_estoque.sql
\i 004_backfill_saldos_projeto_item.sql
```

No Supabase real atual, a 022 já foi aplicada. O próximo passo é aplicar
`../20260707_023_spec010_hardening/` em ordem numérica.

## Passos manuais do usuário (pendentes após aplicar)

- [x] Executar a migration base 022 no Supabase SQL Editor após revisão.
- [ ] Executar o hardening `20260707_023_spec010_hardening`.
- [ ] Rodar o relatório de conferência comentado no fim do arquivo 004 e
      decidir se algum produto sobre-comprometido no histórico precisa de
      ajuste manual. Para o banco real atual, a reconciliação conhecida ficou
      codificada no arquivo `002_reconcile_quantidade_reservada.sql` da 023.
- [ ] Validar com Vitória/Débora a tela de produto: disponível, reservado,
      entrega futura, separação, entregue, transferido e devolvido.
- [ ] Definir a policy de RLS destas duas tabelas (vendedor vê só os
      próprios projetos vs. visão completa de estoque) — hoje só
      `service_role` acessa.
- [ ] Atualizar `supabase/db/current/01_schema_full.sql` (e
      `03_functions.sql`/`04_triggers.sql`/`05_views.sql`) depois da migration
      023 aplicada, conforme `AGENTS.md`.
- [ ] Atualizar `04-Sistemas/<sistema>/supabase/AI_DB_CONTEXT.md` dos sistemas
      que vão consumir o saldo por item (CRM para a SPEC-014; futuro Estoque
      e Compras; Logística).

## Como verificar após aplicar

```sql
-- 1. Confirmar que as tabelas existem
SELECT table_name FROM information_schema.tables
WHERE table_name IN ('estoque_saldos_projeto_item', 'estoque_movimentos_projeto_item');

-- 2. Conferir que o backfill rodou
SELECT count(*) FROM public.estoque_saldos_projeto_item;

-- 3. Aprovar um orçamento de teste (em transação segura):
BEGIN;
SELECT public.aprovar_orcamento_financeiro_base_spec001('<uuid-do-orcamento>');
-- Verificar resultado: deve conter "saldos_operacionais_criados" > 0
SELECT * FROM public.vw_estoque_saldos_projeto_item
WHERE orcamento_id = '<uuid-do-orcamento>';
ROLLBACK; -- não confirmar em teste

-- 4. Cancelar o mesmo orçamento de teste (outra transação) e confirmar que
--    o saldo aparece com status_operacional = 'cancelado' e os campos
--    abertos zerados.
```

## Pendência futura (não bloqueante)

Granularidade completa de `q_ag_separar`/`q_separado` (RPCs de solicitar
separação e confirmar separação) e a lógica de transferência entre
`projeto_item_id` (SPEC-011) e entrega futura/necessidade de compra
(SPEC-012) ainda não foram implementadas — dependem desta migration como
base e ficam para as próximas SPECs.
