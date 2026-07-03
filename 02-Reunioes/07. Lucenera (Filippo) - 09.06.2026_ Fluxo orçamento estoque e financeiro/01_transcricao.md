# Transcrição - 07. Lucenera (Filippo) - 09.06.2026: Fluxo orçamento estoque e financeiro

- Título tl;dv: Adapta Pass <> Filippo
- Assunto principal: Fluxo orçamento estoque e financeiro
- Data: 2026-06-09
- Horário: 14:00
- Link: https://tldv.io/app/meetings/6a2846baebc00200127220aa
- ID tl;dv: 6a2846baebc00200127220aa
- Duração aproximada: 01:19:29
- Participantes/e-mails capturados: kimberly@adapta.org; filippo@lucenera.com.br; pedro@lucenera.com.br

> Fonte: transcrição retornada pela API do tl;dv. Texto mantido com erros naturais de transcrição quando existentes.

## Transcrição

**[00:00] LAGHI Live:** Vamos supor, eu colocando, eu pegando um orçamento, aprovando esse orçamento, e aí automaticamente ele fazer todo o processo que é retirar a peça de estoque, caso não tenha peça em estoque, avisar o financeiro para fazer a compra. Então todo esse tipo de coisa que ele quer entender. Aí ele falou, já tô entrando.

**[00:27] Kimberly Prestes:** Sabe o que dá para fazer? Você usa o cursor, né?

**[00:36] LAGHI Live:** Como assim?

**[00:36] Kimberly Prestes:** Você usa o cursor?

**[00:38] LAGHI Live:** Não, eu uso VS Code.

**[00:41] Kimberly Prestes:** VS Code tem, tem, eu te mando ali depois que agora não vou lembrar o nome, mas para você, tipo um plugin, uma skill cria, sabe, o Miro?

**[00:57] LAGHI Live:** Sim, de fluxo.

**[00:59] Kimberly Prestes:** E aí você pede para ele analisar e criar os fluxos por atividades. Então, por exemplo, orçamento. Qual que é o fluxo do orçamento do usuário, né? Qual que vai ser o fluxo de tal pessoa para isso? E você consegue desenhar isso para ele conseguir ver visual, porque se a gente explicar ainda ele vai ficar com dúvidas, né? Então ele precisa—

**[01:27] LAGHI Live:** é justamente o que tá acontecendo. Eu já expliquei para ele, mas vamos pensar aqui, tem umas outras coisas que eu precisava adiantar com você enquanto ele não entra, que ele vai começar a perguntar. Deixa eu te passar, eu tava tentando fazer o dashboard no Skip. E aí, basicamente, Felipe entrou.

**[02:06] Kimberly Prestes:** Oi, Felipe, tudo bem?

**[02:08] Filippo Giorgi:** Oi, tudo bom?

**[02:10] LAGHI Live:** Oi, Filipe.

**[02:11] Filippo Giorgi:** Oi, boa tarde. Então, você já começaram?

**[02:21] LAGHI Live:** Eu ia começar a falar sobre uma questão do Skip, que é justamente o dashboard, né, o dashboard que eu tô fazendo. E aí eu ia perguntar para Kimberly com relação ao VW. A visualização, porque eu acho que ele não tá buscando todas as informações. Eu queria tirar essa dúvida antes da gente realmente começar.

**[02:49] Filippo Giorgi:** Até que eu escuto vocês, mas qual VW, Pedro?

**[02:55] Kimberly Prestes:** Deixa eu ver aqui, eu tô tentando pegar um Mas o VW tá puxando certo das tabelas, mas no skip não tá aparecendo.

**[03:35] LAGHI Live:** É, no skip não tá aparecendo 100% das informações. Projeto dashboard VW.

**[03:52] Kimberly Prestes:** Você encontrou no VW essas coisas que estão aparecendo, mas não Não, no skip.

**[03:59] LAGHI Live:** Isso.

**[04:00] Kimberly Prestes:** Compartilha aí a tela para mostrar.

**[04:23] LAGHI Live:** Está conseguindo ver?

**[04:31] Kimberly Prestes:** Sim.

**[04:37] LAGHI Live:** Então aqui, ó, esses teoricamente são os dados de todo o período. Na realidade tá bem discrepante. Tá, mas isso aqui, como é uma coisa mais séria, a gente pode ver com o tempo, tem uma prioridade. Eu acho que o Filipe tem mais perguntas que ele quer entender mais relacionado ao Supabase. E você quer começar?

**[05:25] Filippo Giorgi:** Isso aqui já é uma demonstração do que são as minhas preocupações. E eu, nós, a gente chegou a um ponto de parar, né, porque fizemos outros aplicativos, não focamos mais em avançar com Supabase e aplicativos que continua na nossa, em completar nossos processos. Eu sinto que se é só pelo Skip, a gente vai toda vez um pouco apanhar, porque uma coisa não faz, uma coisa não faz tão direto. Então eu acho que da outra vez já mais ou menos falamos, eu acho que temos que dominar o Superbase, depois é fácil fazer um aplicativo, porque as informações estão já organizadas de uma forma assertiva. Porque quando a gente só pede por vibe coding, ó, faz isso, ele faz, mas de repente, não sei, eu acredito, queria ver se conseguimos organizar de dar continuidade, alimentar o Super Base em função de todas as informações que precisamos colocar e ir depois e ir amarrando com skip essas e puxar. Não tem o super base, acho que é a coisa um pouco mais importante. Pode ser skip, pode ser cloud code, pode ser qualquer coisa que depois gerencia aquilo. Então, para mim, eu quero ser assertivo. Então, é lógico, vocês sabem perfeitamente mais que a gente que o mundo da IA é vastíssimo e que a cada semana sai coisa nova. A gente está confiante em trabalhar com vocês com as ferramentas dentro da Adapta, mas também começamos a ter muita dificuldade, vamos precisar sair para outras ferramentas porque não tem. Então pedimos realmente que nessa fase aqui que nós vamos conseguir chegar, se realmente tivermos ajuda de vocês, a gente conseguir correr bem, realmente vamos conseguir terminar um sistema gestional de uma empresa com 3 empresas, uma coisa muito complexa, e num tempo que não sei se será o do summit, mas estaremos muito avançados. Afinal, essa ideia eu tenho na cabeça, de uma forma ou da outra eu preciso chegar lá. Então vamos ver o que podemos fazer com o Super Base em relação a novos processos. Então agora estamos fazendo os orçamentos, isso já tem um aplicativo com script feito pelo Pedro. De lá, aprovou o orçamento, começam as coisas sérias, porque começar a atingir o estoque, ver quantas peças tem no estoque das pedidas, ver a necessidade de pedido. Depois entram as coisas financeiras também, pagamentos, recebimentos. Então essa parte é muito delicada, é muito importante. Então agora queremos atacar isso.

**[08:32] Kimberly Prestes:** É, eu vi aqui, eu até tava pegando qual era a diferença que tava de antes para agora, né? Eu vi que vocês colocaram a remessa bancária Orçamentos, integração Ubiqua.

**[08:45] Filippo Giorgi:** Ubiqua é uma peça que a gente trabalha, é um aplicativo à parte, será gerenciado como produto dentro dos produtos igualmente.

**[08:56] Kimberly Prestes:** Daí a logística e RH, que já tinha antes, né, mas eles foi acrescentado mais coisas. Mas é a base do Supabase, a gente não criou no próprio Skip, né, então a todas as relações ali, porque o Skipper, ele segue o padrão e cria o próprio padrão. Então a gente criou o padrão antes para ele entrar. Só para poder validar, Pedro, aquelas questões das novas planilhas do Diogo, já deu certo com aqueles novos códigos ou não?

**[09:34] LAGHI Live:** Do Sérgio? É, então eu consegui importar para o Superbase normal. Eu só expliquei via SQL que tinha alterado a nomenclatura. E aí eu, na parte do Power BI, eu tive que fazer via SQL também. Não, não é SQL.

