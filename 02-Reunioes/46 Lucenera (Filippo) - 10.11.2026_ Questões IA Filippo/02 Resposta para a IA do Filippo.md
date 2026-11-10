# Resposta à análise "Onde mora cada informação" (10/11/2026)

Para: Filippo e a IA dele. De: Pedro. Base: a análise de 09/11 (arquivo `01.IA`), conferida de novo no banco de São Paulo e no repositório em 10/11. Marquei **Confere** quando reconferi, **Parcial** quando o número ou a leitura difere, e **A conferir** quando não consegui verificar.

## O que era erro e já foi corrigido (10/11)

| # | Erro confirmado | O que foi feito | Como conferir |
|---|---|---|---|
| 1 | **12 vendas da herança Connect ligadas ao cadastro errado** (pauta 1 e 2). Causa: o importador da Reserva/Entrega Futura procurava o cliente só pelo número da Connect, e o número 2010 é a cliente Josimara (cadastro "cliente") e também a arquiteta Kally (cadastro "arquiteto"). | Para as 12 vendas (47, 211, 1189, 1414, 1641, 2620, 3062, 3380, 3794, 5300, 5921, 6011) o orçamento e as 144 linhas de reserva passaram para o cadastro **tipo cliente com o mesmo código da Connect**. A 1641 agora é Josimara Mendonça - Casa (era Kally Nasbine). Ensaiei com ROLLBACK; depois da aplicação, número e valor dos orçamentos, financeiro, saldos por item e reservado total ficaram idênticos. | Venda Parcial, vendas acima: o cliente e o endereço já saem do cadastro de cliente. |
| 2 | **O mesmo bug no importador** (pauta 1). | `scripts/importar_reserva_entrega_futura_connect.py` agora prefere o cadastro tipo `cliente` e só usa outro tipo se não existir cliente com aquele código. Uma reimportação não recria o erro. | Rodar o dry-run: nenhuma venda nova deve cair em arquiteto quando existe cliente com o mesmo código. |
| 3 | **`.env` apontando para Ohio** (seção 1 e pauta 11). Eram **12 sistemas**, não só Compras e Dashboard: Cadastro, Catálogo Ubiqua, Central, Garantia, Produção, Logística, Retorno Bancário, Separação Parcial, Showroom, Vendas, Compras e Dashboard. | Todos os `.env` locais passaram para São Paulo. Conferi um a um: nenhum aponta mais para Ohio. | `grep vcvcwzmbiftcawncibke 04-Sistemas/*/.env` não retorna nada. |
| 4 | **"Sumário Sistemas" inexistente** (seção 4). | Criado `04-Sistemas/00 - Sumario Sistemas.md` com os 20 sistemas do Hub, pasta, repositório e endereço, tirados da tabela `systems`. | Abrir o arquivo. |

| 5 | **Cópias velhas das funções de servidor em 10 sistemas** (seção 4, risco alto). | 112 pastas retiradas dos sistemas (commit e push em cada repositório). Antes, guardei **35 versões distintas** em `supabase/functions_copias_arquivadas_2026-11-10/` com manifesto, porque nenhuma cópia era idêntica ao central e algumas tinham código que o central não tem. Ficaram, de propósito, as funções que só existem dentro de sistemas (`sync-sharepoint`, `sync-fechamentos-automatica`, as do Catálogo Ubiqua e do Vendas, a do RH). | `MANIFESTO.md` na pasta de arquivo; `git log` de cada sistema. |

**Atenção:** não consegui confirmar qual versão de cada função está publicada hoje (o token da API do Supabase está inválido). Antes de publicar qualquer função, comparar o que está no ar com o central e com o arquivo. Isso é a próxima ação.

Dois erros confirmados que **ainda não corrigi**, porque mexem em numeração ou em financeiro e merecem decisão:
- **Número de orçamento repetido** (pauta 8): confirmado, e é pior do que o apontado. Dentro da MANOELLA há **ORC-0004 duas vezes e ORC-0005 três vezes**. É falha na geração do número; corrigir exige migration e decidir como renumerar os existentes.
- **Metalúrgica IL sem cadastro de fornecedor** (pauta 3): confirmado, não existe contato com esse nome. Criar o cadastro e religar 133 duplicatas é alteração de financeiro; só com aprovação.

## Parte A — Como o sistema funciona e por que está assim

1. **Estamos em implantação paralela com a Connect.** A Connect continua sendo o sistema de verdade até a virada. O nosso sistema recebe cópias dela (estoque, reserva por venda, contas a pagar e a receber, notas, clientes) e, em paralelo, já faz a operação nova (orçamento, separação, entrega, compras). Por isso existem dois "lados" de quase tudo: o lado que **espelha a Connect** e o lado **nativo**. Isso não é desorganização: é a ponte da virada.
2. **O que veio da Connect é "herança".** A herança é o saldo que a Connect já tinha (reserva e entrega futura por cliente e por ambiente "L") no dia da carga. Regras decididas ao longo de outubro e novembro (SPEC-232, 243, 244, 250):
   - Venda feita no sistema novo nunca vira herança.
   - Importar planilha ou XML da Connect só enriquece o documento, nunca muda quantidade (antes × depois igual).
   - A herança "sem venda" (reservado sem cliente) é um resíduo de bugs da Connect; está sendo zerada por conferência.
