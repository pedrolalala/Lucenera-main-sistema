# Transcrição - 05. Lucenera (Filippo) - 30.04.2026: Dashboard financeiro e importação do Connect

- Título tl;dv: Filippo <> Adapta Pass
- Assunto principal: Dashboard financeiro e importação do Connect
- Data: 2026-04-30
- Horário: 11:07
- Link: https://tldv.io/app/meetings/69f3623f9ec3c90013df386c
- ID tl;dv: 69f3623f9ec3c90013df386c
- Duração aproximada: 51:22
- Participantes/e-mails capturados: kimberly@adapta.org; filippo@lucenera.com.br; pedro@lucenera.com.br

> Fonte: transcrição retornada pela API do tl;dv. Texto mantido com erros naturais de transcrição quando existentes.

## Transcrição

**[00:00] LAGHI Live:** A, o zoom da tela diminuiu 80%. Ah não, tô diminuindo a nossa conversa. A gente— consigo nem apagar. Travou o computador.

**[00:28] Kimberly Prestes:** Você viu que deu—

**[00:31] LAGHI Live:** apareceu mais uma parte, apareceu, apareceu. Agora ele sumiu.

**[00:39] Kimberly Prestes:** Deve ter dado um erro de UI.

**[01:04] LAGHI Live:** Então, eu baixei— eu tinha baixado um antes que eu tava sem ver, mas eu consegui clicar na— o arquivo. Escondendo o computador, tá pesando. Aí, ó, foram esses arquivos que baixaram.

**[01:33] Kimberly Prestes:** Calma aí que eu tô fazendo o mesmo processo para poder— O meu foi direto.

**[01:53] LAGHI Live:** Então provavelmente algum, algum bug.

**[01:57] Kimberly Prestes:** Você não conseguiu abrir aquele, o documento ali que ele baixa esse DMG, né?

**[02:05] LAGHI Live:** É, vou apertar aqui de novo.

**[02:15] Kimberly Prestes:** Aí no DMG abre aí a tua pasta de, de downloads e tenta clicar. É porque ele já foi baixado, né, do teu próprio navegador, tá proibindo.

**[02:29] LAGHI Live:** Então vamos lá aqui em downloads. Vou pegar o primeiro aqui que eu tinha baixado. Ele não tá abrindo. Eu tinha feito isso antes de começar a reunião, ele não tinha— ele Deu uma bugada, eu não sei o que aconteceu.

**[03:05] Kimberly Prestes:** É, quando abre ali o documento, às vezes teu computador tá muito pesado e daí ele não, não tá abrindo, mas é quando abre aquele— clica ali, ele já aparece o instalador.

**[03:20] LAGHI Live:** Show! Depois eu vou fechar todas as coisas aqui. É, depois você me manda então a gravação da reunião.

**[03:29] Kimberly Prestes:** Sim, você vai receber no teu e-mail. O Felipe também recebe no e-mail dele, eu coloquei a, a, o e-mail dele aqui nessa reunião dele, também vai receber, tá? Me mostre as tabelas que vocês têm para a gente pensar em como vai colocar isso ali. Você entendeu aquele processo que eu mandei lá, é, sobre, foi de produtos que eu fiz apenas, né? Porque aquela mesma ideia é para tudo. Então a gente tem que entender o que que é uma característica ali do, de um item específico. Então, por exemplo, produtos é uma tabela, aí vai ter, sei lá, categorias, aí é outra tabela, porque em produtos vai ter várias vezes que é uma categoria específica. Então isso vai pesando o banco de dados, e que, né, conforme vai crescendo vai, vai deixando mais pesado. Então aí ele só usa uma relação, e aí a gente só cria uma tabela de relacionamento ali entre eles. Toda tabela que tiver fora, que já vem, é, que ele já manda para você, é aquilo que a gente faz lá dentro do Superbase, que é o view, né? Então a gente pega várias, vários dados de tabela e cria uma tabela fixa, e ali no dele vem o código da tabela primária. A gente precisa criar, então, mesmo ele mesmo mandando, essas tabelas específicas, entendeu? Então, tabela de produto, tabela de categoria, tem lá o código. Então é só pegar o produto, tem o código ali específico, e qual é a categoria, a gente só deixa o código da categoria. E a gente cria outra tabela com o código, isso código legado, né? E o e as categorias específicas. Isso para todos os dados que a gente vai ter que importar. Então, é pensar na, no, em quais tabelas a gente precisa criar para não ter essa repetição de dados desnecessárias, e pegar o código legado. E a tabela principal, a gente só deixa o código legado para poder fazer aquele, é, look— agora esqueci o nome— mas fazer essa relação entre as duas para daí conectar a taluí dele.

**[05:45] LAGHI Live:** É o— ui, ai, di, né?

**[05:48] Kimberly Prestes:** Isso, isso, isso.

