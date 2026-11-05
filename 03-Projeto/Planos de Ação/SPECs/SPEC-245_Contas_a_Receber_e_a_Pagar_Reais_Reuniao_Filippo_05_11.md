---
titulo: "SPEC-245 — Contas a Receber e Contas a Pagar reais e diárias (reunião 42 com o Filippo, 05/11)"
status: "EM ANDAMENTO — D1 decidida (importador do financeiro LIBERADO) e conferência escrita em 05/11; achado novo: a empresa por linha não bate com a planilha (G9)"
data: 2026-11-05
origem: "02-Reunioes/42. Lucenera (Filippo) - 05.11.2026_ ]filippo/01.Reunião e 02.Reunião"
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
| G12 | **Campos do backend diferentes da planilha** (auditoria campo a campo, seção 12): conta (plano de contas) de 2.981 negociações de RECEBER copiada da despesa de mesmo número (ex.: receita "RT", "Compras - Revenda"), `cod_venda` vazio em 788 negociações de Receber, `total_parc` desatualizado em 349, forma de pagamento desatualizada em 1.858 parcelas (planilha "Pix", sistema "Duplicata Gerada"). **CORRIGIDO em 05/11** com `scripts/corrigir_campos_financeiro_planilha.py`. Resta ~6% das linhas com diferença (seção 12). | O Filippo olha a conta/categoria e a venda de cada duplicata. |

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
- **D10 — Contas que a planilha tem e o plano de contas não:** 10000008 ALUGUEL SÃO PAULO, 10000009 CONDOMÍNIO - SÃO PAULO e 2060003 MANUTENÇÃO CONTA (e o alias 10000007). Criar no plano de contas (precisa do grupo/subgrupo pai)? **D11 — Duplicatas com o mesmo número em mais de uma empresa (804 no Receber):** reprocessar caso a caso com o Vinícius. **D12 — Usuário de leitura para o Claudio** (opções na seção 12).

## 6. Proposta de entrega (em ordem)

**Fase A — a lista real, do dia, conferida (é a meta)**
1. Decidir D1 e, se confirmado, **desbloquear só o script de Contas a Pagar/Receber** (uma linha em `importar_contas_pagar_receber.py`). Registrar o motivo no código e na SPEC-244.
2. Escrever `scripts/conferir_contas_pagar_receber.py` (só leitura): compara as planilhas do dia com o banco e imprime **abertas, pagas e canceladas por empresa e tipo**, valores, diferenças de status e de valor, e as linhas só no banco. Gera um Excel em `scripts/logs/`. Rodar depois de cada carga (hoje o resultado seria o da seção 3).
3. **Explicar as 667 diferenças e os 878 códigos repetidos do Receber** (acordos): listar, classificar (acordo legítimo, duplicata, valor ajustado) e decidir o tratamento. Sem mexer em dado sem a lista aprovada.
4. Conferir na tela de **Contas a Receber** e de **Contas a Pagar** (os dois sistemas da SPEC-225) que a lista em aberto mostra os mesmos totais por empresa. Anotar o totalizador que o Filippo usa para conferir todo dia.
5. Roteiro de carga diária (quem baixa a planilha, em que pasta, comando, conferência): **ESCRITO em 05/11** em `03-Projeto/Planos de Ação/ROTEIRO_Carga_Diaria_Financeiro_Contas_Pagar_Receber.md` (5 passos, critério de aceite do dia, o que fazer se não fechar e como desfazer).

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
- 05/11 (fim da tarde): **auditoria campo a campo** (`auditar_financeiro_vs_planilha.py`) + **G12 corrigido** (`corrigir_campos_financeiro_planilha.py`): 94,1% das linhas 100% iguais nos 17 campos; valores, datas, status e pagamentos com 0 diferenças.
- 05/11 (tarde): **D7/G9 aplicados** (empresa das negociações corrigida; importador usa a empresa da planilha para duplicata nova; conferência por empresa FECHA); achado G10 (Consultar Duplicatas lê `boletos`).
- 05/11 (tarde): **D1 aplicada** (guarda retirada de `importar_contas_pagar_receber.py`); **`scripts/conferir_contas_pagar_receber.py` escrito** (só leitura; gera Excel em `scripts/logs/conferencia_financeiro/`); 9 boletos de teste apagados (backup em `backup._bkp_boletos_teste_20261105`); achado G9.

