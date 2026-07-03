# Escopo — Hub / Central

## Versao atual

Pacote analisado: `central-lucenera-dashboard-1c9ba`  
Versao declarada apos atualizacao: `0.0.14`

O sistema atual possui autenticacao e uma tela com cartoes que abrem os demais aplicativos. A versao atual ja consulta a tabela `systems` no Supabase para exibir nome, descricao, icone, URL e ordem dos sistemas.

Na fotografia administrativa de 23/06, existiam 7 registros em `systems`. Em 24/06, foi criada migration para orientar o catalogo-alvo com cards externos para Administracao Bancaria, Cadastro, CRM, Gestao Financeira, Sistema de Entregas, RH, Ubiqua e PowerPoint. A Central conta como sistema do portfolio, mas nao precisa aparecer como card de si mesma.

Decisao complementar de 24/06: Hub/Central e Sistema de TI sao sistemas diferentes. O Hub e a porta de entrada dos usuarios. O Sistema de TI administra catalogo, permissoes, saude, integracoes e auditoria. Caso a implementacao atual possua telas administrativas dentro da Central, elas devem ser tratadas como base tecnica temporaria para separacao, nao como fronteira final do produto.

Decisao de fronteira de implementacao em 25/06/2026: Hub/Central e Sistema de TI serao **sistemas separados** (repositorio/pasta proprios cada um), nao um modulo unico dividido por tela. A Central concentra produtividade pessoal e abertura dos demais sistemas; o Sistema de TI concentra governanca, permissao e seguranca. Essa decisao resolve a pendencia registrada em `10_ESCOPO_SISTEMA_TI.md` (SPEC-TI-10).

## Objetivo da evolucao

Transformar o Hub em uma porta de entrada operacional e de produtividade pessoal para:

- exibir os sistemas autorizados ao usuario (cards);
- abrir os sistemas com URLs e ambientes corretos;
- mostrar status resumido recebido do Sistema de TI;
- respeitar permissao central sem administrar permissao dentro do Hub;
- concentrar tarefas/pendencias pessoais, mural, calendario, perfil e diretorio de colaboradores (modulos mapeados na decisao de roadmap de 22/06/2026, detalhados nas SPECs HUB-07 a HUB-12);
- manter uma experiencia simples de entrada no ecossistema Lucenera.

O Hub nao sera sistema de processos de negocio, BI executivo geral, ou ferramenta administrativa de permissao/seguranca — isso pertence ao Sistema de TI.

## SPEC-HUB-01 — Catalogo consumido do Sistema de TI

**Achado:** os cartoes deixaram de ser apenas uma lista fixa e passaram a ler `systems`, mas a administracao completa do catalogo pertence ao Sistema de TI.

**Evolucao:** o Hub deve consumir o catalogo publicado pelo Sistema de TI, sem duplicar cadastro de sistemas.

**Justificativa:** um novo sistema ou mudanca de URL deve aparecer no Hub sem publicacao do frontend, mas a governanca dessa mudanca pertence a TI.

**Relacao com o banco:** `systems` permanece como ponto de partida do catalogo. Ambientes, modulos, acoes, responsaveis, versoes, criticidade e prioridade de mapeamento sao administrados no Sistema de TI.

**Acao a ser realizada:** manter a consulta atual a `systems` e substituir qualquer configuracao local por contrato publicado pelo Sistema de TI.

**Criterio de aceite:** a TI cadastra ou altera um sistema e o Hub reflete a mudanca sem novo deploy do Hub.

## SPEC-HUB-02 — Cartoes por permissao

**Achado:** os cartoes podem aparecer para todos os usuarios autenticados se o filtro de permissao nao estiver aplicado.

**Evolucao:** mostrar somente sistemas liberados ao usuario pelo contrato central de autorizacao.

**Justificativa:** o Hub deve ser a entrada do usuario, nao uma lista tecnica completa.

**Relacao com o banco:** consulta consolidada entre usuario, papeis, excecoes e sistemas ativos, mantida pelo Sistema de TI.

**Acao a ser realizada:** filtrar os cartoes pelo contrato de permissao e registrar tentativas de acesso negadas.

**Criterio de aceite:** dois usuarios com papeis diferentes visualizam conjuntos diferentes de sistemas.

## SPEC-HUB-03 — Abertura dos sistemas

**Achado:** o Hub ja abre aplicativos por URL, mas essa URL precisa acompanhar ambiente, rota e situacao do sistema.

**Evolucao:** abrir o sistema correto usando URL publicada, ambiente valido e, quando necessario, parametros de contexto.

**Justificativa:** alteraçoes de dominio, subdominio ou rota inicial nao devem exigir edicao manual em varios pontos.

**Relacao com o banco:** URL e ambiente publicados pelo catalogo administrado no Sistema de TI.