**[05:50] LAGHI Live:** Então eu te falei, né, que o Sérgio, ele falou que não poderia passar as informações para mim e tal. E aí a gente ficou meio com o pé atrás e um pouco com medo também, porque não sabe o que que ele pode fazer. E a empresa hoje em dia depende 100% do sistema, então não tem, não tem como a gente dar esse passo assim, tentar pegar todas as informações. A gente tá— eu tô meio que dependendo em partes do Vinícius para fazer essa exportação, para depois me mandar. O Filipe até chegou a me passar a conta dele, mas para eu ter acesso à conta dele eu tenho que estar no computador da empresa, porque ele falou que não vai baixar no meu computador. Então a gente tá nesse impasse. E realmente, o que que aconteceu? Vinícius foi lá e me mandou Várias planilhas com relação à parte do— mais da administração. Vou pegar as planilhas aqui.

**[06:54] Kimberly Prestes:** Inclusive, enquanto carrega, é só um parênteses, a— o Jean criou um sistema que é para os consultores usar. A gente consegue anexar o— os projetos o, né, o zip ali e colocar qual, qual API vai ser utilizado. E daí o sistema dele lá, que ele já criou o regs de todas as documentações, tanto do script, tanto da, das APIs. E daí eu pedi do, das APIs da Microsoft. Então quando a gente for fazer do SharePoint, aí já tem tudo ali. E a própria IA, quem tá usando o próprio Opus nesse sistema, que ele, por isso que está só para os consultores, Então essa conexão vai ser mais tranquila, né? Que todo mundo que eu conversei, falei, ah, alguém sabe ali que a gente tá se batendo por causa do SharePoint, essas coisas, né, que você tava com dificuldade de conectar API. Aí todo mundo falou, não, as APIs da Microsoft são horríveis, não são horríveis.

**[07:53] LAGHI Live:** Isso eu já falei para o Filipe, ele tá assim que ele falou, ah, então vamos trocar para o Google. Eu falei, calma, calma, porque tá tudo lá dentro da Microsoft. Aí ele falou, ah, não, tá bom. Aí então vamos lá, deixa eu pegar aqui.

**[08:10] Kimberly Prestes:** Mas daí agora vai ficar mais fácil as integrações.

**[08:13] LAGHI Live:** Não, perfeito. Aí para a gente é que o padrão do mercado é a Microsoft, infelizmente, né? A gente tem que aceitar isso e não tem muito para onde correr.

**[08:24] Kimberly Prestes:** A gente tá usando o Google, né, que porque a gente compra— a gente é os maiores consumidores de API do Gemini da América Latina, daí a gente já tem Não, mas eu entendo, é que assim, 90% do mercado vai ter a Microsoft como padrão, né?

**[08:43] LAGHI Live:** A gente fica nesse impasse. E a Lutineiros também, desde o começo eles trabalham com Microsoft, é que é mais tradicional, né? Deixa eu pegar aqui todas as categorias. Então essa aqui é só do estoque, que tem aquilo— eu já tinha te passado, só que ele adicionou mais algumas coisas aqui no estoque, que é o valor de custo indireto, o valor No valor de custo total já tinha, NCM não tinha, o resto tudo já tinha. Então a do estoque é basicamente a mesma coisa, só adicionou mais 2 campos. Isso é normal que eles estão mandando com mais informações cada hora, tentando puxar mais informação. Então eu acho que isso a gente vai ter um certo problema para ficar importando toda vez para o super base, mas é, não vai ter muito o que fazer. E essas são as categorias de fornecedores, fora tudo, tudo aquilo que eu já te mandei, né?

**[10:03] Kimberly Prestes:** Tem sim, da, dos produtos e da parte compra e venda, entrada e saída, né?

**[10:12] LAGHI Live:** Entrada e saída, tem, nossa, tem muita coisa que eles me passaram aqui. Eu recebo sim.

**[10:20] Kimberly Prestes:** Dentro de entrada e saída, só pensando, porque vocês têm o sistema lá do RH, né, também naquilo, é, dentro do, do, do, do, sai, é, entradas e saídas também tem o, o, os valores de pagamento do folha de salário, né, tá.

**[10:43] LAGHI Live:** Mas isso já tá dentro dessa, dessa pasta. E aí ela vai estar com uma, com, vai estar o de saída, né? É apagar, como apagar. Aí, aí ele basicamente já tá lá uma subcategoria que tem, é, RT, folha de pagamento, é, como que chama, bonificação, tem várias coisas, tem Também quando fecha um contrato tem porcentagem, então tem várias nuances de pagamento.

