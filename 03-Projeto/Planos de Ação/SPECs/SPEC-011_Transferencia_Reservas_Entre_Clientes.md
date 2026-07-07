---
titulo: "SPEC-011 — Transferência de Reservas de Estoque Entre Clientes"
status: não iniciado
data_ultima_modificacao: 2026-07-06
sistemas_envolvidos:
  - Supabase (banco central)
  - Estoque
---

# SPEC-011 — Transferência de Reservas de Estoque Entre Clientes

> **Dependência:** requer SPEC-010 (tabela `estoque_reservas`) implementada antes desta.

## Checklist de Ação

- [ ] Criar tabela `transferencias_estoque`
- [ ] Criar RPC `solicitar_transferencia_estoque`
- [ ] Criar RPC `aprovar_transferencia_estoque` (executada pela Vitória)
- [ ] Criar RPC `cancelar_transferencia_estoque`
- [ ] Criar view `vw_transferencias_estoque` para histórico e pendências
- [ ] Atualizar `current/01_schema_full.sql`
- [ ] Executar migration no Supabase SQL Editor

### Passos manuais do usuário

- [ ] Executar migration no Supabase SQL Editor
- [ ] Confirmar com Vitória o fluxo de aprovação (campo de observação, notificação por e-mail?)
- [ ] Confirmar com Débora como quer receber o aviso de "material chegou — precisa re-reservar"
- [ ] Definir quem tem permissão para aprovar (apenas Vitória, ou qualquer admin?)

## Objetivo

Reunião 06/07/2026: quando material reservado para o Cliente A precisa ser entregue para o Cliente B com urgência, é necessário fazer uma **transferência de reserva**. Atualmente isso é feito via Teams (meninas → Vitória) e controlado em Excel porque o sistema antigo não registra a movimentação.

**O que deve acontecer no sistema:**
1. Meninas solicitam transferência no sistema (informam: produto, de qual cliente tirar, para qual cliente/projeto vai)
2. Vitória aprova e executa no sistema
3. A reserva do Cliente A diminui (pode ficar negativa = entrega futura)
4. A reserva do Cliente B aumenta (sai de entrega futura para reservado)
5. Quando novo material chegar, Débora visualiza a pendência e re-reserva para o Cliente A

## Decisões aprovadas

- Somente é possível transferir se o cliente de origem tiver reserva ativa (`estoque_reservas.status = 'ativa'`)
- A transferência é uma operação de duas etapas: **solicitação** (meninas) → **aprovação** (Vitória)
- A operação precisa ser 100% registrada: produto, quantidade, de quem tirou, para quem foi, quem solicitou, quem aprovou
- Fisicamente os itens são fungíveis (a peça "do Filipe" é igual a do "Pedro") — o vínculo é só lógico
- Retenção de histórico: permanente (pelo menos na tabela), visualização mínima de 3 meses
- A compra de reposição NÃO fica amarrada ao cliente de origem — quando chegar, a Débora decide quem recebe

## Definição da SPEC

### Fluxo da transferência

```
[Meninas]  solicitam no sistema
    produto: Spot X
    de: reserva do Filipe (projeto V-1234)
    para: Vinícius (projeto V-9999)
    quantidade: 10
    motivo: "urgência de entrega"
           ↓
    status = 'solicitada'
           ↓
[Vitória]  visualiza pendências de transferência
           Aprova → status = 'aprovada'
           ↓
    estoque_reservas do Filipe: status → 'transferida' (reduz)
    estoque_reservas do Vinícius: nova linha criada (status = 'ativa')
    estoque_itens.quantidade_reservada: mantido (não muda — já estava reservado)
           ↓
[Débora]  vê alerta: "Filipe perdeu 10 unidades de Spot X — re-reservar quando chegar compra"
```

### Nova tabela: `transferencias_estoque`