**[09:57] Kimberly Prestes:** Mas aí deu certo pelo código?

**[10:00] LAGHI Live:** Deu certo pelo código, eu consegui trocar a nomenclatura.

**[10:04] Kimberly Prestes:** Ah, perfeito. Então essa parte meio que ok. Aí agora o trabalho é fazer com que, porque quando a gente tá falando sobre o Vibe Code que já gera o sistema e já conecta com o banco de dados, o Love, o Skip, eles teoricamente são criados para poder conectar e já criar o banco, né? A gente fez o papel inverso, a gente queria criar o padrão. Então essa partezinha dá um pouco, é um pouquinho chatinho, porque você precisa indicar exatamente qual é a tabela, o que que ele precisa fazer. Por isso, né, que a gente já criou as views. A gente precisa entrar mais a fundo desses sistemas para poder ver. Felipe, o Pedro inclusive tinha me falado que você quer entender, e eu vou passar para ele ali depois, como fazer a parte visual para você entender exatamente qual é o caminho que passa uma informação da outra e pelos sistemas. Então, por exemplo, como que conecta o orçamento lá com o estoque, para você ter esse visual do processo dentro do Superbase e dos sistemas, tá bom?

**[11:17] Filippo Giorgi:** É, na verdade, precisamos fazer as planilhas de forma que funcionem. Isso que Eu quero entender no sentido, eu acho que o domínio desse backhand é fundamental para você poder a qualquer momento implementar, corrigir, não é? Amanhã surge o problema de uma coisa que não tá batendo, a gente tem que saber como encontrar. Então não é, não, na verdade o meu fato é agora dar continuidade, vamos continuar. É só que a gente, tanto que o Pedro até tá fazendo um curso de Superbay, A gente está bastante seguro em como tem que agora, que por exemplo, agora temos lá a parte produtos, acho um pouco também, talvez, não sei se é tudo muito claro. Produtos, a lista de produtos totais que já passaram, ou seja, cada produto tem um cadastro. Esse produto pode estar no estoque ou não. Depois tem um estoque, a quantidade de peças que estão no estoque, que toda hora ela é atualizada. A lista de produtos, imagina uma lista que só que acrescenta. Pode ter que um produto seja desativado uma hora, mas vai ficar lá, né? Agora, produtos em estoque, isso é uma lista dinâmica que todo dia muda, né?

**[12:42] Kimberly Prestes:** Sim.

**[12:45] Filippo Giorgi:** Depois tem as separações. Então, tudo que é a parte de processo que temos, que tem que ser feitas as planilhas certas.

**[12:59] Kimberly Prestes:** Sim, as planilhas já estão conectadas. Inclusive, enquanto você foi vendo, eu fui até olhando aqui para ver se elas estão certinho. Então, por exemplo, estoque itens tá aqui, produto ID.

**[13:13] Filippo Giorgi:** O, a parte, deixa eu ver aqui, tá funcionando realmente, tá? É isso que às vezes, tipo, é de Agora então vamos fazer o aplicativo. Já estamos com tudo no suporte para fazer um aplicativo já de— bom, aprovou o orçamento, acontece isso, isso aqui que agora temos que fazer.

**[13:40] Kimberly Prestes:** Então o ideal é a gente ter, mapear todas essas regras. Então, por exemplo, né, aprovou um orçamento, não é agora que vai sair o produto do estoque. 6, mas precisa ficar reservado, né, que o Diego falou. É só que alguém pode pegar aquele produto daqui 3 anos. Você precisa ter aquele produto no teu estoque que tá como reserva. Então não precisa disparar uma lógica de compra daquele produto específico, porque Não necessariamente.

**[14:19] Filippo Giorgi:** Compra é outra etapa. Eu tenho isso no estoque.

**[14:24] Kimberly Prestes:** São do mesmo fluxo, entendeu? Mesmo que seja sistema diferente, é o mesmo fluxo. Então a gente precisa mapear exatamente todas essas regras, porque isso vira head functions, Pedro.

**[14:38] Filippo Giorgi:** E essas regras, como a gente consegue mapear?

**[14:44] Kimberly Prestes:** É literalmente entender o escopo, o orçamento. O que que daí é exceção? Você vai ter que pegar ponto a ponto do orçamento. Que que acontece quando finaliza um orçamento? Acontece isso, ele tem esses produtos, só que, ok, tem dois caminhos. Tem o orçamento fechou, ele vai reservar. Então vai ter que dar um start lá no estoque, porque ele vai reservar aquilo daqui algum tempo. Qual tem outro start? Quando ele fecha o orçamento, ah, vai para área jurídica que tem que fazer determinada coisa. Enfim, tudo que vai dar start, ok. Agora vai sair dessa parte e vai, sei lá, quando ele for pegar o orçamento, é Né, ele pode ou não mudar os itens, pode mudar os itens. O que que acontece com estoque? E é pegar a história do usuário que a gente fala, é pegar a história de cada um desses pontos e mapeando o que que acontece se fizer isso e se não fizer, o que que acontece. Ah, tem um ou mais soluções, tem que mapear essas regras porque tudo isso precisa virar é de functions para ela fica toda automatizada.

**[16:04] LAGHI Live:** É a história do usuário que tem que criar, que é mais ou menos o que a gente tá fazendo no Miro. A gente tá determinando todas as nuances, só que tem coisas que eu vi que não tem. Por exemplo, se a peça não tá registrada, é uma peça nova, a Débora que trabalha lá, ela tem que entrar, fazer o cadastro da peça, Isso são coisas que não tem.

**[16:31] Filippo Giorgi:** Isso vai ser sempre. Chegou um produto novo, eu vou colocar aí no orçamento, vou registrar esse produto já.

**[16:39] Kimberly Prestes:** Mas aí, pensando, é, daí pensando em produtividade, não vai pedir para Débora, porque daí você sai do sistema, vai ter que mandar, e a gente não quer isso, né? O trabalho fantasma que a gente quer evitar. Então, é, tem um orçamento, é uma peça que não, que não existe, cai numa área lá do estoque de solicitações de peça que não existe. E aí já vem com os dados para que ela analise, aí ela pode aprovar para poder manter ali e mandar, por exemplo, para compras, para, enfim, só ideia. Eu acho uma coisa, esse gatilho, entendeu?

**[17:16] Filippo Giorgi:** Quando a peça não existe, eu acho que quem que está fazendo orçamento, ou uma secretária de administração, na hora já vai registrar. Tem que registrar, porque o orçamento quer ficar com a peça que é registrada. Isso seria o ideal. Hoje fazemos isso um pouco depois, mas na verdade faltou uma peça, então essa peça estou orçando, vai ser usada no futuro, vamos registrar o produto novo na lista de produtos. Isso acho que é até meio o de menos, isso são detalhes. Vamos começar. A questão que temos que realmente fazer é aprovar o orçamento, que acontece, que deve acontecer a nível de estoque e a nível financeiro. São essas duas frentes. Financeiro tem duas versantes: cobrar e pagar, né? Entrada de dinheiro e pagar fornecedores. E o estoque, que é a coisa mais importante, mais delicada do— não, mais não, mas que é muito delicado também. Então, como também se falou, eu vendi, mas a peça vai ficar reservada, mas vai ser entregue daqui a um ano. Então nós temos um estoque de clientes onde as peças estão todas juntas, não estão separadas por cliente, mas já separamos a mercadoria vendida.

**[18:44] Kimberly Prestes:** É, sim.

**[18:46] Filippo Giorgi:** Então tem esse estoque clientes ainda não preparado para o cliente, e depois, quando estamos prestes a entregar, vamos ter que separar para o cliente. Está já separado para cliente, então vamos pegar de lá e vamos separar para ele mesmo. Então tem essas fases, tem que entender. Eu nisso aqui Vamos também fazer mais uma reunião depois, eu, você, Pedro e o Vinícius, porque o Vinícius tem que estar com vocês, tem que acompanhar, porque ele sabe como é o processo. Sem saber o processo, logicamente vocês dois podem imaginar as melhores coisas, mas sem saber exatamente cada detalhe do processo, não vai acontecer aquilo, assim, né? Porque você não está sabendo como que é. Então, Vinícius, tem que— essa parte aqui agora vocês têm que conversar muito bem com Vinícius, secretários, para entender como isso pode, deve ser impostado para funcionar.