**[11:22] Kimberly Prestes:** Porque, por exemplo, tanto isso, tanto no, no estoque, nos sistemas que a gente vai criar quando essa— se a gente subir todas essas informações, vai ser meio que com regras, né? Então, por exemplo, o RH, ele vai ter todas as áreas. Isso só confirmando, tá? Vai ter todas as áreas ali de todos os funcionários já com os valores. Então isso já vai ser colocado, ou, em, por regra, quando coloca ali o salário, já vai ser colocado por regra nos próximos meses do apagar daquele, do financeiro, que daí como é tudo junto já vai aparecer lá na, no sistema financeiro dos próximos meses. Bonificações, a mesma coisa, que é o RH que cuida disso, né? A hora de importar mensalmente, né, essas coisas, até conseguir, né, sair do— vai ter que fazer um tratamento de dados para que saia, por exemplo, os dados do, do RH ali. Então bonificações ou o dos salários, para que saia dessas vertentes e vá para— e só sobe as informações que não vão estar por regra de outros sistemas específicos, entendeu?

**[12:49] LAGHI Live:** Sim, eu entendi. Agora eu tenho uma dúvida, porque você falou em fazer a correlação. Quando ela colocar no sistema, vai automaticamente para, para pasta do que tem que pagar, de contas a pagar. Então, pensando aqui, se a gente já exportou, a gente vai exportar todas as informações e ela vai colocar no sistema lá, não vai ter um conflito de valores? Porque, porque assim, como o que a gente exportar do sistema já vai estar com valor pago para funcionário, com todas as contas fixas, com tudo que é gasto, e no sistema, no RH, a gente já colocou o valor de funcionário, já tá meio avançado. Então, como que isso vai acontecer? A gente faz com que tenha um—

**[13:44] Kimberly Prestes:** vai dar— não, não tá o histórico, né?

**[13:49] LAGHI Live:** É, daqui para frente, sim.

**[13:53] Kimberly Prestes:** O que a gente tá importando é o histórico. Então daqui para frente, aí, ó, o que vai ser colocado dentro do sistema do RH, que é o que vai ser atualizado dentro das planilhas. Só que daí essas informações não pode vir do Connect, senão vai ficar duplicado esses valores, tá? Porque daí não adianta também falar, ah, não, o Connect vai, vai, a informação principal é do Connect. E não do, do sistema do RH. Mas aí vai ficar só um dashboard para o RH, porque daí não vai ter todas essas regras. E aí o sistema vai ficar, vai ficar muita coisa para fazer depois, né? Então é mais fácil fazer essa filtragem, porque ele tem categoria, né? Antes de você subir, é só você excluir as categorias referentes ao RH.

**[14:50] LAGHI Live:** Tá, eu acho que eu entendi.

**[14:52] Kimberly Prestes:** Isso é a mesma coisa para as outras tabelas, tá? Por exemplo, estoque. O estoque tem vendas e assim por diante. Então a gente tá criando o, o que a gente precisa arrumar, inclusive o de projetos e, e, né, e vendas. O de projetos no ele já tá com o banco preparado para que quando o projeto for dado no status lá de, de pago ali, o sinal, ele já vai sinalizar o estoque que é para ser reservado em tal data ali, que é para ser entrega, né, que tá planejado a entrega, que precisa ter aquele estoque. Então já vai estar como devendo e já vai estar no uma pré-venda no— ali dentro do financeiro, entendeu? Então já tá preparado o banco de dados. Aí é como a gente precisa pensar na hora da criação dos sistemas para poder— na— para ficar atualizando as planilhas com os dados que vão vir do, do Connect, para que a gente exclua essa parte dos dados que já estão em regra dentro das, das conexões de cada sistema ali dentro do banco de dados. É muito desses, vai ser tudo correlacionado, né, que já tá correlacionado a maioria.

