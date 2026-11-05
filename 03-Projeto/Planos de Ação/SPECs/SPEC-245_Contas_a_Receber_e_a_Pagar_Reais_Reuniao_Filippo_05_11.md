---
titulo: "SPEC-245 — Contas a Receber e Contas a Pagar reais e diárias (reunião 42 com o Filippo, 05/11)"
status: "EM ANDAMENTO — D1 decidida (importador do financeiro LIBERADO) e conferência escrita em 05/11; achado novo: a empresa por linha não bate com a planilha (G9)"
data: 2026-11-05
origem: "02-Reunioes/42. Lucenera (Filippo) - 05.11.2026_ ]filippo/01.Reunião"
planilhas: "01-Documento/01 - Planilhas/ContaReceber_2026-11-05.xlsx e ContaPagar_2026-11-05.xlsx"
relacionadas: SPEC-225 (Contas a Pagar / a Receber), SPEC-215 (entrada de NF e financeiro), SPEC-204 (notas fiscais da Connect), SPEC-244 (operação em paralelo), SPEC-195/197 (XML importado da Connect)
---

# SPEC-245 — Contas a Receber e Contas a Pagar reais e diárias

## 1. O que o Filippo pediu na reunião 42 (05/11)

O Filippo estava vendo um orçamento aprovado (XML importado da Connect, venda 8502, cliente Mônica Saccarelli / Farol Arquitetura, R$ 840,00) e a conversa foi para o financeiro. O que ficou dito:

- **"A parte financeira tem que estar redonda, tem que estar zerada"** [05:17]: "estamos começando hoje"; só se esperou a planilha chegar (duas semanas) e não dá para começar com tudo "banguelo".
- **Informação real e do dia** [07:15]: "tem que estar com as informações reais de hoje atualizadas e poder receber a partir de hoje as informações para ser alimentado". Ele precisa conferir **diariamente** quais pagamentos mandar fazer e quais recebimentos tem que receber, e "a partir de hoje isso aqui deveria funcionar igual" à Connect.
- **Planilhas diárias** [08:32]: ao perguntar se existem planilhas produzidas todo dia, a resposta foi "Sim". Decisão: **"vamos carregá-las, vamos deixar coisa real"**.
- **Contas reais** [06:50]: "as contas reais a gente tem baixado"; no sistema elas "só estão como contas em aberto, e controle de boleto".
- **Pagamento por fora do sistema** [00:01 a 03:34]: a venda da Mônica já foi paga (um Pix de R$ 890, acréscimo de finalização de obra, pago em 05/11; na condição de pagamento estava "Pix 4/11"). O sistema não sabe. A lógica dita: ao **aprovar** o orçamento o cliente ainda **não pagou**; o pagamento é **conferido pelo financeiro**, que "se ocupa de receber"; a baixa e a conferência acontecem em **Vendas / Contas a Receber**. Enquanto isso, a observação da condição de pagamento registra "já foi pago".
- **Confirmação nas aprovações** [00:27]: "uma confirmação importante na hora das aprovações, porque você pode passar o dedo por engano" (enviar ao financeiro, aprovação da equipe, aprovação financeira).
- **RT do arquiteto** [01:40]: Farol Arquitetura "não está mudando o RT", não é puxado direito pelo cadastro do cliente. Precisa ficar claro **se o arquiteto tem ou não tem RT** (talvez um indicador ao lado do arquiteto).
- **Nota fiscal** [09:06 a 11:19]: a emissão fica em **Vendas** (menu da Central). Lá aparece uma lista longa de notas "pendentes" que são **as notas da Connect**, ainda não marcadas como autorizadas. O Filippo quer saber se as já emitidas estão baixadas. A resposta foi: **"essa informação eu não tenho com as planilhas"**; só se tem contas a receber, contas a pagar, o que foi e o que já recebeu. Ficou para falar com o Vinícius.
- **Dado de teste** [05:10]: um lançamento feito no sistema novo ("isso aqui foi o que a gente fez dentro do nosso sistema") tem que ser **apagado**.
- **Tom da reunião:** o Filippo está cobrando que o financeiro seja fechado agora e que as reuniões do assunto sejam **com ele** ("não adianta, vocês não estão conseguindo dar conta sozinhos"). Haverá reunião com o Vinícius no começo da tarde.

## 2. Meta (para a próxima reunião)

