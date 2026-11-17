---
titulo: "SPEC-321 — Cancelar venda aprovada com pedido de compra em andamento: pop-up de aviso e peças em trânsito entram no Estoque Geral"
status: em_andamento
data_ultima_modificacao: 2026-11-17
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb) — botão/ação de cancelar venda + pop-up
  - Compras (compras-lucenera-3o23t98ee) — aviso ao comprador, entrada de NF
  - Banco (Supabase) — função cancelar_orcamento, novo RPC de prévia, financeiro
---

# SPEC-321 — Cancelar venda com pedido em andamento

> Origem: caso ORC-0048 / VENDA-8527 (projeto 26.315, Ana Paula Curiacos Urtado), 17/11/2026. Cliente cancelou; pedido de compra 2013 (`aguardando_aprovar`, 12 itens, 32 un., nada recebido) estava vinculado.
> Relacionadas: SPEC-299 (destino por projeto, `liberar_destino_projeto_pedido_item`), SPEC-038 (`pedido_compra_item_origem`), SPEC-234 A (trava `baixa_direta`), SPEC-195 (vínculo Connect), SPEC-258 (financeiro novo), SPEC-318 (log de atividade).

## Checklist de Ação

**A. Banco**
- [ ] A1. Corrigir `cancelar_orcamento`: o bloco que desfaz a aprovação testa `status = 'aprovado'`, mas o status real é `'Orçamento Aprovado'` (e `'Aprovação Financeira'`). Hoje cancelar só troca o status e deixa reservas, entrega futura, parcelas, boletos, título e negociação vivos.
- [ ] A2. Na mesma função, cancelar também no financeiro: `financeiro_titulos` (preencher `cancelado_em`, `cancelado_por`, `motivo_cancelamento`) e `negociacoes`/parcelas do orçamento — só se nada foi pago (se houver parcela paga, recusar com mensagem e exigir o financeiro).
- [ ] A3. Na mesma função, tratar pedidos de compra: para cada item de pedido ligado ao orçamento (`pedido_compra_item_origem` pelos `projeto_itens` do orçamento) e destinos por projeto (`pedido_compra_item_destino_projeto` do `projeto_id`), **liberar o vínculo** (mesma regra do `liberar_destino_projeto_pedido_item`, motivo "Cancelamento da venda X por Fulano"). A quantidade vira pedido livre: ao chegar, a entrada não encontra `q_entrega_futura` desse projeto e a peça entra no **Estoque Geral**.
- [ ] A4. Novo RPC `previa_cancelamento_orcamento(p_orcamento_id)` (somente leitura): devolve os pedidos em andamento vinculados (número, status, fornecedor, peça, quantidade, previsão de chegada, quem criou), parcelas/boletos abertos e se há algo pago. Alimenta o pop-up.
- [ ] A5. `cancelar_orcamento` devolve no JSON os pedidos liberados e grava no histórico quem cancelou, motivo obrigatório, pedidos afetados. Registrar no log de atividade (SPEC-318).
- [ ] A6. Aviso a Compras: criar registro/notificação (reaproveitar o aviso Teams da SPEC-229 se couber) dizendo "Venda X cancelada: pedido NNNN tem N peças que entram no Estoque Geral".

**B. Orçamentos (telas)**
- [ ] B1. Ação "Cancelar venda" em orçamento aprovado (hoje não existe tela que chame `cancelar_orcamento` — conferido por busca no repo; se existir em outro sistema, reaproveitar).
- [ ] B2. Pop-up de confirmação que abre **só quando há pedido em andamento** (e um simples de confirmação nos demais casos), mostrando: **quem está cancelando** (nome + data/hora), cliente/venda, motivo (obrigatório), lista dos pedidos de compra vinculados (nº, fornecedor, status, peças e quantidades, previsão), e o texto "estas peças vão entrar no Estoque Geral quando chegarem; a Compras será avisada".
- [ ] B3. Se a venda for vínculo Connect ou `baixa_direta`, mostrar a mensagem de bloqueio já existente (não cancelar).

**C. Compras**
- [ ] C1. Pedido que teve venda cancelada ganha etiqueta "Venda cancelada — peças para Estoque Geral"; na Entrada de NF o "Para quem" não sugere o projeto cancelado e a peça entra no Estoque Geral.
- [ ] C2. Compras decide, no pedido, se mantém, reduz ou cancela o pedido (não é automático: pedido já aprovado/pago tem fornecedor).

