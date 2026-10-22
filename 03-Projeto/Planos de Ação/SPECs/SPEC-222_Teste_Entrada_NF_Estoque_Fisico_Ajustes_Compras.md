---
titulo: "SPEC-222 — Teste da entrada de nota (reunião Vinicius 22/10): estoque físico não sobe na entrada (-4 continuou -4) + ajustes de Compras, Entrada de NF, espelho, cancelamento e Separação Parcial"
status: implementada (falta o teste do Vinicius/Débora)
data_ultima_modificacao: 2026-10-22
sistemas_envolvidos:
  - Necessidade de Compra (compras-lucenera-3o23t98ee) — Necessidade, Pedido de Compra, Entrada de Nota Fiscal, Marcas/Fornecedores
  - Separação Parcial (separacao-parcial) — troca de reserva entre L do mesmo cliente
  - Cadastro / Consulta de Produtos — estoque, reserva, compras em andamento
  - Banco — estoque_itens, RPCs de entrada/cancelamento da SPEC-220 (migrations 234 e 235)
  - scripts/importar_produtos_estoque.py — estoque da Connect suspenso (A4)
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
- [x] A1. Ao registrar a entrada: somar a quantidade que chegou de cada peça em `estoque_itens.quantidade` no local
      **Estoque (Estoque Geral)** + movimento/auditoria com origem = nota. Vale para a parte vinculada e a livre
- [x] A2. Cancelar a entrada (SPEC-218): subtrair de volta a mesma quantidade (bloquear se a peça já saiu — ex.: já
      separada/entregue — e explicar o motivo)
- [x] A3. Conferir `quantidade_reservada`: o vínculo **não** soma reserva de novo (já foi somada na aprovação); peça
      livre não mexe em reserva. Documentar a regra em `AI_DB_CONTEXT.md`
- [x] A4. Proteger contra a importação da Connect sobrescrever o que a entrada somou (`fn_sync_estoque_itens_from_produtos`
      copia `produtos.estoque_*` → `estoque_itens`). Ver Ponto 1
- [ ] A5. Teste com a mesma peça (12728) ou outra só de venda: anotar estoque/reserva/disponível antes, comprar 10 para
      -4, conferir 29/6; cancelar e conferir que volta para 19/-4
- [x] A6. Reserva de **herança** (os 19 reservados sem histórico): hoje aparece no cadastro sem dono. Fica para a
      importação dos relatórios (vem amarrada ao cliente) — só registrar, não mexer agora

## B. Entrada de Nota Fiscal — tela

- [x] B1. Tirar o bloco "Para quem" com os nomes; ficar só um botão **"Escolher cliente"** por peça, ao lado do total da
      linha (abre a escolha das vendas/L em entrega futura). Não poluir com nomes
- [x] B2. Tirar das colunas da peça o **IPI por unidade** (e ST/outras): esses valores só no **Resumo financeiro**
- [x] B3. Tirar o campo **"Valor total da nota"** digitado: o total vem da soma dos itens + impostos − desconto + despesas
- [x] B4. Tirar a linha **"Diferença para nota"**
- [x] B5. Cabeçalho: nº da nota + data de emissão + data da entrega + data da entrada **na mesma linha**; chave de
      acesso na segunda linha, à esquerda
- [x] B6. **Desconto** e **despesas acessórias** preenchidos no Resumo financeiro (em **reais**), não em cima
- [x] B7. Tudo editável, exceto **Valor total dos produtos** (= soma de quantidade × valor unitário)
- [x] B8. **Bug:** com desconto a entrada não deixou registrar ([15:00]–[19:27]: nota de 1.200, desconto aplicado,
      total R$ 774, travou na diferença). Reproduzir e corrigir — desconto tem que reduzir o total e liberar o registro
- [ ] B9. Pagamento antecipado: com 2+ antecipações do mesmo fornecedor, escolher qual vincular (já existe, SPEC-215);
      **"limpar" está limpando tudo** — limpar só a escolhida
- [x] B10. Anexo da nota (PDF/foto do documento) — fica só como registro da entrada, não vai para o financeiro (confirmar
      que já está assim)

