# Transcrição - 06. Lucenera (Filippo) - 13.05.2026: Limpeza de dados e relacionamentos no Supabase

- Título tl;dv: Adapta Pass - Lucenera
- Assunto principal: Limpeza de dados e relacionamentos no Supabase
- Data: 2026-05-13
- Horário: 09:00
- Link: https://tldv.io/app/meetings/6a0467ef097a350013b62060
- ID tl;dv: 6a0467ef097a350013b62060
- Duração aproximada: 02:09:29
- Participantes/e-mails capturados: kimberly@adapta.org; filippo@lucenera.com.br; pedro@lucenera.com.br

> Fonte: transcrição retornada pela API do tl;dv. Texto mantido com erros naturais de transcrição quando existentes.

## Transcrição

**[00:00] Kimberly Prestes:** Lá então, tá. Vamos para a parte que interessa. Dois pontos que você falou, Pedro, ali sobre o Supabase, né, os dados dos projetos que estão duplicados. Dá para fazer manualmente e exportar tudo de novo, a gente só vai ter que apagar e fazer novamente as relações. Mas como daí você já vai Aí você, todo o projeto novo não pode ser duplicado, e daí fazer manualmente, buscar pelo, pelo e-mail do arquiteto, e daí tem que verificar se tá o e-mail correto na planilha de arquitetos e responsável. Então você só tem que pegar, por exemplo, o responsável, você coloca o e-mail dele que tá ali de funcionários.

**[00:57] Filippo Giorgi:** Posso te perguntar uma coisa? Desculpa, porque vocês estão— posso te perguntar uma coisa? Mas não dá para pegar na planilha de projetos ou na planilha de contatos o nome errado que tem uma ideia diferente, falar essa ideia é esse mesmo manualmente? Não dá para fazer isso? Dá para fazer isso, que é o que a gente tá mais fácil para nós. Muito mais fácil que fazer automático.

**[01:27] Kimberly Prestes:** Sim, não, mas é isso que a gente tá fazendo. Aí vai ter que só ver porque as duplicatas não estão só em projetos, né? Então em arquitetos, daí a solução foi ter colocado em canônicos, né? Então tem o principal e esses subsidiários ficam linkados ao principal. Isso em arquitetos ou clientes. E arquiteto, né?

**[01:57] Filippo Giorgi:** Então, se nós mudarmos dentro de contatos, eu tenho 7 André Kalil. Não são muitos arquitetos que tem isso, alguns, mas por exemplo, 7 André Kalil. Eu escolho qual que é o certo, né? Qualquer ideia, o certo, e falo: esse é o certo. De lá, como a gente manualmente Pega esse id e copia, não sei, para ele interpretar esse nome vai ter que ser igual a esse outro, basicamente. Porque se eu coloco id certo, ele não transforma já o nome como é no id?

**[02:38] Kimberly Prestes:** Sim, pronto.

**[02:42] Filippo Giorgi:** No final, depois fica unificado, né? Automaticamente fica unificado. Então vamos fazer, vamos tentar fazer isso, que para nós, para mim, é a coisa mais fácil, que teria já feito.

**[02:56] Kimberly Prestes:** E daí é só conectar daquela forma que eu te ensinei ontem, Pedro. Tem que clicar e aí vai aparecer o André Calil. Só que ali no de arquitetos tá aparecendo só um, né, porque eu já só 2 ou 3, né.

**[03:13] LAGHI Live:** É, são 2. Um, no caso, ele tá como cliente. André Calil, que provavelmente deve ter sido um projeto que ele, da casa dele, ele era cliente.

**[03:23] Filippo Giorgi:** Exatamente.

**[03:24] LAGHI Live:** E aí o outro agora tá como só André Calil Sales. A gente retirou as duplicatas, só que eu preciso confirmar se todos os projetos que ele tem como arquiteto estão vinculados com o nome dele.

**[03:42] Filippo Giorgi:** E por que você não confirmou ainda?

**[03:45] LAGHI Live:** Não, eu tô olhando, né?

**[03:48] Filippo Giorgi:** Não, não, não, não. Você tira um print de tudo que está nele e depois da transformação você conta os projetos, você vê os projetos. É coisa de 2 minutos.

**[04:02] LAGHI Live:** Não, tudo bem, eu vi, tem, são 3 ou 4 projetos que estão faltando.

**[04:14] Filippo Giorgi:** E por quê?

**[04:16] Kimberly Prestes:** Você procurou se o seu projeto não tá linkado com outro contato? A gente precisa encontrar esses projetos, então tem que pegar o nome e procurar ali, e daí conectar manualmente, entendeu?

**[04:30] LAGHI Live:** Eu te mandei no WhatsApp.

**[04:32] Kimberly Prestes:** Calma aí, deixa eu abrir aqui. Agora é o trabalho de formiguinha, o bruto mesmo a gente—

**[04:43] Filippo Giorgi:** Desculpa, eu não sei se eu tenho uma visão errada, mas para mim isso aqui estaria resolvido uma semana, porque eu já fiz, eu ia por este caminho de entrar em contato e mudar essa coisa aqui, já com tudo um conferimento e ver. Eu não entendi agora como foi feito essa unificação após a qual estão faltando 3 projetos? De que jeito foi feito? Então, foi já feita essa unificação?

**[05:13] Kimberly Prestes:** É que foi feita.

**[05:17] Filippo Giorgi:** Como foi feita?

**[05:19] Kimberly Prestes:** Material?

**[05:20] Filippo Giorgi:** Com que expediente? Como foi unificado?

**[05:24] LAGHI Live:** Eu fiz com VS Code, o Copilot.

**[05:29] Filippo Giorgi:** Conversa com o pai do José.

**[05:34] LAGHI Live:** Eu fiz com inteligência artificial, peguei todos os coisas e falei para unificar.

**[05:41] Filippo Giorgi:** Pedro, eu não te falei de fazer isso manualmente. Nós temos um super base com uma quantidade de pasta, química, nomenclaturas que não interessam a gente. Não sei por que foi feito aquilo. Então já venho falando com Pedro muito: vamos limpar, fazer uma coisinha de cada vez, vamos ter controle do que acontece. Os suprimentos têm que ser alimentados o menos possível pela IA. Aí há bagunça, a gente sabe. A IA deve orientar a gente nessa coisa que tem que ser tão precisa como o seu papel. Não podemos pedir toda hora para ela ir lá dentro e mexer, porque ela vai bagunçar e a gente não vai saber o que ela fez. Esse é o problema. Para nós fica muito mais difícil ter controle do que foi feito. Vai ter que passar um dia fuçando o que ela fez. Então eu volto a falar: o caminho manual não é fácil. Se é fácil, Vamos fazer isso agora, por favor. Que orienta a gente fisicamente na tela a como fazer isso manualmente para outra situação, de repente tem outras arquitetos duplicados.

**[07:19] Kimberly Prestes:** Que você me mandou o print, quais que não tem? Confirmar agora.

**[07:43] Filippo Giorgi:** You understand, we are still fussing with this, but if it was, as I asked in the beginning, if it was easy to do this manually, we would have already done it, and it would be hyper-confiable. Vamos questionar o porquê fomos por este caminho de novo.

**[08:15] LAGHI Live:** Não é de novo, isso foi feito antes da gente conversar, Felipe.

**[08:19] Filippo Giorgi:** Ah, então tá. Então o que falamos, temos que voltar atrás, porque na verdade, desculpe, o que a gente fez, que eu vi, dos 25 projetos do André Caleu tinha 5, não faltavam 3, faltavam 5.

**[08:34] LAGHI Live:** Ele tem 25 projetos desde que começou, de 2024 para cá.

**[08:42] Filippo Giorgi:** Nos últimos 2 anos tem muito mais projeto que os 5 que eu vi, te garanto.

**[08:46] LAGHI Live:** Eu tenho aqui na coisa essa foto que você mostrou aqui no WhatsApp, que são os projetos que ele tá registrado.

**[09:00] Kimberly Prestes:** E aí, o que, então, já tá registrado esses?

**[09:03] LAGHI Live:** É esse que eu te mandei, é o que ele, o que tá no WhatsApp, né?

**[09:08] Kimberly Prestes:** E o que que não tá no WhatsApp?

**[09:17] LAGHI Live:** Tô procurando o nome dele aqui.

**[09:19] Kimberly Prestes:** É que os outros, Filipe, que não tá aparecendo, com base ali no que tá nas planilhas, né? Que tem um período que tem ali, é, já tá tudo no sistema. Então, o que não tá mostrando para você é que ele não tá relacionado, e daí tem que fazer manualmente mesmo, porque faltou dados para relacionar.

**[09:56] Filippo Giorgi:** Hoje você não está aqui, Pedro, né?

**[09:59] LAGHI Live:** Não, eu tô em casa. Eu te mandei mensagem no WhatsApp.

**[10:05] Filippo Giorgi:** Eu sei que isso aqui era importante. Deixa eu ver, eu queria compartilhar. Só que eu entendo que você não fizeram um passo em cima disso, mas tudo bem, vamos lá.

**[10:20] Kimberly Prestes:** Ó, Pedro, já encontrei um aqui, ó, dessa Soraia, Soraia 2611, no código de projetos ali do print que você mandou, ó, aqui, e não tá relacionado com arquiteto, e é o André Calil, tá? Eu tô tentando achar o André Calil aqui na Aí no caso só tem que, né, encontrar o código. Então, e pelo código aqui, ó, que todos os projetos têm, e pelo código encontrar o projeto. E aí vem em Architect ID, clicar duas vezes, encontrar o André.

**[11:18] LAGHI Live:** André Calil. Eu vou copiar o ID dele, certo?

**[11:27] Kimberly Prestes:** Sim. Aí eu vou em projeto dele, é só clicar duas vezes.

**[11:40] Filippo Giorgi:** Posso sinalizar uma coisa para vocês? Pedro, você já viu se nos projetos que devem estar aqui André Calil Sales tem? Porque aqui tem 5 aqui.

**[12:01] LAGHI Live:** Sim.

**[12:02] Filippo Giorgi:** Você viu quantos deveria ter?

**[12:05] LAGHI Live:** Já tô, já te mandei aí.

**[12:08] Filippo Giorgi:** Deixa eu ver aqui lá.

**[12:12] Kimberly Prestes:** Mas Pedro, olha aqui na tela para você ver. Você precisa aqui então é o código do projeto, o código do projeto você vai procurar dentro de projetos aqui, que é esse Soraya. Aí você vai faz assim até aqui no canto, vai chegar até o arquiteto ID, e aí você vai filtrar aqui, no caso, no Sales. Aí você filtra o nome igual a Sales com dois L's.

**[12:49] LAGHI Live:** Eu acho que é.

**[12:53] Kimberly Prestes:** Deixa eu ir por Or architect. Então você precisa ter o nome certinho da pessoa e relacionar.

**[13:29] Filippo Giorgi:** Bom dia, faz o favor, vocês, você pode ver isso aí na organização projetos, um tal de André Cassi, é, deveria ser André Calil que está arrumando os projetos e tem alguns projetos no nome desse André Cassi que não sei quem que é, que provavelmente é um erro de digitação dentro do arquivo.

