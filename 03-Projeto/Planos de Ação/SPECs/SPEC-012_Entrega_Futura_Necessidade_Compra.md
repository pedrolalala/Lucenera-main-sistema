---
titulo: "SPEC-012 — Entrega Futura e Necessidade de Compra"
status: não iniciado
data_ultima_modificacao: 2026-07-06
sistemas_envolvidos:
  - Supabase (banco central)
  - Estoque
  - Compras
---

# SPEC-012 — Entrega Futura e Necessidade de Compra

> **Dependência:** requer SPEC-010 (tabela `estoque_reservas`) para rastreabilidade completa.  
> Pode ser parcialmente implementada antes da SPEC-010 usando `estoque_itens.quantidade_reservada`.

## Checklist de Ação

- [ ] Criar view `vw_entrega_futura` — produtos com disponível negativo, por cliente
- [ ] Criar view `vw_necessidade_compra` — déficit agregado por produto (sem vínculo de cliente)
- [ ] Atualizar `vw_estoque_liquido` existente para incluir coluna `qtd_entrega_futura`
- [ ] Verificar e ajustar `vw_estoque_resumo` (criada em SPEC-010) para consistência
- [ ] Executar migration no Supabase SQL Editor

### Passos manuais do usuário

- [ ] Executar migration no Supabase SQL Editor
- [ ] Validar cálculos contra os dados reais da Débora
- [ ] Confirmar com Filippo se a "necessidade de compra" exibe o cliente ou não

## Objetivo

Reunião 06/07/2026: dois conceitos precisam de visualização clara no sistema:

1. **Entrega Futura** — quando o disponível fica negativo (vendemos mais do que temos), isso representa uma entrega prometida que ainda não tem material físico. Deve ser visível por produto E por cliente (qual orçamento gerou o déficit).

2. **Necessidade de Compra** — o déficit agregado por produto que indica o quanto precisa ser comprado. Importante: a compra **não fica amarrada a um cliente específico** — quando o material chegar, a Débora decide quem recebe. Isso corrige um problema do sistema anterior onde a compra era vinculada ao cliente e causava confusão quando o cenário mudava.

## Decisões aprovadas

- Entrega Futura = `MAX(0, quantidade_reservada − quantidade_fisica)` por produto
- Disponível pode ser negativo — isso é permitido e esperado no negócio
- Necessidade de compra mostra apenas "produto X necessita Y unidades" — SEM vinculação ao cliente
- A vinculação cliente ↔ compra existia no sistema antigo e causava problemas (Filippo mencionou explicitamente: "não deixar amarrado com o cliente, porque antes era amarrado e depois a gente não conseguia fazer o vínculo")
- A Débora é quem decide o destino do material quando ele chega (re-reservar manualmente)

## Definição da SPEC

### Conceitos e fórmulas

```
qtd_total       = estoque_itens.quantidade          (físico)
qtd_reservada   = estoque_itens.quantidade_reservada (todos os orçamentos aprovados e não entregues)
qtd_disponivel  = qtd_total − qtd_reservada          (pode ser negativo)
entrega_futura  = MAX(0, qtd_reservada − qtd_total)  (= |qtd_disponivel| quando negativo)
necessidade_compra = entrega_futura                  (quanto precisa comprar no mínimo)
```

Exemplo da reunião [01:46]:
```
Spot X:
  quantidade_fisica    =  0
  quantidade_reservada = 10  (Filipe)
  qtd_disponivel       = -10
  entrega_futura       = 10   ← precisa comprar 10
```

Segundo exemplo [02:13]:
```
Spot X:
  quantidade_fisica    =  0
  quantidade_reservada = 10  (Filipe) + 10 (Vinícius) = 20
  qtd_disponivel       = -20
  necessidade_compra   = 20
```

### View 1: `vw_necessidade_compra`

Agregada por produto, SEM vinculação ao cliente. Usada pela Débora para decidir compras.

