---
titulo: "SPEC-227 — Movimentação de Peças: Reserva → Entrega Futura com baixa automática no Estoque Geral (peça faltando)"
status: implementada
data_ultima_modificacao: 2026-10-26
sistemas_envolvidos:
  - Movimentação de Peças (04-Sistemas/movimentacao-pecas → movimentacao-lucenera.pages.dev)
  - Banco (RPC movimentar_peca_venda, estoque_itens local 'Estoque', movimentacoes_peca)
  - Cadastro (Setores da peça leem estoque_itens — mudam sozinhos)
---

# SPEC-227 — Peça faltando: Reserva → Entrega Futura já baixa o Estoque Geral

> Origem: reunião `02-Reunioes/37. Lucenera Matheus) - 26.10.2026_ Movimentação de peça/Reunião.01` (Pedro e Matheus).
> Exemplo do Matheus: a peça tem 10 no Estoque Geral e 10 na Reserva; na separação só existem 9. Hoje ele move 1 de
> Reserva → Entrega Futura e depois entra no Cadastro para baixar o Estoque Geral para 9 — dois processos para um.
> Decisão: "pode ser interessante se mover aí automático, que aí ele não precisa ficar fazendo dois processos".

## Como está hoje
- `movimentar_peca_venda(..., 'reserva_para_entrega_futura', ...)` só mexe no saldo do L
  (`q_reserva − q`, `q_entrega_futura + q`). A peça "volta livre" no Estoque Geral (livre = quantidade − reservado +
  entrega futura).
- Estoque Geral do Cadastro = `estoque_itens.quantidade` do local `Estoque` (mesma fonte deste sistema).

## Definição
### Banco (migration 243)
- `movimentar_peca_venda` ganha `p_baixar_estoque boolean DEFAULT false` (DROP da assinatura antiga de 4 parâmetros
  antes, para não criar sobrecarga).
- Só vale na ação `reserva_para_entrega_futura`. Quando `true`:
  - confere que o Estoque Geral tem a quantidade; tira `q` de `estoque_itens.quantidade` (local `Estoque`);
    `quantidade_reservada` não muda (a venda continua com a peça vendida, agora em entrega futura → volta a
    necessidade de compra);
  - grava, além do movimento de venda (Reserva → Entrega Futura), um movimento de setor
    `Estoque Geral → Baixa (peça faltando)` com o mesmo motivo e os saldos antes/depois.
- Peça já em Separação que falta: primeiro Separação → Reserva, depois Reserva → Entrega Futura com a baixa.

### Tela
- Nos dois lugares que fazem Reserva → Entrega Futura ("Mover de setor" com origem Reserva e o botão Mover do L):
  caixa **"A peça não existe fisicamente — baixar também do Estoque Geral"** (desmarcada por padrão; desmarcada = a
  peça fica livre, como hoje).
- Histórico: setor "Baixa (peça faltando)" no filtro.
- 26/10 (pedido do usuário, ele escolhia "De: Estoque Geral"): no Mover, **De Estoque Geral → Para Reserva** (escolhe
  um L com entrega futura; usa peça livre = `entrega_futura_para_reserva`) e **De Estoque Geral → Para Entrega Futura**
  (escolhe um L com reserva; peça que não existe = `reserva_para_entrega_futura` com baixa sempre). Separação não entra
  por aqui: separar é na Separação Parcial (cria o pedido de separação).

## Checklist
- [x] Migration 243 + rollback (volta a assinatura de 4 parâmetros)
- [x] Tela: caixa nos dois fluxos + texto de ajuda + filtro do histórico
- [x] Teste em ROLLBACK (10/10 → 9 no Estoque Geral, livre continua 0, 2 movimentos gravados)
- [ ] Teste do Matheus na tela

## Rollback
- `rollback.sql` da 243 recria a função de 4 parâmetros (versão da 236). Baixas feitas não voltam sozinhas: usar o
  histórico e mover/ajustar de volta.