**Entrega**
- [ ] Migration com dry-run em ROLLBACK (sem COMMIT embutido), backup em schema `backup`, teste como usuário sem acesso, publicar Orçamentos e Compras, CHANGELOG, `AI_DB_CONTEXT.md`.

### Passos manuais do usuário
- [ ] Aprovar as decisões abaixo.
- [ ] Decidir o destino do ORC-0048 agora (ver "Caso ORC-0048").

## Regras (decisões propostas)

1. Cancelar nunca apaga: o orçamento fica `cancelado` com histórico (quem, quando, motivo).
2. Peça em trânsito **não vira reserva de outra venda sozinha**: entra no Estoque Geral; a necessidade de compra das outras vendas passa a enxergá-la pelo fluxo normal.
3. Pedido não é cancelado automaticamente — só o vínculo com a venda cai. A Compras é avisada.
4. Venda com parcela **paga** ou nota fiscal emitida: não cancela por esta tela (encaminhar ao financeiro / devolução).
5. Pop-up nomeia sempre quem cancela; a mesma informação vai para o histórico e o aviso.

## Caso ORC-0048 (verificado no banco real, 17/11)

- Status `Orçamento Aprovado` (16/11); 39 itens, saldos ativos (28 reserva + 102 entrega futura), 6 parcelas pendentes (R$ 23.000), 6 boletos `pendente_registro`, 1 título a receber, 1 negociação (duplicata 900052), sem NF.
- Pedido de compra **2013**, `aguardando_aprovar`, 12 itens / 32 un., via `pedido_compra_item_origem`; sem destino por projeto.
- Não usar o botão atual para esse caso (A1). Depois da migration, cancelar pela função corrigida, com dry-run antes.

## Critérios de aceite
- Cancelar venda aprovada: reservas/entrega futura zeradas, parcelas e boletos pendentes cancelados, título/negociação cancelados com motivo, vínculos de pedido liberados.
- Pop-up mostra quem cancela e os pedidos; sem pedido, confirmação simples.
- Entrada de NF do pedido 2013 depois do cancelamento: peças entram no Estoque Geral (`estoque_itens` local Estoque, sem reserva).
- Venda com parcela paga é recusada com mensagem clara.
- Usuário sem acesso não chama o RPC; `anon` sem acesso.

## Ecossistema
Depende de `orcamentos`, `projeto_itens`, `estoque_saldos_projeto_item`, `estoque_itens`, `projeto_parcelas`, `boletos`, `financeiro_titulos`, `negociacoes`, `pedidos_compra`, `pedido_compra_itens`, `pedido_compra_item_origem`, `pedido_compra_item_destino_projeto`. Afeta Orçamentos, Compras, Financeiro e Estoque. Confirmar nomes no banco real antes de redigir (feito para as tabelas acima em 17/11).

## Rollback
`rollback.sql` recria `cancelar_orcamento` com a definição atual (guardada em `backup`) e remove o RPC novo; nenhum dado existente é alterado pela migration.

## Realizado
### 2026-11-17
- SPEC criada a partir do caso ORC-0048; nada implementado nem aplicado.

### 2026-11-17 (implementação)
- Migration 381 REDIGIDA e ensaiada em ROLLBACK no ORC-0048 (NÃO aplicada). Resultado: previa lista pedido 2013 (5 produtos), anon barrado, sem motivo recusado, cancelamento zera 39 saldos, cancela 6 parcelas/6 boletos/1 título, reserva dos produtos -130, 1 aviso gravado.
- Decisões de implementação: `pedido_compra_item_origem` fica (informativo); entrada não sugere o projeto porque o saldo de entrega futura é zerado; destino por projeto só é liberado se o projeto não tem outra venda ativa; bloqueio também para peça separada/entregue.
- Telas: `CancelarVendaDialog` (Orçamentos: listagem + edição) e aviso no `PedidoItensResumo` (Compras). Pendente: A6 aviso Teams (não feito; aviso fica dentro do Compras), commit, deploy.

### 2026-11-17 (publicação)
- Migration 381 APLICADA em SP (funções e RLS conferidos; `anon` sem execute). Orçamentos 90a8452 e Compras 32033bb pushados e publicados por wrangler (Compras levou junto a SPEC-299). Pendente: cancelar o ORC-0048 pela tela nova (Carol/Vinícius conferem o pop-up) e teste da Débora no aviso do pedido 2013.