**Acao a ser realizada:** tratar URLs inativas, manutencao e fallback de ambiente antes de redirecionar o usuario.

**Criterio de aceite:** um sistema desativado ou em manutencao nao e aberto como se estivesse disponivel.

## SPEC-HUB-04 — Saude resumida somente leitura

**Achado:** o Hub atual nao sabe se um sistema esta disponivel ou atualizado.

**Evolucao:** exibir no card um estado resumido produzido pelo Sistema de TI.

**Justificativa:** o usuario precisa saber se um sistema esta indisponivel antes de tentar acessar, mas o Hub nao deve executar checks tecnicos.

**Relacao com o banco:** estado resumido de `sistema_health_checks` e `sistema_health_events`, administrados pelo Sistema de TI.

**Acao a ser realizada:** consumir o resumo de saude e apresentar estados como `saudavel`, `degradado`, `indisponivel` e `sem verificacao`.

**Criterio de aceite:** o Hub mostra o estado atual sem possuir executor proprio de health check.

## SPEC-HUB-05 — Sessao e identidade

**Achado:** acesso ao Hub e acesso aos sistemas dependem da mesma identidade operacional.

**Evolucao:** o Hub deve identificar o usuario, carregar suas permissoes e encaminhar o acesso sem criar regras paralelas de identidade.

**Justificativa:** usuario, papel e acesso precisam ser coerentes em todos os aplicativos.

**Relacao com o banco:** usuario canonico e contrato de autorizacao mantidos pelo Sistema de TI.

**Acao a ser realizada:** remover criacao ou manutencao local de papeis no Hub, deixando somente consumo de identidade e autorizacao.

**Criterio de aceite:** alterar acesso no Sistema de TI muda a experiencia do usuario no Hub.

## SPEC-HUB-06 — Evento de acesso

**Achado:** abertura e tentativa negada de sistema precisam ser rastreaveis.

**Evolucao:** registrar eventos de acesso gerados pelo Hub em estrutura central de auditoria.

**Justificativa:** facilita suporte e revisao de acesso sem transformar o Hub em ferramenta de auditoria.

**Relacao com o banco:** eventos de auditoria pertencentes ao Sistema de TI, contendo usuario, sistema, resultado, horario e origem.

**Acao a ser realizada:** emitir evento ao abrir sistema e ao bloquear acesso.

**Criterio de aceite:** TI consegue consultar quem tentou acessar qual sistema, quando e com qual resultado.

## SPEC-HUB-07 — Tarefas e pendencias centrais

**Achado:** hoje nao existe um lugar unico para o usuario ver o que precisa fazer; pendencias ficam espalhadas em cada sistema.

**Evolucao:** criar um to-do central que reuna tarefas proprias, tarefas atribuidas por gestor e tarefas geradas automaticamente por pendencia de outro sistema (por exemplo, NF pendente no Financeiro, recebimento divergente no Estoque/Compras), cada uma com deep link de volta ao registro de origem no sistema correspondente.

**Justificativa:** decisao de roadmap de 22/06/2026 — o Hub deixa de ser apenas launcher e passa a ser o ponto de entrada diario de trabalho.

**Relacao com o banco:** tarefa central referenciando sistema de origem, tipo, responsavel, prazo e link/identificador do registro original. Os demais sistemas publicam o evento de pendencia; o Hub nao recalcula a regra de negocio.

**Acao a ser realizada:** criar o modelo de tarefa central e o contrato de publicacao de pendencia que qualquer sistema (incluindo o proprio Sistema de TI) pode usar para gerar uma tarefa no Hub.

**Criterio de aceite:** uma pendencia criada em outro sistema aparece na lista de tarefas do responsavel correto no Hub, com link que abre o registro de origem.

## SPEC-HUB-08 — Mural de avisos e aniversarios

**Achado:** avisos internos e aniversarios hoje circulam por canais informais.

**Evolucao:** criar mural simples de avisos administrativos e aniversarios do mes.

**Justificativa:** ideia proposta e aceita no roadmap de 22/06/2026; baixo risco e alto valor percebido.

**Relacao com o banco:** avisos com autor, publico-alvo, data de publicacao/expiracao; data de aniversario lida do cadastro de colaborador (RH).

**Acao a ser realizada:** criar tela de mural com publicacao restrita a papel administrativo e leitura para todos os usuarios autorizados.

**Criterio de aceite:** um aviso publicado aparece para o publico-alvo configurado e some apos a expiracao.

## SPEC-HUB-09 — Caixa de aprovacoes pendentes cross-sistema

**Achado:** aprovacoes (orcamento, pedido de compra, ferias, etc.) hoje exigem que o usuario abra cada sistema separadamente para saber o que esta esperando por ele.

**Evolucao:** consolidar em uma caixa unica as aprovacoes pendentes de qualquer sistema para o usuario logado, com deep link para a tela de decisao no sistema de origem.

