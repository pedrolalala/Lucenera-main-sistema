# Escopo — Sistema de TI

## Versao atual

Nao foi identificado um diretorio local exclusivo do Sistema de TI nesta rodada. Existem responsabilidades administrativas que podem ter sido iniciadas dentro do pacote da Central, mas a decisao de 24/06/2026 e tratar Hub/Central e Sistema de TI como sistemas diferentes.

O Sistema de TI pode reaproveitar componentes, telas ou migrations ja existentes na Central, desde que a fronteira final fique clara: o Hub e a porta de entrada dos usuarios; TI e a ferramenta administrativa do ecossistema.

**Decisao de fronteira de implementacao em 25/06/2026 (resolve SPEC-TI-10):** Hub/Central e Sistema de TI serao **sistemas separados**, cada um com seu proprio diretorio/repositorio. Nao havera um unico pacote dividido por tela. A Central foca em produtividade pessoal e catalogo de acesso; o Sistema de TI foca em permissao, seguranca, saude e auditoria de todo o ecossistema — inclusive da propria Central e de si mesmo.

## Objetivo da evolucao

Criar um sistema administrativo de TI para:

- administrar catalogo de sistemas;
- configurar modulos, acoes, ambientes e URLs;
- controlar papeis, permissoes e excecoes individuais;
- acompanhar saude dos sistemas;
- registrar atualizacoes manuais de incidente, degradacao e manutencao;
- monitorar integracoes e execucoes;
- auditar alteracoes administrativas;
- publicar contratos consumidos pelo Hub e pelos demais aplicativos.

O Sistema de TI nao sera CRM, financeiro, estoque, logistica, RH, BI geral ou central de tarefas operacionais.

## SPEC-TI-01 — Catalogo configuravel de sistemas

**Achado:** a Central ja consulta `systems`, mas a administracao do catalogo ainda nao esta completa como produto separado.

**Evolucao:** permitir que a TI crie, edite, ordene, ative ou desative sistemas pela interface do Sistema de TI.

**Justificativa:** um novo sistema ou mudanca de URL nao deve exigir alteracao e publicacao de codigo.

**Relacao com o banco:** consolidar `systems` como tabela inicial do catalogo e criar extensoes para ambientes, modulos, acoes e responsaveis. Registrar nome, descricao, icone, URL, ambiente, criticidade, versao, situacao, prioridade de mapeamento e ordem.

**Acao a ser realizada:** criar tela administrativa para editar `systems` e estruturas complementares sem criar um segundo cadastro de sistemas.

**Criterio de aceite:** a TI cadastra um sistema e ele aparece no Hub sem nova publicacao do frontend.

## SPEC-TI-02 — Modulos e acoes

**Achado:** os aplicativos possuem rotas e capacidades proprias, mas o controle central precisa enxergar essas capacidades como modulos e acoes.

**Evolucao:** cadastrar modulos e acoes por sistema para apoiar permissao, auditoria e documentacao.

**Justificativa:** permissao por sistema inteiro e insuficiente para operacao real.

**Relacao com o banco:** `sistema_modulos`, `modulo_acoes` e vinculos com `systems`.

**Acao a ser realizada:** criar cadastro de modulos/acoes com chaves estaveis usadas pelos aplicativos.

**Criterio de aceite:** um aplicativo consegue perguntar se o usuario pode executar uma acao especifica.

## SPEC-TI-03 — Papeis e permissoes configuraveis

**Achado:** os sistemas possuem verificacoes e tabelas de papel proprias.

**Evolucao:** criar papeis configuraveis com acesso por sistema, modulo e acao, com duas camadas de granularidade decididas em 25/06/2026:

1. **Escopo de visibilidade**: o papel pode ver o sistema inteiro ("ver tudo") ou apenas um subconjunto de modulos/abas especificas.
2. **Escopo de acao**: dentro de cada modulo liberado, a permissao e concedida separadamente por acao — `criar`, `editar`, `deletar` (e `visualizar`, quando aplicavel) — nao um unico toggle de acesso.

