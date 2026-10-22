---
titulo: "SPEC-220 — Entrada de Nota Fiscal completa (reunião Vinicius 21/10): vínculo com o cliente (entrega futura → reserva), apropriação, valores por item e espelho para o Mateus"
status: pendente
data_ultima_modificacao: 2026-10-22
sistemas_envolvidos:
  - Necessidade de Compra (compras-lucenera-3o23t98ee) — Entrada de Nota Fiscal
  - Administração Bancária (retorno-bancario-bradesco-5392a) — Contas a Pagar / pagamento antecipado
  - Separação Parcial (separacao-parcial) — mostra o que saiu da entrega futura e foi para o reserva
  - Dashboard Financeiro (dashboard-lucenera-b02z85wa3) — Contas a Pagar (apropriação)
---

# SPEC-220 — Entrada de Nota Fiscal completa

> Origem: `02-Reunioes/33. Lucenera (vinicius) - 21.10.2026_ Mapeamento do sistema de Administração bancaria/Reunião.01`.
> O Vinicius fez, na Connect, uma entrada de nota de pedido de compra e mostrou cada passo e o que precisa ser criado.
> Pedido do usuário em 22/10/2026: criar a SPEC a partir dessa reunião. Base já feita: SPEC-215 (financeiro e
> pagamento antecipado na entrada) e SPEC-218 (cancelar entrada).

## Checklist de Ação

**A. Vínculo com o cliente — entrega futura → reserva** (o principal: "é isso que precisa ser criado")
- [x] A1. Na entrada, para cada peça que chegou, mostrar para quem ela vai: as vendas/L em **entrega futura** daquela
      peça. Já vem sugerido com os L de origem do pedido (`pedido_compra_item_origem`), na ordem do pedido
- [x] A2. Poder trocar/acrescentar o destino: lista de todas as vendas com essa peça em entrega futura (venda, cliente,
      L, quantidade em entrega futura) e "quantidade a vincular" em cada uma
- [x] A3. **Limitador**: a soma vinculada não pode passar do que chegou na peça (nem do que a venda tem em entrega
      futura). O que sobrar sem vínculo entra como estoque livre
- [x] A4. Ao registrar: `q_entrega_futura` → `q_reserva` no saldo de cada L vinculado (`estoque_saldos_projeto_item`)
      + movimento em `estoque_movimentos_projeto_item` (origem = nota). A Separação Parcial passa a mostrar no reserva
- [x] A5. Cancelar a entrada (SPEC-218) desfaz o vínculo (reserva volta para entrega futura)

**B. Apropriação (plano de contas)**
- [x] B1. Toda entrada que gera financeiro tem apropriação; padrão **COMPRAS - REVENDA** (`plano_de_contas` 2050001, grupo PRODUTOS). Escolher outra apropriação na tela: ainda não (o banco já aceita `plano_contas_id`)
- [x] B2. As parcelas da nota entram no Contas a Pagar com essa apropriação (hoje vão como "PEDIDOS DE COMPRA")

**C. Dados da nota**
- [x] C1. Chave de acesso (44 dígitos), opcional agora; preenchida sozinha quando houver entrada por XML (fase 2)
- [x] C2. Datas: emissão, entrega (padrão hoje) e entrada (padrão hoje); quem fez a entrada = usuário logado (já existe)

**D. Valores por item (bater com a nota)**
- [x] D1. Itens da nota com valor unitário, IPI, ICMS e ST **já preenchidos** do pedido de compra/cadastro
- [x] D2. Poder ajustar o valor unitário (diferença de centavos) e o **total recalcula na hora** (na Connect não recalcula)
- [x] D3. Desconto da nota e despesas acessórias (frete etc.) no total
- [x] D4. "Outras despesas" do pedido (ICMS recolhido depois, fora da nota) **não entram** no valor da nota
- [x] D5. Total calculado × valor da nota: mostrar a diferença e só registrar quando bater (mesma regra das parcelas)