**[19:56] Kimberly Prestes:** É outra coisa que eu ia perguntar, que eu tava vendo aqui, como agora entrou orçamentos, itens, os orçamentos tá lá em projetos, né, os projetos não fechados, no caso. E os projetos, itens dos projetos que já tem, que a gente conversou na última reunião, é que tava no SharePoint, né? Vai subir ou não vai subir? Ou não, não foi visto nada?

**[20:28] LAGHI Live:** Como assim?

**[20:29] Filippo Giorgi:** Não, projetos tem que estar. Agora, considerando uma coisa, nós estamos com construindo alguma coisa que só pode ser colocada em função realmente quando está completa, porque senão a gente está testando, está funcionando de registrar um projeto, os projetos ficam registrados, só que a gente vai continuar alimentando, puxando de lá, porque ninguém vai carregando aqui no nosso sistema atualmente, então ainda tudo na conecta, então a gente periodicamente tem que baixar nova planilha e atualizar.

**[21:05] Kimberly Prestes:** Né, sim, mas a questão é, os projetos que são fechados, eles têm os itens de cada um desses projetos. Esses projetos, itens, tá dentro do SharePoint, só que ainda não foi, não tá dentro do SharePoint.

**[21:26] Filippo Giorgi:** Não, não temos projetos itens. De repente está no Connect, no sistema, mas não evidenciado como projetos itens.

**[21:38] LAGHI Live:** O que a gente tem de item é a questão do orçamento. Aí o orçamento é aprovado, ele vira a quantidade de item por projeto.

**[21:49] Kimberly Prestes:** Entendeu?

**[21:52] Filippo Giorgi:** É orçamento.

**[21:54] Kimberly Prestes:** Mas isso você já configurou dentro do Superbase ou não?

**[21:58] LAGHI Live:** Então, mas um orçamento aprovado Ainda não, isso eu preciso fazer, eu vou fazer no skip para criar a visualização de aprovar um orçamento até, e aí fazer o fluxo, né, que aí ele vai sair do orçamento e entrar na parte de projetos e itens.

**[22:17] Kimberly Prestes:** Entendi, tá, tá, entendi. E aí, mas vai vir o histórico desses projetos e itens da onde tiver? Ou não?

**[22:30] LAGHI Live:** Vai vir o histórico do orçamento, tá?

**[22:34] Kimberly Prestes:** De todos os orçamentos, no caso. Aí os que são fechados, você—

**[22:38] Filippo Giorgi:** sim, mas espera, espera, porque depois o histórico dos orçamentos, ou seja, os orçamentos, o que é— agora nota bem, porque depois a gente fica bem para limitar o mínimo esse trabalho. O que realmente vamos precisar de histórico, né? Que tem tipo, como gerenciar esse histórico, pode ser que o histórico ficou um histórico, pronto, não precisa ter todas as referências de lançamento de tal. Lá para frente, quando está tudo dentro do sistema, com certeza nós teremos que aquele item foi vendido ontem, semana passada, faz um mês, faz 3 meses, faz um ano. Certas quantidades. Ou seja, lá vamos ter um histórico comprando isso, mas ele não é um histórico tão importante para pensar ter que gravar o atual, entendeu?

**[23:32] Kimberly Prestes:** Não é nem pelo histórico do orçamento, é porque eu tô só para entender da onde que vai vir o projeto itens. Então por isso que eu tô perguntando se é o histórico do orçamento que vai vir e daí ele vai puxar os projetos fechados, linkados ali com esse histórico de orçamento, para daí já popular o projeto itens.

**[23:58] Filippo Giorgi:** Porque tem exatamente até a dúvida que até nós temos isso, projetos itens acho que vem de orçamento uma vez que está aprovado teoricamente.

**[24:10] Kimberly Prestes:** Consigo entender a lógica, Felipe.

**[24:13] LAGHI Live:** Eu consegui. Eu acho que é nesse, nesse, isso que a gente tá falando mesmo. A partir do orçamento é aprovado, aprovado ele entra em projetos itens.

**[24:24] Kimberly Prestes:** E aí a gente já tem aí o histórico, né, o histórico de projetos itens, porque tem coisas que vocês ainda vão ter que entregar, né. Então é orçamento histórico de entrega de material.

**[24:39] LAGHI Live:** Isso, a gente já tem, a gente tem aquele sistema pré-pronto já que tem, só precisa fazer a parte do histórico de material, mas tem todas as entregas, tá?

**[24:52] Kimberly Prestes:** Porque pense, né, eu contratei vocês, digamos, ano passado, daqui 2 anos vocês vão me entregar os dados dos meus itens, então vai vindo histórico de orçamentos, itens que já tá aprovado o meu projeto, e esse projeto fechado já puxa para o projetos itens, entendeu?

**[25:18] LAGHI Live:** E aí, a partir daí, projetos itens, é a entrega.

**[25:23] Filippo Giorgi:** Esse projeto itens é a lista de quê?

**[25:29] Kimberly Prestes:** É uma tabela que tem dentro do Superbase.

**[25:32] Filippo Giorgi:** É a lista de quê?

**[25:35] LAGHI Live:** É a lista das peças do orçamento, ou seja, vendidas a partir do momento que foi aprovado.

**[25:47] Filippo Giorgi:** Mas temos que entender que lista que precisamos, né? A questão é, eu volto a falar, fechamos, nós precisamos, nós precisamos ter, vamos, de geral, sempre a fotografia do estoque. Tá, o estoque disponível e o estoque de cliente são duas listas, talvez separadas, ou é uma lista onde endereçamos o que é cliente, o que é livre. Isso não sei qual é a lógica melhor. Então nós precisamos, né, de ter esses dois estoques disponíveis. No estoque cliente, cada item deve ser também dedicado a um cliente, né? Então é uma lista talvez que possa ser, não sei se são duas planilhas diferentes.

**[26:37] Kimberly Prestes:** É que para funcionar a gente vai ter que saber da onde vai sair esses produtos, os projetos itens.

**[26:47] Filippo Giorgi:** E aí para o estoque, pode esquecer um momentinho, esquece projeto itens um momentinho. Eu fecho um orçamento, eu fecho um orçamento, eu tenho uma lista que é do estoque. Esse estoque, por enquanto, vai vir carregado do estoque existente do outro sistema. Vamos ter uma lista total de estoque disponível no momento do ano zero, do dia zero, quando vamos começar o nosso sistema. Vamos ter a fotografia do estoque atual que vem do Connecta. Vamos até ter uma fotografia de estoque de cliente, que com cada item de quem é o cliente destinatário dele. Depois vai ser alimentado, isso é o momento zero, depois esquece coisa baixadas, depois vai ser alimentado toda vez que fechar um orçamento. Esse orçamento vai criar uma necessidade para o estoque, é uma necessidade que é do estoque cliente mesmo. Que pode ser alimentada pelo estoque físico já presente ou por pedidos. Na verdade, o estoque disponível vai determinar os pedidos, porque o estoque disponível vai ter itens em negativo. Porque se eu fechei vários projetos onde tem aquele item que tem 150 peças no estoque, mas eu vendi 270 peças, eu vou ter no estoque disponível uma necessidade de 120.

**[28:25] Kimberly Prestes:** Sim, né, de produtos. O orçamento, ele é direcionado para orçamento, e os orçamentos fechados, eles são relacionados a projetos. E projetos, tem o projeto completo, projeto fechado, projeto parcelas, né, para poder ter a variação, e projeto itens. O que, por causa do estado, né, a gente trabalha por estados daquele, aquela informação, o estado daquela informação de projetos, aí sim conecta com o com o— agora fugiu o nome— com o estoque. Porque se a tabela inteira de orçamentos que tem fechados ou não fechados estiver conectada com o estoque, pode gerar confusão depois para poder, se precisar arrumar qualquer coisa, porque não é todos os orçamentos que tem que tirar do estoque, porque é só aqueles que são aprovados. Então, uma vez que a gente tá usando projetos, exatamente, e os projetos, eles têm uma tabela específica que é só o projeto ID, entendeu?

