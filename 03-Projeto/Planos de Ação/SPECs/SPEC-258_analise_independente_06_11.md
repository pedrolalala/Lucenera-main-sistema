# SPEC-258 — Análise independente (entrega "a"): divergências e achados novos

> 06/11/2026, segunda análise (modelo Opus 5.5), feita sem confiar na SPEC v2. Somente leitura: nada aplicado, nada enviado.

## 1. Baseline
Igual a 06/11 em todos os números (18.316 linhas / R$ 75.203.769,77 na `v_financeiro_realizado`; 16.968 pagamentos; contagens por tipo e situação idênticas). Sem lançamento novo durante a análise.

## 2. Achados que mudam o desenho

| # | Achado (medido) | Impacto |
|---|---|---|
| A1 | Renegociação/acordo massivo no legado: `tipo_pagamento` "Duplicata Gerada" 2.538 parcelas (R$ 16,37 mi: 827 abertas, 321 pagas, 1.390 canceladas), "Acordo" 293, "Acordo Valor Zerado" 489, "DEV TROCA" 876; coluna `transacoes.acordo` (inteiro) agrupa as parcelas de cada acordo (2.832 linhas com acordo ≠ 0). | O desenho v2 não tinha renegociação. |
| A2 | 2.784 parcelas "pagas" com `vl_pago` = 0 (R$ 10,76 mi): receita 1.818 (Carteira 935 R$ 3,89 mi; Acordo Valor Zerado 489; Boleto 234 R$ 2,06 mi; Duplicata Gerada 83; Acordo 64; Banco 12; Dinheiro 1); despesa 966 (DEV TROCA 713 R$ 2,56 mi; Duplicata Gerada 238; vazio 14; Antecipação Gerada 1). Também pagas acima do valor 137/20 e abaixo 99/11. | Nem todo "pago" é dinheiro: compensação, renegociação, perdão, ou valor não informado. "Conta bancária em toda baixa" não vale. |
| A3 | 3.020 parcelas CANCELADAS com `vl_pago` > 0 e data de pagamento (R$ 9,36 mi): receita 2.919 (Pix 2.213 R$ 6,70 mi; Dinheiro 691 R$ 2,18 mi; Cheque 15), despesa 101. | Hipótese: parcelas renumeradas pela Connect e canceladas pelo importador ("parcelas órfãs"), com a nova também paga. Migrar como baixa contaria recebimento em dobro. Exige conciliação com `connect_contas_espelho`. |
| A4 | `v_financeiro_realizado` exclui 349 parcelas NÃO canceladas (R$ 1,35 mi): despesa 267 (R$ 1,10 mi), receita 82 (R$ 252 mil) — duplicata repetida em outra empresa (`rn > 1`) ou fora de `stg_duplicatas_vigentes`. | Migração 1:1 inflaria os totais e quebraria a prova do baseline. Classificar antes. |
| A5 | `cron` job 8 apaga `auditoria.eventos` com mais de 12 meses (hoje 4.673 eventos, desde 17/04/2026). | Histórico de alterações financeiras não pode depender da auditoria. |
| A6 | Escrita direta sem regra: CRM `services/projetos.ts` (update `projeto_parcelas`); RH `EmployeeFinance.tsx`/`services/funcionarios.ts` (update `folha_pagamento`; insert/update/**delete** `funcionarios_financeiro`); retorno-bancário `Boletos.tsx`, `CadastrarDuplicata.tsx`, `Index.tsx` (update/upsert `boletos`); função `processar_retorno_bancario` (atualiza `transacoes`). RPCs de dinheiro usadas: Compras 16, Orçamentos 21, retorno-bancário 4. | A porta única só vale se a escrita direta for bloqueada (privilégio só por função) e esses escritores religados. |
| A7 | "Folha só RH" × fluxo de caixa precisar da despesa de salário. | Falha do v2: fluxo vê total da folha por mês sem nomes; detalhe só RH. |
| A8 | 305 pagamentos com conta bancária de OUTRA empresa; "Caixa Empresa" sem `empresa_id`. | Precisa de regra de multiempresa e de caixa compartilhado. |
| A9 | `contas_bancarias.saldo` é saldo guardado. | Mais um "lugar com dinheiro"; deve ser derivado das baixas e conciliado com extrato. |
| A10 | A view atual restringe "distribuição de lucro" (`pode_ver_distribuicao_lucro`). | Manter no modelo novo (o v2 não citava). |
| A11 | Falta de-para id antigo → id novo. | Auditoria, `comprovante_url`, `retorno_bancario_registros`, `notas_fiscais.boleto_id` apontam para ids antigos. |
| A12 | Formas não tratadas: Cartão 556, Cheque 69. | Cartão: quem paga é a adquirente, com taxa. Cheque: pode ser pré-datado (custódia). |
| A13 | Origens a ligar: `orcamentos.plano_parcelas`, `valor_sinal`, `data_base_vencimento`; `contatos.limite_credito`; `devolucoes_estoque.gera_credito_financeiro`. | Origem do dinheiro, não armazenamento; precisa de vínculo. |
| A14 | Edge Function `sync-fechamentos-automatica` (grava `projeto_parcelas`) copiada em 7 sistemas; descontinuada (SPEC-004) e ausente no remoto. Nenhum `cron` toca o financeiro. | Inofensiva hoje; remover as cópias antes da virada (já houve republicação automática de funções antigas). |
| A15 | `plano_de_contas` tem coluna `tipo` (níveis 1/2/3: 5/16/138). | Permite a regra de coerência natureza × plano no nativo. |

## 3. Mudanças no desenho (para a v3)
1. Baixa com tipos: `recebimento`/`pagamento` (dinheiro; conta bancária obrigatória), `compensacao` (devolução/troca, permuta, adiantamento, crédito), `renegociacao` (aponta para as parcelas novas), `abatimento` (perdão/acordo valor zerado; motivo + autorização), `estorno`.
2. Parcela com situação `renegociada`; tabela `financeiro_renegociacoes` (parcelas de origem → títulos/parcelas novas), migrada a partir de `transacoes.acordo`.
3. Histórico financeiro próprio e permanente (`financeiro_eventos`) ou excluir o financeiro do expurgo de 12 meses.
4. Tabela de de-para `financeiro_legado_ids` (tabela antiga, id antigo, id novo).
5. Escrita direta proibida (só funções `SECURITY DEFINER`); religar todos os escritores da A6.
6. Folha agregada no fluxo; detalhe só RH; manter a restrição da distribuição de lucro.
7. Saldo bancário derivado; regras de multiempresa e caixa compartilhado.
8. Migração não é 1:1: classificar antes as 349 (A4), as 3.020 (A3) e as 2.784 (A2).

## 4. Correções a afirmações anteriores
- "Conta bancária obrigatória em toda baixa" — errado (A2).
- "transacoes → parcelas 1:1" — errado (A3, A4).
- "A auditoria guarda o histórico" — errado (A5).
- "Folha só RH, sem exceção" — incompleto (A7).

## 5. Incertezas
- A3 é hipótese; só a conciliação com o espelho confirma.
- A8: os 305 pagamentos cruzados podem ser acordo legítimo (os scripts citam "empresa trocada para acordo de RT") ou erro de lançamento.
