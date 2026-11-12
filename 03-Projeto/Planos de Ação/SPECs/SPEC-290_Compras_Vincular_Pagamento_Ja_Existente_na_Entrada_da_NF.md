---
titulo: "SPEC-290 — Compras: vincular o pagamento já existente (Connect/antecipação) na entrada da NF, sem duplicar o Contas a Pagar"
status: implementada A–D em 12/11/2026 (código local nos 2 sistemas; migration 345 redigida e ensaiada, NÃO aplicada); E só ensaiado, aguarda confirmação
data_ultima_modificacao: 2026-11-12
sistemas_envolvidos:
  - Compras / Necessidade de Compra (04-Sistemas/compras-lucenera-3o23t98ee) — Entrada de Nota Fiscal e Pedidos
  - Banco (financeiro_ponte_pedido, registrar_entrada_nota_compra, pagamentos_antecipados, vw_financeiro_duplicatas)
  - Contas a Pagar (retorno-bancario-bradesco-5392a) — Consultar Duplicatas (selo/rastreio)
  - Importação do Connect (scripts/importar_contas_pagar_receber.py)
---

# SPEC-290 — Pedido já pago: vincular o pagamento que já existe

**Origem:** Reunião 52 (Débora) + Reunião 51 (Vinicius, Carol e Lana) + pedido do usuário em 12/11/2026 ("tenha o rastreio para não abrir um contas a pagar duplicado", pedido 1985).
Relacionadas: SPEC-215 (antecipação), SPEC-218 (cancelar entrada), SPEC-288 A (espelho da antecipação), SPEC-289 (opção "já pago").

## Checklist de Ação

**A. Detectar o pagamento existente (Compras)**
- [x] A1. RPC `pagamentos_existentes_para_entrada(pedido)` (SECURITY DEFINER, devolve só duplicata, valor, data, origem, saldo; a 345 acrescenta `valor_igual`, `equivalente` e `pode_forcar`, e um 2º parâmetro opcional com o fornecedor da nota): parcelas **pagas** de `pagar` do mesmo fornecedor e empresa, valor próximo (±R$ 1,00 ou até o total do pedido), data de pagamento a partir de (emissão do pedido − 3 dias), de origem `legado_connect` ou `adiantamento`, **sem vínculo** (ou com saldo) com outro pedido/nota
- [x] A2. Entrada de NF mostra o quadro "Pagamento já feito para este fornecedor" (ex.: *Duplicata 8405 — R$ 2.204,30 — paga em 04/11/2026 — Connect*), **(revisado em 12/11: NÃO pré-seleciona; o usuário sempre clica para vincular, com destaque "valor igual ao do pedido")**
- [x] A3. Pedido com condição "Antecipado" sem vínculo mostra aviso "Pago — falta vincular o pagamento" (lista de Pedidos e Entrada)

**B. Vínculo sem dinheiro novo**
- [x] B1. Tabela `pagamento_existente_vinculos` (parcela_id do financeiro novo, pedido_compra_id, nota_id, valor_aplicado, criado_por/em, cancelado_em) com RLS, `REVOKE ALL FROM anon`, escrita só por RPC
- [x] B2. `registrar_entrada_nota_compra` aceita `p_vinculos_pagamento` (lista parcela + valor): grava o vínculo, **não cria título, parcela nem baixa**; nota coberta integralmente fica sem parcelas, cobertura parcial gera parcelas só do restante (mesma regra B3 da SPEC-289)
- [x] B3. Valida: valor aplicado ≤ saldo da parcela paga; mesma parcela não pode cobrir duas notas além do saldo; fornecedor/empresa coerentes; pedido não cancelado
- [x] B4. `financeiro_ponte_pedido` e `vw_contas_pagar_pedidos_compra` contam o valor vinculado como "consumido" (abate a previsão do pedido), sem somar em dobro com antecipação nativa
- [x] B5. `cancelar_entrada_nota_compra` (SPEC-218) cancela o vínculo; a duplicata da Connect permanece intacta

**C. Rastreio visível**
- [x] C1. Consultar Duplicatas (Pagar): a duplicata vinculada mostra "Pago antecipado — Pedido 1985 / NF 11221" (coluna/selo, filtro por pedido)
- [x] C2. Pedido (Compras): selo "Pago antecipado (dup. 8405)"
- [x] C3. Só lê a duplicata; **nada é gravado na duplicata da Connect**

