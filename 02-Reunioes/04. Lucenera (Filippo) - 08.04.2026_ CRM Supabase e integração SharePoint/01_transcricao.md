# Transcrição - 04. Lucenera (Filippo) - 08.04.2026: CRM Supabase e integração SharePoint

- Título tl;dv: Adapta Pass <> Filippo
- Assunto principal: CRM Supabase e integração SharePoint
- Data: 2026-04-08
- Horário: 11:30
- Link: https://tldv.io/app/meetings/69d66666a5e8fc0013fa5517
- ID tl;dv: 69d66666a5e8fc0013fa5517
- Duração aproximada: 01:09:25
- Participantes/e-mails capturados: kimberly@adapta.org; filippo@lucenera.com.br; pedro@lucenera.com.br

> Fonte: transcrição retornada pela API do tl;dv. Texto mantido com erros naturais de transcrição quando existentes.

## Transcrição

**[00:00] Kimberly Prestes:** do Skip Gold, você vai entrar nela, você vai vir aqui, ó, em gerenciar organização, e aí você vai colocar aqui, ó, convites. E daí todos os convites, aí você vai, vai convidar a tua conta Basic para cá. Porque aí, por exemplo, aqui, né, eu tenho a minha organização própria que eu gasto os meus créditos, mas por exemplo, se eu entro na organização desse Luiz eu vou gastar 2 créditos dele. E aí a mesma coisa que, o que você vai fazer, então é, você manda os convites para quem for, tiver acesso ao Skype, que eu acho que vai ser todo mundo, né, que o Felipe vai liberar, ou não sei, mas coloca o e-mail de todo mundo, eles vão receber, é, quais as funções. Você pode colocar você também como administrador, porque daí você pode adicionar outras pessoas para não ter que ficar entrando nessa conta principal. E aí, aí, eita, e você consegue ficar trocando aqui de, de organização, tá bom? Entre a tua privada e a da empresa.

**[01:10] LAGHI Live:** Tá perfeito. Então eu já vou pedir para o Vinícius fazer isso, que é ele que tá com a conta da Skip, tá? Mas ok. Para conseguir conectar a minha conta, é, porque eu ainda tô sem, tô usando a sua, enfim. E aí, Kimberly, tem uma, uma questão.

**[01:30] Kimberly Prestes:** Esse CRM do Felipe é para passar para conta— Oi, Felipe, tudo bem?

**[01:35] LAGHI Live:** Oi, tudo bom? Tudo certo por aí?

**[01:37] Kimberly Prestes:** Animado?

**[01:37] LAGHI Live:** Muito, muito, na verdade, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, já, tá trabalhando Já me falaram que você tá com sangue no olho, hein?

**[01:48] Kimberly Prestes:** Tem que ganhar essa competição, hein, Filipe?

**[01:51] LAGHI Live:** Olha, eu, eu tô esperançoso. Minha esperança aqui é criar um sistema tudo, tudo.

**[01:58] Kimberly Prestes:** Vamos fazer, eu tô, tô dando umas estudadas aqui, inclusive. Daí depois eu vou pedir algumas opiniões para vocês, mas vamos ganhar. Acho que é de todos os meus clientes, sendo bem sincera, que eu gosto muito de você, né? Mas é Eu acho que é o cliente que tem mais chances ali de ganhar, tá?

**[02:17] LAGHI Live:** Que bom, bom saber. E a gente vai fazer de tudo, mas não por nada, porque realmente estamos querendo—

**[02:26] Kimberly Prestes:** sim, realmente, nossa vida, tá?

**[02:32] LAGHI Live:** Vamos lá, uma, uma questão. Eu queria saber como que a gente faz para para sincronizar o SharePoint com workspace— com workspace não, com o script. Porque todas as tentativas, só, só para contextualizar, todas as tentativas que eu fiz deram errado. Ele, ele pede as informações, eu passo as informações, e no final das contas ele não puxa a pasta certa, enfim, o site em específico. Né?

**[03:06] Kimberly Prestes:** Uhum. Ou quais informações que tem dentro do SharePoint de vocês que vocês estão puxando?

**[03:12] LAGHI Live:** Nesse em específico que a gente quer são as informações de organização de projeto. Pode falar. Não, te explico uma coisa, nós agora estamos querendo centralizar tudo. Por exemplo, CML vai começar, uhum, ser um clone quase de uma, de outras as ferramentas que hoje temos. E entre elas existe essa planilha, por exemplo—

**[03:39] Kimberly Prestes:** Vocês podem compartilhar a tela comigo daí para—

**[03:44] LAGHI Live:** vamos compartilhar. E, tá, você Consegue ver?

**[04:01] Kimberly Prestes:** Aham, sim.

**[04:04] LAGHI Live:** Vê esse, este arquivo embaixo, essa planilha é uma planilha que já tem algum, umas automações que quando é registrado um projeto aqui ela gera a pasta, gera a, o, o projeto no Planner, tem umas, umas automações. Portanto, por enquanto, meu pensamento para ter os melhores benefícios, porque nós que poderíamos fazer, fazer todo esse trabalho e depois uma hora implementar, ou fazer todo esse trabalho e na medida que temos coisas já fazê-las conversar. Uhum. O futuro é que este, este, essa planilha não Talvez não vai ter mais, mas não sei, porque eu acho que por enquanto o pacote Microsoft, tudo que temos implantado lá, eu acho que por enquanto manteria, porque já existem automações, já existem— então daqui praticamente o que, que tem que fazer? O nosso, uma vez que é registrado lá, ele deveria registrar aqui para poder gerar as automações existentes.

**[05:20] Kimberly Prestes:** Tá, registrar lá no sistema do Skip, no caso.

**[05:23] LAGHI Live:** Então seria uma, uma, um link mútuo, tanto quem registra por aqui e quem registra por lá teria que ter essa, esse link. E aí aqui onde o Filipe falou que tem a, as tabelas, as coisas são criadas automaticamente, elas são criadas aqui. Não exatamente, na verdade, porque tem a criação de um planner, que é no outro aplicativo, tem a criação de— sim, das pastas que estão nas— nos vários projetos das pessoas. Então vamos— o primeiro poderia ser isso de ida, ou seja, eu mando elas registrar o projeto no CNR E essa registração de projeto me gera a registração de projeto aqui dentro do SharePoint. Isso seria o mais importante para começar a linkar uma coisa com, com a nossa utilidade.

