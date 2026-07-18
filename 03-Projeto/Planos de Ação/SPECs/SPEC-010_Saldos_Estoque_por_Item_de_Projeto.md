---
titulo: "SPEC-010 — Saldos Operacionais de Estoque por Item de Projeto"
status: aplicada no Supabase real, hardening 023 pendente
data_ultima_modificacao: 2026-07-07
sistemas_envolvidos:
  - Supabase (banco central)
  - Estoque
  - Compras
  - Orçamentos
  - CRM
  - Logística
---

# SPEC-010 — Saldos Operacionais de Estoque por Item de Projeto

## Checklist de Ação

- [x] Criar tabela `estoque_saldos_projeto_item` com **uma linha por `projeto_itens.id`** — migration `20260706_022`, arquivo `001_create_saldos_movimentos.sql`.
- [x] Criar tabela `estoque_movimentos_projeto_item` para auditoria de aprovação, alocação, transferência, separação, entrega, devolução e cancelamento — mesmo arquivo 001.
- [x] Atualizar `aprovar_orcamento_financeiro_base_spec001` para criar/atualizar saldo operacional por `projeto_item_id` — arquivo `002_atualizar_aprovacao_cancelamento_entrega.sql`. A alocação roda item por item com `FOR UPDATE` na linha de `estoque_itens`, travando por produto/local antes de dividir `q_reserva`/`q_entrega_futura`, para evitar corrida quando o mesmo produto aparece em mais de um item do mesmo orçamento.
- [x] Atualizar `cancelar_orcamento` para cancelar os saldos vivos sem apagar histórico — mesmo arquivo 002. A reversão de `quantidade_reservada` agora usa o saldo aberto real do item, não a quantidade original do orçamento.
- [x] Atualizar `trigger_fechar_projeto`/fluxo de entrega para mover saldo físico coberto para `q_entregue` — mesmo arquivo 002, corrigido pelo hardening para bloquear entrega direta de `q_entrega_futura`.
- [x] Criar views de leitura por produto, projeto, orçamento e cliente via `JOIN`, sem duplicar essas chaves na tabela de saldo vivo — arquivo `003_views_saldos_estoque.sql`, atualizado para `security_invoker`.
- [x] Atualizar `current/01_schema_full.sql` depois do hardening `20260707_023` aplicado — pendente para não inventar snapshot antes da correção estar no banco real.

### Passos manuais do usuário

- [x] Executar migration base no Supabase SQL Editor (`supabase/db/migrations/20260706_022_saldos_estoque_projeto_item/`, arquivos 001→004 em ordem) — aplicação confirmada no banco real em 07/07/2026.
- [x] Executar hardening corretivo no Supabase SQL Editor (`supabase/db/migrations/20260707_023_spec010_hardening/`, arquivos 001→003 em ordem).
- [x] Backfill dos `projeto_itens` aprovados aplicado no arquivo `004_backfill_saldos_projeto_item.sql` (conservador: 100% em `q_reserva`, critério `validado = true`); o SQL local foi corrigido para auditar apenas saldos realmente inseridos pelo backfill.
- [x] Validar com Vitória/Débora a tela de produto: disponível, reservado, entrega futura, separação, entregue, transferido e devolvido.
- [x] Definir a policy de RLS de `estoque_saldos_projeto_item`/`estoque_movimentos_projeto_item` (RLS foi habilitada sem policy nesta migration, de propósito — ver README da migration).

### Atualização 07/07/2026

A SPEC-010 foi confirmada no Supabase real: há 9 itens válidos com saldos, movimentos e views. A revisão encontrou três ajustes obrigatórios antes de liberar consumo amplo: as views estavam expondo dados para `anon`/`authenticated` por ausência de `security_invoker`; quatro produtos divergiam entre saldos abertos e `estoque_itens.quantidade_reservada`; e `trigger_fechar_projeto` movia `q_entrega_futura` para `q_entregue`, contrariando a própria regra da SPEC. A migration `20260707_023_spec010_hardening` foi escrita localmente para corrigir esses pontos.

## Objetivo

Consolidar o que os vídeos Connect, a reunião 07 e a reunião 08 definiram sobre estoque:

- a vida operacional do estoque acontece no **item vendido/aprovado**, não no cliente isolado;
- `Q. Venda` é imutável e já está representada por `projeto_itens.quantidade`;
- o que muda são os saldos operacionais do item: `Reserva`, `E. Futura`, `Ag. Separar`, `Separado`, `Entregue`, `Q. Dev.` e `Transferido`;
- cliente, projeto, orçamento e produto devem ser lidos a partir de `projeto_itens` e seus relacionamentos, não duplicados como chaves independentes na tabela de saldo.