**[16:19] LAGHI Live:** É, a grande maioria já tá correlacionado. Agora, o que o Felipe tá me questionando bastante é sobre o dashboard do financeiro. Eu acho que a gente deveria dar um, uma focada agora nisso. Para a gente entregar e já, já se livrar. Eu fiz toda a inclusão do CRM. No CRM a gente tinha as informações de projeto e projeto parcela, que é o valor fechado e quantas parcelas foi fechado, tal. E aí eu consegui— ele tá, ele tava querendo visualizar tudo. E aí eu consegui importar inclusive as vendas que não tem o código de de venda, eu criei uma, uma, um código para ele, um SQL, que a partir do primeiro venda, o próximo era V1, V2, V3, V4, e assim por diante. E aí eu já introduzi— deixa eu até pegar, colocar para cá. Você vai ver aqui que em produtos agora tá com um monte de— aqui, ó, todos os projetos antigos. E aí tem um— o que ele queria ver era se tava batendo as informações com o que tinha na planilha. Porque esse é o grande problema do que tava tendo, que não tava batendo o valor por conta de, das coisas que foram fechadas no passado. Porque é assim, tem projetos que foram fechados em 2021 que estão sendo pagos agora, porque eles, eles são projetos de casa, né? Você pensa, é casa, prédio, então demora para ser feito. E a iluminação é o último do, é a última parte do finalização da obra, antes de entregar mesmo para o cliente. Então muda, tem oscilação de preço, tem várias coisas, e são várias nuances que a gente tem que tomar muito cuidado, porque um, um, um cliente, um projeto, ele pode ter diversos fechamentos, assim, vários, ao longo da obra. E diversas parcelas, compras, então envolve uma coisa, é muito mais complexo. Quando ele começou a me explicar, eu falei, tá, Felipe, é muito mais complexo do que realmente eu pensava. É um negócio assim que tem várias nuances. Para um cliente só pode ter, ele falou, até 8 compras, até 8 projetos fechados. E dependendo, às vezes um um cliente em específico pode ter 8 projetos, entendeu? Trabalha com construtora, tem construtora que tem 6 prédios em Ribeirão. Sim. E aí dessa, desse cliente em específico vai ter de cada projeto tem 8 pedidos, entendeu? E aí eu fiquei realmente pensando nisso e como fazer para, para deixar 100%. Agora, da parte de cliente, da da parte de cliente, não, da parte de projeto aqui, eu introduzi todos os valores e tá batendo.

**[19:53] Kimberly Prestes:** Então os valores, né, porque eu coloquei parcelas para não ficar tipo, é, porque antes tava em colunas, né, parcela 1, parcela 2, parcela 3. Aí ali, ó, naquela outra tabela que é projeto para parcelas ali, ó, É, ele tem só um número, né, da parcela, e quando— e daí no projeto fechados daí fica o quanto que ele é, ou em projetos é o tanto de parcelas que vai ter, né. E aí tá em alguma parte, agora não vou lembrar, mas tem um monte de parcelas, ele é feito, então ele vai conectando com isso. Mas se tem outros tipos de parcelamentos, por exemplo, aí a gente precisa ver essas questões.

**[20:41] LAGHI Live:** É, então por isso que eu queria até que ele tivesse aqui, porque ele, ele iria falar sobre todas as coisas, todas as nuances. É, mas já de antemão, isso foi a parte que mais me pegou quando ele me falou sobre o, a compra e venda, como funciona, tal. E aí, enfim, isso aqui já, já é um ponto. Só que o que que eu fiquei meio com um pé atrás, e ontem eu fui fazer isso, eu já entendi mais ou menos como funciona, é como que eu vou pegar a informação de contas a receber e contas a pagar e introduzir aqui para ficar, para ficar exposto no Dash.

**[21:29] Kimberly Prestes:** Sim, o que, ó, a gente vai, vai introduzir esses dados, que era o que a gente vai ter que dividir, se vai ser uma tabela, outra, outra tabela, e a gente vai criar uma view. A nossa, a nossa tabela principal vai ser a view, que é o que vai ser conectado com dashboard. E daí a gente pode criar o sistema financeiro com dashboard e para o Felipe um dashboard completo.

**[21:54] LAGHI Live:** Entendeu?

**[21:55] Kimberly Prestes:** Sim, porque daí o view é isso aqui, verdade, que daí você tá montando tabelas, que é isso que o Sérgio manda para vocês. Ele só manda view aqui, essas views, eles não são dados, você não importa dados para ele, ele tá puxando dados de outras tabelas. Então você vai criar várias views e aí você vai conectar essas views com o teu dashboard. Então agora a estratégia é colo— aonde ou quantas tabelas a gente vai precisar criar para entradas e saídas, porque às vezes só contas a receber e a pagar, teoricamente o que muda é uma coluna, né, contas a pagar ou não. Então, só que tem outros detalhes. Então, por exemplo, categoria, categoria é uma tabela específica para não ficar se repetindo todo— todas as contas e outras coisas a mais. É, e daí, daí pode criar tanto dashboard dentro do sistema financeiro, tanto um dashboard com todas as views de todas as áreas para o Felipe ver todos os projetos, todos os— a parte financeira, porque daí isso é coisa de ali 2 horas você consegue fazer um dashboard completo porque a view já tá pronta do dashboard. E aí é basicamente isso, conseguiu entender?

**[23:12] LAGHI Live:** Sim. E agora, como que eu vou fazer a introdução do, das planilhas sempre. Depois que já tiver o esquema todo, todo funcional, é só introduzir e boa.

