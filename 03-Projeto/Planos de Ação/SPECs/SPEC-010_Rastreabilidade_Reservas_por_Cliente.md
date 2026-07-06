---
titulo: "SPEC-010 — Rastreabilidade de Reservas de Estoque por Cliente"
status: não iniciado
data_ultima_modificacao: 2026-07-06
sistemas_envolvidos:
  - Supabase (banco central)
  - Estoque
  - Orçamentos
---

# SPEC-010 — Rastreabilidade de Reservas de Estoque por Cliente

## Checklist de Ação

- [ ] Criar tabela `estoque_reservas` com vínculo produto ↔ cliente ↔ projeto ↔ orçamento
- [ ] Atualizar RPC `aprovar_orcamento_financeiro_base_spec001` para inserir em `estoque_reservas`
- [ ] Atualizar RPC `cancelar_orcamento` para marcar reservas como `cancelada`
- [ ] Atualizar `trigger_fechar_projeto` para marcar reservas como `entregue` na entrega
- [ ] Criar view `vw_estoque_por_cliente` — produto + cliente + quantidade reservada
- [ ] Criar view `vw_estoque_resumo` — estoque total / disponível / reservado por produto
- [ ] Atualizar `current/01_schema_full.sql` com a nova tabela
- [ ] Executar migration no Supabase SQL Editor

### Passos manuais do usuário

- [ ] Executar migration no Supabase SQL Editor após revisão
- [ ] Validar que reservas antigas (aprovadas antes desta SPEC) aparecem corretamente — executar backfill
- [ ] Confirmar com Filippo/Vitória o visual da tela de estoque por cliente

## Objetivo

Reunião 06/07/2026 (Filippo, Vinicius, Pedro): o estoque reservado **precisa estar vinculado ao cliente específico**. Hoje `estoque_itens.quantidade_reservada` é um contador total sem rastreabilidade. É impossível saber que "10 unidades estão reservadas para o Filipe e 5 para o Pedro".

Essa rastreabilidade é pré-requisito para:
- Visualizar o estoque de cada cliente (SPEC-010, esta spec)
- Transferir reservas entre clientes (SPEC-011)
- Calcular entrega futura com precisão (SPEC-012)

## Decisões aprovadas

- O estoque reservado **é sempre** vinculado a um cliente específico (via projeto/orçamento)
- `estoque_itens.quantidade_reservada` continua existindo como contador total (compatibilidade)
- A nova tabela `estoque_reservas` é a fonte de verdade para rastreabilidade por cliente
- A soma de `estoque_reservas.quantidade` (where status='ativa') deve igualar `estoque_itens.quantidade_reservada`
- Fisicamente, não há separação por cliente no depósito — o vínculo é apenas lógico/contábil
- A peça "do Filipe" é fungível — o que importa é a registração, não a peça física específica

## Definição da SPEC

### Terminologia definida na reunião

| Termo | Significado |
|---|---|
| Estoque Total | Quantidade física real no depósito |
| Estoque de Cliente / Itens Reservados | Quantidade comprometida para clientes (mesmo conceito) |
| Estoque Disponível | Total − Reservado |
| Entrega Futura | Quantidade comprometida além do estoque físico (Disponível negativo) |

Fórmulas:
```
Disponível = Total − Reservado
Entrega Futura = MAX(0, Reservado − Total)   [= |Disponível| quando negativo]
```

### Nova tabela: `estoque_reservas`

```sql
CREATE TABLE public.estoque_reservas (
    id            uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    produto_id    uuid NOT NULL REFERENCES public.produtos(id),
    cliente_id    uuid REFERENCES public.contatos(id),
    projeto_id    uuid REFERENCES public.projetos(id),
    orcamento_id  uuid REFERENCES public.orcamentos(id),
    quantidade    numeric(10,3) NOT NULL CHECK (quantidade > 0),
    status        text NOT NULL DEFAULT 'ativa'
                    CHECK (status IN ('ativa','transferida','entregue','cancelada')),
    origem        text NOT NULL DEFAULT 'aprovacao_orcamento',
    observacao    text,
    criado_em     timestamptz DEFAULT now(),
    atualizado_em timestamptz DEFAULT now()
);

CREATE INDEX idx_estoque_reservas_produto    ON public.estoque_reservas (produto_id);
CREATE INDEX idx_estoque_reservas_cliente    ON public.estoque_reservas (cliente_id);
CREATE INDEX idx_estoque_reservas_orcamento  ON public.estoque_reservas (orcamento_id);
CREATE INDEX idx_estoque_reservas_status     ON public.estoque_reservas (status)
    WHERE status = 'ativa';
```

| Coluna | Descrição |
|---|---|
| `produto_id` | Produto reservado |
| `cliente_id` | Cliente para quem está reservado |
| `projeto_id` | Projeto de origem da reserva |
| `orcamento_id` | Orçamento que gerou a reserva |
| `quantidade` | Quantidade reservada neste registro |
| `status` | `ativa` / `transferida` (SPEC-011) / `entregue` / `cancelada` |
| `origem` | Como foi criada: `aprovacao_orcamento`, `transferencia`, etc. |

### Alterações em RPCs existentes

#### `aprovar_orcamento_financeiro_base_spec001` — passo adicional

Após o passo 8 (reserva em `estoque_itens`), inserir em `estoque_reservas` uma linha por item com produto_id:

```sql
INSERT INTO public.estoque_reservas (produto_id, cliente_id, projeto_id, orcamento_id, quantidade, origem)
SELECT
    oi.produto_id,
    v_orcamento.cliente_id,
    v_orcamento.projeto_id,
    p_orcamento_id,
    coalesce(oi.quantidade, 0),
    'aprovacao_orcamento'
FROM public.orcamento_itens oi
WHERE oi.orcamento_id = p_orcamento_id
  AND oi.produto_id IS NOT NULL
  AND coalesce(oi.quantidade, 0) > 0;
```