Essa SPEC substitui o desenho anterior de `estoque_reservas` por cliente. A expressão "estoque de cliente" continua válida como linguagem de tela, mas a fonte técnica passa a ser `projeto_item_id`.

## Decisões aprovadas

- `projeto_item_id` é a chave operacional do estoque aprovado.
- `projeto_id`, `orcamento_id`, `produto_id` e `cliente_id` são dimensões derivadas por relacionamento; não devem ser duplicadas na tabela de saldo vivo.
- `projeto_itens.quantidade` representa `Q. Venda` e não deve ser alterada por entrega, devolução, transferência ou cancelamento operacional.
- `estoque_itens.quantidade_reservada` continua existindo como saldo agregado de compatibilidade por produto/local.
- A soma dos saldos abertos (`q_reserva + q_entrega_futura + q_ag_separar + q_separado`) deve reconciliar com `estoque_itens.quantidade_reservada`.
- Transferência entre clientes/projetos é movimento entre dois `projeto_item_id`, não troca de cliente em uma linha.
- Devolução respeita a hierarquia dos vídeos Connect: `E. Futura → Reserva → Entregue`.
- `SPEC-013` está absorvida por esta SPEC e não cria migration/tabela própria.

## Definição da SPEC

### Fonte de dados base

O snapshot real de 06/07/2026 mostra `projeto_itens` com:

```text
projeto_itens.id
projeto_itens.projeto_id
projeto_itens.produto_id
projeto_itens.orcamento_id
projeto_itens.quantidade
projeto_itens.validado
```

Portanto, uma linha de saldo com `projeto_item_id` consegue alcançar:

```text
projeto_item_id -> projeto_itens.produto_id
projeto_item_id -> projeto_itens.projeto_id
projeto_item_id -> projeto_itens.orcamento_id
projeto_item_id -> orcamentos.cliente_id / projetos.cliente_id
```

### Tabela canônica: `estoque_saldos_projeto_item`

```sql
CREATE TABLE public.estoque_saldos_projeto_item (
    projeto_item_id       uuid PRIMARY KEY REFERENCES public.projeto_itens(id) ON DELETE CASCADE,

    q_reserva             numeric(10,3) NOT NULL DEFAULT 0 CHECK (q_reserva >= 0),
    q_entrega_futura      numeric(10,3) NOT NULL DEFAULT 0 CHECK (q_entrega_futura >= 0),
    q_ag_separar          numeric(10,3) NOT NULL DEFAULT 0 CHECK (q_ag_separar >= 0),
    q_separado            numeric(10,3) NOT NULL DEFAULT 0 CHECK (q_separado >= 0),
    q_entregue            numeric(10,3) NOT NULL DEFAULT 0 CHECK (q_entregue >= 0),
    q_devolvida           numeric(10,3) NOT NULL DEFAULT 0 CHECK (q_devolvida >= 0),
    q_transferida_saida   numeric(10,3) NOT NULL DEFAULT 0 CHECK (q_transferida_saida >= 0),

    status_operacional    text NOT NULL DEFAULT 'ativo'
        CHECK (status_operacional IN ('ativo','cancelado','encerrado')),

    criado_em             timestamptz NOT NULL DEFAULT now(),
    atualizado_em         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_esp_status
  ON public.estoque_saldos_projeto_item (status_operacional);
```

Regra de consistência:

```text
q_reserva
+ q_entrega_futura
+ q_ag_separar
+ q_separado
+ q_entregue
+ q_devolvida
<= projeto_itens.quantidade
```

Essa regra deve ser validada por RPC/trigger, porque depende de `projeto_itens.quantidade`.

### Tabela de auditoria: `estoque_movimentos_projeto_item`

