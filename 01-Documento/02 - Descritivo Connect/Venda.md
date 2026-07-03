### **Objetivo do Processo**

Acompanhar o "ciclo de vida" de cada item vendido dentro do sistema. Esta tela virtual permite saber exatamente o que já temos em estoque, o que precisa ser comprado, o que já foi separado para entrega e o que, por ventura, precisou ser transferido para outro cliente.

---

### **Passo 1: Acesso e Consulta da Venda**

1. **Caminho no Sistema:** No menu lateral, acesse **Comercial > Vendas > Venda Parcial**.
2. **Busca:** Digite o número da venda e dê *Enter*.
* *Exemplo do vídeo:* Foi usada a venda da cliente **Giovanna Nori**.


3. **Dados Iniciais:** Na tela, você verá os códigos internos, referências e descrições dos produtos. Há também a coluna **Classificação (L)**.
* **Regra Importante:** Essa letra "L" vincula o produto ao projeto do arquiteto. É uma informação fixa e obrigatória.



---

### **Passo 2: Entendendo as Colunas de Status (O Coração do Sistema)**

A tela é dividida em colunas que mostram onde o produto está naquele momento.

* **Q. Venda (Quantidade Vendida):** É o total de peças compradas pelo cliente naquele pedido.
* **Regra de Ouro:** Este número **NUNCA** muda. Independentemente de devoluções, transferências ou trocas, o número registrado na venda original ficará fixo para o histórico da empresa.


* **Reserva:** Mostra a quantidade de produtos que já temos no nosso estoque físico e que estão "guardados" (reservados) exclusivamente para este cliente.
* **E. Futura (Entrega Futura):** Mostra os produtos que vendemos, mas que **não** temos em estoque no momento. É o material que a empresa ainda precisa comprar ou fabricar.
* **Ag. Separar (Aguardando Separação):** Quando a equipe decide que é hora de enviar o material para o cliente, eles digitam aqui a quantidade que a logística deve separar.
* **Separado:** O produto sai da tela de quem pediu e vai para a logística. O **Mateus** (responsável pelo estoque) pega fisicamente o produto, dá "baixa" no sistema, e o número aparece nesta coluna.
* **Entregue:** Quando o material finalmente chega nas mãos do cliente, a equipe atualiza o sistema e o número vem para cá.
* **Q. Dev. (Quantidade Devolvida):** Usada quando o cliente devolve algo. (O processo detalhado desta coluna será explicado em outro momento).
* **Transferido:** Usada quando vendem um material que estava reservado para o cliente, e transfere para outro.

---

### **Passo 3: A Jornada do Produto (Exemplos Práticos)**

Para facilitar, veja como o sistema se comporta em situações reais:

**Cenário A: Temos estoque suficiente**

* O cliente comprou 40 peças. Temos 80 no galpão.
* O sistema joga automaticamente o número **40** para a coluna **Reserva**.

**Cenário B: Não temos estoque suficiente**

* O cliente comprou 40 peças. Temos apenas 10 no galpão.
* O sistema coloca **10** na coluna **Reserva** e joga **30** para a coluna **E. Futura**.
* *Regra:* Assim que a fábrica entregar essas 30 peças para a Lucenera, o sistema vai vinculá-las a este cliente e passá-las automaticamente do "E. Futura" para o "Reserva".

**Cenário C: O Pedido de Separação (O Trabalho do Mateus)**

* Só é possível pedir para separar o que está na coluna **Reserva**.
* A equipe digita a quantidade no campo **Ag. Separar**. Isso gera uma lista para o **Mateus**.
* Quando o Mateus separa o produto, o sistema registra um histórico completo na parte inferior da tela: qual foi a data, a hora, quem solicitou a separação e quem separou o material. O item vai para a coluna **Separado** e, após a logística finalizar o frete, vai para **Entregue**.

---

### **Passo 4: A Regra de "Transferência" (Urgências)**

A coluna **Transferido** serve para resolver problemas de clientes com extrema urgência.

* **Como funciona:** Imagine que a cliente Giovanna tem 40 peças em "Reserva" (garantidas para ela). Porém, outro cliente (Cliente Y) precisa de 10 dessas peças *para hoje* e não pode esperar o prazo de 30 dias do fornecedor.
* **A Ação:** A equipe pode "pegar emprestado" da Giovanna e transferir para o Cliente Y.
* **O que acontece no sistema da Giovanna?** 1. A coluna *Reserva* cai de 40 para 30.
2. A coluna *Transferido* marca 10 (indicando que 10 peças dela foram para outro lugar).
3. A coluna *E. Futura* volta a marcar 10 (indicando que a empresa agora "deve" 10 peças para a Giovanna e precisa repor isso no futuro).
* **Regra Importante:** Você nunca pode transferir um número maior do que a quantidade total da venda.