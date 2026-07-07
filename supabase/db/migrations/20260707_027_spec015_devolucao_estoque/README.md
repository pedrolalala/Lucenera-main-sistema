# Migration 20260707_027 - SPEC-015 (Devolucao de Estoque por Item de Projeto)

## Contexto

Ver `03-Projeto/Planos de Ação/SPECs/SPEC-015_Devolucao_Estoque_por_Item_de_Projeto.md`.
Depende da SPEC-010 (ja aplicada).

## Arquivos

| Arquivo | Funcao |
|---|---|
| `001_tabela.sql` | Tabela `devolucoes_estoque`, indices, RLS (leitura ampla para `authenticated`). |
| `002_rpc.sql` | `registrar_devolucao_projeto_item`, aplicando a hierarquia `q_entrega_futura -> q_reserva -> q_entregue`. |

## Decisao de permissao

Quem pode registrar devolucao continua uma pendencia aberta na propria SPEC
("Definir aprovacao/permissao da devolucao") — a RPC fica disponivel para
qualquer `authenticated` nesta rodada, sem checagem de role adicional. Isso
sera revisitado quando o fluxo de aprovacao (Filippo/Vitoria/Debora, citado na
SPEC) for definido.

## Aplicado em

2026-07-07, via `psql "$SUPABASE_DB_URL" -f 001_tabela.sql` seguido de
`002_rpc.sql`.

## Verificacao pos-aplicacao

Executada em transacao com `ROLLBACK`, reproduzindo o exemplo da propria SPEC:
item com `q_entrega_futura=10, q_reserva=10, q_entregue=20`, devolucao de 40.

- Resultado: `de_entrega_futura=10, de_reserva=10, de_entregue=20`,
  `status=aguardando_coleta` (bate com o exemplo da SPEC).
- Saldo apos devolucao: `entrega_futura=0, reserva=0, entregue=0, devolvida=40`.
- `estoque_itens.quantidade_reservada` reduziu, mas com `GREATEST(...,0)`
  (RN-08): no teste, o produto reaproveitado ja tinha `quantidade_reservada=7`
  de reserva real preexistente (de outro item de projeto), menor que os 20 que
  o teste isolado tentaria subtrair — o clamp evitou ficar negativo, que e o
  comportamento correto quando `estoque_itens` agrega varios `projeto_item_id`
  do mesmo produto.

## Depois da aplicacao

- Reextrair `supabase/db/current/`.
- Marcar SPEC-015 como implementada em "Realizado".
- Sem frontend nesta rodada — backend-only ate existir sistema de
  Estoque/Compras ou tela de Logistica/CRM que consuma `devolucoes_estoque`.
