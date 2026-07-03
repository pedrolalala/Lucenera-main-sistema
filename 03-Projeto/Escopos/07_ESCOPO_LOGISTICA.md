# Escopo — Sistema de Logística

## Versão atual

Pacote analisado: `lucenera-logistics-b7cd1`  
Versão declarada: `0.0.63`

Organizacao local: manter tanto `Sistema/lucenera-logistica-atual-backup/` (sistema real usado hoje) quanto `Sistema/lucenera-logistics-b7cd1/` (sistema conectado ao banco e destino da migracao).

O sistema atual possui:

- separação;
- calendário;
- pendências;
- registro de entrega;
- entregas finalizadas;
- organização de rota;
- telas administrativas;
- upload de documentos e fotos.

Ainda existem status divergentes, listas configuradas no código, simulação de otimização de rota e separações baseadas em informações livres. Nos vídeos do Connect, o “Pedido em Separação” ainda nasce como documento/PDF enviado para o grupo de separações; no novo ecossistema, esse documento deve ser substituído por uma fila estruturada vinda de Estoque/Compras.

Decisao de armazenamento: documentos, fotos, comprovantes e demais anexos da Logistica nao devem usar Supabase Storage. O sistema deve salvar os arquivos no OneDrive via API e persistir no banco apenas metadados, `driveItemId`, URL controlada e relacao com projeto/separacao/entrega.

## Objetivo da evolução

Ser o sistema oficial para:

- separação de material liberado;
- agenda e organização de entregas;
- entrega parcial ou total;
- evidências;
- ocorrências;
- devolução logística;
- garantia;
- histórico operacional por projeto.

Logística não cria o compromisso comercial nem decide a compra. Ela executa quantidades liberadas por Estoque/Compras.

## SPEC-LOG-01 — Origem no Estoque/Compras

**Achado:** separações podem nascer de texto, PDF ou criação manual. No Connect, após a aprovação operacional do orçamento, é gerado um pedido de separação e enviado para o responsável de estoque/logística.

**Evolução:** receber itens liberados por projeto e produto, com observações operacionais quando houver urgência, material já entregue ou instrução especial.

**Justificativa:** evita separar material ainda não disponível ou diferente do aprovado.

**Relação com o banco:** liberação, `projeto_itens`, reservas e `separacao_itens`.

**Ação a ser realizada:** criar comando de geração de separação a partir de uma liberação estruturada, substituindo o envio manual de PDF/Teams por tarefa/fila interna.

**Critério de aceite:** toda nova separação operacional possui projeto e pelo menos um item, e nenhuma separação é criada a partir de quantidade ainda em entrega futura.

## SPEC-LOG-02 — Itens e quantidades

**Achado:** a separação precisa acompanhar quantidades solicitadas, separadas, entregues e devolvidas.

**Evolução:** controlar o ciclo por item.

**Justificativa:** entregas e separações podem ser parciais.

**Relação com o banco:** `separacao_itens`, `projeto_item_id` e quantidades por estado.

**Ação a ser realizada:** substituir conteúdo livre como fonte principal por linhas estruturadas.

**Critério de aceite:** o saldo pendente de entrega é calculado por item.

## SPEC-LOG-03 — Estados canônicos

**Achado:** existem nomes como `Pendente`, `Pronto`, `material_solicitado`, `em_separacao`, `separado` e `finalizado`.

**Evolução:** definir estados claros e manter equivalência temporária.

**Justificativa:** estados divergentes dificultam automação e relatório.

**Relação com o banco:** estado canônico e histórico de transições.

**Ação a ser realizada:** criar tabela de status/configuração ou enum consolidado após validar o fluxo; migrar valores antigos com relatório.

**Critério de aceite:** cada estado antigo possui destino documentado.

## SPEC-LOG-04 — Separação parcial

**Achado:** parte dos itens pode estar disponível antes do restante.

**Evolução:** concluir parcialmente a separação e manter saldo pendente.

**Justificativa:** a operação não deve esperar todo o pedido quando o projeto permite entrega parcial.

**Relação com o banco:** eventos/linhas de separação por quantidade.

**Ação a ser realizada:** permitir registrar quantidade efetivamente separada e gerar nova separação para o saldo.

**Critério de aceite:** a soma das separações não ultrapassa a quantidade liberada.

## SPEC-LOG-05 — Agenda e rota

**Achado:** o aplicativo possui calendário e tela de rota, mas parte da otimização é apenas simulação visual.

**Evolução:** organizar entregas por data, janela, endereço, prioridade e veículo.

**Justificativa:** atende o processo diário sem introduzir otimização avançada prematuramente.