#### `cancelar_orcamento` — ao cancelar orçamento aprovado

```sql
UPDATE public.estoque_reservas
SET status = 'cancelada', atualizado_em = now()
WHERE orcamento_id = p_orcamento_id
  AND status = 'ativa';
```

#### `trigger_fechar_projeto` — ao entregar (status → 'Entrega materiais')

```sql
UPDATE public.estoque_reservas er
SET status = 'entregue', atualizado_em = now()
FROM public.projeto_itens pi
WHERE pi.projeto_id = NEW.id
  AND er.produto_id = pi.produto_id
  AND er.projeto_id = NEW.id
  AND er.status = 'ativa';
```

### Views

#### `vw_estoque_por_cliente`

Mostra para cada produto a lista de clientes com reservas ativas e quantidade.

```sql
CREATE VIEW public.vw_estoque_por_cliente AS
SELECT
    p.id          AS produto_id,
    p.nome        AS produto,
    p.codigo      AS produto_codigo,
    c.id          AS cliente_id,
    c.nome        AS cliente,
    pr.codigo     AS projeto_codigo,
    pr.id         AS projeto_id,
    o.numero      AS orcamento_numero,
    er.orcamento_id,
    er.quantidade AS qtd_reservada,
    er.criado_em  AS reservado_em,
    er.status
FROM public.estoque_reservas er
JOIN public.produtos  p  ON p.id  = er.produto_id
LEFT JOIN public.contatos  c  ON c.id  = er.cliente_id
LEFT JOIN public.projetos  pr ON pr.id = er.projeto_id
LEFT JOIN public.orcamentos o ON o.id  = er.orcamento_id
WHERE er.status = 'ativa'
ORDER BY p.nome, c.nome;
```

#### `vw_estoque_resumo` (atualiza a existente)

```sql
-- Por produto: total, reservado, disponível, entrega_futura
CREATE VIEW public.vw_estoque_resumo AS
SELECT
    p.id           AS produto_id,
    p.nome         AS produto,
    p.codigo,
    coalesce(ei.quantidade, 0)            AS qtd_total,
    coalesce(ei.quantidade_reservada, 0)  AS qtd_reservada,
    coalesce(ei.quantidade, 0) - coalesce(ei.quantidade_reservada, 0)  AS qtd_disponivel,
    GREATEST(0, coalesce(ei.quantidade_reservada, 0) - coalesce(ei.quantidade, 0))
                                           AS qtd_entrega_futura,
    CASE
        WHEN coalesce(ei.quantidade, 0) - coalesce(ei.quantidade_reservada, 0) < 0
             THEN 'entrega_futura'
        WHEN coalesce(ei.quantidade, 0) - coalesce(ei.quantidade_reservada, 0) = 0
             THEN 'zerado'
        WHEN coalesce(ei.quantidade, 0) - coalesce(ei.quantidade_reservada, 0)
             <= coalesce(p.estoque_minimo, 3)
             THEN 'baixo'
        ELSE 'ok'
    END AS situacao
FROM public.produtos p
LEFT JOIN public.estoque_itens ei
       ON ei.produto_id = p.id AND ei.local = 'Estoque'
ORDER BY qtd_entrega_futura DESC, p.nome;
```

### Backfill de reservas existentes

Para orçamentos já aprovados antes desta SPEC (sem linha em `estoque_reservas`):

```sql
INSERT INTO public.estoque_reservas (produto_id, cliente_id, projeto_id, orcamento_id, quantidade, origem)
SELECT
    oi.produto_id,
    o.cliente_id,
    o.projeto_id,
    o.id,
    coalesce(oi.quantidade, 0),
    'backfill_spec010'
FROM public.orcamento_itens oi
JOIN public.orcamentos o ON o.id = oi.orcamento_id
JOIN public.projetos p   ON p.id = o.projeto_id
WHERE o.status = 'aprovado'
  AND oi.produto_id IS NOT NULL
  AND coalesce(oi.quantidade, 0) > 0
  -- Excluir projetos já entregues (estoque já baixado)
  AND p.status::text NOT IN ('Obra Finalizada','Finalizado','Entrega materiais','Ajustes finais')
  -- Não duplicar
  AND NOT EXISTS (
    SELECT 1 FROM public.estoque_reservas er
    WHERE er.orcamento_id = o.id AND er.produto_id = oi.produto_id
  );
```

### Migration

```
supabase/db/migrations/20260706_019_rastreabilidade_reservas_cliente/
  001_create_estoque_reservas.sql
  002_atualizar_rpcs_aprovacao_cancelamento.sql
  003_atualizar_trigger_fechar_projeto.sql
  004_views_estoque_por_cliente.sql
  005_backfill_reservas_existentes.sql
  README.md
```

### Critérios de aceite

- [ ] Ao aprovar um orçamento, aparece uma linha em `estoque_reservas` por item com produto_id, linkada ao cliente do orçamento
- [ ] `vw_estoque_por_cliente` mostra "10 reservados para Filipe" e "5 para Pedro" separadamente
- [ ] Cancelar orçamento aprovado muda status das reservas para `cancelada`
- [ ] Marcar projeto como "Entrega materiais" muda status das reservas para `entregue`
- [ ] A soma de `estoque_reservas.quantidade` (status='ativa') por produto bate com `estoque_itens.quantidade_reservada`

## Pendências

- [ ] Executar migration após revisão do usuário.
- [ ] Backfill das reservas de orçamentos aprovados antes desta SPEC.
- [ ] Definir se `estoque_reservas` precisa de RLS (Row Level Security) — vendedores veem só seus clientes?