**[13:51] Kimberly Prestes:** Hey, Manuel and Marcel.

**[14:22] Filippo Giorgi:** André Cassy, même, qui est le light designer là de Saint-Joseph de l'Auprès. OK, donc André Cassy, non, c'est André Cassy, mais il n'est pas André Kalimi.

**[14:45] Kimberly Prestes:** Tem outros dois Andrés aqui, que é só André. Ah não, é cliente daqui, desculpa.

**[15:10] Filippo Giorgi:** A lista, você vê, né?

**[15:17] Kimberly Prestes:** Tá, eu peguei aqui o nome certinho.

**[15:20] Filippo Giorgi:** Então, onde foram parar? Então, que imaginação! Fizemos uma coisa com Iá e não temos a mínima ideia onde estão mais que a metade desses projetos. Será que não é oportuno eu pedir para o Pedro: por que você não volta atrás dessa coisa? Volta atrás, vamos. Tem como voltar atrás desta operação e de novo fazer de uma forma diferente? É que, por exemplo, te peço uma informação. Como eu faço agora que estou na frente da tela? Não sei bem, que assim já vamos ver como eu faria. Como eu faço aqui? Espera, tem uma carinha. Anna Karina Bucci, em cima do André Kalimann, que é aí. Anna Karina sem a Bucci é Anna Karina Bucci. Anna Karina Bucci tem 2 ID, não sei por quê. Na verdade, até— ah, não, não, não, não, perdão, são 2 projetos dela. Essa outra Anna Karina em cima de Anna Karina Bucci é ela. Como vamos fazer isso aqui? Vamos falar para o Super Base que Anna Karina É Ana Karina Butch, me ajuda aqui, como vamos fazer? Vamos em contato.

**[16:39] Kimberly Prestes:** A gente aí tem duas maneiras, só que isso é a questão, é, a gente tá falando, mudando agora, indo para arquitetos, a gente vai arrumar os arquitetos ou vai arrumar os projetos? A gente precisa arrumar os projetos.

**[16:53] Filippo Giorgi:** Não, espera, precisa fazer o que é mais assertivo para a coisa automaticamente E eu acho que se a gente vai em contato e fala, coloca lá no seu babê, né, que o ID real de Ana Karina é o de Ana Karina Butch, ela transforma, ela unifica, não é?

**[17:17] Kimberly Prestes:** Sim, aí é só pagar o outro.

**[17:19] Filippo Giorgi:** E automaticamente aqui no projeto não puxa? Não, deveria.

**[17:27] Kimberly Prestes:** Ou não, aqui no projeto, aqui, ó, você vem aqui no projeto e você conecta aqui com Ana, com a Ana, e pronto. Aí ele já vai puxar o nome.

**[17:41] Filippo Giorgi:** Ok, então espera aqui, olha só, olha só, deixa eu te mostrar aqui. Eu aqui, tô aqui, tô com a Ana Karina aqui nos projetos. Acho que é justamente, você falou justo, depois eu cancelo no contato. Nos projetos eu vou falar que esse projeto aqui, Ana Karina, é de fato da Ana Karina Bucci. Como faço? Copia e cola?

**[18:04] Kimberly Prestes:** Não, aqui, ó, esse projeto X é da Ana Karina.

**[18:09] LAGHI Live:** Então seleciona o código do projeto, o código do projeto é o 24012.

**[18:45] Filippo Giorgi:** Como fazemos isso?

**[18:46] Kimberly Prestes:** É só clicar duas vezes e encontrar o contato.

**[18:54] Filippo Giorgi:** Ah, e vou selecionar o certo?

**[18:57] Kimberly Prestes:** Exatamente.

**[18:58] Filippo Giorgi:** Que era o que a gente tava fazendo ali com André Calil. Deixa eu ver, deixa eu ver. Só que agora, como acho facilmente ela? Puts, posso procurar.

**[19:09] Kimberly Prestes:** Encontrar facilmente, você precisa ir ali em filtros.

**[19:12] Filippo Giorgi:** Em cima, e escrevo Ana Karina. Não, ah, de filter, preciso fazer um filtro.

**[19:27] Kimberly Prestes:** Aí você pode filtrar só por arquiteto primeiramente. Aí você vai ali, ó, onde tá escrito, e deu, né? Não, tipo, daí você vai escrever arquiteto. Porque você não sabe exatamente como que tá o nome dela lá. E aplica o filtro.

**[19:46] Filippo Giorgi:** Aqui é nome, é nome, não arquiteto. Tem que escrever nome, né? Tem que filtrar por nome. Pera aí, então vou de novo. Tá, tá. Filter, add filter.

**[20:02] Kimberly Prestes:** Se filtrar por nome, você precisa saber exatamente o nome que ela tá.

**[20:06] Filippo Giorgi:** Nome. Exatamente isso aqui. Então esse é outro filtro, hein?

**[20:12] Kimberly Prestes:** Add.

**[20:14] Filippo Giorgi:** Ah, e o Ana Karina. Ana Karina. Ah não, Abugi, porque preciso selecionar o certo. Vamos ver. Não, não encontrou. Alguma coisa.

**[20:35] Kimberly Prestes:** É, tem que saber exatamente o nome, entendeu? Por isso tem que fazer em vários. Então pega o André Calil, já sabe o nome dele, faz todo o levantamento de todos os projetos e vai um a um.

**[20:48] Filippo Giorgi:** Por causa, para isso que a gente, como perdeu muitas informações, precisamos voltar atrás. Por favor, pode orientar o Pedro Vocês podem ver como voltar atrás desta operação que fizemos semana passada, Pedro, que já te falei, eu já preciso voltar atrás porque perdemos as informações.

**[21:10] LAGHI Live:** Então a questão é que a gente, eu fiz, eu tentei fazer a correlação falando que o André Kalil era para centralizar tudo com aquele mesmo de arquiteto, certo? E aí ele foi lá e pegou e só juntou em 5, em 5 projetos. É, como que você acha que é a melhor forma da gente voltar atrás em relação a projetos?

**[21:38] Kimberly Prestes:** É o certo é a gente pegar e você tem a migração que você fez dentro do Webflow, você pode pedir para ele refazer e tirar essa solicitação. Atualização e ele vai refazer o que ele fez.

**[21:56] LAGHI Live:** Você já tentou fazer dentro do VS Code que eu mexi?

**[22:01] Kimberly Prestes:** Você pode pedir para ele refazer, refazer a determinada SQL que você subiu.

**[22:19] LAGHI Live:** Tem que inclusive ver aqui, analisar arquitetos.

**[22:28] Kimberly Prestes:** Mas quais foram os códigos que você não encontrou dos projetos, Pedro?

**[22:39] LAGHI Live:** Como assim?

**[22:39] Filippo Giorgi:** Eu te falo, eu te falo já.

**[22:43] Kimberly Prestes:** Pode falar, Felipe.

**[22:45] Filippo Giorgi:** Espera um momentinho, eu só preciso achar a coluna certa. Selecionar primeiro todos que são aqui. Não, selecionar isso que é isso aqui. Remove aqui. Search. Item. Soraya não tem. A Marcinha tem, Roberto, Felício tem.

**[23:17] Kimberly Prestes:** Tá, então se for essa da Soraya, o problema não é do Supabase que tá faltando dados, o problema é que tá faltando relacionamento, e é essa parte agora manual, porque todos os dados, tanto de projetos fechados, daquela planilha que a gente tinha, e de organização projetos que a gente tinha, Tudo está aqui, tanto que ele pegou, por exemplo, talvez seja isso.

**[23:45] Filippo Giorgi:** Tem outros 10 aqui, deixa eu falar outros, porque antes de dar já uma diagnóstica em cima de um exemplo só. E aqui tem também Fernando, cidade de Petrópolis.

**[23:59] Kimberly Prestes:** Qual é o código?

**[24:02] Filippo Giorgi:** Código, acho que tem um telefone 25-0-80-86.

**[24:11] Kimberly Prestes:** Calma aí.

**[24:11] Filippo Giorgi:** 5-0-8-6.

**[24:20] Kimberly Prestes:** Tá aqui, ó, Fernando, cidade de Petrópolis.

**[24:24] Filippo Giorgi:** Onde está?

**[24:25] Kimberly Prestes:** Aqui, ó, nos pavês. 25-0-86. Mas não está no estado aqui com aquele do André, porque ele não está com arquiteto ID do André. Aí tem que entrar aqui, clicar, pronto.

**[24:45] Filippo Giorgi:** Na automação não foi feita uma coisa correta, é isso?

**[24:50] Kimberly Prestes:** É porque não.

**[24:51] Filippo Giorgi:** Então não podemos voltar atrás, que assim estão todos encolhidos um atrás do outro para mim. Senão tudo bem. Agora vou ver de filtrar por André, mas não, mas lá não tem mais o André Calil, não tem mais nem André Calil agora.

**[25:05] Kimberly Prestes:** É André Calil de Sales o nome do arquiteto, porque o outro é André Calil, é cliente. E o André Calil de Sales é o arquiteto.

**[25:18] Filippo Giorgi:** Sim, mas desculpa, é aqui. Eu tenho aqui André Calil de Sales. Onde? Pronto, tenho 1, 2, 3, 4 e 5. Aquele lá não está aparecendo aqui. Onde que tá aparecendo? Onde que eu vou encontrá-lo? Em qual? Não tem outros André Calil? Eu posso procurar eu também, mas só para você me ajudar, que você encontrou.

**[25:46] Kimberly Prestes:** É porque esse daí já virou um só, né? Porque está vendo a planilha do Excel? Onde você tá aí? Que eu não tô vendo.

**[25:53] Filippo Giorgi:** Projectos, é a planilha de projetos, estão todos os elencados. Agora eu vou tentar.

**[25:59] Kimberly Prestes:** Qual que é o nome da coluna, Filipe?

**[26:04] Filippo Giorgi:** Esse aqui, nome arquiteto, eu acrescentei porque senão não dava para ver nada disso, né? Eu preciso visualizá-lo aqui para poder ter esse conferimento. E aqui Antes estava o André Calil, estava do jeito que está nessa coisa que me mandou o Pedro, que é de André Calil, André Calil com acento, André Calil sem acento.

**[26:39] Kimberly Prestes:** Como tá aqui vários André Calil, ó, e mesmo o do Fernando, o do Fernando não subiu com o André Calil.

**[26:49] Filippo Giorgi:** E subiu como?

**[26:51] Kimberly Prestes:** Resultadamente não está mais aqui.

**[26:55] Filippo Giorgi:** Sem nada de arquiteto. Então, então isso, Pedro, é que vocês veem como esta coisa automática não deu certo.

**[27:06] Kimberly Prestes:** É que o automático subiu os dados, Felipe. Agora, o que não tá relacionado vai ter que fazer manualmente mesmo. Então é procurar.

**[27:15] Filippo Giorgi:** Mas então eu começava já manualmente. É isso que eu quero fazer, voltar atrás, porque eu Acho que será que é mais fácil voltar atrás ou é mais fácil? Então agora eu vou pôr projeto por projeto, vou procurar. Tá bom, vamos não voltar atrás e fazer projeto por projeto.

