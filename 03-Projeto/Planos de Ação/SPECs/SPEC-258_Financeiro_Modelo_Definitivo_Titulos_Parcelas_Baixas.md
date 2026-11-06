---
titulo: "SPEC-258 — Financeiro: modelo definitivo (títulos, parcelas, baixas e cobranças) — uma fonte de verdade para contas a receber e a pagar"
status: não iniciado
data_ultima_modificacao: 2026-11-06
sistemas_envolvidos:
  - Banco (Supabase SP) — financeiro
  - Orçamentos, Compras, Contas a Pagar, Contas a Receber, Adm. Bancária (CNAB), Dashboard Financeiro, RH (folha)
---

# SPEC-258 — Financeiro: modelo definitivo

> Origem: pedido do usuário (06/11/2026): "negociações e transações deixam o armazenamento em aberto; quero receita, despesa, receita prevista e despesa prevista bem específicas; as informações são 100% geradas no nosso sistema (orçamento gera a receber, necessidade de compra e pedido de compra geram a pagar); já sabemos como a empresa funciona, vamos definir um bom backend".
> **Absorve** as partes 4b–4d da SPEC-246 (estrutura alvo) e a opção B da SPEC-248 item 3. Esta SPEC é **só planejamento**: nada foi aplicado.

## 1. Diagnóstico (medido no banco em 06/11/2026)

**Hoje existem 7 estruturas paralelas guardando dinheiro, cada uma com o seu próprio "pago":**

| Estrutura | O que guarda | Linhas |
|---|---|---|
| `negociacoes` + `transacoes` | duplicata + parcela (Connect até 05/11; nativo depois) | 14.028 / 23.338 |
| `projeto_parcelas` | parcela da venda (orçamento aprovado), com data/valor pago | 387 |
| `boletos` | cobrança bancária **e** contas a pagar cadastradas à mão | 4 |
| `pedido_compra_parcelas` | parcela do pedido de compra (previsão) | 70 |
| `nota_fiscal_compra_parcelas` | parcela da NF de compra | 3 |
| `custos_recorrentes_lancamentos` | lançamento mensal de custo fixo (com juros/multa/desconto próprios) | 0 |
| `folha_pagamento` | salário líquido do mês | 771 |
| (+ `pagamentos_antecipados`) | adiantamento a fornecedor | 0 |

Consequências reais: **uma venda aprovada fica em 3 lugares** (`projeto_parcelas`, `boletos` e, por gatilho, `transacoes`), cada um com situação própria; a compra tem um caminho diferente da venda; **só cabe um pagamento por parcela** (pagamento parcial, estorno e histórico de baixas não existem); **"prevista" não existe**; "receita/despesa" mistura dois eixos; nomes herdados da Connect ("negociação", "transação") não dizem o que são.

Consumidores dos nomes antigos (risco da troca): **2 sistemas** (dashboard e retorno-bancário), 11 funções, 6 views e 16 scripts Python.

## 2. Princípios

1. **Uma fonte de verdade por fato.** A obrigação e a agenda vivem num lugar; o pagamento real (baixa) vive noutro; a cobrança bancária é só instrumento.
2. **O "pago" só existe em `baixas`.** A situação "liquidada" é **derivada** (soma das baixas cobre o valor), nunca digitada.
3. **Dois eixos explícitos**, sem misturar: **natureza** (a receber ou a pagar) × **situação** (prevista, firme, liquidada, cancelada).
4. **Porta única.** Todo dinheiro nasce por funções do banco (`financeiro_criar_titulo` etc.), com as mesmas regras; os sistemas não gravam direto nas tabelas.
5. **Origem rastreável e idempotente.** Cada título aponta para o que o gerou; o mesmo orçamento/pedido/NF nunca gera duas vezes.
6. **Nada se apaga:** cancela-se (com motivo) e a auditoria guarda o antes/depois.
7. **Legado da Connect entra no mesmo modelo**, com ids da Connect imutáveis em colunas `legado_*`.

## 3. Estrutura

**3.1 `financeiro_titulos`** (a obrigação; substitui `negociacoes`)
`id`, `natureza` (`receber`|`pagar`), `origem_tipo`, `origem_id`, `origem_seq`, `especie` (venda, credito_devolucao, compra, nota_compra, adiantamento, despesa, salario, rt_arquiteto…), `empresa_id` (obrigatório), `perfil` (ribeirão/são paulo), `contato_id`/`funcionario_id` (a pessoa, com tipo coerente), `plano_contas_id` (a classificação contábil receita/despesa), `projeto_id`, `orcamento_id`, `pedido_compra_id`, `nota_fiscal_compra_id`, `documento` (nº NF/venda), `descricao`, `substitui_titulo_id` (previsão que este título firme substitui), `cancelado_em/por/motivo`, `legado_cod_duplicata` (imutável), `criado_em/por`.
Único: `(origem_tipo, origem_id, origem_seq)` quando `origem_id` não é nulo.

