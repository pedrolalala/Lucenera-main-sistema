---
titulo: "SPEC-021 — Registrar Pedido de Compra: botão no frontend e RPC no Supabase"
status: planejado
data_ultima_modificacao: 2026-07-10
sistemas_envolvidos:
  - compras-lucenera-3o23t98ee (Necessidade de Compra)
  - Supabase (banco central)
dependencias:
  - SPEC-020 (tabelas pedidos_compra, pedido_compra_itens, solicitacoes_compra)
  - SPEC-012 (vw_necessidade_compra — tela de origem)
---

# SPEC-021 — Registrar Pedido de Compra

> Esta SPEC cobre o fluxo ponta a ponta de registrar uma compra já feita
> (ou a fazer) diretamente da tela de Necessidade de Compra: botão no
> frontend que abre um modal, coleta os dados do pedido e chama uma RPC
> atômica que cria `solicitacoes_compra` + `pedidos_compra` + `pedido_compra_itens`
> em uma única transação.

## Checklist de Ação

### Backend
- [x] Criar migration `20260710_032_spec021_registrar_pedido_compra/001_rpc_criar_pedido.sql`
- [x] Aplicar no Supabase SQL Editor

### Frontend (`compras-lucenera-3o23t98ee`)
- [x] Criar `src/services/pedido-compra.ts` (tipos + chamada à RPC)
- [x] Criar `src/components/compra/ModalRegistrarCompra.tsx` (modal com formulário)
- [x] Adicionar botão "Registrar Compra" na tabela de `NecessidadeCompra.tsx`
- [x] Exibir feedback de sucesso/erro após o registro
- [x] Testar no navegador: golden path + fornecedor não cadastrado

## Objetivo

Na tela de Necessidade de Compra, o usuário (comprador) vê os produtos com
déficit (`necessidade_compra > 0`). Esta SPEC adiciona um botão por linha
que abre um modal para registrar que o pedido de compra foi ou será feito,
persistindo tudo no Supabase em uma única operação atômica.

## Fluxo do usuário

```
Tela NecessidadeCompra
  → linha de produto com necessidade_compra > 0
  → botão "Registrar Compra" (ícone ShoppingCart)
  → Modal abre pré-preenchido com produto e quantidade sugerida
  → Usuário preenche: fornecedor, quantidade, custo unitário,
    número/referência do pedido, data prevista de entrega (opcional),
    condições de pagamento (opcional), observação (opcional)
  → "Confirmar Pedido"
  → RPC criar_pedido_compra_de_necessidade chamada
  → Toast de sucesso: "Pedido #<numero> registrado"
  → Tabela recarregada (produto pode sair da lista se necessidade zerou)
```

## Definição da SPEC

### RPC nova: `criar_pedido_compra_de_necessidade`

Operação atômica — cria três registros em uma transação:

1. **`solicitacoes_compra`** com `status = 'pedido_gerado'`
2. **`pedidos_compra`** com `status = 'enviado'`
3. **`pedido_compra_itens`** vinculando pedido ↔ solicitação ↔ produto

**Assinatura:**

```sql
public.criar_pedido_compra_de_necessidade(
  p_produto_id             uuid,
  p_fornecedor_id          uuid,
  p_quantidade             numeric,
  p_custo_unitario         numeric,
  p_numero                 text,           -- referência/número do pedido
  p_data_prevista_entrega  date DEFAULT NULL,
  p_condicoes_pagamento    text DEFAULT NULL,
  p_observacao             text DEFAULT NULL
) RETURNS jsonb
-- { pedido_id, solicitacao_id, numero, status }
```

**Retorno de sucesso:**
```json
{
  "pedido_id": "<uuid>",
  "solicitacao_id": "<uuid>",
  "numero": "PC-2026-001",
  "status": "enviado"
}
```

**Validações:**
- `p_quantidade > 0` — obrigatório
- `p_custo_unitario > 0` — obrigatório
- `p_numero` não pode ser vazio
- `p_fornecedor_id` deve existir em `contatos`
- `p_produto_id` deve existir em `produtos`

### Frontend — Modal

**Campos do formulário:**

