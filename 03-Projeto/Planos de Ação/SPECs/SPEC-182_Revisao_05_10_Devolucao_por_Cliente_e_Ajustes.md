---
titulo: "SPEC-182 — Reunião de revisão 05/10: devolução pelo CÓDIGO DO PROJETO (não por venda), sem 'em separação', sem etapa Recebida, números sem prefixo e ajustes"
status: em andamento (06/10: tudo publicado exceto T1/T2)
data_ultima_modificacao: 2026-10-06
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb) — rotina de devolução/troca, campos de data, botão salvar
  - Separação Parcial (separacao-parcial) — ver conteúdo da parcial, retirar "Devoluções a receber"
  - Logística (lucenera-logistics-b7cd1) — pop-up de separação cancelada para o Matheus
  - Cadastro (cadastro-lucenera-b86fe) — consulta de produtos (busca que some, setores)
  - Vendas (vendas-lucenera) e demais telas que mostram número de venda/orçamento — números sem prefixo
  - Banco central — RPC de devolução por setor, aprovação da devolução, validação de saldo
dependencias:
  - SPEC-178 / SPEC-179 / SPEC-180 / SPEC-181 (rotina de devolução — esta SPEC revê parte delas)
---

# SPEC-182 — Revisão de 05/10 com o Vinícius: devolução pelo código do projeto e ajustes

> Origem: `02-Reunioes/27. Lucenera (Vinicius) - 05.10.2026_ revisão dos ultimos pedidos/Reunião.01`.
> Os horários `[mm:ss]` citam a transcrição (que reinicia o relógio na metade — marcado como "2ª parte").
> Na transcrição, "Slide" = ISLIGHT e "Manuela" = MANOELLA.
> **Esta SPEC é para conferência do usuário — nada implementado ainda.** Vários itens desfazem decisões
> de 02–05/10 (marcados com ⚠️).
>
> **Definição do usuário (05/10, depois da 1ª leitura):** a devolução se liga ao **código do projeto**. Se o projeto
> tem 10 vendas efetivadas, a busca é feita dentro dessas 10; a pessoa digita o **código da peça** no filtro e a peça
> aparece com o setor em que está (Entrega futura, Reserva, Em separação). Peça **em separação aparece, mas não pode
> ser devolvida** — primeiro cancela a separação, depois devolve. E **em toda coluna com número de venda ou de
> orçamento, tirar "VENDA-" / "ORC-" e deixar só o número — em todos os sistemas** (ex.: Separação).

## Checklist de Ação

### Devolução (Orçamentos + banco)
- [x] D1 ⚠️ Trocar o vínculo "uma venda" (SPEC-181) pelo vínculo com o **CÓDIGO DO PROJETO**: a devolução busca dentro de **todas as vendas efetivadas daquele projeto** e pode ter itens de **várias vendas** no mesmo orçamento.
- [x] D2 **Empresa** (definido 05/10): a pessoa escolhe o **código do projeto**. Se todas as vendas efetivadas do
  projeto são da **mesma empresa**, a empresa da devolução já vem preenchida com ela. Se o projeto tem vendas em **mais
  de uma empresa** (ex.: uma na ISLIGHT e outra na FOCO ou na MANOELLA), aparece um **aviso** "este projeto tem vendas
  em mais de uma empresa — escolha em qual empresa foi a venda que você quer devolver" e a pessoa escolhe a empresa.
  A busca de itens mostra **só o que o projeto comprou dessa empresa**.