## 16. Reunião 42, parte 04 (Filippo, 05/11 ~15h): o que foi dito e o que fazer

**Decisões e pedidos do Filippo:**
1. **Contas a Pagar = só o que ainda falta pagar (presente e futuro).** "Importar 13 mil não faz sentido agora; as planilhas históricas eu faço fora do sistema." → **desmembrar contas a pagar × contas pagas**: tudo que já está pago sai da lista de Contas a Pagar ("vai reduzir muito"); o histórico se ajusta depois. (**D15**)
2. **O Contas a Pagar não tem ligação com pedido de compra** ("exceto 40 fornecedores em comum, mas não tem relação"). Ao fazer um pedido, ele deve gerar **previsão de pagamento** (ou ao menos a informação). (**G17**)
3. **Cadê o nome / o contato / a pessoa / o destinatário** na lista de pagar. → resolvido (G11 e G13); falta o ID exato (G15).
4. **Confiança e método:** "tem que baixar a planilha, conferir se bate com o que registrou, **já** — não preciso esperar o Vinícius dizer que há diferenças; essas coisas não podem chegar crus a mim." → **conferência automática e proativa a cada carga** (G18).
5. **"Quando eu faço uma venda, está amarrado o cliente? Tem que ligar ao projeto? Vamos fazer uma máscara que visualiza tudo."** → visão única venda → cliente → projeto → financeiro → nota (G19).
6. **Fluxo:** venda → financeiro → emissão de nota (integração **Focus NFe**); a "condição de pagamento errada" tem que ser entendida de ponta a ponta.
7. **Pedidos de melhoria e erros** vão pela **Central de Solicitações** (fica documentado; ela já edita e anexa foto) — educar as pessoas a usá-la.
8. **Compras (Débora):** (a) o **desconto da caixa fechada aparece em dois lugares — deixar só em um**; (b) o **pedido de compra da Alloy "do dia 30" não aparece**. (**G20**)
9. **Contexto:** o Filippo diz estar inseguro e avalia contratar um consultor; cobra que o sistema funcione "completo, real", com conferências feitas por nós antes de chegar a ele.

**O que verifiquei no banco (05/11):**
- **Pedidos de compra × pagamentos:** dos **51 pedidos aprovados** (R$ 367.839,55), **só 16 têm parcelas de pagamento** (`pedido_compra_parcelas`: 55 parcelas, R$ 155.409,63, vencimentos até 25/12/2026); **35 não geram nenhuma previsão**. A tela Contas a Pagar **não lê** a view `vw_contas_pagar_pedidos_compra` (a previsão dos pedidos): por isso o Filippo não vê "o pedido virando pagamento". Fornecedores em comum entre pedidos e contas a pagar: **17 de 19** (depois da correção de pessoas; ele viu 40 antes de a ligação por nome existir para os fornecedores).
- **Pedido da Alloy de 30/10: NÃO existe no banco.** Não há nenhum pedido criado entre 29 e 31/10; o único da Alloy é o `PC-LEGADO-1692` (08/07, R$ 451,65, sem itens). Ou não foi salvo (erro na tela?), ou foi cadastrado com outro fornecedor. **Preciso do número/print que a Débora mandou ("R$ 1,50").**
- **Desconto da caixa fechada:** aparece no modal de gerar compra (`ModalGerarCompraItemOrcamento`) e em outro ponto do Compras; falta a Débora dizer qual manter.

