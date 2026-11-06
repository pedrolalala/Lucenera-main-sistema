---
titulo: "SPEC-253 — Previsão de chegada nas vendas, pedido de compra ligado à venda e itens especiais por medida"
status: não iniciado
data_ultima_modificacao: 2026-11-06
sistemas_envolvidos:
  - Compras (04-Sistemas/compras-lucenera-3o23t98ee) — necessidade, pedidos, importação Connect (SPEC-247)
  - Venda Parcial (04-Sistemas/separacao-parcial) — coluna de previsão e janela Transferir
  - Banco (Supabase SP) — pedido_compra_itens, necessidade de compra, vínculo item de pedido ↔ venda
---

# SPEC-253 — Previsão de chegada e itens especiais

> Origem: reunião 06/11 (min. 00–13, 66–75, 138). Relacionadas: SPEC-209 (C3 aviso 10 dias e C4 prazo médio **já feitos**), SPEC-236 (entrega no pedido), SPEC-243 (entrega futura por cliente), SPEC-247 (importar pedido da Connect), SPEC-251.

## Checklist de Ação

- [ ] A. Mostrar, ao lado da peça em **Entrega Futura** da venda (e na janela Transferir da SPEC-251), o **nº do pedido de compra** e a **data prevista de chegada**.
- [ ] B. Quando a compra nasce da necessidade de uma venda (L), gravar o vínculo item do pedido ↔ venda/L; a previsão da venda sai desse vínculo. Peça avulsa: vincular depois, à mão.
- [ ] C. Atualização da previsão: a Débora edita a data prevista do pedido quando o fornecedor avisa atraso (também depois de aprovado); a venda e a janela Transferir passam a mostrar a data nova. Guardar o histórico das datas.
- [ ] D. Regra de atendimento quando um pedido cobre só parte das vendas (ver Pendências).
- [ ] E. **Itens especiais por medida** (ex.: Esteca, Linea, Versa): não importar o pedido da Connect por PDF; montar o pedido **manualmente** no sistema, escolhendo a venda/L de cada quantidade.
- [ ] F. Aviso na importação do PDF (SPEC-247) quando o item for especial por medida.
- [ ] G. Treinar a Débora para importar pedidos normais (feito o teste real na reunião).

### Passos manuais do usuário

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

Nada implementado nesta SPEC. O teste real de importação do PDF (reunião) passou: peças entraram no pedido, apareceram na entrada de NF e saíram da necessidade; o pedido existente é completado, sem duplicar.

## Pendências

- [ ] Definir como identificar item especial por medida (campo no produto, lista, categoria).
- [ ] Confirmar a regra de atendimento (D) quando o pedido cobre parte das vendas.
- [ ] Confirmar se a edição da previsão depois de "Aprovado" já existe no Compras (a conferir no código).
- [ ] Três pedidos ainda sem fornecedor cadastrado (1856, 1976, 1964) — ver SPEC-247.
