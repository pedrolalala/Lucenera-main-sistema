---
titulo: "SPEC-248 — Contas a Pagar: campo de valor, situação (Aberto/Pago/Cancelado) e previsão no fluxo de caixa"
status: pendente
data_ultima_modificacao: 2026-11-06
sistemas_envolvidos:
  - Contas a Pagar (retorno-bancario-bradesco-5392a, build `npm run build:pagar`, projeto Cloudflare contas-pagar-lucenera)
  - Dashboard Financeiro (dashboard-lucenera, Fluxo Futuro) — só no item 3
---

# SPEC-248 — Contas a Pagar: campo de valor, situação e previsão

> Pedido do usuário (06/11/2026), tela "Gerar Conta / Gerar Parcelas" do Contas a Pagar:
> 1. o campo de valor da conta está com o nome "Dia" — trocar o nome e colocar o cifrão (R$);
> 2. Situação: deixar **Aberto / Pago / Cancelado**; Cancelado é para DPL errada ou que mudou, sem excluir, e **não aparece na consulta de DPL em aberto**;
> 3. um check para marcar a conta como **previsão** (valor e data de pagamento podem mudar; serve para ter visão prévia); no **fluxo de caixa** as contas marcadas como previsão vêm **em outra coluna**, conforme desenho enviado antes.

## Checklist de Ação

- [x] 1. "Dia" → **Valor da parcela (R$)** em `CadastrarDuplicata.tsx` (**só no modo Pagar**; a Contas a Receber mantém o "Dia", decisão de 06/11 — o formulário é o mesmo código nos 2 sistemas e o push publica nos dois) (cada parcela adicionada já vem com o valor; vencimentos seguintes no mesmo dia do mês do "Venc 1° Parc"; cabeçalho da tabela "Valor da Parcela (R$)").
- [x] 2a. Situação só **Aberto / Pago / Cancelado** no cadastro do Contas a Pagar (Contas a Receber não mudou).
- [x] 2b. **Cancelado** não aparece em "A pagar (em aberto)", em "Vencido" nem nos totais da consulta; nova opção "Canceladas" na consulta (Pagar); a baixa não lista nem aceita duplicata cancelada.
- [ ] 3. Check **Previsão** + coluna própria no fluxo de caixa — **aguarda o desenho** e uma decisão de arquitetura (ver abaixo).
- [x] Publicar o Contas a Pagar (wrangler, `build:pagar`, variáveis de São Paulo) — NO AR 06/11 (deploy 3bd83b2f; bundle em São Paulo e textos novos conferidos em produção).

### Passos manuais do usuário

- [ ] Reenviar o **desenho do fluxo de caixa** com a coluna de previsão (não está no projeto).
- [ ] Decidir a arquitetura da previsão (item 3).
- [ ] Testar na tela do Contas a Pagar (já publicado): valor da parcela, situação, cancelar uma DPL e ver que sai de "A pagar (em aberto)".

## Decisões aprovadas (06/11/2026)

- "Dia" vira **Valor da parcela (R$)** (e não valor total dividido, nem campo extra), **só no Contas a Pagar** (`EH_PAGAR`); a Contas a Receber continua com "Dia". O "dia do mês" dos vencimentos deixa de ser digitado: segue o dia do "Venc 1° Parc" (31 em mês curto cai no último dia do mês).
- A lista **Aberto / Pago / Cancelado vale só para o Contas a Pagar**; o Contas a Receber mantém Pendente / Pendente Registro / Remessa Enviada / Pago / Cancelado (fluxo de boleto e CNAB).

## Definição da SPEC

### Como está (conferido em 06/11)