- **P1 (D15) FEITO em 05/11 — Contas a Pagar só com o que falta pagar:** na tela Consultar Duplicatas do **Contas a Pagar** a situação passou a ser "A pagar (em aberto)" (padrão), "Vencido" e "Pagas (histórico)"; **não existe mais "Todos"** e as pagas só carregam quando se escolhe o histórico (nada foi apagado: os relatórios financeiros dependem das pagas). O Contas a Receber manteve todas as situações. **Contas em Aberto** já mostrava só o que está em aberto.
- **P2 (G18) FEITO em 05/11 — conferência diária automática:** `scripts/conferencia_diaria_financeiro.py` (`--ensaio`, `--carregar` ou só conferir) roda a cadeia de carga e entrega o relatório de uma página com o veredito BATE / NÃO BATE (em aberto por empresa, linhas ausentes, 6 campos críticos, espelho, ligações e pendências). Resultado de 05/11: **BATE** nos dois lados; nas linhas em aberto, conta bancária ligada em 11/459 (Receber) e 170/1.238 (Pagar) e 41 abertas do Pagar sem conta no plano de contas.

**Plano de correção (ordem):**
- **P1 — D15:** Contas a Pagar mostra só o que falta pagar; pagas viram "histórico" (aba/filtro separado, **sem apagar nada**: relatórios financeiros dependem das pagas).
- **P2 — G18:** `scripts/conferencia_diaria_financeiro.py`: roda tudo (carga → espelho → correções → conferência/auditoria) e **entrega um relatório de uma página** (bate / não bate, o que mudou, o que precisa de decisão), para ninguém descobrir diferença depois.
- **P3 — G17:** ligar pedido de compra ao Contas a Pagar: (a) exigir/gerar parcelas de pagamento no pedido aprovado (hoje 35 de 51 sem); (b) mostrar a previsão do pedido na tela Contas a Pagar, com a origem.
- **P4 — G14/G15:** Info com os 50 campos, decisão da baixa (D13) e ID exato da pessoa (D14, pedir ao Sérgio).
- **P5 — G20:** achar o pedido da Alloy e tirar a duplicidade do desconto da caixa fechada.
- **P6 — G19:** tela "máscara": venda → cliente → projeto → financeiro → nota.

## 15. Reunião 42, partes 02 e 03: o que foi pedido, o que está feito e o que falta (05/11, fim da tarde)

> A parte 04 (preenchida às 15:13) está analisada na seção 16.

**O que o Filippo pediu (02 e 03):**
1. **Confrontar a planilha com o que está no Supabase**, dizer as diferenças e **por quê**. → feito (seções 3, 10 e 12).
2. **"O back-end tem que alimentar corretamente"**: nomes errados (Pessoa 25, conta da Estela no nome da Ana Maria, Cristina × Figueiredo Nunes). → corrigido (G9, G11, G13).
3. **"Não é só importar a planilha: é importar e conectar com o front-end, que tem que mostrar a planilha com TODAS as funcionalidades que o front-end dá."** → **parcial** (G14 abaixo).
4. **"Na planilha tem que ter o ID de quem é o cliente/fornecedor: eu estou recebendo de quem? pagando quem? Não pode ser duplicação de nome; de lá puxa exatamente a pessoa; puxar do CRM."** → **parcial** (G15 abaixo).
5. **"Entender se essa é mesmo a planilha e sempre atualizar, fazer o confronto e atualizar as informações reais; depois o ID para amarrar."** → o confronto está feito para a planilha que temos; falta **confirmar que a planilha é completa** (G16).
6. **Usuário só de leitura para o Claudio** ver o Supabase. → pendente (D12).
7. **Da reunião 01:** confirmação nas aprovações; RT do arquiteto; registrar pagamento feito por fora (Pix 8502); status da nota fiscal da Connect; apagar dados de teste. → ver quadro.