**D. Trava na opção "Este pedido já foi pago" (SPEC-289)**
- [x] D1. Se a RPC de detecção achar pagamento equivalente, a opção **bloqueia** e manda vincular o existente
- [x] D2. Só quem tem acesso a financeiro (Lana) pode forçar um lançamento novo, com observação obrigatória
- [x] D3. Mesma trava na RPC (não só na tela)

**E. Importação do Connect**
- [ ] E1. (NÃO implementado — aguarda confirmação; ver "Ensaio do item E") Ao importar duplicata paga de despesa, se existir antecipação nativa equivalente (mesmo fornecedor, empresa, valor e data ±3 dias, sem vínculo), vincular/marcar como espelhada em vez de criar segunda saída (caso Omega Light R$ 2.608,52)
- [x] E2. Ensaio do importador feito em ROLLBACK/leitura (resultado abaixo); importador NÃO alterado. Sem decisão, fica só o aviso na conferência de integridade (proposta abaixo)

**Entrega**
- [x] Migration **345** (a 344 já existe, é da SPEC-290 do PDF das parcelas) + `rollback.sql` + `dry_run.sql` em ROLLBACK (como Débora sem financeiro, Lana com financeiro e `anon`)
- [ ] Aplicar a migration 345 — **só com autorização do usuário**
- [x] `vite build` (Compras; Contas a Pagar `pagar` e `receber`), `tsc --noEmit` e `oxlint` sem erro novo; CHANGELOG
- [ ] Revisor antes do commit, publicar Compras e Contas a Pagar (wrangler) **depois** de aplicar a 345, `AI_DB_CONTEXT.md`, snapshot

### Passos manuais do usuário
- [ ] **URGENTE — pagamento em dobro no 1985 (achado de 12/11 às 18:44 UTC):** a Débora já deu entrada de novo na NF 11221 pela opção "já foi pago" (SPEC-289): existe a antecipação de R$ 2.204,30 (`pagamentos_antecipados` 276042b6…, título espelho em Consultar Duplicatas) **mais** a duplicata 8405 da Connect. Correção sugerida, depois de aplicar a 345 e publicar as telas: (1) Débora cancela a entrada da NF 11221 (SPEC-218; devolve o estoque e o pedido volta a Aguardando aprovar); (2) Lana cancela a antecipação (fica "sem uso", o espelho é cancelado e estornado); (3) Débora dá a entrada de novo vinculando a duplicata 8405 no quadro "Pagamento já feito para este fornecedor". O ensaio refez exatamente esse caminho em ROLLBACK (cancelar entrada, cancelar antecipação, vincular a 8405: nota sem parcelas e nenhum título novo). Nada foi corrigido no banco real
- [ ] Avisar a Débora para **não dar entrada** nos pedidos 1925 e 1733 (e, até a correção acima, não mexer no 1985) até esta SPEC sair; **e não usar "já foi pago"** neles
- [ ] Aplicar a migration 345 (`python scripts/aplicar_migration_sql.py 20261112_345_spec290_vincular_pagamento_existente`) e só então publicar Compras e Contas a Pagar; rodar o agente `revisor` antes do commit
- [ ] Débora testar o 1985 (vincular duplicata 8405 depois da correção acima) e conferir que nenhum Contas a Pagar novo aparece; testar também o 1925 (dup. 8284) e o 1733 (dup. 7554, que tem uma 2ª candidata de R$ 743,40 e por isso não pré-seleciona sozinha se o valor não bater)
- [ ] Lana conferir o rastreio em Consultar Duplicatas
- [ ] Confirmar o item E (ver proposta em "Ensaio do item E"): decidir se fica só o aviso na conferência de integridade ou se o importador passa a marcar a antecipação como espelhada

## Estado verificado (12/11/2026, somente leitura)