**[06:24] Kimberly Prestes:** Exato. Por exemplo, é só pensando no fluxo, né, o CRM você faz ali a parte de vendas. Então quando cai ali, por exemplo, em negócio fechado Aí já é um projeto, aí já cai para outra pessoa aquelas informações ali que, ó, projeto novo. Aí ela só analisa ali todas aquelas informações, porque do CRM já vai vir várias questões. Então, por exemplo, ah, primeiro contato, isso a gente unindo todos os processos da empresa de vocês, vem lá do, do comercial, primeiro contato, daí já tem as primeiras informações. O histórico, os detalhes, e vai anexando documentos ali necessários. Deu um negócio fechado, aí já manda para o time que é responsável por, por esses projetos. E aí quando o time dá ok, aí já chama para, para esse sistema de vocês. Aí a gente tá tirando todos os gargalos de comunicações ali que precisa mandar para um cliente. Então Cada um vai ter na tua visão ali o, a tua etapa e cada sistema conectado ali com outra. É mais ou menos isso que vocês querem, né?

**[07:41] LAGHI Live:** Sim, de— saiba uma coisa, que aqui isso entra aqui e assim como é, deve ser cadastrado no nosso CMR no momento em que ele se apresenta aqui.

**[07:53] Kimberly Prestes:** Sim, sim.

**[07:54] LAGHI Live:** Não necessariamente ainda fechou nada. Mas ele começou— nós começamos a ter umas atividades para conquistá-lo. É justamente nesse status vai vir se ele chegou a fechar ou se ainda estamos só numa negociação inicial.

**[08:13] Kimberly Prestes:** Sim, tá, vamos lá. Pedro, me mostra o Super Base ali, ó, e a head functions desse, desse projeto específico.

**[08:24] LAGHI Live:** Aqui, sobe, existe, tem a organização projetos. Aqui tá, tá mesmo planilha tal, eu coloquei todas as informações, importei tudo, todas as informações. Inclusive tem mais algumas informações de valor de projeto fechado tal, isso a gente tá ajeitando porque ele vem de outra planilha que é a planilha de projetos fechados, que é alimentado pelas, pelas equipes. Tá, isso aqui pode estar— isso vai mudar muito. Eu, que estamos fazendo nesse momento, é por isso que tem essa planilha de projetos fechados que eu já falei, galera, isso para o Pedro, que na verdade ela vai ter que sair depois. Ela serve só para carregar no, na planilha principal de projetos a parte de valores, porque nós fazemos o quê? Naquele anterior, naquele, naquela planilha que nós temos já, não, não, tudo bem, mas não tem, naquela planilha do checkpoint nós não colocamos valor, sim, são outras informações, é um cadastro com essa coisa de status que dá um andamento, e depois temos esta outra planilha que eu peço para compilar quando— para preencher quando fecha o projeto. É uma perda de tempo ter que digitar de novo todas as informações do projeto. Seria só, sim, é um CMR, entrar para carregar fechamento, tipo registrar fechamento, e se entra aqui, se coloca o valor. Sim, sim, se juntamos as duas coisas e perdemos muito menos tempo. Aliás, tá até a geração desse valor lá dentro pode vir em automático depois de fechar o orçamento, né?

**[10:16] Kimberly Prestes:** Sim.

**[10:17] LAGHI Live:** Então, nessa ótica, então, voltando ao Super Base, nós temos hoje as duas planilhas, mas essa projetos fechados, uma vez que colocamos os valores já e na organização projetos, ela pode sumir daqui, não, não tem por que estar aqui, e pode sim, eu posso até pensar que ainda hoje com SharePoint, através do link com SharePoint, quando colocamos o fechado aqui vai carregar ali. Acho que podemos até pensar em continuar alimentando, mas eu acho que não vai precisar, porque pela verdade ela substitui— é uma— para mim é para visualizar melhor os fechamentos do mês, e que com sistema é complicado, Mas quando está tudo aqui, tá, tá tudo aqui, não tem problema.

**[11:08] Kimberly Prestes:** Dá para fazer, aí é estruturação. O Pedro, só para eu poder mostrar visualmente, coloca— abre lá o sidebar, manda o mouse todo, isso, database. Aqui vai mostrar tudo, a relação que tem entre as planilhas de vocês. Cês podem ver que não tem relação alguma, nenhum dado com o outro. Então, por exemplo, são só informações fixas. O que que isso em, em grande escala faz? Que vocês tenham muitos dados duplicados e que uma coisa não puxa a outra. Porque, por exemplo, se um cliente— esse cliente tem esse projeto, e aí esse cliente tem uma, uma outra função lá, ele— você vai ter que colocar o, é, todas as informações desse cliente novamente. Então não adianta a gente ter uma planilha de clientes sendo que na hora de criar a planilha de projetos eu tô colocando os dados dos clientes, porque aí ele não tá puxando as informações totais. A gente precisa conectar esses dados e fazer essas correlações entre eles. Então, por exemplo, a gente— o que eu imagino, né, na estruturação dos dados de vocês, e já puxando essa parte do financeiro, é ter a planilha dos clientes, e daí esse ID do cliente é o que puxa para o projeto. Então o ID Cliente X é o responsável, o, o dono desse projeto. Perfeito. Na parte do financeiro Aí o projeto também vai ter o ID. Na parte do financeiro vai ter uma outra planilha escrito ID do projeto, pode ter o ID do cliente também, e aí os valores do financeiro. Porque daí você consegue ter um— a gente pensando, né, em grande escala, todas as informações de vocês dentro do Supabase. O primeiro, vai ficar demorado porque a performance do sistema não vai ser tão boa. Segundo, vai ficar, é, demorado, pesado, muito grande, e essas, essas informações pode se perder, porque daí você vai ter que depender do código pro puro para ele entender essas planilhas. E aí o banco de dados funciona ou simplesmente para o teu, o teu banco de dados, ele fazer o tratamento de informações, é não colocar o— essas regras de negócio que a gente fala no teu código para ele entender o teu banco de dados. O teu próprio banco de dados precisa se entender. Só que aqui nesse caso ele não está basicamente se entendendo, entendeu? Quer ver? Vou mostrar um exemplo para vocês. De um sistema muito pequeno, mas—

**[14:13] LAGHI Live:** Deixa eu fazer uma pergunta enquanto isso. Eu fiquei com a sensação— Ah, vê, tem todas essas ligações, né? É porque eu tenho uma sensação: se a gente pretende de fazer tudo com script, quando sabemos que, por exemplo, eu não vou alterar uma planilha que está no Super Bens pelo script. Eu vou entrar na planilha no Super Bens e alterar. Eu acho que isso é melhor. Não alterar de acrescentar um, um cadastro, não. É óbvio que eu passo pelo aplicativo, mas a preparação do aplicativo imagino que tem que ser pensado justamente o Super Bens que funcione muito bem e de lá você vai dar um script, as indicações para puxar isso aqui. E às vezes estavam falando, ah, não, aqui na— não sei se teve algumas coisas de, ah, vai trabalhar muito do skip para o skip fazer isso no Super Base. Ajuda a gente a entender como temos que trabalhar, tá?