| # | Pedido | Situação | Evidência / o que falta |
|---|---|---|---|
| 1 | Financeiro real, do dia, carga diária | **FEITO** | Importador liberado; roteiro escrito; em aberto fecha no total e por empresa. |
| 2 | Confrontar planilha × Supabase | **FEITO** | Auditoria de 17 campos: valores, datas, status e pagamentos 0 diferenças; 94,1% das linhas 100% iguais. |
| 3 | Nome da pessoa certo / nunca vazio | **FEITO** | 8.183 + 2.971 negociações ligadas; 139 pré-cadastros; espelho da planilha (283). |
| 4 | Planilha no Supabase (espelho) | **FEITO** | `connect_contas_espelho` (50 colunas, igual à planilha em linhas e somas). |
| 5 | Dados de teste do financeiro | **FEITO (parcial)** | 9 boletos de teste apagados (backup). Falta o Filippo confirmar se as 387 parcelas de projeto de 04/05 também são "teste". |
| 6 | Front-end com todas as funcionalidades | **PARCIAL — G14** | Ver abaixo. |
| 7 | ID exato da pessoa (sem depender de nome) | **PARCIAL — G15** | Ver abaixo. |
| 8 | Planilha completa e igual ao que a Connect mostra | **ABERTO — G16** | Caso Figueiredo Nunes / Copélia R$ 12.872 venc. 10/11 não localizado na planilha. |
| 9 | Registrar pagamento por fora (Pix 8502) | **ABERTO** | Fase B. |
| 10 | Confirmação nas aprovações | **ABERTO** | Fase B. |
| 11 | RT do arquiteto (tem / não tem) | **ABERTO** | Fase C. |
| 12 | Status da nota fiscal da Connect | **ABERTO** | Planilha não traz; precisa de exportação (D4). |
| 13 | Usuário de leitura para o Claudio | **ABERTO — D12** | Decisão. |

**G14 — Front-end com todas as funcionalidades (o que a tela Consultar Duplicatas faz hoje com as duplicatas da Connect):** lista, filtros (empresa, perfil, situação, datas, venda, fatura, duplicata, boleto, pessoa) e totais: **sim**. **Executar (baixa), Editar e Exportar: bloqueados para a duplicata da Connect** (decisão minha de 05/11: "só consulta"); **Acordo: "ainda não implementado"** (já era assim); **Info:** mostra só os campos do boleto, **não** os 50 campos da planilha. Para o pedido do Filippo faltam: (a) **Info com todos os campos do espelho** (conta, venda, nota, acordo, dev/troca, forma de pagamento, observação, funcionário…); (b) **decidir a baixa** de duplicata da Connect feita aqui (D13); (c) **Acordo**.
**G15 — ID da pessoa:** a planilha traz `cod_pessoa`, mas ele **não identifica a pessoa sozinho**: o mesmo número aparece como cliente e como arquiteto, e no Pagar 37 códigos têm mais de um nome (ex.: 278). A planilha **não traz o tipo da pessoa nem CPF/CNPJ**; no CRM os 357 fornecedores **não têm código da Connect**. Por isso a ligação ficou por **nome** (com pré-cadastro). **Para ter o ID exato (D14):** pedir ao Sérgio, que gera a planilha, que acrescente **o tipo da pessoa (cliente/fornecedor/arquiteto) e o CPF/CNPJ** (ou um id único), e exportar da Connect o **cadastro de Fornecedores** (código, nome, CNPJ) para gravar o código nos fornecedores do CRM.
**G16 — A planilha é completa?** Caso levantado pelo Filippo: "conta de R$ 12.872, vencimento 10/11, a pagar à Figueiredo Nunes / Copélia". **Na planilha de 05/11 não existe parcela de R$ 12.872 com vencimento 10/11** (a mais próxima é a duplicata 7912, parcela 1 de R$ 12.878,74, **paga** em 21/09, e a parcela 2 de R$ 12.669,33 com vencimento 05/11). A duplicata 7912 é de **acordo (nº 743) e marcada dev/troca**: o original de R$ 27.179,41 (duplicata 6988) foi baixado em 08/09 por esse acordo e substituído por 2 parcelas. Ou o item que o Filippo viu não está nesta planilha (exportação incompleta), ou a Connect mostra outra data. **Precisa do print da tela da Connect desse lançamento** para confrontar. Além disso, **866 parcelas do Pagar têm vencimento anterior à emissão** (dado da Connect), o que pode ser o "vencimento puxou errado".

**Decisões novas:** **D13** baixa de duplicata da Connect feita no sistema novo (hoje bloqueada): permitir e proteger da próxima carga até a Connect confirmar? **D14** pedir ao Sérgio tipo da pessoa + CPF/CNPJ na planilha e o cadastro de Fornecedores.

