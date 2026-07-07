# Migration 20260707_026 - SPEC-011 (Transferencia de Reserva Entre Itens de Projeto)

## Contexto

Ver `03-Projeto/Planos de Ação/SPECs/SPEC-011_Transferencia_Reserva_Entre_Itens_de_Projeto.md`.
Depende da SPEC-010 (ja aplicada, hardening 023, RLS de leitura 024).

## Arquivos

| Arquivo | Funcao |
|---|---|
| `001_tabela_e_view.sql` | Tabela `transferencias_estoque`, indices, RLS (leitura ampla para `authenticated`), view `vw_transferencias_estoque`. |
| `002_rpcs.sql` | `solicitar_transferencia_estoque`, `aprovar_transferencia_estoque` (restrita a `admin`/`gerente`), `cancelar_transferencia_estoque`. |

## Decisao de permissao (role)

Aprovacao restrita a `usuarios.role IN ('admin','gerente')`, verificado dentro
da propria RPC (nao via RLS de tabela, ja que a escrita e sempre via
`SECURITY DEFINER`). Configuracao granular por modulo/acao pela UI do Hub
(SPEC-006) fica para quando esse sistema existir — esta migration usa o role
simples ja existente, sem antecipar esse desenho.

## Aplicado em

2026-07-07, via `psql "$SUPABASE_DB_URL" -f 001_tabela_e_view.sql` seguido de
`002_rpcs.sql`.

## Verificacao pos-aplicacao

Executada em transacao com `ROLLBACK` (nenhum dado de teste ficou no banco):

1. `solicitar_transferencia_estoque` cria registro `solicitada` e recusa
   quantidade acima de `q_reserva` da origem.
2. `aprovar_transferencia_estoque`, chamada como usuario `admin` real (via
   `SET LOCAL request.jwt.claim.sub`), moveu os saldos corretamente:
   origem `q_reserva -2`, `q_entrega_futura +2`, `q_transferida_saida +2`;
   destino `q_entrega_futura -1` (limitado ao disponivel), `q_reserva +2`.
3. Dois movimentos gravados em `estoque_movimentos_projeto_item`
   (`transferencia_saida`/`transferencia_entrada`), ambos com o mesmo
   `referencia_id` da transferencia.
4. Cancelar uma transferencia ja aprovada foi corretamente bloqueado.

## Depois da aplicacao

- Reextrair `supabase/db/current/` (feito ao final do lote desta rodada).
- Marcar SPEC-011 como implementada em "Realizado".
- Sem frontend nesta rodada — SPEC-011 e backend-only ate existir sistema de
  Estoque/Compras ou tela que consuma `vw_transferencias_estoque`.
