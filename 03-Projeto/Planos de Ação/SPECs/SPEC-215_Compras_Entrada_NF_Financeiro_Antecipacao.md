---
titulo: "SPEC-215 — Entrada de Nota Fiscal: CNPJ, troca de fornecedor, parcelas da nota e pagamento antecipado"
status: pendente
data_ultima_modificacao: 2026-10-21
sistemas_envolvidos:
  - Compras (compras-lucenera-3o23t98ee) — Entrada de Nota Fiscal
  - Adm. Bancária (retorno-bancario-bradesco-5392a) — Contas em Aberto › Pagar
  - Dashboard Financeiro (dashboard-lucenera-b02z85wa3, `services/cash-flow.ts`) — Contas a Pagar / Fluxo Futuro (só se precisar mostrar a coluna nova; a view já é somada)
  - Script de importação do Connect (scripts/importar_contas_pagar_receber.py)
---

# SPEC-215 — Entrada de Nota Fiscal com financeiro e pagamento antecipado

## Checklist de Ação

**A. Fornecedor e CNPJ na entrada (Compras)**
- [x] A1. Entrada por pedido mostra o fornecedor com CNPJ
- [x] A2. Botão "Trocar fornecedor" (busca no cadastro, mostra CNPJ); ao registrar, o fornecedor do **pedido** passa a ser o novo (decisão do usuário) e a troca fica na auditoria

**B. Parcelas da nota (Compras)**
- [x] B1. Na entrada: Valor total da nota e Valor do ST da nota (sugerido pelos itens que chegaram, editável)
- [x] B2. Parcelas sugeridas pela condição de pagamento do pedido, **com o ST inteiro na 1ª parcela**; vencimento e valor de cada parcela editáveis; incluir/tirar parcela
- [x] B3. Soma das parcelas + antecipação vinculada tem que bater com o valor da nota (mostra a diferença e não deixa registrar)

**C. Pagamento antecipado**
- [x] C1. Adm. Bancária › Contas em Aberto (Pagar): botão "Lançar pagamento antecipado" — fornecedor, empresa, valor, data em que foi pago, pedido de compra (opcional), observação
- [x] C2. Lista de pagamentos antecipados com saldo (Disponível / Usado em parte / Usado), cancelar lançamento sem uso
- [x] C3. Na entrada da nota: aviso "Existe pagamento antecipado para este fornecedor" com a lista (saldo); selecionar e vincular
- [x] C4. Antecipação cobre a nota toda → não gera parcela. Sinal → desconta do total e as parcelas são do restante. Sobra de saldo fica para a próxima nota

**D. Contas a Pagar**
- [x] D1. Parcelas da nota entram no Contas a Pagar (DESPESAS › PEDIDOS DE COMPRA, marcadas "nota") e a previsão do pedido diminui no valor da nota
- [x] D2. Pagamento antecipado aparece como pago (DESPESAS › PAGAMENTO ANTECIPADO) e, se ligado a pedido, abate a previsão do pedido
- [x] D3. Quando a duplicata do Connect da mesma nota chega na importação, a parcela da nota sai (vale a do Connect)
- [x] D4. Importação do Connect passa a gravar `num_nota` em `negociacoes`

**Banco / entrega**
- [x] Migration (rascunho + dry-run em ROLLBACK + aplicar) — 229 aplicada 21/10
- [x] `vite build` de Compras e Adm. Bancária (Dashboard não muda: já soma a view); testado no banco como a Débora, a Lana e anon
- [x] Publicar e atualizar CHANGELOG

### Passos manuais do usuário

- [ ] Dar à Carol acesso ao sistema "Administração Bancária" no Hub (hoje só a Lana tem; sem ele não lança antecipação)

- [ ] Confirmar com Lana/Carol o item "Pendências" 1 (antecipação também lançada no Connect?)
- [ ] Teste: lançar um sinal de 50% num pedido, dar entrada na nota, vincular, conferir as parcelas do restante no Contas a Pagar
- [ ] Teste: pedido 100% antecipado → entrada sem parcelas

## Objetivo