**3.2 `financeiro_parcelas`** (a agenda; substitui a parte "agenda" de `transacoes`, `projeto_parcelas`, `pedido_compra_parcelas`, `nota_fiscal_compra_parcelas`, `custos_recorrentes_lancamentos`)
`id`, `titulo_id`, `numero`, `vencimento`, `valor`, `situacao` (`prevista`|`firme`|`cancelada`|`substituida`), `confirmada_em/por` (quando virou firme), `forma_prevista`, `valor_baixado` (mantido por gatilho a partir das baixas), `legado_cod_itens_duplicata` (imutável).
Único `(titulo_id, numero)`.

**3.3 `financeiro_baixas`** (o fato real; **novo**)
`id`, `parcela_id`, `tipo` (`pagamento`|`recebimento`|`compensacao`|`estorno`), `data`, `valor`, `juros`, `multa`, `desconto`, `forma`, `conta_bancaria_id`, `cobranca_id`, `comprovante_url`, `origem_baixa` (`manual`|`retorno_bancario`|`antecipacao`|`legado`), `estorno_de`, `criado_em/por`.
Permite pagamento parcial, várias baixas por parcela, estorno e o histórico de contas pagas completo.

**3.4 `financeiro_cobrancas`** (instrumento; absorve `boletos`)
`id`, `parcela_id`, `meio` (`boleto`|`pix`|`cartao`|`deposito`|`carteira`), `nosso_numero`, `linha_digitavel`, `remessa_sequencial`, `conta_bancaria_id`, `status_banco`, valores/vencimento da cobrança. O **retorno bancário gera baixa**; a cobrança não é fonte do valor nem do "pago".

**3.5 Enumerações:** `fin_natureza`, `fin_situacao`, `fin_origem` (orcamento, pedido_compra, nota_fiscal_compra, manual, custo_recorrente, folha, permuta, adiantamento, rt_arquiteto, legado_connect).

## 4. Os quatro nomes que o negócio usa (views)

| | Prevista | Firme | Liquidada |
|---|---|---|---|
| **A receber** | **Receita prevista** | A receber | **Receita realizada** |
| **A pagar** | **Despesa prevista** | A pagar | **Despesa realizada** |

"Receita/despesa" contábil = classificação do **plano de contas**. Views: `vw_contas_a_receber`, `vw_contas_a_pagar`, `vw_historico_baixas` (histórico de contas pagas/recebidas), `vw_fluxo_caixa` (por mês e dia: receita prevista, receita realizada, despesa prevista, despesa realizada, saldo), `vw_financeiro_integridade`. Derivados: **vencida** = firme com vencimento passado e saldo; **parcial** = baixas < valor.

## 5. Como cada origem alimenta (todas pela porta única)

| Origem | Gera | Situação | Regra |
|---|---|---|---|
| **Orçamento** (venda) | a receber, espécie venda | prevista na aprovação da equipe → **firme** na aprovação financeira | cobranças (boleto/pix/cartão) criadas junto; carteira/permuta sem boleto |
| **Pagamento no ato** (Pix com comprovante, SPEC-254) | baixa na parcela | liquidada | a baixa nasce já com o comprovante |
| **Devolução** | título a receber espécie `credito_devolucao` (valor negativo, só nessa espécie) | firme | compensa a venda de origem |
| **Permuta** | contrapartida a pagar ligada | firme | `origem_tipo = permuta` |
| **Necessidade de compra** | a pagar, espécie compra | **prevista** | valor estimado |
| **Pedido de compra aprovado** | a pagar (as parcelas do pedido **viram** parcelas do financeiro) | prevista | `pedido_compra_parcelas` deixa de guardar dinheiro: guarda só a condição de pagamento |
| **NF de entrada** | a pagar, espécie nota_compra | **firme** | com vencimento real; **substitui** a prevista do pedido (`substitui_titulo_id`) sem contar duas vezes |
| **Adiantamento a fornecedor** | título a pagar já com baixa | liquidada | `compensacao` abate a NF quando ela entrar |
| **Custo recorrente** | uma prevista por mês | prevista → firme no vencimento/confirmação | o cadastro de recorrência gera os meses |
| **Folha** | a pagar (por funcionário/mês) | firme | pessoa = funcionário |
| **Lançamento manual** | a pagar ou a receber | prevista (com check) ou firme | |
| **RT do arquiteto** | a pagar | prevista quando a venda é recebida | **a confirmar com o negócio** |
| **Legado Connect** | título + parcelas + baixas | firme/liquidada/cancelada conforme estava | `origem_tipo = legado_connect`, ids imutáveis |