**[15:21] Kimberly Prestes:** Como que a gente— a estratégia e o porquê isso não é uma boa, um bom caminho, Felipe. Porque o Skip, quando ele vai criando código, se você abre ali o código de um sistema, vai aparecer todas as migrações que ele fez, todas as edge functions. E essas migrações, se você abre aí— o Pedro pode abrir aí para você— é, vai aparecer lá uma pastinha Supabase, e ali tem todas as migrações de todos os SQLs que ele criou lá dentro do Supabase. Então, com essas, esses documentos, ele sabe exatamente o que foi criado dentro do banco de dados e ele vai guardando no contexto. Porque às vezes você vai criar o teu banco de dados ou já tá criando o teu sistema, já tem o banco de dados, você vai lá e altera você mesmo o teu banco de dados, o script não tem esse contexto que você alterou. Porque ele tá vendo ali o código que tá dessa estrutura, e daí a nova estrutura ele não entendeu, ele que tem uma outra aba que é principal, e daí isso que vai acontecendo, os erros, tá?

**[16:37] LAGHI Live:** O qual— acrescentei uma aba, uma coluna com os valores, você agora tem que pegar esses valores e importar aqui.

**[16:48] Kimberly Prestes:** Isso não— o que eu recomendo de ser um—

**[16:51] LAGHI Live:** fala como tem que trabalhar.

**[16:53] Kimberly Prestes:** O que eu recomendo de ser uma boa prática: peguem um Word e vocês vão ter que estruturar exatamente todos os dados que vocês precisam para daí depois criar esses prompts de um sistema. E daí pode ser um sistema— eu quero só carcaça, mas mais focado na criação do banco de dados. E aí coisas pontuais, aí a gente altera lá dentro do banco de dados, mas a estrutura a gente deixa para o Skip, mas primeiro a gente precisa pensar na estrutura antes de ir para o Supabase, antes de ir para o próprio Skip. Então quais são os dados que a gente vai mapear? Eu quero, quero dados de clientes, quero o dado do CRM. Então o CRM, o que que eu preciso de informações? Ah, todo, todas essas informações aqui. Quando der OK no negócio fechado, ele já vai sair de CRM e vai pro— e vai passar essas informações lá para clientes. E aí você vai mapeando todos, todos, todos os dados que vocês têm. E aí depois você só vai pedir para ele criar só uma carcaça visual de tudo isso, só para você visualizar no Skip, mas o foco é criar o banco de dados, tá? Porque aí depois, com tudo isso mapeado, qualquer sistema que vocês forem fazer É, vocês entendem que o, a criação de sistemas é apenas manipulação de dados, né, criação e manipulação de dados. Vocês já vão ter os dados tudo criados, a estrutura toda criada, como funciona. Então vocês só vão criar sistemas que vão se alimentar desses dados e criar novos. E aí é muito mais fácil criar qualquer outro sistema depois que todos esses dados forem mapeados e estruturados.

**[18:42] LAGHI Live:** OK, só que Kimberly, eu acho que com o nosso seminário chegamos a um ponto muito bom.

**[18:47] Kimberly Prestes:** Sim, sim.

**[18:48] LAGHI Live:** Não recomeçarmos, é, então vamos analisar o que está, se dá para realmente continuar assim, o que, que precisamos fazer, porque estamos praticamente, chegamos quase ao fim do que a gente deve fazer, é, então gostaria depois atacar outras coisas, de repente, e continuar Ah, sim, é basicamente para te explicar aqui, as informações internas do CRM são— foram todas tiradas de dentro do, do Teams, do SharePoint. Então as informações de cliente, os arquitetos, isso são todos banco de dados que já tinham, que foi basicamente importar a planilha para dentro do Supabase. E agora, o que, o que a gente está tendo mais dificuldade aqui no geral é sincronizar a planilha de organização projetos, que no caso é essa aqui, com projetos finalizados. Eu até fiz aqui, eu acho que vocês entenderam que não puxa, porque não puxa. Projetos fechados aqui, essa projetos fechados, ó, com essa daqui, ó. Só que tá, um momentinho, deixa eu te fazer uma parêntese, porque agora estou vendo uma coisa, que esse projetos fechados, eu não sei porquê, vou ainda analisar ainda, mas não está reportando tudo. Eu já descobri, é, é a questão da data, como tem projeto que começa, começou em 2021 e foi pago só em 2024, entendeu? Eu— você entendeu? Entendi, entendi. Pronto, perfeito. Isso a gente já resolveu, resolvi antes da reunião. Beleza. Agora vamos lá, vamos lá, momentinho. Quero que a gente se dê uma— tem um dashboard que eu ainda vou mexer, mas beleza. Só que não pedi ainda o que eu quero que esteja, mas beleza. Projetos, tá, todos os projetos, estão os filtros funcionando, o responsável Marina, bom, e bota todos, é, tenho 3 visualizações, operacional e completa, aqui teoricamente me coloca a suma de todos os pagamentos, eu vou aqui, ele me mostra que teve um pagamento aqui, o pagamento aqui, então Tá bem funcional. Sim, sim. Posso cadastrar mais novo arquiteto, vou cadastrar, entendeu?

**[21:34] Kimberly Prestes:** Tá legal. Vamos, vamos— vocês têm uma tabela só dos próprios responsáveis ou não?

**[21:43] LAGHI Live:** Como assim? Desculpa, fechei. Como a tabela de todos os responsáveis? Sim.

**[21:49] Kimberly Prestes:** Dos responsáveis ali dentro do banco de dados?

**[21:53] LAGHI Live:** Não, não, porque são poucos responsáveis, para você entender, no caso.

**[22:01] Kimberly Prestes:** Mas é verdade que tem que ter, é, vai ter 30 mil, pensa no banco total, né, vai ter 30 mil Marina, 30 mil Thaís, e daí você tá repetindo o nome, isso tá gastando. Quando você clica no, é, muda ali no para outra página, ele demora para carregar. E isso vai demorar muito mais conforme vai crescendo os dados de vocês, entendeu? A gente vai fazendo esses dados relacionados, que daí a gente puxa o ID, entendeu? O que a gente fazer? Abre, abre ali a aba do, do dashboard, do prompt, desculpa, no skip. Isso. Aí você coloca: analise o banco de dados completo do Supermercado.

**[22:50] LAGHI Live:** Uma coisa, aquela planilha projetos fechados que não deve— que não faz— eu acho que realmente até para tudo que você tá falando é uma toda uma repetição, na verdade.

**[23:07] Kimberly Prestes:** Exato, você vai criando dados relacionados ali dentro.