**[27:31] Kimberly Prestes:** Mas eu, eu, vocês têm certeza absoluta que essa operação que fizeram não gerou outras alterações, outras coisas que de repente nós não vamos só conhecer na hora que É isso que eu falo, bateu certinho os números ali, que era, vou falar números exatos ali para não ficar quebrando, mas é mais ou menos os 800 projetos que veio da planilha de organização, e daí tinha mais ou menos 600 projetos que vinha da planilha de projetos fechados, tirando as duplicatas ali. Juntando tudo isso dava os 1400, que ali tem 1481. Esses quebradinhos, 81. Então tá batendo exatamente porque eu peguei ali.

**[28:28] Filippo Giorgi:** Porque juntou, como juntou os projetos fechados, os mesmos dos projetos na organização são uma quantidade menor porque não todos fecharam, mas os projetos fechados não são 600 projetos a mais do Organização Projetos.

**[28:46] LAGHI Live:** Mas são 600 projetos que fazem parte do Organização Projetos, que vieram antes de 2024, que foi aquele filtro que a gente fez, mas só foi fechado depois de 2024.

**[29:06] Filippo Giorgi:** Não, mas não podem ter sido 600 projetos a mais.

**[29:09] Kimberly Prestes:** Não, tinha mil e poucos, daí a gente já tirou as duplicatas e ficou 600, entendeu? Dentro planilha de projetos fechados.

**[29:18] Filippo Giorgi:** Olha, eu vou falar uma coisa para vocês: eu não entendo tanto de técnica, mas eu entendo bem do que estamos fazendo. E te falo, eu falo para vocês, ou se trabalha manualmente ou com operações de A que são extremamente É comando simples de aqueles coisas SQL, beleza, que tem que usar. Mas não quero que se passam essas coisas onde a gente não sabe o que que acontece, não sabe.

**[29:55] Kimberly Prestes:** Mas pelo menos o que a gente roda, e até o Pedro quando ele fala VS Code, ele tá rodando SQL, tá? É que o VS Code cria o SQL para poder rodar.

**[30:06] Filippo Giorgi:** Eu sei, mas nós temos saber que Temos que ter um controle maior, gente. Não podemos fazer uma operação e não saber onde foi uma coisa, onde foi a outra. Isso é o ponto. Eu não sei como vocês querem, cuida, mas eu, se nós continuarem assim, nós arrumamos umas coisas, fazemos operação e sem saber para onde são outras. Então, vamos para frente e voltamos para trás toda hora. O CMR ainda não funciona 100% por causa dessas coisas. Quando seria já pronto, estaria pronto há um mês, mas não sei porque ainda não funciona devido a essas coisas. Então vamos começar. Ah, Kimberly, CMR, vou ter que limpar tudo. Tem um monte de pastas que eu não faço nada com elas. Então lá vocês fizeram um carregamento geral de tudo que não funciona para gente. Trindade. Eu preciso visualizar partes daquilo que são coisas que são da nossa trindade. Não basta você fez toda aquela coisa sobre avaliação RH, eu contrato uma pessoa por ano, não preciso disso, entendeu? Você tem que entender que não é tudo que vocês falam na DAPTA ou por outros clientes, nós não somos advogados, não somos médicos, cada um tem uma série de dados e de operações que faz diferentes. Então a gente tem que entender o que nós precisamos. Então agora nós temos que montar um super base. Não vou querer pegar um miro e falar: me faz super base desse miro. Não, montar uma pasta de cada vez, linkar ela manualmente com que tem que ser linkado, Quais você quer? Ele gosta do comando, mas quero fazer uma coisa de cada vez, que nos dá, nos permite de ver. Não são uma quantidade de dados infinitos, são menos passos do que você criou, entendeu? Então a gente tem que limpar de novo, deixar só as que são realmente as nossas informações e ir alimentando com o que eu pedi para Vinícius de fazer agora toda a lista. De todas as planilhas. E não só agora, planilha por planilha tem que pegar, salvar para essa planilha. É dessa forma que a planilha é, são essas informações que eu preciso lá dentro. Se não fizermos isto, estamos fazendo coisas sem consistência, sem relação com— não vai entregar o sistema de gerência na sua empresa, vai Vai mostrar uma máquina que faz umas coisas a mais, umas coisas a menos, e não é o intuito, porque sem que faça tudo que nós precisamos, não podemos implantar isso como sistema. Então vocês têm que ajudar a gente a fazer isso bonitinho, um passo cada vez.

**[33:10] Kimberly Prestes:** Ok, aí fica a critério, vocês querem refazer toda a planilha de projetos Aí vocês pegam o que vocês já têm e precisa do, e normalizar todos os nomes de arquitetos e colocar um código para cada um. Toda vez que repete o nome, repete o mesmo código do lado ali, né? Criar mais uma coluna dentro da planilha, não dentro dos database, para depois conseguir fazer essa relação por SQL. Porque o problema da tabela de projetos é que ela não tem o código do do arquiteto. E as outras planilhas, ela tem o código do arquiteto, só que tem arquitetos que estavam duplicados, então eram mais de um código. E daí tem o código de pessoa que lá no Connect tem, tanto que eu puxei o código de pessoas para cá para eu conseguir fazer, né, para a gente conseguir fazer algumas ações. Então, pelo código de pessoa Agora, em projetos, todos os projetos que estão no, nas planilhas de organização de projetos e projetos fechados já estão no Supabase. O que não está aparecendo aí, como a Andrea Calil, você só precisa procurar pelo código aqui na segunda coluna e verificar aqui em arquiteto e selecionar qual é o arquiteto, qual é o responsável. Então é esse o trabalho de formiguinha que tem que fazer, que é basicamente o mesmo trabalho que tem que fazer lá. A mesma coisa que tem que fazer em todas as outras tabelas que já possuem dados é verificar cada uma delas. Puxa pelo código, verifica, vê se tem selecionado pelo ID do responsável, da pessoa, do cliente certinho. E aí vocês vão, vão conectando essas coisas no sistema. Porque, por exemplo, projeto ou cliente, família, que eu vi que tinha muito isso, tinha às vezes está conectado com o cliente, às vezes é o mesmo arquiteto, depende do cliente, daí o projeto é diferente, daí o arquiteto muda o nome. Então dá para fazer tudo isso ao mesmo tempo. Vou fazer primeiro do André Calil, que tem mais. Aí pego tudo do André Calil, é, e pronto, conectei tudo. Vou lá em contatos e vejo tudo que tem o nome dele. Deixo só um, só deixo um de cliente, um de arquiteto, né, porque ele tinha os dois. Ok, passa para o próximo arquiteto, vê o que tem, é, ver todos os projetos que tem. Ok, vai lá em contato.

**[35:55] Filippo Giorgi:** Entendemos, então essa coisa manualmente assim, ok. Agora, reorganizar as pastas todas, ou seja, limpar do que tem, que muita coisa que não precisamos, que foi criada de forma automática, que talvez poderemos precisar mais para frente. Mas eu gostaria de os clubes crescerem na forma que está entendido para a gente, que está alimentado, que está controlado, que estão linkadas as coisas. e não já tudo montado e depois vamos alimentar as pastas, porque isso aqui gera uma visualização muito complexa, muito, né, um pouco dispersiva. Então vamos, que vamos fazer? Vamos cancelar todas as partes que não precisamos.

**[36:42] Kimberly Prestes:** É só vir aqui o que não tá sendo utilizado nas outras colunas, por exemplo, candidatos e avaliações, e deletar tabelas. A questão é Categorias financeiras, por exemplo. Categorias financeiras existem para que o código não fique replicado em todas as 14 mil linhas do financeiro. E aí, por isso que tem o código, que é exatamente igual o Connect. É categorias de produto, mesma coisa. Esse contas a pagar, contas a receber, a gente já unificou. O Contas bancárias, essas três são o código ID que está dentro das planilhas que vem do Connect.

**[37:27] Filippo Giorgi:** Mas isso aqui está já linkado, que cada vez— isso que é importante, se isso aqui está já funcionando, ótimo, que não temos que construir. Toda vez que baixarmos, a— como é que está conectado? Como?

**[37:40] Kimberly Prestes:** Com Conecta não tá conectado, está— eu mandei o Python ali, né, que vai fazer essa, essa conexão. Mas os scripts já entendem que a planilha, quando vem do financeiro, ou contas a pagar ou contas a receber, e tem lá o código, é o código da conta bancária, ele já entende que é do Bradesco, que já, que é do, e aí ele já faz essa correlação. contato de contas bancárias. Esses códigos precisam ter—

**[38:43] Filippo Giorgi:** para mim estará tudo ok quando ele estará funcionando dentro do sistema. Ou seja, não está ainda. O que falta? Falta linkar, falta baixar essas planilhas que vem do banco.

**[38:58] Kimberly Prestes:** O que falta linkar é as coisas mais brutas agora, é linkar projetos, é linkar É, né, a parte do financeiro que tem coisas que não tá linkadas porque não tinha informações o suficiente. Então, ó, agora é um trabalho manual, que é isso que a gente tá falando de projetos, é linkar com arquitetos responsável. Em transações precisa linkar com transações, precisa linkar aqui com projeto. Parcela, categoria e todas as outras coisas que precisa para poder aparecer, entendeu? Que daí esse trabalho manual, de que forma?

**[39:47] Filippo Giorgi:** Então vamos lá, com respeito, vamos um momentinho entender. Estamos falando contas a pagar. OK, aqui não tem nada.

**[40:02] LAGHI Live:** É, ele tá em transações, contas a pagar.

**[40:06] Filippo Giorgi:** E contas a pagar, então, que é, tá em transações.

**[40:11] Kimberly Prestes:** E aí você vê o que que é.

**[40:14] Filippo Giorgi:** Então, conta a pagar, essa pasta conta a pagar serve para alguma coisa?

**[40:21] Kimberly Prestes:** Não, você, ela vai ser apagada. Já a gente conversou.

**[40:24] Filippo Giorgi:** Então é transações.

**[40:28] Kimberly Prestes:** Aí tem tipos de receita ou despesa?

**[40:32] Filippo Giorgi:** Transações. Aqui são todos. Isso é só pagar ou é receita, despesa? Então são todas, todas, né? Isso é alimentado diariamente.

**[40:52] LAGHI Live:** Isso foi da planilha que o Sérgio mandou, não tá saindo diariamente, mas a gente vai alimentar ela diariamente.

**[41:00] Filippo Giorgi:** Eu só tenho, eu só vou entender porque isso é super importante, o ministro também tem que saber, tem que, então, isso vem do Bradesco ou do sistema? Do sistema. Ok, então, BIM. Isso aqui é já, não sei, seria importante acompanhar na tela. Você entra no Supabase e vê transações. Transações é a planilha que vem do sistema de todas as contas a pagar e a receber. Agora, justamente você que ainda nem falava, tem que ser conectada com o projeto, etc., para ser alimentada internamente.

**[41:47] Kimberly Prestes:** Certo, sim.

