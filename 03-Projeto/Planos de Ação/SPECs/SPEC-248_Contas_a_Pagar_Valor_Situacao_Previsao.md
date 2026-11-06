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
- [~] 3. Check **Previsão** + coluna própria no fluxo de caixa — **opção B confirmada**; **base de dados APLICADA** (migration 301, ver Realizado); faltam o desenho da coluna, a tela do Fluxo Futuro e o cadastro nativo (SPEC-246).
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

**Revisão em 06/11 (pergunta do usuário: "e quando o nosso sistema estiver 100% em uso?"):** pela SPEC-246, depois do marco toda baixa, lançamento e acordo nasce em `transacoes` (front nativo) e a carga da Connect termina. Com o sistema 100% em uso a **opção A deixaria duas fontes permanentes** no fluxo (`transacoes` e `boletos`), com risco de contar a mesma conta duas vezes (já há caminhos que criam boleto CP sozinhos, como a parcela de NF de compra, e as parcelas de pedido de compra entram como previsão) e com as contas lançadas à mão fora do financeiro nativo; seria um remendo a migrar depois. A **opção B é o destino da SPEC-246**. A objeção anterior à B ("mexe no financeiro travado em 05/11") **não procede**: o que o marco travou é a importação da planilha e os corretores dela; a gravação nativa é o que passa a ser exigido.

**Recomendação atual: opção B**, como parte do passo 4 da SPEC-246 (front nativo): marca `previsao` em `transacoes`, coluna "Previsão" no Fluxo Futuro (que já lê `transacoes`), e o cadastro do Contas a Pagar gravando duplicata e parcelas em `transacoes` (ids próprios, `origem = sistema`); o boleto/CNAB segue para o banco. **Dependência:** a SPEC-246 ainda não foi aplicada (falta autorização de cada migration). A opção A só serviria como solução temporária, com custo de migração depois. **B CONFIRMADA pelo usuário em 06/11.** Aguarda: reenviar o desenho e responder (3) e (4).

## Achados fora do pedido (não alterados)

- No **Contas a Receber** o mesmo vazamento existe: `cancelar_orcamento` grava boleto como `cancelado` (minúsculo) e a consulta o conta como aberto. Fica para decidir se corrigimos lá também.
- A tela de Pagar e o financeiro nativo são duas fontes (`boletos` × `transacoes`); vale decidir qual é a oficial do Contas a Pagar (ver item 3).

## Realizado

### 2026-11-06

- Itens 1 e 2 implementados, compilando (sem migration) e PUBLICADOS no Contas a Pagar (deploy 3bd83b2f; bundle conferido em produção: São Paulo, "Valor da parcela", "Aberto", "Canceladas", "A pagar (em aberto)").
- Levantamento do item 3 (fluxo de caixa não lê `boletos`; desenho não está no projeto).

### 2026-11-06 (item 3 — base de dados da Previsão pela opção B; migration 301 APLICADA)

- **Migration 301 (`20261106_301_spec248_previsao_transacoes`):** (1) `transacoes.previsao` (boolean, padrão `false`: nada que já existe vira previsão); (2) `v_financeiro_realizado` ganha a coluna `previsao` no FIM — verdadeira **só para parcela em aberto** (`status_pago = 0`): Pago e Cancelado **nunca** aparecem como previsão, mesmo com a marca ligada (resposta à pergunta 4, conforme a sugestão); (3) função `definir_previsao_transacoes(ids, previsao, motivo)`: marca ou **desmarca** (a conta vira firme — pergunta 3: sim, pode) parcelas em aberto; recusa parcela paga/cancelada; quem pode = `pode_acessar_sistema('financeiro')`; `anon` sem execução; a auditoria da tabela registra antes/depois.
- **Dry-run com ROLLBACK (como admin):** a view ganhou 1 coluna (`previsao`, a última) e as **mesmas linhas e a mesma soma** de antes; marcar 3 parcelas em aberto → 3 na view; pagar uma → 2 (o pago some mesmo com a marca ligada); firmar outra → 1; marcar parcela paga é recusado; auxiliar de estoque (sem financeiro) barrado; `anon` barrado.
- **Aplicada em 06/11 com OK do usuário e conferida:** coluna `transacoes.previsao` criada, `v_financeiro_realizado` com 18.316 linhas e a mesma soma (R$ 75.203.769,77), nenhuma parcela marcada como previsão, `authenticated` lê/executa e `anon` não.
- **Importante:** as respostas às perguntas 3 e 4 acima são as **minhas sugestões**; o usuário ainda não as confirmou. Se mudar algo (ex.: Pago aparecer em outra coluna), é só ajustar a coluna da view.
- **Falta para fechar o item 3:** o desenho da coluna no Fluxo Futuro; a tela do Fluxo Futuro (dashboard) com a coluna "Previsão"; o cadastro do Contas a Pagar gravando duplicata e parcelas em `negociacoes`/`transacoes` com a marca (passo 4 da SPEC-246, que ainda não foi aplicada).

## Pendências

- [ ] Item 3: receber o desenho, fazer a coluna no Fluxo Futuro e o cadastro nativo (SPEC-246, passo 4).
- [ ] Decidir se a Contas a Receber também deixa de contar boleto cancelado como aberto.
