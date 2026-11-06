---
titulo: "SPEC-253 — Previsão de chegada nas vendas, pedido de compra ligado à venda e itens especiais por medida"
status: pendente
data_ultima_modificacao: 2026-11-06
sistemas_envolvidos:
  - Compras (04-Sistemas/compras-lucenera-3o23t98ee) — necessidade, pedidos, importação Connect (SPEC-247)
  - Venda Parcial (04-Sistemas/separacao-parcial) — coluna de previsão e janela Transferir
  - Banco (Supabase SP) — pedido_compra_itens, necessidade de compra, vínculo item de pedido ↔ venda
---

# SPEC-253 — Previsão de chegada e itens especiais

> Origem: reunião 06/11 (min. 00–13, 66–75, 138). Relacionadas: SPEC-209 (C3 aviso 10 dias e C4 prazo médio **já feitos**), SPEC-236 (entrega no pedido), SPEC-243 (entrega futura por cliente), SPEC-247 (importar pedido da Connect), SPEC-251.

## Checklist de Ação

- [x] A. Mostrar, ao lado da peça em **Entrega Futura** da venda (e na janela Transferir da SPEC-251), o **nº do pedido de compra** e a **data prevista de chegada** (por PEÇA; ver Realizado).
- [ ] B. Quando a compra nasce da necessidade de uma venda (L), gravar o vínculo item do pedido ↔ venda/L; a previsão da venda sai desse vínculo. Peça avulsa: vincular depois, à mão.
- [x] C. Atualização da previsão: a Débora edita a data prevista do pedido quando o fornecedor avisa atraso (também depois de aprovado); a venda e a janela Transferir passam a mostrar a data nova. Guardar o histórico das datas.
- [ ] D. Regra de atendimento quando um pedido cobre só parte das vendas (ver Pendências).
- [ ] E. **Itens especiais por medida** (ex.: Esteca, Linea, Versa): não importar o pedido da Connect por PDF; montar o pedido **manualmente** no sistema, escolhendo a venda/L de cada quantidade.
- [ ] F. Aviso na importação do PDF (SPEC-247) quando o item for especial por medida.
- [ ] G. Treinar a Débora para importar pedidos normais (feito o teste real na reunião).

### Passos manuais do usuário

- [x] Migrations 292 e 293 APLICADAS e Compras + Venda Parcial publicados (06/11).
- [ ] Débora: importar os pedidos normais da Connect pelo botão do PDF e conferir se saem da Necessidade de Compra.
- [ ] Débora e Vinicius: listar quais produtos são "especiais por medida" (hoje não há marca no cadastro, a conferir).

## Objetivo

Quem vai transferir peça ou conversar com o cliente precisa saber **se tem compra a caminho e quando**, sem ligar para a Débora. E o pedido de compra importado da Connect precisa baixar a necessidade só quando for possível saber de quem é a peça.

## Decisões aprovadas (reunião)

- Pedido de compra normal (sem item especial) importado do PDF liga às peças e **sai da necessidade** (teste real com 4 vendas deu certo).
- Item especial por medida: o pedido de compra não diz de quem é. Fica o pedido **manual** direto no sistema (Vinicius e Pedro). Alternativa descartada por ora: vincular depois.
- A previsão precisa ser **real**: a Débora atualiza quando o fornecedor atrasa.
- Mesmo item em várias vendas: uma pode já estar comprada e outra não; a informação é por venda.

## Definição da SPEC

### Como está (conferido nas SPECs, não no código)

- Aviso de 10 dias antes da chegada e sugestão de prazo médio do fornecedor: **feitos** (SPEC-209 C3/C4).
- Previsão de entrega no pedido existe (SPEC-209 C e SPEC-236); a edição só era livre em "Aguardando aprovar" (D3).
- Falta: a previsão chegar até a **venda** e até a janela Transferir; vínculo pedido ↔ venda para necessidade de cliente.

### Itens especiais (E/F)

