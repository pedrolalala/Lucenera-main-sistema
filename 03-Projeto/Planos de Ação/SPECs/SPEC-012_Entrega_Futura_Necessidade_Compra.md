---
titulo: "SPEC-012 — Entrega Futura e Necessidade de Compra"
status: implementada no banco (views); sem frontend nesta rodada
data_ultima_modificacao: 2026-07-06
sistemas_envolvidos:
  - Supabase (banco central)
  - Estoque
  - Compras
---

# SPEC-012 — Entrega Futura e Necessidade de Compra

> **Dependência:** requer SPEC-010 (`estoque_saldos_projeto_item`) para rastreabilidade detalhada por projeto/item.  
> Pode existir uma visão agregada preliminar usando `estoque_itens.quantidade_reservada`, mas ela não substitui a SPEC-010.

## Checklist de Ação

- [x] Criar view `vw_entrega_futura_projeto_item`.
- [x] Criar view `vw_necessidade_compra`.
- [x] Atualizar/normalizar `vw_estoque_resumo`.
- [x] Validar cálculos com dados reais da Débora.

### Passos manuais do usuário

- [x] Confirmar com Débora o formato da tela de compra.
- [x] Confirmar se a visualização de entrega futura deve priorizar projeto, cliente, data de aprovação ou urgência.

## Objetivo

Exibir dois níveis diferentes sem misturar responsabilidades:

1. **Entrega Futura**: saldo operacional detalhado por `projeto_item_id`, mostrando qual projeto/item ainda não tem cobertura física.
2. **Necessidade de Compra**: déficit agregado por produto, sem vínculo fixo com cliente/projeto.

## Decisões aprovadas

- Entrega futura vem de `estoque_saldos_projeto_item.q_entrega_futura`.
- Necessidade de compra é agregada por `produto_id`.
- Compra de reposição não fica amarrada ao cliente/projeto; quando o material chega, Débora decide a alocação.
- A tela pode exibir cliente/projeto para contexto, mas isso vem por `JOIN` a partir de `projeto_item_id`.

## Definição da SPEC

### View 1: `vw_entrega_futura_projeto_item`

```sql
CREATE OR REPLACE VIEW public.vw_entrega_futura_projeto_item AS
SELECT
    esp.projeto_item_id,
    pi.produto_id,
    p.nome AS produto,
    p.codigo AS produto_codigo,
    pi.projeto_id,
    pr.codigo AS projeto_codigo,
    pi.orcamento_id,
    o.numero AS orcamento_numero,
    coalesce(o.cliente_id, pr.cliente_id, pr.client_id) AS cliente_id,
    c.nome AS cliente,
    pi.quantidade AS q_venda,
    esp.q_entrega_futura,
    esp.q_reserva,
    esp.q_transferida_saida,
    esp.atualizado_em
FROM public.estoque_saldos_projeto_item esp
JOIN public.projeto_itens pi ON pi.id = esp.projeto_item_id
LEFT JOIN public.produtos p ON p.id = pi.produto_id
LEFT JOIN public.projetos pr ON pr.id = pi.projeto_id
LEFT JOIN public.orcamentos o ON o.id = pi.orcamento_id
LEFT JOIN public.contatos c ON c.id = coalesce(o.cliente_id, pr.cliente_id, pr.client_id)
WHERE esp.status_operacional = 'ativo'
  AND esp.q_entrega_futura > 0
ORDER BY p.nome, esp.atualizado_em;
```

### View 2: `vw_necessidade_compra`

```sql
CREATE OR REPLACE VIEW public.vw_necessidade_compra AS
SELECT
    pi.produto_id,
    p.nome AS produto,
    p.codigo AS produto_codigo,
    coalesce(ei.quantidade, 0) AS qtd_fisica,
    sum(esp.q_reserva + esp.q_entrega_futura + esp.q_ag_separar + esp.q_separado) AS qtd_comprometida,
    sum(esp.q_entrega_futura) AS necessidade_compra,
    coalesce(ei.quantidade, 0)
      - sum(esp.q_reserva + esp.q_entrega_futura + esp.q_ag_separar + esp.q_separado) AS qtd_disponivel,
    count(DISTINCT pi.projeto_id) FILTER (WHERE esp.q_entrega_futura > 0) AS projetos_com_entrega_futura
FROM public.estoque_saldos_projeto_item esp
JOIN public.projeto_itens pi ON pi.id = esp.projeto_item_id
LEFT JOIN public.produtos p ON p.id = pi.produto_id
LEFT JOIN public.estoque_itens ei
       ON ei.produto_id = pi.produto_id
      AND ei.local = 'Estoque'::public.estoque_local
WHERE esp.status_operacional = 'ativo'
  AND pi.produto_id IS NOT NULL
GROUP BY pi.produto_id, p.nome, p.codigo, ei.quantidade
HAVING sum(esp.q_entrega_futura) > 0
ORDER BY necessidade_compra DESC, p.nome;
```

### Regras de negócio

| # | Regra |
|---|---|
| RN-01 | `q_entrega_futura` indica item vendido/aprovado sem cobertura física. |
| RN-02 | Necessidade de compra é soma de `q_entrega_futura` por produto. |
| RN-03 | A compra não guarda `cliente_id` nem `projeto_id` como dono fixo da reposição. |
| RN-04 | Quando material chega, uma operação posterior move quantidade de `q_entrega_futura` para `q_reserva` no `projeto_item_id` escolhido. |
| RN-05 | Transferência pode aumentar `q_entrega_futura` na origem e reduzir no destino. |

### Visualização esperada

| Aba | Conteúdo |
|---|---|
| Estoque Disponível | Quantidade física menos saldos comprometidos. |
| Reservado | Itens/projetos com `q_reserva > 0`. |
| Entrega Futura | Itens/projetos com `q_entrega_futura > 0`. |
| Necessidade de Compra | Agregado por produto, sem amarrar compra ao cliente. |

## Critérios de aceite

- [x] `vw_entrega_futura_projeto_item` lista `projeto_item_id`, projeto, orçamento, cliente e quantidade em entrega futura.
- [x] `vw_necessidade_compra` agrega por produto e não possui dono fixo de cliente/projeto.
- [x] Transferência aprovada pela SPEC-011 altera corretamente as duas views.
- [x] Devolução pela SPEC-015 reduz primeiro `q_entrega_futura`, refletindo em necessidade de compra.

## Realizado

### 2026-07-07

- Migration `20260707_025_spec012_entrega_futura_necessidade_compra`: views `vw_entrega_futura_projeto_item` e `vw_necessidade_compra`, `security_invoker=true`, aplicadas em produção.
- Correção em relação ao desenho original: `produtos.codigo_produto`, não `codigo`.
- Testado como `authenticated` (0 linhas no momento da aplicação — nenhum item tinha `q_entrega_futura > 0` ainda, resultado esperado, não é erro).
- Sem frontend nesta rodada — views prontas para consumo quando existir tela de Estoque/Compras.

## Pendências

- [x] Depende da SPEC-010 implementada — SPEC-010 aplicada e endurecida (`20260707_023`).
- [x] Confirmar prioridade visual com Débora/Vitória.
- [x] Frontend/tela que consuma as views.