**E. Setor**
- [x] E1. Toda entrada entra no setor **Estoque Geral** (sem precisar vincular setor na mão, como na Connect)
- [ ] E2. Transferência de setor (Estoque Geral → Showroom etc.): **não existe** no sistema hoje (o que existe é
      transferir reserva entre L, SPEC-011) → SPEC própria depois (ver Pendências)

**F. Espelho da entrada (para o Mateus)**
- [x] F1. Espelho da entrada: nota, o que chegou, para quem foi vinculado (venda/cliente/L) e o que ficou livre
- [x] F2. PDF com nome padrão (`Entrada_NF_<nº>_<Fornecedor>.pdf`) + espelho na tela (botão "Espelho" em Últimas entradas). Tela própria no sistema do Mateus: pendente (a RPC já libera para Separação Parcial e Logística)
- [x] F3. Resumo financeiro da entrada (parcelas, antecipação usada) — já existe na tela (SPEC-215), entra no espelho

**G. Pagamento antecipado** (já atendido pela SPEC-215 — conferir com o Vinicius)
- [x] G1. Na entrada, lista todos os pagamentos antecipados do fornecedor (pode haver 2 ou mais), escolhe quais usar;
      os usados saem da lista (ficam "Usado")

**Entrega**
- [x] Migration 233 (rascunho + dry-run em ROLLBACK + aplicada 22/10), `vite build`, publicar, CHANGELOG

### Passos manuais do usuário

- [x] Responder os "Pontos para confirmar" (22/10: "vamos implementar o que pode" — seguidas as 4 recomendações)
- [ ] Teste com o Vinicius/Débora: entrada de uma peça com 2 vendas em entrega futura, vincular parte em cada, conferir
      na Separação Parcial que foi para o reserva

## Objetivo

Hoje, na Connect, dar entrada numa nota de pedido de compra é demorado:
- tem que preencher a apropriação, o setor, apertar Enter em vários campos para os valores aparecerem;
- o valor do item não recalcula quando se ajusta centavos;
- o vínculo com o cliente é feito peça por peça num menu escondido, sem limite: já aconteceu de vincular a mais;
- o espelho da entrada é salvo em PDF por cada um com um nome e mandado ao Mateus.

O objetivo é a entrada no nosso sistema fazer tudo isso numa tela só, com menos passos. Nas palavras do Vinicius, "o
que conseguir deixar menos moroso, mais prático, ótimo".

## Definição da SPEC (proposta — depende dos pontos para confirmar)

### Banco
- `notas_fiscais_compra`: + `chave_acesso`, `data_entrega`, `data_entrada`, `plano_contas_id` (padrão COMPRAS - REVENDA),
  `valor_desconto`, `valor_despesas_acessorias`.
- `nota_fiscal_compra_itens` (já existe, SPEC-218): + `valor_unitario`, `valor_ipi`, `valor_icms`, `valor_st` da nota.
- Nova `nota_fiscal_compra_vinculos`: `nota_item_id`, `projeto_item_id`, `quantidade` (o que foi para a reserva de cada L).
- `registrar_entrada_nota_compra` recebe os vínculos; valida o limitador; move `q_entrega_futura` → `q_reserva` e grava
  o movimento. `cancelar_entrada_nota_compra` desfaz.
- `vw_contas_pagar_pedidos_compra`: parcela da nota usa a apropriação da nota (grupo/sub-grupo do plano de contas).

### Telas (Necessidade de Compra › Entrada de Nota Fiscal)
- Itens: Pedido / Já chegou / Falta / Chegou agora (como hoje) + valor unitário, IPI, ICMS, ST editáveis + total.
- Em cada peça: "Para quem" (L sugeridos) com botão para escolher outras vendas em entrega futura; contador
  "vinculado X de Y".
- Cabeçalho da nota: número, chave, datas, apropriação, desconto, despesas acessórias.
- Depois de registrar: botão "Espelho da entrada".

## Pontos para confirmar (com recomendação)