- A tela grava em **`boletos`** (uma linha por parcela, `tipo_operacao = 'CP'`, `status` = a situação escolhida). Hoje há só 4 boletos CP, todos "Pendente".
- `boletos.status` **não tem constraint** (só o gatilho de auditoria): "Aberto" é aceito sem migration.
- A consulta (`ConsultarDuplicatas`) junta `boletos` com `transacoes` (duplicatas da Connect, só consulta; `status_pago = 2` = cancelada já fica de fora). O "aberto" era `status <> 'Pago'`, então **boleto "Cancelado" aparecia como aberto**.
- Funções do banco que citam `'Pendente'` (`cancelar_orcamento`, `desfazer_aprovacao_financeira`, `aprovar_orcamento_financeiro`) são da **Receber/orçamento**; `fn_nota_compra_parcela_gera_contas_pagar` cria boleto CP "Pendente" (NF de compra) — a tela trata `Pendente`, `pendente_registro` e `Remessa Enviada` como **Aberto** no Pagar (ao editar, vira "Aberto").
- **O fluxo de caixa não lê `boletos`.** `FluxoFuturo.tsx` lê `v_financeiro_realizado` (sobre `transacoes`), com colunas por mês: A Receber | A Pagar | Saldo do mês | Saldo acumulado. Hoje "PREVISAO" no financeiro = transação em aberto (`status_pago = 0`) de negociação criada depois do marco (SPEC-246).

### Itens 1 e 2 — feito (só tela; sem migration)

- `CadastrarDuplicata.tsx`: campo "Valor da parcela" com prefixo R$; situação conforme o modo; ao editar conta antiga, o status legado aparece como "Aberto".
- `ConsultarDuplicatas.tsx`: `ehCancelada` (aceita "cancelado" minúsculo, como o banco grava em `cancelar_orcamento`) fora de "A pagar", "Vencido" e totais; opção "Canceladas"; coluna A/P/**C** na grade.
- `BaixarDuplicata.tsx`: cancelada não aparece em "Aberto" e dá erro claro se for selecionada.
- `BoletosTable.tsx`: status "Aberto" com a mesma cor do "Pendente".
- `tsc`: 41 erros antes e depois (dívida antiga de tipos em `types.ts`); nenhum novo. `build:pagar` ok, bundle em São Paulo.

### Item 3 — Previsão (pendente de decisão)

**Problema:** marcar "previsão" no cadastro (que grava `boletos`) não chega ao fluxo de caixa (que lê `transacoes`). Opções:

| Opção | O que muda | Prós / contras |
|---|---|---|
| A. Check `previsao` em `boletos` + o Fluxo Futuro passa a ler também os boletos CP em aberto numa coluna "Previsão" | coluna nova `boletos.previsao boolean`; view/consulta nova para o dashboard; coluna nova no Fluxo Futuro | simples para o usuário; mantém o cadastro como está; cria 2ª fonte no fluxo (cuidar de duplicar com `transacoes`) |
| B. O cadastro do Contas a Pagar passa a gravar também em `transacoes` (negociação + parcela) com a marca de previsão | RPC de cadastro; alinha com a SPEC-246 (financeiro nativo em `transacoes`) | uma fonte só; mais trabalho e mexe no financeiro que o chefe travou no marco de 05/11 |

Perguntas em aberto: (1) o desenho; (2) A ou B; (3) previsão pode ser desmarcada depois (virar conta firme)? (4) "Cancelado"/"Pago" ainda aparecem como previsão? (sugestão: não).

## Achados fora do pedido (não alterados)

- No **Contas a Receber** o mesmo vazamento existe: `cancelar_orcamento` grava boleto como `cancelado` (minúsculo) e a consulta o conta como aberto. Fica para decidir se corrigimos lá também.
- A tela de Pagar e o financeiro nativo são duas fontes (`boletos` × `transacoes`); vale decidir qual é a oficial do Contas a Pagar (ver item 3).

## Realizado

### 2026-11-06

- Itens 1 e 2 implementados, compilando (sem migration) e PUBLICADOS no Contas a Pagar (deploy 3bd83b2f; bundle conferido em produção: São Paulo, "Valor da parcela", "Aberto", "Canceladas", "A pagar (em aberto)").
- Levantamento do item 3 (fluxo de caixa não lê `boletos`; desenho não está no projeto).

## Pendências

- [ ] Item 3: receber o desenho, decidir A ou B, escrever a migration (`previsao`) e a coluna no Fluxo Futuro.
- [ ] Decidir se a Contas a Receber também deixa de contar boleto cancelado como aberto.