**As listas de Contas a Receber e Contas a Pagar do sistema novo são as das planilhas de 05/11, reais e do dia, e passam a ser atualizadas todo dia.** O foco é a **lista** (ver, filtrar, totalizar por empresa, aberto × pago × cancelado, vencimento). A emissão de nota, a conciliação bancária e a baixa automática ficam fora desta SPEC, a não ser como pontos de decisão (seção 5).

## 3. Situação medida hoje (conferência com as planilhas de 05/11)

A carga das planilhas de 05/11 foi feita pela manhã (`importar_contas_pagar_receber.py`: 93 transações novas, 21 atualizadas, 2 órfãs canceladas, 18 negociações novas da LUCE NERA). Conferi o resultado contra as duas planilhas:

| | Contas a Receber | Contas a Pagar |
|---|---|---|
| Linhas da planilha | 5.064 | 14.308 |
| Pagas / abertas / canceladas na planilha | 4.510 / 459 / 95 | 12.109 / 1.238 / 961 |
| **Em aberto na planilha** | **459 · R$ 2.851.487,96** | **1.238 · R$ 4.082.025,35** |
| **Em aberto no banco** | **459 · R$ 2.851.487,96** | **1.238 · R$ 4.082.025,35** |
| Em aberto no banco que não está aberto na planilha | 0 | 0 |
| Em aberto na planilha que não está aberto no banco | 0 | 0 |
| Linhas da planilha ausentes do banco | 0 | 0 |
| Empresas na planilha | LUCE NERA 1.999 · ISLIGHT 1.987 · FOCO 1.078 | LUCE NERA 5.648 · ISLIGHT 4.369 · FOCO 4.291 |

**Conclusão:** as **listas em aberto** já batem exatamente com as planilhas, em quantidade e em valor, nos dois lados. Nada em aberto foi lançado direto no sistema novo (0 transações abertas sem o código da Connect).

O que **não** está redondo ou ainda não foi analisado:

- **Contas a Receber, pagas e canceladas — RESOLVIDO pela conferência (seção 10):** a primeira comparação mostrava 752 canceladas e 667 valores diferentes só porque 878 códigos se repetem no banco (acordos/negociações duplicadas, que o importador cancela de propósito). Comparando linha a linha com o status e o valor certos, **0 divergências de status e 0 de valor** nos dois lados.
- **Linhas só no banco:** 2.709 de Receber e 377 de Pagar não estão nas planilhas de 05/11 (histórico mais antigo ou fora do período exportado). Hoje não afetam o que está em aberto, mas afetam totais históricos.
- **Parcelas e boletos do sistema novo:** o banco tem 387 parcelas de projeto, todas **pagas** (R$ 8,12 mi, criadas em 04/05, vindas da migração antiga) e 12 boletos. Não conferi se é isso que o Filippo quer "apagar".
- **Nota fiscal:** não existe na planilha (ver seção 1).

## 4. Lacunas (o que impede a meta hoje)

