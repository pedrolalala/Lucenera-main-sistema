---
titulo: "SPEC-322 — Compensação (permuta) entre Contas a Pagar e Contas a Receber da mesma pessoa"
status: pendente
data_ultima_modificacao: 2026-11-17
sistemas_envolvidos:
  - Contas a Pagar (retorno-bancario-bradesco-5392a, build pagar)
  - Contas a Receber (retorno-bancario-bradesco-5392a, build receber)
  - Banco (financeiro_baixas / financeiro_parcelas)
---

# SPEC-322 — Compensação (permuta) entre Contas a Pagar e Contas a Receber da mesma pessoa

## Checklist de Ação

- [x] Conferir no banco real (leitura) como as contas de `boletos` (CP/CR) aparecem no modelo novo (`financeiro_parcelas`) e se a baixa `compensacao` já é aceita pelas views/telas de consulta e de caixa.
- [x] Migration 383 (rascunho, NÃO aplicada; ensaio em ROLLBACK ok): coluna `financeiro_baixas.compensacao_id` + RPC `financeiro_compensar(p_parcela_pagar, p_parcela_receber, p_valor, p_motivo, p_data)` que grava 2 baixas `compensacao` ligadas (uma em cada parcela), sem conta bancária e sem mexer no caixa.
- [x] RPC de listagem (`financeiro_compensacao_candidatas`): títulos em aberto da mesma pessoa (`contato_id`) do lado oposto, com saldo.
- [x] Tela (NO AR 17/11, 12ea9d4): botão Compensar em Consultar Duplicatas (Pagar e Receber), `CompensarModal` com compensação parcial e várias contas; aba "Registrar o serviço e compensar" (parte de uma conta a receber).
- [x] Opção 1: Cadastrar Duplicatas do Contas a Pagar passa a gravar no financeiro novo (`financeiro_cadastrar_conta_manual`); conta antiga (boletos) segue editando pelo caminho antigo.
- [x] RPC de estorno `financeiro_estornar_compensacao` (as duas baixas juntas); o Estornar da consulta (`estornarParcelas`) já estorna a compensação inteira.
- [ ] Atualizar `CHANGELOG.md`, `AI_DB_CONTEXT.md` do sistema e esta SPEC.

### Passos manuais do usuário

- [x] Migration aprovada e aplicada.
- [ ] Testar com o caso real (Leonardo Agostinho Bermudes) e conferir com a Carol.

## Objetivo

Caso real (17/11/2026): o Leonardo Agostinho Bermudes é prestador de serviços, fez um serviço para a empresa em permuta, e a empresa tem valores a receber dele. Em vez de lançar um Contas a Receber **negativo**, registrar o serviço em Contas a Pagar normalmente e **compensar** os dois lados (sem dinheiro), quitando total ou parcialmente cada um.

## Decisões aprovadas

- Não criar valor negativo em Contas a Receber (a alteração de 17/11 em `CadastrarDuplicata.tsx` foi descartada).
- Serviço entra em Contas a Pagar como duplicata normal; a compensação é uma ação à parte, ligada aos dois lados.
- Compensação parcial permitida: o saldo continua em aberto no lado que sobrou.
- As duas baixas ficam ligadas e registradas no log, com motivo obrigatório.
- A compensação não movimenta caixa nem exige conta bancária (`financeiro_baixas.tipo = 'compensacao'`, já previsto no modelo, `movimenta_caixa = false`).
- Mantido como proteção: a Remessa ignora boleto de valor negativo (`Remessa.tsx`, filtro `valor > 0`).

## Definição da SPEC

- Regra: só entre parcelas em aberto da **mesma pessoa** (`contato_id`); valor compensado <= menor saldo entre as duas; mesma empresa do grupo por padrão.
- Fluxo: Contas a Pagar → conta do serviço → "Compensar" → lista de contas a receber em aberto da pessoa → escolher e informar valor → motivo → confirmar → 2 baixas `compensacao` (mesmo identificador de compensação).
- Estorno: desfaz as duas baixas de uma vez (usa `estorno_de`).
- Segurança: função `SECURITY DEFINER`, `REVOKE ALL ... FROM PUBLIC, anon`, permissão `financeiro` (AGENTS.md), trava de papel com `IS DISTINCT FROM`.
- Teste obrigatório: ensaio em ROLLBACK como usuário `financeiro` e como usuário sem o sistema.

## Achados da conferência no banco (17/11/2026, só leitura)

- O a receber do Leonardo (contato `d4ce33fa-...`) já está no modelo novo: 3 títulos `legado_connect`/`venda` em `financeiro_titulos`, saldo total R$ 1.686,99 (= −910,00 − 776,99 da tela). Não há boleto dele em `boletos`.
- A baixa `compensacao` já existe no modelo (enum `fin_baixa_tipo`, `movimenta_caixa = false`, motivo obrigatório) e há 4 usadas em acordos. `financeiro_baixar` aceita o tipo, mas não liga duas baixas; baixa é imutável (trigger), então o vínculo `compensacao_id` nasce no INSERT.
- **Cuidado:** a tela Cadastrar Duplicatas (Contas a Pagar) grava na tabela antiga `boletos`. Os 63 boletos CP existentes não têm espelho em `financeiro_parcelas`, então uma duplicata cadastrada por essa tela NÃO seria vista pela compensação. A conta a pagar do serviço precisa nascer no modelo novo (`financeiro_criar_titulo`, origem `manual`, exige `plano_contas_id`) — ou a tela de cadastro passa a usar essa RPC.
- Ensaio em ROLLBACK (Leonardo, a pagar de teste R$ 500 x a receber): compensar R$ 300 deixa saldos 200,00 e 1.386,99; nenhuma baixa movimenta caixa; valor acima do saldo é recusado; estorno devolve 500,00 e 1.686,99. Nada ficou gravado.

## Realizado

### 2026-11-17

- Conferência no banco e migration `20261117_383_spec322_compensacao_permuta` (up/rollback/dry_run) com 5 funções: candidatas, compensar, estornar compensação, cadastrar conta manual (opção 1) e compensar criando a conta (opção 2). Ensaiada em ROLLBACK com o Leonardo; APLICADA em 17/11 (conferida).
- Migration 383 aplicada e telas publicadas por wrangler: contas-pagar-lucenera (cd4af9b1) e contas-receber-lucenera (e566a640).
- Decisões da opção 1: conta nova do Pagar exige Fornecedor e Apropriação, nasce Aberta (para registrar como paga: baixar na consulta); Conta bancária não é gravada no cadastro; linha digitável vai na observação.

## Pendências

- [ ] Definir se a ação nasce só em Contas a Pagar ou também em Contas a Receber (proposta: as duas, mesma função).
- [ ] Definir se a compensação vale entre empresas diferentes do grupo (proposta: só mesma empresa nesta primeira versão).
- [ ] Testar no caso do Leonardo e conferir com a Carol; checar nas outras telas (Contas em Aberto, fluxo de caixa) se a conta manual nova do Pagar aparece como esperado.
