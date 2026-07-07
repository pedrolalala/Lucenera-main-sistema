---
titulo: "SPEC-011 — Transferência de Reserva Entre Itens de Projeto"
status: implementada no banco (backend); sem frontend nesta rodada
data_ultima_modificacao: 2026-07-06
sistemas_envolvidos:
  - Supabase (banco central)
  - Estoque
  - Compras
  - CRM
---

# SPEC-011 — Transferência de Reserva Entre Itens de Projeto

> **Dependência:** requer SPEC-010 (`estoque_saldos_projeto_item` e `estoque_movimentos_projeto_item`) implementada antes desta.

## Checklist de Ação

- [ ] Criar tabela `transferencias_estoque`.
- [ ] Criar RPC `solicitar_transferencia_estoque`.
- [ ] Criar RPC `aprovar_transferencia_estoque` (executada pela Vitória ou perfil autorizado).
- [ ] Criar RPC `cancelar_transferencia_estoque`.
- [ ] Criar view `vw_transferencias_estoque` para histórico e pendências.
- [ ] Atualizar `current/01_schema_full.sql` após aplicar migration.

### Passos manuais do usuário

- [ ] Confirmar com Vitória o fluxo de aprovação e os campos obrigatórios de motivo/observação.
- [ ] Confirmar com Débora como quer visualizar itens que perderam reserva e voltaram para entrega futura.
- [ ] Definir role/permissão para aprovar transferência.

## Objetivo

Quando uma quantidade fisicamente reservada para um projeto precisa atender outro projeto com urgência, o sistema deve registrar a operação sem apagar a obrigação original.

Na linguagem operacional, isso ainda aparece como "transferência entre clientes"; tecnicamente é uma transferência entre dois `projeto_item_id`, porque um mesmo cliente pode ter vários projetos e orçamentos.

## Decisões aprovadas

- Origem e destino da transferência são `projeto_item_id`.
- O produto da origem e do destino deve ser o mesmo.
- A origem precisa ter `q_reserva` suficiente.
- A aprovação reduz `q_reserva` da origem, aumenta `q_entrega_futura` da origem e registra `q_transferida_saida`.
- O destino recebe cobertura física em `q_reserva`; se havia `q_entrega_futura`, ela é reduzida.
- `estoque_itens.quantidade_reservada` não muda, porque o total comprometido por produto é o mesmo.
- Compra de reposição continua agregada por produto; não fica amarrada ao cliente/projeto de origem.

## Definição da SPEC

### Nova tabela: `transferencias_estoque`

```sql
CREATE TABLE public.transferencias_estoque (
    id                         uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    origem_projeto_item_id     uuid NOT NULL REFERENCES public.projeto_itens(id) ON DELETE RESTRICT,
    destino_projeto_item_id    uuid NOT NULL REFERENCES public.projeto_itens(id) ON DELETE RESTRICT,
    quantidade                 numeric(10,3) NOT NULL CHECK (quantidade > 0),

    status                     text NOT NULL DEFAULT 'solicitada'
        CHECK (status IN ('solicitada','aprovada','cancelada')),
    motivo                     text,
    solicitado_por             uuid REFERENCES auth.users(id),
    aprovado_por               uuid REFERENCES auth.users(id),
    solicitado_em              timestamptz NOT NULL DEFAULT now(),
    aprovado_em                timestamptz,
    cancelado_em               timestamptz,
    motivo_cancelamento        text
);

CREATE INDEX idx_te_origem  ON public.transferencias_estoque (origem_projeto_item_id);
CREATE INDEX idx_te_destino ON public.transferencias_estoque (destino_projeto_item_id);
CREATE INDEX idx_te_status  ON public.transferencias_estoque (status) WHERE status = 'solicitada';
```

### RPC: `solicitar_transferencia_estoque`

```sql
CREATE OR REPLACE FUNCTION public.solicitar_transferencia_estoque(
    p_origem_projeto_item_id  uuid,
    p_destino_projeto_item_id uuid,
    p_quantidade              numeric,
    p_motivo                  text DEFAULT NULL
) RETURNS jsonb
```

Validações:

- origem e destino existem em `projeto_itens`;
- ambos têm o mesmo `produto_id`;
- origem tem `q_reserva >= p_quantidade`;
- destino ainda tem saldo operacional capaz de receber cobertura física, normalmente `q_entrega_futura >= p_quantidade`;
- quantidade não ultrapassa `projeto_itens.quantidade` de origem/destino.

### RPC: `aprovar_transferencia_estoque`

```sql
CREATE OR REPLACE FUNCTION public.aprovar_transferencia_estoque(
    p_transferencia_id uuid
) RETURNS jsonb
```

Ao aprovar:

1. trava origem e destino em `estoque_saldos_projeto_item`;
2. reduz `origem.q_reserva`;
3. aumenta `origem.q_entrega_futura`;
4. aumenta `origem.q_transferida_saida`;
5. reduz `destino.q_entrega_futura` até o limite disponível;
6. aumenta `destino.q_reserva`;
7. grava movimentos `transferencia_saida` e `transferencia_entrada` em `estoque_movimentos_projeto_item`;
8. marca transferência como `aprovada`.

### RPC: `cancelar_transferencia_estoque`

Cancelamento só é permitido enquanto `status = 'solicitada'`. Transferência aprovada não é apagada; reversão exige nova transferência no sentido contrário.

### View: `vw_transferencias_estoque`

A view deve resolver produto, projeto, orçamento e cliente por `JOIN` a partir dos dois `projeto_item_id`.

Campos mínimos:

```text
transferencia_id
status
produto_id, produto, produto_codigo
quantidade
origem_projeto_item_id, origem_projeto_codigo, origem_orcamento_numero, origem_cliente
destino_projeto_item_id, destino_projeto_codigo, destino_orcamento_numero, destino_cliente
motivo
solicitado_por, aprovado_por
solicitado_em, aprovado_em
```

## Regras de negócio

| # | Regra |
|---|---|
| RN-01 | Transferência é entre dois `projeto_item_id`, não entre clientes soltos. |
| RN-02 | Origem e destino precisam ser do mesmo produto. |
| RN-03 | Origem precisa ter `q_reserva` suficiente. |
| RN-04 | Origem perde cobertura física e volta para `q_entrega_futura`. |
| RN-05 | Destino ganha cobertura física em `q_reserva`. |
| RN-06 | O total agregado em `estoque_itens.quantidade_reservada` não muda. |
| RN-07 | Compra de reposição é por produto, sem vínculo fixo ao cliente/projeto de origem. |
| RN-08 | Histórico é permanente e auditável. |

## Critérios de aceite

- [ ] Solicitação de transferência cria linha em `transferencias_estoque` com status `solicitada`.
- [ ] Não é possível transferir entre produtos diferentes.
- [ ] Não é possível transferir mais do que `origem.q_reserva`.
- [ ] Aprovação atualiza saldos da origem e destino conforme regra acima.
- [ ] Movimentos de saída e entrada ficam registrados em `estoque_movimentos_projeto_item`.
- [ ] View mostra origem/destino por projeto, orçamento e cliente, sem duplicar essas chaves na tabela de transferência.

## Realizado

### 2026-07-07

- Migration `20260707_026_spec011_transferencia_reserva`: tabela `transferencias_estoque`, view `vw_transferencias_estoque`, RPCs `solicitar_/aprovar_/cancelar_transferencia_estoque`. Aplicada em produção via `SUPABASE_DB_URL`.
- Testado em transação com `ROLLBACK` (sem dado real afetado): solicitação, aprovação com saldos corretos (origem `q_reserva -2`/`q_entrega_futura +2`/`q_transferida_saida +2`, destino `q_entrega_futura -1`/`q_reserva +2`), dois movimentos em `estoque_movimentos_projeto_item`, e bloqueio de cancelamento pós-aprovação.
- Aprovação restrita a `usuarios.role IN ('admin','gerente')`, verificado dentro da RPC.
- Sem frontend nesta rodada — backend-only, pronto para consumo quando existir tela de Estoque/Compras ou painel administrativo.

## Pendências

- [x] Depende da SPEC-010 implementada — SPEC-010 aplicada e endurecida (`20260707_023`).
- [x] Definir role de aprovação — `admin`/`gerente`, ver "Realizado".
- [ ] Definir notificação para Débora quando origem voltar para entrega futura.
- [ ] Frontend/tela que consuma `vw_transferencias_estoque`.