- [x] D3 Busca pelo **código da peça** no filtro, entre todas as vendas do projeto (o usuário não precisa saber o número da venda).
- [x] D4 Mostrar o número da venda **sem o prefixo** ("0001", não "VENDA-0001") — ver também N1.
- [x] D5 Manter a visualização atual **uma linha por L e por setor**, com o saldo de cada uma (aprovada na reunião).
- [x] D6 ⚠️ A peça **aparece** com o setor em que está (Entrega futura, Reserva, Em separação e Entregue). **"Em separação" / "Aguardando separar" aparece mas NÃO pode ser devolvida**: a linha fica bloqueada com o aviso "cancele a separação antes"; depois de cancelada, a peça volta para Reserva e aí pode ser devolvida (e avisar o Matheus).
- [x] D7 ⚠️ **Entregue pode ser devolvido e não baixa** (confirmado 05/10): o orçamento de devolução de material entregue só é criado **depois que a peça já chegou ao estoque**; ao devolver, a coluna Entregue continua preenchida (histórico de que foi entregue) e só a "Quantidade devolvida" sobe. Exige ajustar a regra de saldo do banco (ver Pontos técnicos).
- [x] D8 ⚠️ **Retirar a etapa "Recebida"** (SPEC-180) — confirmado 05/10: a devolução só é lançada quando a peça já chegou; ao aprovar, o material volta direto ao estoque. **Tirar da Separação Parcial o botão "Devoluções a receber" e a janela "Devoluções aguardando recebimento"**; no banco, Entregue volta a liberar a reserva na aprovação (status `registrada`).
- [x] D9 Valor já com o desconto da venda (já está assim) e **sem mostrar o percentual** do desconto — só o preço que o cliente pagou.
- [x] D10 Quantidade "A Devolver" nunca acima do saldo do setor (já está assim — conferido na reunião).
- [x] D11 Na devolução, **forma de pagamento já vem como "Carteira"** e **Frete não é obrigatório**.
- [x] D12 **Pop-up para o Matheus** quando uma separação é cancelada (por causa de devolução ou estorno): ao abrir o
  sistema de **Logística**, aparece um aviso com as separações canceladas que ele ainda não viu (venda, cliente,
  projeto, motivo, quem cancelou e quando) e um botão "Ciente". Base: a pendência `separacao_estornada` que o banco já
  cria em `entregas_pendentes` quando uma separação é estornada por completo (hoje só aparece na tela Pendentes).

### Números sem prefixo (todos os sistemas)
- [x] N1 Em **toda coluna/campo de tela** que mostra número de venda ou de orçamento, tirar o prefixo e deixar só o número: "VENDA-0001" → "0001", "ORC-0032" → "0032". Vale para **todos os sistemas** — Orçamentos (lista, cabeçalho, devolução, resumo), Vendas, Separação Parcial, Compras/Necessidade de Compra, Logística e impressões. Só exibição: o número gravado no banco não muda e a busca continua aceitando com ou sem prefixo. (A Separação Parcial já mostra a venda sem prefixo desde a SPEC-176.)

### Orçamento (geral)
- [x] O1 Campos de data (emissão, validade, previsão): permitir **digitar a data** além de escolher no calendário.
- [x] O2 Botão "Criar Orçamento" passa a se chamar **"Salvar orçamento"** (pedido do Vinícius, [15:06] 2ª parte).

### Separação Parcial
- [x] S1 Poder **ver o que está em cada parcial** (o que foi expedido / lista de entrega) — uma visualização ou "reimprimir" da parcial, embaixo da separação parcial da venda.
- [x] S2 (dúvida da reunião) Explicar/rever o botão "Estornar" das parciais — o Vinícius não entendeu a que se referia (eram trocas de teste de 11/09).

### Cadastro — consulta de produtos
- [x] C1 **Bug:** ao buscar um produto (ex.: 6654), a pesquisa **some sozinha depois de ~2 segundos**, como se não tivesse sido feita.
- [x] C2 Setores da peça com abas clicáveis, no modelo da tela do **Connect** mostrada na reunião ("Volta lá no Connect"): **Entrega futura, Reserva, Separação e Compras** (sem o "saque" do Connect); "Setores" = resumo geral; ao clicar num setor, abrir uma janela com o detalhe (a confirmar — ver Pontos a confirmar). Hoje o nosso Cadastro não tem "saque".
- [x] C3 (a investigar) Produto 13213/13037 não aparecia na busca da devolução ("tá dando bug") — o Vinícius tinha acabado de reativar o produto. Hoje os dois estão ativos; refazer o teste.

### Testes e dados
- [ ] T1 Criar **vendas de teste grandes** (com o nome do Pedro), zerar os testes e refazer o fluxo completo desde o começo.
- [ ] T2 Decidir o que fazer com a devolução **ORC-0037** aprovada na reunião (6 aros da VENDA-0001: 4 da reserva + 2 que estavam "aguardando separar" — caso que agora deve ser bloqueado).

### Passos manuais do usuário
- [x] Conferir esta SPEC e os Pontos a confirmar antes de qualquer implementação.
- [ ] Banco no Brasil: o Vinícius disse que vai **recriar o banco no servidor brasileiro** ([00:27]) — definir quem faz e quando (ver conversa de 05/10 sobre migração de região).

## Implementação (06/10/2026)