- **Pedido 1985** (`1985 CONNECT`, R$ 2.204,31, condição "Antecipado", `aguardando_aprovar`): a duplicata **8405** da Connect (RIBAS DAVILA, MANOELLA, R$ 2.204,30, emissão 03/11, **paga em 04/11**, `legado_connect`, sem `num_nota`) já é o pagamento. A NF 11221 gerou uma parcela de R$ 2.204,30 (vencimento 09/12) e foi cancelada pela Débora às 17:38 com o motivo "entrada de NF gerou o financeiro, sendo que foi pago de forma integral antecipadamente".
- Só 3 pedidos "Antecipado" abertos (1925, 1733, 1985); os três têm duplicata Connect paga de valor igual (8284 em 14/10; 7554 em 28/07; 8405 em 04/11) e **nenhum** tem antecipação nativa.
- A regra D3 da SPEC-215 (duplicata da Connect com mesmo `num_nota` remove a parcela da nota) **não protege** este caso: a 8405 não tem `num_nota`.
- A opção "Este pedido já foi pago" (SPEC-289, publicada em 12/11) criaria um **segundo pagamento** no 1985. A Débora não a usou (nenhuma antecipação ligada ao pedido; verificado).

## Decisões (recomendações do usuário, 12/11/2026)

1. SPEC própria (290), separada da 289.
2. Opção "já pago" **bloqueia** quando há equivalente; só a Lana força.
3. Aviso à Débora para não dar entrada nos três pedidos até sair.
4. O vínculo só marca cobertura; **nada é gravado na duplicata da Connect**.

## Riscos / atenção

- Casamento por valor ±R$ 1,00 pode sugerir pagamento errado: sempre confirmação humana; pré-seleciona só com correspondência única.
- Fornecedor do pedido x contato da duplicata: usar `contato_id` do financeiro (já casam nos 3 pedidos); fornecedor trocado na entrada (SPEC-215 A2) precisa recalcular a lista.
- Importador: mudança em script de produção; ensaiar em ROLLBACK.

## Rollback

Telas: reverter commits de Compras e Contas a Pagar. Banco: `rollback.sql` devolve a RPC e a view anteriores e apaga a tabela de vínculos (vínculos criados deixam de abater a previsão).

## Realizado (12/11/2026)

**Banco — migration `supabase/db/migrations/20261112_345_spec290_vincular_pagamento_existente/` (up.sql, rollback.sql, dry_run.sql; NÃO APLICADA)**
- Número 345: a 344 já existe (SPEC-290 do PDF das parcelas, aplicada). As duas SPECs de número 290 convivem; os nomes das pastas as distinguem.
- B1: tabela `pagamento_existente_vinculos` (parcela, pedido, nota, `valor_aplicado`, rótulos gravados na hora: duplicata, número do pedido, NF; `criado_*`, `cancelado_*`), RLS de leitura (`necessidade-de-compra`, `financeiro`, `dashboard-financeiro`, `contas-pagar`, com `(SELECT ...)`), `REVOKE ALL FROM PUBLIC, anon, authenticated` + `GRANT SELECT` a `authenticated`, trigger de auditoria; escrita só pelas RPCs.
- A1: `_pagamentos_existentes_candidatos` (interna, sem EXECUTE para ninguém) e `pagamentos_existentes_para_entrada(p_pedido_id, p_fornecedor_id DEFAULT NULL)`: parcelas pagas de `pagar`, mesmo fornecedor (ou o da nota, se trocado) e empresa, origem `legado_connect` (ou `adiantamento` que não seja espelho de `pagamentos_antecipados`, esse já tem o caminho nativo), paga a partir de emissão do pedido − 3 dias, saldo > 0 (pago − vínculos ativos) e saldo ≤ total do pedido + R$ 1,00. Devolve só: `parcela_id`, `duplicata`, `valor`, `saldo`, `data_pagamento`, `origem`, `valor_igual` (±R$ 0,01 do total do pedido), `equivalente` (±R$ 1,00), `pode_forcar`. Trava: `hub_pode_executar('necessidade-de-compra', editar)`.
- C: `pedidos_pago_antecipado_info(uuid[])` (selo e aviso "falta vincular", só leitura) e coluna `pago_antecipado` no FIM de `vw_financeiro_duplicatas` (nenhum dependente; `security_invoker` mantido).
- B2/B3/D: `registrar_entrada_nota_compra` com `p_vinculos_pagamento jsonb DEFAULT NULL` (9 parâmetros; DROP da de 8; ACL `REVOKE FROM PUBLIC, anon` + `GRANT` a `authenticated`; comportamento da 343 mantido, inclusive o teto e a antecipação ligada). Valida: pedido não cancelado, parcela de `pagar` ativa e paga, origem `legado_connect`/`adiantamento`, não ser antecipação do sistema, mesmo fornecedor e empresa, valor ≤ saldo (mesma parcela não cobre duas notas além do saldo, inclusive dentro do mesmo envio). Vem antes do uso automático da antecipação ligada ao pedido. Não cria título, parcela nem baixa. Trava da opção "já foi pago": com pagamento equivalente (`equivalente` ou |saldo − valor informado| ≤ R$ 1), recusa e manda vincular; só quem tem `financeiro`/`dashboard-financeiro` força (`p_pagamento.forcar_novo = true`) e a observação é obrigatória (grava "Lançado apesar de pagamento existente (dup. X): ..."); vínculo e "já foi pago" no mesmo envio são recusados.
- B4: `financeiro_ponte_pedido` e `vw_contas_pagar_pedidos_compra` **não foram alterados de propósito**: o consumido já é `Σ notas.valor` (a parte coberta por vínculo está dentro do valor da nota) + saldo de antecipação ainda NÃO aplicado a notas; somar o vínculo seria dupla contagem. O ensaio confirma: pedido de 2.000 + nota de 1.000 coberta por vínculo → previsão 1.000 na view e no financeiro novo; com vínculo 600 + antecipação nativa 500 na mesma nota de 1.100 → previsão 900 (não 400 nem 500).
- B5: `cancelar_entrada_nota_compra` cancela o vínculo (`cancelado_em`, motivo) e devolve `vinculo_pagamento_cancelado`; a duplicata fica intacta.