| # | Lacuna | Por que importa |
|---|---|---|
| G1 | ~~A carga diária está bloqueada~~ **RESOLVIDO em 05/11:** `importar_contas_pagar_receber.py` voltou a gravar (a guarda da SPEC-244 foi retirada só dele; estoque, herança e pedido de compra continuam travados). | Decisão D1. |
| G2 | **Não existe rotina diária.** A carga é um script rodado à mão por quem recebe a planilha. Não há conferência pós-carga registrada (o que acabei de fazer foi manual). | O Filippo precisa conferir todo dia; a lista só vale se for atualizada e conferida. |
| G3 | **Pagamento feito fora do sistema não tem onde ser registrado** no fluxo novo (caso do Pix de R$ 890). O vínculo "XML importado da Connect" não cria parcela nem boleto (SPEC-195), e o orçamento novo só ganha parcela depois da aprovação. | O financeiro receberia a venda como "a receber" mesmo já paga. |
| G4 | **Venda nova do sistema × financeiro da Connect em paralelo.** Se a equipe aprova uma venda nos dois sistemas, o recebível pode existir duas vezes (parcela do sistema novo + linha importada da Connect). | Totais de Contas a Receber inflados. A SPEC-215 já criou a regra "casa por nº da nota" para o Pagar; para o Receber não há regra equivalente. |
| G5 | **Aprovação sem confirmação** (ou com confirmação fraca) nas telas de aprovação. | Aprovação por engano mexe em financeiro. |
| G6 | **RT do arquiteto não aparece/atualiza** no orçamento a partir do cadastro do cliente. | Comissão/RT errada no financeiro. |
| G7 | **Status da nota fiscal das vendas da Connect** não vem nas planilhas; a lista de Vendas mostra tudo "pendente". | O Filippo vê pendência que na verdade já foi emitida na Connect. |
| G8 | **Dados de teste no financeiro do sistema novo** ("eu tenho que apagar isso aqui"). | "Redonda e zerada." |
| G9 | ~~A empresa por linha não bate~~ **CORRIGIDO em 05/11:** 3.437 negociações (6.182 parcelas) alinhadas à empresa da planilha (`scripts/corrigir_empresa_negociacoes_financeiro.py`, backup em `backup._bkp_negociacoes_empresa_20261105`); o importador passou a criar duplicata nova na empresa da planilha. Em aberto **fecha por empresa nos dois lados**. Sobram 4 negociações ambíguas e 2 que colidem com outra (abas `ambiguas_puladas`/`colisoes_puladas` do Excel de correção), 1 parcela em aberto divergente no Receber. | Ver seção 10. |
| G10 | **"Consultar Duplicatas" não mostra as duplicatas da Connect.** Nos sistemas Contas a Receber/Pagar, **Consultar/Cadastrar/Baixar Duplicata** leem a tabela `boletos` (cadastro feito neste sistema; hoje 3 linhas `NFC-` do Compras); só **Contas em Aberto** lê `transacoes`, onde as planilhas são carregadas. As 5.064 duplicatas de Receber e 14.308 de Pagar das planilhas só aparecem em Contas em Aberto. | A tela que o Filippo conhece da Connect (Duplicata, Par., Tot., Venda, Fatura, Pessoa, Emissão, Vencimento, Atraso, Pagamento, Vl. Parcela, Vl. Pago) estaria vazia. Decisão D8. |
| G11 | **Duplicatas com "Pessoa 464" e pessoa ERRADA.** 9.714 das 14.027 negociações estavam sem contato (a tela mostra "Pessoa <código>") e **1.609 das 2.330 despesas ligadas apontavam para outra pessoa** (ex.: despesa da Adriana Jabur ligada ao cliente "Benedito Gastronomia"). Causa: o importador ligava o contato só ao CRIAR a negociação e pelo `cod_pessoa` sem olhar o tipo (o número repete entre cliente e arquiteto; os 357 fornecedores não têm `codigo_legado`); as antigas nunca foram preenchidas. **CORRIGIDO em 05/11 (seção 11).** | Quem paga/recebe estava errado ou em branco na lista. |

## 5. Decisões que dependem do Filippo e do Vinícius

- **D1 — Carga diária do financeiro: DECIDIDO em 05/11 (pelo usuário, "pode liberar o importador").** `importar_contas_pagar_receber.py` voltou a gravar; ao final de cada carga rodar `scripts/conferir_contas_pagar_receber.py`. A guarda da SPEC-244 continua só no estoque, na herança e no pedido de compra.
- **D2 — Quem dá baixa em recebimento por fora do sistema** (caso do Pix): o financeiro, em Contas a Receber. A baixa do sistema novo é a fonte, ou só o que vier da planilha do dia seguinte? Recomendação: a **planilha manda** (é a verdade da Connect) e a observação "já foi pago" no orçamento só sinaliza.
- **D3 — Receber duas vezes:** para venda aprovada **nos dois** sistemas, qual vale? Recomendação: o recebível da **Connect (planilha)** vale enquanto houver Connect, e a parcela do sistema novo fica **sem gerar linha própria no Contas a Receber** até o fim do paralelo. Precisa do Vinícius.
- **D4 — Nota fiscal da Connect:** como marcar "autorizada"? A planilha não traz. Opções: importar o status de outro relatório da Connect, ou o Vinícius marcar em lote por intervalo de datas. Fora do escopo desta SPEC até haver dado.
- **D5 — O que apagar no financeiro novo:** confirmar com o Filippo **o quê** ("isso aqui" do [05:10]). Não apagar nada sem lista aprovada.
- **D6 — Quem fecha as pontas:** o Filippo pediu que as reuniões do financeiro sejam com ele; agendar com o Vinícius.
- **D7 — Empresa por linha: APROVADO e APLICADO em 05/11 (pelo usuário, "Sim").** Ver G9 e seção 10.
- **D8 — Consultar Duplicatas (G10):** recomendação: a tela passar a ler `transacoes` (a mesma fonte de Contas em Aberto) com as colunas da Connect, mantendo `boletos` só para o que é emitido/baixado por aqui, em vez de copiar 19 mil linhas para `boletos`. Precisa do OK e de olhar como a tela cadastra/baixa para não perder essas funções.
- **D9 — Pessoa das negociações antigas que não estão na planilha de hoje:** ligar as 2.089 de Receber pelo cliente de mesmo `codigo_legado` (~96% certo) ou deixar "Pessoa N" até haver planilha antiga com nomes? Recomendação: ligar só se o Filippo precisar do histórico antigo por pessoa.

