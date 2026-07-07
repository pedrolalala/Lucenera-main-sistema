---
titulo: "SPEC-015 — Devolução de Estoque por Item de Projeto"
status: implementada no banco (backend); sem frontend nesta rodada
data_ultima_modificacao: 2026-07-06
sistemas_envolvidos:
  - Supabase (banco central)
  - Estoque
  - Compras
  - Logística
  - CRM
  - Financeiro
---

# SPEC-015 — Devolução de Estoque por Item de Projeto

## Checklist de Ação

- [ ] Criar tabela `devolucoes_estoque`.
- [ ] Criar RPC `registrar_devolucao_projeto_item`.
- [ ] Registrar movimentos em `estoque_movimentos_projeto_item`.
- [ ] Aplicar hierarquia dos vídeos Connect: `E. Futura → Reserva → Entregue`.
- [ ] Atualizar views da SPEC-010/SPEC-012 após devolução.
- [ ] Definir etapa financeira quando a devolução gerar crédito, abatimento ou reembolso.

### Passos manuais do usuário

- [ ] Validar com Filippo/Vitória/Débora quem solicita e quem aprova devolução.
- [ ] Validar com Financeiro quando a devolução gera crédito ou ajuste financeiro.
- [ ] Validar com Logística quando a devolução envolve coleta física de item já entregue.

## Objetivo

Formalizar a regra de devolução já documentada nos vídeos Connect, preservando `Q. Venda` e ajustando apenas os saldos operacionais do item.

Na modelagem nova, a devolução acontece por `projeto_item_id`, não por cliente solto.

## Decisões aprovadas

- `projeto_itens.quantidade` (`Q. Venda`) nunca muda.
- A devolução aumenta `q_devolvida`.
- A devolução reduz saldos seguindo a hierarquia:
  1. `q_entrega_futura`;
  2. `q_reserva`;
  3. `q_entregue`.
- Se a quantidade atravessar mais de uma situação, a RPC deve dividir automaticamente os movimentos.
- Devolução de item já entregue pode exigir logística/coleta física.
- Compra/necessidade de compra deve ser recalculada automaticamente quando `q_entrega_futura` for reduzida.

## Definição da SPEC

### Nova tabela: `devolucoes_estoque`

```sql
CREATE TABLE public.devolucoes_estoque (
    id                    uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    projeto_item_id        uuid NOT NULL REFERENCES public.projeto_itens(id) ON DELETE RESTRICT,
    quantidade             numeric(10,3) NOT NULL CHECK (quantidade > 0),

    qtd_de_entrega_futura  numeric(10,3) NOT NULL DEFAULT 0 CHECK (qtd_de_entrega_futura >= 0),
    qtd_de_reserva         numeric(10,3) NOT NULL DEFAULT 0 CHECK (qtd_de_reserva >= 0),
    qtd_de_entregue        numeric(10,3) NOT NULL DEFAULT 0 CHECK (qtd_de_entregue >= 0),

    status                 text NOT NULL DEFAULT 'registrada'
        CHECK (status IN ('registrada','aguardando_coleta','coletada','cancelada')),
    motivo                 text,
    gera_credito_financeiro boolean,
    solicitado_por         uuid REFERENCES auth.users(id),
    aprovado_por           uuid REFERENCES auth.users(id),
    criado_em              timestamptz NOT NULL DEFAULT now(),
    aprovado_em            timestamptz,
    cancelado_em           timestamptz
);

CREATE INDEX idx_dev_projeto_item ON public.devolucoes_estoque (projeto_item_id);
CREATE INDEX idx_dev_status       ON public.devolucoes_estoque (status);
```

### RPC: `registrar_devolucao_projeto_item`

```sql
CREATE OR REPLACE FUNCTION public.registrar_devolucao_projeto_item(
    p_projeto_item_id uuid,
    p_quantidade      numeric,
    p_motivo          text DEFAULT NULL
) RETURNS jsonb
```

Fluxo:

1. Trava a linha de `estoque_saldos_projeto_item`.
2. Valida que `p_quantidade > 0`.
3. Valida que `p_quantidade <= q_entrega_futura + q_reserva + q_entregue`.
4. Calcula automaticamente:
   - `v_de_entrega_futura = LEAST(p_quantidade, q_entrega_futura)`;
   - `v_restante = p_quantidade - v_de_entrega_futura`;
   - `v_de_reserva = LEAST(v_restante, q_reserva)`;
   - `v_restante = v_restante - v_de_reserva`;
   - `v_de_entregue = LEAST(v_restante, q_entregue)`.
