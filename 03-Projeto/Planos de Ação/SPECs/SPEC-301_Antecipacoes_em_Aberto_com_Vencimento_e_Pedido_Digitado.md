---
titulo: "SPEC-301 — Antecipações (Contas a Pagar e a Receber): sem baixa automática, vencimento e nº do pedido digitado"
status: migration 358 escrita e ENSAIADA (rollback), NÃO aplicada; telas alteradas no repo Retorno Bancário, sem deploy
data_ultima_modificacao: 2026-11-13
sistemas_envolvidos:
  - Contas a Pagar / Contas a Receber (04-Sistemas/retorno-bancario-bradesco-5392a)
  - Banco (pagamentos_antecipados, vw_pagamentos_antecipados, financeiro_espelhar_pagamento_antecipado, financeiro_lancar_antecipacao, lancar_pagamento_antecipado)
---

# SPEC-301

**Origem:** Central de Solicitações, Carol, 13/11/2026 16:53, "ANTECIPAÇÕES" (id e32712ee-8b38-4afc-9659-910083e7d021), com print "antecipações de duplicatas.png".
Texto: "Lançamentos de pagamentos antecipados (tanto receber quanto a pagar) não podem ser baixados automaticamente e no layout fazer as alterações conforme na imagem anexa."

## O que o print pede (tela Antecipações do Contas a Pagar)
- "Valor **pago** (R$)" → rótulo **"Valor do vencimento (R$)"** (confirmado pelo usuário).
- "Data do **pagamento**" riscado, escrito "vencimento" → **"Data do vencimento"**.
- "Pedido de compra (opcional)" com lista "Sem pedido" → **campo livre para digitar o nº do pedido**.

## Como era
- Pagar: `financeiro_espelhar_pagamento_antecipado` criava o título e já dava `financeiro_baixar(... 'pagamento')` na hora.
- Receber: `financeiro_lancar_antecipacao` também baixava na hora (`recebimento`), exigia conta bancária e proibia data futura.

## Feito (migration 358, ensaiada)
- [x] Pagar: título/parcela nascem **firmes, em aberto**, vencimento = data informada, sem baixa. Pode ser data futura. Baixa à mão em Consultar Duplicatas.
- [x] Receber: igual; a trava de data futura caiu e a conta bancária deixou de ser obrigatória (ela é escolhida na baixa).
- [x] Pedido digitado: coluna nova `pagamentos_antecipados.pedido_numero_manual`; `lancar_pagamento_antecipado` ganhou `p_pedido_numero` (assinatura trocada com DROP, sem sobrecarga). Se o número existe e não está cancelado, liga ao pedido (mesmo fornecedor obrigatório, senão recusa); se não existe (pedido antigo/Connect), grava só o texto. A view mostra `COALESCE(pedido, digitado)`.
- [x] Telas: rótulos, campo livre, cabeçalho "Vencimento", textos explicativos, formulário do Receber sem conta bancária/forma.
- [x] Revisor (2 críticos tratados na própria 358):
  - O "já foi pago" da Entrada de NF (SPEC-289) insere direto em `pagamentos_antecipados` e **continua baixando**: coluna nova `em_aberto_manual` (padrão false); só o painel de Antecipações grava true e nasce em aberto.
  - `vw_contas_pagar_pedidos_compra` (Dashboard, linha PAGAMENTO ANTECIPADO) deixou de contar como paga a antecipação em aberto: só conta quando há baixa na parcela (ou quando não é lançamento em aberto).
  - Pedido digitado que existe mas está cancelado agora é recusado (antes virava texto livre); desempate com ORDER BY.
  - Receber: a tela mostra "Em aberto" / "Recebida" / "Cancelada" e o saldo a compensar só aparece depois da baixa.
- [ ] Aplicar migration, deploy dos dois modos, teste da Carol.

## Não mexido
- Os 2 lançamentos do Pagar já existentes (04 e 05/11) ficam como estão, já pagos.
- A Entrada de NF continua usando o saldo da antecipação (tabela `pagamentos_antecipados`), agora com a antecipação ainda em aberto até a baixa.

## Pontos em aberto (decisão de negócio)
- A Entrada de NF pode abater e vincular uma antecipação que ainda não foi paga (a nota fica "coberta" por um pagamento futuro). Em Compras o texto "pago em" mostra agora o vencimento: confirmar com Carol/Débora e ajustar o rótulo.
- A compensação das antecipações do Receber (Fase 2, SPEC-270) deve exigir a baixa antes de usar o saldo.

## Rollback
`rollback.sql` da 358 devolve as 3 funções e a view; a coluna `pedido_numero_manual` fica.
