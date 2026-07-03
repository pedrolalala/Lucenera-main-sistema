# Escopo — Sistema Financeiro

## Versão atual

Pacote de origem: `retorno-bancario-bradesco-5392a`  
Versão declarada após atualização: `0.0.40`

O sistema atual possui:

- consulta de duplicatas;
- boletos;
- geração de remessa CNAB 400;
- leitura de retorno;
- registro de notas fiscais;
- autenticação.

A versão atual já consulta `boletos`, `empresas`, `projetos`, `projeto_parcelas`, `retornos_processados`, `notas_fiscais` e executa funções de remessa/faturamento. Parte do fluxo ainda possui dados simulados ou ações incompletas, especialmente no upload de notas e na automação de aprovação/faturamento.

Os vídeos do Connect reforçam que boleto, remessa, retorno e baixa são etapas diferentes. Gerar o boleto/PDF não significa que o boleto já foi registrado no banco; a remessa deve ser enviada em lote e o retorno bancário confirma ocorrências e pagamentos.

No Supabase atual existem 14.963 transações, 13.863 linhas em `staging_conta_pagar`, 4.357 em `staging_conta_receber`, 709 parcelas de projeto, 411 vendas, 9 boletos, 2 retornos processados e 0 notas fiscais registradas.

## Objetivo da evolução

Renomear e evoluir o sistema para **Financeiro**, incorporando:

- previsões;
- contas a pagar;
- contas a receber;
- títulos e parcelas;
- notas;
- boletos;
- remessa;
- retorno;
- baixas;
- conciliação;
- visão por projeto;
- integrações com Orçamentos e Estoque/Compras.

## SPEC-FIN-01 — Nova identidade e navegação

**Achado:** a aplicação é apresentada apenas como Administração Bancária.

**Evolução:** reorganizar a navegação sob a identidade Financeiro.

**Justificativa:** o novo escopo reúne planejamento, títulos e operação bancária.

**Relação com o banco:** nenhum novo domínio duplicado; a aplicação passa a consumir o núcleo financeiro consolidado.

**Ação a ser realizada:** renomear aplicação, rotas, menus e textos; organizar módulos por Visão Geral, Pagar, Receber, Previsões, Boletos, Remessa, Retorno, Conciliação e Notas.

**Critério de aceite:** o usuário acessa todo o ciclo financeiro pela mesma aplicação.

## SPEC-FIN-02 — Previsões financeiras

**Achado:** pedidos aprovados e vendas aprovadas produzem compromissos esperados. A planilha nova possui 2.042 vendas aprovadas, mas elas ainda não aparecem em `vendas.cod_venda`.

**Evolução:** manter previsões separadas dos títulos confirmados.

**Justificativa:** planejamento não pode ser confundido com obrigação ou recebível já emitido.

**Relação com o banco:** `previsoes_financeiras`, origem, projeto, pedido/venda, valores e datas estimadas. Para a carga histórica, a origem deve guardar `CodVenda`, arquivo e linha.

**Ação a ser realizada:** criar telas de previsões e comandos de confirmação, ajuste ou cancelamento.

**Critério de aceite:** uma previsão não aparece como paga, vencida ou conciliada.

## SPEC-FIN-03 — Contas a pagar

**Achado:** o Supabase atual possui 13.863 linhas em `staging_conta_pagar`, com base nas cargas mais recentes.

**Evolução:** importar e operar títulos a pagar com fornecedor, parcelas, vencimento, pagamento e origem.

**Justificativa:** substitui consultas e baixas manuais do Connect.

**Relação com o banco:** títulos financeiros, partes, parcelas, projeto/pedido quando aplicável e identificadores externos.

**Ação a ser realizada:** criar importação idempotente e tela operacional com filtros, baixa e divergência.

**Critério de aceite:** repetir a carga não duplica títulos.

## SPEC-FIN-04 — Contas a receber

**Achado:** o Supabase atual possui 4.357 linhas em `staging_conta_receber`. A planilha de vendas aprovada também traz `CodVenda`, que deve ajudar a relacionar recebíveis, venda e projeto.

**Evolução:** relacionar recebíveis a venda, projeto e cliente.

**Justificativa:** permite visão financeira por projeto e reconciliação com a origem comercial.

**Relação com o banco:** título, venda, projeto, parcela, cliente e código externo.

**Ação a ser realizada:** usar `cod_venda` como uma das regras de relacionamento, respeitando empresa e revisão de ambiguidades.

