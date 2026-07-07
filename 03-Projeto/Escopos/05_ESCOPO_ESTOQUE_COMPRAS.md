# Escopo — Novo Sistema de Estoque e Compras

## Versão atual

Sistema novo.

Atualmente, partes da responsabilidade aparecem no Cadastro, no aplicativo de Logística, em tabelas do banco, planilhas e no Connect. Não existe uma interface única que acompanhe o item aprovado desde a necessidade até a reserva, compra e recebimento.

No Supabase atual existem 1.757 registros em `estoque_itens`, 4.392 produtos ativos, 0 registros em `pedido_compra`, 0 em `solicitacoes_compra` e 0 em `projeto_itens`. A planilha `Vendas 01012025 a 23062026.xlsx` passa a ser a fonte para criar o histórico de itens aprovados e movimentos operacionais.

Os vídeos do Connect mostram que cada item aprovado possui uma vida operacional própria: quantidade vendida imutável, reserva, entrega futura, solicitação de separação, separado, entregue, devolvido e transferido.

A reunião 08 de 06/07/2026 consolidou a terminologia: "estoque de cliente" e "itens reservados" são o mesmo conceito de tela/operação; estoque disponível é estoque físico menos reservado; entrega futura é o compromisso sem cobertura física; necessidade de compra deve ser agregada por produto, sem vínculo fixo com cliente.

## Objetivo

Criar o sistema responsável por:

- dados operacionais de produtos e fornecedores;
- locais e saldos;
- movimentos;
- reservas;
- necessidades de compra;
- cotações;
- negociação;
- pedidos;
- aprovação;
- prazos;
- recebimentos;
- divergências;
- integração com Financeiro;
- liberação para Logística.

Os dados cadastrais continuarão sendo mantidos no sistema de Cadastro e reutilizados neste sistema.

## SPEC-EST-01 — Reutilização dos cadastros

**Achado:** produtos e fornecedores precisam aparecer em Cadastro e Estoque/Compras.

**Evolução:** consultar a mesma ficha cadastral e acrescentar uma visão operacional.

**Justificativa:** evita duas versões de produto ou fornecedor.

**Relação com o banco:** `produtos`, contatos com papel fornecedor e tabelas operacionais relacionadas.

**Ação a ser realizada:** construir as telas operacionais sobre IDs canônicos, sem tabela paralela de cadastro.

**Critério de aceite:** alteração cadastral feita no Cadastro aparece no Estoque/Compras.

## SPEC-EST-02 — Informações operacionais de produto e fornecedor

**Achado:** compras precisam de custo, prazo, condição, referência do fornecedor e histórico.

**Evolução:** manter informações operacionais por relação produto-fornecedor.

**Justificativa:** o mesmo produto pode ter fornecedores, custos e prazos diferentes.

**Relação com o banco:** `produto_fornecedores`, condições, código no fornecedor, último custo, prazo e mínimo.

**Ação a ser realizada:** criar aba operacional no produto e histórico de condições, sem sobrescrever o cadastro mestre.

**Critério de aceite:** o comprador compara fornecedores do mesmo produto.

## SPEC-EST-03 — Locais e saldo

**Achado:** o processo diferencia estoque, showroom, trânsito, reserva e material em obra.

**Evolução:** cadastrar locais e calcular saldo por produto/local.

**Justificativa:** um único campo de estoque total não representa disponibilidade real.

**Relação com o banco:** `estoque_locais`, `estoque_movimentos` e visão de saldos.

**Ação a ser realizada:** implementar ledger de movimentos e relatórios de saldo físico, reservado e disponível.

**Critério de aceite:** todo saldo pode ser explicado por movimentos.

## SPEC-EST-04 — Importação dos movimentos históricos

**Achado:** a planilha de itens vendidos mistura vendas e movimentos.

**Evolução:** importar todas as categorias diferentes de `VENDAS` como movimentos. Na planilha atual isso inclui `TROCA DEV`, `REMESSA TRANSP`, `GARANTIA`, `CASA COR SAIDA`, `BONIFICACAO`, `USO E CONSUMO`, `CASA COR ENTRADA`, `DEV EM GARANTIA`, `INVENTARIO`, `SAIDA INDUSTRIALIZACAO`, `SAC`, `REMESSA CONSERTO`, `DEV COMPRA`, `DESCARTE` e `RETORNO`.