**[23:14] LAGHI Live:** Tá pedindo isso de projetos fechados, que é aquela que, como eu te falei, a gente não reportou já os dados de lá. É, na realidade a gente vai ter que mexer nela ainda, mas deixa eu entender uma coisa. No suvabens, é, no script, você falou que tem que pegar o valor do projetos fechados e colocar na planilha para organização projetos, ou você já isso fez manualmente? Não, eu fiz um— aí eu fiz um, um sync history, que é esse, é, eu vim aqui em add function e criei um, essa sincronização com fechamento automático. Ah, então, então tá certo isso? Tá, tá certo sim, é porque Não, mas aí futuramente a gente vai pegar e vai apagar essa planilha porque ela já, ela já importou tudo para dentro. Tirar essa função, senão ela vai procurar e vai se perder, não é? Na realidade, essa função só é puxada quando, quando eu aperto para ser puxada, entendeu? Quando eu peço para ela, falo para ela, ela me avisa, entendeu?

**[24:35] Kimberly Prestes:** Pedro, mas o— os projetos fechados pode puxar por, é, os dados ali relacionados. E aí na tabela de projetos fechados só as outras informações que não tá da tabela de projetos gerais. E daí só criar uma coluna de projetos gerais com ele estando lá como fechado. E daí no fechado já cria um ID na— em projetos fechados. E aí as outras informações que são a mais do que não tava na planilha de projetos em gerais do CRM.

**[25:17] LAGHI Live:** Tá, é o que que eu tenho que perguntar aqui?

**[25:19] Kimberly Prestes:** Analise o banco de dados no próprio Supabase. E cria um plano de ação para o refatoramento do banco de dados, abordando criação de novas tabelas. Relações de novas, de novas tabelas necessárias, né? É criar relações visando a performance, relações de dados visando a performance. E otimização do banco. Aí pode enviar. Uma outra dica também para vocês é: vai lá no, no Supabase Copia lá, ó, copy as SQL no canto superior direito, canto superior direito lá do outro lado. Isso, agora entra no, no Adapter, no, no próprio Adapter, entra no chat.

**[27:08] LAGHI Live:** Aí, ó, já apareceu uma nova aba aqui, empresa. Eu acho que já entrou em vigor workspace.

**[27:17] Kimberly Prestes:** É, mas ainda não tá workspace aí, né, que eu ia pedir para você usar o Opus. Clica ali no—

**[27:23] LAGHI Live:** é, esse não é workspace, né?

**[27:30] Kimberly Prestes:** Ainda não. Coloca ali no cloud. Ah, passa o mouse ali no cloud. É, ainda não tá aparecendo. Me manda o enxema aqui para, para mim, que daí eu mostro o que que vocês vão fazer no workspace. Acho que vai ter que mandar no WhatsApp, porque senão aqui tem limite.

**[28:09] LAGHI Live:** [No speech]Mas de qualquer forma, é, o que que a gente teria que fazer?

**[28:23] Kimberly Prestes:** A gente vai pegar e vai pedir para o próprio Opus, que é o, a melhor IA para programação, para que ele analise o teu esquema e que ele cria um plano de ação de como estruturar melhor visando tudo isso. Então ele vai criar a nova estrutura do banco de dados considerando todos esses dados atuais. E aí você poderia também acrescentar ali— eu só quero mostrar ali o processo para vocês, mas aí vocês vão usar toda essa estrutura que, que ele vai criar, tanto se vocês quiserem jogar em prompt no skip ou ele vai mandar ali um SQL para você editar, e aí você já vai editar todo o teu banco de dados, e aí vocês conseguem arrumar todas essas funções. Deixa eu pegar aqui.

**[29:14] LAGHI Live:** Mas para mim, então, não tô entendendo nada. Não, mas isso aí é a parte mais— eu entendo do que eu preciso.

**[29:25] Kimberly Prestes:** Tem que ser bom, tem que ser bom em uma coisa só, né?

**[29:28] LAGHI Live:** Mas acho que é importante entender do que você precisa, né?

**[29:32] Kimberly Prestes:** Exato. Mas eu acho que tem que ter uma base só, não tantos detalhes, que daí isso o Pedro se vira, né, Felipe?

**[29:42] LAGHI Live:** É, deixa a bomba comigo, tá?

**[29:45] Kimberly Prestes:** Vamos lá, ó, essa é a visão do workspace só para vocês terem os gostinhos. Aqui tá todas as integrações necessárias que vocês poderiam ter. E aí é bem simples de conectar, então só é clicar aqui exatamente e conectar. Não tem nenhuma outra questão aqui dentro, tá? Aqui em cima então vocês conseguem também registrar. Então todo dia de manhã é analise os meus emails, é busque no— em tal local. E aí você vai criando todas essas automações aqui, né, como se fosse um Open Cloud. Não sei se vocês já ouviram falar, mas aí vocês conseguem criar vários plays para, para atividade de vocês. Mas vamos lá, o nosso foco aqui é outro. Vou vir aqui, vou escolher o Open Cloud, o Cloud 4.6 Ops. E vou falar, é, aja como um engenheiro de banco, adosso, e analise o meu tema do supa baby e crie um plano e crie uma estrutura nova, detalhada, com justificativa. E aí, Pedro, eu vou pedir para você usar com, por exemplo, com justificativa, é, explicando os conceitos, porque daí quando você for analisar Aí quando você vai lendo, você já vai entendendo ali para você replicar em outras, em outros, né, quando você for criando os bancos de dados. Porque aí você vai bater o olho, vai falar, opa, tem algo de errado. Então já vai estudando e, e aplicando aqui todas essas funções. Então, aja como engenheiro de banco de dados e analise meu esquema do outro país e crie uma estrutura nova detalhada com justificativa visando— uma maior performance— relacionamento de dados entre as— belas. É necessário criação de novas belas, pensando em uma escala de volume de dados e mais informações da empresa. E aí o que que eu vou fazer? Vou clicar aqui no melhorador de prompt para dar uma— nisso também. E aí que eu vou colocar— vou colocar mais uma regrinha aqui para que ele não gere, mas Non, ieri, un nuovo—

**[34:00] LAGHI Live:** sta scrivendo in italiano, schema—

