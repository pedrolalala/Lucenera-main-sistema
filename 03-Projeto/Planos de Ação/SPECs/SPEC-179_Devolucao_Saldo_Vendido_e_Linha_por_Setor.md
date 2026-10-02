---
titulo: "SPEC-179 — Devolução: saldo = vendido − devolvido, uma linha por setor e efeito no estoque por setor"
status: aplicada (migration 20261002_178) e publicada (Orçamentos 32554 v0.0.379 — 02/10), aguardando teste
data_ultima_modificacao: 2026-10-02
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb) — rotina de devolução
  - Banco central — orcamento_itens, estoque_saldos_projeto_item, estoque_itens, separacao_itens
  - Separação Parcial / Logística — triggers de separação (efeito indireto, correção)
  - Compras — aba de devolução por setor usa a mesma RPC (passa a aceitar "em separação")
dependencias:
  - SPEC-178 (devolução a partir de venda efetivada, valor líquido, mesma empresa)
  - SPEC-054 (registrar_devolucao_projeto_item_setor)
  - SPEC-071 (devolução via orçamento)
---

# SPEC-179 — Devolução: saldo do vendido, linha por setor, efeito por setor

Regras R1–R4 repassadas pelo usuário em 02/10/2026.

## Decisões do usuário (02/10)

- Material "a separar"/"separado" entra como setor próprio **"Em separação"**: é físico, volta ao estoque e sai
  da fila da separação.
- Devolução de **Entregue** volta ao estoque **na aprovação da devolução** (sem etapa de coleta).

## Como era (achados)

- Aprovação da devolução usava `registrar_devolucao_projeto_item` em cascata (entrega futura → reserva →
  entregue), sem setor por linha. Material em separação ficava fora do disponível (ex.: VENDA-0002 aros, vendido
  34, disponível 29).
- `registrar_devolucao_projeto_item_setor` com "entregue" gravava `aguardando_coleta` (não existe fluxo de entrada)
  e somava `q_devolvida` sem baixar `q_entregue` — estourava `fn_validar_saldo_projeto_item` quando todo o
  vendido já estava entregue.
- Triggers da separação moviam a quantidade cheia de `separacao_itens` ignorando `quantidade_estornada` (bug
  também do estorno parcial já existente).
- Venda da Dammari citada no pedido não existe no banco; `devolucoes_estoque` estava vazia.

## Regras implementadas

- **R1/R2**: saldo do item = reserva + entrega futura + em separação + entregue = vendido − já devolvido (o
  trigger `fn_validar_saldo_projeto_item` garante a soma). Não é o estoque do produto.
- **R3**: uma linha por setor. `orcamento_itens.setor_origem` (reserva, entrega_futura, em_separacao, entregue);
  a busca mostra uma linha por setor com saldo; a aprovação devolve de cada setor pela RPC por setor.
- **R4**: a aprovação da venda soma tudo em `estoque_itens.quantidade_reservada` e nada libera na
  separação/entrega; por isso devolver n libera n da reserva em qualquer setor — reserva/em separação/entregue
  (físico) aumentam o disponível; entrega futura diminui a necessidade de compra (virtual).
- Validação: tela (A Devolver ≤ saldo do setor), ao salvar (por item e por setor) e no banco (RPC recusa acima
  do saldo do setor).

## Migration `supabase/db/migrations/20261002_178_devolucao_por_setor/`

1. `001` coluna `orcamento_itens.setor_origem` + CHECK.
2. `002` `replace_orcamento_itens` grava `setor_origem`.
3. `003` `registrar_devolucao_projeto_item_setor`: setor em_separacao (baixa a separar → separado, marca
   `quantidade_estornada`, cancela a separação se tudo foi devolvido), entregue baixa `q_entregue`, libera
   reserva em todos os setores, status `registrada`.
4. `004` `aprovar_orcamento_financeiro` (ramo devolução): linha com setor usa a RPC por setor; linha antiga sem
   setor segue a cascata.
5. `005` triggers `sync_separado_ao_ficar_pronto`, `sync_entregue_ao_finalizar_separacao`,
   `sync_entregue_ao_finalizar_entrega` movem só `quantidade − quantidade_estornada`.

Dry-run (ROLLBACK) em 02/10 com o item real VENDA-0002 aros (reserva 24, EF 5, a separar 5): devolver 2 reserva +
1 EF + 3 em separação → reserva 22, EF 4, a separar 2, devolvida 6, reserva do produto 13 → 7, 3 estornadas na
separação; excesso recusado; finalizar a separação depois moveu só 2 para entregue; devolver 2 entregue →
soma dos setores = 34 = vendido. Sem overload de função.

## Frontend (Orçamentos)

`devolucoesService.ts` (linhas por setor, saldo do item, validação por setor), `DevolucaoItemSearchModal.tsx`
(coluna Setor, "já devolvido · saldo do item", "saldo no setor"), `BudgetFormPage.tsx` / `useBudgetStore.ts`
(`setor_origem` no item, gravação e leitura), `BudgetItemCard.tsx` (selo "Devolução · Setor" na linha).

## Pontos em aberto

- `estoque_itens(local='Estoque')` é sobrescrito pelo sync do Connect (como já acontece com a reserva da venda).
- Ordem de publicação: aplicar a migration **antes** de publicar o frontend (o frontend lê `setor_origem`).
- Rollback: reaplicar as definições anteriores (salvas no scratchpad da sessão) e `DROP COLUMN setor_origem`.