```sql
CREATE OR REPLACE VIEW public.vw_necessidade_compra AS
SELECT
    p.id                                                          AS produto_id,
    p.nome                                                        AS produto,
    p.codigo                                                      AS produto_codigo,
    coalesce(ei.quantidade, 0)                                    AS qtd_fisica,
    coalesce(ei.quantidade_reservada, 0)                          AS qtd_reservada,
    coalesce(ei.quantidade, 0) - coalesce(ei.quantidade_reservada, 0)
                                                                  AS qtd_disponivel,
    GREATEST(0, coalesce(ei.quantidade_reservada, 0) - coalesce(ei.quantidade, 0))
                                                                  AS necessidade_compra,
    -- Quantos orçamentos/projetos dependem deste produto
    (SELECT count(DISTINCT er.orcamento_id)
     FROM public.estoque_reservas er
     WHERE er.produto_id = p.id AND er.status = 'ativa')          AS orcamentos_dependentes,
    CASE
        WHEN coalesce(ei.quantidade, 0) - coalesce(ei.quantidade_reservada, 0) < 0
             THEN 'entrega_futura'
        WHEN coalesce(ei.quantidade, 0) - coalesce(ei.quantidade_reservada, 0) = 0
             THEN 'zerado'
        WHEN coalesce(ei.quantidade, 0) - coalesce(ei.quantidade_reservada, 0)
             <= coalesce(p.estoque_minimo, 3)
             THEN 'estoque_baixo'
        ELSE 'ok'
    END                                                           AS situacao
FROM public.produtos p
LEFT JOIN public.estoque_itens ei
       ON ei.produto_id = p.id AND ei.local = 'Estoque'::public.estoque_local
WHERE
    -- Só mostra produtos que têm algo reservado ou físico
    coalesce(ei.quantidade, 0) > 0 OR coalesce(ei.quantidade_reservada, 0) > 0
ORDER BY necessidade_compra DESC, p.nome;
```

### View 2: `vw_entrega_futura`

Detalhada por cliente/orçamento. Mostra QUEM está em entrega futura e quanto.
Usada para visualização gerencial — não para vincular a compra.

```sql
CREATE OR REPLACE VIEW public.vw_entrega_futura AS
-- Retorna os orçamentos aprovados cujos itens
-- excedem o estoque físico disponível
SELECT
    p.id                  AS produto_id,
    p.nome                AS produto,
    p.codigo              AS produto_codigo,
    c.nome                AS cliente,
    pr.codigo             AS projeto_codigo,
    o.numero              AS orcamento_numero,
    er.quantidade         AS qtd_reservada_cliente,
    coalesce(ei.quantidade, 0)           AS qtd_fisica_total,
    coalesce(ei.quantidade_reservada, 0) AS qtd_reservada_total,
    coalesce(ei.quantidade, 0) - coalesce(ei.quantidade_reservada, 0)
                          AS qtd_disponivel_total,
    er.criado_em          AS reservado_desde
FROM public.estoque_reservas er
JOIN public.produtos   p  ON p.id  = er.produto_id
LEFT JOIN public.contatos  c  ON c.id  = er.cliente_id
LEFT JOIN public.projetos  pr ON pr.id = er.projeto_id
LEFT JOIN public.orcamentos o ON o.id  = er.orcamento_id
LEFT JOIN public.estoque_itens ei
       ON ei.produto_id = er.produto_id AND ei.local = 'Estoque'::public.estoque_local
WHERE
    er.status = 'ativa'
    -- Só mostra produtos em déficit
    AND coalesce(ei.quantidade, 0) - coalesce(ei.quantidade_reservada, 0) < 0
ORDER BY p.nome, er.criado_em;
```

### Regras de negócio

| # | Regra |
|---|---|
| RN-01 | Disponível pode ser negativo — isso é válido e esperado; representa compromisso futuro |
| RN-02 | A necessidade de compra é calculada por produto, SEM vínculo ao cliente |
| RN-03 | Quando a compra chegar, é a Débora quem re-reserva manualmente para o cliente correto |
| RN-04 | A "entrega futura" por cliente é informativa — não bloqueia nenhuma operação |
| RN-05 | O sistema NÃO amarra compra ↔ cliente (diferente do sistema antigo de Sérgio) |

### Visualização esperada (tela de estoque)

Conforme descrito na reunião [03:33-03:47], o produto deve exibir em abas:

| Aba | Conteúdo |
|---|---|
| Estoque Disponível | Quantidade física menos reservado |
| Reservado (por cliente) | Lista: "Filipe: 10, Pedro: 5, ..." |
| Entrega Futura | Quantidade negativa — orçamentos sem cobertura |
| Necessidade de Compra | Deficit agregado — quanto comprar |

### Critérios de aceite

- [ ] `vw_necessidade_compra` mostra produto com `situacao = 'entrega_futura'` quando `qtd_reservada > qtd_fisica`
- [ ] `vw_entrega_futura` lista cada cliente/orçamento que está em situação de entrega futura
- [ ] A coluna `necessidade_compra` não tem vínculo com nenhum cliente específico
- [ ] Os cálculos batem com os dados do banco (validar com Débora)
- [ ] Após uma entrega ser registrada (trigger_fechar_projeto), o produto sai da necessidade de compra

## Pendências

- [ ] Depende de SPEC-010 (`estoque_reservas`) para `vw_entrega_futura` funcionar por cliente.
- [ ] Confirmar com Débora o formato de visualização preferido para a tela de compras.
- [ ] Verificar se `produtos.estoque_minimo` existe no schema — se não, adicionar na migration.