- Hoje a necessidade subtrai pedidos em aberto por peça: um pedido de 15 m abate 15 dos 70 m em aberto sem saber quais clientes atende. Para itens por medida isso mascara a necessidade.
- Proposta: marca no cadastro do produto (campo "por medida") e, no PDF importado, a linha desse item **não abate** a necessidade até a Débora ligar às vendas; ou o pedido é criado direto na tela (sem PDF).

### Regra de atendimento (D) — proposta

Ordem de atendimento pela **data da venda** (mais antiga primeiro), podendo a Débora ajustar. A venda mostra "atendida pelo pedido N, previsão dd/mm" ou "sem compra".

## Critérios de aceite

- Venda com item em Entrega Futura e pedido ligado mostra o nº e a data; sem pedido mostra "sem compra".
- Mudar a data do pedido atualiza a venda e a janela Transferir.
- Pedido importado por PDF com item normal baixa a necessidade; item por medida não baixa sem vínculo e mostra aviso.

## Realizado

### 2026-11-06 (A e C — migrations 292 e 293 APLICADAS; Compras e Venda Parcial NO AR)

- **Migration 292 (`20261106_292_spec253_previsao_chegada_produto`)**: view só de leitura `vw_previsao_chegada_produto` (pedido aprovado ou parcialmente recebido com item ainda não recebido por inteiro: peça, nº do pedido, data prevista, quantidade pendente, projeto da solicitação quando houver). `security_invoker`, sem custo nem fornecedor, `REVOKE` de `anon`. Dry-run: 13 linhas/13 peças hoje (todas com data), `anon` barrado, `authenticated` lê.
- **Migration 293 (`20261106_293_spec253_atualizar_previsao_pedido`)**: função `atualizar_previsao_pedido_compra(pedido, data, motivo)` — mesma permissão do "Voltar para edição" (`necessidade-de-compra`/`editar`), só pedido aprovado ou parcialmente recebido, motivo obrigatório, grava a data nova e uma linha na observação ("de dd/mm para dd/mm em …: motivo"); o histórico fica também no log de auditoria do pedido. Dry-run com ROLLBACK: compradora atualiza (30/11 → 10/12); sem motivo, pedido cancelado, projetista sem acesso a Compras e `anon` são recusados.
- **Venda Parcial (commit a41915d, pushado; deploy 0e572112):** ao lado da quantidade em Entrega Futura aparece "Chega dd/mm" (verde), "Pedido sem data" (âmbar) ou "Sem compra" (cinza), com o detalhe dos pedidos no passar do mouse; a janela Transferir mostra "Compra em andamento desta peça" com os pedidos e as datas.
- **Compras (commit 491e35a, pushado; deploy 7d0a949e):** botão **Previsão** nos pedidos aprovados/parcialmente recebidos; janela com a nova data e o motivo obrigatório; não desfaz a aprovação nem mexe no Contas a Pagar.
- `tsc` sem erro novo nos dois; builds ok só com São Paulo.
- **Limite desta versão:** a previsão é por **peça** (quando chega o que está a caminho), não por venda. O vínculo item do pedido ↔ venda existe só para pedidos feitos pela Necessidade de Compra (solicitação com projeto); os 42 pedidos importados da Connect não têm esse vínculo. Por isso o item B e a regra de atendimento (D) ficam pendentes. O teste real de importação do PDF (reunião) passou: peças entraram no pedido, apareceram na entrada de NF e saíram da necessidade; o pedido existente é completado, sem duplicar.

## Pendências

- [ ] Débora: lembrar de preencher a data prevista dos pedidos importados da Connect (os 42 vieram sem data; hoje só 5 pedidos aprovados têm data). A planilha da Connect não traz previsão.
- [ ] Definir como identificar item especial por medida (campo no produto, lista, categoria).
- [ ] Confirmar a regra de atendimento (D) quando o pedido cobre parte das vendas.
- [ ] Confirmar se a edição da previsão depois de "Aprovado" já existe no Compras (a conferir no código).
- [ ] Três pedidos ainda sem fornecedor cadastrado (1856, 1976, 1964) — ver SPEC-247.