**Critério de aceite:** um projeto exibe seus recebíveis sem busca pelo nome do cliente.

## SPEC-FIN-05 — Integração com pedidos de compra

**Achado:** pedido aprovado gera previsão; nota/recebimento confirma ou ajusta a obrigação.

**Evolução:** consumir os dois eventos do Estoque/Compras.

**Justificativa:** evita digitação duplicada e mantém diferença entre previsto e realizado.

**Relação com o banco:** previsão e título ligados ao mesmo pedido, recebimento e nota.

**Ação a ser realizada:** criar endpoints/comandos idempotentes de previsão e confirmação.

**Critério de aceite:** o Financeiro mostra a origem do título e a variação em relação à previsão.

## SPEC-FIN-06 — Integração com vendas e orçamentos

**Achado:** a aprovação comercial pode definir condições de recebimento. O histórico aprovado virá da planilha `Vendas 01012025 a 23062026.xlsx`. Nos vídeos do Connect, o Financeiro confere vencimentos, forma de pagamento e frete antes de faturar; no novo sistema, essa conferência deve validar vencimentos calculados pelo orçamento.

**Evolução:** receber previsões com vencimentos calculados e depois validar/confirmar os títulos.

**Justificativa:** o editor de orçamento não deve executar cobrança ou baixa, e o Financeiro deve validar a cobrança sem redigitar dados que o sistema já consegue calcular.

**Relação com o banco:** venda, projeto, condição, frete, prazo, parcelas/vencimentos calculados, previsão e título.

**Ação a ser realizada:** gerar previsões a partir da aprovação e permitir ao Financeiro validar ou ajustar emissão, vencimentos e forma de cobrança. Na importação histórica, criar vínculo com `vendas` e `projeto_parcelas` sem duplicar títulos já existentes.

**Critério de aceite:** condições do orçamento são rastreáveis até os recebíveis e nenhum boleto nasce sem vencimento calculado ou validado.

## SPEC-FIN-07 — Boletos

**Achado:** o sistema já possui cadastro e gestão de boletos. No processo do Connect, o boleto pode ser gerado antes do registro bancário efetivo.

**Evolução:** relacionar boleto ao título/parcela canônica e diferenciar boleto gerado de boleto registrado.

**Justificativa:** boleto é instrumento de cobrança, não a própria obrigação. O PDF sem remessa enviada pode não estar registrado no banco.

**Relação com o banco:** `boletos`, título, parcela, projeto, empresa emissora, lote de remessa e status de registro.

**Ação a ser realizada:** remover boletos isolados, exigir referência ao recebível e usar estados como `pendente_registro`, `remessa_enviada`, `registrado`, `pago`, `cancelado` ou equivalentes definidos pelo Financeiro. Se a operação fiscal exigir NF antes do registro bancário, permitir boleto preparado como pendente, mas bloquear remessa/registro até a conferência fiscal.

**Critério de aceite:** a baixa do boleto atualiza o recebível correspondente e o usuário consegue distinguir boleto gerado de boleto registrado.

## SPEC-FIN-08 — Remessa CNAB

**Achado:** já existe geração de arquivo CNAB 400. No Connect, a remessa é gerada em lote, normalmente ao fim do dia, e precisa ser enviada ao banco para o boleto ser registrável.

**Evolução:** gerar remessa a partir de boletos elegíveis, registrar o lote e evitar envio individual automático a partir da aprovação do orçamento.

**Justificativa:** preserva o recurso existente com rastreabilidade.

**Relação com o banco:** lote de remessa, itens, arquivo, empresa e situação.

**Ação a ser realizada:** validar o gerador com arquivos reais do banco, retirar dados simulados, impedir reenvio acidental e criar tela/rotina para lote diário de boletos de venda.

**Critério de aceite:** cada boleto enviado possui referência ao lote e arquivo, e boletos de orçamento aprovado entram na fila sem gerar remessa automaticamente.

## SPEC-FIN-09 — Retorno bancário

**Achado:** a tela atual ainda contém registros iniciais simulados.

**Evolução:** processar arquivo real, identificar ocorrências e aplicar baixas idempotentes.

**Justificativa:** retorno é a fonte bancária de confirmação.

**Relação com o banco:** arquivo, linha, código de ocorrência, boleto, título e transação.

**Ação a ser realizada:** remover dados simulados, persistir linhas processadas e criar fila de ocorrências não conciliadas.