**[23:26] Kimberly Prestes:** Exato. Só que daí o que a gente precisa pensar é a parte de excluir dados que são as regras de outros sistemas, entendeu? Que, por exemplo, RH, você vai ter que excluir os dados, normalizar antes. Então, a categoria X não vai entrar né, nesse upload. Se a gente, por exemplo, na parte do sistema do financeiro— isso mais para frente, né, que não tá na, na, para ser próximo— mas, por exemplo, tem um sistema que a empresa vai usar, né, futuramente. E aí as solicitações por usuário, né, por funcionário, para o financeiro, para pagar alguma coisa, comprar alguma coisa, já vai ser regra. Então a gente precisa pensar todos os sistemas que já tem para ver se tem alguma regra específica. O CRM, ele, quando ele tiver rodando mesmo, ele, o projeto já vai para contas a pagar, contas a receber. Então essa regra é também, tem, vai ter que ser excluída da importação com SQL. É, ou não, antes de você importar, você só filtra aí, tá, tá.

**[24:43] LAGHI Live:** Então Pensando aqui, eu tenho a planilha de produtos, que é no caso a estoque, o quanto que tem estoque e tal. Isso daí é o quê? É o view, view aqui na—

**[25:02] Kimberly Prestes:** o que é VW, é view.

**[25:04] LAGHI Live:** Não, é, não tava mostrando, eu tava só falando, tá? É que eu tava mexendo no coisa, mas É, eu tenho essa planilha do estoque produtos, né? E aí essa planilha é tudo que tem correlacionado a estoque, valor de custo de peça, valor de venda de peça. E aí, é, eu já preciso meio que introduzir isso para o Filipe começar realmente ver. Então essa, a, a valor valor, não, contas a receber e contas a pagar.

**[25:43] Kimberly Prestes:** Se você quiser, eu te mando o esquema ou a própria planilha, é, manda a própria planilha para eu poder ver como é que tá os dados, tá? Aqui, ó, a atualização de todas as planilhas ali. O de produtos a gente não importou ainda, né? Que precisa mudar o esquema.

**[26:10] LAGHI Live:** Não, a gente ainda não importou produtos.

**[26:14] Kimberly Prestes:** Você me mandou duas de produtos e elas são diferentes. Uma era só os dados principais e a outra tinha outras coisas.

**[26:23] LAGHI Live:** Então a gente vai com a que tem tudo, tá? Que é justamente isso, a gente tá tentando desmembrar do Connect. A gente vai ter que ter o máximo de informação possível de tudo que a gente pode ter.

**[26:36] Kimberly Prestes:** Tá, contas a pagar e contas a receber, é essa mesmo, né?

**[26:40] LAGHI Live:** É essa aqui, foi a última.

**[26:43] Kimberly Prestes:** Oi, 26 do 3 é a última que eu tenho.

**[26:48] LAGHI Live:** É isso, é 26, é o ano, né? 26 do 3, 31. Isso, você tem essas planilhas?

**[26:56] Kimberly Prestes:** Essas duas eu tenho.

**[27:00] LAGHI Live:** Então a outra vai estar aqui, que é a do estoque. É, não, na realidade, a produtos eu te mandei ela completa, não mandei?

**[27:15] Kimberly Prestes:** Mandou, mandou. Eu, é o que eu falei, eu tenho duas planilhas, uma que não tava completa e a outra que, que tá.

**[27:20] LAGHI Live:** Então é isso que a gente precisa focar agora, no meu ponto de vista.

**[27:25] Kimberly Prestes:** E o de estoque?

**[27:28] LAGHI Live:** O de estoque é essa, é a produtos.

**[27:30] Kimberly Prestes:** Ah, de produtos, já tá. Essa que tá o estoque. Não, eu não tenho a completona, eu tenho duas, que é uma que não tem nenhum dado e a outra tem algo que tem tipo poucos dados. Deixa eu ver aqui. É, o que eu, o que eu tenho é uma que tem o código referência e a descrição do produto, e a outra só tem categorias. Tem junto com categoria.

**[27:55] LAGHI Live:** Deixa eu ver o que o—

**[27:58] Kimberly Prestes:** me manda a grandona do, do produto, tá?

**[28:03] LAGHI Live:** Eu vou te mandar, porque aí a gente conseguindo introduzir isso, Felipe já vai ficar um pouco mais de boa com relação a tudo, tá? Mas se eu acho que é É justamente aquela que eu te mandei, porque aqui para cima não vai ter muita coisa em relação a—

**[28:24] Kimberly Prestes:** porque, ó, a última que você me mandou, que foi a que tinha mais dados, é essa aqui que eu te falei agora, que ela tem até descrição. A que você me mostrou ali agora pouco, é, ela não tem tudo isso. Aí você só me mandou o A partir de sim.

**[28:47] LAGHI Live:** Então, só pegar aqui porque eu tenho— que o Sérgio tá exportando.

**[28:54] Kimberly Prestes:** Tá.

**[29:13] LAGHI Live:** Manda a última, já fica atualizado.