```sql
CREATE TABLE public.transferencias_estoque (
    id                    uuid DEFAULT gen_random_uuid() PRIMARY KEY,

    -- O quê
    produto_id            uuid NOT NULL REFERENCES public.produtos(id),
    quantidade            numeric(10,3) NOT NULL CHECK (quantidade > 0),

    -- De onde vem
    reserva_origem_id     uuid NOT NULL REFERENCES public.estoque_reservas(id),
    origem_cliente_id     uuid REFERENCES public.contatos(id),
    origem_projeto_id     uuid REFERENCES public.projetos(id),

    -- Para onde vai
    destino_cliente_id    uuid REFERENCES public.contatos(id),
    destino_projeto_id    uuid REFERENCES public.projetos(id),

    -- Rastreabilidade
    status                text NOT NULL DEFAULT 'solicitada'
                            CHECK (status IN ('solicitada','aprovada','cancelada')),
    motivo                text,
    solicitado_por        uuid REFERENCES auth.users(id),
    aprovado_por          uuid REFERENCES auth.users(id),
    solicitado_em         timestamptz DEFAULT now(),
    aprovado_em           timestamptz,
    cancelado_em          timestamptz,
    motivo_cancelamento   text,

    -- Referência da nova reserva criada (preenchida ao aprovar)
    reserva_destino_id    uuid REFERENCES public.estoque_reservas(id),

    created_at            timestamptz DEFAULT now()
);

CREATE INDEX idx_transf_produto   ON public.transferencias_estoque (produto_id);
CREATE INDEX idx_transf_origem    ON public.transferencias_estoque (origem_cliente_id);
CREATE INDEX idx_transf_destino   ON public.transferencias_estoque (destino_cliente_id);
CREATE INDEX idx_transf_status    ON public.transferencias_estoque (status)
    WHERE status = 'solicitada';
```

### RPC: `solicitar_transferencia_estoque`

```sql
CREATE OR REPLACE FUNCTION public.solicitar_transferencia_estoque(
    p_reserva_origem_id  uuid,     -- ID da estoque_reservas de origem
    p_destino_projeto_id uuid,     -- Projeto de destino
    p_quantidade         numeric,  -- Quantidade a transferir
    p_motivo             text DEFAULT NULL
) RETURNS jsonb
```

**O que faz:**
1. Valida que `estoque_reservas` de origem existe, está `ativa` e tem quantidade suficiente
2. Cria linha em `transferencias_estoque` com status `'solicitada'`
3. Registra quem solicitou (`auth.uid()`)
4. Retorna dados da solicitação criada

**Validações:**
- Reserva de origem deve ser `status = 'ativa'`
- `p_quantidade <= reserva_origem.quantidade`
- `p_destino_projeto_id` deve existir

**Retorno:**
```json
{
  "transferencia_id": "uuid",
  "produto": "Spot X",
  "quantidade": 10,
  "origem_cliente": "Filipe",
  "destino_projeto": "V-9999",
  "status": "solicitada"
}
```

### RPC: `aprovar_transferencia_estoque`

```sql
CREATE OR REPLACE FUNCTION public.aprovar_transferencia_estoque(
    p_transferencia_id uuid
) RETURNS jsonb
```

**O que faz:**
1. Valida que transferência existe e está `'solicitada'`
2. Valida novamente que reserva de origem ainda tem quantidade disponível
3. **Reduz** `quantidade` na `estoque_reservas` de origem (se zerar, marca como `'transferida'`)
4. **Cria nova** linha em `estoque_reservas` para o destino (status `'ativa'`)
5. Preenche `reserva_destino_id` na transferência
6. Atualiza `status = 'aprovada'`, `aprovado_por = auth.uid()`, `aprovado_em = now()`
7. **NÃO altera** `estoque_itens.quantidade_reservada` (o total reservado não muda)

**Retorno:**
```json
{
  "transferencia_id": "uuid",
  "status": "aprovada",
  "reserva_origem_id": "uuid",
  "reserva_destino_id": "uuid",
  "aprovado_em": "..."
}
```

### RPC: `cancelar_transferencia_estoque`