**[34:06] Kimberly Prestes:** ehm, antes da mia validazione da nova estrutura do banco. E aí vou enviar. Que que vocês podem fazer? Ah, preciso conectar com mais dados, Kingo. Você pega o, o teu esquema atual e aí você vai falar, ó, eu tenho esses novos dados que eu preciso, analisa o a minha estrutura atual e me explique, né, e cria uma, uma estratégia de como eu posso criar essa nova tabela dentro desse banco de dados, com todas, pensando em performance e essas outros detalhes. E aí vocês conseguem estruturar usando a própria IA. Quando ela responder aqui eu mostro para vocês, mas aí vocês conseguem isso montando como se fosse um quebra-cabeça. E agora vocês têm um manual de instrução do quebra-cabeça, que agora jogaram um monte de peça de Lego na mesa de vocês, vocês estavam tentando conectar, né? Mas assim vai ficar tudo relacionado, o banco de dados de vocês vai ficar muito mais, é, com performance. Não, vocês daqui a pouco ia estar gigantesco banco de dados, e agora a gente vai enxutar ele Só para dados realmente necessários, porque o resto é tudo relação ali entre eles, que é isso que faz um sistema centralizado, né? Então dessa forma vocês vão ter um sistema muito bom, que daí depois o sistema do skip é só conectar e aí mostrar os próprios dados. Então, é, ou criar novos dados dentro da planilha, né? Mas Aí qualquer outro sistema é bem mais fácil de construir, tá?

**[36:05] LAGHI Live:** Então aí no final das contas, depois eu pego, pego as instruções que ele falou e faço a sincronização dentro do Supabase.

**[36:13] Kimberly Prestes:** Ele vai mandar um SQL editor e aí você pode mandar lá. Daí você manda para o script para ele poder analisar e criar um— o arquivo do Supabase ali com todas as funções. Vamos ver o que que o próprio script respondeu.

**[36:31] LAGHI Live:** No caso, seria só eu colocar aqui dentro, no SQL.

**[36:34] Kimberly Prestes:** Você pode fechar tudo isso, inclusive, que você abriu. É, não precisa deixar aberto ali porque é só para— você manda e roda ele, e aí ele já faz todas as alterações. Vamos ver o que que o script escreveu sobre o banco de dados.

**[36:54] LAGHI Live:** Cê— aquilo lá antes você perguntou uma coisa, mas— ah, uma coisa, eu também tenho um usuário, o meu, esse aqui. É, eu preciso saber, me ajude um pouquinho assim a racionalizar o mais correto lá. E eu posso usar no meu para dar, por exemplo, eu entro de noite, vejo isso, ah, cara, quero mais um filtro, né, quero mais um filtro. Isso aqui eu de repente vou já tentando fazer e normalmente me dá certo.

**[37:47] Kimberly Prestes:** Uhum.

**[37:48] LAGHI Live:** Ora, eu— é igual usar minha conta com uma conta da empresa?

**[37:54] Kimberly Prestes:** É, eu até mostrei aqui, eu vou compartilhar que você estava em ligação na hora. Como que vai funcionar? E daí, eu tinha até perguntado, daí a gente entrou no assunto ali e faltou a resposta. Esse CRM vocês querem que passe para organização da empresa E, ou pode deixar na do Filipe mesmo.

**[38:17] LAGHI Live:** Não, eu acho que como é um sistema mais robusto, vai ter—

**[38:23] Kimberly Prestes:** tá, vamos lá. A da empresa, vocês têm 4.000 créditos. Então vocês, tudo que tiver dentro da empresa tem 4.000 créditos. Dentro de cada um privado de vocês tem 800 créditos mensais, né? O que que eu recomendo? Os 800 créditos serem sistemas mais, é, os sistemas menores, sistemas mais pontuais. E aí vocês vão criando com esses 800 créditos sistemas mais robustos, como é o caso do CRM. Eu deixaria dentro da empresa porque em algum momento os créditos ali, como são 800 créditos, são menor, né? Não, você vai torrar os 800 créditos criando todo esse sistema. É, e aí você já tem 4.000 créditos dentro da empresa, então você poderia estar gastando esses 4.000 créditos para criar um sistema mais robusto. E aí, como que funciona isso? Daí tem que— vocês precisam entrar na, na organização da, do Adaptago, do Skip Gold. E aí você vem aqui em gerenciar organização e vai enviar os convites. Então você vai mandar os convites para todo mundo que vai poder ter o acesso à conta do, é, do Skip aqui, da, desses 4.000 créditos. Vamos colocar o, o e-mail que tá tua conta pessoal ali dos 800 créditos, é, Felipe, o do, o do Pedro também vai entrar aqui. E aí vocês vão enviando esses convites às outras pessoas também, vocês enviam aqui. É para poder entrar. E aí, como que vai funcionar? Por exemplo, eu estou aqui na minha organização. Se eu estiver na minha organização, aqui estão os meus próprios projetos pessoais e eu tenho os meus próprios créditos. Então, uma quantidade do que eu estou gastando aqui é dos meus créditos. Se eu troco aqui, por exemplo— inclusive, se vocês quiserem, pode me colocar na organização, que daí às vezes que vocês me pedem ajuda ali no WhatsApp, é só eu clicar no botão aqui e aí eu já tenho acesso a tudo que vocês estão construindo ali. E daí, e daí ali do banco de dados já ensino também como fazer isso no Superbase. Mas por exemplo, aí eu entrei na organização do Luiz. O do Luiz, digamos, é o, a organização geral de vocês. Da empresa. Aí vai ter todos os projetos aqui. E se eu, por exemplo, mandasse um prompt aqui, ou entrar em um projeto específico e mandar um prompt, eu tô gastando os créditos dele, não os meus ali. Então, quando vocês estiverem num sistema que tá na empresa, não no, no do Skip Gold, vai estar gastando os 4.000 créditos. E aí os 800 créditos fica para coisas mais pontuais ali Que daí, ou coisas que, por exemplo, o Felipe não quer, sistemas pessoais dele que ele não, não quer dividir para outras pessoas. Ou Pedro pode usar esses créditos também para criar outros tipos de sistemas para coisas bem pontuais ali, é como eu dei ideia ontem para o Pedro de criar um design, criar os prompts específicos para poder mapear também os processos que a gente vai criar tanto dentro do workspace tanto dentro do skip, para poder mapear tudo aquilo. Porque daí, por exemplo, ah, tal pessoa foi mandada embora, mas o que que ela fazia? Eu já saí de empresa que ninguém sabia fazer o que eu fazia e não tinha mapeado em nenhum lugar. Vocês mapearem exatamente o que a pessoa faz, qual é o sistema, como que ela utiliza, quais prompts ela usa, quais plays ela usa, aí faz com que o onboard do RH de vocês vai ser muito melhor. Porque daí a pessoa já sabe exatamente ali o passo a passo, é, se tiver mudança de cargo, então fica tudo mapeado, fica tudo certinho. Que aí, por exemplo, esse sistema poderia ser no próprio pessoal ali do Pedro, mas aí eu recomendo passar para o principal. Aí vocês me digam aí se querem—

