---
titulo: "SPEC-020 — Operacionalização de Compras: produto_fornecedores, solicitações, cotações, pedidos, recebimentos e re-reserva"
status: planejado
data_ultima_modificacao: 2026-07-10
sistemas_envolvidos:
  - compras-lucenera-3o23t98ee (Necessidade de Compra)
  - Supabase (banco central)
referencias_escopo:
  - SPEC-EST-02 (produto_fornecedores)
  - SPEC-EST-07 (necessidade de compra operacional)
  - SPEC-EST-08 (cotações)
  - SPEC-EST-09 (pedidos de compra)
  - SPEC-EST-12 (recebimento de material)
---

# SPEC-020 — Operacionalização de Compras

> Esta SPEC cria o backend operacional que transforma a **necessidade de compra**
> (já visualizável via `vw_necessidade_compra` da SPEC-012) em um fluxo
> rastreável: solicitação → cotação → pedido → recebimento → re-reserva por
> Débora. Toda a lógica segue as decisões da reunião 08 (06/07/2026):
> compra sem vínculo fixo ao cliente; rastreabilidade por `projeto_item_id`;
> Débora decide a re-reserva quando o material chega.

## Checklist de Ação

- [x] Aplicar `001_produto_fornecedores.sql`
- [x] Aplicar `002_solicitacoes_compra.sql`
- [x] Aplicar `003_cotacoes_compra.sql`
- [x] Aplicar `004_pedidos_compra.sql`
- [x] Aplicar `005_recebimentos_compra.sql`
- [x] Aplicar `006_rpc_registrar_recebimento.sql`
- [x] Aplicar `007_view_pendencias_re_reserva.sql`
- [x] Aplicar `008_rpc_re_reservar.sql`
- [x] Homologar fluxo ponta a ponta: necessidade → solicitação → pedido → recebimento → re-reserva no Supabase real

### Passos manuais do usuário

- [x] Abrir o SQL Editor do Supabase e executar cada arquivo da pasta `20260710_031_spec020_operacionalizacao_compras/` na ordem numérica
- [x] Confirmar que as views `vw_necessidade_compra` e `vw_pendencias_re_reserva` retornam dados esperados

## Objetivo

Criar as tabelas e RPCs necessárias para o sistema **compras-lucenera-3o23t98ee** operar o fluxo completo de compra por necessidade:

1. **`produto_fornecedores`** — dados operacionais por relação produto-fornecedor (custo, prazo, mínimo), sem duplicar o cadastro mestre de `produtos` e `contatos`.
2. **`solicitacoes_compra`** — converte a necessidade calculada (`vw_necessidade_compra.necessidade_compra > 0`) em um documento de solicitação formal por produto.
3. **`cotacoes_compra` + `cotacao_itens`** — registra propostas de fornecedores para comparação.
4. **`pedidos_compra` + `pedido_compra_itens`** — gera o pedido oficial, ligando cotação vencedora e solicitações.
5. **`recebimentos_compra` + `recebimento_itens`** — registra chegada do material e aumenta o saldo físico (`estoque_itens.quantidade`).
6. **RPC `registrar_recebimento_compra`** — operação atômica: registra o recebimento, atualiza saldo físico e status do pedido.
7. **View `vw_pendencias_re_reserva`** — painel de Débora: itens com `q_entrega_futura > 0` E produto com estoque físico disponível para cobrir.
8. **RPC `re_reservar_projeto_item`** — ação de Débora: move `q_entrega_futura → q_reserva` para um item de projeto específico, debitando do estoque disponível.

## Decisões aprovadas (Reunião 08 — 06/07/2026)

- Compra não fica vinculada a cliente específico — `solicitacoes_compra` referencia apenas `produto_id` + quantidade.
- Rastreabilidade de "quem vai receber" é informativa (via `vw_entrega_futura_projeto_item`) e não uma chave da compra.
- Quando o material chega, **Débora** decide quais projetos recebem o estoque, via `re_reservar_projeto_item`.
- A re-reserva altera `q_entrega_futura → q_reserva` em `estoque_saldos_projeto_item` e incrementa `estoque_itens.quantidade_reservada`.

## Definição da SPEC

### Fluxo operacional completo

```
vw_necessidade_compra (produto com deficit)
    ↓
solicitacoes_compra (solicitação por produto/qtd)
    ↓
cotacoes_compra + cotacao_itens (propostas de fornecedor)
    ↓
pedidos_compra + pedido_compra_itens (pedido aprovado)
    ↓
recebimentos_compra + recebimento_itens (material chega)
    ↓ RPC registrar_recebimento_compra
estoque_itens.quantidade += qtd_recebida
    ↓ vw_pendencias_re_reserva
Débora vê: projeto_item com q_entrega_futura > 0 E qtd_disponivel > 0
    ↓ RPC re_reservar_projeto_item
estoque_saldos_projeto_item: q_entrega_futura → q_reserva
```

### Tabelas novas

#### `produto_fornecedores` (SPEC-EST-02)

Informações operacionais por relação produto-fornecedor. Não duplica `produtos` nem `contatos`.

Colunas principais: `produto_id` (FK `produtos`), `fornecedor_id` (FK `contatos`), `codigo_fornecedor`, `custo_unitario`, `prazo_entrega_dias`, `qtd_minima`, `unidade`, `ativo`.