**[29:21] Kimberly Prestes:** Me manda também a de projetos que você importou, porque eu lembro que daí saiu alguns códigos para eu poder relacionar o, os arquitetos. Lembra que a gente conversou sobre isso? Só que o que tinha, que você tinha baixado no teu computador antes de eu, de eu arrumar o banco de dados, a de projetos, é que era completona, todos os projetos, que daí tinha o código de cada um, que eu vou precisar desses códigos de projetos.

**[29:54] LAGHI Live:** Vai estar aqui, se eu não me engano. Vamos por— mas eu não sei se aqui tem as informações do É aquela grandona que eu—

**[31:03] Kimberly Prestes:** dos arquitetos, é aquela grandona que tava antes no banco de dados, que você tinha feito backup no seu computador antes de eu mudar o banco de dados lá.

**[31:22] LAGHI Live:** Todos os backups que eu fiz estão aqui.

**[31:35] Kimberly Prestes:** Cria uma pasta no Drive para me mandar essas coisas.

**[31:39] LAGHI Live:** Vou criar, vou criar, daí me manda o link. Tá em CSV?

**[31:49] Kimberly Prestes:** Não, mas no Drive o, o sheet já muda automaticamente.

**[31:54] LAGHI Live:** Perfeito, melhor ainda. Mando pelo Google Drive então?

**[31:59] Kimberly Prestes:** Coloca numa pasta e daí já, já coloca tudo, tá?

**[32:06] LAGHI Live:** E aí, só, só lembrando para a gente realmente dar um— focar nessa parte do Dash para já entregar para o Felipe, porque toda a outra parte, o RH, já, já deixei meio que pré-pronto. Eu só tô dependendo da, da Lana, que a pessoa que mexe com toda a parte do RH lá da empresa, que ela tá me passando as coisas que precisam adicionar, os campos que precisam ser adicionados. Ela pediu para colocar o outros campos de, de salário, porque tem várias modalidades dentro da empresa, tem a porcentagem e tal. E aí ela, enfim, ela tá me passando tudo que precisa do CRM, já tá praticamente completo, todas as informações já importei para o CRM.

**[33:04] Kimberly Prestes:** É arrumar essas relações, né, que é por isso que eu Porque não, ela não tá puxando o arquiteto específico, né?

**[33:12] LAGHI Live:** Ou você não tá puxando o arquiteto específico, mas eu, como eu fui fazendo na mão aqui, é que agora não vai aparecer. Ah, vou puxar daqui mesmo. É, aqui em projetos eu já fiz a correlação aqui, eu tenho que ir para Ska-gonyo. Eu fui fazendo uns testes no CRM, comecei a importar na mão, e aí eu já fui fazendo a interligação do, dos arquitetos. Então tem alguns que tem, outros não, que a partir daqui Felipe, why? Será que quando eu introduzi a nova planilha ele jogou tudo para o— para o Felipe? Ah, não, aqui, aqui já tem um arquiteto e os clientes, tá? Mas é isso, só em alguns também, né? Só nos que eu importei na mão, o resto vai estar sem mesmo. Aí, como que você acha que a gente vai fazer isso? É literalmente pegar aquela planilha que tá completa e fazer a interligação com SQL?

**[35:51] Kimberly Prestes:** É, vai ter que fazer isso, mas, ó, eu— vai ter que ter o código legado para poder relacionar cada uma delas. Que aí o código legado do, do arquiteto, do cliente, exatamente, da planilha, tá bom.

**[36:07] LAGHI Live:** Então eu vou te passar tudo, já vou fazer o, o drive agora, vou te mandar todas as questões que a gente conversou. É, eu acho que é isso.

**[36:20] Kimberly Prestes:** Você tá fazendo na mão isso ou você usa IA na sua ideia ali?

**[36:26] LAGHI Live:** Como assim, fazendo na mão?

**[36:28] Kimberly Prestes:** Você mesmo tá fazendo manualmente tudo isso?

**[36:33] LAGHI Live:** Não, em grande parte eu uso aí a minha, minha auxiliando com SQL, mas ó, o que que dá para você fazer?

**[36:42] Kimberly Prestes:** Eu não sei se no VS Code tem como, mas o Antigravity da Google, que é outra ideia, você consegue colocar o teu Cloud Code na, no Antigravity.

**[36:54] LAGHI Live:** E aí eu tenho já no VS Code.

**[36:58] Kimberly Prestes:** Ah tá, e aí eu Eu sou— todo o refatoramento que eu fiz, eu fiz usando o Cloud Code conectado com o Supabase. Daí eu só dava OK e ele mesmo fazia.

**[37:10] LAGHI Live:** Interessante. Aí você fez algum código interno no terminal ou não?

**[37:17] Kimberly Prestes:** Só, só foi dando no terminal quando o Cloud Code— eu não uso no terminal, eu uso ele direto pelo chat, mas dentro da, dentro do, da IDE. E aí eu só passei as credenciais e aí ele conseguiu, ele já fez tudo. Que no antigo ele tem a extensão, né? Não sei se tem aí no VS Code. Ah, tem ali na extensão, tem.

