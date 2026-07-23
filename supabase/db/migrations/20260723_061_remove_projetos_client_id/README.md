# Migration 20260723_061 - Remoção de `projetos.client_id`

## Contexto

Durante a preparação do projeto "Cruzamento de Dados" (ver `01-Documento/01 - Planilhas/AGENTS.md` e `DECISOES.md`), o usuário pediu para confirmar se `projetos.client_id` era uma coluna morta antes de removê-la, já que `projetos.cliente_id` é o campo realmente usado para ligar projeto → cliente.

A busca por `client_id` no código de todos os 11 sistemas não encontrou nenhum uso real (os únicos resultados eram falsos positivos: o `client_id` OAuth do SharePoint em `sync-sharepoint/index.ts`, e a chave `ubiqua_client_id` do carrinho do Ubiqua, ambos sem relação com a coluna do banco).

Mas uma checagem direta no schema (`information_schema.views`, `pg_indexes`, `pg_constraint`) mostrou que `client_id` **era** usado — só que dentro do próprio banco, em 10 views:

- 4 views (`vw_projetos_pipeline`, `vw_projetos_por_status`, `vw_financeiro_projetos`, `vw_dashboard_crm_fechamento`) liam **só** `p.client_id`, sem nenhum fallback. Como `client_id` nunca foi preenchido (0 de 3.700 projetos), essas 4 telas — Pipeline, Financeiro por Projeto, Status de Projetos e Fechamento do CRM — estavam retornando cliente/contagem de clientes vazios para **100% dos projetos**, um bug pré-existente descoberto por esta checagem.
- 6 views (área de estoque/compras: `vw_estoque_saldos_projeto_item`, `vw_entrega_futura_projeto_item`, `vw_transferencias_estoque`, `vw_pedido_compra_item_origem`, `vw_pendencias_re_reserva`, `vw_necessidade_compra_detalhe`) usavam `COALESCE(orcamento.cliente_id, projeto.cliente_id, projeto.client_id)` — `client_id` era só o último fallback, então já eram tolerantes à ausência dele.

Havia ainda um índice (`idx_projetos_client_id`) e uma foreign key (`projetos_client_id_fkey → contatos.id`) só nessa coluna.

## Arquivos

| Arquivo | Função |
|---|---|
| `001_fix_views_para_cliente_id.sql` | Recria as 10 views apontando para `projetos.cliente_id` em vez de `projetos.client_id`. Nas 4 views que expunham a coluna como saída (`client_id`), o nome de saída foi preservado com `AS client_id` na primeira etapa (Postgres não permite renomear coluna de saída num `CREATE OR REPLACE VIEW`) e depois renomeado para `cliente_id` via `ALTER VIEW ... RENAME COLUMN` — output final chama `cliente_id` em todas. Nenhum consumidor (frontend dos 11 sistemas, dashboard Python) foi encontrado lendo o nome `client_id` dessas views, então o rename é seguro. |
| `002_remover_indice_fk_coluna_client_id.sql` | Remove o índice, a foreign key e a coluna `projetos.client_id`. |

## Status

**Já aplicada no Supabase real em 2026-07-23**, diretamente via `psycopg2`/`SUPABASE_DB_URL`, com autorização explícita do usuário, em uma única transação (rollback automático se qualquer etapa falhasse). Reaplicar os dois arquivos depois disso não é idempotente para o `002` (a coluna já não existe — mas usa `IF EXISTS`, então não quebra) nem para o `001` (`CREATE OR REPLACE VIEW` é sempre seguro de reaplicar).

## Verificação feita pós-aplicação

- `vw_projetos_por_status`: antes retornava `total_clientes = 0` em todas as linhas; depois de aplicada, retornou contagens reais (ex: "Obra Finalizada" → 129 clientes).
- `vw_dashboard_crm_fechamento`: mesma correção (ex: mês 06/2025 → 26 clientes, antes 0).
- `vw_financeiro_projetos` e `vw_projetos_pipeline`: testadas com o projeto `24.408 LOJA IORANE` (que já tinha `cliente_id` preenchido) e passaram a retornar o cliente corretamente.
- As 6 views de estoque/compras foram testadas com `SELECT count(*)` para confirmar que não quebraram.
- `information_schema.columns` de `projetos` confirmou que só `cliente_id` restou (sem `client_id`).

## Relação com o projeto de Cruzamento de Dados

Esta remoção era um pré-requisito do **cruzamento 1 (Projeto → Cliente)** do backlog em `01-Documento/01 - Planilhas/AGENTS.md`: preencher `cliente_id` sem deixar uma segunda coluna (`client_id`) ambígua e sem dono claro no banco.