**Critério de aceite:** reprocessar o mesmo arquivo não duplica baixa.

## SPEC-FIN-10 — Conciliação

**Achado:** título, boleto, parcela e transação ainda não estão sempre ligados.

**Evolução:** permitir alocação total ou parcial da transação.

**Justificativa:** um pagamento pode liquidar mais de uma parcela ou uma parcela pode receber mais de um pagamento.

**Relação com o banco:** ponte entre transação e parcelas/títulos.

**Ação a ser realizada:** criar tela de conciliação com sugestão automática e confirmação humana para ambiguidades.

**Critério de aceite:** o saldo do título é calculado pelas alocações confirmadas.

## SPEC-FIN-11 — Notas fiscais e documentos

**Achado:** o cadastro atual de nota possui upload ainda simulado e o Supabase atual não possui notas fiscais registradas. No Connect, a nota passa por conferência de pagamento/frete, geração, assinatura e envio.

**Evolução:** registrar nota real e vinculá-la à compra, venda, orçamento ou título.

**Justificativa:** a nota é evidência e fonte de confirmação financeira.

**Relação com o banco:** `notas_fiscais`, empresa, parte, pedido/venda/orçamento, título, arquivo/DANFE e status de emissão.

**Ação a ser realizada:** implementar armazenamento real, validação básica e vínculo obrigatório à origem quando disponível. Enquanto não houver API, registrar manualmente número, série, data, valor, origem e arquivo da nota real, sem simulação.

**Critério de aceite:** a nota pode ser aberta a partir do pedido, orçamento ou título.

## SPEC-FIN-12 — Visão financeira por projeto

**Achado:** o projeto é a unidade operacional, mas o financeiro ainda depende de nomes e códigos indiretos.

**Evolução:** mostrar previsto, confirmado, recebido, pago e pendente por projeto.

**Justificativa:** permite avaliar o projeto sem planilhas paralelas.

**Relação com o banco:** títulos, previsões, transações e alocações relacionados ao projeto.

**Ação a ser realizada:** criar visão oficial por projeto consumida também pelo CRM.

**Critério de aceite:** os totais podem ser reconciliados com os títulos detalhados.

## SPEC-FIN-13 — Rotinas administrativas essenciais

**Achado:** Lana e Caroline executam baixas, tarifas, impostos, cartões, transferências e relatórios.

**Evolução:** incluir somente as rotinas necessárias para abandonar o Connect.

**Justificativa:** o sistema deve atender a operação real sem virar um ERP genérico nesta fase.

**Relação com o banco:** categorias, contas bancárias, transferências, tarifas e documentos.

**Ação a ser realizada:** mapear cada rotina obrigatória para uma tela ou comando antes do corte.

**Critério de aceite:** a equipe confirma que as rotinas diárias priorizadas não exigem o Connect.

## SPEC-FIN-14 — Reconciliação das parcelas históricas

**Achado:** relatórios anteriores apontam diferença relevante entre parcelas ativas e backup.

**Evolução:** revisar o backup antes de consolidar ou remover estruturas antigas.

**Justificativa:** evita perda de histórico financeiro.

**Relação com o banco:** parcelas atuais, backup, vendas, projetos e transações.

**Ação a ser realizada:** criar relatório linha a linha com presente, ausente, divergente e duplicado.

**Critério de aceite:** toda parcela do backup possui classificação e decisão documentada.

## Itens removidos ou adiados

- DocSign (baixa prioridade — mapear como plano futuro, não remover do roadmap; ver `03_ESCOPO_CRM.md`, SPEC-CRM-12);
- emissão fiscal completa integrada a prefeitura/SEFAZ;
- tesouraria avançada;
- orçamento comercial;
- controle físico de estoque;
- BI financeiro corporativo amplo;
- fechamento contábil automatizado completo.

## Fundamentação

- `Sistema/retorno-bancario-bradesco-5392a/src/App.tsx`
- `Sistema/retorno-bancario-bradesco-5392a/src/pages/Remessa.tsx`
- `Sistema/retorno-bancario-bradesco-5392a/src/pages/RetornoBoletos.tsx`
- `Consolidação/Mapeamento de Processos/Mapeamento Markdown/01_lana_financeiro_administrativo.md`
- `Consolidação/Mapeamento de Processos/Mapeamento Markdown/02_caroline_administrativo_suprimentos.md`