**Relação com o banco:** agenda, rota, ordem e entregas relacionadas.

**Ação a ser realizada:** persistir a ordem definida pelo usuário e retirar a falsa otimização aleatória.

**Critério de aceite:** a rota salva é recuperada igualmente por todos os usuários.

## SPEC-LOG-06 — Registro de entrega

**Achado:** o sistema já possui fluxo de registro e fotos.

**Evolução:** ligar evidências à entrega e aos itens.

**Justificativa:** comprova o atendimento e alimenta CRM e Estoque.

**Relação com o banco:** entrega, itens, recebedor, data, metadados dos arquivos no OneDrive, assinatura simples opcional e observações.

**Ação a ser realizada:** exigir recebedor e quantidade entregue; integrar OneDrive via API para anexos/fotos/comprovantes; gravar `driveItemId`, URL, tipo, tamanho, hash quando disponível e ator.

**Critério de aceite:** o projeto mostra quem recebeu, quando, quais itens foram entregues e abre as evidências a partir do OneDrive, sem depender de Supabase Storage.

## SPEC-LOG-07 — Ocorrências e insucesso

**Achado:** entrega pode ser reagendada, recusada, parcial ou apresentar divergência.

**Evolução:** registrar motivo e próxima ação.

**Justificativa:** um status genérico de pendência não explica o problema.

**Relação com o banco:** ocorrências, tipo, evidência, responsável, resolução e novo agendamento.

**Ação a ser realizada:** criar tipos configuráveis de ocorrência e fluxo simples de resolução.

**Critério de aceite:** uma entrega não concluída possui motivo e responsável pela resolução.

## SPEC-LOG-08 — Devolução e garantia

**Achado:** o processo mapeado inclui retirada, recebimento do defeituoso e entrega do substituto.

**Evolução:** executar tarefas logísticas das ocorrências abertas por Estoque/Compras.

**Justificativa:** a origem da garantia é operacional, mas transporte e prova pertencem à Logística.

**Relação com o banco:** ocorrência, movimentos de estoque, coleta, entrega e item substituto.

**Ação a ser realizada:** criar tipos de serviço `coleta`, `troca` e `entrega de garantia`.

**Critério de aceite:** a coleta e a entrega ficam vinculadas à mesma ocorrência.

## SPEC-LOG-09 — Integração com CRM

**Achado:** o responsável pelo projeto precisa acompanhar separação e entrega.

**Evolução:** publicar eventos na timeline.

**Justificativa:** CRM deve informar o andamento sem editar os dados logísticos.

**Relação com o banco:** evento de separação iniciada, pronta, enviada, entregue, parcial ou com ocorrência.

**Ação a ser realizada:** registrar eventos padronizados por projeto.

**Critério de aceite:** o CRM mostra o evento poucos instantes após a atualização logística.

## SPEC-LOG-10 — Configurações e acessos

**Achado:** listas de gestoras e permissões aparecem em código ou estruturas locais.

**Evolução:** obter usuários, papéis e configurações pelo Sistema de TI.

**Justificativa:** evita manutenção manual em cada aplicativo.

**Relação com o banco:** permissões centrais e configurações operacionais.

**Ação a ser realizada:** retirar listas hardcoded e migrar cadastros locais de função.

**Critério de aceite:** uma alteração de acesso no Sistema de TI é respeitada na Logística.

## SPEC-LOG-11 — Painel administrativo real

**Achado:** algumas áreas administrativas apresentam atividades montadas localmente.

**Evolução:** exibir métricas derivadas das separações, entregas e ocorrências reais.

**Justificativa:** evita indicadores de demonstração.

**Relação com o banco:** views de operação logística.

**Ação a ser realizada:** remover dados locais e calcular pendências, atrasos, entregas e produtividade.

**Critério de aceite:** todos os indicadores podem ser abertos até o registro de origem.

## Itens removidos ou adiados

- otimização matemática avançada de rotas;
- sincronização com Teams/SharePoint sem necessidade validada;
- criação manual irrestrita de material;
- administração própria de usuários;
- chat com IA.

## Fundamentação

- `Sistema/lucenera-logistics-b7cd1/src/App.tsx`
- `Sistema/lucenera-logistics-b7cd1/src/pages/SeparacaoPage.tsx`
- `Sistema/lucenera-logistics-b7cd1/src/pages/RegistrarEntregaPage.tsx`
- `Sistema/lucenera-logistica-atual-backup/`
- `Consolidação/Mapeamento de Processos/Mapeamento Markdown/09_troca_garantia_luminaria.md`