**[41:48] Filippo Giorgi:** Portanto, daqui vai ser super importante entender como fazemos isso. Um projeto fecha, né? Quando o projeto fecha, o orçamento, esse orçamento, vamos lá, 100 mil fechadas. Em 4 parcelas de 25, com as datas. Isso aqui é carregado dentro do nosso sistema Conecta Org e nosso sistema do Genera Amanhã, né? Então nós precisaremos fazer essa máscara, né, de fechamento. Fechou tantas parcelas, não sei pelo— bom, e vai registrar essa informação aqui dentro. Como vamos fazer isso?

**[42:41] Vinicius Bortolin:** Tá, precisa o Vinícius quer falar, daí a gente já deixa eu tentar entender, tentar passar um pouco aqui minha posição, tá? Me parece muito confuso ainda, tipo, a gente tá tratando da parte do contas a pagar, contas a receber, e a gente não tem ainda estruturado, que foi a confusão no começo, dos projetos em si. Porque assim, o contas a pagar e o contas a receber, eles só vão acontecer depois que um orçamento fecha. Então eu penso assim, se a gente, se pelo Supabase, né, tô falando, se a gente não tem muito bem estruturado lá, a gente pode usar o Supabase, por exemplo. Eu acho que é válido a gente usar, por exemplo, os dados de contas a pagar, contas a receber, para a gente poder fazer uma análise. Do que já aconteceu nesse primeiro momento, 24 e 25, porque ali não se mexe mais. 26 está acontecendo. Para aquilo ser alimentado e ter toda essa conexão que quer ser feita, os cadastros de clientes nos fabels precisa estar perfeito, tem que ser carregado ou é conversado. Se a gente quer montar o nosso sistema, teoricamente não pode ter API. Correto, ou a gente inicialmente tenta uma API com o Sérgio. Mas vamos lá, porque é rápido fazer o sistema. Não, beleza, mas se a gente não estrutura o cadastro de cliente certo, o cadastro de arquiteto com os links, os engenheiros, eletricistas, que a gente nem tem no sistema, esse link dos projetos que tá sumindo dados, porque o contas a pagar, por exemplo, ele só surge Num pedido de compra, desculpe, eu entendo que você está falando, mas o contratar, pagar e receber se baixa muito facilmente do sistema. Não, tá, mas o Sérgio gerou um script que gera planilha diária.

**[44:45] Filippo Giorgi:** Não, mas não, mas a questão é que a gente tenta entender um pouquinho. Para fazer isso, é lógico que tem que montar as coisas na medida que temos. Nós estamos mudando o que você está falando, que está problema, mas estamos montando. Isso aqui justamente estamos resolvendo, vamos resolver os problemas e vai e funciona. Agora, o fato que temos já os contas a pagar é porque faz-se baixar. É bom de tê-lo lá, não importa que por enquanto não está funcionando, mas se a gente monta os pedaços e vai linkando essa construção que vamos chegar lá. Se pretendemos fazer de maneira linear Ah, primeiro faço isso, depois faço isso, depois faço isso, depois faço isso. Vamos demorar 2 anos.

**[45:32] Vinicius Bortolin:** Não, entendi.

**[45:33] Filippo Giorgi:** A ideia é montamos, vamos criar links até chegar, porque essa coisa já adiantada de quando depois fizermos a última operação de link já está tudo funcionando. Então a lógica é se preencher os vazios que conseguimos e ir linkando e preenchendo processos até, ah, chegamos até aqui. Está faltando isso agora. Vamos trabalhar nisso. Então, mas aí essa questão, você concorda com essa visão?

**[46:06] Kimberly Prestes:** Se for só para visualizar, Felipe, já tem aqui todas as planilhas, tudo que o Sérgio tá gerando. A questão é, e aí eu concordo com os dois, tá? A questão é, dentro de planilhas a receber e apagar, é a mesma estrutura, só que aqui não puxa por nome de projetos, tá? Aqui é o nome da pessoa, aqui na planilha pura.

**[46:33] Filippo Giorgi:** Tô na planilha que tá, que o suporte já, isso deve ser mudado, deve ter dado, ser dado o ID do cliente.

**[46:42] Kimberly Prestes:** É isso aí, depende do Sérgio, e o Sérgio que tá barrando algumas coisas. Ok. Aqui tem o nome de pessoa.

**[46:51] Vinicius Bortolin:** Isso nunca foi pedido, tá?

**[46:53] Filippo Giorgi:** Não, mas isso aqui ele não vai poder fazer.

**[46:56] Vinicius Bortolin:** Não, isso nunca foi pedido. Até porque aqui tem que sair o nome da pessoa mesmo, porque é o nome que sai a nota fiscal, é o nome do cliente.

**[47:06] Filippo Giorgi:** Está dentro do nosso super bem. Se a gente que tem que fazer isso agora, agora temos que estudar. Então, perfeito, você vê o problema de que tem que resolver aqui. Disso que vamos baixar, porque um dia vamos baixar ele definitivamente pela última vez, porque já estará funcionando perfeitamente tudo. O que que tem que funcionar? Tem que essa planilha, uma primeira coisa que vejo, tem que ter o ID do cliente. Temos que acrescentar o ID, temos que fazer de uma forma, pegar a planilha, trabalhar fora do Super Base, conseguindo com uma IA de repente dar os IDs que tem em função do nome, de novo, do número de projeto.

**[47:47] Vinicius Bortolin:** Não sei se tem, porque assim, ó, aqui, Filipe, ó, porque tem o nome do cliente e tem o nome fantasia que a gente usa. Então, por exemplo, vai ter lá Filipe Jorge, vai estar no nome do cliente, que é o nome que tem que sair os dados fiscais. No nome fantasia, as meninas colocam projeto 25.460 Casa MS, por exemplo, tá no nome fantasia. Se o nome fantasia não tá aparecendo nessa planilha que o Sérgio gera, aí eu posso pedir, aí a gente pede para ele, Sérgio, naquela planilha do financeiro que você tá gerando, preciso que saia também o nome fantasia. Aí é uma coisa que talvez facilite para poder fazer esse link, entendeu?

**[48:32] Filippo Giorgi:** Só que sai numa linha só, vai sair Desculpa, vamos pegar a informação mais inequívoca. O nome fantasia, eu já imagino que é uma vez, sei lá, que nem sempre é tão correto. É o nome, desculpa, não tem um nome de faturamento aqui?

**[48:52] Vinicius Bortolin:** É o nome do cliente. Esse nome de faturamento com certeza deve estar no cadastro cliente, é o mesmo do sistema.

**[49:01] Filippo Giorgi:** É equivocado, com certeza. Um nome, faturamento tal corresponde a tal ID, então tenha esse nome fantasia, né? Então a gente acrescentamos, mas o importante é isso, é achar nessa planilha qual é a informação que conseguimos achar também, cadastro cliente, para poder amarrar as duas coisas.

**[49:23] Kimberly Prestes:** Tá, Vini, então uma Uma planilha que resolveria tudo é de contas a pagar e receber, ok? Pode ser na mesma e ele só colocar o tipo, não precisa ser duas, só que ter o código da pessoa, o nome da pessoa, daí o nome fantasia, porque às vezes, né, os advogados se baseiam pelo nome do projeto, fantasia mesmo, é, e o código do projeto. Porque aí eu consigo puxar com esses códigos aqui, daí é com projetos fechados e projeto e organização de projetos, que daí tem esses códigos. Então se vier junto dessa planilha do financeiro o código do projeto, código da pessoa, projeto, tá fácil.

**[50:17] Vinicius Bortolin:** É, deixa eu mostrar para vocês porque uma coisa, posso compartilhar aqui rápido? Rapidamente.

**[50:22] Kimberly Prestes:** Pode.

**[50:38] Vinicius Bortolin:** Aqui é o sistema. Então, por exemplo, esse aqui é o cadastro do cliente em si. O que que acontece? Que que ele, que que tem aqui, ó? Tem o nome fantasia, por exemplo, é onde vai o código do projeto, que é o do organização lá. Só que não tem um campo código, tá? Ele vai ser, deixa eu pegar um cliente aqui. O cliente é Fabiano Teixeira Rodrigues da Cunha e no nome fantasia tem 18207 e Paulo e Leonardo, que é o nome do projeto que as meninas tratam. No financeiro ele tá vindo só assim, certo? Que é a razão social no caso e o código ali na frente. E esse código aqui, né, esse aqui é esse código, é o código que o sistema gera automaticamente quando cadastra um cliente. Tá, aí eu posso pedir então para que seja gerado isso daqui. Se a gente tirar um relatório de cadastro de cliente, eu acredito que venha já esses 3 campos, esse, esse e esse. No contas a receber, por exemplo, eu acredito que não venha o nome fantasia, venha só a razão social, né? E aí a gente pode pedir para incluir.

**[52:08] LAGHI Live:** Deixa eu confirmar aqui. Contas.

**[52:10] Vinicius Bortolin:** E o código do projeto, é isso que eu tô falando, código do projeto tá junto com o nome fantasia, não tem um campo código do projeto, entendeu? Ah, então, mas aí é no cadastro do cliente quando as meninas fazem. Não é todos que vem com código, tá vendo aqui, ó, um pouco mais de 1000 que vem É, mas eu não tenho muitos mais sem o código não, tá? Tô dando uma passada de olho aqui.

**[52:45] Kimberly Prestes:** O que você pode ver ali dentro do Supabase, que tem umas tabelas que começa com VW, aquelas tabelas são view, então elas são como se fosse consultas mais rápidas do banco de dados. Ele consegue puxar numa mesma planilha ou código da pessoa, nome da pessoa, nome fantasia, o código do projeto, porque aí ele tá puxando de várias áreas. E daí isso a gente já conseguiria fazer um SQL para linkar tudo, entendeu? Do, da aba de projetos, do, de contas a pagar e receber.

**[53:23] Vinicius Bortolin:** É porque não é um campo específico. É nome fantasia, nome fantasia no sistema, na Connect é assim, dessa forma. Não tem porque assim, ó, esse Esse é o cadastro de um cliente interno.

**[54:01] Filippo Giorgi:** Esse aqui gera automático.

**[54:05] Vinicius Bortolin:** Isso, não tem campo código de projeto, não existe. E aí teria que ter dois códigos, entendeu? Ele é colocado, é isso que eu tava falando, ele é colocado aqui, ó, na mesma linha do nome fantasia. Mesma linha.

**[54:23] Filippo Giorgi:** Eu acho que a gente pode fazer você uma operação, se você quiser, uma transformação linear. Divide a coluna, coloca numa coluna o número e na outra coluna o texto.

**[54:35] Vinicius Bortolin:** Acho que tem como separar, né?

**[54:37] Filippo Giorgi:** Isso aqui deve ser fácil de fazer.

**[54:41] Kimberly Prestes:** É o que tá na planilha atualmente, né?

**[54:44] Vinicius Bortolin:** Não entendi, quem?

**[54:45] Kimberly Prestes:** Aqui, planilha atualmente, ó. A planilha mesmo de projetos fechados está código cliente, projetista, o valor fechado, pagamento.

**[55:00] Vinicius Bortolin:** Então, Helena, aqui é o código de projetos fechados, certo? Ele não consegue ler?

