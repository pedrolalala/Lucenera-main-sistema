---
titulo: "SPEC-222 — Teste da entrada de nota (reunião Vinicius 22/10): estoque físico não sobe na entrada (-4 continuou -4) + ajustes de Compras, Entrada de NF, espelho, cancelamento e Separação Parcial"
status: pendente
data_ultima_modificacao: 2026-10-22
sistemas_envolvidos:
  - Necessidade de Compra (compras-lucenera-3o23t98ee) — Necessidade, Pedido de Compra, Entrada de Nota Fiscal, Marcas/Fornecedores
  - Separação Parcial (separacao-parcial) — troca de reserva entre L do mesmo cliente
  - Cadastro / Consulta de Produtos — estoque, reserva, compras em andamento
  - Banco — estoque_itens, RPCs de entrada/cancelamento da SPEC-220 (migration 233)
---

# SPEC-222 — Teste da entrada de nota com o Vinicius e a Débora (22/10)

> Origem: `02-Reunioes/35. Lucenera (Vinicius) - 22.10.2026_ Reuniões gerais/Reunião.04 (importante)`.
> O Vinicius testou, com a Débora, o fluxo inteiro feito nas SPECs 209/214/215/218/220: necessidade → pedido →
> enviar ao fornecedor → entrada da nota com vínculo ao cliente → espelho → cancelamento da entrada.
> Pedido do usuário (22/10): "se atente na questão de quantidade de peça em estoque que não alterou quando foi pedido
> 10 peças e tinha -4 em estoque, deveria ter ficado 6 mas continuou -4 — mas o fluxo funcionou na teoria".
>
> **Resultado geral do teste:** o fluxo funcionou. Entrega futura → reserva, limitador do vínculo ("vínculo 4 de 10,
> 6 ficam livres"), peça não vinculada voltou para a necessidade da Cristiane, cancelar a entrada voltou tudo para
> entrega futura. O que falhou: **o estoque físico não subiu** (seção A) e uma série de ajustes de tela.
> A SPEC-221 (regra da necessidade por data da venda) fica **em standby**: primeiro ver a estrutura de reserva em uso.

## A. Estoque físico não sobe na entrada — PRINCIPAL

### O que aconteceu no teste ([69:05]–[83:26])
Peça **12728 — FITA ALL LIGHT 12V EVO 7W IP20 AMBAR**. Antes: estoque 19, disponível **-4** (a VENDA-0001 / projeto
26.209 tem 2 L de 2 peças em entrega futura). Pedido de compra de **10**, entrada da nota, vínculo de 4 (2+2) nos L.
Esperado: estoque geral **29**, disponível **6**. Resultado: os L foram para a reserva (certo), mas o estoque
continuou **19** e o disponível **-4**.

### Causa (conferida no banco em 22/10)
- O disponível da Consulta/Cadastro vem de `vw_detalhe_produto_estoque` = `estoque_itens.quantidade −
  quantidade_reservada`. Para a 12728: `quantidade` = **19** (vindo da Connect, último ajuste 19/10) e
  `quantidade_reservada` = **23** (19 de herança da Connect + 4 que a aprovação do orçamento somou em 19/10:
  auditoria 19→21→23). Logo 19 − 23 = **-4**.
- A entrada (migration 233, SPEC-220) foi feita, por decisão de 22/10, para mexer **só no saldo dos L**
  (`estoque_saldos_projeto_item`: entrega futura → reserva) e **não tocar o estoque físico** (`estoque_itens` /
  `produtos.estoque_*`), porque o estoque ainda vinha da Connect. Por isso nada entrou no Estoque Geral.
  O item **E1 da SPEC-220** ("toda entrada entra no setor Estoque Geral") ficou marcado como feito, mas na prática
  só a tela diz isso — nenhuma quantidade é somada.
- Conta certa com a correção: `quantidade` 19 + 10 = 29; `quantidade_reservada` continua 23 (os 4 já tinham sido
  reservados na aprovação; o vínculo só muda o estado do L) → disponível **6**. Bate com o que o Vinicius esperava.

### Checklist
- [ ] A1. Ao registrar a entrada: somar a quantidade que chegou de cada peça em `estoque_itens.quantidade` no local
      **Estoque (Estoque Geral)** + movimento/auditoria com origem = nota. Vale para a parte vinculada e a livre
- [ ] A2. Cancelar a entrada (SPEC-218): subtrair de volta a mesma quantidade (bloquear se a peça já saiu — ex.: já
      separada/entregue — e explicar o motivo)
- [ ] A3. Conferir `quantidade_reservada`: o vínculo **não** soma reserva de novo (já foi somada na aprovação); peça
      livre não mexe em reserva. Documentar a regra em `AI_DB_CONTEXT.md`
- [ ] A4. Proteger contra a importação da Connect sobrescrever o que a entrada somou (`fn_sync_estoque_itens_from_produtos`
      copia `produtos.estoque_*` → `estoque_itens`). Ver Ponto 1
- [ ] A5. Teste com a mesma peça (12728) ou outra só de venda: anotar estoque/reserva/disponível antes, comprar 10 para
      -4, conferir 29/6; cancelar e conferir que volta para 19/-4
- [ ] A6. Reserva de **herança** (os 19 reservados sem histórico): hoje aparece no cadastro sem dono. Fica para a
      importação dos relatórios (vem amarrada ao cliente) — só registrar, não mexer agora

## B. Entrada de Nota Fiscal — tela

- [ ] B1. Tirar o bloco "Para quem" com os nomes; ficar só um botão **"Escolher cliente"** por peça, ao lado do total da
      linha (abre a escolha das vendas/L em entrega futura). Não poluir com nomes
- [ ] B2. Tirar das colunas da peça o **IPI por unidade** (e ST/outras): esses valores só no **Resumo financeiro**
- [ ] B3. Tirar o campo **"Valor total da nota"** digitado: o total vem da soma dos itens + impostos − desconto + despesas
- [ ] B4. Tirar a linha **"Diferença para nota"**
- [ ] B5. Cabeçalho: nº da nota + data de emissão + data da entrega + data da entrada **na mesma linha**; chave de
      acesso na segunda linha, à esquerda
- [ ] B6. **Desconto** e **despesas acessórias** preenchidos no Resumo financeiro (em **reais**), não em cima
- [ ] B7. Tudo editável, exceto **Valor total dos produtos** (= soma de quantidade × valor unitário)
- [ ] B8. **Bug:** com desconto a entrada não deixou registrar ([15:00]–[19:27]: nota de 1.200, desconto aplicado,
      total R$ 774, travou na diferença). Reproduzir e corrigir — desconto tem que reduzir o total e liberar o registro
- [ ] B9. Pagamento antecipado: com 2+ antecipações do mesmo fornecedor, escolher qual vincular (já existe, SPEC-215);
      **"limpar" está limpando tudo** — limpar só a escolhida
- [ ] B10. Anexo da nota (PDF/foto do documento) — fica só como registro da entrada, não vai para o financeiro (confirmar
      que já está assim)

## C. Espelho da entrada (Mateus)

- [ ] C1. **Bug:** cada peça aparece **triplicada** (repete por parcela — junção errada). Uma linha por peça
- [ ] C2. Números sem sentido na coluna de vínculo (ex.: "4", "30, 30, 30", "1 e 1" — [27:04]–[28:47]). Mostrar por peça:
      **quantidade total que entrou** + embaixo os **L e para quem** (cliente/venda) com a quantidade de cada + o que
      ficou livre no estoque
- [ ] C3. Valor pode continuar no espelho

## D. Cancelar a entrada → pedido volta "Aguardando aprovar"

- [ ] D1. Hoje o cancelamento devolve o pedido como **aprovado** (`cancelar_entrada_nota_compra`). Decisão na reunião:
      volta como **`aguardando_aprovar`**, com o pedido original, para **editar** (tirar/ajustar item, desconto) ou
      **cancelar**. Assim não precisa refazer um pedido de 40 itens por causa de um erro
- [ ] D2. Pedido **aprovado** com quantidade errada (antes de qualquer entrada): hoje só dá para cancelar. Permitir
      **voltar para "aguardando aprovar"** e editar (some do Contas a Pagar até aprovar de novo)

## E. Separação Parcial — trocar reserva entre L do mesmo cliente

- [ ] E1. Hoje a troca só é entre clientes diferentes. Permitir trocar a reserva **entre L da mesma venda/cliente**
      (ex.: tirar do L6, que não vai sair agora, para o L26 que precisa ser entregue). Registrar a troca; o L que ficou
      sem vira entrega futura e **volta para a necessidade** (mesma regra da troca entre clientes)

## F. Necessidade de Compra / Pedido de Compra

- [ ] F1. **Pedido de compra avulso**: a aba **"Estoque"** passa a se chamar **"Pedido de compra"** e serve para montar
      pedido **sem necessidade** (qualquer produto do cadastro, ex.: o fornecedor ofereceu 50% para fechar R$ 10 mil;
      caixa fechada). Mesmo carrinho da necessidade, com desconto %. Hoje a necessidade só lista peças negativas e não
      deixa escolher outras (ex.: código 1003)
- [ ] F2. Tirar a aba **"Cotação"** (repetida; desconto fica na necessidade e no pedido avulso)
- [ ] F3. Tirar o card de **custo de estoque** da necessidade (número não bate com nada). Se ficar algum número, só o da
      necessidade de compra (déficit)
- [ ] F4. **Fechar pedido**: mostrar **uma linha por peça** com a soma (sem L) — a lista por L, com quantidade e escolha
      de L, fica na Necessidade. Motivo: 10–15 dias sem comprar de um fornecedor viram uma lista gigante para conferir
- [ ] F5. No fechamento, poder **alterar a quantidade** da linha (ver Ponto 3: só para menos ou também para mais —
      caixa fechada)
- [ ] F6. **Desconto %** preenchido no próprio fechamento (campo de cima, mais intuitivo). Cálculo atual está certo
      (desconto no unitário e depois os impostos dá o mesmo resultado — conferido na reunião)
- [ ] F7. Total do fechamento discriminado: produtos, **IPI, ST e outras despesas separados** (não só o total com
      impostos) — na tela e na impressão
- [ ] F8. **Condição de pagamento obrigatória** para fechar/aprovar (hoje aprovou "sem parcela, sem condição de
      pagamento" e não entrou no Contas a Pagar, e depois de aprovado não dá para editar)
- [ ] F9. Condição de pagamento com opção **À vista / pagamento antecipado já pago**: quando a Lana/Carol já lançou o
      pagamento no Contas a Pagar antes do material chegar, o pedido **não** pode gerar outra saída (duplicidade no
      fluxo). Amarrar com o pagamento antecipado da SPEC-215
- [ ] F10. Previsão de entrega continua opcional, mas incentivar (base para o tempo médio de entrega por fornecedor)

## G. Enviar ao fornecedor (SPEC-214)

- [ ] G1. **Cópias fixas**: além do e-mail do fornecedor, um campo de cópias sempre usadas (quando a Débora manda:
      comercial, Ronaldo e o Vinicius; quando o Vinicius manda, o inverso). Ver Ponto 4
- [ ] G2. Editar os e-mails do fornecedor também na tela de **Marcas** (botão ao lado da marca: vincular fornecedor à
      marca — uma marca pode ter mais de um —, adicionar/trocar e-mail, desativar o antigo). Lista em ordem alfabética
- [ ] G3. O .eml abriu no **Outlook novo** e não no clássico (dois Outlook no computador — provável atualização do
      Windows 11). Investigar o programa padrão para .eml; a assinatura vem do Outlook certo

## H. Consulta / Cadastro de Produtos

- [ ] H1. **Compras em andamento** da peça: mostrar unificado por pedido — nº do pedido, quantidade, data de emissão e
      data prevista de entrega (sem cliente)
- [ ] H2. Tirar o número de **reserva** solto do rodapé do cadastro (ex.: 12822 mostrava "reserva 3" sem origem) ou
      mostrar de onde vem

## Passos manuais do usuário
- [ ] Débora monta mais pedidos de compra e testa "com outro olho"; Vinicius faz vendas e devoluções para testar
- [ ] Antes de cada teste, **anotar estoque/reserva/disponível da peça** (no teste de 22/10 não foi anotado)
- [ ] Segunda-feira: Débora reserva uma hora para mexer no cadastro de produto

## Pontos para confirmar (com recomendação)

1. **Estoque físico no nosso sistema × Connect** (seção A). Hoje a Connect ainda é importada (último estoque de 14/10;
   o Vinicius parou de atualizar). Se a entrada somar no `estoque_itens` e uma importação da Connect rodar depois, a
   entrada é perdida ou contada em dobro. Recomendação: **a entrada passa a somar no estoque** (é o que o teste
   espera) e **a importação de estoque da Connect fica suspensa** para as peças com movimento no sistema novo — ou
   de vez, já que o trabalho em paralelo foi considerado inviável na reunião ("é muito difícil trabalhar em paralelo").
2. **Cancelar entrada** (D1): o Vinicius e o Pedro chegaram em "volta como aguardando aprovar, com opção de editar ou
   cancelar". Recomendação: **sim**.
3. **Alterar quantidade no fechamento** (F5): na reunião ficou "só para menos aqui; para mais na necessidade (caixa
   fechada)". Recomendação: **para menos e para mais** no fechamento — o pedido avulso/caixa fechada é justamente
   comprar a mais.
4. **Cópias fixas** (G1): por usuário (quem envia) ou por empresa? Recomendação: **por usuário** (cada um cadastra
   suas cópias padrão), editável no envio.

## Rollback
- A1/A2: desfazer = RPCs da 233 de volta (rollback da migration nova) + ajuste manual de `estoque_itens` das notas
  registradas no intervalo (listar pelos movimentos com origem = nota).
- Telas: reverter o commit do Compras / Separação Parcial.

## Realizado

(vazio)