**[42:41] LAGHI Live:** então vamos ver como vamos fazer isso agora. Importante é Vamos chamar o Vinícius nisso, porque o acesso central— o acesso tá na conta dele, né? Porque ele não vai conseguir trazer o PC para cá. Vamos lá em cima, vamos lá em cima para ver se ele tá ali já. Isso, e concordo plenamente. Entretanto, nós temos 5 contas teoricamente, mas é, estou vendo que mais uma É considerada mais como conta na organização com 4 mil créditos. Posso então eu passar para toda equipe, mesmo que seja 12, e— e provavelmente não é que— quem que vai trabalhar mais com isso é— somos nós. É o Pedro, um pouco o Vinícius, um pouco— e depois sim, tudo bem, tomando confiança, alguém começa a trabalhar. Mas como funciona essa questão? Eu posso colocar 12 pessoas na organização?

**[43:46] Kimberly Prestes:** 15? Ali agora eu não lembro qual que é o limite de, de pessoas ali, né? Ah, então é 5 pessoas. Mas o que você pode fazer, é como essas outras pessoas, elas não têm a conta privada delas que tá rodando crédito, Pode ser uma conta. Elas vão estar criando sistema tudo ao mesmo tempo, né? Pode ser uma conta para dividir com mais de uma pessoa, e aí eles vão criando ali, entendeu? Então vocês podem criar, por exemplo, o, uma conta ali que vai transferir entre todo mundo.

**[44:37] LAGHI Live:** Você— é, ok, login, ele entra e entra na, na organização, né?

**[44:45] Kimberly Prestes:** Sim, aí entra aqui, ó, aqui, organiza—

**[45:08] LAGHI Live:** Regenerando passo.

**[45:16] Kimberly Prestes:** Como é 5? Eu pensei que era ilimitado. Eu vou ver aqui com o Alain para que, é, ele altere, que a minha não conte como 5, e daí coloca 6 no caso para vocês, e daí para vocês colocarem o meu e-mail ali como Aí eu falo ali, daí eu dou ok para vocês, daí depois para colocar o meu e-mail.

**[45:41] LAGHI Live:** Uma iniciação, uma— eu não posso entrar, não dá, né, também não pude entrar. Eu te diria que o certo é deixar uma com a Mari, uma com o Vini. É, sim, a Mari gerencia o projeto. É, e aí a Mari, a Mari comanda a partir disso. Eu tô engajado com todo mundo, acho que é um pouquinho, né, devagarzinho se envolver.

**[46:11] Kimberly Prestes:** Sim, mas o, o Felipe, criar uns desafios aí com a galera, que eu acho que isso é o que a gente vai ter algumas novidades que a gente tá criando que, que já vai influenciar vocês a isso, que daí você vai ter o controle total do que cada funcionário tá fazendo, tá aplicando atividades, essas coisas, tá? Você também tem o panorama do que cada um tá fazendo, né? Tudo isso.

**[46:38] LAGHI Live:** Sim, eu preciso disso.

**[46:40] Kimberly Prestes:** Mas o que que você pode fazer, Felipe, desde já? Vocês têm as reuniões semanais de vocês, né? Agora, liberando o workspace, você já pega e, e vai Influenciando as pessoas, ó, vou criar um desafio aí, sei lá, dá um almoço em algum restaurante para quem desenvolver o melhor workflow, e daí todo mundo vai votar e vai criando esses desafios. A gente faz aqui na DAPTA muito isso, a galera que é bem competitiva também, né? E a gente cria desafios, é, por exemplo, no nosso time, no nosso próprio time, toda semana a gente precisa mostrar algo ou uma pessoa específica precisa apresentar o que que ela aplicou no negócio. Então você já cria um calendário, ó, em tal dia você vai ter 15 minutos para poder mostrar o que você tá aplicando, porque daí isso não é punitivo para galera, mas é meio que força a galera a aplicar em algum lugar, entendeu?

**[47:44] LAGHI Live:** A gente vai fazer isso, estamos querendo postar tudo, e tamo também com uma aplicaçãozinha que tamo fazendo para criação de fichas técnicas, e vai ajudar muito elas. Eu quero entrar um momentinho com nós mais preparados, com já vendo algum produto que fala, olha o benefício que estamos tendo com isso, com isso. Agora tá a vocês, agora, bom, desafio para todo mundo. Então vamos, vamos fazer isso sim. Agora estamos aqui nessa tela aqui, eu aliás, eu, a convite pendente, como eu respondo? Eu vou entrar no meu, no teu email.

**[48:18] Kimberly Prestes:** Você vai receber, não, não recebe tão na hora, tá, mas daqui a pouquinho vai chegar no e-mail de vocês. E daí é só aceitar e daí vai ter as organizações ali.

**[48:29] LAGHI Live:** Eu acho que não, né, só isso que tem que fazer na, na— aqui já chegou o convite, é só aceitar. E aí todos os meus projetos vão entrar pela rotineira.

**[48:46] Kimberly Prestes:** Não, você vai conseguir ver todos os projetos da, da luteineira, mas agora que já tá tudo conectado, aí eu só preciso fazer porque eles têm que fazer isso manualmente, porque não tem função ainda para isso. E daí o, o Alan que vai pegar todos os projetos, então é aqueles 3 que você me passou, e aí me manda certinho o do CRM do Felipe, e se tiver mais algum outro, eu já vou te mandar a nomenclatura inclusive agora de como ele tá, porque aí já fica para não esquecer. E daí eu já peço para—

**[49:22] LAGHI Live:** Oi, é só esse sistema, é o que a gente vai fazer de começo do, do Filipe, que é só esse sistema.

**[49:41] Kimberly Prestes:** Tá, deixa eu mostrar como faz isso agora no banco de dados para vocês.

**[49:46] LAGHI Live:** Da importação do CRM para dentro da coisa.

**[49:53] Kimberly Prestes:** Agora, dentro do banco de dados, o que que vocês vão fazer para poder— aí depois eu te dou ok lá, Pedro, quando for para, para adicionar novas para me adicionar na organização de vocês. É, o que que vai acontecer agora no Supabase? Você vai abrir na organização de vocês, ele vai ter todos os projetos. Aí, aqui, ó, Teams. E aí no, no Teams você vem aqui e você convida um usuário. Aí você coloca o meu e-mail lá, kimberly@adapta.org. E aí eu vou receber aqui, daí eu só aceito Participar da organização de vocês ali do, do Supabase, que daí eu já consigo, quando vocês pedirem algo, eu consigo ver ali o skip e o banco de dados ali.

**[50:41] LAGHI Live:** Mas a nossa conta não é paga da, do coisa, não sei se dá para colocar mais de uma.

**[50:48] Kimberly Prestes:** Pode, tem sim, ó, o tanto aqui, ou, ou essa daqui também não é paga. Perfeito. Vamos lá, só deixa eu te mostrar aqui o, a estratégia que ele gerou, só para poder—

**[51:06] LAGHI Live:** só que, ó, eu aqui tenho, ó, o que que ele fez?