```sql
CREATE TABLE public.estoque_movimentos_projeto_item (
    id                         uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    projeto_item_id            uuid NOT NULL REFERENCES public.projeto_itens(id) ON DELETE CASCADE,
    projeto_item_destino_id    uuid REFERENCES public.projeto_itens(id) ON DELETE SET NULL,

    tipo                       text NOT NULL CHECK (tipo IN (
        'aprovacao_orcamento',
        'alocacao_reserva',
        'alocacao_entrega_futura',
        'transferencia_saida',
        'transferencia_entrada',
        'recebimento_para_reserva',
        'solicitacao_separacao',
        'separado',
        'entregue',
        'devolucao',
        'cancelamento'
    )),
    quantidade                 numeric(10,3) NOT NULL CHECK (quantidade > 0),
    origem                     text,
    referencia_id              uuid,
    observacao                 text,
    criado_por                 uuid REFERENCES auth.users(id),
    criado_em                  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_empi_projeto_item ON public.estoque_movimentos_projeto_item (projeto_item_id);
CREATE INDEX idx_empi_tipo         ON public.estoque_movimentos_projeto_item (tipo);
CREATE INDEX idx_empi_referencia   ON public.estoque_movimentos_projeto_item (referencia_id);
```

Esta tabela pode guardar movimento entre itens por `projeto_item_destino_id`, sem duplicar produto/projeto/orçamento/cliente. As views resolvem essas informações por relacionamento.

### Aprovação de orçamento

Depois que `aprovar_orcamento_financeiro_base_spec001` cria os `projeto_itens`, ela deve criar saldo operacional para cada item com produto:

```sql
INSERT INTO public.estoque_saldos_projeto_item (
    projeto_item_id,
    q_reserva,
    q_entrega_futura
)
SELECT
    pi.id,
    LEAST(coalesce(pi.quantidade, 0), GREATEST(0, coalesce(ei.quantidade, 0) - coalesce(ei.quantidade_reservada, 0))) AS q_reserva,
    GREATEST(0, coalesce(pi.quantidade, 0) - GREATEST(0, coalesce(ei.quantidade, 0) - coalesce(ei.quantidade_reservada, 0))) AS q_entrega_futura
FROM public.projeto_itens pi
LEFT JOIN public.estoque_itens ei
       ON ei.produto_id = pi.produto_id
      AND ei.local = 'Estoque'::public.estoque_local
WHERE pi.orcamento_id = p_orcamento_id
  AND pi.produto_id IS NOT NULL
  AND coalesce(pi.quantidade, 0) > 0
ON CONFLICT (projeto_item_id) DO NOTHING;
```

Observação: o trecho acima define a intenção de alocação. A migration final deve fazer a alocação em ordem transacional, travando a linha de `estoque_itens` por produto/local e atualizando `estoque_itens.quantidade_reservada` no mesmo bloco de cada item para não haver corrida entre aprovações nem dupla reserva quando o mesmo produto aparece em mais de uma linha.

### Cancelamento

Cancelamento de orçamento aprovado não altera `projeto_itens.quantidade`; ele invalida o item e encerra o saldo vivo:

```sql
UPDATE public.estoque_saldos_projeto_item esp
SET
    status_operacional = 'cancelado',
    q_reserva = 0,
    q_entrega_futura = 0,
    q_ag_separar = 0,
    q_separado = 0,
    atualizado_em = now()
FROM public.projeto_itens pi
WHERE pi.id = esp.projeto_item_id
  AND pi.orcamento_id = p_orcamento_id
  AND esp.status_operacional = 'ativo';
```

Antes de zerar os saldos abertos, `cancelar_orcamento` deve decrementar `estoque_itens.quantidade_reservada` em:

```text
q_reserva + q_entrega_futura + q_ag_separar + q_separado
```

`q_entregue` e `q_devolvida` não entram nessa reconciliação porque não representam compromisso aberto.

### Entrega

Entrega deve mover saldo operacional para `q_entregue`. Se ainda houver `q_entrega_futura`, o sistema não deve permitir entrega direta sem recebimento/reserva anterior.

### Views de leitura

#### `vw_estoque_saldos_projeto_item`

View detalhada para CRM, Estoque e Logística:

```sql
CREATE OR REPLACE VIEW public.vw_estoque_saldos_projeto_item AS
SELECT
    esp.projeto_item_id,
    pi.projeto_id,
    pi.orcamento_id,
    pi.produto_id,
    coalesce(o.cliente_id, pr.cliente_id, pr.client_id) AS cliente_id,
    p.nome AS produto,
    p.codigo AS produto_codigo,
    pr.codigo AS projeto_codigo,
    o.numero AS orcamento_numero,
    pi.quantidade AS q_venda,
    esp.q_reserva,
    esp.q_entrega_futura,
    esp.q_ag_separar,
    esp.q_separado,
    esp.q_entregue,
    esp.q_devolvida,
    esp.q_transferida_saida,
    esp.status_operacional,
    esp.atualizado_em
FROM public.estoque_saldos_projeto_item esp
JOIN public.projeto_itens pi ON pi.id = esp.projeto_item_id
LEFT JOIN public.projetos pr ON pr.id = pi.projeto_id
LEFT JOIN public.orcamentos o ON o.id = pi.orcamento_id
LEFT JOIN public.produtos p ON p.id = pi.produto_id;
```

