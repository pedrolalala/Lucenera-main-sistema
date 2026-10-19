---
titulo: "SPEC-209 — Compras: pedidos da reunião de 19/10 (Necessidade de Compra, Pedidos, Entrada e Separação Parcial)"
status: pendente
data_ultima_modificacao: 2026-10-19
sistemas_envolvidos:
  - Necessidade de Compra (compras-lucenera)
  - Separação Parcial
  - Dashboard Financeiro (fluxo de caixa) — só a parte F, depois
---

# SPEC-209 — Compras: pedidos da reunião de 19/10 com Vinicius e Débora

Fonte: `02-Reunioes/32. Lucenera (Vinicius e Debora) 19.10.2026_ Sistema de Necessidade de compra/Reunião 01`.
O minuto da gravação aparece entre colchetes em cada pedido.

## Checklist de Ação

**A. Montar o pedido de compra (Necessidade de Compra)**
- [ ] A1. Seleção que não se perde: marcar L de produtos diferentes (e produtos inteiros) num só "carrinho" do pedido. Abrir outro produto não pode desmarcar o anterior.
- [ ] A2. Fechar o pedido só com os L marcados. Hoje "Fechar pedido em lote" leva o produto inteiro, todos os L.
- [ ] A3. Filtro de empresa (Manoela / Foco / Islight / Todas) na lista da Necessidade de Compra, pela empresa da venda.
- [ ] A4. Já trazer a empresa da venda selecionada no pedido, podendo trocar.
- [ ] A5. Poder arrastar a janela "Gerar compra" / "Fechar pedido" para o lado e ver a tela de trás.
- [ ] A6. Barra do pedido em montagem sempre visível: N itens, fornecedor, empresa, total, botão "Fechar pedido" e "Limpar".

**B. Valores no pedido (janelas Gerar Compra e Fechar Pedido em Lote)**
- [x] B1. Tirar a coluna ICMS.
- [x] B2. Ordem das colunas: Preço de custo · ST · IPI · Outras despesas · Total.
- [x] B3. "Líquido" passa a se chamar "Preço de custo" e já vem com o desconto do produto (`porc_desconto`). Exemplo: R$ 100 com 25% vem R$ 75.
- [x] B4. ST, IPI e Outras despesas calculados sobre o preço de custo com desconto, pelos % do cadastro (`porc_st`, `ipi_entrada`, `porc_despesas`). Mostrar o % junto do R$ para bater com o cadastro.
- [x] B5. Rodapé com "Valor total dos produtos" (preço de custo × quantidade) e embaixo "Valor total dos produtos com impostos" (com ST + IPI + outras despesas). Este substitui o "Total estimado".
- [x] B6. Gravar outras despesas no item do pedido (coluna nova `valor_outras_despesas` em `pedido_compra_itens`).

**C. Condição de pagamento e previsão de entrega**
- [ ] C1. Aceitar "30/60/90" (dias) e também datas digitadas (ex.: 15/11, 15/12). As parcelas são divididas em partes iguais.
- [ ] C2. Gerar as parcelas do pedido (`pedido_compra_parcelas`) com data e valor, para alimentar a previsão de pagamento.
- [ ] C3. Aviso de chegada: quando faltarem 10 dias para a data prevista de entrega de um pedido em aberto, mostrar aviso ao abrir o sistema ("Em 10 dias chega o pedido #N da Interlight — confirme com o fornecedor").
- [ ] C4. (Depois, quando houver histórico) sugerir o prazo médio de entrega do fornecedor, pela diferença entre a data do pedido e a data da entrada. Por enquanto só mostrar quando já houver pedidos concluídos.

**D. Pedidos: juntar Solicitações em Pedidos e novos status**
- [ ] D1. A aba "Solicitações" deixa de existir; tudo fica na tela "Pedidos".
- [ ] D2. Status do pedido: **Aguardando aprovar** (enviado ao fornecedor, esperando o retorno) → **Aprovado** (fornecedor confirmou) → **Concluído parcialmente** / **Concluído**. Também **Cancelado**. Não usar "Rejeitado".
- [ ] D3. Pedido em "Aguardando aprovar" pode ser editado: quantidade, preço, desconto, itens a mais ou a menos, condição, previsão.
- [ ] D4. Botão "Aprovar" (Aguardando aprovar → Aprovado).
- [ ] D5. Cancelar exige justificativa (como na aprovação financeira). Ao cancelar, a necessidade de compra dos itens volta a aparecer.
- [ ] D6. Abas ou filtro por status na tela Pedidos.