**[29:59] Filippo Giorgi:** Agora, tudo começa com orçamento, que não é Não se sabe se é aprovado ou não. Sempre tem um orçamento, o orçamento se modifica, vai lá, e esse orçamento a nível de necessidade, coisa, não mexe em nada, não mexe em estoque, não mexe absolutamente em nada, é só um orçamento. Ele só vai atingir a lista de produtos onde tem o preço, etc. Então, mas ainda não é nada, é uma coisa em um limbo, está lá suspenso no ar. No momento que é aprovado Lá fica, começa tudo. Lá é uma lista de material que temos que entregar para um cliente. Então, dele passar para o estoque disponível e chegar no estoque cliente e ser separado depois para o cliente específico.

**[30:50] Kimberly Prestes:** Sim, sim, que daí tem, é esse o ponto, que daí tem a tabela específica de projetos itens. Uma questão que eu, para te perguntar, Pedro, o orçamentos, ele já tá linkado com projetos? Já?

**[31:08] LAGHI Live:** Não, não, ainda não, tá.

**[31:11] Filippo Giorgi:** Mas eu posso fazer, deve, lógico, deve. O orçamento é de um projeto. Quando nós fazemos, como não está linkado com o projeto, talvez não está linkado a nível, a nível de super base, mas já na mascara de orçamento, a gente coloca qual projeto é. Então tem que justamente ser estruturado a nível de ideia e coisa para que essa ideia seja realmente aquilo daquele que estamos colocando no projeto.

**[31:39] LAGHI Live:** Sim, mas é para criar um orçamento.

**[31:45] Filippo Giorgi:** No orçamento, quais informações que vêm de outras planilhas? Tem o projeto, se é um número de projeto, A empresa que está vendendo, o projeto, o nome do cliente, o arquiteto, o responsável, todos isso estão lá dentro e tem que ser puxado como ID de outra planilha, né?

**[32:08] Kimberly Prestes:** Tá certo, Pedro, porque como tem cliente ID, o cliente tá— ah não, mas é que na verdade nem precisaria do cliente, precisa do projeto, porque o projeto tá linkado com o cliente. Só que o cliente pode ter mais de um projeto, só que o projeto sempre é o mesmo cliente, entendeu?

**[32:28] LAGHI Live:** É que no orçamento atual ele sempre aparece o nome do cliente, aí por isso que a gente fez com base nisso. Mas eu vou colocar o número do projeto, tá?

**[32:40] Filippo Giorgi:** Que aí é uma coisa inclusive vai ter até isso aqui, temos que entender o projeto A referência do projeto é um número, né? E aquilo, além do número de projeto visível para nós, existe uma ideia daquele projeto, certo? Sim, que é amarrado ao cliente, é um arquiteto e é um responsável, e é um engenheiro, e eventualmente um eletricista.

**[33:16] Kimberly Prestes:** Pensando em eficiência, ele fica um pouco redundante, porque o projeto já tem que ter qual é a empresa, qual é o arquiteto, qual é o cliente.

**[33:28] Filippo Giorgi:** Não, espera, o projeto a empresa ainda não tem, talvez. Então a gente começa a trabalhar e depois, na hora de faturar, pode, na hora de começar Pode ser que nem projeto não entra empresa, empresa entra a partir do orçamento, vamos falar justamente disso. O momento de registrar empresa no fluxo é o orçamento. No projeto deve saber quem que é o cliente, quem que é o arquiteto que trouxe o cliente, quem que é o arquiteto responsável, o light designer da luz negra, quem que é o engenheiro responsável da obra, Isso são as coisas importantes. Também acrescentamos o eletricista, porque para nós pode ser importante. Então também o eletricista. Mas não precisa nesse momento estar amarrado a uma empresa. É possível até que a gente faça vendas por empresas diferentes ao mesmo projeto e ao mesmo cliente.

**[34:34] LAGHI Live:** Sim, essa parte fica bem mais complexa.

**[34:43] Kimberly Prestes:** É porque, ó, porque vai ter que fazer o caminho inverso de orçamentos, porque o cliente ele pode ter vários projetos. Então não tem nem a única questão que teria para ter essa coluna é caso algum projeto não tivesse o cliente, mas como todos os projetos tem que ter cliente. Não, aqui você não vai usar essa coluna para nada porque ele faz todo o FK, né? Então ele puxa que projeto é de tal pessoa e as informações necessárias, né?

**[35:15] Filippo Giorgi:** É, teoricamente também para fazer o projeto bastaria uma dessas informações para puxar as outras.

**[35:22] Kimberly Prestes:** Exatamente.

**[35:23] Filippo Giorgi:** Para fazer orçamento, desculpa, na hora de orçamento. Isso é uma questão de funcionalidade, beleza.

**[35:31] Kimberly Prestes:** Funcionalidade, tá? Porque na hora de registrar, se a pessoa dentro do sistema, né, dentro do sistema de orçamento, se a pessoa conectar, por exemplo, com um cliente ID diferente, e aí depois e linkar dentro dos campos com outro projeto, Vai quebrar todas aquelas informações. Então esses FKs não pode ser redundante porque pode gerar inconsistência. Então ela tem que anexar qual é o projeto para daí com esse projeto puxar todas as informações, e daí pode colocar a empresa, daí não tem problema.

**[36:10] Filippo Giorgi:** Tá, ok, concordo. Ou seja, o que que tem que ser, que puxar tudo é o número de projeto, porque o cliente poderia ter mais projetos. Então isso enquanto o número de projeto é aquele cliente, aquele cliente pode ter mais projeto, aquele cliente pode ter mais orçamentos, mas é sempre aquele número de projeto, é o orçamento amarrado ao número de projeto, correto? Como é hoje também.

**[36:36] Kimberly Prestes:** Exatamente. O que que você pode colocar? Porque também tem arquiteto e tem todas as informações ali, Pedro. O que que você pode colocar para bloquear isso dentro do sistema. É que quando ele precisa obrigatoriamente responder qual é o projeto, e o projeto puxa todos os itens, todas essas informações. Se acaso não tiver uma informação, aí sim a pessoa pode trocar. Se já tiver informação, ele é proibido de trocar os dados dentro dos campos ali na hora de registrar um orçamento.

**[37:14] LAGHI Live:** Tá, eu preciso confirmar depois, até conversar com a Mari, porque eu acho que tem orçamentos que são feitos antes do projeto realmente estar registrado.

**[37:32] Filippo Giorgi:** Tá, mas isso aqui a gente pode, talvez deve mudar no momento em que a gente se põe fazer um orçamento, tem que registrar o que eu falei, que é aquele número sequencial, querendo ou não, vai ter que entrar. E independentemente que seja um projeto, uma venda de um item, uma venda de um orçamentinho, que cai assim, sem projeto, vai para o CRM, né?

**[38:00] Kimberly Prestes:** Se ela cria um, um orçamento, precisa estar no campo dentro do CRM para poder fazer o follow-up. Essas pessoas.

**[38:08] Filippo Giorgi:** Exato. E a gente tem que categorizar isso aqui, se é projeto, se é venda de luminária, se é, sei lá, uma venda solta, orçamentos de projeto, ou uma cobrança de um serviço de projeto.

**[38:31] Kimberly Prestes:** Isso aqui que deve ter Sim, o que que dá para você fazer, Pedro, é colocar na hora dela ir criar um orçamento, porque daí já obriga a fazer isso, né? Que não adianta só falar, né? Para, a gente precisa colocar uns guarda-reis aí para galera seguir exatamente. Na hora de criar um orçamento, já se ela não colocar ali o projeto, já tem um botão para criar um novo projeto. Aí dentro de projeto, se não tiver o cliente, vai ter um botão de novo cliente. Então obrigatoriamente vai ter que seguir o fluxo, senão não gera o orçamento, tá?

