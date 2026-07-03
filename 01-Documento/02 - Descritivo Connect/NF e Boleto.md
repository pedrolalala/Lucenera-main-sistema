### **Objetivo do Processo**

Emitir a Nota Fiscal eletrônica da venda aprovada, gerar os boletos bancários para pagamento do cliente e criar o arquivo de "Remessa" que informa ao banco que aqueles boletos existem e podem ser pagos.

---

### **Passo 1: Emissão da Nota Fiscal (NF)**

1. **Acesse a Tela Fiscal:** No menu lateral do sistema, vá em **Comercial > Fiscal > Nota Fiscal Eletrônica (NF-e)**.
2. **Localize a Venda:** As vendas recém-aprovadas aparecerão nesta lista. No vídeo, a usuária seleciona a venda da cliente **Manoella** (Número da Venda: 5072).
3. **Conferência Rápida:** Dê um duplo clique para abrir a venda. Antes de gerar a NF, dê uma olhada rápida na aba "Transportador / Pagamento" para conferir se as datas de vencimento e os valores estão corretos (ex: boletos para dia 23/07, 23/08).
4. **Gerar, Assinar e Enviar:** Na parte superior da tela, siga a sequência de botões:
* Clique em **"Gerar"**.
* Depois clique em **"Assinar"**.
* E por fim, clique em **"Enviar"**.


5. **Salve o PDF da Nota (DANFE):** Se não houver nenhum erro de imposto, o sistema abrirá o PDF da Nota Fiscal na tela.
* Clique em Imprimir e escolha **"Microsoft Print to PDF"** (Salvar como PDF).
* **Regra de Organização:** Salve na pasta específica do cliente (Ex: `ADM > NF Emitidas Manoella 2026`). Nomeie o arquivo com o número da NF para facilitar, por exemplo: `NF 4740`. O sistema segue uma ordem sequencial (a próxima será a 4741).



---

### **Passo 2: Geração dos Boletos**

1. **Aceite a Sugestão do Sistema:** Assim que você fechar a tela da Nota Fiscal, o sistema perguntará automaticamente: *"Deseja imprimir Boletos?"*. Clique em **"Yes" (Sim)**.
2. **Gere os Boletos:** A tela de impressão de boletos vai abrir com as parcelas da cliente. Selecione os boletos e clique no botão superior **"Gerar Boleto"**.
3. **Salve o PDF do Boleto:** O PDF com o layout do banco (Bradesco, no caso do vídeo) vai aparecer na tela. Salve este arquivo em PDF no seu computador, pois ele precisará ser enviado ao cliente junto com a Nota Fiscal (geralmente por WhatsApp ou E-mail).
* **ATENÇÃO:** O sistema tem um botão chamado **"Remessa"** nesta tela. **NÃO CLIQUE NELE AGORA**. Como a empresa gera dezenas de boletos por dia, a remessa é feita toda de uma vez no final do expediente, para não mandar 50 arquivos separados para o banco.



---

### **Passo 3: Geração do Arquivo de Remessa (Rotina de Fim de Dia)**

No final do dia, você precisa avisar o banco sobre todos os boletos que foram gerados.

1. **Acesse a Tela de Boletos:** Vá em **Financeiro > Boletos > Imprimir Boletos**.
2. **Filtre os Boletos do Dia:** Coloque a data do dia atual nos campos de filtro e selecione o tipo "Venda". O sistema vai listar todos os boletos gerados naquele dia.
3. **Gere a Remessa:** Selecione todos os boletos da lista e clique no botão **"Remessa"** na parte superior.
4. **Localize o Arquivo:** O sistema vai gerar um arquivo de texto (com extensão `.rmt` ou similar) e salvará automaticamente em uma pasta do sistema (Ex: `Financeiro > Remessa`).

---

### **Passo 4: Entendendo as Regras de Negócio Cruciais**

* **A Regra de Ouro da Remessa:** O arquivo de remessa gerado no Passo 3 **precisa obrigatoriamente ser enviado/subido no sistema do banco**. Se você mandar o PDF do boleto para o cliente, mas esquecer de mandar a Remessa para o banco, quando o cliente tentar pagar, vai dar erro de **"Boleto não registrado"**. O banco precisa desse arquivo para "autorizar" o código de barras.
* **O Arquivo de Retorno:** No dia seguinte após você enviar a Remessa, o banco gera um arquivo de "Retorno". Esse arquivo faz o processo inverso: ele entra no sistema da Lucenera e dá "baixa" (marca como pago) automaticamente em todos os boletos que os clientes pagaram no dia anterior.
* **Comissão de Arquitetos (RT - Reserva Técnica):**
* No vídeo, a venda da Manoella não tinha arquiteto vinculado, então nenhuma comissão foi gerada.
* **Regra de Exceção:** Mesmo que houvesse um arquiteto na venda, itens técnicos e insumos como **Fita de LED** e **Fontes** não geram comissão (RT). A comissão só é paga sobre peças decorativas e luminárias específicas. Por isso, neste pedido específico, o valor da comissão seria zero de qualquer forma.