**[51:09] Kimberly Prestes:** Análise completa. Então, problemas críticos sem chave primária: arquitetos, empresas, clientes, projetos associados, é praticamente todos os usuários. Então É, né, as chaves entre as tabelas, sem vínculo formal entre projetos e clientes e arquitetos, organização. Nada impede a inserção de um projeto referenciado, um cliente ou arquiteto inexistente. A integridade depende apenas— então, quando você anota, por exemplo, informações diferentes, ele pode aplicar e nem percebe.

**[51:47] LAGHI Live:** Minuto, só um probleminha aqui. Agora, olha, organização de Filipe, aqui tem membros Vinícius e convites. Quer, quer adicionar o Vinícius aí na organização de Filipe? No meu tem membros Manda o link para ele, pede para ele entrar. Eu não tenho convite, tá estranho. O meu— o seu Skype, como você enxerga? Como Skype, meu Skype tá como organização Filipe agora. Eu tenho duas organizações, ó. Eu não, eu tenho só organização índia. Que estranho, organização de Filipe. É a— não tenho mais a minha conta aqui. Posso ver o seu? Deixa eu ver uma coisa. Organização Filipe, que é outro e-mail, né, gente, que é o primeiro de todos. Tem o CRM, tem o app web e tal. E aí aqui tem os meus projetos. Aqui não tem. Parece que vocês entraram na minha conta, não na organização. Não, a gente entrou na, na conta geral, ó. Até aqui. Então eu preciso ter acesso à minha conta pessoal. Aqui, ó, o convite que eu mandei tá aqui, ó. Skip. Vamos aceitar. Deixa eu mandar para o, para o Vinícius, para ele te mostrar aqui. Não, eu consigo te mostrar.

**[53:29] Kimberly Prestes:** É, entra na conta do Felipe.

**[53:32] LAGHI Live:** Eu tô com todas as contas aqui centralizadas no meu computador. Ah, você já tá vendo já? Tá. Então aqui eu tô na minha. Como que não apareceu opção para trocar de conta? Aí eu tenho, eu tenho como entrar. Ele já sentou, né? Mas essa aqui estão as informações da minha. Não sei se juntou. Será que juntou?

**[54:07] Kimberly Prestes:** Atualiza para ver. Então, o que tá com, o que tá com o Adapta Gold é diferente o e-mail do que tá com o do Basic do Felipe, né? É diferente dos e-mails, né?

**[54:31] LAGHI Live:** O do Filipe tá aqui, ó. Aqui, ó, esse é o do Filipe. Ele precisa aceitar no e-mail, né?

**[54:48] Kimberly Prestes:** Veja ali, convites, que às vezes aparece aí convite.

**[54:56] LAGHI Live:** E aí, e depois de membro atingido, integrações, ele falou que não chegou no email dele. E no seu email não chegou, né, Filipe? Chegou agora, organização de Filipe, agora, agora tem a minha pessoal e a organização da Dá para trocar o nome de organização para— Dá para trocar? Não tem. Agora, não, mas isso, exatamente, nós temos agora que migrar do meu para o organização de Filipe, organização mesmo. Não pode mudar esse nome? É, tem que mudar o nome. Renomear, né? É, bom, então, que a questão é, é essa. Agora eu consegui acessar, tenho as duas, a organização com o homenzinho, a organização com a casinha. Preciso mudar um dos dois nomes, poderia ser organização de Lucha Negra, o nosso grande, ou mudo o meu, não tem problema. Fora isso, que é o de menos, A questão é que os projetos, o CRM está no meu, preciso agora migrar para organização. Como é que eu vou fazer? É, eu já mandei para ela o CRM. Você quer— tem mais algum que você quer mandar? Não, é o CRM só. É, então eu já mandei para ela o link.

**[56:33] Kimberly Prestes:** Manda o e-mail da conta principal de vocês, do, do Adapta Gold, porque, Felipe, isso a gente vai ter que fazer manualmente aqui, tá bom?

**[56:41] LAGHI Live:** A conta principal é a sua, né, Vinícius? Convidar ela? Ah, no Skype? No Skype, sim. A conta principal é a sua, né, Vinícius? É, Vinícius @luchinheiro. Posso convidar? Deixa ver. E na organização te convido, né? É, na organização. Eu acho que agora estamos todos. Convite. Qual que é o seu e-mail, Kimberly?

**[57:19] Kimberly Prestes:** Kimberly, eu vou mandar aqui no teu WhatsApp.

**[57:23] LAGHI Live:** Manda no WhatsApp. Qualquer coisa eu entro por aqui. Tá travado 100%. Mas o quê? Você tava mostrando—

**[57:39] Kimberly Prestes:** tem que ver se você tem permissão. Se você tiver como membro, você—

**[57:43] LAGHI Live:** eu sou— ah, tá, eu tô como administrador. Já, já vou colocar aqui.

**[57:50] Kimberly Prestes:** E daí eu peço para poder trocar o nome ali também do—

**[57:54] LAGHI Live:** você aceitou e o Pedro aceitou, e eu passei para lá. Agora sumiu, mas tava dando limite máximo de membros. É, mas o dela vai estar como não membro. Ela vai— agora manda para aqui, né? Depois eu já tô mandando.

**[58:07] Kimberly Prestes:** Não sei se vai estar como não membro ainda, tá? Se não, se não der—

**[58:13] LAGHI Live:** membro ou administrador, tanto faz.

**[58:18] Kimberly Prestes:** Mas se não der para— aí eu preciso pedir aqui para eles liberarem mais um acesso para não contabilizar com os 5 de vocês.

**[58:28] LAGHI Live:** Não, mas tem 3, são 3 membros por enquanto. Por enquanto não tem problema, aqui depois nós—

**[58:34] Kimberly Prestes:** daí eu peço ali para eles, daí só me coloquem daí também lá no, no suporte.

**[58:42] LAGHI Live:** E aí é o mesmo e-mail, né?

**[58:46] Kimberly Prestes:** Uhum.

**[58:51] LAGHI Live:** Onde que eu venho aqui?

**[58:52] Kimberly Prestes:** Ela aqui tem que mudar em organização.

**[58:55] LAGHI Live:** O nome.

**[58:57] Kimberly Prestes:** Aqui eu tentei ver na organização lá. Pode clicar ali, ó, Felipe, aqui, né? Você vai lá em Teams, lá no canto, no, no site de bar ali. Isso, Teams. E aí você me convida. Tá, do suvabês chegou.

**[59:31] LAGHI Live:** Agora aquela conta de suvabês é outra história, mas é, eu não me lembro, mas tá, tá bom, vamos manter aquela, né? Ela vai pedir para o pessoal do, do sistema para trocar o CRM para conta da empresa. E aí depois é só trocar o nome aqui do, da Filippo para Luchinera. É também a mudança de nome, eles que fazem, né? Acho que sim, porque eu aqui não estou vendo possibilidade de gerenciar isso. Não, não tem, vai ter que pedir para o—