**[39:11] LAGHI Live:** Perfeito. Então a partir do orçamento já eu já tenho que criar o projeto, e se não tiver o cliente, automaticamente o cliente também.

**[39:22] Kimberly Prestes:** Exatamente, que daí segue todo esse fluxo. E daí dentro do orçamento, quando anexou o projeto, já puxa todos os dados. E aí os campos que não tiver registrado, então por exemplo, qual que é o arquiteto, aí ela pode ou não preencher. Mas se tiver registrado, eu selecionei projeto X e dentro desse projeto já tem cliente, já tem arquiteto, já tem vendedor, enfim, todos os campos já vai ser puxado automaticamente e trava esses campos de mudança, porque daí ela não pode mudar, entendeu? Porque daí a gente consegue amarrar tudo. E daí, caso tiver um projeto que não tem arquiteto, e aí depois alguém vai querer colocar, então aí ela vai lá e coloca aquele projeto, entendeu? Coloca para aquele arquiteto ali específico. Daí posteriormente vocês podem criar algumas regras para ver quem que pode mudar de arquiteto, quem que não pode, mas Isso, ok, perfeito.

**[40:28] Filippo Giorgi:** Mas isso, ok, essa coisa até que fica automática, todas as informações não precisa selecionar. Eu não sei se até já isso aqui era assim, não esqueça disso. Agora, é uma coisa que estou curioso e que me serve na ótica de entender supermercado, etc., que acontece nesse orçamento, uma vez que estamos fazendo esse orçamento onde está registrando essas informações. Mas isso é justamente ter o controle disso. Mas depois, a partir de agora, como fazer a aprovação? Essa coisa é importante. Como fazemos a aprovação? E de lá, como desencadear as estoque e pagamentos?

**[41:13] Kimberly Prestes:** Tá, ali tem a tabela status. Status está esperando aprovação. Ok, deixa eu ver aqui, orçamento itens. Quando mudar o status aqui, ele precisa ir para projetos itens. É isso, né?

**[41:33] LAGHI Live:** É isso mesmo.

**[41:42] Filippo Giorgi:** Precisa criar necessidade daqueles itens, né?

**[41:45] Kimberly Prestes:** É que daí, ó, por exemplo, descrição, quantidade, preço unitário, tudo isso dá para reformular essa tabela de projetos, itens, e criar um FK para puxar do orçamento, para não reescrever tudo. E aí também a mesma coisa, projeto inteiro, a necessidade, porque vai ter um orçamento. Então deixar, não precisa deixar redundante. Projeto de orçamento, orçamento itens. Ó, também não precisa de produtos, produto ID, porque ele vai estar dentro de orçamento itens. Então basicamente o que que tem que ser projetos itens? É só referência do projeto fechado com o orçamento.

**[42:48] Filippo Giorgi:** O projeto, os itens, tem a lista dos itens, dos produtos, que aliás acho que tem um amarramento justamente com a planilha de produtos em termos de qual é o item. E acho que cria a necessidade, né? Cria um número de quantos precisa. Sim, deveria na hora da aprovação criar um negativo correspondente a um número de itens no orçamento, ou não, o número positivo de o que é necessário. Que é projetos itens?

**[43:37] LAGHI Live:** Exatamente, é a lista de que isso que é quando aprovou um orçamento automaticamente ele vira o projeto dos itens.

**[43:48] Filippo Giorgi:** Sim, mas a lista, se eu vejo a planilha projetos itens, ela tá sem nada porque não tem nenhum aprovado. Okay, então lá vai, irão todos os produtos.

**[44:06] LAGHI Live:** É sim, a partir do orçamento. Aí aprovou orçamento, vai para projetos, itens. De projetos, itens, a gente já vai fazer uma amarração com produtos e fazer com que ele fique separado ou uma coisa assim.

**[44:24] Filippo Giorgi:** Mas não tanto com produtos. Produtos é lista de produtos existentes.

**[44:30] LAGHI Live:** Que nós utilizamos.

**[44:32] Filippo Giorgi:** Não é nem o estoque, acho. Produtos em si. E tem um numérico do estoque em produtos? Então essa é a lista do estoque. Eu acho até que pela lógica do database não deveria ser a matriz do produto. Deveria ter uma lista anterior. De o que é o produto, é uma tabela com quais são os produtos que existem, independentemente de estoque, necessidade, o quê. Isso são os produtos. E o estoque puxa o ID dessa tabela. Essa é a lógica certa, pelo que eu sei, tá bom?

**[45:11] LAGHI Live:** Não, essa era a lógica que a gente importou do sistema do Sérgio, da Connect.

**[45:18] Filippo Giorgi:** Sim, eu sei, mas para organizar o database não é assim que deveria ser feita a lista dos produtos? E esse aqui, só mudar a questão que o produto é registrado em outra planilha, isso deveria ser fácil de criar? Eu não sei se, mas eu vejo que é assim que se organiza, certo? A informação nível básico, porque pode mudar uma coisa, ele não pode ser diretamente o stock. O estoque, ok, mas olha, a gente tem que poder intervir no produto sem mudar o estoque em si, mas o estoque puxando a mudança que vai no produto. Essa é a lógica, né, de ter essa. Então o produto tem que ter uma planilha de produto, do estoque tem que puxar e falar: me faz a lista de todos os itens que estão aqui dentro, registrar numa planilha desses produtos onde tem a marca, o modelo, fornecedor, Lá o fornecedor também é um ID, porque tem a lista dos fornecedores, vai puxar da tabela dos fornecedores. Bom, mas isso aqui, ok. Então, isso é uma parêntese, mas que eu acho importante. Acho que sempre, compreendendo o database, tem que fazer isso. Essa planilha de produto, a planilha de produto, o estoque é uma planilha que é dependente da planilha de produto em termos do elenco dos itens. E depois tem a necessidade, que é project, esse é o projeto de itens, é a necessidade que nós temos de fornecer, que se deverá relacionar com estoque em relação à necessidade efetiva depois de compra, que será uma outra planilha. É isso que precisamos fazer, a planilha agora dos itens necessários para ser comprados em virtude do Q-BEN, do projetos itens.

**[47:10] Kimberly Prestes:** Pedro, deixa eu só, ó, aqui então em produtos tem estoque total, daí remove e o estoque showroom e já tem a planilha estoque itens, só que tem uma discrepância de 3, 2 mil e poucos produtos diferentes entre as duas clínicas. Aí mesmo que seja zero, ele, aí eu não sei, né, se for zero ele não aparece no estoque.

**[47:49] LAGHI Live:** Acho que sim, né? É, eu penso isso. Aqui em produtos a gente tem todos os produtos que já foram cadastrados, até mesmo os que não trabalhamos mais. E estoque a gente tem tudo que tem que tá dentro do estoque.

**[48:05] Filippo Giorgi:** Tem a planilha produtos? Tem a planilha produtos?

**[48:09] Kimberly Prestes:** Tem, tem.

**[48:10] Filippo Giorgi:** Ah, desculpa, desculpa. Não, tem já, isso.

**[48:14] Kimberly Prestes:** E esse estoque dá para cortar então o estoque total, o estoque showroom e disponível.

**[48:21] LAGHI Live:** É isso que a gente vai fazer, a gente vai pegar essa planilha produtos e dividir ela para fazer com que a gente consiga ter todas as informações separadas.

**[48:30] Kimberly Prestes:** Mas já tem o estoque itens, né?

**[48:32] LAGHI Live:** Tem o estoque itens, mas não tem, vamos supor, showroom. Não tem.

**[48:38] Filippo Giorgi:** É o menos importante para trabalhar.

**[48:42] Kimberly Prestes:** Ah, tem, aparece o showroom local.