**[55:07] Kimberly Prestes:** Consegue. Essa parte é o que tá já no Supabase, entendeu? A questão é de projetos fechados Aí outro ponto que também precisa de código para a gente fazer essa relação, e depois a gente trata os clientes, é os contatos, que é— cadê, cadê, cadê— arquiteto responsável, organização de projetos, não tem o código do arquiteto.

**[55:35] Vinicius Bortolin:** Tá, se eu tirar no relatório de arquiteto vai ter o código interno do cadastro do sistema. Mas não tem lá o arquiteto relacionado, vinculado a um projeto específico, porque ele vai, faz parte de vários projetos.

**[55:52] Kimberly Prestes:** Sim, mas é um código só. E aí quando o Sérgio vai tirar, como é um código interno do sistema, ele consegue tirar com o código ali.

**[56:04] Vinicius Bortolin:** É, vai sair no outro campo.

**[56:06] LAGHI Live:** Provavelmente todos que tem mais de uma nomenclatura vai ter mais de um registro. De arquiteto.

**[56:15] Kimberly Prestes:** O Vinícius normaliza isso, entendeu?

**[56:18] LAGHI Live:** O Pedro, o André Calil, por exemplo, onde o André Calil tem André Calil com acento no André, tem André Calil de Sales, tem André Calil de Sales com acento. Então tem diversas, diversos André. Nesse caso ele vai vir diversos códigos.

**[56:41] Vinicius Bortolin:** Não, mas aonde vocês estão vendo isso?

**[56:44] LAGHI Live:** Isso dentro da planilha.

**[56:47] Vinicius Bortolin:** Mas qual planilha? Porque, ó, deixa eu mostrar uma coisa para vocês, espera aí, vou compartilhar de novo.

**[56:59] Kimberly Prestes:** Cadê?

**[57:01] LAGHI Live:** Filtra só por André, que aí provavelmente vai aparecer.

**[57:05] Vinicius Bortolin:** Deixa eu retomar aqui rapidinho, quem Se eu vier aqui, ó, vamos usar o André de exemplo, né? Cadastro de pessoas funcionária e terceiro. O terceiro no caso é o André Arquiteto, tá? Se eu pesquiso ele, só tem um, só existe um, só tem um com código 501. Não existe outro André Calil. Vou pesquisar ele como cliente porque ele também às vezes compra. Então aqui é cadastro de cliente. Vamos ver se tem outros. Só existe um também.

**[57:44] LAGHI Live:** E por que que na planilha exportada pelo, pelo Sérgio aparece mais de um nome de André Calil?

**[57:50] Vinicius Bortolin:** Qual planilha?

**[57:53] LAGHI Live:** É na planilha de projetos.

**[57:57] Vinicius Bortolin:** O Sérgio não exporta planilha de projetos.

**[58:01] LAGHI Live:** Projetos não tá dentro do sistema, planilha de projetos é a que tá no SharePoint.

**[58:06] Vinicius Bortolin:** Ah, então aí é que as meninas preenchem manualmente. Aqui no sistema só existe um, ele nem deixa. Sim, é porque o sistema ele nem vai dar alguma coisa. Por exemplo, que pode acontecer, que eu vi no Super Base aí, tá? Pegar um caso específico aqui de cliente só para vocês entenderem e tomar cuidado com essa unificação também. Pegar outro, eu acho. Pera aí, como chama aquele cara da Virazão, Filipe? E o outro, tem outro?

**[58:58] Filippo Giorgi:** Rogério.

**[59:10] Vinicius Bortolin:** Peraí que eu tô achando um exemplo aqui. Ó, esse aqui, ó, André Fiorotto, por exemplo, ó, tá vendo que tem aqui, ó, como na razão social ele tá duplicado? Só que são projetos diferentes, tipo, ele fez duas casas. E aí eu não sei como vai ser tratada essa questão da unificação, entendeu?

**[59:48] Filippo Giorgi:** Também.

**[59:49] Kimberly Prestes:** Mas isso é um campo de cliente, né? Teoricamente é a mesma pessoa, então tem que ser o mesmo código dentro do Superbase, o mesmo código linkado em dois projetos, entendeu?

**[59:57] Vinicius Bortolin:** É, só que aqui para efeito de sistema, por exemplo, tem dois cadastros, entendeu? Porque senão a gente não conseguiria diferenciar, por exemplo, aqui numa— é, caramba, até porque um os dados fiscais em um endereço e a outra obra, dados fiscais em outro endereço. Então teria que ter, teve que ter dois cadastros.

**[01:00:22] Kimberly Prestes:** Sim, que no caso nesse Superbase, da forma que tá estruturado, então ali você conseguiria fazer essa diferenciação, entendeu?

**[01:00:30] Vinicius Bortolin:** Isso é importante fazer essa diferenciação, mas aí de repente pelo número do projeto, né? Só que é isso, o número do projeto Desculpa, o número do projeto no sistema ele não tem um campo, é isso que a gente tá falando, ele é aqui, né? E aí aquela questão que vocês falaram do André, que tem André com acento, sem acento, com espaço, sem espaço, aí é o preenchimento manual, né, lá no projeto, por isso que acontece.

**[01:00:56] LAGHI Live:** Então o certo vai ser realmente pegar, ver todos que estão com nome e fazer aquela, daquela forma que você falou, Kim. A mão mesmo.

**[01:01:07] Kimberly Prestes:** Sim, vamos. O Sérgio demora quanto tempo depois de pedir uma planilha?

**[01:01:15] Vinicius Bortolin:** Depende, se for uma planilha pronta, por exemplo, extraída os dados de arquiteto, de cliente e tal, se eu pedir hoje, talvez até no final do dia, no máximo amanhã. Agora, se precisar elaborar, por exemplo, a gente tá desenvolvendo, eu e o Pedro tá desenvolvendo um software e tal. Que dia que eu pedi, Pedro? Segunda, né? Foi, não foi ontem?

**[01:01:37] LAGHI Live:** Se eu não me engano, ontem, ontem, não foi ontem. Parou, você mutou, Vinícius, não tá dando para te ouvir.

**[01:01:51] Vinicius Bortolin:** Ah, desculpa, mudei sem querer. Por exemplo, um relatório que ele precisou elaborar, que a gente pediu específico para criar um software, um aplicativo, eu pedi na segunda, ele me entregou ontem à noite. Tá, tudo vai depender da complexidade, mas essas coisas são prontas. Por exemplo, se eu pedir para extrair o cadastro de cliente, cadastro de arquiteto, fornecedor, tudo isso teoricamente é bate-pronto. É, na verdade até tem, né, dá para tirar também. Sim, porque eu acho que, acho que é importante tirar de novo esses relatório de cadastro?

**[01:02:34] Kimberly Prestes:** O de clientes tem, né?

**[01:02:36] Vinicius Bortolin:** Porque ele vai se atualizando, né?

**[01:02:40] Kimberly Prestes:** O de arquitetos não.

**[01:02:42] Vinicius Bortolin:** Ah, vocês têm ou não têm?

**[01:02:44] Kimberly Prestes:** Tem, tem.

**[01:02:46] Vinicius Bortolin:** Mas posso pedir de novo.

**[01:02:48] Kimberly Prestes:** Mas o interessante é que nessa planilha de contas a pagar e contas a receber tenha os campos, ó, Porque ela, todo código que fica aqui são, né, na estruturação dentro do banco de dados deles são tabelas diferentes. Então, por exemplo, aqui, né, como ele tá montando uma planilha, isso daqui é, ó, por exemplo, nome da empresa, descrição, isso daqui e o código, esses três é uma tabela ali que foi exatamente o que eu recriei dentro do Supabase aqui, certo, de empresas. Aí eu peguei e coloquei aqui exatamente da forma que tava ali. Quando é código duplicata e todos esses pontos, perfeito, mesma coisa, ele vai puxando. Aí quando a gente fala de quem está, quem está pagando, ele só coloca o nome da pessoa e o código da pessoa, né?

**[01:03:53] Vinicius Bortolin:** É o nome fiscal, digamos assim.

**[01:03:56] Kimberly Prestes:** Exatamente. Então vai ter que ter o nome fantasia para a gente poder linkar com o código do projeto.

**[01:04:05] Vinicius Bortolin:** Acho que isso é tranquilo.

**[01:04:11] LAGHI Live:** Tá sendo difícil para ouvir o Felipe.

**[01:04:17] Kimberly Prestes:** É, não, na verdade não dá para ouvir, né?

**[01:04:19] Filippo Giorgi:** Não estamos utilizando atualmente contas a receber e a pagar, estamos usando transações aqui no Superbase. Estão todas as receber e apagar, até que acho que na verdade contas a receber e apagar talvez precisem ser umas visualizações dentro do Superbase, porque as transações estão dentro de transações. Então não precisamos replicar isso. Pode ser uma visualização que eu preciso de ver todas as contas a receber, todas as contas a pagar.

**[01:04:48] Kimberly Prestes:** Então está, só falta, elas estão criadas, mas falta em aberto.

**[01:04:57] Filippo Giorgi:** Mas aquele lá para cima, não vamos lá então. Contas a pagar, contas a receber, né? Não, a gente vai pagar. Até cancelado.

**[01:05:09] Kimberly Prestes:** Sim, é que foi da agora, da última que a gente subiu esses dados, que daí a gente deixou de utilizar.

**[01:05:23] Filippo Giorgi:** Então vamos analisar ela para entender se está com as coisas certas ou precisamos recriá-la.

**[01:05:30] Vinicius Bortolin:** Olha aqui, e outra coisa que eu ia perguntar, ele colocou para chegar junto.

**[01:05:36] Kimberly Prestes:** Sim, ele separa.

**[01:05:38] Vinicius Bortolin:** Quer que separa? Fazer duas?

**[01:05:44] Kimberly Prestes:** Não, tanto faz, é o mesmo trabalho. Subir uma ou duas é o mesmo trabalho, só que no Superbase elas estão unificadas ali porque é exatamente as mesmas colunas, né?

**[01:05:57] Filippo Giorgi:** Então eu preciso entender uma coisa aqui. Nas contas, nas transações, falta muita informação que nós temos lá na planilha, contas receber, pagar, etc. O que acontece, tenho, se você puder abrir a planilha transações, eu tenho um ID, imagino é o ID da transação mesmo, né? A conta ID. Um ID que é amarrado à conta em cadastro, talvez.

**[01:06:38] Vinicius Bortolin:** Você quer compartilhar sua tela? Eu não tenho acesso nesse pavio.

**[01:06:42] Filippo Giorgi:** Aí você tem que começar a ter acesso, menino, porque isso é uma tela que eu te mandei. Aonde, Pedro?

**[01:06:49] LAGHI Live:** Vai no seu e-mail. Está falando em contas a receber, Felipe?

**[01:06:59] Filippo Giorgi:** Não, tô falando de transações, tá?

**[01:07:03] Kimberly Prestes:** Que é os dois juntos. E qual que é o acesso?

**[01:07:18] Filippo Giorgi:** É o meu mesmo? É o seu e-mail, o acesso que você não tem no Skip, não tem acesso, né? Mas é o mesmo do Skip porque automaticamente foi gerado, acho, né?