## 14. Espelho da planilha no Supabase (G13, 05/11 — "o nome da pessoa está null; a planilha tem que ser um espelho")

- **Problema:** o nome da pessoa vinha só do cadastro de contatos; sem contato ligado a tela mostrava vazio/"(sem contato vinculado)".
- **Solução (migration 283 + scripts):** tabela **`connect_contas_espelho`** = cópia 1:1 das planilhas ContaReceber/ContaPagar (50 colunas, chave `tipo` + `cod_itens_duplicata`) e colunas **`negociacoes.nome_pessoa`/`razao_pessoa`** com o nome COMO A PLANILHA DIZ. As telas Contas em Aberto e Consultar Duplicatas mostram, nesta ordem: nome da planilha > cadastro > "Pessoa <código>" (nunca vazio). Carga: `scripts/carregar_espelho_contas_connect.py` (passo 1b do roteiro), com conferência de linhas e somas contra a planilha.
- **Ensaio de 05/11 (dentro de transação desfeita):** espelho Receber 5.064 linhas (R$ 39.073.563,70; 459 em aberto · R$ 2.851.487,96) e Pagar 14.308 (R$ 46.791.596,03; 1.238 em aberto · R$ 4.082.025,35), **IGUAIS à planilha**; 10.569 negociações ganhariam o nome da planilha. Sem nome da planilha ficam só as antigas fora da planilha de hoje (1.022 Pagar e 2.436 Receber), das quais 475 também sem cadastro (mostram "Pessoa N").
- **Ordem de publicação (importante):** (1) aplicar a **283**; (2) `carregar_espelho_contas_connect.py --aplicar`; (3) só então publicar as telas (elas leem as colunas novas; antes disso a consulta falharia). **Status: migration, script e telas PRONTOS, nada aplicado/publicado.**

## 13. Mapa de ligações (ids) — o que cada coluna da planilha liga no Supabase e o que falta (05/11)

**Pergunta do usuário:** o que precisamos para ligar por id as planilhas, para não sobrar informação sem vínculo. Medido contra ContaReceber/ContaPagar de 05/11 (Receber 5.064 linhas, 459 em aberto · R$ 2,85 mi; Pagar 14.308 linhas, 1.238 em aberto · R$ 4,08 mi).