**[37:46] LAGHI Live:** Então eu já meio que tô fazendo desse jeito, eu não tô fazendo o do Supabase, né? Explica certinho como que você fez.

**[37:59] Kimberly Prestes:** Clica ali, ó, tem engrenagem ali em cima, onde fica o— não, aonde fica o— isso, chat, tem do lado ali, ali mesmo, aonde abriu a engrenagem, MCP Service. Agora procura su-pa-base. Agora instala. Aí, agora ele tem acesso, e aí ele consegue fazer tudo.

**[38:44] LAGHI Live:** Aí, a partir do momento que eu pedir, é só introduzir uma planilha aqui, ele consegue já pensar qual que é a melhor forma de introduzir tudo lá dentro.

**[38:54] Kimberly Prestes:** Exatamente, e ele introduz e ainda faz todas essas relações, é tudo que você precisar, quer uma— é de functions com base em uma documentação, cria uma skill sobre a documentação e aí depois só falar usa essa skill para poder criar essa edfunctions e aí ele vai criar.

**[39:11] LAGHI Live:** Nossa, muito mais fácil do que eu tô fazendo.

**[39:14] Kimberly Prestes:** Sim, inclusive indo pelo OMCP você consegue colocar, por exemplo, N8N para você fazer workflows direto pelo, pela sua ideia.

**[39:26] LAGHI Live:** Eu não sabia disso. Qual mais que tem além do N8n?

**[39:31] Kimberly Prestes:** Tem qualquer coisa que você precisar. Por exemplo, ó, a parte de design, a galera usa muito o Stitch, né, o Stitch da Google, que é para fazer a interface ali mais bonita, né, do sistema. E você já usou?

**[39:47] LAGHI Live:** Não, esse kit não.

**[39:49] Kimberly Prestes:** Vou abrir aqui para te mostrar. Isso assim, essas coisas deixa muito rápido, como, né, eu preciso ser muito rápida para poder atender, né, essas questões mais complexas. E isso me ajuda um monte porque aí ela vai ali me ajudando, eu deixo ela fazendo. Porque se fosse fazer manual, aí esqueça, né? Deixa— ó, o Stitch só mostrando ali, ele é igual um, um skip, só que ele é voltado para design. Então ele faz designs muito melhores, protótipo, sites, ele manda muito bem nisso. E aí todo prompt que você manda, ele cria toda a interface. Consegue mandar também imagens de modelos que você deseja, é para ele seguir ali as referências. Quando você vem aqui, você consegue editar, por exemplo, editar. Aí o editar ou anotar aqui, você só rabisca a tela. Então, ah, eu quero que tal, sei lá, que, que essa região mude para tal coisa, eu escrevo e ele vai editar a imagem aqui exatamente. É, depois que você termina isso, você consegue conectar também com MCP para que ele pegue esses modelos e recrie todo o design do, dos teus sistemas. Daí é só você importar para o Skip ali depois que você fizer. E ou também você pode fazer direto no Skip, que é pegar aqui, ó, em mais, mostrar código. Copiar código, porque às vezes você vai fazendo e daí você percebe, putz, faltou tal coisa. Então aqui é bem mais prático porque você vai fazendo, vai só prototipando, né, o sistema. E aí você copia o código, baixa ali a versão, pode mandar para o Figma também se quiser fazer alguma coisa. E aí com o código e o— com o código e a imagem você pode mandar pro, pro, pro, pro Skip para que ele recrie as, as páginas com base naquele código e naquela imagem.

**[42:11] LAGHI Live:** Tá perfeito.

**[42:12] Kimberly Prestes:** É uma ideia.

**[42:14] LAGHI Live:** E agora você me deu um insight aqui de uma coisa que eu fiz para empresa, e aí ele tá no meu computador. Eu fiz aquele, aquela questão da ficha técnica Você lembra que a gente tinha conversado?

**[42:27] Kimberly Prestes:** Sim.

**[42:27] LAGHI Live:** Eu consegui fazer e consegui fazer com que todo mundo das equipes concordasse em, em centralizar dentro do código interno, porque tava no código externo e isso tava dando um conflito porque nunca tava certo. Então agora a gente tá renomeando tudo para deixar certo e o código já tá funcionando, ele tá emitindo PowerPoint da— de forma correta. E aí eu queria saber, em vez dele ficar rodando no meu computador, tem como eu importar para o Skip?

**[43:02] Kimberly Prestes:** Mas ele é qual linguagem?

**[43:05] LAGHI Live:** É Python?

**[43:06] Kimberly Prestes:** Não, não vai rodar, não. Ele é TypeScript e React. O que que dá aqui? Como é Python, você vai ter que Ele tem interface também, ou não?