```sql
CREATE OR REPLACE FUNCTION public.cancelar_transferencia_estoque(
    p_transferencia_id uuid,
    p_motivo           text DEFAULT NULL
) RETURNS jsonb
```

**O que faz:**
- Apenas muda `status = 'cancelada'` se ainda estava `'solicitada'`
- Não desfaz transferências já `'aprovadas'` (operação irreversível — requer nova transferência reversa)

### View: `vw_transferencias_estoque`

```sql
CREATE VIEW public.vw_transferencias_estoque AS
SELECT
    t.id,
    t.status,
    pr.nome        AS produto,
    pr.codigo      AS produto_codigo,
    t.quantidade,
    co.nome        AS origem_cliente,
    po.codigo      AS origem_projeto,
    cd.nome        AS destino_cliente,
    pd.codigo      AS destino_projeto,
    t.motivo,
    u_sol.email    AS solicitado_por_email,
    u_apr.email    AS aprovado_por_email,
    t.solicitado_em,
    t.aprovado_em
FROM public.transferencias_estoque t
JOIN public.produtos pr    ON pr.id = t.produto_id
LEFT JOIN public.contatos co  ON co.id = t.origem_cliente_id
LEFT JOIN public.projetos po  ON po.id = t.origem_projeto_id
LEFT JOIN public.contatos cd  ON cd.id = t.destino_cliente_id
LEFT JOIN public.projetos pd  ON pd.id = t.destino_projeto_id
LEFT JOIN auth.users u_sol    ON u_sol.id = t.solicitado_por
LEFT JOIN auth.users u_apr    ON u_apr.id = t.aprovado_por
ORDER BY t.solicitado_em DESC;
```

### Visualizações necessárias no frontend

| Tela | Quem usa | O que mostra |
|---|---|---|
| "Transferências pendentes" | Vitória | Solicitações aguardando aprovação |
| "Histórico de transferências" | Todos | Transferências aprovadas/canceladas |
| "Reservas por produto" | Débora | Lista de clientes com reservas ativas (para detectar onde tem para transferir) |
| "Alerta de reposição" | Débora | Clientes com reserva perdida por transferência — necessidade de recompor |

### Regras de negócio

| # | Regra |
|---|---|
| RN-01 | Só é possível transferir se a reserva de origem está `ativa` com quantidade suficiente |
| RN-02 | Transferência requer aprovação — meninas solicitam, Vitória aprova |
| RN-03 | A transferência é irreversível após aprovada (para reverter: nova transferência no sentido contrário) |
| RN-04 | O cliente de origem fica com déficit (entrega futura) — não bloqueia o sistema, mas aparece no relatório de necessidade de compra |
| RN-05 | A compra de reposição NÃO é amarrada ao cliente de origem — quando chegar, Débora decide |
| RN-06 | Todo o histórico deve ser registrado: produto, quantidade, de/para, solicitante, aprovador, timestamps |
| RN-07 | `estoque_itens.quantidade_reservada` não muda com a transferência (o total reservado é o mesmo, só muda de dono) |

### Critérios de aceite

- [ ] Solicitação de transferência cria linha em `transferencias_estoque` com status `'solicitada'`
- [ ] Tentativa de transferir mais do que a reserva disponível retorna erro claro
- [ ] Aprovação cria nova `estoque_reservas` para o destino e reduz/fecha a de origem
- [ ] `estoque_itens.quantidade_reservada` permanece igual antes e depois da transferência
- [ ] `vw_transferencias_estoque` mostra produto, de quem tirou, para quem foi, quem aprovou
- [ ] Histórico dos últimos 3+ meses acessível para consulta

## Pendências

- [ ] Depende de SPEC-010 (tabela `estoque_reservas`) estar implementada antes.
- [ ] Definir com Pedro/Vitória quem tem permissão de aprovar transferências (role específico?).
- [ ] Definir notificação para Débora quando transferência é aprovada (e-mail? notificação no sistema?).
- [ ] Regra de devolução mencionada por Filippo ao final da reunião — será SPEC-013 após esta estar funcionando.