3. **Banco oficial = São Paulo desde 14/10/2026.** Ohio ficou como reserva (cópia de segurança por script). Todo deploy sai por `wrangler` com as variáveis de São Paulo informadas na hora do build.
4. **Uma única fonte para o código e o banco: o repositório central.** Migrations oficiais só em `supabase/db/migrations`. Cada sistema tem repositório próprio só para o front.
5. **Regra de trabalho:** nada se implementa sem SPEC; migration nova é ensaiada com ROLLBACK antes de aplicar; segurança por RLS e por permissão do Hub, não pela tela.

## Parte B — Ponto a ponto

### Seção 1 — O que é "antigo"
| Item | Situação | Resposta |
|---|---|---|
| Banco antigo (Ohio) | **Confere, e era mais amplo:** 12 sistemas tinham o `.env` local em Ohio. | **Corrigido** (ver tabela no topo). O `.env` da Separação Parcial é versionado no repositório do sistema; a troca está feita no arquivo e fica para commit, junto com o próximo deploy. |
| Financeiro antigo (`transacoes`/`negociacoes`) | **Confere** (23.339 e 14.029 linhas). | Não é lixo: é o espelho que a carga diária da Connect ainda alimenta (SPEC-245). O modelo novo (`financeiro_titulos` 10.425, `_parcelas` 19.440, `_baixas` 16.731) é preenchido por uma ponte. Só vira "histórico" depois da fase 4c da SPEC-258. |
| Pedido de compra antigo | **Confere.** | `pedido_compra` (247) é a planilha da Connect, lado financeiro. `pedidos_compra` (109) é o Compras. Ver item de pedidos abaixo. |
| Papéis antigos (`usuarios.role`) | **Confere.** | Ver item 10. |
| Retorno bancário antigo | **Confere.** | Mantido enquanto o novo (migration 314) é validado. |
| Foto antiga do banco | **Confere.** A pasta `supabase/db/current` parou em jul/2026, e o repositório já tem 328 migrations. | Proposta: extrair de novo do banco de São Paulo. |

### Seção 2 — Mesma informação em mais de um lugar
| Informação | Situação | Resposta |
|---|---|---|
| Funcionários (`funcionarios` 37 × `funcionarios_novo` 27) | **Confere.** | O RH nasceu como sistema à parte, com tabela própria. Não tenho registro de uma decisão que justifique manter duas; é uma lacuna real. Concordo com o lugar oficial `funcionarios`, com o RH gravando ali e `funcionarios_novo` virando complemento. **Decisão: Filippo/Vinicius** (dado de RH tem sensibilidade própria). |
| Acesso (`user_system_access` 268, Hub, `user_roles_separacao` 22, `usuarios.role`) | **Confere.** | Foram camadas sucessivas (SPEC-069 papéis, SPEC-183 acesso a sistemas, SPEC-242 segurança). Moara confirmada: 0 acessos e 0 papéis. Concordo com o Hub como oficial e os outros derivados. |
| Pedido de compra (247 × 109) | **Confere.** | Origens diferentes: um é cópia da Connect, o outro é o fluxo novo. A diferença nos dados vem de os pedidos da Connect entrarem sem itens (ver item 5). |
| Contas a pagar/receber | **Confere.** | Ver seção 1. Falta definir de onde o Dashboard lê depois da virada: concordo que deve ser do modelo novo. |
| Cobranças/boletos | **Parcial** (`boletos` 6, `financeiro_cobrancas` 1, `projeto_parcelas` 387). | Três lugares é verdade. Os dois primeiros quase não têm volume; a unificação deve acompanhar a SPEC-258. |
| Notas fiscais | **Confere** (`notas_fiscais` 0, `_connect` 599, `_compra` 7). | Venda e entrada separadas é intencional. NF de venda em duas tabelas: aceito, resolve quando a emissão vier para cá (SPEC-154, Focus NFe). |
| Entregas (`separacoes` 1.000, `entregas_finalizadas` 427, `entregas_pendentes` 0, `entregas` 0) | **Confere.** | As tabelas da Logística têm origem anterior; `separacoes` é o fluxo atual. **A conferir** com a Logística se `entregas_finalizadas` ainda recebe gravação. |
| Fornecedores (`fornecedores` vazia) | **Confere.** | Oficial é `contatos` tipo fornecedor. Concordo: `fornecedores` sai. As 4 views que a leem precisam ser revisadas antes. |
| Devoluções | **Parcial.** | Devolução é frequente e tem hoje três caminhos. Concordo que precisa de um caminho único. Já há regras próprias para devolução vinculada a venda (SPEC-178/179/181/182). **Decisão: Vinicius.** |