**[43:22] LAGHI Live:** Tem, tem.

**[43:23] Kimberly Prestes:** Coloca na versão, e daí depois a gente, na hora de criar o sistema que vai centralizar tudo, né, os módulos, aí a gente só coloca aquele dali, mas daí ele vai ficar na versão, tá?

**[43:40] LAGHI Live:** É, mas de qualquer forma, né, de qualquer forma meu computador vai ter que estar rodando.

**[43:46] Kimberly Prestes:** Não, na Vercel ele vai estar na nuvem.

**[43:50] LAGHI Live:** aí na Vercel ele roda 100% na nuvem sem problema.

**[43:55] Kimberly Prestes:** Exato, você vai ter que colocar— é bem fácil, tá? Entra aí na Vercel, você vai ter que colocar ele no teu GitHub. Só um pouquinho que eu tô com 1% de bateria no computador agora que eu vi.

**[44:46] LAGHI Live:** É hoje um pouco complicado, eu acabo de falar com o Márcio, com o Pato, com o Zilu, ele realmente tá— tá meio gungido. Pode falar, o Felipe tava mandando mensagem.

**[45:02] Kimberly Prestes:** Tá, vamos lá, é, entra no— cria uma conta.

**[45:27] LAGHI Live:** Mm, what—

**[45:54] Kimberly Prestes:** Ai, que tem que criar, clicar ali, criar. Tá, agora você vai em adicionar novo. Ou deploy ali que tinha aparecido, sumiu. Pode entrar, ou se tivesse no GitHub era só mandar o link também, né.

**[46:59] LAGHI Live:** Aí, ó, GitHub, eu tenho que ver se eu fiz o, o commit.

**[47:17] Kimberly Prestes:** Aí você manda o link e clica em deploy, e daí ele vai fazer o deploy, e daí você já vai ter o link ali da própria, da Vercel, com ele na nuvem.

**[47:26] LAGHI Live:** Tá perfeito, ainda bem, porque eu tava— eu tô usando o meu computador, e aí ele tem que estar ligado para o pessoal usar.

**[47:36] Kimberly Prestes:** Quer ver, ó, se você ali, ó, Clica em importar ali, ó, o CRM. Aí ele já vê toda o— quais são as linguagens. E daí você clica em deploy, bem tranquilo, e pronto, já tá na— já vai estar na nuvem.

**[47:59] LAGHI Live:** Aí daqui não precisa pagar nada?

**[48:02] Kimberly Prestes:** Não.

**[48:04] LAGHI Live:** Porque a maioria dos— porque como é projeto interno, da maioria dos outros que eu tinha visto, ele tinha que pagar para, para colocar o—

**[48:13] Kimberly Prestes:** tem uns, às vezes tem umas limitações. Por exemplo, a primeira vez que você entra, ele demora ali 30 segundos para ele reiniciar, porque ele não fica ativo. E daí, se a pessoa tá usando o dia inteiro, ele não vai ter que reiniciar. Mas só na primeira vez, mas bem, bem tranquilo, não, 30 segundos, a ninguém, né? Aí pronto, fez o deploy. Se você quer ver, vai ter o domínio, olha ali, ó, o domínio da Vercel.

**[48:46] LAGHI Live:** Se você clicar aí, ele vem até— tá perfeito. Fechou, fechou.

**[48:58] Kimberly Prestes:** Aqui é barra login, né, o primeiro de vocês, porque não tem o site.

**[49:04] LAGHI Live:** Vai aparecer aqui mesmo ou no app?

**[49:14] Kimberly Prestes:** É, não, aí mesmo, barra login. Não deve ser esse, mas é só para—

**[49:20] LAGHI Live:** eu já entendi já, mas tem a vai ficar aqui. Então, perfeito. Eu já vou fazer isso agora, já vou subir e mandar um novo HTTP para, para equipe.

**[49:32] Kimberly Prestes:** Fechado.

**[49:33] LAGHI Live:** Obrigado, Kim.

**[49:34] Kimberly Prestes:** Obrigada, eu. E aí me manda o Drive que, ah, amanhã eu vou estar trabalhando e eu não tenho horário para atender. Aí eu já faço isso e te mando, tá?

**[49:48] LAGHI Live:** Tá perfeito.

**[49:49] Kimberly Prestes:** Fechado, então.

**[49:50] LAGHI Live:** Qualquer coisa, se você tiver alguma dúvida, pode me chamar. Amanhã eu também vou estar tranquilo.

**[49:54] Kimberly Prestes:** Fechado, então a gente vai conversando, tá? Tá. Tchau, tchau, Pedro.

**[49:59] LAGHI Live:** Tchau, tchau. Bom almoço. [MASKED] [MASKED] [MASKED] [MASKED] [MASKED] [MASKED]