- **Banco** — migration `supabase/db/migrations/20261006_184_devolucao_por_projeto` (dry-run com rollback, depois
  aplicada): coluna `estoque_saldos_projeto_item.q_devolvida_entregue` (Entregue não baixa; devolvível do Entregue =
  `q_entregue − q_devolvida_entregue`), `fn_validar_saldo_projeto_item` sem contar o entregue devolvido duas vezes,
  `registrar_devolucao_projeto_item_setor` recusa `em_separacao`, grava sempre `registrada` e libera a reserva
  (sem etapa Recebida), `aprovar_orcamento_financeiro` confere cada item contra venda efetivada do **mesmo projeto e
  empresa** (não usa mais `venda_origem_id`) e recusa linha "em separação"; a view expõe `q_devolvida_entregue` e
  `empresa_id`. Teste no dry-run: em separação recusado; 2 entregues devolvidos → Entregue fica 2, devolvida 2;
  3ª devolução recusada; saldo do item fecha 5/5.
- **Orçamentos** (Skip 32554 v0.0.382): devolução pelo projeto (janela "Vincular venda" removida); aviso quando o
  projeto tem vendas em mais de uma empresa e a lista de empresas fica só com as do projeto; busca por projeto +
  empresa com linha "Em separação" bloqueada ("Cancele a separação antes"); preço líquido sem %; venda sem prefixo;
  Carteira já marcada e frete opcional na devolução; datas digitáveis (dd/mm/aaaa) com calendário; botão
  "Salvar orçamento"; números sem prefixo nas listas, cabeçalho e diálogos.
- **Separação Parcial** (48801 v0.0.47): sem "Devoluções a receber"; "Ver itens" em cada parcial com
  "Reimprimir"; texto explicando "Estornar".
- **Logística** (24039 v0.0.98): pop-up "Separação cancelada" ao abrir o sistema (todos os usuários menos
  entregador; "Ciente" guarda no navegador; a pendência continua em Pendentes); números sem prefixo no cartão de
  separação e nas pendências. Ao aplicar, o Skip rodou as 2 migrations legadas da Logística: `seed_admin_user`
  falhou sem efeito (tabela `user_roles` não existe) e `fix_foreign_key_entregas_finalizadas` registrou sem mudar
  nada (PKs/FK já existiam, 0 órfãs). Retirá-las do Skip foi bloqueado pela permissão automática.
- **Separação Parcial, ajuste de 06/10** (48801 v0.0.48, pedido do usuário): janela "Ver itens" maior com dados da
  venda (número, empresa, cliente, projeto, vendedor, endereço, telefone) e da parcial (data, funcionário, previsão,
  totais), colunas Referência e Descrição separadas; impressão com colunas **L · Cód. · Ref. · Descrição · Quant.**,
  descrição em letra menor quebrando linha (não corta mais), itens em ordem de L (reunião [08:48]) e de volta a
  declaração "Assumo total responsabilidade pelas mercadorias correspondentes a esta entrega, bem como declaro correto
  o conteúdo e as quantidades mencionadas acima" (reunião [08:02], texto da SPEC-144). Reimpressão usa a previsão de
  entrega da venda. Endereço de entrega próprio (reunião [08:30]) continua pendente.
- **Vendas** (59346 v0.0.15) e **Compras** (40326 v0.0.80): números sem prefixo.
- **Cadastro** (36668 v0.0.93): C1 corrigido — a carga inicial de todas as peças (em lotes) terminava depois da
  busca e sobrescrevia o resultado; agora só a carga mais recente grava.
- **C3**: 13213 e 13037 nunca foram vendidos (nenhum orçamento/venda) — por isso não aparecem na busca de
  devolução, que só lista o que foi vendido. Não é bug.