**E. Entrada de mercadoria amarrada ao pedido**
- [ ] E1. A entrada pelo número do pedido atualiza `qtd_recebida` de cada item.
- [ ] E2. Se todos os itens chegaram, o pedido vai sozinho para **Concluído**. Se chegou só uma parte, vai para **Concluído parcialmente**. Quando o resto der entrada, vai para **Concluído**.
- [ ] E3. Conferir a entrada de ponta a ponta com a Débora depois de A–D prontos ("gostaria que arrumasse antes de testar").

**F. Fluxo de caixa (depois de C2)**
- [ ] F1. Parcelas dos pedidos em aberto entram como previsão de pagamento no fluxo de caixa (visualização que o Vinicius vai montar com Carol e Lana).

**G. Separação Parcial (mesmo padrão da consulta de produtos)**
- [x] G1. Linhas da tabela em preto, como no Cadastro (SPEC-195 B4). No computador do Vinicius as linhas cinza somem.
- [x] G2. Linha mais grossa separando cada L (acabou o L1, linha; acabou o L2, linha).
- [x] G3. Linha selecionada ou com o mouse em cima em azul claro bem visível, igual para todos.
- [x] G4. Cabeçalho fixo ao rolar, se a lista for longa (mesma correção da SPEC-208).

**H. Já feito / fora do sistema**
- [x] H1. Busca de item na Separação Parcial (SPEC-207, 19/10).
- [x] H2. Cabeçalho fixo na consulta de produtos do Cadastro (SPEC-208, 19/10).
- [ ] H3. Acesso da Débora: ela trocou a senha e não consegue entrar. Resetar pela Central ou pelo "Esqueci a senha". O e-mail de recuperação depende do SMTP próprio, pendente na SPEC-205.

### Passos manuais do usuário

- [ ] Aprovar as decisões em aberto (seção abaixo).
- [ ] Aplicar as migrations quando estiverem prontas (status novos, coluna de outras despesas, parcelas).
- [ ] Teste com a Débora: montar um pedido com L de vendas diferentes, aprovar, dar entrada parcial e depois total.

## Objetivo

Deixar a Débora montar pedidos de compra do jeito que ela compra de verdade: escolhendo L por L de vários produtos e
vendas, por empresa, com o custo igual ao do cadastro (desconto e ST/IPI/outras despesas). O pedido deve seguir um
ciclo claro (aguardando aprovar → aprovado → concluído), com a entrada de mercadoria fechando o pedido sozinha e as
parcelas indo para a previsão de pagamento.

## Decisões aprovadas (na reunião)

- O ICMS sai da tela de compra. O custo usa ST, IPI e outras despesas: às vezes os três, às vezes só um [06:54].
- O preço de custo do pedido já vem com o desconto do cadastro [09:03].
- Compra-se por empresa conforme a venda (99% dos casos), mas pode montar em outra empresa [03:26].
- Parcelas divididas em partes iguais por enquanto [14:49].
- "Rejeitado" vira "Cancelado", com justificativa obrigatória. Cancelar devolve a necessidade de compra [22:17–23:15].
- Concluído e Concluído parcialmente são automáticos pela entrada amarrada ao número do pedido [23:48].
- A sugestão de prazo médio do fornecedor depende de histórico; leva de 2 a 3 meses para ficar boa [12:30].

## Definição da SPEC

### Estado atual (19/10/2026)

| Ponto | Hoje | Onde |
|---|---|---|
| Seleção por L | Fica dentro do produto aberto (`NecessidadeCompraDetalhe`, estado local). Abrir outro produto perde a seleção. | `components/compra/NecessidadeCompraDetalhe.tsx` |
| Pedido em lote | Seleciona produto inteiro; leva todos os L | `pages/NecessidadeCompra.tsx` + `ModalPedidoLote.tsx` |
| Filtro | Só marca e busca; sem empresa | `pages/NecessidadeCompra.tsx` |
| Colunas de valor | Líquido · ICMS · IPI · ST · Total; custo = líquido + ICMS + IPI + ST (sem outras despesas) | `ModalGerarCompraItemOrcamento.tsx`, `ModalPedidoLote.tsx` |
| Líquido | `preco_custo` sem desconto (ou custo do `produto_fornecedores`) | `services/pedido-compra.ts` (`getProdutoImpostos*`) |
| Status do pedido | CHECK: rascunho, aprovado, enviado, parcialmente_recebido, recebido, cancelado. Em uso: enviado 52, cancelado 4. | `pedidos_compra` |
| Solicitações | Tela própria com Aguardando aprovar / Aprovado / Rejeitado (`solicitacoes_aprovacao_compra`, vazia hoje) | `pages/Solicitacoes.tsx` |
| Cancelar pedido | Já pede motivo (`motivo_cancelamento`) | `pages/PedidosCompra.tsx` |
| Entrada | Já busca o pedido pelo número (modo "Tenho o número do pedido") | `pages/EntradaNotaFiscal.tsx` |

