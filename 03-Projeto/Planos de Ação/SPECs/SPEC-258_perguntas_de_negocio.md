# SPEC-258 — Perguntas de negócio (entrega "b")

> 06/11/2026. Lista fechada, com recomendação em cada pergunta. Resposta curta basta: "tudo como recomendado, exceto 2 (b) e 9 (a)".
> **[CRÍTICA]** = bloqueia a migração. **[PODE DEPOIS]** = dá para fechar mais tarde sem travar. Nada é aplicado antes das respostas.
> Base dos números: `SPEC-258_analise_independente_06_11.md` e `scripts/financeiro/baseline_spec258.sql`.

## Respostas recebidas (06/11/2026)

| # | Resposta do usuário | O que muda no desenho |
|---|---|---|
| 1 | **Vamos criar uma planilha que estipula o % de RT.** | Criada: `01-Documento/01 - Planilhas/RT_percentual_arquitetos.xlsx` (867 arquitetos ativos; colunas: % de RT, base de cálculo, quando é pago, emite NF, vigência; aba de padrão e de exceções por venda/projeto). **Pendente: o usuário preencher.** A planilha vira a tabela `financeiro_regras_repasse` (prioridade: exceção da venda/projeto > acordo do arquiteto > padrão). |
| 5 | **Preciso confirmar se é emitida a nota.** | Pendente do usuário. A planilha traz a coluna "Emite nota fiscal?" já como "A confirmar". Até confirmar, a regra de pagamento do RT não depende de NF. |
| 22 | **"Pago" é uma baixa dada por algum processo interno, sem movimentação nas parcelas, mas que precisava registrar algo no sistema.** | A baixa de **valor zero em Carteira** (935 parcelas, R$ 3,9 mi) **não é recebimento em dinheiro**. Entra no modelo como tipo de baixa próprio, `baixa_interna` (sem movimentação de caixa): **não exige conta bancária, não conta como receita realizada no fluxo de caixa**, exige motivo, fecha a parcela e fica rastreável. Vale também para as demais "pagas com valor zero" (Acordo Valor Zerado, Duplicata Gerada, DEV TROCA, vazio), que o usuário não detalhou; tratar do mesmo jeito, com o motivo derivado da forma de pagamento. |
| 27 | **"Provavelmente isso": pode ser acordo entre as empresas ou erro de lançamento** (não confirmado). | Não dá para decidir por regra. Os 305 pagamentos com conta bancária de outra empresa entram **marcados** (`empresa_pagadora` ≠ empresa devedora) e na **fila de pendências** (tipo `pagamento_de_outra_empresa`) para o Financeiro classificar cada um: *acordo entre empresas* (fica, com a empresa pagadora registrada) ou *erro de lançamento* (corrigir). Antes de migrar, o Financeiro recebe a lista dos 305. |

**Continuam sem resposta (por ordem de bloqueio):** 2, 3, 4, 6 a 21 (menos 22), 23 a 26, 28 a 38. Quem quiser adiantar: o mais urgente é o bloco A (RT; já tem a planilha), a 23 (conciliar as 3.020 canceladas com pagamento, só leitura) e a 20/21 (acordo e DEV TROCA).

## A. RT do arquiteto (a mais importante — o banco não guarda isso e o histórico não permite deduzir)