- **C2** (Cadastro 36668 v0.0.94 + migration `20261006_185_cadastro_peca_abas_setores`), decisões do usuário 06/10:
  a peça abre numa **área larga abaixo da lista** (fim do card lateral); cabeçalho Código/Referência/Descrição/Valor
  de venda/**Disponível** (geral − reservado, vermelho se negativo); abas **Setores** (consolidado, setor clicável abre
  a aba dele; inclui Entregue = entregue − devolvido) · **Reserva · Entrega Futura · Separação · Entregue** (mesmas
  colunas: Orçamento, Venda, Funcionário, Cliente, Projeto, L, Qtd, Data Orçamento, Data da Entrega, **Valor total
  do orçamento**; Entregue só leitura) · **Compras** (pedidos ativos: Pedido, Qtd pendente, Data Emissão, Data
  Entrega, Empresa, Perfil). View nova `vw_cadastro_produto_movimentos`; `vw_necessidade_compra_pedido_detalhe`
  ganhou `data_emissao` e `perfil`. Arquivos: `src/pages/Pecas.tsx`, `src/components/pecas/PecaDetailsPanel.tsx`,
  `src/components/pecas/PecaAbasSetores.tsx` (novo), `src/services/produtos.ts`.
- **Fora desta rodada**: T1/T2 (dados de
  teste — aguardam decisão do ponto 7 e da ORC-0037), PDF do orçamento gerado pela Edge Function (número continua
  com prefixo; mexer na função exige publicação controlada).

## Objetivo

Ajustar a rotina de devolução ao jeito que a equipe trabalha no dia a dia: a pessoa sabe o **projeto** e a **peça**,
não o número da venda. O sistema mostra onde a peça está (venda, L e setor) e a devolução sai pelo setor certo.
Mais alguns ajustes de usabilidade no Orçamento, Separação Parcial e Cadastro pedidos na mesma reunião.

## O que o Vinícius pediu — com a fala de origem

**D1 — vincular pelo cliente, não pela venda** — [08:24], [10:31], [07:40 2ª parte], [10:34 2ª parte]
> "Elas não vão buscar de qual venda... só vão ver em qual empresa foi vendida" / "Em vez de vincular com a venda,
> eu vou vincular com o cliente. Aí... tudo que for vendido por aquele cliente vai aparecer aqui."
> Exemplo: devolver 10 de um item, 5 numa venda e 5 em outra, no **mesmo** orçamento ([00:01 2ª parte]).
> Recap: "não vincular com a venda em específico e sim com o cliente" ([10:34 2ª parte]).

**D2 — empresa certa** — [02:03], [04:06]
> "Tem que ser sempre na empresa correta, na empresa que fez a venda." / "Se eu não mudar a empresa aqui, ele pode
> até deixar seguir, só que ele não pode me mostrar a peça porque não vendi na Manuela."

**D3/D4 — busca por código e número sem prefixo** — [07:40 2ª parte], [09:01 2ª parte]
> "Ela colocou aqui em cima 6654, ele vai filtrar tudo que já foi vendido para esse cliente." / "Só deixa o 001".

**D5 — linha por L e setor** — [13:45], [08:38 2ª parte], [09:58 2ª parte]
> "Ele separou [por setor] e duplicou" — "Eu acho que isso daqui eu gosto".

**D6 — em separação não devolve** — [05:59 2ª parte], [09:17 2ª parte], [21:42 2ª parte], [21:53 2ª parte]
> "Se precisa devolver um material que tá em separação, aquela parcial precisa ser cancelada" / "tem que cancelar a
> lista de entrega, o pedido de separação, faz a devolução, e aí depois avisa o Matheus" / "se tiver no setor
> aguardando separar, não pode deixar fazer a devolução".

**D7 — entregue continua preenchido** — [01:51 2ª parte]
> "O entregue permanece... a quantidade devolvida vai estar com 15... se tem alguma devolução de algo entregue, ele
> não mexe, ele fica lá preenchido para a gente saber que em algum momento aquilo foi entregue, só que voltou."

**D8 — sem etapa Recebida** — [23:50 2ª parte] a [24:31 2ª parte]
> "A gente nem faz a devolução se não tiver o material." / "Se o material foi entregue e ainda está na obra, não pode
> passar a devolução, porque é automático, fez a devolução, o material já volta para o estoque." → "essa função aí a
> gente pode tirar".

**D9 — desconto sem percentual** — [13:49]
> "Já vem com o desconto. Não precisa trazer a porcentagem... tem que vir já no preço que ele pagou."

**D11 — carteira e frete** — [15:32 2ª parte], [17:28 2ª parte]
> "A frete, isso aqui tem que deixar para não deixar obrigatório" / Pedro: "quando for devolução, já vou deixar
> pré-programado para ser carteira".

**O1/O2** — [15:32 2ª parte] "Aqui não tem como tipo para poder digitar?" (data) / [15:06 2ª parte] "eu colocaria
salvar orçamento".

**S1** — [20:00]–[20:48 2ª parte] "tem que deixar ver o que que tá na parcial... abriu uma visualização do que que foi
expedido... reimprimir, eu consigo ver o que que tava naquela parcial."

**C1** — [25:32]–[25:59 2ª parte] "quando você clica em cima do produto que você colocou a informação no buscar, ele
some" / "2 segundos... apaga a pesquisa".

**C2** — [29:20]–[29:58 2ª parte] "tira esse saque" / "pode deixar só entrega futura, reserva e separação, e o compras"
/ "setores é o resumo" / "clicar e conseguir me chamar numa outra janela".

## Decisões aprovadas na reunião

- A devolução se vincula ao **código do projeto** (definição do usuário, 05/10 — na reunião se falou em cliente/projeto);
  a busca roda em todas as vendas efetivadas do projeto; dentro dele, só aparecem peças vendidas pela **empresa** do
  orçamento.
- A peça aparece com o setor; **em separação aparece bloqueada** (cancelar a separação antes de devolver).
- Números de venda e orçamento **sem prefixo** em todas as telas de todos os sistemas.
- **Entregue** continua preenchido depois da devolução (histórico); a devolvida sobe.
- **Sem** etapa "Recebida" — devolução só é lançada com o material em mãos.
- Visualização por L e setor, preço líquido sem mostrar o percentual.

## Pontos técnicos (o que muda no que já existe)

- **D1 desfaz parte da SPEC-181**: `orcamentos.venda_origem_id` e a regra "uma venda" deixam de valer. O orçamento
  já tem `projeto_id`: ao escolher Devolução, o campo obrigatório passa a ser o **Código do Projeto** (em vez da janela
  "Vincular venda de origem"); a busca de itens filtra `vw_estoque_saldos_projeto_item` pelo projeto + empresa; a
  aprovação passa a conferir que cada item é de venda **do mesmo projeto e da mesma empresa** da devolução.
  A coluna `venda_origem_id` pode ficar sem uso (ou ser removida em migration).
- **D6 desfaz parte da SPEC-179**: o setor "Em separação" continua aparecendo na busca, mas **sem campo "A Devolver"**
  (linha bloqueada com o aviso), e a RPC `registrar_devolucao_projeto_item_setor` passa a recusar `em_separacao`.
  A correção dos triggers da separação (quantidade estornada) continua valendo.
- **N1**: hoje cada tela monta o texto do número; o jeito mais seguro é uma função única "sem prefixo" por sistema
  (a Separação Parcial já tem `semPrefixo`). Levantar todas as telas com `numero_venda`/`numero` antes de mexer.
- **D7 conflita com a regra de saldo do banco**: hoje `fn_validar_saldo_projeto_item` exige
  `reserva + EF + a separar + separado + entregue + devolvida <= vendido`. Se Entregue não baixar e a Devolvida subir,
  a soma estoura. Opção: a regra passar a contar `entregue` como histórico e o saldo devolvível do entregue ser
  `entregue − devolvido_do_entregue` (precisa de um contador do que já foi devolvido do entregue, ou somar em
  `devolucoes_estoque.qtd_de_entregue`). Precisa de migration com dry-run.
- **D8 desfaz parte da SPEC-180**: tirar o status `aguardando_recebimento`, o botão/tela da Separação Parcial e voltar a
  liberar a reserva na aprovação também para Entregue. Hoje não há nenhuma devolução aguardando recebimento.
- **Log de Trocas em branco** (citado em [22:53 2ª parte]): não é bug — as 2 trocas de teste foram apagadas a pedido
  do usuário em 03/10 (SPEC-180, migration `20261003_180`).
- **Devolução ORC-0037** (aprovada na reunião, 05/10 20:19): registrou 4 da reserva + 2 "em separação" — exatamente
  o caso que D6 passa a bloquear (T2).

## Pontos a confirmar (antes de implementar)

1. ~~D1 — vincular por quê?~~ **Fechado (05/10): código do projeto.**
2. ~~D2 — empresa escolhida ou do 1º item?~~ **Fechado (05/10):** vem do projeto; com vendas em mais de uma empresa,
   aviso e a pessoa escolhe.
3. ~~D6 — bloquear ou cancelar dali?~~ **Fechado (05/10): aparece bloqueada; cancela a separação antes.**
   ~~Aviso ao Matheus?~~ **Fechado (05/10): pop-up** (D12). Falta só confirmar: o pop-up fica na **Logística** (onde o
   Matheus vê as pendências) e aparece para todos de lá ou só para ele? Cancelamento **parcial** da separação (só
   alguns itens) também avisa, ou só quando a separação inteira é cancelada?
4. ~~D6/D7 — Entregue devolvível?~~ **Fechado (05/10):** sim; a devolução só é criada com a peça já no estoque;
   Entregue não diminui, só a devolvida sobe; sem etapa "Recebida".
5. **C2** — As abas de setor entram na consulta de produtos do **Cadastro** (que já mostra os 8 setores na vertical,
   SPEC-174 N6c)? A janela ao clicar num setor mostra o quê — clientes/projetos/vendas com a peça naquele setor?
6. **S1** — A visualização da parcial pode ser o mesmo documento da impressão "Pedido em Separação" (reimprimir)?
7. **T1** — Quantas vendas de teste e de que tamanho? Pode apagar as devoluções/separações de teste atuais?
8. **Banco no Brasil** — quem faz a migração (o Vinícius disse que ia fazer) e em que data.