**[48:44] LAGHI Live:** É, mas aí tem que ver também, porque além de, eu sei que em produtos tem estoque disponível e estoque total.

**[49:07] Kimberly Prestes:** Tem a quantidade só. Ah, tá.

**[49:09] LAGHI Live:** É, é a quantidade e o estoque disponível. Tem que, para a gente ver a quantidade disponível Para venda a gente tem que fazer o estoque total menos o disponível.

**[49:25] Kimberly Prestes:** Sim.

**[49:28] LAGHI Live:** Que aí a gente consegue basear com quantos tem vendidos em estoque, entendeu?

**[49:34] Kimberly Prestes:** Uhum. Vai ter que passar então produtos, essas 3 colunas para cá é de stock items. Para poder ficar tudo separado, certo? É isso, né?

**[49:48] LAGHI Live:** Eu acho que no final das contas é isso, é passar o estoque total.

**[49:54] Kimberly Prestes:** Mas aí um ponto, que isso daí é mais tranquilo, né? Um ponto é se dentro de estoque vai ficar só o que realmente tem estoque, aí precisa pensar o que que vai acontecer quando um projeto estiver produtos a ser descontado do estoque, sendo que a gente vai estar dentro da tabela.

**[50:18] LAGHI Live:** Daí vai ter que criar um move.

**[50:21] Kimberly Prestes:** O que que vai acontecer quando o projeto dos itens, né, que é o orçamento fechado, tiver produtos que não tiver dentro do estoque ou dentro aqui do, dentro da tabela?

**[50:33] LAGHI Live:** Então aí justamente aparece aquilo que o Filipe tinha falado, que é É uma nova planilha de pedido de compra, alguma coisa assim?

**[50:45] Kimberly Prestes:** Sim, tá. Então, mas essa outra planilha de solicitação, né, ou de recompra de estoque já realizado ou de novo produto.

**[51:00] LAGHI Live:** Tá, e daí você tá mutado, Felipe.

**[51:08] Kimberly Prestes:** Tá muito bom.

**[51:12] Filippo Giorgi:** Sim, ok. Então isso é a parte do estoque e depois tá a parte financeira. Mas agora, como aliás daqui a pouco eu até preciso sair daqui a pouco, mas um pouco do nosso tempo, tá, mais um pouco até a nível geral De como, porque, de como dar continuidade em relação a o que podemos usar, por exemplo, eu usei bastante como assistente, um assistente que eu me criei assim banal, mas só para focar no Super Bezo, lá dentro da plataforma do Workspace, e deu bastante certo, vamos trabalhar Gitem, entendeu? Porque ele pode entrar, conferir, é isso mesmo? Eu não sei as coisas que às vezes falo, que não sou um experto, tô aprendendo, trabalhando com vocês, trabalhando. Então é um pouco a nível geral agora para conseguir implementar tudo isso. É certo isso partir do Super Base ou tentar fazer pois que ele imposta o Super Base, ou estamos no caminho certo, estamos, vamos fazendo as planilhas assim. É mais um pouco também ser orientados em geral sobre o trabalho.

**[52:41] Kimberly Prestes:** Sim, eu acho que essas modificações vai, eu acharia mais seguro se fazer direto pelo VS Code. Não, pelo VS Code. Você lembra que eu te mostrei? Vou abrir a pasta de vocês.

**[53:00] LAGHI Live:** É que eu peguei, eu tô usando ela de referência.

**[53:05] Filippo Giorgi:** O que é o VS Code?

**[53:07] LAGHI Live:** É como se fosse o script Python, é uma plataforma que você consegue mexer em código.

**[53:17] Kimberly Prestes:** Todos os sistemas que você for for criar, já clona dentro dessa pasta ali, né, da Luceneira, ali dentro do VS Code. Porque isso é muito bom para você usar como contexto para ele refinar e melhorar ali o Supabase de vocês. Então sempre, por exemplo, quando preciso fazer algo para vocês, eu abro lá meu antigo e já tem todo o clone do sistema de vocês e tem as credenciais do Superbase. Então qualquer coisa, e tem todas as transcrições das nossas reuniões. Então sempre quando eu mando uma coisa lá, ele já sabe o que que eu falei, o que que eu não falei, né, o que vocês pediram, qual é a necessidade. E ele meio que vai estruturando dessa maneira, né, que ele gera o SQL para fazer as migrações. É melhor do que fazer direto pelo Skip. E daí pelo Skip você pode pedir para ele também gerar os prompts para você mandar lá certinho. Então manda muito bem detalhado, porque qualquer coisa que, como, né, o banco de dados já tá criado, qualquer coisa que não colocar ali uma letra, ele pode— nossa, ele mandou eu colocar Isso. Então ele pode acabar criando alguma coisa que não era para criar, entendeu? Então, e sempre colocar, né, não crie nada no banco de dados, apenas conecte o sistema com ele, com essas tabelas já existentes. É confiável, pois está mensagem já grande, confiável, porque daí a gente já coloca ali o guarda-rei da IA para ela, né, de alucinação. Então usa bastante isso, tá? Mas é essa linha de raciocínio mesmo. Pega orçamentos, orçamento tem que colocar um FK para conectar com projeto, e daí esse projeto, quando tem um orçamento OK, gera projeto, os itens. Quando cair um projeto, os itens conectar com a tabela de estoque e aí dividir projeto, produtos e estoques para poder funcionar.

**[55:42] LAGHI Live:** E aí falta aquele pedido de quando não tem estoque, tem que ter o pedido, né?

**[55:49] Kimberly Prestes:** Mas essa tabela, exatamente, que daí ela também tá conectado com o FK, o o FK de projetos, itens, e com o projetos, itens e produtos, né? Porque quando não tiver o produto, já vai ser registrado.

**[56:11] LAGHI Live:** Que no caso, o estoque que a gente vai mudar, que a nomenclatura tá com produto, mas vai virar o estoque.

**[56:17] Kimberly Prestes:** Não, quando não tem o item, ele não vai para estoque, ele vai para essa outra tabela que é de solicitação. OK, ele não tem o cadastro, ou se ele não tiver o cadastro, né, se ele não tiver o cadastro daquele produto, aí Projeto Itens tem que conectar com essa tabela de, ou com a tabela de produtos, para poder criar um novo, entendeu?

**[56:41] LAGHI Live:** Sim, sim, eu entendi. Agora eu entendi.

**[56:45] Kimberly Prestes:** Na verdade não vai ser Projeto, vai ser Orçamentos. Orçamentos tem que ter a capacidade de criar produtos dentro do orçamento.

**[56:55] Filippo Giorgi:** Sim, tem que ser até a possibilidade de registrar um novo produto. É o grande problema, que é produtos, que não é o estoque.

**[57:07] Kimberly Prestes:** É seguir na mesma lógica do de criar um projeto ou criar um, né, um cliente. O produto vai seguir na mesma lógica, dá para fazer direto pelo Skip, tá? Então Quando não tiver um produto listado, é um botão ali, criar produto, e daí a pessoa registra todos, coloca, né, obrigatório ali as coisas, e aí ele já registra na tabela de produtos para ter o ID.

**[57:35] LAGHI Live:** É, o que me pega um pouco é que quem determina o valor de venda e imposto, essas coisas, é o Vinícius. Então essa, o Ursa, teoricamente essa parte tem que passar por ele.

**[57:54] Filippo Giorgi:** Não, com certeza, essa parte da cena tem que fazer absolutamente. Eu estou aqui em parte também, conferir bem com ele que estejam todas as planilhas certas. Tem que fazer com ele, essa parte é puramente com ele.

**[58:10] Kimberly Prestes:** Mas não, mas porque ele precisa registrar isso, né?

**[58:13] LAGHI Live:** Isso.

**[58:14] Kimberly Prestes:** Mas cria uma aba dentro do sistema dele, do financeiro, uma aba que é aprovado, né, ele registro de pendência de registro de produtos. E aí quando gera esse orçamento fica ali só para pessoa. Só um momentinho.