## 6. Proposta de entrega (em ordem)

**Fase A — a lista real, do dia, conferida (é a meta)**
1. Decidir D1 e, se confirmado, **desbloquear só o script de Contas a Pagar/Receber** (uma linha em `importar_contas_pagar_receber.py`). Registrar o motivo no código e na SPEC-244.
2. Escrever `scripts/conferir_contas_pagar_receber.py` (só leitura): compara as planilhas do dia com o banco e imprime **abertas, pagas e canceladas por empresa e tipo**, valores, diferenças de status e de valor, e as linhas só no banco. Gera um Excel em `scripts/logs/`. Rodar depois de cada carga (hoje o resultado seria o da seção 3).
3. **Explicar as 667 diferenças e os 878 códigos repetidos do Receber** (acordos): listar, classificar (acordo legítimo, duplicata, valor ajustado) e decidir o tratamento. Sem mexer em dado sem a lista aprovada.
4. Conferir na tela de **Contas a Receber** e de **Contas a Pagar** (os dois sistemas da SPEC-225) que a lista em aberto mostra os mesmos totais por empresa. Anotar o totalizador que o Filippo usa para conferir todo dia.
5. Roteiro de carga diária (quem baixa a planilha, em que pasta, comando, conferência), em `03-Projeto/`.

**Fase B — pagamento fora do sistema e aprovação**
6. Observação "já foi pago" e **registro do pagamento** conforme D2 (campo na condição de pagamento ou baixa em Contas a Receber).
7. **Confirmação** nas ações de aprovação (enviar ao financeiro, aprovar equipe, aprovar financeiro), com o resumo do que vai acontecer.

**Fase C — o resto**
8. **RT do arquiteto**: indicador "tem RT / não tem RT" ao lado do arquiteto, vindo do cadastro (investigar por que Farol não atualiza).
9. Regra do recebível duplicado (D3).
10. Status da nota fiscal da Connect (D4), quando houver dado.
11. Limpeza dos lançamentos de teste (D5), só com lista aprovada, com backup no schema `backup`.

## 7. Critérios de aceite (para a próxima reunião)

1. Contas a Receber e Contas a Pagar mostram, em aberto, **os mesmos números das planilhas do dia** (hoje: 459 · R$ 2.851.487,96 e 1.238 · R$ 4.082.025,35), por empresa.
2. A carga de amanhã roda **sem recusa** e a conferência pós-carga fecha com **0 diferença** nas abertas.
3. Existe um comando de conferência e um roteiro de carga diária por escrito.
4. Uma venda paga por fora (caso 8502) tem onde ser marcada como paga, sem virar "a receber" duplicado.
5. Nenhum dado do financeiro foi apagado sem lista aprovada pelo Filippo.

## 8. Riscos

- **Dois números para o mesmo recebível** (G4) se a equipe aprovar nos dois sistemas e a planilha também trouxer a linha.
- **Importar o Receber sem entender os acordos repetidos** pode cancelar ou duplicar parcelas legítimas; por isso a Fase A.3 vem antes de qualquer correção.
- **Contradição de instruções:** a SPEC-244 manda parar as importações; esta SPEC pede para manter a do financeiro. Resolver por escrito (D1) antes de mexer.
- **Pressão por prazo:** o Filippo espera a lista funcionando "na reunião"; a lista já bate nas abertas, então a entrega mínima é segura, mas o que o Filippo vê é a tela, não o banco; conferir a tela antes.

## 9. Realizado

