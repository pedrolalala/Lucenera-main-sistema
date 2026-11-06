# Reunião 43 — 06/11/2026 — Sistema em geral (Vinicius, Pedro, Matheus, equipes de vendas, Débora)

> Transcrição: `Reunião. 01` (mesma pasta, ~2h20). Reunião é evidência, não decisão final: o que virou diretriz está nas SPECs 249–256.
> Participantes (pelo áudio): Vinicius, Pedro (desenvolvimento), Matheus (logística/estoque), Marina, Adriana, Murilo, Thaís e demais da equipe de vendas, Vitória (só citada), Débora (compras, ao final).

## Blocos da reunião

| Min. | Assunto | SPEC |
|---|---|---|
| 00–13 | Pedido de compra da Connect em PDF: teste real com o fornecedor de teste (vendas 5980, 5967, 5950, 5945); peças entram no pedido e saem da necessidade. Item especial por medida (Esteca/Linea/Versa) não dá para vincular. Débora vai importar os pedidos normais. | 253 |
| 13–14 | Boleto do Figueiredo Nunes: planilha dia 5, sistema sem nada (provável mudança de data entre a carga e ontem). | 249 |
| 15–29 | Rotina de transição: cliente novo/inativo, orçamento feito na Connect → XML → sistema novo; datas de pagamento só no novo; "tudo duplicado, só boleto e nota não". | 249, 254 |
| 29–38 | Separação e devolução nos dois sistemas; movimentação de estoque igual nos dois; avisar divergência cedo. | 249 |
| 38–48, 105–115 | Setor "em trânsito": reserva sem venda (herança Connect) que ficou no limbo; comando para limpar. Itens de teste 12757, 9931, 9988, 10614. | 250 |
| 48–67 | Venda Parcial: lista de vendas, separação, botão separar tudo, vendas antigas entregues sem lista, histórico, estorno. | 252 |
| 61–75, 126–135 | Transferir (pegar emprestado) entre vendas, todas as equipes, log por venda e geral. | 251 |
| 66–75 | Previsão de chegada ao lado da peça; pedido de compra ligado à venda; fornecedor atrasa → atualizar. | 253 |
| 75–78 | Fora de linha: tag e limite ao estoque (testado, funciona). Enter não adiciona item (de propósito). | 249 |
| 78–93 | Reimportar XML atualiza o orçamento (testado); desconto não atualiza; arquiteto puxado do vínculo; sinal; anexar comprovante Pix. | 254 |
| 93–101 | Bugs repetidos na Central; vendas já entregues em cinza/tag; remessa de transporte em aba separada. | 249, 252 |
| 101–104 | Calendário de entregas conta cada lista como uma entrega. | 256 |
| 115–138 | Garantia: saída sem financeiro, fluxo de aprovação, número de venda, log. | 255 |

## Decisões tomadas na reunião

1. **Transição:** a venda é montada na Connect e o XML vai para o sistema novo; as datas de pagamento e as etapas de aprovação são feitas só no novo. Nota fiscal e boleto saem só da Connect por enquanto. Parar de emitir nota na Connect: provavelmente janeiro.
2. **Estoque:** toda movimentação é feita nos dois sistemas. Divergência é avisada na hora (em 30 dias vira retrabalho total).
3. **Separação:** na Connect só se faz a separação dos itens; depois repete-se no sistema novo, que abre a tela de Logística. Dois testes feitos em 05/11 deram certo.
4. **Reimportar XML do mesmo número de orçamento atualiza** (não duplica). Plano B do mesmo cliente é outro orçamento.
5. **Transferir** aparece para todas as equipes e lista as vendas de todas as equipes; a Venda Parcial continua por equipe. Todo uso fica no log (quem, quando, de quem, por quê).
6. **Vendas finalizadas** ficam na mesma tela, em cinza ou com tag verde "Finalizado", sem guia separada.
7. **Remessa de transporte** vai para aba separada (consulta de Matheus e Vinicius).
8. **Itens especiais por medida:** o pedido de compra é montado manualmente no sistema, não importado do PDF.
9. **Garantia:** não gera financeiro e não pode depender da revisão financeira.
10. **Comprovante (Pix):** anexar na hora de "aprovar e enviar ao financeiro", não dentro do orçamento.
11. **Calendário de entregas:** agrupar entregas do mesmo cliente, endereço e data (nunca só pelo nome).
12. **Log de trocas:** aparece nas duas vendas envolvidas, nunca na venda que não participou; log geral com busca. Por enquanto as vendedoras continuam tirando print para o grupo de transferências.

## Pendências e dúvidas em aberto

- Regra de limpeza da "reserva sem venda": confirmar com a lista de conferência (Vitória confere ~10 itens depois que o Matheus baixar as listas de 05/11 na Connect). Ver SPEC-250.
- Vendas antigas já entregues sem lista de entrega: duas falas diferentes (não gerar saída irreal × dar baixa normal). Ver SPEC-252.
- Como distribuir a previsão de chegada quando um pedido de compra atende várias vendas. Ver SPEC-253.
- Garantia retroativa e número de venda com prefixo G. Ver SPEC-255.
- Chamados técnicos: 249.

## Insights

- A Débora é a dona de "atualizar previsão quando o fornecedor atrasa"; sem isso a previsão na venda não serve.
- Contagem de entregas para dashboard deve ser por entrega real (cliente + endereço + dia), não por lista.