**[01:07:36] LAGHI Live:** Não, são coisas disso, é o que foi gerado do Skip para cá, é a categoria São as coisas do RH e as partes das planilhas de entrega, que são cópias do que foi criado pelo escritório.

**[01:08:08] Filippo Giorgi:** Bom, mas enquanto isso enquanto ele acessa, já vamos entender um momentinho. Essa conta ID, sabemos onde vai, onde a puxa, por onde a gente vê como é conectada alguma coisa, onde tá esse elo, esse elinho, né?

**[01:08:33] Kimberly Prestes:** Oh, calma aí.

**[01:08:36] LAGHI Live:** Em database, não é?

**[01:08:38] Kimberly Prestes:** Sim, o InDatabase você consegue ver. Eu tava compartilhando minha tela. InDatabase você consegue ver todos os elos que tem de tudo. Então, ó, você consegue ver o esquema ali da visualização dele, você consegue ver da onde tá saindo cada coisa. Então, ó, transações aqui, transações, o ID Ele vem para, e daí você vai seguindo os caminhos. Então você consegue ver ali bem visual essa questão. Você consegue ver também as relações que tem atualmente, transações. As transações a gente consegue ver pelo ID, que é o ID ali da ação que aconteceu, o ID da conta Que lembra que eu falei, ah, é aqui, deixa eu subir, só um momento. Na planilha original, na planilha original, tá, tem o código da empresa, nome da empresa e descrição do perfil da empresa. Aqui a gente também tem a tabela de empresas com o código, nome E essa é a razão social. E qual é as contas bancárias? Aqui ele já puxa conta da empresa, porque aí ele já conectou ali qual é a conta, qual é a empresa que tá pagando. Projeto ID é o que a gente ainda não puxou.

**[01:10:16] Filippo Giorgi:** Mas espera, espera, conta da empresa, ou seja, se eu clico, por exemplo, em uma, em um ID Me vem primeiro, que me vem 4 ideias, não sei por quê.

**[01:10:30] Kimberly Prestes:** São de contas bancárias.

**[01:10:33] Filippo Giorgi:** Abriu a planilha que tem todos os códigos que vão nessa coluna, basicamente.

**[01:10:45] Kimberly Prestes:** Exatamente.

**[01:10:46] Filippo Giorgi:** A planilha aqui, no caso, esse é Bradesco, Lutineira. Entendi, ok. E daí, depois, projeto ID, porque não está amarrado o projeto, deveria.

**[01:10:59] Kimberly Prestes:** Como fazemos isso aí, o Felipe? Essa questão que por isso que ele fica com código e não com o nome explícito, porque aqui só tá a conta ID. Qual conta foi paga? Foi paga pelo Bradesco. Só que lá em contas bancárias O Bradesco tá dizendo que ele é da empresa Luthener. Então ele linka as empresas em si, né, porque tem ali do grupo. E isso tá acontecendo em todas, por isso que tem várias tabelas que a gente ainda não está utilizando, mas depois vai utilizar. Porque igual o Vini falou, ele tem isso em outros casos, né, ele tem 2 clientes registrados porque há 2 projetos e precisa de 2 de duas relações ali fiscais, né? O que, né, nessa estrutura do Supabase ele faz? Como uma coisa tá conectada com a outra, a conta ID tá puxando empresa, empresa puxa outra coisa, e aí ele já consegue fazer esse balanceamento dentro do Supabase, mesmo que a gente esteja vendo só os códigos aqui. Conseguiu entender? É meio que uma chave que desencadeia outras informações caso preciso, tá?

**[01:12:17] Filippo Giorgi:** Mas agora nós, como isso, de contas, as transações vão ser originadas, são originadas por vendas e pedidos, então tudo que é o processo de venda, então as informações de venda Código do projeto, nome do cliente, pelo menos, né? As parceiras vão vir no ato da venda e vão ser importantes. Informações que serão importadas nessa planilha transações devem estar contempladas logicamente por ID, não é? Que tem que reportar de novo a informação, mas tem que ser, se amarrada àquele ID.

**[01:13:05] Kimberly Prestes:** Já tá tudo certinho essas questões, lógica. O cliente aqui dá lógica, só que o projeto ID não está conectado aqui porque a gente vai pegar isso, projeto ID.

**[01:13:22] Filippo Giorgi:** Quando amarrarmos a projeto ID, nós conseguimos amarrar justamente também o nome do cliente e tudo.

**[01:13:29] Kimberly Prestes:** Exatamente, perfeito, porque daí ele já entende.

**[01:13:31] Filippo Giorgi:** Então temos que fazer isso.

**[01:13:32] Vinicius Bortolin:** Então O principal é pedir para colocar o nome fantasia lá naquela planilha para poder conseguir fazer essa amarração.

**[01:13:43] Kimberly Prestes:** Porque com o Projeto ID, o Projeto ID, quando coloca o nome fantasia, tem o código ali na frente. Aquele código é relacionado com esse código aqui, tá vendo? Com esse código aqui.

**[01:13:59] Filippo Giorgi:** O caminho que eu estou enxergando, lógico, mais fácil e manual. Manual entre aspas. Pega a planilha, mostra a planilha que vem do sistema, aquela que você ajudar. Foi a origem do carregamento.

**[01:14:17] Kimberly Prestes:** Essa aqui.

**[01:14:18] Filippo Giorgi:** Exato.

**[01:14:19] Kimberly Prestes:** Nós temos aqui— Só mostrar a minha compartilhamento de tela. Ah, ó, aqui o que vem de contas a pagar e contas a receber, ele vem o nome de pessoa atualmente. Se tiver o nome da fantasia, ele vai vir com o código, que o código é esse aqui, é esse daqui, porque ele tá separado no projeto, tá vendo? Quando puxa esse código, aí o que a gente vai fazer no Supabase é basicamente um PROC V ali, né, falando isso em termos de Excel, é um PROC V dizendo que esse código do projeto ID, ele é do nome fantasia das transações ali, o código tem que puxar de projetos. Perfeito, puxou de projetos. Qual é o projeto específico daquele pagamento?

**[01:15:24] Filippo Giorgi:** Ok.

**[01:15:24] Kimberly Prestes:** Quando ele puxa, ele vai puxar o cliente D, tá? Só que o cliente D não está sendo puxado porque o cliente D aí da questão do SharePoint, ele não está com esses dados certinho ali dos nomes, porque não tá normalizado lá. Aí a gente precisa normalizar essas questões que vem do SharePoint, que no caso é essa planilha aqui, porque aqui, por exemplo, quer ver, ó, cadê? Na verdade, ele nem tem o nome do cliente, ele tem o nome do projeto e o nome fantasia aí, teoricamente, entendeu? Exato. E daí, com aí a gente consegue conectar com a pessoa em específico, tá, com o cliente.

**[01:16:18] LAGHI Live:** Mas esse nome fantasia é o mesmo nome fantasia que tá lá no sistema?

**[01:16:26] Filippo Giorgi:** Por isso que uma vez que baixamos essa planilha do Sérgio, eu faria a divisão de uma coluna código, uma coluna nome fantasia. Porque código eu acho que é mais imitando o cabo.

**[01:16:39] Vinicius Bortolin:** Posso dizer que ele já consegue gerar assim.

**[01:16:43] Kimberly Prestes:** É, e qualquer coisa também é uma fórmula só.

**[01:16:46] Filippo Giorgi:** Porque para ele é uma complicação, você vai complicar demais, ele vai demorar demais. A gente com 10 minutos de ar faz isso.

**[01:16:54] Vinicius Bortolin:** O Júlio de repente faz.

**[01:16:56] Filippo Giorgi:** Qualquer uma faz, tirando.

**[01:16:59] Kimberly Prestes:** É uma fórmula só, gente, para poder fazer isso, é criar uma coluna e criar um negócio ali, depois a gente vai tirar o número.

**[01:17:05] Vinicius Bortolin:** Então assim, para a gente começar a fazer esse link é incluir o nome fantasia naquele relatório.

**[01:17:13] Kimberly Prestes:** Exatamente, que daí consegue fazer essa conexão, tá?

**[01:17:19] Filippo Giorgi:** Ok, então depois, tarefa minha com ajuda da Kim é ajustar essa planilha dentro do Super Base de uma forma que comece a ser conectada com todas as informações necessárias de projeto. É com o primeiro passo, é isso, conectar as duas. Depois é entender como nós temos que fazer o fechamento. Onde que fazemos o fechamento? Nós não esquece, nós estamos montando o sistema, então temos que fazer todas as operações que fazemos, visualizar. Então cadastrei, fechei, fechei. Como fecha? Coloca o valor, parcelas. Consequentemente isso se amarra a essas transações.

**[01:18:09] Kimberly Prestes:** Tá, outra coisa, Vini, o que que seria interessante é ter uma nova planilha de clientes, que porque aqui essa planilha de clientes tem o código de cliente e o nome do cliente, ter o nome Então é nome fantasia dentro da, da, o nome fantasia dentro de contas a pagar, contas a receber, e uma nova tabela, é uma nova, é um novo pedido de clientes com nome fantasia, tá?

**[01:18:45] Vinicius Bortolin:** O ideal é sempre aparecer o nome fantasia por conta do código de projeto para poder fazer as amarrações.

**[01:18:52] Kimberly Prestes:** Exatamente.

**[01:18:53] Filippo Giorgi:** Mas eu acho que a identificação Vai ser pelo código projeto que está dentro do nome fantasia, eu acho. Porque, repito, isso mesmo, tá?

**[01:19:07] Kimberly Prestes:** Só que a gente daí tá estruturando para que não tenha duplicatas. Então vai precisar do código de pessoa, vai precisar do código do nome fantasia, porque o código de pessoa consegue linkar com outras coisas e o código fantasia é só do projeto, esse código, entendeu?

**[01:19:27] Vinicius Bortolin:** É o único, né?

**[01:19:29] Kimberly Prestes:** Exatamente. Então é o código de projetos é o único, mas o de pessoas aí pode ser mais. Então daí a gente pode normalizar para que a gente cria, né, e depois analisando a planilha, para que a gente já arrume para nova versão, o que você está tendo de problema fora de você criar dois contatos para, né, criar dois contatos para que substituir aquelas questões de fiscal, né. Então tem dois arquitetos só por questões fiscais, só que não precisa, porque daí a gente fazendo essa relação você consegue entender qual é o projeto daquele mesmo arquiteto. Daí a gente deixa mais limpo o sistema e sem essas duplicatas que tá hoje em dia. Mas é o que precisa. Eu mando ali no grupo também. É dentro de contas a pagar, contas a receber, ter nome fantasias. O de clientes também ter nome fantasia. É, arquitetos também tem o nome, tem nome fantasia, não?

**[01:20:39] Filippo Giorgi:** Não, não, não, perfeito.

**[01:20:41] Kimberly Prestes:** E é isso basicamente que a gente consegue amarrar essas questões, fechado? Porque daí a gente consegue conectar ali, por exemplo, transações com esses dados. Transações a gente conecta com o projeto e deixa eu ver, a gente vai conseguir conectar com o projeto em específico. Categories. Deixa eu só ver como é que tá vindo a planilha. Um momento.