**Ensaio em ROLLBACK (`dry_run.sql`, 71 verificações, banco real intacto depois)** — dados reais: pedido 1985 e duplicata 8405; Débora (Compras sim, financeiro não) e Lana (os dois):
- Detecção como Débora: o 1985 devolve só a 8405 (R$ 2.204,30, `legado_connect`, paga em 04/11), com `valor_igual` = única; só os campos necessários. Para o 1925 devolve a 8284 (R$ 743,40) e para o 1733 a 7554 (R$ 9.106,13, `valor_igual`) mais a 8284 (não igual).
- Preparo (achado): o 1985 está hoje com a entrada duplicada (ver "URGENTE" acima); o ensaio cancela essa entrada (Débora) e a antecipação (Lana) dentro do ROLLBACK para voltar ao ponto de partida da SPEC (Aguardando aprovar).
- D: Débora com "já foi pago" no 1985: bloqueada ("Já existe pagamento ... (duplicata 8405)"), também com `forcar_novo`; Lana sem confirmar: bloqueada; Lana confirmando sem observação: bloqueada; Lana com confirmação e observação: libera e grava a observação com o aviso; vínculo + "já foi pago": recusado; nada gravado nas tentativas recusadas.
- B: 1985 vinculado à 8405 como Débora: nota sem parcelas, 1 vínculo de R$ 2.204,30 com rótulos, nenhum título, parcela ou baixa nova para o fornecedor, nenhuma antecipação nova, nenhum título da nota, duplicata 8405 intacta, 8405 sai da lista de candidatas (saldo 0), `vw_contas_pagar_pedidos_compra` sem linha do pedido, selo no pedido (dup. 8405 / NF) e na view ("Pedido 1985 CONNECT / NF ..."); aviso "falta vincular" antes do vínculo.
- B (parcial e uso duplo): nota de R$ 1.000 coberta por R$ 1.000 da 8405 (sem parcelas); outra nota com R$ 1.204,31 recusada (saldo 1.204,30, nada gravado); vínculo parcial de R$ 1.204,30 + parcela de R$ 295,70 aceito (parcela que não fecha, recusada); 8405 esgotada recusa novo vínculo; duplicata de outro fornecedor e de outra empresa recusadas; antecipação nativa não entra pelo vínculo.
- B5: cancelar a entrada devolve o vínculo (R$ 2.204,30), a 8405 permanece paga e volta a ser candidata com saldo cheio, o selo some.
- Acesso: `anon` recusado na tabela e nas 3 RPCs novas e na entrada; usuário sem papel recusado; Débora usa a detecção mas não grava nem altera a tabela; Lana usa tudo; 1 única assinatura de `registrar_entrada_nota_compra` (9 parâmetros), `anon` sem EXECUTE; RLS ligada; view com `security_invoker` e a coluna nova no fim.
- `rollback.sql` reensaiado (aplica o up e o rollback numa transação e compara): `registrar_entrada_nota_compra` (8 parâmetros, 1 overload), `cancelar_entrada_nota_compra` e `vw_financeiro_duplicatas` voltam **idênticas** ao original (ACL e `security_invoker` da view incluídos), tabela e funções novas removidas.

