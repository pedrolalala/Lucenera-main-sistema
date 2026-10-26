---
titulo: "SPEC-232 — Reserva sem venda (herança Connect) não muda com venda feita no sistema"
status: concluído
data_ultima_modificacao: 2026-10-26
sistemas_envolvidos:
  - Banco (Supabase)
  - Cadastro (consulta de produtos)
  - Separação Parcial
  - Logística
  - Compras (re-reserva)
  - Orçamentos (aprovação)
---

# SPEC-232 — Reserva sem venda (herança Connect) não muda com venda feita no sistema

## Checklist de Ação

- [x] Finalizar a separação (Entregue) baixa o Estoque Geral e libera o reservado (`sync_entregue_ao_finalizar_separacao`).
- [x] Entrega concluída na Logística baixa o Estoque Geral, libera o reservado e não conta em dobro o que a separação já entregou (`sync_entregue_ao_finalizar_entrega`).
- [x] Devolução do Entregue soma no Estoque Geral e não baixa o reservado (`registrar_devolucao_projeto_item_setor`; `confirmar_recebimento_devolucao` não mexe mais).
- [x] Re-reserva (Entrega Futura → Reserva) não soma o reservado de novo (`re_reservar_projeto_item`).
- [x] Aprovação: peça já com o cliente (empréstimo, SPEC-223) não soma no reservado (`aprovar_orcamento_financeiro`).
- [x] Acerto da peça 12822: reservado 85 → 82 (herança 35 → 32), Estoque Geral 100 → 97 (disponível 15, Reserva 50).
- [x] Migration `20261026_247_spec232_heranca_connect_venda_interna` (up + rollback), ensaiada com ROLLBACK.
- [x] Aplicar a migration 247 no Supabase.

### Passos manuais do usuário

- [x] Autorizar a aplicação da migration 247.
- [ ] Conferir na consulta de produtos a 12822: Estoque Geral 97, Reserva 50, herança Connect 32, disponível 15.

## Objetivo

Em 26/10 a peça 12822 (GU10 Dicroica 2700K) passou de 32 para 35 em "Reserva sem venda (herança Connect)", e tudo o que foi feito nela foi por venda do sistema. O número é
`estoque_itens.quantidade_reservada (Estoque) − (Reserva + Entrega Futura + Separação dos L)`, mas algumas operações
mexiam só num lado da conta:

| Operação | Antes | Efeito na herança |
|---|---|---|
| Entregar (finalizar separação / entrega) | saldo saía da Separação, reservado ficava | sobe |
| Devolver do Entregue | baixava o reservado | desce |
| Re-reserva EF → Reserva | somava o reservado de novo (a aprovação já somou a venda inteira) | sobe |
| Aprovação com peça já com o cliente | somava reservado, saldo ia direto pra Entregue | sobe |

Na 12822: 9 entregues (+9) e 6 devolvidas do Entregue (−6) → +3.

## Decisões aprovadas

- (Usuário, 26/10) Opção 1: entregar passa a baixar o reservado da Connect.
- (Usuário, 26/10) Estoque Geral físico acompanha a venda: entregar baixa, devolver do Entregue soma de volta.
  12822 deve ficar Estoque Geral 97, disponível 15, Reserva 50.
- (Usuário, 26/10) Regra geral: o que é feito por venda do sistema **não** altera a herança da Connect. Toda operação
  de venda mexe no reservado na mesma medida em que mexe em Reserva + Entrega Futura + Separação.

## Definição da SPEC

Invariante: para operações de venda do sistema, Δ`quantidade_reservada` = Δ(Reserva + Entrega Futura + Separação).

Já estavam certas e não mudam: aprovação normal (+venda inteira), cancelar orçamento (−saldo aberto), desfazer
aprovação, devolução de Reserva/Entrega Futura (−), separação/cancelamento/transferência entre L (não mexem em nenhum dos dois),
entrada de NF (EF → Reserva, não mexe no reservado), fechar projeto (`trigger_fechar_projeto`: bloqueia se houver
Entrega Futura aberta e baixa físico + reservado pelo mesmo saldo que leva para Entregue).

**Regra (usuário, 26/10): o que foi feito no sistema nunca vira herança.** Toda função nova que mexer em saldo de
venda precisa mexer no `quantidade_reservada` na mesma medida.

## Realizado

### 2026-10-26

- Diagnóstico da 12822 pelos movimentos de `estoque_movimentos_projeto_item` (únicos movimentos de entregue/devolução do banco).
- Migration 247 gerada a partir do `pg_get_functiondef` atual (só os trechos marcados SPEC-232 mudam) e ensaiada com ROLLBACK: 12822 fica Geral 97 / reservado 82 / Reserva 50 / herança 32 / disponível 15.
- Migration 247 APLICADA (autorizada pelo usuário). Conferido no banco: 12822 Geral 97, reservado 82, Reserva 50, herança 32, disponível 15; as 6 funções com o trecho SPEC-232.

## Pendências

- [ ] Conferência visual da 12822 na consulta de produtos (Cadastro) pelo usuário.