**Justificativa:** centraliza a administracao e evita regras diferentes para o mesmo usuario; um papel "ver tudo, sem editar" e diferente de um papel "editar so um modulo".

**Relacao com o banco:** `papeis`, `permissoes`, `papel_permissoes`, `usuario_papeis`, `sistema_modulos` e `modulo_acoes`. `papel_permissoes` deve guardar a combinacao sistema + modulo (ou "todos os modulos") + acao.

**Acao a ser realizada:** criar matriz visual de permissoes que combine sistema, modulo/aba e acao (criar/editar/deletar/visualizar), com opcao de "acesso total ao sistema", e contrato comum de consulta para todos os aplicativos.

**Criterio de aceite:** uma alteracao feita no Sistema de TI e refletida no acesso ao modulo e a acao correspondente; e possivel criar um papel que ve tudo mas só edita um modulo especifico.

## SPEC-TI-04 — Excecoes individuais

**Achado:** alguns usuarios precisam de acesso diferente do papel padrao.

**Evolucao:** permitir concessao ou restricao individual, com justificativa e validade opcional.

**Justificativa:** evita criar um novo papel para cada excecao.

**Relacao com o banco:** `usuario_permissao_excecoes`, relacionada a usuario, sistema, modulo e acao.

**Acao a ser realizada:** criar interface de excecoes e definir precedencia clara entre papel e regra individual.

**Criterio de aceite:** a TI consegue conceder ou negar uma acao especifica sem alterar o papel dos demais usuarios.

## SPEC-TI-05 — Saude dos sistemas

**Achado:** o ecossistema ainda nao possui uma visao unica de disponibilidade e atualizacao.

**Evolucao:** configurar verificacoes automaticas de aplicacao, banco e ultima sincronizacao.

**Justificativa:** TI precisa identificar rapidamente indisponibilidade ou integracao parada.

**Relacao com o banco:** `sistema_health_checks`, `sistema_health_events` e estado resumido no sistema/ambiente.

**Acao a ser realizada:** criar executores de checks configuraveis e uma tela com estados `saudavel`, `degradado`, `indisponivel` e `sem verificacao`.

**Criterio de aceite:** o Sistema de TI mostra ultima execucao, resultado, latencia e mensagem resumida de cada check.

## SPEC-TI-06 — Atualizacao manual de saude

**Achado:** algumas condicoes operacionais nao podem ser detectadas automaticamente.

**Evolucao:** permitir que a TI marque manualmente manutencao, degradacao ou incidente.

**Justificativa:** o estado exibido precisa refletir tambem situacoes conhecidas pela equipe.

**Relacao com o banco:** evento manual ligado ao sistema, ambiente, usuario, motivo, inicio e encerramento.

**Acao a ser realizada:** criar comando de atualizacao manual sem apagar o resultado dos checks automaticos.

**Criterio de aceite:** o historico diferencia claramente estado automatico de atualizacao manual.

## SPEC-TI-07 — Monitoramento das integracoes

**Achado:** importacoes e automacoes atuais nao possuem uma visao unica de sucesso, falha ou volume.

**Evolucao:** mostrar a ultima execucao das integracoes relevantes.

**Justificativa:** uma aplicacao pode estar online enquanto sua sincronizacao esta parada.

**Relacao com o banco:** `integracoes`, `integracao_execucoes`, contadores de lidos, inseridos, atualizados, rejeitados e mensagem de erro.

**Acao a ser realizada:** padronizar o registro das execucoes e apresentar historico por integracao.

**Criterio de aceite:** TI identifica qual integracao falhou e qual lote ou periodo foi afetado.

## SPEC-TI-08 — Auditoria administrativa

**Achado:** alteracoes de URL, sistema, permissao e excecao precisam ser rastreaveis.

**Evolucao:** manter historico das mudancas feitas pela TI.

