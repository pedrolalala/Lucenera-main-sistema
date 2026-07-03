# Validacao Cruzada - MIRO, Transcricoes, Banco e Sistemas

> Nota (atualização): a leitura do board Miro usada como base deste documento foi refeita com maior fidelidade no board consolidado "fluxograma Lucenera" (`https://miro.com/app/board/uXjVHEZy9vM=/`) — ver arquivos `01` a `09` e `99`. Os nomes de etapas citados abaixo (ex.: status, gatilhos) continuam válidos como contexto de cruzamento com banco/sistemas; eventuais nomes de caixa do Miro citados aqui podem ter variado ligeiramente em relação ao texto exato confirmado nos arquivos atualizados.

Resposta curta: o mapeamento bate com a operacao descrita nas transcricoes e com o desenho conceitual do banco, mas ainda nao bate 100% com a implementacao atual dos sistemas. Ele representa o fluxo desejado/real de negocio; parte dele ainda esta desconectada, incompleta ou com nomes de status diferentes no Supabase e nos frontends.

## O que bate bem

### Projeto, contrato e cobrancas

O fluxo `entrada de projeto -> briefing -> contrato/sinal -> DocuSign -> cobrancas -> pre-executivo -> executivo -> obra` bate com os objetos recuperados do MIRO e com os status reais vistos no CRM/documentos (`Proposta Sinal`, `Elaboracao Orcamento`, `Projeto executivo`, `Entrega materiais`, `Ajustes finais`, `Finalizado`).

O banco tambem tem gatilhos que refletem essa intencao:

- Ao mudar para `Proposta Sinal`, o trigger `trigger_reserva_estoque` reserva itens em `estoque_itens` com local `Reservado`.
- Ao mudar para `Entrega materiais`, o trigger `trigger_fechar_projeto` baixa estoque, zera reserva, credita sinal e cria `separacoes` com `separacao_itens`.
- Ao marcar separacao como `Pronto`, o trigger `trigger_separacao_pronta` cria/atualiza `entregas`.

### Estoque, reserva, entrega futura, devolucao e transferencia

O fluxo bate fortemente com a transcricao da reuniao: Vinicius descreve `estoque geral`, `disponivel`, `reserva`, `entrega futura`, devolucao que reduz reserva, transferencia entre clientes e lista de separacao que vira `aguardando separar -> separado -> entregue`.

O mapeamento Mermaid representa isso como reserva, entrega futura, compra/producao, separacao e entrega.

### Debora/compras

O fluxo da Debora bate com o mapeamento anterior e com a estrategia documentada: cadastro de produto, NCM, impostos, simulador, margem, necessidade de compra, orcamento fornecedor, aprovacao, transportadora, chegada ao estoque, pecas decorativas, pecas especiais e producao Lucenera/Claudio.

### Lana/Caroline/financeiro

Os processos de Lana e Caroline batem com os prints e com a analise das planilhas: `CAROLINE`, `LANA` e `DEBORA` aparecem como operadores/processadores financeiros em ContaPagar/ContaReceber. As rotinas de DDA, boletos, baixas, impostos, contabilidade, folha, comissoes e suprimentos estao coerentes com os dados financeiros mapeados.

## Onde bate como modelo, mas nao como sistema pronto

### Orcamento aprovado como gatilho unico

As transcricoes e a analise critica dizem que o correto e: orcamento aprovado dispara itens do projeto, reserva/estoque, compras e financeiro. Isso esta no mapeamento. No banco, porem, ainda ha lacunas:

- `orcamentos` existe, mas historicamente muitos orcamentos nao estao vinculados a `projetos`.
- `projeto_itens` e `projeto_sinal` aparecem como estruturas previstas, mas os documentos indicam uso operacional baixo/zero em alguns momentos.
- Falta consolidar a regra de desconto entre `orcamentos`, `orcamento_itens` e `projeto_itens`.

### Financeiro

O fluxo conceitual bate: parcelas, recebimentos, transacoes, contas a pagar/receber e contabilidade. Mas os documentos apontam que `transacoes`, `projeto_parcelas`, imports do Connect e o sistema de gestao financeira ainda tem divergencias e silos.

### Estoque real

O mapeamento assume estoque operacional confiavel. A estrategia documentada alerta que, enquanto Connect ainda for fonte real de produtos/estoque, o Supabase deve registrar status/intencao/auditoria, nao agir como fonte unica definitiva.

## Divergencias de nomenclatura que precisam normalizar

### Status de projeto

O MIRO usa linguagem de negocio: `Projeto pre executivo aprovado`, `Projeto executivo aprovado`, `Contrato aprovado`, `Material em estoque`.

O banco/sistema usa valores como:

- `Proposta Sinal`
- `Elaboracao Orcamento`
- `Projeto executivo`
- `Entrega materiais`
- `Ajustes finais`
- `Finalizado`

E os documentos tambem citam status historicos como `Emissao Projeto Executivo`, `Venda Docusign`, `Contrato de Projeto`, `Obra Finalizada`, `Nao Fechou`.

### Status de logistica

O fluxo humano fala em `aguardando separar`, `separado`, `entregue`.

O app de logistica usa:

- `material_solicitado`
- `em_separacao`
- `separado`
- `finalizado`

O trigger do banco usa enum de separacao com nomes como `Pendente`, `Pronto`, `Cancelado`.

Essa diferenca nao invalida o fluxo, mas exige uma tabela de equivalencia antes de automatizar.

## Conclusao

O mapeamento atual e fiel ao negocio e consistente com as transcricoes. Ele tambem conversa com a arquitetura planejada do banco. O ponto de atencao e que ele nao deve ser lido como "o sistema ja faz tudo isso hoje"; ele e o blueprint operacional que revela o que os sistemas precisam passar a executar de forma integrada.

Prioridades para transformar o fluxo em implementacao:

1. Normalizar status de projeto e logistica entre MIRO, CRM, banco e app de logistica.
2. Tornar `orcamento -> projeto -> projeto_itens -> estoque/reserva -> separacao -> entrega -> financeiro` uma trilha transacional clara.
3. Resolver a fonte de verdade de estoque enquanto Connect e Supabase coexistem.
4. Amarrar `projeto_parcelas` e `transacoes` sem duplicar financeiro.
5. Definir a regra final de desconto e valor final do item aprovado.