### O "IPI errado" do 11248 [04:21–06:02]

Não é erro de cadastro. O produto 11248 tem `ipi_entrada` = 3,75 (%) e `preco_custo` = R$ 66,04. A coluna da compra mostra
o **valor** em R$: 66,04 × 3,75% = R$ 2,47. A consulta de produtos mostra o **percentual** (3,75). Por isso o B4 manda mostrar
o % ao lado do R$. O custo total do cadastro confere: 66,04 × (1 + 3,75% + 34% de outras despesas) = R$ 90,97.

### Fórmula do item (igual ao cadastro, SPEC-190)

```
preco_custo_com_desc = preco_custo × (1 − porc_desconto/100)        -- "Preço de custo" na tela
st    = preco_custo_com_desc × porc_st/100
ipi   = preco_custo_com_desc × ipi_entrada/100
outras= preco_custo_com_desc × porc_despesas/100
custo_com_impostos = preco_custo_com_desc + st + ipi + outras
Valor total dos produtos               = Σ preco_custo_com_desc × qtd
Valor total dos produtos com impostos  = Σ custo_com_impostos × qtd   (− desconto do pedido, se houver)
```

Tudo continua editável na linha, porque o fornecedor pode dar outro preço.

### Status novos do pedido (proposta de migration)

| Status gravado | Nome na tela | Como chega |
|---|---|---|
| `aguardando_aprovar` | Aguardando aprovar | ao gerar o pedido (substitui `enviado`) |
| `aprovado` | Aprovado | botão Aprovar |
| `parcialmente_recebido` | Concluído parcialmente | entrada com parte dos itens |
| `recebido` | Concluído | entrada com tudo |
| `cancelado` | Cancelado | botão Cancelar + justificativa |

Os 52 pedidos `enviado` viram `aguardando_aprovar` (ou `aprovado`, ver decisão 3). `rascunho` sai do CHECK se não houver uso.

## Decisões em aberto (perguntar ao Vinicius/Débora)

1. Na seleção por L, o pedido continua sendo de **um fornecedor só**? Hoje o lote trava num fornecedor.
2. O filtro de empresa usa a **empresa da venda** (orçamento) ou a empresa que vai comprar?
3. Os 52 pedidos antigos `enviado` vão para "Aguardando aprovar" ou "Aprovado"?
4. Aviso dos 10 dias: só para a Débora (papel de compras) ou para todos que abrem a Necessidade de Compra? Aparece só em pop-up ou também numa lista "Chegando nos próximos 10 dias"?
5. Pedido "Aprovado" ainda pode ser editado, ou só "Aguardando aprovar"?
6. A tela Solicitações e a tabela `solicitacoes_aprovacao_compra` (vazia hoje) somem de vez?

## Realizado

### 2026-10-19 — partes B e G

- **B (compras-lucenera c844b87):** as 3 janelas de compra mostram a mesma coisa.
  - As janelas são Gerar Compra por item, Pedido em Lote e Comprar.
  - Colunas: Preço de custo (já com `porc_desconto`) · ST % · IPI % · Outras despesas % (o R$ de cada um embaixo) · Total/un.
  - O ICMS saiu.
  - Rodapé com "Valor total dos produtos" e "Valor total dos produtos com impostos".
  - Os % vêm do cadastro e podem ser ajustados no pedido.
  - O custo do fornecedor (`produto_fornecedores.custo_unitario`) continua valendo sem aplicar desconto.
- **B6:** migration 225 aplicada.
  - `pedido_compra_itens.valor_outras_despesas` e `criar_pedido_compra_lote` gravam outras despesas.
  - `criar_pedido_compra_de_necessidade` ganhou `p_valor_outras_despesas`; foi recriada com DROP para não virar overload.
  - Dry-run testou as duas RPCs e a chamada antiga; o rollback foi conferido.
- **G (separacao-parcial c9ad7cb):** tabela de itens da venda:
  - em ordem de L, com linhas pretas;
  - linha grossa entre um L e outro;
  - linha azul ao passar o mouse e mais forte enquanto se digita nela;
  - cabeçalho fixo, com a tabela rolando dentro de 70% da altura da tela.

## Pendências

- [ ] Responder as 6 decisões em aberto da SPEC-209 com o Vinicius e a Débora antes de implementar A, D e E.
- [ ] Implementar a SPEC-209 por partes: B + G primeiro (só tela), depois A, depois D + E (com migration), depois C e F.
- [ ] Acesso da Débora ao sistema (senha trocada); e-mail de recuperação depende do SMTP da SPEC-205.