| Campo | Tipo | Obrigatório | Obs |
|---|---|---|---|
| Produto | texto desabilitado | — | pré-preenchido da linha selecionada |
| Quantidade | número | Sim | padrão = `necessidade_compra` da linha |
| Fornecedor | select/busca em `contatos` | Sim | filtra por nome |
| Custo unitário | número (R$) | Sim | — |
| Nº do pedido / referência | texto | Sim | ex: "PC-2026-001" |
| Data prevista de entrega | data | Não | — |
| Condições de pagamento | texto | Não | ex: "30/60/90 dias" |
| Observação | textarea | Não | — |

**Comportamento:**
- Botão "Registrar Compra" fica desabilitado até fornecedor + quantidade + custo + número preenchidos
- Ao confirmar: spinner no botão, chama RPC, mostra toast de sucesso ou mensagem de erro
- Após sucesso: fecha o modal e recarrega `vw_necessidade_compra`

### Serviço TypeScript

```typescript
// src/services/pedido-compra.ts

export interface CriarPedidoInput {
  produto_id: string
  fornecedor_id: string
  quantidade: number
  custo_unitario: number
  numero: string
  data_prevista_entrega?: string   // 'YYYY-MM-DD'
  condicoes_pagamento?: string
  observacao?: string
}

export interface CriarPedidoResult {
  pedido_id: string
  solicitacao_id: string
  numero: string
  status: string
}

export async function criarPedidoCompra(input: CriarPedidoInput): Promise<CriarPedidoResult> {
  const { data, error } = await supabase.rpc('criar_pedido_compra_de_necessidade', {
    p_produto_id:            input.produto_id,
    p_fornecedor_id:         input.fornecedor_id,
    p_quantidade:            input.quantidade,
    p_custo_unitario:        input.custo_unitario,
    p_numero:                input.numero,
    p_data_prevista_entrega: input.data_prevista_entrega ?? null,
    p_condicoes_pagamento:   input.condicoes_pagamento ?? null,
    p_observacao:            input.observacao ?? null,
  })
  if (error) throw error
  return data as CriarPedidoResult
}

export async function getFornecedores(search?: string) {
  let query = supabase.from('contatos').select('id, nome').eq('ativo', true)
  if (search) query = query.ilike('nome', `%${search}%`)
  const { data, error } = await query.order('nome').limit(50)
  if (error) throw error
  return data ?? []
}
```

### Integração com `NecessidadeCompra.tsx`

- Adicionar coluna de ação na tabela (última coluna): botão `<Button size="sm" variant="outline">` com ícone `ShoppingCart`
- `onClick`: setar `produtoSelecionado` no estado local e abrir o modal
- Após fechar o modal com sucesso: chamar `refetch()` da lista

## Análise de ecossistema

- Não altera `vw_necessidade_compra` nem `vw_entrega_futura_projeto_item`
- Não afeta saldos de estoque (`estoque_saldos_projeto_item`, `estoque_itens`) — isso só muda ao receber o material (`registrar_recebimento_compra`, SPEC-020)
- A tela de Necessidade de Compra continua mostrando o produto até o material chegar e ser re-reservado por Débora — registrar o pedido não remove o déficit imediatamente (comportamento correto: o déficit é real até o estoque aumentar)
- Único sistema afetado: `compras-lucenera-3o23t98ee`

## Critérios de aceite

- [x] Botão "Registrar Compra" aparece em cada linha da tabela de necessidade
- [x] Modal abre pré-preenchido com produto e quantidade da linha
- [x] Formulário valida campos obrigatórios antes de habilitar o botão de confirmar
- [x] Chamar a RPC com dados válidos cria pedido + solicitação + item no Supabase
- [x] Toast de sucesso exibe o número do pedido registrado
- [x] Chamar a RPC com `p_quantidade = 0` retorna erro tratado no frontend
- [x] A tabela recarrega após o registro

## Pendências pós-implementação

- [x] Tela de listagem de pedidos de compra (consultar `pedidos_compra` + `pedido_compra_itens`)
- [x] SPEC-EST-10: aprovação do pedido + previsão financeira (fora de escopo desta SPEC)
- [x] Busca de fornecedores preferidos via `produto_fornecedores` (pré-selecionar o fornecedor padrão do produto)