5. Reduz os saldos nessa ordem.
6. Aumenta `q_devolvida`.
7. Decrementa `estoque_itens.quantidade_reservada` apenas pelo que saiu de saldo aberto: `v_de_entrega_futura + v_de_reserva`.
8. Cria linha em `devolucoes_estoque`.
9. Cria movimentos `devolucao` em `estoque_movimentos_projeto_item`, com `referencia_id = devolucoes_estoque.id`.
10. Se `v_de_entregue > 0`, marca a devolução como `aguardando_coleta`; caso contrário, `registrada`.
11. Quando houver coleta de item já entregue, a entrada física em estoque deve ser registrada em fluxo logístico/estoque próprio, não como reserva aberta.

### Exemplo

Item com:

```text
q_entrega_futura = 10
q_reserva = 10
q_entregue = 20
```

Devolução de 20:

```text
q_entrega_futura reduz 10
q_reserva reduz 10
q_entregue reduz 0
q_devolvida aumenta 20
```

Devolução de 40:

```text
q_entrega_futura reduz 10
q_reserva reduz 10
q_entregue reduz 20
q_devolvida aumenta 40
status = aguardando_coleta
```

### Regras de negócio

| # | Regra |
|---|---|
| RN-01 | `Q. Venda` (`projeto_itens.quantidade`) nunca muda. |
| RN-02 | Devolução sempre aumenta `q_devolvida`. |
| RN-03 | A redução segue `q_entrega_futura → q_reserva → q_entregue`. |
| RN-04 | Se tocar `q_entregue`, existe impacto físico/logístico. |
| RN-05 | Se reduzir `q_entrega_futura`, reduz necessidade de compra agregada. |
| RN-06 | Se reduzir `q_reserva`, libera estoque físico para disponibilidade de outro item/projeto. |
| RN-07 | Se houver crédito/reembolso, Financeiro trata em fluxo próprio referenciado pela devolução. |
| RN-08 | `estoque_itens.quantidade_reservada` só é reduzido pela parte devolvida que estava em `q_entrega_futura` ou `q_reserva`; devolução de `q_entregue` depende de coleta/entrada física. |

## Critérios de aceite

- [ ] Devolução parcial reduz primeiro `q_entrega_futura`.
- [ ] Devolução que atravessa situações é dividida automaticamente pela RPC.
- [ ] `projeto_itens.quantidade` não é alterada.
- [ ] `q_devolvida` reflete a quantidade total devolvida.
- [ ] Movimentos de auditoria permitem reconstruir de onde a devolução saiu.
- [ ] Quando há redução de `q_entrega_futura`, `vw_necessidade_compra` muda.
- [ ] Quando há devolução de entregue, o status indica necessidade de coleta/logística.

## Realizado

### 2026-07-06

- Regra dos vídeos Connect incorporada como fonte operacional: `E. Futura → Reserva → Entregue`.
- SPEC deixou de ser apenas placeholder da reunião 08 e virou desenho implementável dependente da SPEC-010.

### 2026-07-07

- Migration `20260707_027_spec015_devolucao_estoque`: tabela `devolucoes_estoque`, RPC `registrar_devolucao_projeto_item`. Aplicada em produção.
- Testado em transação com `ROLLBACK`, reproduzindo o exemplo da própria SPEC (`q_entrega_futura=10, q_reserva=10, q_entregue=20`, devolução de 40): resultado `de_entrega_futura=10, de_reserva=10, de_entregue=20`, `status=aguardando_coleta`, exatamente como o exemplo previa.
- `estoque_itens.quantidade_reservada` reduzido com `GREATEST(...,0)` (RN-08) — não fica negativo mesmo quando o produto tem outras reservas concorrentes.
- Sem frontend nesta rodada — backend-only.

## Pendências

- [ ] Definir aprovação/permissão da devolução — RPC aberta a qualquer `authenticated` por enquanto.
- [ ] Definir efeitos financeiros: crédito, reembolso, abatimento ou só registro operacional.
- [ ] Definir tela de Logística para coleta quando a devolução tocar `q_entregue`.
- [ ] Frontend/tela que consuma `devolucoes_estoque`.
