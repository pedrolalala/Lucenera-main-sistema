---
titulo: "SPEC-297 — Contas a Receber/Pagar: devolução aparecia 2x e Editar/Apagar conta com justificativa e log"
status: migration 354 APLICADA em 13/11/2026; tela commitada (f8b93cf no repo Retorno Bancário), deploy pendente
data_ultima_modificacao: 2026-11-13
sistemas_envolvidos:
  - Contas a Receber / Contas a Pagar (04-Sistemas/retorno-bancario-bradesco-5392a, mesmo código, modo no build)
  - Banco (vw_financeiro_duplicatas, financeiro_parcelas, financeiro_titulos, boletos, auditoria.eventos)
---

# SPEC-297

**Origem:** solicitação da Carol na Central em 13/11/2026 13:57, "ORÇAMENTO DE DEVOLUÇÃO DUPLICOU CONTAS A RECEBER" (orçamento 0042, 2 contas negativas), e pedido do usuário: habilitar editar e apagar contas a receber e a pagar, com pop-up de justificativa e log.

## Causa da duplicação (verificada no banco)
A aprovação da devolução cria **dois registros** para a mesma parcela: o título novo do financeiro (`ORC-0042`, -123,23) e o boleto "Nota de Crédito" (`ORC-0042-P1`, -123,23). A view `vw_financeiro_duplicatas` só ligava boleto a parcela pela rota das vendas (`transacoes`); na devolução o elo é `financeiro_legado_ids 'projeto_parcelas'`, que a view não olhava. Sem o elo (`boleto_id` nulo) a tela somava as duas linhas. Não há título duplicado: no banco só existe 1 título e 1 parcela do ORC-0042.

## Feito (migration 354, aplicada)
- [x] A. View ganhou o 3º ramo do `boleto_id` (devolução → boleto "Nota de Crédito"). Com o elo, a tela esconde a linha do financeiro e mostra só o boleto. Vale já sem deploy. `security_invoker=true` mantido (o revisor pegou que `CREATE OR REPLACE VIEW` zerava essa opção).
- [x] B. `financeiro_editar_parcela(parcela, vencimento, valor, descrição, motivo)`: justificativa obrigatória; permissão `financeiro_exige`; só parcela aberta e sem baixa; não troca sinal; **recusa conta de venda/devolução do sistema** (as pontes `transacoes`/`projeto_parcelas` refariam o valor); contas da Connect e notas de compra podem ser editadas; boleto ligado só muda se ainda não foi registrado/enviado ao banco.
- [x] C. `financeiro_apagar_parcela(parcela, motivo)`: **cancela** a parcela (e o título, se for a última) em vez de apagar o histórico; remove o boleto ligado só se não registrado/pago/usado, copiando antes para `backup.spec297_boletos_apagados`.
- [x] D. `boleto_apagar_avulso(boleto, motivo)`: boleto sem parcela no financeiro, mesma trava e backup; recusa boleto de venda/devolução.
- [x] E. Log em `auditoria.eventos` (`editou_conta` / `apagou_conta`, com motivo, antes/depois, usuário e data).
- [x] F. Tela (Consultar Duplicatas): botão **Apagar** novo e **Editar** liberado para contas do financeiro, ambos com pop-up de justificativa obrigatória.
- [ ] G. Deploy dos dois modos (`VITE_MODO_SISTEMA=receber` e `pagar`) → contas-receber-lucenera / contas-pagar-lucenera.
- [ ] H. Carol/financeiro testar.

## Limites conhecidos (do revisor)
- Apagar conta de venda aprovada cancela no financeiro novo, mas `transacoes`/`projeto_parcelas` legados seguem ativos (inconsistência de relatório legado, não reabre).
- `financeiro_cobrancas` do boleto apagado pode ficar órfã (não limpei).
- Um boleto `NFC-%` apagado pode ser recriado se a nota de compra for reprocessada.

## Ensaio (ROLLBACK)
Passou: sem acesso ao financeiro recusado, sem motivo, troca de sinal, anon, edição de devolução recusada, edição de conta da Connect (valor+vencimento+log), apagar (parcela cancelada, título cancelado, boleto no backup, log), apagar duas vezes recusado, boleto avulso.

## Rollback
`rollback.sql` da 354 (restaura a view e remove as 3 funções; a tabela de backup fica).