- 05/11: reunião lida; conferência manual das listas em aberto; SPEC escrita.
- 05/11 (tarde): **D7/G9 aplicados** (empresa das negociações corrigida; importador usa a empresa da planilha para duplicata nova; conferência por empresa FECHA); achado G10 (Consultar Duplicatas lê `boletos`).
- 05/11 (tarde): **D1 aplicada** (guarda retirada de `importar_contas_pagar_receber.py`); **`scripts/conferir_contas_pagar_receber.py` escrito** (só leitura; gera Excel em `scripts/logs/conferencia_financeiro/`); 9 boletos de teste apagados (backup em `backup._bkp_boletos_teste_20261105`); achado G9.

## 11. Correção das pessoas (G11, 05/11)

- **`scripts/corrigir_pessoas_financeiro.py`** (ensaio e `--aplicar`; backups em `backup._bkp_negociacoes_contato_20261105` e `backup._bkp_contatos_precadastro_financeiro_20261105`): liga cada negociação ao contato pelo **NOME** da planilha (`nome_pessoa`/`razao_pessoa`, sem acento). Receber prefere cliente > arquiteto; Pagar prefere fornecedor > arquiteto > cliente. O que não existe vira **pré-cadastro** (Receber → cliente; Pagar → fornecedor) com nome e razão social da planilha e observação para completar CPF/CNPJ, contato e endereço.
- **Resultado:** 7.873 negociações corrigidas (6.018 sem contato + 1.855 com a pessoa errada), **138 pré-cadastros** (121 fornecedores e 17 clientes), 308 ambíguas puladas (mesmo nome em mais de um cadastro do mesmo tipo; aba `ambiguas_puladas` do Excel). Transações, valores e estoque não mudaram.
- **Ainda sem pessoa:** 2.454 negociações de Receber e 1.242 de Pagar que **não estão na planilha de hoje** (emitidas entre 2024 e 2026, pagas ou antigas): sem o nome não dá para ligar com segurança. 2.089 das de Receber têm um cliente com o mesmo código (96% dos códigos de Receber conferem pelo nome); ligar por esse código é a decisão D9.
- **Importador:** `importar_contas_pagar_receber.py` deixou de ligar contato pelo `cod_pessoa` (era a causa do erro). **Roteiro diário:** depois de cada carga rodar `corrigir_pessoas_financeiro.py --aplicar` e `conferir_contas_pagar_receber.py`.

## 10. Resultado da conferência de 05/11 (`conferir_contas_pagar_receber.py`)

| | Receber | Pagar |
|---|---|---|
| Em aberto, TOTAL (planilha × sistema) | 459 · R$ 2.851.487,96 × igual — **FECHA** | 1.238 · R$ 4.082.025,35 × igual — **FECHA** |
| Em aberto, POR EMPRESA | FOCO 90 · R$ 584 mil × 107 · R$ 904 mil; ISLIGHT 251 · R$ 1,95 mi × 82 · R$ 676 mil; MANOELLA 118 · R$ 320 mil × 270 · R$ 1,27 mi — **NÃO FECHA** | FOCO 419 · R$ 1,14 mi × 87 · R$ 264 mil; ISLIGHT 413 · R$ 1,69 mi × 98 · R$ 557 mil; MANOELLA 406 · R$ 1,26 mi × 1.053 · R$ 3,26 mi — **NÃO FECHA** |
| Linhas da planilha ausentes do sistema | 0 | 0 |
| Status divergente / valor divergente | 0 / 0 | 0 / 0 |
| Empresa divergente (status e valor iguais) | 2.749 (trocas entre as três empresas) | 3.403 (todas: planilha FOCO ou ISLIGHT, sistema MANOELLA) |
| Abertas só no sistema / lançadas aqui sem código da Connect | 0 / 0 | 0 / 0 |
| Linhas só no sistema (histórico) | 2.712 (1.627 pagas, 1.085 canceladas) | 377 (267 pagas, 110 canceladas) |
| Códigos repetidos no sistema | 878 | 0 |

**Leitura:** os números do que está a pagar e a receber estão certos no total. O que não está certo é **a que empresa cada parcela pertence**; quem filtra Contas a Pagar/Receber por empresa vê valores diferentes da planilha. O script sai com código 1 enquanto a divisão por empresa não fechar.


- 05/11: reunião lida; conferência das listas em aberto feita contra as planilhas de 05/11 (seção 3); SPEC escrita. **Nada foi implementado, aplicado ou alterado no banco por esta SPEC.**