| # | Pergunta | Opções | Recomendação |
|---|---|---|---|
| 1 [CRÍTICA] | **Onde mora o percentual do RT?** (diga também qual é o percentual mais comum) | (a) fixo por arquiteto; (b) negociado venda a venda; (c) por projeto; (d) por faixa de valor | você me conta como é hoje |
| 2 [CRÍTICA] | **Sobre qual valor incide?** | (a) valor bruto da venda; (b) valor líquido (depois do desconto); (c) sem frete e sem imposto; (d) só o que o cliente já pagou | (d) se pago proporcionalmente; senão (b) |
| 3 [CRÍTICA] | **Quando o RT é devido e pago?** | (A) proporcional ao que o cliente pagou; (B) só com a venda 100% recebida; (C) tudo na aprovação; (D) data fixa do mês (qual dia?) | (A) |
| 4 [CRÍTICA] | **Devolução ou cancelamento da venda:** o RT diminui? Se o arquiteto já recebeu, ele devolve ou desconta do próximo? | (a) diminui proporcional e desconta do próximo RT; (b) diminui e o arquiteto devolve (vira conta a receber); (c) não muda | (a) |
| 5 [CRÍTICA] | **O arquiteto emite nota fiscal** para receber o RT? O pagamento depende dela? | sim / não / depende | você me conta |
| 6 | **Mais de um arquiteto na venda:** o RT é dividido pela mesma divisão do projeto (hoje todos estão em 100%)? | sim / não | sim |
| 7 | **Histórico de RT (1.168 títulos, R$ 1,81 mi), nunca ligado à venda:** aceitar como "RT sem venda" (consulta apenas)? | sim / quero ligar à mão | sim |
| 8 | **93 RT pagos a contato "fornecedor", 78 a "cliente" e 20 lançados como receita (R$ 107 mil):** quem corrige o cadastro? | Financeiro / eu / deixar como está | Financeiro, pela fila de pendências |

## B. Comissão e folha

| # | Pergunta | Opções | Recomendação |
|---|---|---|---|
| 9 [CRÍTICA] | **Comissão do funcionário:** sobre o vendido (como a tela calcula hoje) ou sobre o recebido? | (a) vendido, no mês de entrada do projeto; (b) recebido, proporcional a cada parcela | (b) |
| 10 [CRÍTICA] | **Hoje ela é por equipe** (13 pessoas, até 5,5%). Continua por equipe ou passa a ser por funcionário e venda? | equipe / funcionário | equipe |
| 11 | **A comissão é paga junto com a folha ou em separado?** (hoje a coluna de comissão da folha está zerada nas 771 folhas) | junto / separado | junto |
| 12 [CRÍTICA] | **Folha entra como conta a pagar** por funcionário e mês? | sim / não | sim |
| 13 | **As 49 folhas antigas:** migrar como já pagas ou começar do mês atual? | todas pagas / só do mês atual | todas pagas (histórico) |
| 14 [CRÍTICA] | **Folha no fluxo de caixa:** o fluxo mostra só o **total do mês, sem nomes** (o detalhe fica só com o RH). Pode? | sim / não | sim |
| 15 | **"Salário por fora":** continua só no RH, fora do fluxo e de qualquer tela financeira geral? | sim / não | sim |

## C. Quando é prevista e quando é firme

| # | Pergunta | Recomendação |
|---|---|---|
| 16 [CRÍTICA] | **Receita:** prevista na aprovação da equipe, firme na aprovação financeira? | sim |
| 17 [CRÍTICA] | **Despesa de compra:** necessidade = prevista; pedido aprovado = prevista; NF de entrada = firme e **substitui** a prevista (sem contar duas vezes)? | sim |
| 18 | **Conta prevista pode voltar a firme e vice-versa?** E conta **paga ou cancelada** nunca aparece como previsão? | sim às duas |

## D. Legado: renegociação, acordo e "pagos" sem dinheiro (novos, da segunda análise)