Restrição: `UNIQUE (produto_id, fornecedor_id)` — um par produto-fornecedor tem uma ficha operacional.

#### `solicitacoes_compra` (SPEC-EST-07)

Uma solicitação por produto. Não tem FK para cliente/projeto — vínculo informativo fica na `vw_entrega_futura_projeto_item`.

Status: `aberta → em_cotacao → pedido_gerado → cancelada`.

#### `cotacoes_compra` + `cotacao_itens` (SPEC-EST-08)

Cotação por fornecedor com N itens. Cada item pode referenciar uma `solicitacao_id` (opcional).

Status da cotação: `em_andamento → recebida → aprovada → rejeitada → cancelada`.

#### `pedidos_compra` + `pedido_compra_itens` (SPEC-EST-09)

Pedido oficial gerado a partir de cotação aprovada ou diretamente. Cada item do pedido referencia a solicitação de origem.

Status: `rascunho → aprovado → enviado → parcialmente_recebido → recebido → cancelado`.

#### `recebimentos_compra` + `recebimento_itens` (SPEC-EST-12)

Conferência do material recebido contra o pedido. Cada item do recebimento aponta para um `pedido_compra_item_id`.

### RPCs novas

#### `registrar_recebimento_compra(p_pedido_id, p_numero_nota, p_data, p_itens jsonb)`

Operação atômica que:
1. Insere em `recebimentos_compra`
2. Para cada item em `p_itens` (array de `{pedido_item_id, quantidade_recebida, divergencia}`):
   - Insere em `recebimento_itens`
   - Atualiza `pedido_compra_itens.qtd_recebida += quantidade_recebida`
   - Aumenta `estoque_itens.quantidade += quantidade_recebida` (WHERE `produto_id = ... AND local = 'Estoque'`)
3. Recalcula status do pedido: `parcialmente_recebido` ou `recebido`
4. Retorna resumo com `recebimento_id` e itens processados

#### `re_reservar_projeto_item(p_projeto_item_id, p_quantidade)`

Move `q_entrega_futura → q_reserva` para um item de projeto específico:
1. Valida que `q_entrega_futura >= p_quantidade`
2. Valida que estoque disponível >= `p_quantidade`
3. Atualiza `estoque_saldos_projeto_item`: `q_entrega_futura -= p_quantidade`, `q_reserva += p_quantidade`
4. Atualiza `estoque_itens.quantidade_reservada += p_quantidade`
5. Registra em `estoque_movimentos_projeto_item` com `tipo = 're_reserva'`

### Views novas

#### `vw_pendencias_re_reserva`

Painel de Débora. Mostra itens com `q_entrega_futura > 0` e produto com estoque disponível.

Colunas: `projeto_item_id`, `produto`, `produto_codigo`, `projeto_codigo`, `orcamento_numero`, `cliente`, `q_entrega_futura`, `qtd_fisica`, `qtd_disponivel`, `qtd_pode_re_reservar` (= `LEAST(q_entrega_futura, qtd_disponivel)`), `atualizado_em`.

Filtro: apenas registros onde `qtd_pode_re_reservar > 0` — só mostra quando há algo a fazer.

### RLS

Todas as tabelas:
- `SELECT` para `authenticated` (política permissiva)
- `INSERT/UPDATE/DELETE` exclusivamente via RPC `SECURITY DEFINER` (sem policy de escrita direta)

### Análise de ecossistema

- Depende de: `produtos`, `contatos`, `projeto_itens`, `estoque_saldos_projeto_item`, `estoque_movimentos_projeto_item`, `estoque_itens`, `projetos`, `orcamentos`
- Não altera contratos existentes: `vw_necessidade_compra` e `vw_entrega_futura_projeto_item` (SPEC-012) permanecem sem mudança
- Sistema afetado: `compras-lucenera-3o23t98ee` (lê as novas tabelas/views); `cadastro-lucenera-b86fe` não é afetado
- `re_reservar_projeto_item` afeta `estoque_saldos_projeto_item` e `estoque_itens` — mesmo escopo das RPCs de SPEC-010/011

## Critérios de aceite

- [x] `SELECT * FROM produto_fornecedores` retorna sem erro
- [x] `SELECT * FROM solicitacoes_compra` retorna sem erro
- [x] `SELECT * FROM vw_pendencias_re_reserva` retorna sem erro (pode ser vazio se não há `q_entrega_futura > 0`)
- [x] Chamar `registrar_recebimento_compra` com pedido existente aumenta `estoque_itens.quantidade`
- [x] Chamar `re_reservar_projeto_item` com item em `q_entrega_futura > 0` e estoque disponível move corretamente para `q_reserva`
- [x] Chamar `re_reservar_projeto_item` sem estoque suficiente levanta exceção clara

## Pendências pós-aplicação

- [x] Criar tela de solicitação de compra no sistema `compras-lucenera-3o23t98ee`
- [x] Criar painel de re-reserva para Débora no sistema `compras-lucenera-3o23t98ee`
- [x] SPEC-EST-10 (aprovação do pedido + previsão financeira) — fora de escopo desta SPEC
- [x] SPEC-EST-11 (prazos e acompanhamento) — fora de escopo desta SPEC
- [x] SPEC-EST-13 (confirmação conta a pagar) — fora de escopo desta SPEC