**[58:34] Filippo Giorgi:** Ah, mas você está falando que registrar um produto tem que passar por Vinícius, é isso?

**[58:39] LAGHI Live:** Porque vamos supor, vamos pensando aqui as meninas estão fazendo orçamento e aí surgiu uma peça nova. Elas não podem colocar qual que é o preço de venda porque elas não estipulam preço de venda. O Vinícius—

**[58:53] Filippo Giorgi:** Mas elas devem poder registrar o item, depois o preço de venda, o preço a gente tem que colocar. Não, espera, o preço de venda elas vão ter que consultar O Vinícius, isso sim. Às vezes não tem uma tabela, mas não, muitas vezes tem uma tabela. O interno de uma empresa que tem já uma tabela e que te pode dar automaticamente o preço de venda. Pelo contrário, sabe que quando você registra, preço de venda deve vir possivelmente das regras da marca, que é aquilo, aquelas coisas registradas.

**[59:35] LAGHI Live:** Que o Vinícius tem pronta lá.

**[59:37] Filippo Giorgi:** Exato, que é uma planilha que deve estar dentro do Super Base, obviamente.

**[59:41] LAGHI Live:** Sim, que essa planilha vai fazer, vai fazer com que determine. Aí a única coisa que realmente a gente vai ter que ver é a relação relacionada a imposto. Aí tem que ver em qual empresa tá para determinar o preço do imposto em cima daquela peça. Isso provavelmente, o que que eu pensei foi o que a Kimberly falou também. Eu acho que o certo seria justamente a gente pegar e criar uma parte só da administração. Quando entra uma peça nova, fica pendente lá para o Vinícius ou para Lana, e um dos dois vai lá e aprova e coloca o preço de imposto, e o preço da venda já vem automático daquela planilha.

**[01:00:36] Filippo Giorgi:** Sim, mas se tem condições pelas regras, se não tem irregular, coisas que ele já entrar, porque senão atrapalha muito. Te falo que todo dia pode ter um produto novo que está no orçamento, então todo dia, 2 dias, dependendo do outro, quase depende do outro, é. Então, se tem, como a maioria dos casos a regra já está estabelecida pelo tipo de produtos e coisa, e pode vir automática só de registrar o produto lá, então deve ter essa possibilidade. Lá onde não tem regra suficiente para determinar o preço do produto, se cria esse alarme.

**[01:01:19] Kimberly Prestes:** Pode ser uma regra não impeditiva, Pedro, que pode ir para eles registrarem o imposto e valores, só que não travar o orçamento, mas vai para ele.

**[01:01:33] Filippo Giorgi:** Na questão de imposto, são coisas específicas. Na verdade, o que acontece com o Titânio, porque acontece no dia a dia de elas fazer orçamento, onde fazem, recebem código 999 provisório que é um código especial, é que coloca um preço, coloca um preço de venda, porque elas têm uma tabela de transformação, ah, é dessa marca, então eu ponho aqui. Então nós vamos facilitar muito a vida deles, porque vamos criar automaticamente que as regras da marca vão já estabelecer o custo. Então não deve nem ir procurar, estamos dando mais confiabilidade ao nosso orçamento, o valor que é colocado, por respeito ao que hoje estamos fazendo. Então está ótimo assim poder puxar as regras, que 90% das vezes dá certo. E aí, em alguns casos, tem pessoas que saem, vendeu para os estados, tem umas questões que pode dar uma trava se não tem as regras dentro do database, onde ele vai achar, né, para automaticamente colocar já o preço, tá.

**[01:02:38] Kimberly Prestes:** Sim, tem que a parte dos instrumentos, inclusive ela, deixa eu ver aqui, questões, tem que pensar questões de negociação, por exemplo, ah, deu desconto, não sei como, se vocês têm alguma tratativa, porque precisa ver o quanto, né, 'Foi abaixado de tal valor', senão vai ficar o valor fixo. Agora, se teve alguma negociação por fora e deu desconto, vai para a tabela de projetos como se fosse aquele valor e, consequentemente, vai para parcelas. Então, precisa pensar nisso das negociações.

**[01:03:29] LAGHI Live:** Então, olha aqui, e dentro de orçamento eu já fiz isso, tem já o desconto global e ele é a porcentagem de tudo, ele não vai ser por peça. Então, mas isso aí a gente tem que pensar também como que vai fazer, se é uma regra ou valor da peça de venda, porque isso vai determinar todos os valores, vai mudar tudo. Valor de todas as peças, que é 20% de desconto para esse cliente em específico. E aí todas as peças que vão para itens, projeto item, tem que estar com o valor já com desconto.

**[01:04:15] Kimberly Prestes:** É bom para depois, né, para análise financeira, é bom para saber realmente qual quanto foi o lucro dividido por peça ou por projeto, não apenas globalmente, né?

**[01:04:30] Filippo Giorgi:** Exatamente, cada peça, que lucro teve realmente no final.

**[01:04:35] Kimberly Prestes:** Se não mudar, aí vai parecer que se ele for, ah, quanto que teve o lucro, ele vai aparecer que o lucro foi tanto, mas por causa do desconto foi menos, então Então, certo seria a gente criar em projeto itens uma nova coluna que fale o valor real da venda com desconto? Sim, ou até mesmo em orçamento, né? Em orçamento, não, mas o desconto é só quando vai aprovar.

**[01:05:10] LAGHI Live:** Vem no orçamento.

**[01:05:13] Kimberly Prestes:** Mas quando vai aprovar, por exemplo, falou: ah, esse é o desconto, então vamos aprovar. Ou, por exemplo, ah, eu tenho esse desconto, daí vai aprovar, entendeu?

**[01:05:26] LAGHI Live:** Na realidade, às vezes o cliente já conversa, vamos supor, isso o Filipe vai poder falar melhor, mas eu acho que o cliente chega e fala: ó, vou passar no Pix, quanto que faz?

**[01:05:37] Kimberly Prestes:** Então é em projetos e itens. Para saber o valor final.

**[01:05:44] LAGHI Live:** Mas isso tem que aparecer no orçamento para o cliente.

**[01:05:50] Filippo Giorgi:** Eles estão falando do desconto?

**[01:05:52] Kimberly Prestes:** Isso.

**[01:05:53] Filippo Giorgi:** A questão é bem simples, a gente dá um desconto e coloca essa porcentagem final e pronto. Não é— podemos padronizar, podemos padronizar, mas na verdade no final tem liberdade de dar o desconto final.

**[01:06:10] Kimberly Prestes:** Acho que é melhor deixar em orçamento, porque daí os itens vai ficar ali.

**[01:06:15] Filippo Giorgi:** Sim, sim, dentro de orçamento já, desconto tal, e calcula já como faz hoje. É igual o orçamento de hoje, né, Pedro? Então tem o valor final, depois temos o desconto, e valor final com desconto. E esse desconto, logicamente, é ótimo que se espalha em todos os itens, Porque essa ideia é até interessante para mim às vezes fazer ver, olha, essa peça a gente tá pagando tanto, não tanto, né, porque tem um desconto. Então, assim, como já está sendo, se não me engano, né, tem uma coisa que eles colocam desconto, é desse jeito, na hora do orçamento coloca o desconto. Mas isso está bom.

**[01:06:59] Kimberly Prestes:** Como tem orçamento desconto global aqui, em orçamento os itens, ao invés de ter o desconto em número para depois para fazer carry para poder analisar, puxa o valor, valor de venda ou valor final, ao invés de ter desconto, entendeu? Porque o desconto já tá lá. E daí só fazer, por exemplo, se tiver o desconto, sai o quanto foi vendido. Se não tiver, só replica o valor do preço unitário. Tá, o preço unitário não, né, da multiplicação da quantidade versus o preço unitário, ao invés de desconto.

**[01:07:48] LAGHI Live:** Isso em desconto itens, isso em produto, projeto itens.

**[01:07:53] Kimberly Prestes:** Não, orçamento itens. Isso, orçamento itens, porque daí projetos itens vai certinho para lá, entendeu?