**Justificativa:** essas linhas alteram a posição física ou a finalidade do material, mas não são novos itens aprovados.

**Relação com o banco:** movimento, tipo, cliente, projeto, venda original, produto, quantidade, valor de referência e origem. O produto deve ser conciliado por `produtos.codigo_legado`.

**Ação a ser realizada:** criar mapeamento de CFOP para tipo de movimento e enviar casos sem relação única para revisão. As 5.550 linhas não `VENDAS` da planilha devem ser tratadas como carga operacional, não comercial.

**Critério de aceite:** nenhuma categoria diferente de `VENDAS` cria `projeto_item` aprovado.

## SPEC-EST-05 — Recebimento dos itens aprovados

**Achado:** orçamento aprovado ou venda histórica aprovada deve gerar a necessidade operacional. Hoje `projeto_itens` está vazio. No Connect, a coluna `Q. Venda` representa a quantidade vendida original e não muda mesmo com devolução, entrega ou transferência.

**Evolução:** consumir `projeto_itens` gerados por Orçamentos ou pela importação histórica e criar posição operacional inicial por item.

**Justificativa:** Estoque/Compras não deve reinterpretar documentos comerciais nem alterar a quantidade aprovada original.

**Relação com o banco:** `projeto_itens`, produto, `q_venda`/quantidade aprovada, quantidade em reserva, entrega futura, aguardando separação, separado, entregue, devolvido e transferido.

**Ação a ser realizada:** criar uma fila de novos compromissos por projeto. A primeira carga deve consumir as 16.621 linhas `VENDAS` conciliadas da planilha nova e bloquear promoção das linhas sem projeto ou produto. Ao receber um item aprovado, calcular a primeira posição: o que houver disponível vira reserva; o déficit vira entrega futura/necessidade de compra.

**Critério de aceite:** todo item aprovado aparece uma única vez para atendimento, e a quantidade vendida original permanece imutável.

**Atualização 30/06/2026:** a migration `20260630_010_reserva_estoque_aprovacao`, no repositório central, já calcula uma posição inicial simples ao aprovar o orçamento — soma em `estoque_itens.quantidade_reservada`. **Isso não é a implementação desta SPEC**: roda dentro de Orçamentos (`aprovar_orcamento_financeiro_base_spec001`), não como comando de um sistema Estoque/Compras, não distingue reserva de entrega futura por déficit, e não consome a carga histórica das 16.621 linhas `VENDAS`. Deve ser tratada como ponte a avaliar quando este sistema for construído — decidir se a lógica migra para cá ou se é substituída. Ver [Adendo 03/07/2026](../06_ADENDO_ATUALIZACAO_03_07_2026.md).

**Atualização 07/07/2026:** a SPEC-010 foi confirmada no Supabase real com saldos operacionais por `projeto_item_id` em `estoque_saldos_projeto_item`, com auditoria em `estoque_movimentos_projeto_item`. Produto, projeto, orçamento e cliente são resolvidos por `JOIN` a partir de `projeto_itens`, não duplicados no saldo vivo. Antes de liberar operação em Estoque/Compras, aplicar o hardening `20260707_023_spec010_hardening`, reconciliar `estoque_itens.quantidade_reservada` e definir RLS.

## SPEC-EST-06 — Reserva

**Achado:** material disponível precisa ser separado do saldo livre. No Connect, somente quantidade em `Reserva` pode ser solicitada para separação.

**Evolução:** reservar quantidade por item do projeto e permitir liberação para separação somente a partir da reserva.

**Justificativa:** impede que o mesmo saldo seja prometido a dois projetos.

**Relação com o banco:** `estoque_saldos_projeto_item`, `estoque_movimentos_projeto_item`, quantidade em reserva, entrega futura, aguardando separação, separado, entregue, devolvido e vínculo com `projeto_item`.

**Ação a ser realizada:** implementar reserva total ou parcial, registrar motivo de liberação e bloquear solicitação de separação acima da quantidade reservada. Quando compra/produção chegar para um item em entrega futura, mover a quantidade atendida para reserva do cliente correto.

**Critério de aceite:** o saldo disponível diminui sem reduzir o saldo físico até a saída, e separação nunca nasce de quantidade em entrega futura.

Regra adicional de transferência entre clientes:

- se uma reserva do cliente A for transferida para o cliente B, o cliente A perde reserva, ganha quantidade transferida no histórico e volta a ter necessidade em entrega futura;
- a transferência não pode ultrapassar a quantidade vendida original;
- o movimento deve apontar o `projeto_item` de origem e o `projeto_item` de destino.

