---
titulo: "SPEC-060 — Necessidade de Compra: Cancelar Pedido de Compra"
status: concluído
data_ultima_modificacao: 2026-08-05
sistemas_envolvidos:
  - Necessidade de Compra (compras-lucenera-3o23t98ee)
---

# SPEC-060 — Necessidade de Compra: Cancelar Pedido de Compra

> `status` aceita apenas: `não iniciado`, `pendente`, `concluído`.
> Toda vez que a SPEC for editada, atualizar `data_ultima_modificacao`.

## Checklist de Ação

- [x] Item 1 — Migration `supabase/db/migrations/20260805_076_spec060_cancelar_pedido_compra/`: `ALTER TABLE pedidos_compra ADD COLUMN cancelado_em/cancelado_por/motivo_cancelamento` + RPC nova `cancelar_pedido_compra(p_pedido_id uuid, p_motivo text DEFAULT NULL)`. **Aplicada no Supabase real em 2026-08-05.**
- [x] Item 2 — Frontend (`compras-lucenera-3o23t98ee`, Skip `projectId 40326`): botão "Cancelar Pedido" em `PedidosCompra.tsx` (visível só quando o status permite), com confirmação (`AlertDialog`) e campo opcional de motivo. **Publicado em produção, versão `0.0.51`/`fe7bc4e`.**
- [x] Item 3 — Cancelar o pedido nº 1768 (ACEND ILUMINACAO LTDA), criado por engano em teste no dia anterior — feito via SQL direto (`cancelar_pedido_compra`) antes mesmo do botão ir ao ar, para reverter a distorção na Necessidade de Compra imediatamente.
- [x] Item 4 — Atualizar `supabase/db/domains/estoque_compras.md` com a função/colunas novas.
- [x] Item 5 — Atualizar `CHANGELOG.md`.

### Passos manuais do usuário

- [ ] Nenhum — RPC não tem checagem de papel (mesmo padrão de `criar_pedido_compra_lote`, que qualquer `authenticated` já podia chamar).

## Objetivo

O usuário relatou que um pedido de compra fictício (nº 1768, fornecedor ACEND ILUMINACAO LTDA) foi criado por engano/teste e está distorcendo a tela "Necessidade de Compra" (reduz artificialmente a coluna "Pendente" dos produtos daquele pedido, por contar como "pedido em aberto"). Hoje não existe nenhuma forma de cancelar um pedido de compra pela interface — a tabela `pedidos_compra` só tem policy de `SELECT`, todo `INSERT`/alteração passa por RPC `SECURITY DEFINER`, e nenhuma RPC de cancelamento existe. Esta SPEC cria essa capacidade de forma genérica (não só para o caso pontual) e usa a nova RPC para reverter o pedido 1768 imediatamente.

## Decisões aprovadas

- Reaproveitar o campo `status` já existente (`pedidos_compra_status_check` já aceita `'cancelado'`) — não criar enum/coluna de status novo.
- Cancelamento não é permitido para pedidos já `recebido` ou `parcialmente_recebido` (mercadoria já entrou fisicamente — isso é papel da tela de Devolução, SPEC-015/054, não desta SPEC) nem para pedidos já `cancelado`.
- Parcelas (`pedido_compra_parcelas`) do pedido cancelado que ainda não estão `pago` são marcadas `cancelado` junto — pedido cancelado não deve aparecer como conta a pagar em aberto.
- Sem checagem de papel/permissão na RPC — mesmo padrão já usado por `criar_pedido_compra_lote`/`criar_pedido_compra_de_necessidade` (qualquer usuário `authenticated` do sistema já pode criar pedido, então também pode cancelar).

## Definição da SPEC

### Estado atual confirmado (leitura direta do Supabase real, 2026-08-05)

- Pedido nº 1768: `status = 'enviado'`, `valor_total = 9935.45`, fornecedor ACEND ILUMINACAO LTDA, `empresa_id = NULL` (bug conhecido da SPEC-039/057), 7 itens em `pedido_compra_itens`, **0 parcelas geradas, 0 recebimentos, 0 vínculos em `pedido_compra_item_origem`** — caso limpo, cancelamento não precisa reverter nenhum efeito colateral físico.
- `pedidos_compra` só tem `POLICY authenticated_select_pedidos_compra FOR SELECT USING (true)` — nenhuma policy de `UPDATE`. Confirma que o cancelamento só pode ser feito por RPC `SECURITY DEFINER`, igual às RPCs de criação.
- `vw_necessidade_compra_pedidos_abertos`/`vw_necessidade_compra_pedido_detalhe` (SPEC-039) já filtram por `pedidos_compra.status NOT IN ('recebido', 'cancelado')` — ou seja, **marcar o pedido como `cancelado` já é suficiente** para ele sumir de "pedidos em aberto" e a coluna "Pendente" de `vw_necessidade_compra` voltar a subir. Nenhuma view precisa mudar.
- `PedidosCompra.tsx` (rota `/pedidos`) lista pedidos e expande para o painel de parcelas (`PedidoParcelasPanel.tsx`), mas não tem nenhuma ação de cancelar.