**Justificativa:** facilita suporte, revisao e reversao de configuracoes.

**Relacao com o banco:** `auditoria_configuracoes` ou eventos especificos com entidade, antes, depois, autor e data.

**Acao a ser realizada:** registrar automaticamente todas as alteracoes administrativas relevantes.

**Criterio de aceite:** e possivel identificar quem alterou uma permissao ou cadastro e quais valores foram modificados.

## SPEC-TI-09 — Contratos para Hub e aplicativos

**Achado:** cada aplicativo tende a implementar sua propria leitura de papel e configuracao.

**Evolucao:** publicar contratos claros para catalogo, autorizacao, saude e auditoria.

**Justificativa:** a separacao entre Hub e TI so funciona se os demais sistemas consumirem uma fonte comum.

**Relacao com o banco:** views, RPCs ou endpoints controlados sobre `systems`, permissoes, eventos de saude e auditoria.

**Acao a ser realizada:** definir os contratos minimos: listar sistemas permitidos, verificar acao permitida, registrar evento de acesso, consultar saude resumida e registrar execucao de integracao.

**Criterio de aceite:** CRM, RH, Logistica e Hub conseguem usar a mesma regra de permissao sem copiar matriz local.

## SPEC-TI-10 — Fronteira de implementacao [decidido em 25/06/2026]

**Achado:** ainda nao ha pasta local dedicada para TI dentro de `Sistema/`.

**Decisao:** o Sistema de TI sera **sistema separado**, com repositorio/pasta propria — nao um modulo dentro da Central. A Central pode servir de base tecnica temporaria (telas/componentes reaproveitados), mas o produto final e dois sistemas distintos.

**Justificativa:** para o mapeamento, Hub e TI sao produtos diferentes mesmo que uma fase tecnica reaproveite codigo; a separacao reduz acoplamento e deixa a governanca de permissao isolada do app de uso diario.

**Relacao com o banco:** pode usar as mesmas tabelas administrativas, desde que a propriedade funcional fique documentada.

**Acao a ser realizada:** criar o diretorio/repositorio proprio do Sistema de TI e registrar no indice do portfolio (`00_INDICE.md` e `04_ADENDO_ATUALIZACAO_24_06_2026.md`).

**Criterio de aceite:** o usuario acessa Hub e TI como sistemas distintos, com objetivos, URLs e permissoes separados.

## SPEC-TI-11 — Gestao administrativa de credencial de usuario

**Achado:** hoje, alteracao de senha e e-mail acontece de forma dispersa ou nao existe fluxo administrativo claro; o Hub trata apenas autoatendimento de perfil (SPEC-HUB-12).

**Evolucao:** o Sistema de TI administra a credencial do usuario — reset de senha, alteracao de e-mail e bloqueio/reativacao de conta — para todos os usuarios de todos os sistemas, incluindo usuarios da Central e do proprio Sistema de TI.

**Justificativa:** decisao de 25/06/2026 — identidade e credencial sao governanca, nao autoatendimento de perfil; devem ficar no mesmo lugar que define permissao.

**Relacao com o banco:** usuario canonico (Supabase Auth) e qualquer tabela complementar de identidade; toda alteracao administrativa de credencial deve gerar evento de auditoria (ver SPEC-TI-08).

**Acao a ser realizada:** criar tela administrativa de usuario com acoes de reset de senha, alteracao de e-mail e bloqueio/reativacao, distinta da tela de perfil pessoal do Hub.

**Criterio de aceite:** um administrador de TI altera a senha/e-mail de qualquer usuario de qualquer sistema sem precisar de acesso direto ao banco, e a alteracao fica registrada na auditoria.

## SPEC-TI-12 — Historico de acesso e atividade por sistema

**Achado:** o evento de acesso do Hub (SPEC-HUB-06) registra abertura/bloqueio de sistema, mas nao existe uma visao consolidada de atividade do usuario dentro de cada sistema.