| # | Pergunta | Recomendação |
|---|---|---|
| 19 [CRÍTICA] | **"Duplicata Gerada" (2.538 parcelas, R$ 16 mi) é renegociação:** a Connect trocou a dívida antiga por duplicatas novas? Quer ver a ligação "antiga → nova"? | sim; guardar a ligação |
| 20 [CRÍTICA] | **"Acordo" (293) e "Acordo Valor Zerado" (489):** é perdão total ou parcial de dívida? Quem autoriza? Entra no fluxo como receita realizada? | perdão; fica como "abatimento" com motivo, **fora** da receita realizada |
| 21 [CRÍTICA] | **"DEV TROCA" (876, pagas com valor zero):** é devolução/crédito de venda? | sim; vira "compensação" |
| 22 [CRÍTICA] | **"Carteira" (1.208 parcelas; 935 pagas com valor zero, R$ 3,9 mi):** o que significa "paga" em carteira? O cliente pagou fora do sistema, ou nunca foi cobrado em dinheiro? | você me conta |
| 23 ✔ | **3.020 canceladas com pagamento (R$ 9,36 mi): CONCILIADO em 06/11** (ver `SPEC-258_analise_independente_06_11.md`, seção 6). **R$ 5,07 mi (54%) são artefatos de renumeração/duplicidade → não viram baixa.** **R$ 4,29 mi (1.527 parcelas, receitas, 1.502 em Pix) são de duplicatas que a Connect removeu e não estão contadas em outro lugar** → o Financeiro precisa conferir com o extrato (lista em `01-Documento/01 - Planilhas/CONFERIR_canceladas_com_pagamento_sem_origem.csv`). | **NOVA PERGUNTA 23B [CRÍTICA]:** quem do Financeiro confere as 1.527 com o extrato bancário? Se o dinheiro entrou, vira receita realizada (baixa); se não, fica cancelada. |
| 24 | **349 parcelas (R$ 1,35 mi) que a view atual esconde** (duplicata repetida em outra empresa): continuam fora do fluxo, guardadas como arquivo? | sim |
| 25 | **Datas com defeito** (1 paga com data futura, 22 vencimentos de ano absurdo, 5 pagas sem data): quem corrige? | Financeiro, pela fila de pendências |
| 26 | **245 contas sem plano de contas e 982 pagamentos sem conta bancária:** o Financeiro classifica pela fila? | sim |

## E. Bancos, empresas e formas de pagamento

| # | Pergunta | Recomendação |
|---|---|---|
| 27 [CRÍTICA] | **305 pagamentos feitos com a conta bancária de outra empresa:** é legítimo? Se sim, registramos "pago pela empresa X" para a empresa Y? | você me conta; se legítimo, registrar a empresa pagadora |
| 28 | **"Caixa Empresa" não pertence a nenhuma empresa:** é caixa compartilhado ou de qual empresa? | compartilhado, com a empresa pagadora em cada baixa |
| 29 | **Cartão (556 parcelas):** o dinheiro entra quando o cliente paga ou quando a operadora repassa? A taxa da operadora entra como despesa? | registrar a data do repasse e a taxa |
| 30 | **Cheque (69):** pré-datado conta como recebido só no depósito? | sim |
| 31 | **Saldo bancário:** hoje é um número digitado. Passa a ser calculado pelas baixas? | sim, e conciliar com o extrato numa fase posterior |
| 32 | **Retirada de lucro:** continua como despesa com visibilidade restrita (como hoje)? | sim |

## F. Estrutura e migração

| # | Pergunta | Recomendação |
|---|---|---|
| 33 [CRÍTICA] | **Migrar o legado da Connect** para o modelo novo (com os ids da Connect guardados, sem alterar) ou deixá-lo nas tabelas antigas só para consulta? | migrar |
| 34 | **Uma tabela de títulos** com a coluna "a receber / a pagar" e duas views claras, ou duas tabelas separadas? | uma tabela + duas views |
| 35 | **Crédito de devolução** como título de valor negativo ligado à venda? | sim |
| 36 [CRÍTICA] | **Pendências do legado:** migrar tudo com uma fila de pendências, e só dar por concluído com zero abertas (ou aceitas com motivo pelo administrador)? | sim |
| 37 [CRÍTICA] | **Histórico financeiro permanente** (hoje a auditoria é apagada com mais de 12 meses): guardar para sempre? | sim |
| 38 [CRÍTICA] | **Proibir a gravação direta nas tabelas de dinheiro** e religar o CRM, o RH e o Contas a Pagar/Receber para passarem pelas funções do banco? | sim |

## Como responder
Basta um bloco assim: **"Recomendadas, exceto: 2 → (b); 22 → [explicação]; 27 → [explicação]."** As perguntas **1, 5, 22 e 27** precisam de uma explicação sua, porque o banco não tem a informação.