| Coluna da planilha (id da Connect) | Liga em (id do sistema novo) | Cobertura hoje | O que falta para fechar |
|---|---|---|---|
| `cod_duplicata`, `cod_itens_duplicata` | `negociacoes.cod_duplicata`, `transacoes.cod_itens_duplicata` | **100%** | — |
| `cod_empresa`/`nm_empresa` | `negociacoes.empresa_id` | **100%** (corrigido hoje) | — |
| `cod_pessoa` + `nome_pessoa`/`razao_pessoa` | `negociacoes.contato_id` | **~99%** (restam 501 negociações antigas pagas/canceladas) | **O número da pessoa da Connect não é único por tipo** (repete entre cliente e arquiteto, e os 357 fornecedores não têm `codigo_legado`). Gravar `codigo_legado` nos fornecedores a partir da planilha (código + nome únicos) para parar de depender só do nome. |
| `cod_apropriacao` | `negociacoes.plano_contas_id` (via `plano_de_contas.codigo_connect`) | Receber **97%**, Pagar **96%** por código | Criar no plano de contas: 10000008 ALUGUEL SÃO PAULO, 10000009 CONDOMÍNIO - SÃO PAULO, 2060003 MANUTENÇÃO CONTA (D10). |
| `nm_funcionario` | `negociacoes.funcionario_id` (via `funcionarios.nm_connect`) | Receber 96% | Funcionários ex-Connect sem cadastro (Katia, Ricardo). |
| `cod_conta`/`desc_conta` (1 Caixa, 2 Bradesco Lucenera, 3 Bradesco Islight, 4 Bradesco Foco) | `transacoes.conta_id` (via `contas_bancarias.codigo_connect`, só 4 contas) | O código existe em **90% (Receber) e 96% (Pagar)** das linhas, mas `conta_id` está preenchido em só **10% e 26%** | **Não precisa de dado novo:** preencher `conta_id` pela planilha. Falta cadastrar `codigo_connect` das contas que não são essas 4. |
| nome da pessoa começando com **código de projeto** (`26.245 NADIELE E JOÃO`) | `negociacoes.projeto_id` (via `projetos.codigo`) | Receber **37%** ligado hoje; o código do nome acha o projeto em **74%** (391 das 459 em aberto). Pagar 4% (despesa não é por projeto) | **Não precisa de dado novo:** ligar pelo código no nome (+1.943 linhas no Receber). O resto precisa do mapa venda → orçamento → projeto (abaixo). |
| `cod_venda` | `negociacoes.cod_venda` → orçamento/venda do sistema novo | A planilha traz `cod_venda` em 94% das linhas do Receber (hoje guardado). Mas das **3.122 vendas** citadas no Receber **só 272** existem como orçamento no sistema novo (herança); **2.850 vendas ficaram sem destino** (3.457 negociações; 261 com parcela em aberto). Pagar: 6% das linhas têm venda e 1.079 em aberto não têm | **Precisa de uma exportação da Connect** que ligue **cod_venda ↔ cod_orçamento ↔ cod_cliente/projeto** (relatório de Vendas/Orçamentos aprovados). Hoje só as planilhas de Reserva/Entrega Futura trazem esse par (só para o que está em aberto) e o XML traz o orçamento e o cliente, mas **não** a venda. |
| `num_nota` | `notas_fiscais_connect.numero` | Receber: 2.846 linhas com nota; **35%** existem nas notas importadas. Pagar: 2% | **Precisa de exportação das notas fiscais da Connect** do período que falta (a SPEC-204 importou só jan–set; faltam 2024–2025 e out–nov/2026). Sem o status de autorização por planilha (D4). |
| `nosso_numero` / `n_documento` (boleto) | `boletos.nosso_numero` | Só 3 boletos no sistema (os de teste foram apagados) | Definir se o boleto da Connect entra aqui (retorno bancário) ou fica só na Connect. |

**Ordem para fechar o "rombo":**
1. **Sem dado novo (posso fazer agora, no mesmo padrão com ensaio e backup):** (a) preencher `transacoes.conta_id` pela planilha; (b) ligar o projeto pelo código no nome da pessoa (Receber); (c) gravar `codigo_legado` nos fornecedores a partir da planilha; (d) criar as 3 contas do plano (D10, com o OK).
2. **Com exportação da Connect (precisa de você):** (e) relatório **Vendas × Orçamento × Cliente/Projeto** (liga as 2.850 vendas sem destino e os 261 recebíveis em aberto sem venda); (f) notas fiscais de 2024–2025 e out–nov/2026; (g) uma planilha antiga de Contas com nomes para as 501 negociações antigas sem pessoa.
3. **Regra daqui para a frente:** incluir no `auditar_financeiro_vs_planilha.py` o **relatório de cobertura de ligações** (pessoa, conta, projeto, venda, nota) e exigir que **toda linha em aberto** tenha pessoa, empresa, conta e plano de contas.

## 12. Auditoria campo a campo e correção dos campos (G12, 05/11 — reunião 02, "confrontar a planilha com o que está no Supabase")

**Como:** `scripts/auditar_financeiro_vs_planilha.py` (só leitura) compara CADA linha da planilha com o Supabase em 17 campos: status, valor da parcela, valor pago, desconto, juros, vencimento, emissão, pagamento, nº e total de parcelas, cod. da duplicata, cod. da venda, nº da nota, empresa, pessoa, plano de contas e forma de pagamento.

**Resultado ANTES das correções** (Receber 5.064 linhas, Pagar 14.308; 0 linhas da planilha ausentes do sistema):