**Atualização 30/06/2026, 02/07/2026 e 06/07/2026:** reserva simples e reversão de reserva já funcionam via `estoque_itens.quantidade_reservada`, mas a transferência operacional segue pendente. A reunião 08 definiu a regra de negócio em linguagem de cliente; a modelagem consolidada traduz isso para transferência entre `projeto_item_id`: Vitória aprova, origem perde `q_reserva` e ganha `q_entrega_futura`, destino ganha `q_reserva`, e a compra de reposição continua agregada por produto. Ver SPEC-010, SPEC-011 e SPEC-012.

## SPEC-EST-07 — Necessidade de compra

**Achado:** a diferença entre quantidade aprovada e disponível precisa virar ação de compra.

**Evolução:** criar necessidade agregada por produto, com visualização informativa dos clientes/projetos impactados.

**Justificativa:** a reunião 08 confirmou que a compra não deve ficar amarrada a um cliente específico, porque transferências podem mudar quem receberá o material quando ele chegar.

**Relação com o banco:** necessidade por produto/quantidade/prioridade/situação; vínculos com clientes/projetos devem ser informativos para priorização, não chave da compra.

**Ação a ser realizada:** calcular déficit após a reserva e permitir ajuste justificado.

**Critério de aceite:** o comprador identifica quanto comprar por produto e consegue consultar quais clientes/projetos estão impactados, sem prender o pedido de compra a um cliente.

## SPEC-EST-08 — Cotações

**Achado:** o processo inclui solicitação, retorno do fornecedor, conferência de referência, descrição, acabamento, preço, NCM e prazo.

**Evolução:** registrar cotações e itens cotados por fornecedor.

**Justificativa:** a decisão de compra precisa ser comparável e rastreável.

**Relação com o banco:** `cotacoes_compra`, `cotacao_itens`, fornecedor, condições e anexos.

**Ação a ser realizada:** criar comparação de preço, prazo, imposto, condição e aderência à necessidade.

**Critério de aceite:** o usuário seleciona a cotação vencedora por item ou conjunto.

## SPEC-EST-09 — Pedido de compra

**Achado:** a planilha atual possui pedidos e parcelas, mas não representa todo o vínculo por item.

**Evolução:** gerar pedido com itens, fornecedor, empresa compradora, condições, prazo e origem.

**Justificativa:** somente o total do pedido não permite ligar compra e projeto.

**Relação com o banco:** `pedidos_compra`, `pedido_compra_itens` e vínculos às necessidades.

**Ação a ser realizada:** criar pedido a partir das cotações/necessidades e preservar alterações por versão ou evento.

**Critério de aceite:** cada item do pedido mostra quais necessidades atende.

## SPEC-EST-10 — Aprovação do pedido e previsão financeira

**Achado:** pedido aprovado representa compromisso previsto, ainda não necessariamente uma obrigação final.

**Evolução:** enviar previsão ao Financeiro no momento da aprovação.

**Justificativa:** permite planejamento sem antecipar a confirmação da conta.

**Relação com o banco:** evento idempotente e `previsoes_financeiras` relacionadas ao pedido.

**Ação a ser realizada:** criar comando de aprovação que congele valores aprovados e publique a previsão.

**Critério de aceite:** aprovar novamente o mesmo pedido não duplica a previsão.

## SPEC-EST-11 — Prazos e acompanhamento

**Achado:** compras exigem acompanhamento, cobrança de atraso e comunicação à equipe.

**Evolução:** controlar prazo prometido, revisões e atraso.

**Justificativa:** o projeto precisa saber quando o material estará disponível.

**Relação com o banco:** eventos de prazo, previsão atual e histórico.

**Ação a ser realizada:** criar alertas e registrar cada mudança de previsão.

**Critério de aceite:** o usuário identifica pedidos atrasados e projetos impactados.

## SPEC-EST-12 — Recebimento de material

**Achado:** chegada exige conferência de nota, volume e, em alguns casos, item a item.

**Evolução:** registrar recebimentos parciais ou totais e divergências.

**Justificativa:** pedido aprovado não comprova que o material chegou corretamente.

**Relação com o banco:** `recebimentos_compra`, itens recebidos, lote, local, nota e divergências.