## C. Espelho da entrada (Mateus)

- [x] C1. **Bug:** cada peça aparece **triplicada** (repete por parcela — junção errada). Uma linha por peça
- [x] C2. Números sem sentido na coluna de vínculo (ex.: "4", "30, 30, 30", "1 e 1" — [27:04]–[28:47]). Mostrar por peça:
      **quantidade total que entrou** + embaixo os **L e para quem** (cliente/venda) com a quantidade de cada + o que
      ficou livre no estoque
- [x] C3. Valor pode continuar no espelho

## D. Cancelar a entrada → pedido volta "Aguardando aprovar"

- [x] D1. Hoje o cancelamento devolve o pedido como **aprovado** (`cancelar_entrada_nota_compra`). Decisão na reunião:
      volta como **`aguardando_aprovar`**, com o pedido original, para **editar** (tirar/ajustar item, desconto) ou
      **cancelar**. Assim não precisa refazer um pedido de 40 itens por causa de um erro
- [x] D2. Pedido **aprovado** com quantidade errada (antes de qualquer entrada): hoje só dá para cancelar. Permitir
      **voltar para "aguardando aprovar"** e editar (some do Contas a Pagar até aprovar de novo)

## E. Separação Parcial — trocar reserva entre L do mesmo cliente

- [x] E1. Hoje a troca só é entre clientes diferentes. Permitir trocar a reserva **entre L da mesma venda/cliente**
      (ex.: tirar do L6, que não vai sair agora, para o L26 que precisa ser entregue). Registrar a troca; o L que ficou
      sem vira entrega futura e **volta para a necessidade** (mesma regra da troca entre clientes)

## F. Necessidade de Compra / Pedido de Compra

- [x] F1. **Pedido de compra avulso**: a aba **"Estoque"** passa a se chamar **"Pedido de compra"** e serve para montar
      pedido **sem necessidade** (qualquer produto do cadastro, ex.: o fornecedor ofereceu 50% para fechar R$ 10 mil;
      caixa fechada). Mesmo carrinho da necessidade, com desconto %. Hoje a necessidade só lista peças negativas e não
      deixa escolher outras (ex.: código 1003)
- [x] F2. Tirar a aba **"Cotação"** (repetida; desconto fica na necessidade e no pedido avulso)
- [x] F3. Tirar o card de **custo de estoque** da necessidade (número não bate com nada). Se ficar algum número, só o da
      necessidade de compra (déficit)
- [x] F4. **Fechar pedido**: mostrar **uma linha por peça** com a soma (sem L) — a lista por L, com quantidade e escolha
      de L, fica na Necessidade. Motivo: 10–15 dias sem comprar de um fornecedor viram uma lista gigante para conferir
- [x] F5. No fechamento, poder **alterar a quantidade** da linha (ver Ponto 3: só para menos ou também para mais —
      caixa fechada)
- [x] F6. **Desconto %** preenchido no próprio fechamento (campo de cima, mais intuitivo). Cálculo atual está certo
      (desconto no unitário e depois os impostos dá o mesmo resultado — conferido na reunião)
- [x] F7. Total do fechamento discriminado: produtos, **IPI, ST e outras despesas separados** (não só o total com
      impostos) — na tela e na impressão
