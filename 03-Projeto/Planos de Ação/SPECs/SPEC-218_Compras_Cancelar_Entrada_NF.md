---
titulo: "SPEC-218 — Necessidade de Compra: cancelar uma Entrada de Nota Fiscal"
status: concluída
data_ultima_modificacao: 2026-10-21
sistemas_envolvidos:
  - Necessidade de Compra (compras-lucenera-3o23t98ee)
---

# SPEC-218 — Cancelar uma Entrada de Nota Fiscal

## Checklist de Ação

- [x] Migration 230 redigida + rollback; teste completo em transação com ROLLBACK no banco real (como o Vinícius)
- [x] Botão "Cancelar" em Entrada de Nota Fiscal › Últimas entradas, com motivo obrigatório
- [x] `vite build` do Compras ok
- [x] Aplicar a migration 230 no Supabase (21/10)
- [x] Push do Compras bfb2e5c (Cloudflare) e ponteiro do submodule no repo central
- [x] NF 211026 cancelada em 21/10 pela RPC (usuário do Vinícius; a conta do Pedro não tem editar na Necessidade de Compra) — pedido 1783 voltou para Aprovado, 0 recebido, parcela fora do A Pagar

## Pedido do usuário (21/10)

O Vinícius apertou Enter e a NF 211026 (pedido 1783, R$ 1.456,71) entrou sem querer. A entrada faz várias coisas com um
clique (quantidade recebida, status do pedido, parcelas no Contas a Pagar da Adm. Bancária/Dash, antecipação). Precisa de
um botão para cancelar a entrada dentro da própria aba Entrada de Nota Fiscal.

## O que o cancelamento faz

RPC `cancelar_entrada_nota_compra(p_nota_id, p_motivo)` (permissão: `necessidade-de-compra` com editar), numa transação:

1. Devolve a quantidade recebida de cada item que entrou por esta nota (`nota_fiscal_compra_itens`).
2. Recalcula o status do pedido: tudo recebido → Concluído; algo recebido → Concluído parcialmente; nada → Aprovado
   (limpa `recebido_em`/`primeira_entrada_em` conforme o caso). Pedido cancelado não muda.
3. Apaga as parcelas da nota (`nota_fiscal_compra_parcelas`) → saem do Contas a Pagar.
4. Apaga os vínculos com pagamento antecipado → o saldo da antecipação volta.
5. Marca a nota como cancelada (`cancelada_em`, `cancelada_por`, `motivo_cancelamento`). Ela continua na lista, riscada,
   com o selo "Cancelada" (motivo no passar do mouse). Nota cancelada não abate a previsão do pedido no A Pagar e não
   impede relançar o mesmo número.

Não volta: a troca de fornecedor feita na entrada (o fornecedor antigo não é guardado). Estoque não é tocado (a
entrada também não toca). Cancelamento não tem "desfazer"; para corrigir, lançar a nota de novo.

## Banco (migration `20261021_230_spec218_cancelar_entrada_nf`)

- `notas_fiscais_compra`: colunas `cancelada_em`, `cancelada_por`, `motivo_cancelamento`; trigger de auditoria.
- Correção: o trigger `notas_fiscais_compra_updated_at` chamava `fn_atualiza_updated_at` (coluna `updated_at`, que a
  tabela não tem) — todo UPDATE nessa tabela dava erro. Trocado por `update_atualizado_em`.
- Tabela nova `nota_fiscal_compra_itens` (nota × item do pedido × quantidade), RLS de leitura igual às parcelas, escrita
  só pelas RPCs. Backfill: nota única do pedido recebe tudo que foi recebido (hoje só a 211026: 7 itens, 44 un.).
- `registrar_entrada_nota_compra`: grava `nota_fiscal_compra_itens`; checagem de nota duplicada ignora cancelada.
- `vw_contas_pagar_pedidos_compra`: nota cancelada não entra no consumo da previsão nem nas parcelas.

## Teste (21/10, em ROLLBACK, como o Vinícius)

- Sem motivo → erro; cancelar a 211026 → pedido 1783 volta para Aprovado, qtd recebida 0, parcela `nf:` some do A
  Pagar, nota marcada; cancelar de novo → erro; `anon` → sem permissão; auditoria registra nota e pedido.
- Relançar a 211026 com metade de um item → Concluído parcialmente, itens gravados, parcela nova no A Pagar; cancelar
  essa → volta para Aprovado. Rollback.sql roda limpo.

## Rollback

`rollback.sql` da migration (volta função/view da 229, tira tabela, colunas e trigger). Usar só antes de cancelar alguma
nota: parcelas e vínculos apagados no cancelamento não voltam.