**Ação a ser realizada:** criar conferência entre pedido, material e nota, com possibilidade de pendência.

**Critério de aceite:** o saldo físico só aumenta pela quantidade efetivamente recebida.

## SPEC-EST-13 — Confirmação da conta a pagar

**Achado:** valor e parcelas podem mudar entre previsão e nota.

**Evolução:** confirmar ou ajustar a obrigação financeira após nota ou recebimento.

**Justificativa:** separa planejamento de compromisso real.

**Relação com o banco:** evento de confirmação ligado a pedido, recebimento, nota e previsão.

**Ação a ser realizada:** enviar ao Financeiro os valores finais, parcelas e divergências.

**Critério de aceite:** o Financeiro mostra valor previsto, valor confirmado e diferença.

## SPEC-EST-14 — Liberação para Logística

**Achado:** a Logística precisa receber itens já disponíveis e autorizados. Hoje o Connect gera um pedido de separação após a aprovação operacional.

**Evolução:** liberar quantidade reservada/atendida para separação estruturada.

**Justificativa:** evita criar separação de material ainda indisponível.

**Relação com o banco:** `projeto_itens`, reservas, quantidade liberada e `separacao_itens`.

**Ação a ser realizada:** criar comando de liberação total ou parcial por projeto/item, substituindo o envio manual de PDF/Teams por uma fila estruturada para Logística. Observações de urgência ou material já entregue devem virar campo de observação da separação.

**Critério de aceite:** Logística só separa quantidades liberadas.

## SPEC-EST-15 — Garantia, troca e devolução

**Achado:** os processos mapeados possuem vários caminhos de retorno e substituição. O vídeo de devolução mostra uma hierarquia fixa: reduzir primeiro `E. Futura`, depois `Reserva` e por último `Entregue`.

**Evolução:** abrir ocorrência vinculada ao cliente, produto e origem, aplicando automaticamente a hierarquia operacional.

**Justificativa:** garantia e devolução não devem ser registradas como nova venda, e a quantidade vendida original não deve ser alterada.

**Relação com o banco:** ocorrência, movimentos de entrada/saída, venda original, item substituto, quantidade devolvida e saldos de entrega futura, reserva e entregue.

**Ação a ser realizada:** criar fluxos simples para receber defeituoso, reservar substituto, comprar se necessário e concluir a troca. Para devolução, receber a quantidade total e gerar movimentos automaticamente na ordem `E. Futura → Reserva → Entregue`; quando a quantidade atravessar mais de um status, o sistema deve dividir internamente os movimentos.

**Critério de aceite:** o histórico mostra o produto devolvido e o produto entregue em substituição, sem reduzir `Q. Venda`.

**Atualização 06/07/2026:** os vídeos Connect já definem a regra base de devolução: reduzir primeiro `E. Futura`, depois `Reserva`, por último `Entregue`, preservando `Q. Venda`. A SPEC-015 foi atualizada para esse desenho; seguem pendentes apenas aprovação, efeito financeiro e coleta física quando houver item já entregue.

## SPEC-EST-16 — Painel operacional

**Achado:** compradores e estoque precisam de uma visão diária.

**Evolução:** mostrar necessidades, reservas incompletas, cotações, pedidos atrasados, recebimentos pendentes e divergências.

**Justificativa:** concentra as ações que hoje ficam em planilhas e mensagens.

**Relação com o banco:** views operacionais sobre as entidades do domínio.

**Ação a ser realizada:** criar filtros por responsável, fornecedor, projeto, prazo e situação.

**Critério de aceite:** a equipe consegue organizar o dia sem consultar planilhas paralelas.

## Itens removidos ou adiados

- previsão de demanda por IA;
- reposição automática sem aprovação;
- otimização avançada de fornecedores;
- manufatura completa;
- roteirização logística;
- emissão bancária.

## Fundamentação

- `Consolidação/Mapeamento de Processos/Mapeamento Markdown/03_debora_compras_cadastro_producao.md`
- `Consolidação/Mapeamento de Processos/Mapeamento Markdown/04_fluxo_comercial_faturamento_estoque.md`
- `Reunioes/07. Lucenera (Filippo) - 09.06.2026: Fluxo orçamento estoque e financeiro/01_transcricao.md`
- `Lucenera PLANILHAS/Planilhas atualizadas e novas/PedidoCompra_26-06-22.xlsx`
- `Vendas 01012025 a 23062026.xlsx`
