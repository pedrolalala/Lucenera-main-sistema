# Escopo — Sistema de Orçamentos

## Versão atual

Pacote analisado: `gestao-financeira-clone-544cb (1)`  
Versão declarada após atualização: `0.0.178`

Apesar do nome do pacote, as rotas ativas direcionam o usuário para Orçamentos. O sistema já possui lista, formulário, itens, produtos, clientes, projetos, vendedores, formas de pagamento e estados de aprovação.

A versão atual já grava em `orcamentos` e `orcamento_itens`, busca projeto pelo código operacional e possui ação de aprovação/sincronização que cria `projeto_itens` e `projeto_parcelas`. No Supabase atual existem 7 orçamentos e 17 itens de orçamento, mas `projeto_itens` ainda está vazio.

Os vídeos do Connect acrescentam regras operacionais importantes: item especial sem preço bloqueia aprovação, frete precisa estar definido, vencimentos precisam nascer da forma de pagamento/prazo do orçamento e o orçamento aprovado deve ficar travado para edição comercial direta.

## Objetivo da evolução

Ser o editor oficial de orçamentos da Lucenera:

- orçamento vinculado ao projeto;
- versões;
- itens e condições;
- cálculo;
- revisão;
- aprovação;
- snapshot dos itens aprovados;
- integração com CRM, Estoque/Compras e Financeiro.

O sistema não deve manter cadastro paralelo de projeto, cliente, produto ou usuário.

## SPEC-ORC-01 — Projeto obrigatório

**Achado:** historicamente existem orçamentos sem `projeto_id`, mas a tela atual já trabalha com busca obrigatória pelo código do projeto.

**Evolução:** todo novo orçamento Lucenera deve estar ligado a um projeto.

**Justificativa:** projeto define cliente, responsável, timeline e destino dos itens.

**Relação com o banco:** `orcamentos.projeto_id` obrigatório para o contexto Lucenera.

**Ação a ser realizada:** manter o bloqueio de salvamento/aprovação sem projeto e padronizar a busca pelo código operacional, usando a mesma normalização definida para a importação da planilha de vendas.

**Critério de aceite:** nenhum novo orçamento Lucenera é criado sem projeto.

## SPEC-ORC-02 — Reutilização dos dados canônicos

**Achado:** o formulário consulta projetos, clientes, produtos e usuários diretamente.

**Evolução:** consumir somente entidades oficiais, sem criar cópias locais.

**Justificativa:** alterações cadastrais precisam refletir no orçamento sem sincronizações paralelas.

**Relação com o banco:** `projetos`, `contatos`, `produtos`, `usuarios` e `empresas`.

**Ação a ser realizada:** remover qualquer criação paralela e usar comandos do sistema responsável quando um cadastro novo for necessário.

**Critério de aceite:** o orçamento referencia IDs canônicos.

## SPEC-ORC-03 — Versionamento

**Achado:** revisões fazem parte do projeto e podem ocorrer antes ou depois da apresentação.

**Evolução:** cada revisão relevante gera uma versão identificável.

**Justificativa:** valores aprovados não podem ser reconstruídos a partir do estado atual.

**Relação com o banco:** cabeçalho lógico do orçamento e versões com itens próprios ou snapshots.

**Ação a ser realizada:** implementar duplicação controlada de versão e impedir sobrescrita da versão aprovada.

**Critério de aceite:** é possível comparar versões e identificar qual foi aprovada.

## SPEC-ORC-04 — Itens e valores históricos

**Achado:** preço, desconto e quantidade precisam permanecer como foram negociados. A planilha de vendas mostra que o histórico aprovado precisa preservar o valor da época, e não recalcular pelo produto atual.

**Evolução:** registrar snapshot comercial por item.

**Justificativa:** mudanças futuras no produto não podem alterar o histórico.

**Relação com o banco:** `orcamento_itens` com produto, descrição, quantidade, preço, desconto, impostos aplicáveis e subtotal.

**Ação a ser realizada:** salvar valores calculados e referências do produto no momento da versão.

**Critério de aceite:** abrir um orçamento antigo apresenta exatamente os valores daquela versão.

## SPEC-ORC-05 — Comando de aprovação

**Achado:** mudar somente um campo de status não garante todos os efeitos necessários. A versão atual já possui uma função de aprovação e migração, mas ela precisa ser endurecida para origem, versão e item. No Connect, a aprovação também bloqueia orçamento com item especial sem preço, exige conferência de frete e trava a edição comercial depois do fechamento.

**Evolução:** aprovação deve ser uma operação única e idempotente, antecedida por validação de preço, frete, forma de pagamento e prazo. Quando a condição estiver estruturada, o sistema calcula vencimentos automaticamente.

**Justificativa:** evita criar itens duas vezes, deixar o orçamento aprovado sem operação correspondente ou gerar cobrança com dados financeiros incompletos.

**Relação com o banco:** aprovação, versão aprovada, `projeto_itens`, venda e evento de timeline. O vínculo precisa identificar a origem do item: orçamento atual ou importação histórica de vendas. Também precisa haver campos ou estrutura complementar para frete, forma de pagamento, prazo/condição de pagamento, parcelas calculadas e bloqueio de edição da versão aprovada.