Pedido do usuário em 21/10/2026 (Necessidade de Compra › Entrada de Nota Fiscal):
- mostrar o CNPJ e poder trocar o fornecedor ("montamos o pedido em nome da Emétris, mas a nota veio no nome da
  Spot LED; ambas são Metal Spot, ajustamos na entrada para ficar certo com a nota");
- lançar a parte financeira da nota na entrada — vencimentos e valores editáveis ("quase nunca são divididas
  igualmente"); ST destacado é cobrado sempre na 1ª parcela;
- "vincular pagamento antecipado": ex. Figueiredo Nunes, 50% de entrada antes do material e da nota. Esse valor é
  lançado manualmente no Contas a Pagar como antecipação; na entrada da nota o sistema mostra que existe
  antecipação para o fornecedor, a pessoa seleciona e vincula. 100% antecipado → não gera mais financeiro;
  sinal → desconta do total e gera o restante em parcelas.

## Decisões aprovadas (21/10/2026)

- **Connect continua:** a nota de compra continua sendo lançada no Connect. Por isso as parcelas digitadas aqui
  são provisórias: valem no Contas a Pagar até a duplicata do Connect daquela nota chegar pela importação.
- **A nota substitui a previsão:** as parcelas da nota entram no A Pagar e a previsão do pedido (parcelas geradas
  ao aprovar, SPEC-209 F) diminui no valor da nota; pedido concluído → a previsão que sobrar sai.
- **Antecipação é lançada na Adm. Bancária**, em Contas em Aberto › Pagar (Lana/Carol).
- **Trocar fornecedor muda o fornecedor do pedido** (não só da nota).

## Definição da SPEC

### Banco (uma migration, sem tocar `transacoes`)

- `notas_fiscais_compra`: + `valor_st numeric`. (`fornecedor_id`, `empresa_id`, `valor` já existem.)
- **Nova** `nota_fiscal_compra_parcelas`: `nota_id`, `numero_parcela`, `data_vencimento`, `valor`.
- **Nova** `pagamentos_antecipados`: `fornecedor_id`, `empresa_id`, `pedido_compra_id` (opcional), `valor`,
  `data_pagamento`, `observacao`, `criado_por`, `cancelado_em/por`.
- **Nova** `pagamento_antecipado_vinculos`: `pagamento_id`, `nota_id`, `valor_aplicado`. Saldo = valor − aplicado.
- `negociacoes`: + `num_nota integer` (preenchido pela importação do Connect).
- RLS: tabelas novas com `ENABLE RLS` + `REVOKE ALL FROM anon`; leitura/escrita da antecipação com
  `pode_acessar_sistema` (Adm. Bancária / Dashboard Financeiro); leitura do saldo na entrada pela Compras via RPC
  `SECURITY DEFINER` (só fornecedor, data, valor e saldo).
- **RPC `registrar_entrada_nota_compra`** (substitui o par `registrar_entrada_pedido_compra` + insert da nota, numa
  transação só): quantidades por item (regra atual), fornecedor novo do pedido (opcional), nota, parcelas e
  vínculos de antecipação. Valida: soma das parcelas + antecipação aplicada = valor da nota (±R$ 0,01); valor
  aplicado ≤ saldo; antecipação do mesmo fornecedor (o da nota) ou ligada ao mesmo pedido.
- **RPC `lancar_pagamento_antecipado`** / `cancelar_pagamento_antecipado` (só sem vínculo).

### Contas a Pagar (`vw_contas_pagar_pedidos_compra`, que o Dashboard já soma)

- **Previsão do pedido:** consumido = Σ valor das notas do pedido + Σ saldo das antecipações ligadas ao pedido.
  O consumido abate as parcelas de previsão **da primeira para a última** (o sinal e a primeira nota substituem as
  parcelas mais próximas). Pedido concluído → previsão zero. A tabela `pedido_compra_parcelas` não é alterada
  (o cálculo é na view).
- **Parcelas da nota:** uma linha por parcela, "Nota <nº> — <fornecedor> (parcela x/y)", enquanto não existir no
  Connect uma duplicata de despesa com **mesma empresa + mesmo `num_nota` + mesmo total (±R$ 1,00)**.
  (O fornecedor não serve para casar: os fornecedores dos pedidos não estão ligados aos contatos das duplicatas do
  Connect e a planilha do Connect não traz CNPJ.)
- **Antecipação:** linha paga (`status_pago = 1`, `dt_pagamento` = data informada) em DESPESAS › PAGAMENTO ANTECIPADO.

### Telas

- **Compras › Entrada de Nota Fiscal (por pedido):** cabeçalho com fornecedor + CNPJ e "Trocar fornecedor";
  seção "Financeiro da nota" (valor total, ST, parcelas editáveis, botão "Gerar pelas condições do pedido");
  quadro "Pagamento antecipado" quando houver saldo para o fornecedor (o da nota ou o do pedido) — marcar e
  informar quanto usar (sugere o menor entre saldo e total da nota).
- **Adm. Bancária › Contas em Aberto › Pagar:** botão "Lançar pagamento antecipado" (janela) e aba/lista
  "Pagamentos antecipados" com saldo e notas vinculadas.

## Pendências

1. **Antecipação no Connect:** se a Lana/Carol também lançam o sinal no Connect, o pagamento sai duas vezes no
   fluxo de caixa (o nosso + o do Connect). Confirmar com elas; se lançam, a nossa antecipação passa a servir só
   para vincular na entrada e não entra no fluxo.
2. **Duplicata do Connect com valor cheio:** quando a nota teve sinal, o Connect pode trazer a duplicata pelo valor
   total. A partir daí vale o que estiver no Connect (decisão "Connect continua").
3. A importação só preenche `num_nota` a partir da próxima rodada; até lá a parcela da nota fica no A Pagar.

## Rollback

- Telas: reverter os commits de Compras e Adm. Bancária.
- Banco: `DOWN.sql` da migration volta a view da 228, apaga as 3 tabelas novas, as colunas e as RPCs novas
  (a `registrar_entrada_pedido_compra` atual não é apagada).

## Realizado

### 2026-10-21

- **Migration 229 aplicada** (`20261021_229_spec215_entrada_nf_financeiro_antecipacao`, com `rollback.sql`):
  `notas_fiscais_compra.valor_st`, `negociacoes.num_nota`, tabelas `nota_fiscal_compra_parcelas`,
  `pagamentos_antecipados`, `pagamento_antecipado_vinculos` (RLS, sem anon, escrita só por RPC, auditoria),
  view `vw_pagamentos_antecipados`, RPCs `registrar_entrada_nota_compra`, `lancar_pagamento_antecipado`,
  `cancelar_pagamento_antecipado`, `antecipacoes_para_entrada`; `vw_contas_pagar_pedidos_compra` refeita.
- Dry-run (ROLLBACK) com o pedido 1783 e parcelas de teste 500/500/456,71:
  - sinal de 700 (Lana) → previsão 0/300/456,71 + linha paga de 700;
  - Débora não vê a tabela, vê o saldo pela RPC; não consegue lançar antecipação;
  - entrada parcial com nota de 1.000 (ST 50), 700 do sinal e parcelas 200+100, nota em nome de outro fornecedor →
    pedido Concluído parcialmente e trocado de fornecedor, sinal "usado", A Pagar = previsão 456,71 + nota 200 e 100;
  - duplicata do Connect com num_nota 12345 e total 1.000 → as parcelas da nota saem;
  - completar o pedido → previsão some;
  - recusados: soma que não bate, uso acima do saldo, nota repetida no pedido, anon.
- **Compras:** Entrada de Nota Fiscal com CNPJ, "Trocar fornecedor", valor total e ST sugeridos pelo que chegou,
  parcelas sugeridas pela condição do pedido (ST na 1ª) e editáveis, quadro de pagamento antecipado, tudo gravado
  pela RPC numa transação só. Entrada avulsa continua como antes.
- **Adm. Bancária:** Contas em Aberto › Pagar › "Pagamentos antecipados" (lançar, lista com saldo, cancelar sem uso).
- **Importação do Connect** (`scripts/importar_contas_pagar_receber.py`): grava `num_nota` em `negociacoes`
  (testado em ROLLBACK: 3.230 negociações recebem o número na próxima importação).
- Observação: a Carol não tem acesso ao sistema `financeiro` (Adm. Bancária); só a Lana consegue lançar hoje.
