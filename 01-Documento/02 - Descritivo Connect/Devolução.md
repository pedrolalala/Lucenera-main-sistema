### **Objetivo do Processo**

Registrar corretamente a devolução parcial ou total de produtos por parte do cliente. O grande desafio aqui é que o sistema possui uma **regra de programação rigorosa** (uma hierarquia) para decidir de qual "status" ele vai subtrair o item devolvido.

---

### **Regra Inicial e Intocável**

* **A Coluna "Q. Venda" (Quantidade Vendida) NUNCA MUDA.** Se o cliente comprou 40 peças originais, esse número ficará registrado como 40 para sempre, mesmo que ele devolva tudo. O que muda são os status das outras colunas.
* A quantidade que o cliente desistiu/devolveu sempre aparecerá na coluna **Q. Dev. (Quantidade Devolvida)**.

---

### **A Regra de Ouro: A Hierarquia de Subtração**

Quando você registra uma devolução, o sistema precisa "tirar" esse produto de alguma coluna de status. Ele faz isso seguindo uma ordem estrita e obrigatória:

1. **1º LUGAR: E. Futura (Entrega Futura)**
* *O que é:* O produto ainda nem chegou da fábrica.
* *Por que é o primeiro?* Se o cliente desistiu de algo que nem temos no estoque ainda, o sistema apenas reduz a nossa obrigação de comprar esse item do fornecedor. É um processo virtual (não envolve caixas físicas voltando).


2. **2º LUGAR: Reserva**
* *O que é:* O produto está no nosso estoque, guardado para este cliente.
* *Por que é o segundo?* O produto fisicamente já está com a empresa. O sistema apenas "tira o nome" do cliente da caixa e o produto volta a ficar disponível para venda para outra pessoa.


3. **3º LUGAR: Entregue**
* *O que é:* O produto já estava na casa/obra do cliente.
* *Por que é o último?* Aqui ocorre a devolução física real. O produto saiu da empresa e teve que ser transportado de volta para dar entrada física no galpão.



---

### **Exemplos Práticos (Como o sistema pensa)**

Imagine o pior cenário possível: Uma venda de **40 peças**, que estão divididas e "espalhadas" no sistema da seguinte forma:

* **10** em *E. Futura*
* **10** em *Reserva*
* **20** em *Entregue*

#### **Situação A: O cliente quer devolver apenas 5 peças**

O sistema vai olhar para a Hierarquia. O primeiro da fila é o *E. Futura* (que tem 10 peças).

* Ele subtrai 5 do *E. Futura*.
* **Resultado:** O *E. Futura* cai para 5. A coluna *Q. Dev.* passa a marcar 5.

#### **Situação B: O cliente quer devolver 20 peças**

O sistema olha para a Hierarquia. Ele precisa de 20 peças para devolver, mas o primeiro da fila (*E. Futura*) só tem 10. Ele "zera" o *E. Futura* e pega o resto (mais 10) do próximo da fila, a *Reserva*.

* **Resultado:** *E. Futura* cai para 0. A *Reserva* cai para 0. A coluna *Q. Dev.* passa a marcar 20. A coluna *Entregue* continua intacta com 20.

---

### **A Limitação do Sistema (Como Lançar Corretamente)**

Como o sistema segue essa hierarquia rígida, **você não pode lançar o número da devolução de uma vez só se ele envolver mais de uma coluna**. Se você tentar devolver 20 peças digitando "20" em uma única linha, o sistema vai bugar, pois vai tentar tirar 20 peças do *E. Futura*, que só tem 10.

**O que você deve fazer (O Truque das Linhas):**
Você precisa criar linhas separadas de devolução, respeitando a quantidade máxima de cada coluna. Usando o cenário de 40 peças (10 em E. Futura, 10 em Reserva, 20 Entregue):

* **Se for devolver 20 peças:**
* Lance a **Linha 1** com devolução de **10**. (O sistema entende: "Vou zerar o E. Futura").
* Insira o produto de novo e lance a **Linha 2** com devolução de mais **10**. (O sistema entende: "Vou zerar a Reserva").


* **Se for devolver a Venda Total (40 peças):**
* **Linha 1:** Devolução de **10** (Zera E. Futura)
* **Linha 2:** Devolução de **10** (Zera Reserva)
* **Linha 3:** Devolução de **20** (Zera Entregue)



**Resumo:** O sistema é lógico, mas precisa que você "mastigue" a informação para ele criando várias linhas de devolução sempre que a quantidade a ser devolvida for maior do que o saldo disponível na primeira coluna da hierarquia.