**[01:00:13] Kimberly Prestes:** o que que vocês falaram?

**[01:00:14] LAGHI Live:** Desculpa. É o Filipe trocar aqui organização de Filipe para organização.

**[01:00:21] Kimberly Prestes:** Eu vou, eu vou solicitar isso já, tá? Já não tem.

**[01:00:24] LAGHI Live:** Perfeito. Então aí ficou, eu já te mandei o convite, então tem dois convites aqui, o seu e o da Mari.

**[01:00:37] Kimberly Prestes:** E aí eu mandei também o do Super Base, é do Super Base, eu já entrei, do Skip eu ainda não recebi.

**[01:00:43] LAGHI Live:** Ótimo, isso já ajuda. Essa coisa do suba vez que sempre me preocupou, e realmente— é, não, que, que realmente tem que estar super bem postado para trabalhar bem nesse CRM e nos próximos aplicativos. E, ô, Kimberley, deixa eu te falar, você pode me mandar no WhatsApp o que a DAPTA respondeu?

**[01:01:08] Kimberly Prestes:** Já mandei, já tá no—

**[01:01:10] LAGHI Live:** perfeito.

**[01:01:14] Kimberly Prestes:** Ali, mas depois, quando você tiver acesso ali o workspace, usa ali o óculos, daí você continua. Então, por exemplo, ah, preciso acrescentar mais essas informações. E aí você vai criando essa estratégia. Você pode pedir inclusive, é, você pode fazer até O, já adapta, coloca ali no, no adaptar, no cloud, no, no, isso, tipo, dentro dos números, começou a pagar 100, coloca no cloud 4.6 SONHE, só que no sistema lá, né, que ela tá no jeito certinho, vai aparecer assim, aí precisa fazer o coluna de valor total da venda. Aí a gente vai fazer— a gente vai se repetir.

**[01:02:09] LAGHI Live:** Então tem que pegar essa— calma aí que eu não tô conseguindo te ouvir, que eles estão conversando ali. E aí, tudo bem? Bom demais. É, o que que eu coloco? Desculpa.

**[01:02:26] Kimberly Prestes:** Daí você só vai, vai falar: cria uma skill expert em análise de esquema do supabase e criação de estratégia de estruturas de banco de dados. Para isso, faço uma pesquisa detalhada das melhores boas práticas. Para isso, crie— faça uma pesquisa, desculpa, detalhada sobre as, sobre as melhores boas práticas. Estruturas, arquitetura de banco, dados relacionados, segurança, performance, estrutura—

**[01:03:31] LAGHI Live:** calma aí que eu—

**[01:03:32] Kimberly Prestes:** estrutura, melhores, boas práticas de estruturas, performance, arquitetura de banco, É, segurança, relacionamento de dados, criação de novas tabelas. E gere a skill. E daí, com isso, pode enviar. Aí, com isso, ele vai criar uma skill que vai deixar salva ali. Então, toda vez que você mandar um esquema ali do— para base, ele vai— toda essa skill que ele vai criar, tudo automaticamente. Então, por exemplo, você já pode ir pensando em alguns processos que dá para fazer dentro da Adapta. Às vezes você tem um processo que você tem— precisa de vários especialistas, e daí cada especialista você pode criar uma skill específica para aquela área. Então, ah, quero fazer uma pesquisa, cria um pesquisador voltado para aquela coisa, e todas as skills vão ficar ativas no sistema. E aí elas ficam ativas, é, você consegue, e só escrevendo, então quero uma pesquisa ele já sabe como fazer uma pesquisa. Quero fazer uma análise, ele já sabe como analisar um esquema. E aí, com, com isso vai, vai aumentando a produtividade. Aí depois a gente cria skills para conectar com as integrações propriamente ditas, tá?

**[01:05:18] LAGHI Live:** Fechou, fechou. Era isso então, é muita informação, mas é informação, mas deu para esclarecer bastante coisa. E agora o foco real é reorganizar o database para, para ficar tudo certinho. Aí passar o CRM para conta principal da luteineira e as outras coisas, o, os 3 projetos que eu te mandei que tava na minha conta.

**[01:05:46] Kimberly Prestes:** Sim, e daí a gente precisa resolver aquele negócio do, do, dos projetos de vocês lá da Microsoft.

**[01:05:56] LAGHI Live:** É que aí o link, né, que o link do SharePoint com com as informações internas do Supabase. A gente vai fazer com Supabase, né, o link das duas, um function head.

**[01:06:11] Kimberly Prestes:** Sim, não, para a gente utilizar aí no código puro, a gente é só coisas bem mais complexas ou automações bem mais que você precisa de muitas APIs na mesma chamada. E aí você vai precisar de um N8N da vida ou em código. Tirando isso, você pode fazer direto na, na edifuncions, que ela já consegue, apesar dela ser um código ali dentro.

**[01:06:37] LAGHI Live:** É, os— é, edifuncions é do Supabase, é como se fosse API interna do Supabase, tá? É uma ponte, né?

**[01:06:45] Kimberly Prestes:** Aham, é algo que faz as automações. E aí, como automação é manipulação de dados integração é o que a Edge Functions faz, né? Então a gente não vai utilizar tanto N8n, mas caso você queira— ah, Kimberly, não quero ficar quebrando a cabeça com, com Edge Functions— pode fazer lá no, o fluxo ali do teu N8n, porque daí vai ser curto, né? E a Edge Functions vai chamar o webhook, e aí o webhook já vai fazer todo aquele processo, que daí você é, simplifica o teu trabalho também do que ficar quebrando cabeça, né, com API.

**[01:07:24] LAGHI Live:** Tá, tá bom, fechou.

**[01:07:26] Kimberly Prestes:** Então aí a gente conversa ali pelo WhatsApp, tá?

**[01:07:29] LAGHI Live:** Tá, então obrigado, Kimberly.

**[01:07:32] Kimberly Prestes:** Obrigada eu. Tchau, tchau, Pedro.

**[01:07:34] LAGHI Live:** Legal, tchau. Então essa coisa de ligar, que acabou de ver que eu tô com pouquíssimos créditos, e assim a gente consegue já—

**[01:07:43] Kimberly Prestes:** eu vou, eu vou mandar mensagem aqui assim que eles voltarem, eu já peço com urgência para eles mandarem o CRM pro, pro, para, para conta principal, tá bom? Obrigado aí, tchau, tchau, gente!

**[01:08:12] LAGHI Live:** [MASKED] [MASKED] [MASKED] [MASKED] [MASKED] [MASKED]