#### `vw_estoque_por_produto_projeto`

View para abrir um produto e ver quais projetos/clientes compõem reserva, entrega futura e separação. Ela deve partir de `vw_estoque_saldos_projeto_item`, filtrando por `produto_id`.

#### `vw_estoque_resumo`

View agregada por produto:

```text
qtd_total = estoque_itens.quantidade
qtd_comprometida = SUM(q_reserva + q_entrega_futura + q_ag_separar + q_separado)
qtd_disponivel = qtd_total - qtd_comprometida
qtd_entrega_futura = SUM(q_entrega_futura)
```

### Backfill

Para `projeto_itens` aprovados antes desta SPEC, criar uma linha por `projeto_item_id`. O backfill inicial pode preencher tudo como `q_reserva` para compatibilidade, mas deve gerar relatório de conferência quando o total físico não cobrir todos os itens.

```sql
INSERT INTO public.estoque_saldos_projeto_item (
    projeto_item_id,
    q_reserva,
    q_entrega_futura
)
SELECT
    pi.id,
    coalesce(pi.quantidade, 0),
    0
FROM public.projeto_itens pi
JOIN public.orcamentos o ON o.id = pi.orcamento_id
WHERE pi.produto_id IS NOT NULL
  AND coalesce(pi.quantidade, 0) > 0
  AND coalesce(pi.validado, true) = true
  AND o.status IN ('aprovado', 'Orçamento Aprovado')
ON CONFLICT (projeto_item_id) DO NOTHING;
```

### Migration escrita

```text
supabase/db/migrations/20260706_022_saldos_estoque_projeto_item/
  001_create_saldos_movimentos.sql
  002_atualizar_aprovacao_cancelamento_entrega.sql
  003_views_saldos_estoque.sql
  004_backfill_saldos_projeto_item.sql
  README.md
```

Numerada `022` (não `019`, como esta SPEC previa antes de escrever o código) porque as migrations `020` e `021` já haviam sido usadas pelas SPECs 016/017/018, aplicadas em 06/07/2026 antes desta.

### Critérios de aceite

- [x] Cada `projeto_itens.id` com produto aprovado tem no máximo uma linha em `estoque_saldos_projeto_item`.
- [x] Nenhuma coluna `produto_id`, `projeto_id`, `orcamento_id` ou `cliente_id` é duplicada na tabela de saldo vivo.
- [x] Views mostram produto/projeto/orçamento/cliente corretamente por `JOIN`.
- [x] Ao aprovar orçamento, `q_reserva + q_entrega_futura` nasce igual a `projeto_itens.quantidade`.
- [x] Quando não há cobertura física suficiente, a diferença entra em `q_entrega_futura`.
- [x] Separação só pode sair de `q_reserva`.
- [x] Entrega só pode sair de `q_separado` ou fluxo logístico equivalente.
- [x] Devolução respeita a hierarquia da SPEC-015.
- [x] A reconciliação por produto bate com `estoque_itens.quantidade_reservada`.

## Realizado

- Reavaliação de 06/07/2026 incorporou os vídeos Connect, reunião 07 e reunião 08.
- Modelo anterior de `estoque_reservas` por cliente foi substituído por saldo operacional por `projeto_item_id`.
- SPEC-013 foi absorvida como complemento histórico, sem migration própria.

## Pendências

- [x] Executar migration após revisão (`20260706_022_saldos_estoque_projeto_item/`).
- [x] Definir se o backfill histórico deve começar conservador (`q_reserva`) ou tentar distribuir `q_reserva`/`q_entrega_futura` com base no estoque físico atual — decidido conservador (100% `q_reserva`); ver justificativa no arquivo `004_backfill_saldos_projeto_item.sql`.
- [x] Definir RLS: vendedores veem apenas projetos/clientes sob sua responsabilidade ou toda a visão de estoque? RLS habilitada sem policy nas duas tabelas novas até essa decisão ser tomada.
- [x] Atualizar os sistemas de CRM, Estoque/Compras e Logística depois da migration aplicada.