### RPC nova

```sql
cancelar_pedido_compra(p_pedido_id uuid, p_motivo text DEFAULT NULL) RETURNS jsonb
```

- Trava a linha (`FOR UPDATE`), valida existência.
- Bloqueia se `status IN ('recebido', 'parcialmente_recebido', 'cancelado')` — mensagem de erro clara por caso.
- `UPDATE pedidos_compra SET status = 'cancelado', cancelado_em = now(), cancelado_por = auth.uid(), motivo_cancelamento = p_motivo`.
- `UPDATE pedido_compra_parcelas SET status = 'cancelado' WHERE pedido_id = p_pedido_id AND status <> 'pago'`.
- Retorna `{pedido_id, numero, status}`.

### Frontend

- `pedido-compra.ts`: nova função `cancelarPedidoCompra(pedidoId, motivo?)` chamando a RPC.
- `PedidosCompra.tsx`: botão "Cancelar Pedido" na linha (com `stopPropagation` para não expandir/colapsar a linha), visível quando `status` não é `recebido`/`parcialmente_recebido`/`cancelado`. Confirmação via `AlertDialog` (componente já existe no projeto) com campo de motivo opcional. Em sucesso: toast + `loadData()`.

## Impacto no banco

- `ALTER TABLE pedidos_compra ADD COLUMN cancelado_em timestamptz, ADD COLUMN cancelado_por uuid REFERENCES auth.users(id), ADD COLUMN motivo_cancelamento text` (aditivo, sem default obrigatório, sem impacto em dado existente).
- RPC nova `cancelar_pedido_compra`. Nenhuma RPC existente é alterada.

## Impacto em telas

Só `PedidosCompra.tsx` (`compras-lucenera-3o23t98ee`, rota `/pedidos`) ganha o botão/confirmação de cancelamento. `NecessidadeCompra.tsx` não muda — o efeito (Pendente voltando a subir) já é automático via as views existentes.

## Regras de permissão

Sem checagem de papel na RPC (ver "Decisões aprovadas"). Mesma exposição de acesso que já existe hoje para criar pedidos.

## Análise obrigatória de ecossistema

- Depende de `pedidos_compra`/`pedido_compra_itens`/`pedido_compra_parcelas`. Não depende de `projetos`, `orcamentos`, `contatos` (além do FK já existente de fornecedor), `produtos`, `boletos`, `projeto_itens`, `usuarios`, `systems` ou `user_system_access`.
- Afeta só o domínio Estoque/Compras (Necessidade de Compra). Nenhum outro domínio.
- Nenhum dado duplicado sendo criado.
- Nenhuma migration antiga conflita — `pedidos_compra_status_check` já permite `'cancelado'` desde a criação da tabela (SPEC-020).
- Atualiza `supabase/db/domains/estoque_compras.md` (novas colunas + RPC).

## Critérios de aceite

- Pedido em status `rascunho`/`aprovado`/`enviado` pode ser cancelado pela tela; pedido `recebido`/`parcialmente_recebido`/já `cancelado` mostra erro claro e não altera nada.
- Após cancelar, o pedido não aparece mais em "pedidos em aberto" e a coluna "Pendente" de `vw_necessidade_compra` para os produtos daquele pedido volta a refletir o déficit real.
- Pedido 1768 (ACEND ILUMINACAO LTDA) cancelado e confirmado via consulta direta.

## Testes/verificações obrigatórios

- Após aplicar a migration: `SELECT cancelar_pedido_compra('<uuid-1768>', 'Pedido fictício de teste, revertido a pedido do usuário');` e conferir `status = 'cancelado'`.
- `SELECT * FROM vw_necessidade_compra_pedidos_abertos WHERE produto_id IN (<produtos do pedido 1768>)` não deve mais contar esse pedido.
- QA pipeline do Skip (`skip_project_apply_changes`) precisa passar antes de publicar.

## Realizado

### 2026-08-05

- SPEC criada.
- Migration aplicada no Supabase real: colunas novas em `pedidos_compra` + RPC `cancelar_pedido_compra`.
- Pedido nº 1768 (ACEND ILUMINACAO LTDA) cancelado via SQL direto — confirmado que ele não conta mais como "pedido em aberto" em nenhum produto.
- Frontend implementado e publicado em produção via Skip (`projectId 40326`, versão `0.0.51`/`fe7bc4e`) — QA (build+testes) passou antes da publicação.
- `supabase/db/domains/estoque_compras.md` e `CHANGELOG.md` atualizados.

## Pendências

- [ ] Nenhuma. Submodule local `04-Sistemas/compras-lucenera-3o23t98ee` continua desatualizado/sujo (não é uma pendência desta SPEC, achado pré-existente) — implementação ficou só no Skip.