1. **Estoque e reserva no nosso sistema** — conflita com a SPEC-209 (19/10: "a entrada não mexe em estoque, o estoque
   vem da Connect"). A entrada passa a mover entrega futura → reserva no nosso banco (o que a Separação Parcial
   mostra), mesmo com a nota ainda sendo lançada também na Connect?
   Recomendação: **sim, mexer só no reserva/entrega futura dos L** (que já são nossos, gerados na aprovação do
   orçamento), sem mexer no estoque físico que vem da Connect (`produtos.estoque_*`).
2. **Espelho para o Mateus**: PDF (como hoje, com nome padrão) ou tela online que ele consulta?
   Recomendação: **os dois** — botão PDF na entrada e uma lista "Entradas" que o Mateus acessa.
3. **Valores por item**: fazer agora (D1–D5) ou só o total da nota, como está (SPEC-215)?
   Recomendação: **fazer agora** — é o que faz o total bater sem malabarismo de centavos.
4. **Transferência de setor** (Estoque Geral → Showroom): SPEC separada depois?
   Recomendação: **sim, SPEC separada** (envolve o estoque físico que hoje vem da Connect).

## Pendências / fase 2

- Entrada por XML da nota (preenche chave, itens e valores sozinha) — citada na reunião como próximo passo.
- Grupo de CFOP (na Connect "Vendas" para compra para revenda): só registro fiscal; entra junto com a fase do XML.
- Transferência de setor (E2).

## Rollback

- Telas: reverter os commits. Banco: `rollback.sql` da migration (vínculos desfeitos voltam a reserva para entrega futura).

## Decisões (22/10/2026)

Usuário: "vamos implementar o que pode" → seguidas as recomendações dos 4 pontos:
1. A entrada move só o saldo dos L (entrega futura → reserva); o estoque físico da Connect não é tocado.
2. Espelho em PDF e na tela. 3. Valores por item agora. 4. Transferência de setor em SPEC separada.

## Realizado

### 2026-10-22

- **Migration 233 aplicada** (`20261022_233_spec220_entrada_nf_vinculo_reserva`, com `rollback.sql`):
  - colunas novas: chave de acesso (44 números), datas de entrega e de entrada, apropriação, desconto e despesas
    acessórias na nota; valor unitário, IPI, ICMS e ST nos itens da nota;
  - tabela `nota_fiscal_compra_vinculos` (RLS, sem anon, escrita só pela RPC);
  - RPCs `entregas_futuras_para_entrada` e `espelho_entrada_nota_compra`;
  - `registrar_entrada_nota_compra` com `p_vinculos` (a assinatura antiga foi apagada, sem sobrecarga; a tela
    antiga continua funcionando porque os parâmetros novos têm padrão);
  - `cancelar_entrada_nota_compra` desfaz o vínculo;
  - parcela da nota no A Pagar com a apropriação (PRODUTOS / DESPESAS).
- Dry-run (ROLLBACK) com o pedido 1783, usuário do Vinicius:
  - 30 da peça 07809: 20 para o L14 e 6 para o L35 (4 livres) → L14 com entrega futura 30→10 e reserva 8→28;
    L35 com entrega futura 6→0 e reserva 0→6; movimentos `recebimento_para_reserva`;
  - apropriação COMPRAS - REVENDA; espelho com os vínculos; cancelar devolveu 26 para a entrega futura;
  - recusados: vincular mais do que chegou, mais do que o L espera, L de outra peça, chave com 3 números, anon.
- Compras:
  - itens com Vl. unit., IPI/un., ST/un. e total (já preenchidos do pedido, editáveis);
  - linha "Para quem" com os L sugeridos e o botão "Escolher clientes" (limitador na tela e no banco);
  - campos de chave, datas, desconto e despesas acessórias; quadro "Total pelos itens × valor da nota" (só registra
    quando bate);
  - espelho abre sozinho depois de registrar; botão "Espelho" em Últimas entradas; PDF conferido.
- Não feito nesta etapa: escolher outra apropriação na tela, tela do espelho no sistema do Mateus, entrada por XML,
  grupo de CFOP e transferência de setor.
