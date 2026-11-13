---
titulo: "SPEC-291 — Compras: pedido parcialmente recebido mostra só o que falta (itens, valor a receber e parcelas)"
status: implementada localmente em 12/11/2026 (sem commit, sem publicação; falta revisor e teste da Débora)
data_ultima_modificacao: 2026-11-12
sistemas_envolvidos:
  - Compras / Necessidade de Compra (04-Sistemas/compras-lucenera-3o23t98ee) — aba Pedidos
  - Banco (só leitura: pedido_compra_itens, notas_fiscais_compra, vw_contas_pagar_pedidos_compra) — sem migration prevista
---

# SPEC-291 — Pedido "Concluído parcialmente": mostrar só o que falta

**Origem:** pedido do usuário em 12/11/2026 (Débora, pedido 1930 com print): peças já recebidas continuam aparecendo no pedido e o valor do pedido continua o total depois da entrada parcial.
Relacionadas: SPEC-209 E, SPEC-213, SPEC-263, SPEC-289.

## Checklist de Ação

- [x] A. `PedidoItensResumo`: em pedido `parcialmente_recebido`, lista primeiro só o que **falta** (coluna "Falta"); itens 100% recebidos ficam recolhidos em **"Já recebidas (N) — ver"**; pedido nos outros status não muda
- [x] B. Cabeçalho da linha: valor principal vira **"A receber: R$ X"** (custo × o que falta) e, menor, "Pedido R$ total · recebido R$ Y"
- [x] C. `PedidoParcelasPanel`: mostra o **restante de cada parcela** (mesma conta da previsão no Contas a Pagar) e a linha "já abatido pela NF <nº>"; "Soma das parcelas" compara com o valor a receber, não com o total
- [x] D. PDF e "Enviar ao fornecedor" de pedido parcial listam **só o que falta**; pedido sem recebimento segue igual
- [x] E. `valor_total` gravado **não muda** (PDF, e-mail, previsão e Contas a Pagar dependem dele)
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
4. (revisor, 12/11) Vermelho no rodapé das parcelas **só em erro real de cadastro** (sem NF nem antecipação e soma das parcelas diferente do `valor_total` gravado). Com NF/antecipação a diferença para o "a receber" é só informação cinza ("Diferença = impostos/ST da NF").
5. (revisor, 12/11) PDF/e-mail de pedido parcial **não imprime tabela de parcelas**: só itens com saldo, observação "Saldo do pedido" + NF já recebidas (sem valores) e "Valor do saldo (itens que faltam)".

## Rollback

Reverter o commit de Compras (só tela; sem migration).

## Realizado (12/11/2026)

- Compras, só tela, sem migration: `PedidoItensResumo.tsx` (A), `PedidosCompra.tsx` (B, repasse de props), `PedidoParcelasPanel.tsx` (C), `pdf-pedido-fornecedor.ts` + `pdf-pedido-fornecedor-desenho.ts` (D; o "Enviar ao fornecedor" usa o mesmo gerador), `services/pedido-compra.ts` (leituras novas: `getResumoParcialPedidos`, `getConsumidoPedido`, `restanteDasParcelas`).
- A receber = Σ custo_unitario x falta; recebido = Σ custo_unitario x recebido. Restante da parcela = max(0, min(valor, acumulado - consumido)), consumido = Σ notas ativas + saldo de antecipação não aplicado (mesma conta de `financeiro_ponte_pedido`).
- Validação (leitura no banco real, pedido 1930): consumido 2.448,47 -> parcelas 0,00 / 598,19 / 1.523,34 (bate com a previsão do Contas a Pagar); itens: a receber 2.760,00, recebido 1.810,00.
- PDF de pedido parcial: quantidade = falta, itens sem saldo somem, total recalculado do que falta (valor_total gravado ignorado só no desenho), parcelas pelo restante (parcela zerada some), observação "Saldo do pedido".
- `tsc --noEmit`: 6 erros, os mesmos de antes; `oxlint` e `vite build` ok.
- Observação: no 1930, "Soma do que falta pagar" (2.121,53) difere do "a receber" (2.760,00) porque a NF (2.448,47) inclui ST e o recebido por itens é 1.810,00; a tela mostra a divergência em vermelho, como a SPEC pede (comparar com o a receber).
- Passos pendentes: rodar o agente `revisor`; commit e publicação do Compras (wrangler) só a pedido; Débora conferir o pedido 1930 na tela e o PDF/e-mail.

### Correções do revisor (12/11/2026)
- Falha silenciosa removida: `getConsumidoPedido` lança em qualquer erro (notas, antecipações, vínculos). Painel de parcelas mostra "Não foi possível calcular o restante das parcelas" e "—" nos valores (nunca parcela cheia como restante). PDF e e-mail abortam com o toast de erro já existente. Cabeçalho mostra "A receber indisponível" se a leitura falhar.
- "A receber"/"recebido" e o total do PDF passam a considerar o `desconto_percentual` do pedido (não se há `valor_negociado`); `custo_unitario` já embute IPI/ST (vem de `l.c.total` do pedido), então o total do saldo é coerente com as linhas de IPI/ST do PDF.
- Rodapé: vermelho só em erro real; senão informação neutra. PDF parcial: "Valor do saldo / (itens que faltam)", sem parcelas.
- `tsc` 6 erros (iguais), `oxlint` e `vite build` ok. Não testado no navegador.
