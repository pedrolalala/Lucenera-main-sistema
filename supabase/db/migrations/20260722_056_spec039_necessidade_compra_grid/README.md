# Migration 20260722_056 - SPEC-039 (Necessidade de Compra: grid full-screen, colunas de fornecedor/empresa/status/entrega, fix de busca)

## Contexto

SPEC completa: `03-Projeto/Planos de Ação/SPECs/SPEC-039_Necessidade_Compra_Grid_Fullscreen_Fix_Busca.md`.

Pedro pediu 4 melhorias na tela **Necessidade de Compra** do sistema `compras-lucenera-3o23t98ee`: layout full-screen, novas colunas (Fornecedor, Empresa que comprou, Status do pedido, Data prevista de entrega), correção de um bug real de busca, e recálculo de "Pendente" considerando pedidos de compra já em aberto. As decisões de negócio (P-01 a P-04) foram fechadas pelo usuário em 21/07/2026 (ver seção "Decisões do usuário" da SPEC).

## Decisões aplicadas nesta migration

- **P-03** (origem de "Empresa que comprou"): nova coluna `pedidos_compra.empresa_id`, preenchida automaticamente dentro das RPCs `criar_pedido_compra_de_necessidade`/`criar_pedido_compra_lote` a partir de `usuarios.empresa_id` do usuário autenticado (`auth.uid()`) — sem input manual no frontend.
- **P-01** (granularidade produto × pedido): Alternativa A — `vw_necessidade_compra` continua 1 linha por produto (resumo agregado); uma view auxiliar nova (`vw_necessidade_compra_pedidos_abertos`) resume N `pedidos_compra` por produto, e outra (`vw_necessidade_compra_pedido_detalhe`) lista cada pedido individualmente para o painel expansível do frontend.
- **P-04** (comportamento do "Pendente"): coluna nova `pendente` em `vw_necessidade_compra` = `GREATEST(0, necessidade_compra - qtd_em_pedidos_abertos)`. O `WHERE` que decide quais produtos aparecem na lista muda de `qtd_reservada > qtd_estoque` para `pendente > 0` — produto some da lista quando o déficit já está 100% coberto por pedido de compra em aberto (decisão contrária à recomendação original da SPEC, mantida por instrução explícita do usuário).
- **P-02** (vocabulário de status): não é migration — o enum real de `pedidos_compra.status` é gravado cru nas views; a tradução para rótulo em português (`rascunho` → "Pendente", etc.) é feita no frontend (`compras-lucenera-3o23t98ee`).

## Arquivos

| Arquivo | Função |
|---|---|
| `001_pedidos_compra_empresa_id.sql` | `ALTER TABLE pedidos_compra ADD COLUMN empresa_id uuid REFERENCES empresas(id)` (+ índice). |
| `002_criar_pedido_compra_empresa_automatica.sql` | Recria (`CREATE OR REPLACE`, sem `DROP FUNCTION` — contagem de parâmetros não muda) `criar_pedido_compra_de_necessidade` (12 parâmetros) e `criar_pedido_compra_lote` (6 parâmetros) para resolver `v_empresa_id` via `SELECT empresa_id FROM usuarios WHERE id = auth.uid()` e gravar em `pedidos_compra.empresa_id` no INSERT. Toda a lógica pré-existente (numeração automática, breakdown de impostos da SPEC-038, validações) foi preservada — conferida contra `20260721_054_spec038_compras_melhorias/002_pedidos_compra_numero_automatico.sql`, a última migration real que recriou essas duas RPCs. |
| `003_vw_necessidade_compra_pedido_resumo.sql` | Duas views novas: `vw_necessidade_compra_pedidos_abertos` (1 linha por produto: `qtd_pedidos_abertos`, `qtd_em_pedidos_abertos`, `proxima_data_prevista_entrega`, `status_mais_critico`) e `vw_necessidade_compra_pedido_detalhe` (1 linha por pedido em aberto: `numero`, `status` cru, `empresa_nome`, `data_prevista_entrega`, `qtd_pendente`) — usada pelo painel expansível do frontend. |
| `004_vw_necessidade_compra_pendente_e_filtro.sql` | `CREATE OR REPLACE VIEW vw_necessidade_compra`, preservando todas as colunas existentes (incluindo as da SPEC-038: `percentual_desconto_compra`, `marca_id`/`marca_nome`, `fornecedor_id`/`fornecedor_nome`) e adicionando `pendente`, `qtd_pedidos_abertos`, `proxima_data_prevista_entrega`, `status_mais_critico`. Troca o `WHERE` de `qtd_reservada > qtd_estoque` para `pendente > 0`. |

## Ordem de aplicação

Estritamente sequencial (001 → 002 → 003 → 004): `004` depende da view criada em `003`; `002` depende da coluna criada em `001`.

## Status

**Rascunhada, não aplicada.** Conforme regra do agente implementador, nenhuma migration desta pasta foi executada contra o Supabase real — aplicação é passo manual do usuário (orquestrador).

## Verificação esperada (pós-aplicação, passo manual do usuário)

- `SELECT column_name FROM information_schema.columns WHERE table_name = 'pedidos_compra' AND column_name = 'empresa_id';` retorna 1 linha.
- Criar um pedido via `criar_pedido_compra_de_necessidade` ou `criar_pedido_compra_lote` com um usuário autenticado cujo `usuarios.empresa_id` esteja preenchido — `pedidos_compra.empresa_id` do registro criado deve bater com esse valor.
- `SELECT * FROM vw_necessidade_compra_pedidos_abertos LIMIT 5;` e `SELECT * FROM vw_necessidade_compra_pedido_detalhe LIMIT 5;` executam sem erro.
- `SELECT produto, necessidade_compra, pendente, qtd_pedidos_abertos, proxima_data_prevista_entrega FROM vw_necessidade_compra LIMIT 20;` retorna as colunas novas; nenhuma linha com `pendente = 0` aparece na view (filtro `WHERE pendente > 0` aplicado).
- Um produto com déficit 100% coberto por pedido de compra em aberto (não recebido/cancelado) deixa de aparecer em `vw_necessidade_compra`, mas continua aparecendo em `vw_necessidade_compra_pedidos_abertos`/`vw_necessidade_compra_pedido_detalhe` (rastreabilidade até o recebimento efetivo).
- Reextrair `supabase/db/current/` depois de aplicar (pendência crônica do domínio, reforçada por esta SPEC).