### Seção 3 — Tabelas sem uso
Concordo em marcar como histórico depois da virada e só então apagar. Não apagar nada agora: a implantação ainda pode precisar de reimportação. Staging de importação fica até a virada definitiva.

### Seção 4 — Pastas dos sistemas
| Item | Resposta |
|---|---|
| Funções de servidor copiadas | **Confere** em parte: `process-remittance` em 9 sistemas, `sync-fechamentos-automatica` em 6, `process-billing-automation` em 4 (a análise diz 5). **É o risco mais sério:** publicar de um sistema com cópia velha reverte a função no ar (já aconteceu com a função de Cadastro). Concordo em tirar as cópias; é a ação que eu faria primeiro. |
| Migrations dentro dos sistemas | A fonte oficial é só o repositório central. Concordo em marcar as antigas como "não usar". |
| Nomes confusos | **Confere** (`gestao-financeira-clone-544cb (1)` = Orçamentos). Renomear mexe em deploy, então só com cuidado e fora de horário de uso. |
| "Sumário Sistemas" | **Confere.** **Corrigido:** arquivo criado. O inventário agora lista os 20 sistemas do Hub. |

### Seção 5 — Proposta "lugar oficial"
Concordo com a regra e com a ordem. Observação: "nada agora" vale para apagar ou renomear tabela. **Sugiro adiantar** a decisão de lugar oficial e a limpeza das cópias de funções.

### Pauta — prioridade 1
| # | Item | Resposta |
|---|---|---|
| 1 | Importador procura cliente sem o tipo | **Confere e corrigido** (ver topo). |
| 2 | 12 vendas com cliente errado | **Confere e corrigido** (ver topo). A pergunta "as outras 11 vão para o cadastro de cliente da mesma pessoa?" tinha resposta no próprio banco: existe cadastro tipo cliente com o mesmo código da Connect para todas. Já foram. |
| 3 | Metalúrgica IL ligada à Interlight | **Confere** em parte: não existe cadastro de fornecedor da Metalúrgica IL. Falta criar e religar as duplicatas (financeiro, aguarda aprovação). |
| 4 | Diferenças Connect × sistema | **Atualização:** ontem (09/11) acertei 9923 e 10106; hoje (10/11) acertei **12761, 12395 e 12135** para bater com a Connect (prints). Detalhe: 12135 teve 30 un. movidas de Reserva para Entrega Futura nas vendas 5882, 4865 e 5619, conforme a lista de "necessidade suprida". Também liberei as vendas 4907 e 4908 para separação (SPEC-267). Peças 7365, 8952, 13653 e as vendas 2299 e 6021 seguem pendentes. |
| 5 | Pedidos da Connect sem itens | **Parcial:** hoje são **76 de 95** pedidos aprovados, quase igual ao "80 de 90". Risco de comprar duas vezes é real. O botão de completar por PDF existe no Compras. |

### Prioridade 2
| # | Item | Resposta |
|---|---|---|
| 6 | Criar projeto: CRM exige demais | Concordo com mínimo = nome + Estado e o resto "a completar". É decisão de processo. |
| 7 | Orçamento exige código do projeto | **Confere:** 31 dos 35 rascunhos sem projeto. Regra combinada é cliente obrigatório e projeto só se existir. |
| 8 | Número de orçamento repetido | **Confere e é pior:** MANOELLA tem ORC-0004 ×2 e ORC-0005 ×3. Erro real de geração de número; precisa de migration. |
| 9 | Devoluções | Ver seção 2. |
| 10 | Acessos e papéis | **Confere** para a Moara (0 acessos e 0 papéis). Concordo em revisar os papéis antigos e os nomes fixos em funções do banco. |
| 11 | `.env` de Compras e Dashboard | **Confere.** Ver seção 1. |

### Prioridade 3 e histórico
Concordo. Documento do cliente (CPF/CNPJ) será exigido na etapa de nota e boleto; a SPEC-239 já cuida disso.

## Parte C — O que veio da reunião de 10/11 e entra nesta conversa
- **Uso e consumo sem financeiro:** a decisão foi seguir todas as etapas, incluindo a aprovação financeira com valor zero e texto, para gerar a venda e o histórico de quem aprovou. Exceção só para esse tipo, não gera cobrança.
- **Ajuste manual de estoque:** o Filippo pediu que seja previsto e registrado. Hoje o kardex registra a movimentação sozinho, mas **não guarda o motivo**. Proposta: tela de ajuste manual com motivo obrigatório (o mesmo desenho da liberação manual da SPEC-267).
- **Conferência diária às 8h:** rotina automática que envia o relatório do que não bate com a Connect.

## Decisões que preciso de vocês
1. Aprovar a lista "lugar oficial" por informação (Parte B, seção 5).
2. Autorizar a limpeza das cópias velhas de funções de servidor.
3. Funcionários: `funcionarios` como oficial?
4. Número de orçamento repetido: posso fazer a SPEC para gerar o número por empresa e renumerar os duplicados?
5. Devolução: qual caminho único?
6. Ajuste manual de estoque com motivo: posso fazer SPEC?