| Campo | Receber | Pagar |
|---|---|---|
| status, valor da parcela, valor pago, desconto, juros, vencimento, emissão, pagamento, nº da parcela, cod. da duplicata, nº da nota | **0 diferenças** | **0 diferenças** |
| plano de contas | 1.483 | 856 |
| cod. da venda (sistema vazio) | 1.295 | 0 |
| total de parcelas | 753 | 0 |
| forma de pagamento | 95 | 1.763 |
| pessoa diferente | 8 | 1 |
| empresa | 1 | 0 |
| **Linhas 100% iguais** | 3.523 (69,6%) | 11.738 (82,0%) |

**Causas (por que não batia):**
1. **Plano de contas:** 2.981 negociações de Receber carregavam a conta da DESPESA de mesmo número (cópia de 29/06/26 — o mesmo número de duplicata existe como despesa e como receita). Por isso uma receita aparecia como "RT", "Compras - Revenda", "Frete entrada", etc.
2. **cod_venda:** o importador só gravava a venda ao CRIAR a negociação; as antigas ficaram em 0.
3. **total_parc:** o sistema guardava o total de parcelas do dia em que a duplicata nasceu (acordos e parcelamentos mudam isso).
4. **Forma de pagamento:** a planilha muda de "Duplicata Gerada/Boleto" para "Pix/Cartão" quando paga; o importador atualizava status e datas, mas não a forma.
5. **Pessoa/empresa:** ver G9 e G11.

**Correção (`scripts/corrigir_campos_financeiro_planilha.py --aplicar`, backup campo a campo em `backup._bkp_financeiro_campos_20261105_144330`):** 968 contas corrigidas no Receber e 6 no Pagar, 788 `cod_venda` preenchidos, 349 `total_parc`, 1.858 formas de pagamento. Transações, soma das parcelas, soma em aberto e soma paga ficaram idênticas antes e depois.

**Resultado DEPOIS:** **94,1% das linhas 100% iguais nos 17 campos nos dois lados** (Receber 4.766 de 5.064; Pagar 13.459 de 14.308). Valores, datas, status e pagamentos continuam com 0 diferenças.

**O que ainda difere (não corrigido, com causa):**
- **Pagar, plano de contas (848 linhas):** quase tudo é **só o nome** da conta (a Connect renomeou: "DESP. OPERAC. MANOELLA" × "Despesa operacional", "DARF GPS" × "DARF/FGPS", "Taxis fretes adm" × "Taxis/Frete/Uber", "Viagens visitas" × "Viagens/Vistas"); o código bate (13.766 de 14.308 iguais por código; 13 pelo alias decidido em 22/09). Há 4 contas da planilha que **não existem no plano de contas** do sistema: 10000008 ALUGUEL SÃO PAULO (13 linhas), 10000009 CONDOMÍNIO - SÃO PAULO (12), 2060003 MANUTENÇÃO CONTA (1) e o código 1 sem nome (as DEV TROCA, tratadas como Devolução por decisão de 07/10). **Decisão D10:** criar essas contas no plano?
- **Receber, plano de contas (153 linhas / 75 negociações), cod_venda (142), pessoa (8) e empresa (1):** concentram-se onde o **mesmo número de duplicata existe em mais de uma negociação/empresa** (804 negociações de Receber): o sistema escolhe uma vencedora e cancela as demais, e os dados da vencedora (conta, venda, pessoa) vêm da que nasceu primeiro. 104 `cod_venda` já tinham outro número no sistema (conflito, não sobrescrito). **Decisão D11:** reprocessar essas 804 duplicatas repetidas, caso a caso, com o Vinícius.
- **Pessoa (9 linhas):** duplicatas 1539, 2072 e 2988 (o mesmo número usado por clientes diferentes) e 2226 (planilha sem nome).

### Pontos da reunião 02 respondidos