**Ação a ser realizada:** criar comando transacional que valide a versão, bloqueie item especial ou item sem cadastro com preço zero, leia frete/forma de pagamento/prazo, calcule vencimentos quando possível, registre a aprovação e gere os itens. A idempotência deve ser por origem, orçamento/versão/item, projeto e produto, e não apenas por “já existe algum item no projeto”.

**Critério de aceite:** repetir a solicitação de aprovação não duplica venda nem item, sem bloquear novos aditivos ou versões aprovadas posteriores. Orçamento com item especial sem preço ou condição de pagamento/frete impossível de interpretar não avança para a geração financeira.

## SPEC-ORC-06 — Integração com CRM

**Achado:** CRM precisa mostrar o andamento e o resultado do orçamento.

**Evolução:** publicar eventos de criação, revisão, envio, aprovação, cancelamento e substituição.

**Justificativa:** CRM exibe a timeline, mas Orçamentos continua sendo dono do documento comercial.

**Relação com o banco:** eventos relacionados ao projeto e ao orçamento.

**Ação a ser realizada:** registrar eventos padronizados consumidos pela timeline do CRM.

**Critério de aceite:** a aprovação aparece no CRM sem edição manual duplicada.

## SPEC-ORC-07 — Integração com Estoque/Compras

**Achado:** o item aprovado é o compromisso que gera reserva ou necessidade.

**Evolução:** disponibilizar `projeto_itens` imediatamente após aprovação.

**Justificativa:** Estoque/Compras não deve interpretar PDFs ou textos para descobrir o que comprar.

**Relação com o banco:** `projeto_itens` referencia orçamento, versão, item e produto. Para o histórico importado, também deve referenciar venda, item da venda e linha de origem.

**Ação a ser realizada:** emitir evento de itens aprovados e permitir consulta de snapshots.

**Critério de aceite:** Estoque/Compras recebe os itens estruturados do projeto.

## SPEC-ORC-08 — Condições e parcelas previstas

**Achado:** orçamento pode definir pagamento, mas a operação financeira pertence ao Financeiro. Nos vídeos do Connect, vencimentos são conferidos manualmente; no novo sistema, essa conferência deve virar cálculo automático com validação financeira.

**Evolução:** registrar condições comerciais, frete e prazo de pagamento para calcular a previsão de recebimento.

**Justificativa:** separa a negociação da cobrança efetiva, reduz digitação manual e evita boleto com vencimento sem base.

**Relação com o banco:** condições do orçamento, frete, prazo, parcelas/vencimentos calculados e previsões financeiras relacionadas à venda/projeto.

**Ação a ser realizada:** criar ou ajustar campos estruturados para condição de frete, forma de pagamento, prazo, quantidade de parcelas calculada, vencimentos calculados e observações de negociação. Gerar previsões após aprovação, sem criar baixa ou transação realizada.

**Critério de aceite:** Financeiro recebe o planejado com vencimentos calculados e pode validar/ajustar antes de confirmar títulos, boletos ou remessa.

## SPEC-ORC-09 — Cancelamento, aditivo e substituição

**Achado:** projetos podem ter revisão após aprovação, devolução ou nova aquisição.

**Evolução:** representar ajustes por evento e nova versão, sem apagar a aprovação anterior.

**Justificativa:** o histórico comercial e os efeitos em estoque precisam ser preservados.

**Relação com o banco:** eventos de ajuste, itens substituídos e movimentos compensatórios.

**Ação a ser realizada:** criar operações explícitas de cancelamento, complemento e substituição.

**Critério de aceite:** o saldo operacional reflete o ajuste e o histórico anterior continua consultável.

## SPEC-ORC-10 — Limpeza da identidade antiga

**Achado:** o pacote ainda possui resíduos de dashboard e tabela financeira `transactions`.

**Evolução:** assumir identidade exclusiva de Orçamentos.

**Justificativa:** evita confusão com o novo sistema Financeiro.

**Relação com o banco:** remover dependências de `transactions` depois da migração dos consumidores.

**Ação a ser realizada:** retirar telas, serviços e nomenclaturas financeiras residuais que não pertencem ao orçamento.

**Critério de aceite:** navegação, textos e contratos do sistema tratam somente de orçamento.

## Itens removidos ou adiados

- dashboard financeiro próprio;
- contas a pagar/receber;
- cadastro independente de projeto;
- DocSign (baixa prioridade — mapear como plano futuro, não remover do roadmap; ver `03_ESCOPO_CRM.md`, SPEC-CRM-12);
- aprovação por IA;
- três modelos concorrentes de orçamento Lucenera.

## Fundamentação

- `Sistema/gestao-financeira-clone-544cb (1)/src/App.tsx`
- `Sistema/gestao-financeira-clone-544cb (1)/src/pages/BudgetFormPage.tsx`
- `Consolidação/Mapeamento de Processos/Mapeamento Markdown/04_fluxo_comercial_faturamento_estoque.md`
- `Reunioes/07. Lucenera (Filippo) - 09.06.2026: Fluxo orçamento estoque e financeiro/01_transcricao.md`
- `Videos Connect/Orçamentos.md`