**[01:08:03] LAGHI Live:** Então criar uma nova coluna aqui que não tem, né, relacionada.

**[01:08:08] Kimberly Prestes:** É, você pode trocar, na verdade, ao invés de desconto, você vai remover essa coluna de descontos, orçamentos itens. E ter o valor total, porque o desconto ele já tá aqui, que é o desconto global. Aí é só ter o automatizar, que quando ele tiver em orçamentos, cadê o orçamentos, quando tiver o desconto global vai ser, né, dividido em todos os itens. E aí Vai, daí ele arruma ali o cálculo, né, que daí seria a quantidade vezes o preço unitário.

**[01:08:54] LAGHI Live:** Então teria que ser o preço final, né, do preço unitário. Eu acho que com base aqui tem o desconto, não entendo isso, porque Não tem nada disso para manter o padrão do sistema, porque isso pode dar uma diferenciação no final das contas.

**[01:09:20] Filippo Giorgi:** Mas pera aí, pera aí, temos a questão é uma, o desconto é vendo preço final e beleza, isso está fácil. Depois tem a questão dos itens ser com preço registrado com preço de venda final mesmo, né? É isso?

**[01:09:34] LAGHI Live:** É isso.

**[01:09:35] Filippo Giorgi:** Porque isso depois, é isso que eu quero entender dele.

**[01:09:40] Kimberly Prestes:** Ele puxa projetos e o financeiro teoricamente vai sair de projetos.

**[01:09:45] Filippo Giorgi:** Ah não, espera, tem uma planilha que não é projetos itens, que é tudo vendido, né? Projetos itens é tudo que é vendido, né?

**[01:09:59] Kimberly Prestes:** É.

**[01:09:59] Filippo Giorgi:** Então, ele aprovou. Então lá em Projectos, Itens, tem o item vendido e toda vez é registrado com o valor de venda final.

**[01:10:18] Kimberly Prestes:** É porque o orçamento precisa estar com o preço unitário, é, precisa estar com desconto. Então vai ter que alterar ali.

**[01:10:29] Filippo Giorgi:** O orçamento está com desconto final, não está com discriminado atualmente. Vocês têm que olhar o atual nosso orçamento que vai na mão do cliente. É isso que é importante que tenha. E ter o preço dos itens unitário e no final tem um desconto final. Então olha, no final tem, em cima de tudo isso, tem o desconto. Não precisa visualizar o preço efetivamente depois feito pelo desconto no item. Esta é uma informação que nós precisamos ter. Então, no orçamento está resolvido. Então, em orçamento essa informação não precisa ser visualizada na planilha, seria redundância. Onde que é registrado? Em Project Items vai efetivamente um item vendido, Tout à fait, c'est qu'ici, je pense que c'est encore une fois qu'il va se réfléchir dans sa planille, j'imagine. Il va être enregistré comme une vente et c'est le montant final, effectivement, avec le profit et tout, sur cet item. C'est là qu'il est enregistré et c'est là qu'on pioche les informations à l'heure de savoir la prestation final de cada venda de produto, de cada produto por venda. Entendeu? Então é mais simples. Agora, para garantir os itens tem que ter realmente toda uma série de informações. Tipo, não, porque cada vez tem uma linha, me parece que funciona assim mesmo, que tem uma linha que registra o vendido e lá então tem que ter De qual venda, então, de qual venda já amarra cliente, projeto, etc. Então pronto, tem que ter as informações certas para somar só essas duas planilhas, né?

**[01:12:30] Kimberly Prestes:** Tá, então projeto, os itens, coloca o valor total. Uma coisa que tem que conectar com Tem que cruzar em algum momento o projeto sinal, porque o orçamento vem o sinal quando ele fechou, né, o projeto.

**[01:13:05] Filippo Giorgi:** No valor total, sim, da venda dos itens, mas tem que ter o valor unitário, uma, talvez uma coluna com valor unitário, sim.

**[01:13:13] Kimberly Prestes:** É que daí já puxa pelo item.

**[01:13:16] Filippo Giorgi:** Em projetos, itens, sim, tem que ter o valor unitário com que foi vendido aquele item.

**[01:13:22] LAGHI Live:** É, aqui já tem, tá estruturado, né, desse jeito: quantidade, preço unitário e desconto da peça.

**[01:13:31] Filippo Giorgi:** Ah, entendi. Eu acho que pode ficar ali. Esse desconto puxa, é o desconto mesmo que está lá, né, que foi dado.

**[01:13:47] LAGHI Live:** Que é a questão de percentagem em cima da peça.

**[01:13:50] Filippo Giorgi:** Esse desconto de onde eu pego? Eu pego, é confiável de pegar do desconto que está escrito no orçamento. Ele coloca aquele desconto em todos os itens do orçamento e sai depois o valor efetivo.

**[01:14:09] LAGHI Live:** Eu acho que é isso, que aí eu vai ter o preço unitário.

**[01:14:16] Kimberly Prestes:** Sim, porque daí tem o desconto, é exatamente quem tá falando. Deixa o desconto aqui certinho e depois só o dentro de orçamentos, né? Porque tem dois descontos, porque tem da tabela orçamentos, tem desconto global do orçamento itens, tem outro desconto. Você pode colocar o valor real de qual é o valor que ele seguiu para não ficar Porque, por exemplo, 8 é por cento, 8%.

**[01:14:53] LAGHI Live:** É porcentagem o desconto, porcentagem. Isso, então seria 8% do valor total da venda. Isso tem que ser diluído entre as peças para a gente ter uma noção de quanto foi vendido cada peça.

**[01:15:10] Kimberly Prestes:** Sim, então coloca, mas só que precisa ir para tudo. É justamente isso que eu tava pensando, porque daí projetos item já vai certinho e não resolve isso lá, né, no caso.

**[01:15:45] LAGHI Live:** Já tá, já tá pré-determinado isso aqui dentro. No orçamento tem o desconto global, no orçamento itens tem o desconto por peça, e aí projeto item tem o preço unitário e o desconto. Então já segue essa lógica.

**[01:16:09] Kimberly Prestes:** Acho que fechou tudo, né? Acho que é nessa aí.

**[01:16:15] LAGHI Live:** Tem mais alguma dúvida, Felipe?

**[01:16:17] Filippo Giorgi:** Perfeito. Não, não, vamos lá, vamos, vamos, vamos, vamos, vamos, trabalho, né, Pedro? É isso.

**[01:16:26] Kimberly Prestes:** Obrigado. Só uma coisinha, vejam aquela questão que eu mandei no grupo, não sei se chegou a ver, Felipe. É, eu fiz ontem com cliente, eu não sabia que dava para fazer isso, mas o AutoCAD ele tem como colocar plugins que automatiza tarefas. E é, eu fiz assim 10 minutos coisas que ele demora por dia. Eu mandei até o videozinho que eu fiz lá na reunião com ele, olha lá no grupo depois. Daí a Mariana falou que vocês não tem nenhum plugin. Então tem várias coisas, por exemplo, pegar uma base, uma biblioteca de todos os produtos de vocês, e aí ele já conta, já marcar ali, criar legenda, fazer a parte, dá para fazer muita coisa.

**[01:17:14] Filippo Giorgi:** Muito bom, muito bom, obrigado. Vou ver, a gente vai entrar em contato.

**[01:17:18] Kimberly Prestes:** Já lembrei, o Filipe, aí eu mandei hoje para ele.

**[01:17:21] Filippo Giorgi:** Obrigado.

**[01:17:23] Kimberly Prestes:** Tá bom, gente.

**[01:17:25] Filippo Giorgi:** Obrigadão então.

**[01:17:27] Kimberly Prestes:** Tchau, tchau, tchau! Boa semana aí para vocês, e daí a gente vai conversando.

**[01:17:32] Filippo Giorgi:** Você também.

**[01:17:32] Kimberly Prestes:** Tchau, tchau, tchau!