**[01:21:37] Filippo Giorgi:** Que código é esse? Será que é aquele código que a gente—

**[01:21:45] LAGHI Live:** deixa eu ver.

**[01:21:45] Vinicius Bortolin:** Aqui, vou pegar. José Carlos e Marina.

**[01:21:49] Filippo Giorgi:** Que senão temos já tudo. E, Kim, eu posso te perguntar uma coisa? Estou dando uma analisada aqui das pastas. Contatos origens.

**[01:22:06] Kimberly Prestes:** Isso, Ara, são o que é o esquema original mesmo que a gente vai utilizar. Ele tá dentro disso, a gente só tá colocando outras tabelas para poder servir de apoio para a gente fazer esse Proc V e depois apagar, tá bom?

**[01:22:25] Filippo Giorgi:** Não sei, tem que ficar aqui de qualquer forma agora.

**[01:22:29] Kimberly Prestes:** É contato origem, é da onde está vindo quando vocês fazem importações direto do sistema. Então, por exemplo, CRM cliente, da onde que tá vindo esse, essa origem desse contato, entendeu?

**[01:22:46] Vinicius Bortolin:** É aquele código, é o código de cadastro do cliente.

**[01:22:51] Filippo Giorgi:** Porque assim, para que serve essa planilha aqui? Contato origens.

**[01:22:58] Kimberly Prestes:** Esse contato origem, ele é, por exemplo, tem o Calil, ele é cliente e ele é arquiteto. Deveria ter um código só para o Calil e ele ser um cliente e um arquiteto, não dois códigos para o Calil de cliente e arquiteto. Aí esse contato origem ele vai servir como suporte para depois ele conseguir fazer essas duas relações, que a mesma coisa que o Vinícius falou sobre ter mais de uma, de um arquiteto, por exemplo. Só que aqui a gente tem mais de uma função dentro de uma mesma pessoa. Desse contato origem vai ser algo unificado que ele vai funcionar depois que tiver tudo certinho ali, tá?

**[01:23:45] Filippo Giorgi:** Então, junto com tudo bem, tudo bem.

**[01:23:50] Kimberly Prestes:** Contato tipo também mesmo, tipo alguma coisa do tipo, que sim, é só para puxar e fazer relação, tá?

**[01:23:57] Filippo Giorgi:** Isso aqui, é isso aqui, é, ou seja, isso aqui é o contato, é o nosso número de cliente que vem naquela planilha. Perfeito. Agora, se a gente vai em contatos Ou seja, aqui, porque talvez não precisa pedir muita coisa para tu. Como que foi isso aqui inserido? Porque ele na planilha então puxa as duas informações.

**[01:24:22] Vinicius Bortolin:** E aqui, Filipe, é o nome fantasia que tá aparecendo.

**[01:24:26] Filippo Giorgi:** Deixa eu mostrar uma coisa, Kima, aqui no sistema. Se você vai ver em contatos mesmo, tem a primeira coluna ID, depois tem código legado. Esse código legado. Eu não sei por onde entrou então, porque se a planilha não estava puxando, eu também não sei mais o que é. A planilha que nós usamos para criar esta planilha de contatos vem do sistema, é aquela lá. Ah não, aquela é da contas a pagar.

**[01:24:54] Kimberly Prestes:** Vem do SharePoint.

**[01:24:55] Filippo Giorgi:** Aquela das transações que estavam vendo. Então aqui temos já aqueles números. Então a gente já tem o código legado, poderíamos usar. O código, o código aqui, o código é que a questão é o código que vem na transação de contas a pagar e contas a receber.

**[01:25:26] Kimberly Prestes:** É que a questão é o, como que eu posso dizer, o ali ele tá puxando o projeto, porque não é a pessoa em específico. A gente precisa entender da onde tá saindo aquele valor do projeto.

**[01:25:44] Filippo Giorgi:** E aí, ali, projeto, oi, a transação envolve cliente, é ligada a projeto, porque uma pessoa pode ter mais de um projeto.

**[01:25:55] Kimberly Prestes:** Então não faz sentido a gente conectar pelo contato e sim pelo projeto. Por isso que a gente precisa do nome fantasia.

**[01:26:08] Vinicius Bortolin:** Sabe o que eu tô achando estranho? Que aqui nesse, onde o Filipe tá mostrando, contato, ele mostra Já entendi. O que que acontece? Isso daqui, a planilha de cadastro de cliente, tá vindo assim, ó, pelo que eu entendi, tá? A planilha de cadastro de cliente não vem o nome, a razão social, digamos assim, o nome fiscal da pessoa, vem o nome fantasia. É o que eu tô vendo aqui no na planilha de clientes, é o contatos dentro do Subabase.

**[01:26:54] Kimberly Prestes:** Aí ali vem exatamente assim, essa que foi de clientes.

**[01:27:05] Vinicius Bortolin:** Essa é o, então, mas aí aqui dentro, endereço, essa é a que o Sérgio fez. Dá dois cliques na coluna B aí, fazendo favor, para expandir ela.

**[01:27:16] Kimberly Prestes:** Eu só abri com o Tite, que só tá como visualização.

**[01:27:23] Vinicius Bortolin:** Porque ali dentro do Supabase, na contatos, tem o código interno do sistema e o nome fantasia. Aí tá vindo a razão social. No seu passeio tem o nome fantasia, tá vendo? Tá em nome, tá o nome fantasia, é, e não tá o nome, a razão social. Por exemplo, peguei aqui o, esse José aqui, ó, para aí, 1186. Procura aí o 1186, por exemplo. 86. Aqui nesse caso veio como nome fantasia na razão social. Vou até ver aqui no sistema. 1186.

**[01:28:30] LAGHI Live:** Então filtra pelo nome fantasia. Ordenando, porque aí os números vão ficar em cima.

**[01:28:46] Filippo Giorgi:** Posso?

**[01:28:49] LAGHI Live:** Eu acho que é isso aí, ó. É isso, é justamente isso. Basicamente isso.

**[01:29:06] Kimberly Prestes:** Tem 851 com o código, o nome fantasia, tá?

**[01:29:14] LAGHI Live:** Não é a razão social.

**[01:29:15] Vinicius Bortolin:** Deixa eu pegar um de exemplo só para ver se é o que eu tô pensando aqui. Pera aí, quem deixa eu pegar, mas aonde tem um nome fantasia? Deixa eu pegar esse aqui, ó, 2681.

**[01:29:31] Kimberly Prestes:** Veja um que não tenha, por exemplo, 2225.

**[01:29:34] Vinicius Bortolin:** É, por exemplo, esse 2681. Qual que é o problema? É um cadastro incompleto que provavelmente foi feito somente para fazer o orçamento. Não tem CPF, não tem nada. E no nome fantasia e na razão social Tá a mesma coisa, entendeu? Esse é um exemplo.

**[01:29:59] Kimberly Prestes:** Pegar outro, pega 2225.

**[01:30:05] Filippo Giorgi:** Isso poderia até acontecer, né? A gente tem que cadastrar o engenheiro da obra, mas ninguém responde, dá no dado, a gente põe de novo. Acontece, vai acontecer ainda, né?

**[01:30:20] Vinicius Bortolin:** 317 é cadastro antigo que não foi, que veio da CITELS, do outro sistema, né? E no nome fantasia e na nota fiscal é o mesmo nome.

**[01:30:32] Filippo Giorgi:** Da Marina, Marina mesmo?

**[01:30:34] Kimberly Prestes:** Ô Vini, pede com a razão, com os dois nomes, a gente consegue ver, daí a gente consegue conectar essas planilhas tudo certinho. É um contato, o Pontas Apagar, receber.

**[01:30:55] Vinicius Bortolin:** Ok, tá, vou pedir para o Sérgio terminando aqui, eu vou mandar uma mensagem para ele, tá?

**[01:31:06] Kimberly Prestes:** Planilhas que estão feitas, né? Só precisa conectar, só precisa gerar o script para poder incluir. É isso, basicamente. Com isso a gente vai ter vários processos conectando com todos os quartos. Inicialmente é isso que você precisa de mim? Exatamente, que é o que eu precisar de você que vai conectar todo mundo.

**[01:31:41] LAGHI Live:** Tá, então da minha parte também eu vou pegar e vou colocar, centralizar todos os arquitetos para não deixar duplicar. Vou passar um pente fino. Aí é só pegar o código de um deles e colocar, copiar e jogar para o projeto. É isso, né?

**[01:32:10] Kimberly Prestes:** Pedro, no Drive. E daí quando ele mandar, aí só me dá um ok, que daí eu vejo e já te mando ali essa relação.

**[01:32:19] LAGHI Live:** Eu não ouvi o começo.

**[01:32:21] Kimberly Prestes:** É, pega essas planilhas e coloca no nosso Drive lá, né? Me manda um zip no Drive com essas planilhas, que daí eu já Já vejo ali certinho para te mandar o que é para fazer, tá bom?

**[01:32:38] LAGHI Live:** Mas eu acho que já tá tudo lá, são inclusive são as planilhas que eu já te mandei, a que vai ter tá em projeto, tá? Dessas novas, a da planilha nova, das atualizadas. E depois só uma coisa, como que é para subir? A gente vai usar aquele, aquele script que você me mandou?

**[01:33:05] Kimberly Prestes:** Os scripts lá não tinha o nome de pessoas, tá? Essa questão dessa nova coluna. Então por isso que eu preciso ver para poder criar esses novos, ajustar ali os scripts, tá?

**[01:33:23] LAGHI Live:** O que que a gente adicionou mesmo, Vini?

**[01:33:26] Vinicius Bortolin:** Os nomes fantasias, né?

**[01:33:28] LAGHI Live:** Não, não, que a gente pediu para o Sérgio, que ele acabou de colocar. Ah, o valor de revenda da Albicor.

**[01:33:37] Vinicius Bortolin:** Ah, então, só que ele, eu não, igual eu falei, né, falei, vou ver com ele se consegue gerar no relatório, né, porque assim, que acontece, eu trago material da China, certo, aí eu tenho duas situações, ou eu vendo aqui para o consumidor final, ou eu tenho lojistas que a gente tá começando, representantes, que eu vendo para o lojista, para o lojista vender para o consumidor final, certo? Como importador, são dois preços. O que eu vendo aqui, por exemplo, eu vendo a mil, para o cara eu tenho que vender a 300, entendeu? Aí hoje no sistema eu tenho só uma tabela de preço, que é a do cliente final. Aí eu pedi para ele gerar uma posição, gerar, ver se dava para gerar essa questão da— mas rolou. Só que agora eu preciso fazer a minha parte, que é preencher, entendeu? Ele gerou, elaborou um relatório que aí vai vir só o Bico, viu, o Pedro, separado das outras marcas. E aí vai ter essa tabela 2, que é o preço de revenda, tabela.

**[01:34:46] LAGHI Live:** Isso.

**[01:34:47] Vinicius Bortolin:** E aí, só que eu tenho que fazer o trabalho agora, que é cadastrar o valor de revenda nos produtos. A partir do momento que eu cadastro, aí já vai puxar com esse valor de revenda, tá?