**Telas (só local, sem commit, sem publicar)**
- Compras: `EntradaNotaFiscal.tsx` + `FinanceiroNotaEntrada.tsx` (quadro "Pagamento já feito para este fornecedor" com duplicata, valor, data e origem; pré-marca só se houver 1 correspondência de valor igual; recalcula se o fornecedor da nota mudar; aviso "Pago — falta vincular o pagamento" no pedido Antecipado sem vínculo; "já foi pago" bloqueada com a explicação, e só o Financeiro vê a caixa "Lançar pagamento novo mesmo assim" com observação obrigatória; vínculo desliga "já foi pago"; soma do quadro financeiro conta o vínculo), `PedidosCompra.tsx` (selo "Pago antecipado (dup. 8405)" e aviso na coluna Condição), `notas-fiscais-compra.ts` (chamadas; `p_vinculos_pagamento` só vai quando há vínculo, então a tela não quebra se for publicada antes da migration).
- Contas a Pagar (`retorno-bancario-bradesco-5392a`): `financeiro-novo.ts` lê a coluna nova; `ConsultarDuplicatas.tsx` mostra o selo "Pago antecipado — Pedido X / NF Y" ao lado do número da duplicata e o filtro "Pedido (antec.)". Só leitura.
- Verificação: `vite build` (Compras e Contas a Pagar nos modos `pagar` e `receber`) ok; `tsc --noEmit` com o mesmo nº de erros de antes (6 e 41, todos em outros arquivos); `oxlint` sem aviso novo; `oxfmt --check` já acusava os mesmos arquivos antes (formatação anterior, não reformatei).
- **Não testado no navegador:** golden path (o usuário/Débora precisam testar: pedido 1985 depois da correção, quadro, vínculo, nota sem parcela, selo no pedido e em Consultar Duplicatas, bloqueio do "já foi pago").
- Fora do escopo/limite: `EspelhoEntradaDialog`/PDF do espelho da entrada não ganharam linha própria do vínculo (a nota sem parcelas aparece como paga por antecipação); só o selo. Não toquei no mecanismo de idempotência do Retorno Bancário (hash do arquivo / `processar_retorno_bancario`).

## Ensaio do item E (importação do Connect) — nada alterado no importador

Caso Omega Light: antecipação nativa `889322d0…` de R$ 2.608,52 em 05/11 (MANOELLA, "PRIMEIRO ANTECIPADO LANÇADO") e o espelho em `financeiro` (título `adiantamento`, SPEC-288 A). Verificado só em leitura e em ROLLBACK:
1. A planilha mais recente (`ContaPagar_2026-11-05.xlsx`) **não tem** nenhuma parcela de R$ 2.608,52: a saída da Omega só aparecerá numa planilha futura, como duplicata **nova**.
2. Desde 05/11 a trava `trg_transacoes_legado_imutavel` (marcador `connect_financeiro_encerrado`) **recusa o INSERT** de qualquer `transacoes` com `cod_itens_duplicata`. Ensaio: o INSERT da duplicata da Omega como o importador faria falha com "Financeiro encerrado para carga da Connect (05/11/2026)". Como o importador grava tudo numa transação única, **uma duplicata nova na planilha derruba a execução inteira** (rollback total); o trigger só barra INSERT, então as atualizações de duplicatas que já existem passam.
3. Para ver o que aconteceria sem a trava, o ensaio removeu o marcador **só dentro da transação** (ROLLBACK depois; o marcador continua lá): o importador só escreve em `negociacoes`/`transacoes`; **nada nasce em `financeiro_titulos`** (a contagem de parcelas pagas de ~R$ 2.608,52 da Omega no financeiro novo continua 1). O risco de segunda saída ficaria nos relatórios que ainda leem `transacoes` (provável soma da transação da Connect com a antecipação `pa:` de `vw_contas_pagar_pedidos_compra`; não verifiquei cada relatório); há 1 antecipação nativa candidata (mesmo fornecedor, empresa, valor e data ±3 dias).
4. **Proposta (aguarda confirmação):** (a) não mexer no importador enquanto a trava de 05/11 existir; (b) acrescentar à conferência de integridade um aviso "antecipação nativa sem duplicata correspondente / duplicata da Connect equivalente a antecipação nativa sem vínculo" (mesmo fornecedor, empresa, valor ±R$ 0,01 e data ±3 dias), só leitura; (c) se a trava for um dia levantada, o importador passa a, ao inserir despesa paga com antecipação nativa equivalente e sem vínculo, gravar a ligação (nova coluna/tabela de "espelhada") em vez de tratá-la como saída nova, e o relatório do dashboard exclui a espelhada. A implementação do (c) mexe em script de produção e fica para a sua decisão.