**Evolucao:** manter historico de acesso (login, abertura de sistema) e de atividade relevante (acoes de criar/editar/deletar executadas) por usuario e por sistema.

**Justificativa:** suporte, investigacao de incidente e conformidade exigem saber quem fez o que, onde e quando, em qualquer um dos sistemas do ecossistema.

**Relacao com o banco:** eventos de acesso (consumidos do contrato do Hub) e eventos de atividade publicados pelos aplicativos ao executar acoes sensiveis, ambos com usuario, sistema, modulo, acao, resultado e horario.

**Acao a ser realizada:** definir o contrato de publicacao de evento de atividade (alem do evento de acesso ja definido em SPEC-HUB-06/TI-09) e criar tela de consulta por usuario ou por sistema.

**Criterio de aceite:** a TI abre o historico de um usuario especifico e ve login, sistemas acessados e acoes relevantes executadas em cada um.

## SPEC-TI-13 — Auto-governanca: TI e Central tambem sao sistemas regidos

**Achado:** existe risco de Central e o proprio Sistema de TI ficarem fora das regras que eles mesmos administram, por serem a base tecnica/administrativa.

**Evolucao:** as regras de permissao, saude e auditoria definidas pelo Sistema de TI aplicam-se a todos os sistemas do ecossistema sem excecao, inclusive a Central e ao proprio Sistema de TI.

**Justificativa:** decisao explicita de 25/06/2026 — nenhum sistema fica fora da governanca, mesmo sendo quem a administra.

**Relacao com o banco:** Central e Sistema de TI devem ter registro proprio em `systems`/`sistema_modulos`/`modulo_acoes`, como qualquer outro sistema do portfolio.

**Acao a ser realizada:** garantir que o cadastro de modulos/acoes e a matriz de permissao cubram tambem os modulos internos da Central e do Sistema de TI (por exemplo, "quem pode editar papeis" e por si so uma permissao auditavel).

**Criterio de aceite:** e possivel restringir o acesso de um administrador de TI a apenas parte das funcoes do proprio Sistema de TI, e o acesso a modulos da Central tambem passa pela mesma matriz.

## SPEC-TI-14 — Sistemas monitorados/regidos versus sistemas exibidos como card

**Achado:** o conjunto de sistemas sob governanca de permissao/saude/auditoria do TI (todos, inclusive Central e o proprio TI, ver SPEC-TI-13) nao e necessariamente o mesmo conjunto de sistemas que devem aparecer como card na Central — a Central, por exemplo, ja nao aparece como card de si mesma.

**Evolucao:** modelar explicitamente dois atributos distintos por sistema cadastrado: (a) esta sob governanca/monitoramento do TI; (b) deve aparecer como card na Central, e para quais papeis.

**Justificativa:** evita decisao implicita ou hardcoded sobre o que aparece no catalogo da Central; um sistema pode precisar de permissao e saude monitoradas sem precisar de card (caso do proprio TI, por exemplo, se o acesso a ele for direto e nao via card), e vice-versa.

**Relacao com o banco:** estender `systems` (ou tabela equivalente) com um indicador de visibilidade de card (e, quando relevante, por papel) separado do indicador de governanca/monitoramento, que e sempre verdadeiro para todos os sistemas cadastrados.

**Acao a ser realizada:** ajustar o cadastro de sistemas para registrar os dois atributos separadamente e revisar a consulta usada pelo Hub (SPEC-HUB-01) para filtrar apenas pelo atributo de visibilidade de card.

**Criterio de aceite:** desativar o card de um sistema na Central nao remove suas regras de permissao/saude/auditoria do Sistema de TI, e vice-versa.

## Fundamentacao

- `Sistema/central-lucenera-dashboard-1c9ba/supabase/migrations/20260624160000_update_active_systems_portfolio.sql`
- `Versao Final - Lucenera/04_ADENDO_ATUALIZACAO_24_06_2026.md`
- `Versao Final - Lucenera/Escopos/01_ESCOPO_HUB_TI.md`