- **"Previsão de comissão no nome do Clóvis":** **não existe** "previsão de comissão" nem descrição parecida nas planilhas (Pagar e Receber) nem em `transacoes`/`plano_de_contas`. A conta que representa comissão do arquiteto é **"RT"** (1.116 linhas no Pagar; 58 em aberto, R$ 213.328,50), e na planilha ela vem **no nome do arquiteto/empresa** (Storrer Tamburus, Camila Strang…). Se na tela apareceu em nome de cliente, pode ser (a) uma **receita** com a conta "RT" copiada da despesa (bug de plano, corrigido nesta rodada) ou (b) outra tela. **Preciso do print/da tela** para confirmar.
- **"Conta de R$ 118 no nome de Pessoa 25":** é a SAERP (água e esgoto de Ribeirão Preto), R$ 118,43, vence em 05/11/2026; estava sem contato; **corrigida em G11**.
- **"Conta da Estela de R$ 2.400 no nome da Ana Maria Prudente":** hoje **não existe** parcela em aberto de R$ 2.400 no Pagar na planilha; as duas de R$ 2.400 em aberto no Receber (duplicata 3857) estão com o nome certo (26.250 Guilherme Corrêa). O erro era a ligação de pessoa por código (G11, corrigido).
- **"Cristina × Figueiredo Nunes":** duplicata 7912, ISLIGHT, "COMPRAS - REVENDA", pago por Pix a parcela 1 (R$ 12.878,74, 21/09) e parcela 2 (R$ 12.669,33) vence em 05/11; **o credor é a Figueiredo Nunes Serviços** (a planilha), não a Cristina. Corrigido em G11.
- **"Usuário só de leitura para o Claudio ver o Supabase":** **pendente, decisão D12.** Opções: (1) usuário do SISTEMA com acesso às telas Contas a Receber/Pagar (só consulta, sem Executar/Cadastrar) — mais simples e sem expor o banco; (2) papel de banco `leitura_financeiro` com SELECT apenas nas views/tabelas do financeiro, conectado pelo pooler (exige criar senha — não criei); (3) chave de API anon + um usuário de leitura com RLS. Recomendo (1) agora e (2) se ele precisar consultar o banco direto.

## 11. Correção das pessoas (G11, 05/11)

- **`scripts/corrigir_pessoas_financeiro.py`** (ensaio e `--aplicar`; backups em `backup._bkp_negociacoes_contato_20261105` e `backup._bkp_contatos_precadastro_financeiro_20261105`): liga cada negociação ao contato pelo **NOME** da planilha (`nome_pessoa`/`razao_pessoa`, sem acento). Receber prefere cliente > arquiteto; Pagar prefere fornecedor > arquiteto > cliente. O que não existe vira **pré-cadastro** (Receber → cliente; Pagar → fornecedor) com nome e razão social da planilha e observação para completar CPF/CNPJ, contato e endereço.
- **Resultado:** 7.873 negociações corrigidas (6.018 sem contato + 1.855 com a pessoa errada), **138 pré-cadastros** (121 fornecedores e 17 clientes), 308 ambíguas puladas (mesmo nome em mais de um cadastro do mesmo tipo; aba `ambiguas_puladas` do Excel). Transações, valores e estoque não mudaram.
- **2ª passada ("corrigir tudo", 05/11):** as negociações antigas que não estão na planilha de hoje foram ligadas pelo **código da pessoa**: (a) quando o código tem UM só nome na planilha de hoje (despesa 874 + receita 1.019), ou (b) no Receber, pelo cliente de mesmo `codigo_legado` (1.078). Códigos com mais de um nome na planilha (ex.: 278 = Juliana e Stella no Pagar) não foram usados. Resultado: +2.971 negociações ligadas, +1 pré-cadastro; backups `backup._bkp_negociacoes_contato_20261105_142930` e `_bkp_contatos_precadastro_financeiro_20261105_142930`.
- **Ainda sem pessoa (501):** 355 de Receber e 146 de Pagar, **todas pagas ou canceladas, nenhuma em aberto**: sem nome e sem código utilizável. Continuam mostrando "Pessoa N" até haver planilha antiga com nomes (D9 resolvida com essa ressalva).
- **Empresa, resíduo:** 4 negociações ambíguas e 2 colisões do Receber (todas pagas) e 1 parcela paga de R$ 0 com empresa divergente (cod 4387). Nada em aberto; não corrigidas por não haver como decidir a empresa sem apagar/mesclar negociações.
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