**[01:35:01] Kimberly Prestes:** Uma coisa que eu ia perguntar é, por exemplo, projetos fechados. Quando a pessoa fecha um projeto e compra ali, né, daí vai pagando para vocês, tem todos os itens que ela leva. Sim, existe aonde essa relação dos itens do projeto quando ela compra? Ou quando ela não comprou e para reservar, porque isso é um próximo passo depois de fazer isso. Mas a gente precisa pensar nisso, porque eu lembro que o Felipe queria que, por exemplo, fechou o contrato, já deixa sinalizado lá no, no, no, no, ai, aonde fica os produtos, no estoque, que tá meio que reservado, mesmo que demore tempo, mas que você tá, você vai ter que utilizar, tá? De uma previsão disso. Então a gente precisa saber, mas não é para agora, né, que agora o próximo passo é isso, mas é saber cada projeto fechado o que que é os itens, né, primariamente de pagamento, quais são os itens daquele projeto que foi o final, né?

**[01:36:13] Vinicius Bortolin:** O que eu posso fazer é te mostrar como funciona hoje no sistema. Como vai ser feito aí, não sei como vai ser estruturado isso, tá?

**[01:36:21] LAGHI Live:** E tem uma questão: o que é pedido no estoque não necessariamente é o pedido inteiro do cliente.

**[01:36:31] Kimberly Prestes:** Sim, e também quando o projeto fechado não necessariamente é o que vai sair depois, né?

**[01:36:37] Vinicius Bortolin:** Como Pedro, não entendi o que você falou.

**[01:36:38] LAGHI Live:** Vamos supor, quando tem fases da obra, né, às vezes é um pedido do cliente, vai ser separado em várias entregas, não é?

**[01:36:49] Vinicius Bortolin:** Ah, tá, em várias entregas, mas a venda é a mesma, é uma venda só.

**[01:36:53] LAGHI Live:** Não, sim.

**[01:36:54] Vinicius Bortolin:** Deixa eu mostrar para Kimberly como funciona o sistema. Tá visualizando?

**[01:37:08] Filippo Giorgi:** Beleza.

**[01:37:10] Vinicius Bortolin:** Então assim, aqui a pessoa vai fazer o orçamento, né? Acho que não sei se faz sentido ver isso, orçamento tal, vai preencher com todas as informações, todos os L. Beleza, fechou. Aqui mesmo tem a condição de pagamento, certo? Vai ser dinheiro, Pix, boleto. Quantidade de parcela, desconto. Beleza, agora essa é a parte básica, né? Agora a questão da venda, para você entender como fica. Vou te mostrar como funciona o estoque primeiro, só para você entender a lógica do negócio. Eu peguei um produto em específico, tá? Esse, isso é a mesma coisa para todos os produtos, tá? Eu tenho setores. Vamos lá, o que são os setores? Eu tenho aqui estoque geral. O estoque geral é tudo que eu tenho na empresa, seja vendido ou não. Material, certo? O que eu tenho aqui disponível aqui em cima é tudo que tá disponível para venda, tá no estoque, tá disponível. Se quiser levar o 124 hoje, pode levar, tá? Aí eu tenho aqui reserva. O que é o reserva? O reserva é todo material vendido de cliente, e aqui pode ser distribuído para N clientes. Então, por exemplo, se eu clico aqui, ó, reserva, Tá vendo? Aquela soma de 150 tá distribuído nessas vendas aqui. Então eu tenho 7 para o Éder Mialic, eu tenho 6 para Vânia, e muitos dos casos se repetem. Tipo, vai ter, por exemplo, pode ter 3 da Tatiane aqui, porque o sistema separa aqui por L. O L é a identificação nossa no orçamento correlacionado com o projeto. OK, vou pegar um item que tem entrega futura aqui, peraí. Só para você entender. Aqui já é outro acontecido, tá? Então, o que que é o estoque geral? É tudo que eu tenho no estoque. Então, eu tenho 13 no estoque, só que os 13 estão vendidos. Tá vendo que tá em reserva? Reservado para um cliente específico, reservado para o Henrique. Só que eu tô negativo 220, porque eu vendi 220 sem ter o material. Então ele cai aqui no setor entrega futura. E aí quando a gente clica aqui na entrega futura, ele me mostra a soma desses 220. Então eu tenho aqui, ó, por exemplo, tá vendo esse Nokia aqui, ó, ele se repete, tá vendo, ó? Todas essas linhas aqui é a mesma venda, só que os 70 é para um L, os 13 é para outro, e assim sucessivamente. Isso preciso visualizar, não tem como, tá? E aqui eu vou ter também o departamento de Aí, por exemplo, vamos supor, é complexo. Aqui eu tenho se já foi comprado. Então, por exemplo, tá 220 negativo, só que só tem 218 de compra. Então, tipo, ainda preciso comprar 2. Mas por que isso? Porque esses 2 saiu depois, ó, entendeu? Essa é a diferença. Como fica a venda, a visualização dessa venda? Então vem aqui, a gente chama de venda parcial. Quero pegar uma que de repente já tenha tido alguma entrega, alguma coisa assim. Aqui não vai ter entrega, mas beleza. Então aqui como funciona, quantidade vendida. Certo? A situação que está esses materiais, por exemplo, esse tá na entrega futura, é tudo material que eu preciso comprar. Posso comprar agora ou posso comprar mais para frente. Por exemplo, esse daqui, esse 13.532, é um material que eu não vou comprar agora, precisa de desenho, a obra precisa andar, enfim. Quando esse material chega e a gente vai fazer a entrada dele no sistema, No momento da entrada, a gente vai vincular essa entrada de 40, seja chegando 40 ou chegando mais, para esse cliente. No momento que vincula, esses 40 sai da entrega futura e cai aqui para o reserva.

**[01:42:11] Kimberly Prestes:** Perfeito.

**[01:42:12] Vinicius Bortolin:** Então fica 40 reservado para esse cliente, certo? Eventualmente tem alguma devolução de 10, por exemplo, vamos supor que chega Seja essa situação, vendeu 40, tem 40 reservado. No momento que esse material tá aqui no estoque, aqui na empresa, as meninas façam uma devolução de 10, por exemplo, porque mudou na obra. Esse reserva vai mudar para 30 e essa, e vai apresentar 10 devolvido aqui, certo? Para a gente poder visualizar que teve essa devolução. Transferido. O que que é esse transferido? Vamos supor que eu tenho 40 aqui, eu só tenho em reserva. Só pode ser transferido se tiver em reserva, senão não tem jeito, tá? E aí apareceu uma dor de barriga aqui, um cliente que precisa de 5 desse produto e eu não tenho naquela quantidade disponível, eu só tenho desse cliente. A gente pega emprestado. Então transfere 5 desse cliente para o outro cliente que precisa. Então aqui vai ficar transferido 5, ou seja, vai faltar atender 5 para esse cliente.

**[01:43:28] Kimberly Prestes:** Ok, é futuro, tá? Faz sentido.

**[01:43:30] Vinicius Bortolin:** Exato. A separar é quando as meninas fazem a lista de entrega. Então elas vão vir aqui, vai fazer uma separação, por exemplo, clica aqui, ó, um 3, certo? Por exemplo, e se elas salvarem isso daqui, vai gerar uma lista de separação que vai lá para o Mateus. Aí vai, elas vão salvar, no momento que salva isso daqui cai para o aguardando separar. Aí o Mateus, o pessoal do estoque vai lá, separa todo o material, tudo, e vai dar baixa nisso, ele vai pular para o separado. Que é para as meninas visualizarem a situação de como tá. A partir do momento que entrega, vai ser dado baixa na lista de entrega. Deu baixa na lista de entrega, vai cair aqui para o entregue. Aí deixa eu pegar um aqui que tenha, que tem alguma entrega. Eita, devolução cai tudo aqui, tá? Então, por exemplo, essa daqui é a lista de entrega. Se eu colocar para reimprimir aqui, por exemplo, essa aqui é a lista que gera de entrega. Quando ela chega, ela é baixada. Então, se a gente der dois cliques aqui, aqui aparece a data que foi data baixa, o quem gerou isso, quem fez a baixa e quem recebeu a mercadoria. Aparece aqui, tem que preencher no momento da baixa. Nesse caso aqui, ó, foi a própria Kátia, é funcionária antiga, que pegou o material para entregar para cliente. Então se ela pegou para entregar, ela ficou responsável, entendeu? Então é aqui que a gente visualiza a venda e a gente vai ter vendas gigantes.

**[01:45:31] Kimberly Prestes:** A venda, no caso, é o projeto, o valor do projeto total ali.

**[01:45:35] Vinicius Bortolin:** É, é, por exemplo, projetou, especificou as luminárias, fita, lâmpada, driver, tudo, mas a gente consegue o código.

**[01:45:49] Kimberly Prestes:** Esse código é da venda ali, ó.

**[01:45:52] Vinicius Bortolin:** Aqui é o código da venda. Que o sistema gera. E aqui o código de baixo, código referência, aqui é o código dos produtos, tá? Aqui é código de produto, é o código interno.

**[01:46:06] Kimberly Prestes:** Eu entendi, ele, ó, venda, e ali o projeto.

**[01:46:09] Vinicius Bortolin:** Isso, cliente aqui, ó, aparece como nome fantasia, que é o projeto.

**[01:46:14] Kimberly Prestes:** Ok, tá.

**[01:46:15] LAGHI Live:** Mas esse código da venda, esse é o código do projeto, 25019.

**[01:46:21] Vinicius Bortolin:** Isso, o código da venda é o sistema que gera automaticamente quando fecha a venda.

**[01:46:26] Kimberly Prestes:** Aí conecta tudo, fechado. Mas isso é uma planilha posteriormente.

**[01:46:31] Vinicius Bortolin:** Então é aqui, até anotei aqui que o Felipe falou, isso aqui não tem planilha, isso aqui é virtual, entendeu?

**[01:46:39] Kimberly Prestes:** Pro Sérgio, né, a relação disso.

**[01:46:42] LAGHI Live:** É, isso aqui não tem planilha, a gente também fez a parte, também a parte de entrega. Que é o sisteminha que a gente fez o clone no—

**[01:46:53] Kimberly Prestes:** Sim, lá no GitHub. Mas é, eu já tô com isso mapeado lá no GitHub lá que eu te mandei, tá, a relação de todos os sistemas que vocês já têm. Mas daí eu já penso nessa, nesse ponto. Então agora eu só preciso dessas planilhas com os nomes fantasias para que a gente faça essa relação, tá bom?

**[01:47:20] Vinicius Bortolin:** Ok, vou solicitar para o— terminando aqui, tem 5 pessoas aqui já atrás de mim.

**[01:47:25] Kimberly Prestes:** Então, gente, tem outra reunião já, tudo bem atrasada. Tchau, tchau para vocês! Confirma ali no grupo e daí a gente vai conversando, tá bom?

**[01:47:36] Vinicius Bortolin:** Fechou, tá bom.

**[01:47:38] Kimberly Prestes:** E daí essa parte do estoque já tá meio que mapeado, né, de vendas e itens. Fechado então, gente?

**[01:47:46] Vinicius Bortolin:** Ok, fechado. Obrigado.