## 6. Regras de integridade (no banco)

- Natureza coerente com a origem (venda → receber; compra/NF/folha/recorrente → pagar).
- `empresa_id` obrigatório; pessoa com tipo compatível; plano de contas: **alerta** para legado, **trava** para lançamento nativo.
- Valor > 0 (exceto espécie crédito); `numero` único por título; baixa não entra em parcela cancelada ou substituída; soma das baixas controlada pelo gatilho.
- Colunas `legado_*` imutáveis; nada é apagado (cancelar com motivo); auditoria do banco em todas as tabelas.
- Idempotência por origem (o mesmo orçamento/pedido/NF não duplica).
- Permissão: `pode_acessar_sistema('financeiro')` nas funções; RLS ligado e `anon` sem acesso.

## 7. Porta única (funções)

`financeiro_criar_titulo`, `financeiro_confirmar_parcelas` (prevista → firme), `financeiro_substituir_previsao`, `financeiro_baixar_parcela`, `financeiro_estornar_baixa`, `financeiro_cancelar_titulo`, `financeiro_definir_previsao`. Os sistemas só chamam estas.

## 8. Migração (sem quebrar ninguém)

**Baseline para provar que nada mudou (06/11/2026):** `v_financeiro_realizado` = **18.316 linhas**, soma **R$ 75.203.769,77**; `transacoes` = 23.338 (receita aberta 459, paga 4.592, cancelada 3.602; despesa aberta 1.238, paga 12.376, cancelada 1.071); **16.968 pagamentos** no histórico.

1. **Fase 0:** decidir os pontos da seção 10 e aprovar esta SPEC.
2. **Fase 1:** criar as tabelas, enums, funções e views novas **vazias** (ensaio com ROLLBACK).
3. **Fase 2:** migrar o legado: `negociacoes` → títulos; `transacoes` → parcelas + baixas (parcela paga gera a baixa com data, valor, juros, desconto e forma); conferir **os mesmos totais** por tipo, situação e mês.
4. **Fase 3:** `negociacoes`, `transacoes`, `projeto_parcelas`, `boletos`… viram **views de compatibilidade** com os nomes antigos; dashboard, retorno-bancário, as 11 funções, as 6 views e os 16 scripts passam a ler o modelo novo, um por vez.
5. **Fase 4:** ligar as portas nativas: orçamento (troca o destino do gatilho atual), compra e NF, manual, recorrentes, folha.
6. **Fase 5:** tela do Fluxo Futuro com as quatro colunas; remover as estruturas antigas só depois de um período sem leitura.

A migration 301 (`transacoes.previsao`) é **passo intermediário**: a situação `prevista` a substitui na Fase 2.

## 9. Efeito sobre outras SPECs

- **SPEC-246:** 4b–4d substituídas por esta estrutura; 4a (mapa de pessoas), 4g (integridade) e 4h (marco) continuam valendo.
- **SPEC-248 item 3:** a Previsão passa a ser a situação `prevista`; o cadastro do Contas a Pagar grava pela porta única.
- **SPEC-254 (comprovante) e Compras (SPEC-209/215/222):** passam a usar baixa e a substituição de previsão.

## 10. Decisões de negócio ainda necessárias

1. Receita **prevista** na aprovação da equipe e **firme** na aprovação financeira — confirma?
2. Despesa: necessidade de compra gera **prevista**, pedido aprovado continua prevista, NF de entrada torna **firme** e substitui — confirma?
3. **RT do arquiteto** é uma conta a pagar que o sistema deve gerar? Em que momento (venda recebida? proporcional ao recebido?).
4. **Folha** entra como a pagar por funcionário/mês?
5. Uma tabela de títulos com `natureza` + duas views (recomendado) ou duas tabelas separadas?
6. Migrar o legado da Connect para o modelo novo (recomendado) ou deixá-lo nas tabelas antigas só para consulta?
7. Crédito de devolução: título com valor negativo (proposto) ou compensação direta contra a venda?

## Checklist de Ação

- [ ] Decidir os pontos da seção 10 (usuário).
- [ ] Aprovar a SPEC.
- [ ] Fase 1: migrations das tabelas, enums, funções e views (ensaio).
- [ ] Fase 2: migração do legado com conferência de totais.
- [ ] Fase 3: views de compatibilidade e troca dos consumidores.
- [ ] Fase 4: portas nativas (orçamento, compra/NF, manual, recorrentes, folha).
- [ ] Fase 5: tela do Fluxo Futuro e remoção das estruturas antigas.

## Realizado

### 2026-11-06

- Levantamento no banco e escrita desta SPEC (nada implementado/aplicado).

## Pendências

- [ ] Resposta do usuário aos pontos da seção 10 para começar a Fase 1.
