---
titulo: "SPEC-291 — Compras: pedido parcialmente recebido mostra só o que falta (itens, valor a receber e parcelas)"
status: pendente (SPEC aprovada nas recomendações; implementação não iniciada)
data_ultima_modificacao: 2026-11-12
sistemas_envolvidos:
  - Compras / Necessidade de Compra (04-Sistemas/compras-lucenera-3o23t98ee) — aba Pedidos
  - Banco (só leitura: pedido_compra_itens, notas_fiscais_compra, vw_contas_pagar_pedidos_compra) — sem migration prevista
---

# SPEC-291 — Pedido "Concluído parcialmente": mostrar só o que falta

**Origem:** pedido do usuário em 12/11/2026 (Débora, pedido 1930 com print): peças já recebidas continuam aparecendo no pedido e o valor do pedido continua o total depois da entrada parcial.
Relacionadas: SPEC-209 E, SPEC-213, SPEC-263, SPEC-289.

## Checklist de Ação

- [ ] A. `PedidoItensResumo`: em pedido `parcialmente_recebido`, lista primeiro só o que **falta** (coluna "Falta"); itens 100% recebidos ficam recolhidos em **"Já recebidas (N) — ver"**; pedido nos outros status não muda
- [ ] B. Cabeçalho da linha: valor principal vira **"A receber: R$ X"** (custo × o que falta) e, menor, "Pedido R$ total · recebido R$ Y"
- [ ] C. `PedidoParcelasPanel`: mostra o **restante de cada parcela** (mesma conta da previsão no Contas a Pagar) e a linha "já abatido pela NF <nº>"; "Soma das parcelas" compara com o valor a receber, não com o total
- [ ] D. PDF e "Enviar ao fornecedor" de pedido parcial listam **só o que falta**; pedido sem recebimento segue igual
- [ ] E. `valor_total` gravado **não muda** (PDF, e-mail, previsão e Contas a Pagar dependem dele)
- [ ] F. Build, revisor, publicar Compras, CHANGELOG; teste da Débora com o pedido 1930

### Passos manuais do usuário
- [ ] Débora conferir o pedido 1930 (a peça 10292 falta; as outras duas recolhidas; valor a receber R$ 2.760,00)

## Estado verificado (pedido 1930 CONNECT, 12/11/2026)

- 3 itens: 9961 (10/10), 10292 (0/4, R$ 2.760,00), 10453 (10/10). `valor_total` R$ 4.570,00; parcelas do pedido 1.523,33 / 1.523,33 / 1.523,34 (tabela `pedido_compra_parcelas`, não alterada por design).
- NF 23713 de R$ 2.448,47 (ST 461,99) ativa (uma entrada anterior foi cancelada às 17:22).
- No Contas a Pagar a previsão já caiu para R$ 598,19 (07/12) e R$ 1.523,34 (06/01): a tela de Pedidos é que não reflete isso.
- O recebido por itens (R$ 1.810,00) difere da NF (R$ 2.448,47) por causa do ST; a tela mostra os dois sem tentar igualar.

## Decisões (recomendações do usuário, 12/11/2026)

1. Mostrar "A receber" no cabeçalho e **manter** o `valor_total` gravado.
2. PDF e envio ao fornecedor de pedido parcial listam só o que falta.
3. Peça totalmente recebida fica **recolhida** ("Já recebidas"), não some.

## Rollback

Reverter o commit de Compras (só tela; sem migration).