- [x] F8. **Condição de pagamento obrigatória** para fechar/aprovar (hoje aprovou "sem parcela, sem condição de
      pagamento" e não entrou no Contas a Pagar, e depois de aprovado não dá para editar)
- [x] F9. Condição de pagamento com opção **À vista / pagamento antecipado já pago**: quando a Lana/Carol já lançou o
      pagamento no Contas a Pagar antes do material chegar, o pedido **não** pode gerar outra saída (duplicidade no
      fluxo). Amarrar com o pagamento antecipado da SPEC-215
- [x] F10. Previsão de entrega continua opcional, mas incentivar (base para o tempo médio de entrega por fornecedor)

## G. Enviar ao fornecedor (SPEC-214)

- [x] G1. **Cópias fixas**: além do e-mail do fornecedor, um campo de cópias sempre usadas (quando a Débora manda:
      comercial, Ronaldo e o Vinicius; quando o Vinicius manda, o inverso). Ver Ponto 4
- [x] G2. Editar os e-mails do fornecedor também na tela de **Marcas** (botão ao lado da marca: vincular fornecedor à
      marca — uma marca pode ter mais de um —, adicionar/trocar e-mail, desativar o antigo). Lista em ordem alfabética
- [ ] G3. O .eml abriu no **Outlook novo** e não no clássico (dois Outlook no computador — provável atualização do
      Windows 11). Investigar o programa padrão para .eml; a assinatura vem do Outlook certo

## H. Consulta / Cadastro de Produtos

- [x] H1. **Compras em andamento** da peça: mostrar unificado por pedido — nº do pedido, quantidade, data de emissão e
      data prevista de entrega (sem cliente)
- [x] H2. Tirar o número de **reserva** solto do rodapé do cadastro (ex.: 12822 mostrava "reserva 3" sem origem) ou
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

### 2026-10-22 — Seção A (estoque físico na entrada)
- Pedido do usuário: "pode seguir com a correção do estoque".
- Migration `supabase/db/migrations/20261022_234_spec222_entrada_nf_soma_estoque/` (`001_entrada_nf_soma_estoque.sql` +
  `rollback.sql`) **APLICADA** no SP:
  - coluna `notas_fiscais_compra.estoque_somado_em`;
  - `registrar_entrada_nota_compra`: soma o que chegou de cada peça em `estoque_itens.quantidade` (local `Estoque`),
    devolve `estoque_somado`;
  - `cancelar_entrada_nota_compra`: subtrai o que a nota somou (só se `estoque_somado_em` preenchido); bloqueia se o
    estoque da peça já for menor que o que a nota deu entrada; devolve `estoque_retirado`;
  - acerto da única nota ativa (NF 221025, pedido 1786): peça 12728 foi de 19 / reservado 23 / disponível **-4** para
    **29 / 23 / 6** (o que o Vinicius esperava).
- Dry-run em ROLLBACK: acerto (29/23/6), cancelamento da NF 221025 (volta 19/23/-4), nova entrada de 10 pela RPC
  (29/23/6), `rollback.sql` (volta 19/23/-4); grants iguais (só `authenticated`).
- Compras `6ef4d19`: os avisos da entrada e do cancelamento dizem quantas peças entraram/saíram do Estoque Geral.
- **Ainda aberto:** A4 (importação da Connect sobrescreve `estoque_itens` — não rodar o import de estoque da Connect
  sem decidir o Ponto 1), A5 (teste do Vinicius com outra peça) e A6.

### 2026-10-22 — Seções B a H (pedido do usuário: "pode implementar a spec 222!! vamos fazer tudo funcionar!!")
Decisões dos Pontos para confirmar: seguidas as recomendações (1: estoque da Connect suspenso; 2: cancelar entrada
volta "Aguardando aprovar"; 3: quantidade no fechamento para mais e para menos; 4: cópias por usuário).

**Banco** — migration `supabase/db/migrations/20261022_235_spec222_compras_ajustes/` (`001_compras_ajustes.sql` +
`rollback.sql`) **APLICADA** no SP:
- `espelho_entrada_nota_compra`: itens agrupados por peça (vinha uma linha por L do pedido = "triplicado") — C1/C2;
- `cancelar_entrada_nota_compra`: sem nada recebido, o pedido volta para `aguardando_aprovar` (limpa aprovado_por/em) — D1;
- nova `voltar_pedido_compra_para_edicao(p_pedido_id, p_motivo)`: aprovado, sem entrada de nota nem parcela paga,
  volta para `aguardando_aprovar` (motivo anotado na observação; sai do A Pagar) — D2;
- `aprovar_pedido_compra`: exige condição de pagamento; se não for "Antecipado", exige que as parcelas sejam geradas
  (condição não reconhecida dá erro claro) — F8;
- `_lucenera_datas_parcelas`: "À vista" = 1 parcela na data do pedido; "Antecipado" = nenhuma;
  `gerar_parcelas_pedido_compra`: "Antecipado" devolve 0 parcelas sem erro — F9;
- `usuarios.copias_pedido_compra` (o próprio usuário edita, RLS `usuarios_update_own`) — G1;
- `gerar_parcelas_pedido_compra` e `_lucenera_datas_parcelas` deixaram de ser executáveis por `anon` (SPEC-196).
- Dry-run em ROLLBACK: espelho da NF 221025 com 1 linha (12728 × 10); cancelar → `aguardando_aprovar`; voltar pedido
  1783 para edição; aprovar sem condição (erro), "À vista" (1 parcela), "Antecipado" (0 parcelas), "xpto" (erro);
  `anon` sem EXECUTE nas funções; `rollback.sql` remove a coluna.

**Script** `scripts/importar_produtos_estoque.py` — A4: EstoqueTotal/Disponivel só são gravados com `--incluir-estoque`
(o trigger `fn_sync_estoque_itens_from_produtos` sobrescreve `estoque_itens`, inclusive a reserva). Anotado em
`scripts/AGENTS.md`.

**Compras** `584bf2d` (no ar):
- Entrada de NF — B1: coluna "Cliente" com botão "Escolher cliente" e "x de y vinculado" (sem a lista de nomes); B2: sem
  IPI/ST por unidade nas linhas; B3/B4/B8: o valor da nota é o total calculado (sem campo digitado nem "diferença" —
  o desconto agora só reduz o total, que era o que travava); B5: nº + 3 datas numa linha, chave de acesso embaixo à
  esquerda; B6/B7: "Resumo da nota" com produtos (fixo), IPI, ST, desconto e despesas acessórias editáveis em R$;
  B10: anexo marcado "só registro". Cancelar avisa que o pedido volta para "Aguardando aprovar" e o estoque sai.
- B9 (antecipação): conferido — desmarcar tira só aquela antecipação; as parcelas são refeitas porque o restante a
  pagar muda. Não houve mudança.
- Pedidos — D2: botão "Voltar para edição" (com motivo) em pedido aprovado; aprovar mostra o caso antecipado.
- F1/F2/F3: aba "Estoque" virou **"Pedido de compra avulso"** (`/pedido-avulso`: fornecedor + qualquer produto do
  cadastro + mesmo fechamento da necessidade); aba Cotações saiu (rota redireciona para Pedidos); o card de custo
  saiu junto com a página de estoque; na Necessidade, o "Comprar" direto virou "Pôr no pedido" (um caminho só).
- F4/F5: "Fechar pedido" com uma linha por peça (soma dos L, coluna "Vendas" com quantos L e o que é a mais/continua
  na necessidade); o pedido grava 1 item por peça ligado a cada L (origem repartida na ordem do carrinho);
  quantidade editável para mais e para menos.
- F6/F7: desconto % no quadro de totais; totais com ST, IPI e outras despesas separados (fechar e editar pedido).
- F8/F9: campo de condição obrigatório com "A prazo / À vista / Antecipado (já pago)" (fechar e editar).
- F10: previsão de entrega continua opcional, com o prazo médio do fornecedor embaixo (já existia).
- G1: campo "Cópia" no Enviar ao fornecedor (gravado no usuário; vai como `Cc` no .eml). G2: ícone de e-mail em cada
  fornecedor da marca (tela Marcas) para editar os e-mails de pedido; marcas já em ordem alfabética.
- G3 (Outlook novo × clássico): não é do sistema — é o programa padrão do Windows para `.eml`. Pendente com o Pedro.

**Separação Parcial** `5ede8b3` (no ar) — E1: a lista do "Trocar" mostra o L, marca "esta venda" e põe os L da
própria venda primeiro; só lista quem tem reserva. O banco já aceitava troca no mesmo projeto.

**Cadastro** `8b39378` (no ar) — H1: aba Compras uma linha por pedido (quantidade somada). H2/A6: nos Setores, linha à
parte "Reserva sem venda (herança Connect)" = reservado da Connect − (reserva + entrega futura + separação dos L).

**Ainda aberto:** A5 (teste com outra peça, anotando antes/depois), G3 (Outlook), teste geral da Débora.
