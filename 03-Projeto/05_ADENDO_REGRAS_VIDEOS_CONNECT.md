# Adendo — Regras operacionais extraídas dos Videos Connect

Data da análise: 24 de junho de 2026

## Objetivo

Este adendo complementa a versão final com regras observadas nos arquivos `.md` da pasta `Videos Connect`. Esses arquivos mostram como alguns processos ainda funcionam no Connect hoje e revelam regras que precisam ser preservadas na transição para o novo ecossistema.

Importante: os vídeos mostram o processo manual atual. O novo sistema não deve repetir todos os cliques do Connect. A intenção é preservar a regra de negócio e automatizar o que puder ser calculado com segurança a partir de dados estruturados.

Arquivos analisados:

- `Videos Connect/Orçamentos.md`
- `Videos Connect/NF e Boleto.md`
- `Videos Connect/Venda.md`
- `Videos Connect/Devolução.md`

## 1. Orçamento aprovado não é apenas mudança de status

No processo atual, o orçamento passa por conferências antes de virar pedido operacional. O usuário confere produtos, valores, descontos, frete, condição de pagamento e vencimentos. Depois disso, o orçamento é fechado/travado e segue para aprovação financeira.

Regras identificadas:

- item especial ou item sem preço, com valor zero, bloqueia o avanço;
- a condição de frete precisa estar definida como “com frete”, “sem frete” ou regra equivalente antes do faturamento;
- ao fechar/aprovar, o orçamento não deve mais ser editável pela equipe comercial sem uma reabertura ou nova versão;
- parcelas e vencimentos não devem ser criados por suposição solta; quando forma de pagamento e prazo estiverem estruturados no orçamento, o sistema deve calcular os vencimentos automaticamente e deixar o Financeiro validar;
- a aprovação gera um documento de separação para o estoque/logística.

**Impacto nos documentos finais:** a SPEC de aprovação de orçamento foi ajustada para calcular parcelas e vencimentos a partir dos dados do orçamento, bloquear apenas casos sem base suficiente e enviar o resultado para validação do Financeiro.

**Ação a ser realizada:** garantir que o orçamento tenha campos estruturados para frete, forma de pagamento e prazo. A função deve calcular as parcelas; o Financeiro valida, edita exceções quando necessário e libera boleto/remessa.

## 2. NF e boleto possuem uma sequência operacional própria

O processo atual separa emissão de nota, geração do boleto, remessa e retorno bancário. O PDF do boleto não significa que o boleto já está registrado no banco.

Regras identificadas:

- antes de emitir a nota, a pessoa confere valores e datas na área de transportador/pagamento;
- nota fiscal segue a sequência operacional de gerar, assinar e enviar;
- DANFE/PDF da nota é salvo com o número da nota;
- boleto pode ser gerado após a nota, mas a remessa não deve ser disparada individualmente por cada venda;
- remessa é gerada em lote, normalmente ao fim do dia;
- o arquivo de remessa precisa ser enviado ao banco; sem isso, o boleto pode aparecer como não registrado;
- o retorno bancário do dia seguinte é o que permite baixar boletos pagos automaticamente.

**Impacto nos documentos finais:** a SPEC de orçamento/financeiro foi ajustada para manter NF como pendente nesta fase, criar boleto como `pendente_registro` e deixar claro que a remessa é um lote financeiro posterior. Se a regra fiscal exigir NF antes do registro bancário, o boleto pode ficar preparado, mas não deve ir para remessa antes da conferência fiscal.

**Ação a ser realizada:** tratar boleto gerado, remessa enviada, boleto registrado, retorno processado e pagamento baixado como estados diferentes.

## 3. Item vendido possui vida operacional no estoque

O processo de venda no Connect acompanha a quantidade vendida em colunas operacionais. A quantidade vendida original não muda; o que muda é a posição operacional do item.

Regras identificadas:

- `Q. Venda` é a quantidade aprovada/vendida e nunca deve ser alterada por devolução, transferência ou entrega;
- `Reserva` representa estoque físico separado para o cliente;
- `E. Futura` representa item vendido que ainda precisa ser comprado, produzido ou recebido;
- `Ag. Separar` representa quantidade solicitada para separação;
- `Separado` representa quantidade fisicamente separada;
- `Entregue` representa quantidade entregue ao cliente;
- `Q. Dev.` representa quantidade devolvida;
- `Transferido` representa material reservado para um cliente e transferido para outro;
- separação só pode ser solicitada a partir de quantidade em `Reserva`;
- quando compra/produção chega, a quantidade de `E. Futura` pode virar `Reserva` para o cliente correto.

**Impacto nos documentos finais:** o escopo de Estoque/Compras foi atualizado para explicitar esses saldos operacionais por item de projeto.

**Ação a ser realizada:** modelar os saldos operacionais por `projeto_item`, mantendo `q_venda` imutável e calculando saldos por movimento ou por campos controlados reconciliáveis.

## 4. Devolução segue hierarquia obrigatória

No processo atual, a devolução não simplesmente reduz a venda. Ela reduz primeiro o que ainda não saiu fisicamente ou o que ainda não foi comprado.

Hierarquia identificada:

1. reduzir primeiro `E. Futura`;
2. depois reduzir `Reserva`;
3. por último reduzir `Entregue`.

Regra complementar:

- se a devolução atravessar mais de um status, o processo precisa ser dividido por status;
- no novo sistema, essa divisão pode ser automatizada para não depender do usuário criar várias linhas manualmente.

**Impacto nos documentos finais:** o escopo de Estoque/Compras foi ajustado para usar essa hierarquia nas devoluções.

**Ação a ser realizada:** criar comando de devolução que receba a quantidade total e gere automaticamente os movimentos respeitando a ordem `E. Futura → Reserva → Entregue`.

## 5. Transferência entre clientes gera dívida operacional

O Connect permite transferir material reservado de um cliente para outro em caso de urgência. Essa transferência não apaga a obrigação com o cliente original.

Regra identificada:

- ao transferir reserva do cliente A para o cliente B, o cliente A perde reserva, ganha quantidade transferida e volta a ter necessidade futura pela quantidade retirada.

**Impacto nos documentos finais:** o escopo de Estoque/Compras passa a tratar transferência como movimento operacional próprio, não como simples ajuste manual de saldo.

**Ação a ser realizada:** criar operação de transferência vinculada a dois `projeto_itens`: origem e destino. A origem deve receber reposição em `E. Futura` quando perder reserva.

## 6. Comissão/RT não deve ser calculada genericamente

O processo de NF e boleto menciona regra de comissão/RT: se não houver arquiteto vinculado, não há comissão. Mesmo quando há arquiteto, itens técnicos ou insumos não entram na comissão.

Regra identificada:

- itens como fita de LED, fontes e insumos técnicos não devem gerar RT automaticamente;
- RT deve ser tratada somente para peças decorativas ou luminárias elegíveis, conforme regra comercial.

**Impacto nos documentos finais:** essa regra não altera a SPEC atual de orçamento/financeiro, porque a fase agora é aprovar orçamento, criar itens, parcelas e boletos. Ela deve entrar como regra futura se houver módulo de comissão/RT.

**Ação a ser realizada:** não implementar cálculo genérico de comissão/RT nesta etapa. Quando o módulo existir, usar uma flag/categoria de elegibilidade por produto.

## 7. Otimizações recomendadas para o novo fluxo

Os passos manuais do Connect devem virar automações orientadas por dados estruturados. Abaixo estão as otimizações recomendadas a partir dos vídeos:

1. **Vencimentos calculados pelo sistema**
   - Hoje o usuário confere manualmente o prazo.
   - No novo fluxo, o orçamento registra forma de pagamento e prazo.
   - O sistema calcula parcelas e vencimentos.
   - O Financeiro apenas valida ou ajusta exceções.

2. **Frete como campo estruturado**
   - Hoje a pessoa precisa lembrar de marcar “com frete” ou “sem frete”.
   - No novo fluxo, o orçamento deve ter campo obrigatório ou regra derivável de frete.
   - Se estiver ausente, o sistema bloqueia ou destaca a pendência antes do faturamento.

3. **Item especial sem preço com pendência inteligente**
   - Hoje o processo para e alguém pede cadastro/preço para Débora ou Vinícius.
   - No novo fluxo, o sistema deve criar uma pendência clara para o responsável pelo produto/preço, já vinculada ao orçamento e ao item.

4. **Separação sem PDF manual**
   - Hoje o pedido de separação é gerado e enviado para grupo/mensagem.
   - No novo fluxo, a aprovação deve criar uma fila estruturada para Estoque/Compras e Logística, com projeto, itens, quantidades e observações.

5. **Boleto e remessa em esteira financeira**
   - Hoje a pessoa gera boleto e depois faz remessa em lote.
   - No novo fluxo, boletos entram automaticamente em fila de remessa, mas não são enviados individualmente na aprovação.
   - O Financeiro valida o lote e envia a remessa.

6. **Devolução com divisão automática**
   - Hoje a pessoa precisa dividir devolução manualmente quando passa por `E. Futura`, `Reserva` e `Entregue`.
   - No novo fluxo, o usuário informa a quantidade total e o sistema divide os movimentos conforme a hierarquia.

7. **Transferência entre clientes com reposição automática**
   - Hoje a transferência exige cuidado para não perder a obrigação com o cliente original.
   - No novo fluxo, o sistema move a reserva para o cliente destino e automaticamente cria necessidade futura para o cliente origem.

## 8. Conclusão

Os vídeos não mudam a decisão macro de simplificar o ecossistema, mas adicionam regras de negócio importantes para evitar que a substituição do Connect perca controles operacionais.

As principais alterações necessárias são:

- bloquear aprovação com item especial sem preço;
- exigir frete, forma de pagamento e prazo estruturados;
- calcular vencimentos automaticamente quando a regra estiver clara;
- deixar o Financeiro validar e ajustar exceções antes de faturamento/remessa;
- tratar boleto/remessa/retorno como etapas separadas;
- manter NF pendente até emissão real ou futura API;
- criar saldos operacionais de item aprovado;
- preservar `Q. Venda` imutável;
- aplicar hierarquia de devolução;
- tratar transferência entre clientes como operação com reposição.