## Correções do revisor (12/11/2026, ainda na migration 345, que não foi aplicada)

- **Falha silenciosa na detecção (tela):** se a consulta `pagamentos_existentes_para_entrada` falhar, a Entrada de NF mostra "Não consegui consultar pagamentos já feitos; não registre como pago sem falar com o Financeiro", limpa os vínculos marcados e bloqueia a opção "já foi pago" (caixa desabilitada e o envio fica recusado se já estava marcada). Resposta atrasada (troca de pedido ou de fornecedor da nota) é descartada por flag `ativo` no efeito.
- **Sem pré-marcação:** nada vem marcado; vincular é confirmação humana. A tela destaca "valor igual ao do pedido" e, se houver **outro pedido aberto do mesmo fornecedor/empresa com valor parecido** (±R$ 1,00), avisa "Atenção: o pedido aberto X ... confira qual compra este pagamento quitou" (a RPC devolve a coluna `outros_pedidos`).
- **RPC mais estrita (a RPC é a defesa real):** `registrar_entrada_nota_compra` agora (1) recusa duplicata paga fora da mesma janela da lista de candidatos (paga a partir de emissão do pedido − 3 dias); (2) aplica o teto: Σ vínculos ativos do pedido + antecipações aplicadas a notas ativas do pedido ≤ `valor_total` + R$ 0,01 (testado também somando antecipação nativa); (3) confere o fornecedor com `IS DISTINCT FROM` contra o fornecedor **da nota** (`v_forn`): com fornecedor trocado na entrada, só vale a duplicata do fornecedor novo, a do antigo é recusada.
- **Aviso e selo:** "falta vincular" só para pedido **aberto** (nem `recebido` nem `cancelado`), sem antecipação do sistema, sem vínculo e sem nota ativa já coberta por antecipação. O selo "Pago antecipado (dup. X)" continua aparecendo em qualquer pedido não cancelado (inclusive `recebido`), porque é o rastreio do que foi vinculado; se preferir esconder nos concluídos, é só filtrar na RPC.
- **Permissão de `pedidos_pago_antecipado_info`:** passa a usar a ação `'visualizar'` de `necessidade-de-compra` (antes `NULL`), para não dar exceção a quem tem permissão granular.
- **Previsão com vínculo parcial (item 2 do revisor): ACEITO como defasagem temporária.** A previsão do pedido (`financeiro_ponte_pedido` / `vw_contas_pagar_pedidos_compra`) desconta o valor da nota, não a parte coberta pelo pagamento já existente; com vínculo parcial a previsão fica momentaneamente mais alta do que o devido até as parcelas da nota entrarem. É o lado conservador (aparece mais a pagar, nunca menos) e some quando as parcelas do restante são lançadas.
- **Ensaio (dry_run.sql, agora 83 verificações, bloco 6 novo):** janela (pedido emitido hoje recusa a 8405; borda emissão − 3 dias entra; a lista de candidatos segue a mesma janela), teto (vínculo 1.200 em pedido de 1.000 recusado e nada gravado; antecipação nativa 500 + vínculo 600 recusado; 500 + 500 passa), fornecedor trocado (duplicata do fornecedor antigo recusada e lista recalculada sem a 8405), pedido `recebido` Antecipado sem aviso e aberto com aviso, `outros_pedidos` na detecção. Dry-run completo e `rollback.sql` reensaiados (funções, view e ACL voltam idênticas ao original). `vite build` (Compras; Contas a Pagar `pagar` e `receber`) ok, `tsc --noEmit` com os mesmos 6 e 41 erros de antes (outros arquivos), `oxlint` sem aviso novo nos arquivos alterados.