**Justificativa:** reduz a chance de uma aprovacao ficar esquecida por falta de visibilidade.

**Relacao com o banco:** contrato de publicacao de "pendencia de aprovacao" por sistema, similar ao de HUB-07, mas com semantica especifica de decisao (aprovar/rejeitar).

**Acao a ser realizada:** definir o contrato comum de aprovacao pendente e consumir nos sistemas que ja possuem fluxo de aprovacao (Orcamentos, Estoque/Compras, RH).

**Criterio de aceite:** uma aprovacao pendente em qualquer sistema integrado aparece na caixa do aprovador certo, sem que ele precise abrir cada sistema para descobrir isso.

## SPEC-HUB-10 — Diretorio de colaboradores e busca global

**Achado:** encontrar o contato ou responsavel certo hoje depende de perguntar ou abrir o RH.

**Evolucao:** criar diretorio de colaboradores com busca por nome, cargo, sistema/area e dados de contato basicos.

**Justificativa:** ideia proposta e aceita no roadmap de 22/06/2026; apoia o restante do ecossistema sem duplicar cadastro.

**Relacao com o banco:** leitura de `funcionarios_novo`/usuario canonico; sem escrita.

**Acao a ser realizada:** criar tela de busca somente leitura sobre os dados oficiais de colaborador.

**Criterio de aceite:** buscar por nome ou area encontra o colaborador certo sem abrir o RH.

## SPEC-HUB-11 — Calendario central

**Achado:** compromissos de diferentes sistemas (entregas da Logistica, prazos de compra, ferias do RH) nao tem visao unificada.

**Evolucao:** criar calendario central que agregue eventos relevantes publicados pelos demais sistemas.

**Justificativa:** decisao de roadmap de 22/06/2026.

**Relacao com o banco:** contrato de evento de calendario (data, tipo, sistema de origem, link) publicado pelos sistemas participantes.

**Acao a ser realizada:** definir o contrato de evento de calendario e consumir nos sistemas que ja possuem datas relevantes (Logistica, RH, Estoque/Compras).

**Criterio de aceite:** um evento criado em outro sistema aparece no calendario central do usuario correto.

## SPEC-HUB-12 — Perfil pessoal e dashboard individual

**Achado:** configuracoes de conta (foto, nome) e visao de desempenho pessoal hoje nao tem lugar central; PowerBI executivo nao deve ser exibido para todo usuario.

**Evolucao:** criar tela de perfil para autoatendimento (foto, nome; alteracao de senha/e-mail delega para o Sistema de TI, que e quem administra credencial) e um dashboard pessoal simples com dados do proprio usuario conforme permissao. PowerBI/BI executivo fica restrito a papel de gestor/diretoria.

**Justificativa:** ajuste do roadmap de 22/06/2026 — BI geral nao e para todo mundo; cada usuario comum ve um recorte pessoal, nao o executivo.

**Relacao com o banco:** dados de perfil do usuario canonico (leitura/edicao de atributos nao-credenciais) e views pessoais filtradas por permissao.

**Acao a ser realizada:** separar claramente o que e autoatendimento de perfil (Hub) do que e gestao administrativa de credencial (Sistema de TI, ver SPEC-TI-11). Restringir o widget de PowerBI por papel.

**Criterio de aceite:** um usuario comum ve seu dashboard pessoal e edita nome/foto; alteracao de senha/e-mail e tratada pelo Sistema de TI; somente gestor/diretoria ve o PowerBI executivo.

## Itens pertencentes ao Sistema de TI

Os itens abaixo nao pertencem ao escopo final do Hub. Eles estao descritos em `10_ESCOPO_SISTEMA_TI.md`:

- cadastro e edicao completa de sistemas;
- matriz de papeis e permissoes, com granularidade de "ver tudo" vs. abas/funcoes especificas e por acao (criar/editar/deletar);
- excecoes individuais;
- executores de health check;
- atualizacao manual de saude;
- monitoramento de integracoes;
- auditoria administrativa;
- administracao de modulos, acoes, ambientes e responsaveis;
- gestao administrativa de credencial de usuario (reset de senha e e-mail);
- historico de acesso e atividade do usuario por sistema;
- definicao de quais sistemas sao monitorados/regidos por permissao (todos, inclusive a Central e o proprio Sistema de TI) versus quais sistemas aparecem como card na Central (subconjunto configuravel).

## Fundamentacao

- `Sistema/central-lucenera-dashboard-1c9ba/src/pages/Dashboard.tsx`
- `Sistema/central-lucenera-dashboard-1c9ba/supabase/migrations/20260624160000_update_active_systems_portfolio.sql`
- `Versao Final - Lucenera/04_ADENDO_ATUALIZACAO_24_06_2026.md`
