# Tasks Gerais do Ecossistema Lucenera

Data de consolidação: 25 de junho de 2026

Atualizado com o [Adendo de 03/07/2026](../06_ADENDO_ATUALIZACAO_03_07_2026.md) e com a reunião 08 de 06/07/2026, que consolidou estoque reservado/estoque de cliente como linguagem de tela, transferência de reservas, entrega futura e necessidade de compra.

Este documento reúne **todas as tasks necessárias para colocar o ecossistema Lucenera em operação completa**, cruzando:

- o [Relatório Geral Final](../01_RELATORIO_GERAL_FINAL.md);
- o [Relatório do Banco de Dados](../02_RELATORIO_BANCO_DE_DADOS.md) e seus grupos de migration M00–M12;
- os adendos de [23/06](../03_ADENDO_ATUALIZACAO_23_06_2026.md), [24/06](../04_ADENDO_ATUALIZACAO_24_06_2026.md) e [regras dos Vídeos Connect](../05_ADENDO_REGRAS_VIDEOS_CONNECT.md);
- os 10 [Escopos](../Escopos/) por sistema;
- a [SPEC-001](SPECs/SPEC-001_Aprovacao_Orcamento_para_Administracao_Bancaria.md), já implementada, e os desdobramentos [SPEC-002](SPECs/SPEC-002_Prazo_Inicio_Cobranca_Orcamento.md), [SPEC-003](SPECs/SPEC-003_Validacao_Coleta_Frete_Orcamento.md), [SPEC-004](SPECs/SPEC-004_Auditoria_Parcelas_Orcamento_Aprovado.md) e [SPEC-005](SPECs/SPEC-005_Remocao_Triggers_Legados_Bloqueio_Aprovacao.md);
- a [SPEC-006](SPECs/SPEC-006_Permissoes_Granulares_no_Hub.md) (permissões granulares no Hub, V1 de `TI-02/03/04/08/13`), a [SPEC-007](SPECs/SPEC-007_Token_Acesso_Compartilhado_Entre_Sistemas.md) (token de acesso compartilhado entre sistemas) e a [SPEC-008](SPECs/SPEC-008_Conciliacao_Retorno_Bancario_Baixa_Parcelas.md) (conciliação de retorno bancário e baixa automática de parcelas), todas escritas em 26/06/2026 e ainda não implementadas;
- o [Adendo de 03/07/2026](../06_ADENDO_ATUALIZACAO_03_07_2026.md), que registra 7 novos grupos de migration no banco central (`20260630_010` a `20260702_016` — reserva de estoque na aprovação, cancelamento de orçamento, comissão por equipe) e o fluxo de aprovação financeira implementado em Orçamentos entre 26/06 e 03/07/2026;
- as SPECs consolidadas em 06/07/2026: [SPEC-009](SPECs/SPEC-009_Aprovacao_Cliente_Orcamento.md) (aprovação do cliente no orçamento, aplicada no banco e supersedida pela normalização da SPEC-016), [SPEC-010](SPECs/SPEC-010_Saldos_Estoque_por_Item_de_Projeto.md) (saldos operacionais por item de projeto), [SPEC-011](SPECs/SPEC-011_Transferencia_Reserva_Entre_Itens_de_Projeto.md) (transferência entre itens de projeto), [SPEC-012](SPECs/SPEC-012_Entrega_Futura_Necessidade_Compra.md) (entrega futura e necessidade de compra), [SPEC-013](SPECs/SPEC-013_Rastreabilidade_Reserva_Estoque_Por_Projeto.md) (complemento absorvido pela SPEC-010), [SPEC-014](SPECs/SPEC-014_Aba_Itens_Aprovados_CRM.md) (itens aprovados no CRM), [SPEC-015](SPECs/SPEC-015_Devolucao_Estoque_por_Item_de_Projeto.md) (devolução por item de projeto), [SPEC-016](SPECs/SPEC-016_Normalizacao_Aprovacao_Financeira_Orcamento.md) (normalização da aprovação financeira aplicada no banco e UI), [SPEC-017](SPECs/SPEC-017_Modal_Unificado_Aprovacao_Financeira_Orcamento.md) (modal/fluxo financeiro unificado por orçamento implementado em homologação) e [SPEC-018](SPECs/SPEC-018_Criar_Produto_no_Modal_de_Orcamento.md) (criação de produto dentro do orçamento implementada em homologação);
- e a conferência direta do código em `Sistema/` (migrations aplicadas, versões de pacote, presença/ausência de tabelas e arquivos) em 25/06/2026, com atualização pontual em 03/07/2026 para os itens citados no adendo acima.

## Como usar este documento

Cada task tem um identificador (`SPEC-XXX-NN` quando vem de um Escopo, ou `M0N` quando vem de um grupo de migration) e um status:

| Marcação | Significado |
|---|---|
| `[x]` **Concluído** | Implementado e confirmado no código/banco atual |
| `[~]` **Parcial** | Implementação iniciada, mas incompleta ou precisa de ajuste |
| `[ ]` **Pendente** | Ainda não iniciado |
| `[ ]` **Bloqueado por decisão** | Não pode avançar sem uma escolha do cliente/equipe (ver seção 6) |

Quando uma task foi concluída por uma SPEC específica (como a SPEC-001), isso é citado explicitamente, com o caminho do arquivo. Ao escrever uma nova SPEC detalhada para qualquer item abaixo, marque a task correspondente como concluída/parcial e adicione a referência, no mesmo padrão da SPEC-001.

Esta é uma fotografia em 25/06/2026. Antes de assumir um status como verdade absoluta, confira o código atual — sistemas mudam de versão com frequência neste projeto.

## 1. Visão por fase (substituição do Connect)

Da seção 6 do Relatório Geral Final.

- [x] **Fase 1 — Preparar a base**: fotografia administrativa do Supabase (23/06) e conferência da planilha `Vendas 01012025 a 23062026.xlsx` concluídas. Falta o framework de importação repetível (ver M01).
- [ ] **Fase 2 — Projetos e itens vendidos**: pendente. `projeto_itens` segue vazio fora do fluxo novo de aprovação; a carga histórica da planilha de vendas não foi promovida.
- [ ] **Fase 3 — CRM configurável**: pendente. Nenhuma tabela de fluxo versionado (`crm_fluxos`, `crm_etapas`, `crm_substatus`) existe no banco.
- [ ] **Fase 4 — Estoque e Compras**: pendente. O sistema ainda não existe — nenhuma pasta, nenhuma tabela `pedido_compra`/`solicitacoes_compra` populada.
- [~] **Fase 5 — Financeiro**: parcial. O ciclo orçamento → projeto_itens → parcelas → boletos já funciona para orçamentos aprovados no novo sistema (SPEC-001), mas CP/CR ainda estão em staging bruto, e a operação diária ainda depende de planilhas/Connect para a maior parte do histórico.
- [ ] **Fase 6 — Logística e corte**: pendente. Sem data de corte definida (decisão D08 — não há prazo fixo).

## 2. Grupos de migration do banco (M00–M12)

Da seção 5 do [Relatório do Banco de Dados](../02_RELATORIO_BANCO_DE_DADOS.md).

- [x] **M00 — Fotografia e contrato de referência**: concluído. Fotografia administrativa de 23/06 e adendo de 24/06 registraram contagens, relações e funções.
- [ ] **M01 — Infraestrutura de importação e identificadores externos**: pendente. Não existe ainda lote de importação genérico, hash por linha nem fila de revisão reutilizável entre planilhas.
- [~] **M02 — Dados mestres**: parcial. `produtos.codigo_legado` já é usado como chave de conciliação (1.287 de 1.508 códigos batem), mas 221 produtos e a deduplicação de 504 contatos sem documento / 1.255 sem e-mail ainda não foram tratados.
- [~] **M03 — Projetos e participantes**: parcial. 213 códigos com match exato e 66 por dígitos já identificados; 51 códigos de projeto e 706 linhas `VENDAS` extraídas ainda sem correspondência; cliente canônico e `responsavel_id` ainda não unificados em uma única coluna.
- [ ] **M04 — Vendas e itens aprovados**: pendente — **gap crítico**. As 16.621 linhas `VENDAS` da planilha (2.042 vendas, 330 projetos, 1.508 produtos, R$ 29.291.376,23) ainda não foram promovidas para `vendas`, itens da venda e `projeto_itens`. Hoje `projeto_itens` só recebe registros pelo fluxo novo de aprovação de orçamento (SPEC-001); o histórico anterior ao novo sistema continua fora do banco.
- [ ] **M05 — Movimentos de estoque**: pendente. Depende do sistema novo de Estoque e Compras, que não existe.
- [ ] **M06 — Compras e recebimentos**: pendente. `pedido_compra` e `solicitacoes_compra` continuam vazias.
- [~] **M07 — Financeiro consolidado**: parcial. `orcamento_id` já existe em `projeto_itens`, `projeto_parcelas`, `boletos` e `notas_fiscais` (migrations da SPEC-001), mas não há tabela formal de `previsoes_financeiras` nem promoção de `staging_conta_pagar`/`staging_conta_receber` (13.863 + 4.357 linhas) para títulos operacionais.
- [ ] **M08 — Workflow do CRM**: pendente. Nenhuma tabela de fluxo configurável criada.
- [~] **M09 — Logística**: parcial. Existe schema de separações (`separacoes_schema`, migration `20260608130000`), mas evidências/fotos ainda usam Supabase Storage, não OneDrive.
- [ ] **M10 — Sistema de TI**: pendente. Nenhuma tabela administrativa (`sistema_modulos`, `papeis`, `permissoes`, `sistema_health_checks`, `integracoes`) foi encontrada em nenhum dos 9 sistemas.
- [ ] **M11 — Compatibilidade e retirada do legado**: pendente (não pode começar antes de M02–M10 avançarem).
- [ ] **M12 — Validação e corte do Connect**: pendente (sem data definida — D08).

## 3. Tasks por sistema

### 3.1 Hub / Central (`central-lucenera-dashboard-1c9ba`, v0.0.14)

> **Decisão de fronteira tomada em 25/06/2026**: Hub/Central e Sistema de TI serão **sistemas separados** (repositórios/pastas próprios), não um único pacote dividido por tela. A Central concentra produtividade pessoal e catálogo de acesso; o Sistema de TI concentra permissão, segurança, saúde e auditoria de todo o ecossistema — inclusive da própria Central e de si mesmo. Isso resolve a antiga `TI-10` (ver 3.2) e detalha os módulos da Central já mapeados na decisão de roadmap de 22/06/2026 (ver memória `lucenera-decisoes-roadmap-2026-06-22`).

- [~] **HUB-01** Catálogo consumido do Sistema de TI — parcial. Já lê `systems` e tem migration de 24/06 (`20260624160000_update_active_systems_portfolio.sql`) orientando o catálogo-alvo de 8 cards, mas a administração completa (ambientes, módulos, responsáveis, criticidade) ainda não existe porque o Sistema de TI não foi criado. **Atualização 30/06/2026**: RLS ligada em `systems`/`usuarios` (policy `admin_all_*` via `is_admin()`) e renomeação de cards de catálogo (`20260630174522_rename_cadastro_and_rls_policies.sql`) — reforço de segurança e nomenclatura, não avanço estrutural do catálogo em si (ver [Adendo 03/07/2026](../06_ADENDO_ATUALIZACAO_03_07_2026.md)).
- [ ] **HUB-02** Cartões por permissão — pendente. **SPEC-006 escrita em 26/06/2026** (`SPEC-006_Permissoes_Granulares_no_Hub.md`) define a RPC `hub_sistemas_permitidos` para substituir a leitura binária atual de `user_system_access` (confirmado no código: `AccessTab.tsx` só liga/desliga sistema inteiro, sem módulo/ação) — falta implementar. **Confirmado em 03/07/2026**: nenhum commit entre 26/06 e 03/07 tocou módulos, papéis, ações ou a RPC `hub_sistemas_permitidos`.
- [~] **HUB-03** Abertura dos sistemas — parcial. Abre por URL, mas sem tratamento de ambiente/manutenção/fallback. A continuidade de sessão ao abrir outro sistema (sem pedir login de novo) está desenhada na `SPEC-007_Token_Acesso_Compartilhado_Entre_Sistemas.md` (26/06/2026) — falta implementar.
- [ ] **HUB-04** Saúde resumida somente leitura — pendente. Depende de TI-05.
- [ ] **HUB-05** Sessão e identidade central — pendente. **SPEC-007 escrita em 26/06/2026** define o mecanismo de código de troca de curta duração (SSO sem novo login) entre sistemas — falta implementar.
- [ ] **HUB-06** Evento de acesso — pendente. Depende de TI-07/TI-08.
- [ ] **HUB-07** Tarefas e pendências centrais — pendente. To-do que reúne tarefas próprias, atribuídas por gestor e geradas automaticamente por pendência de outro sistema, com deep link de volta ao registro de origem.
- [ ] **HUB-08** Mural de avisos e aniversários — pendente.
- [ ] **HUB-09** Caixa de aprovações pendentes cross-sistema — pendente. Consolida aprovações de Orçamentos, Estoque/Compras, RH etc. em um único lugar, com deep link para a decisão no sistema de origem.
- [ ] **HUB-10** Diretório de colaboradores e busca global — pendente. Leitura sobre `funcionarios_novo`/usuário canônico, sem escrita.
- [ ] **HUB-11** Calendário central — pendente. Agrega eventos publicados por Logística, RH, Estoque/Compras.
- [ ] **HUB-12** Perfil pessoal e dashboard individual — pendente. Autoatendimento de foto/nome e dashboard pessoal por permissão no Hub; reset de senha/e-mail fica no Sistema de TI (TI-11), não no Hub. PowerBI executivo restrito a gestor/diretoria.

### 3.2 Sistema de TI (sem pasta local própria ainda)

> **Decisão de 25/06/2026 (resolve `TI-10`)**: o Sistema de TI será **sistema separado** da Central, com repositório/pasta próprio. Ele administra regras de permissão de acesso para **todos os sistemas do ecossistema, incluindo a própria Central e ele mesmo** (auto-governança, `TI-13`). É preciso diferenciar o conjunto de sistemas **monitorados/regidos por permissão** (todos, sem exceção) do conjunto de sistemas **exibidos como card na Central** (subconjunto configurável — ver `TI-14`).
>
> **Adendo de 26/06/2026 (escopo V1)**: para a V1, a separação física acima fica **adiada**. A lógica de permissão que iria para o Sistema de TI nasce **dentro do Hub/Central** (`central-lucenera-dashboard-1c9ba`), com a mesma granularidade prevista em `TI-03`/`TI-04` (módulo, aba e tipo de ação — criar/editar/deletar/visualizar — concedidos separadamente). Acesso de configuração dessas regras fica restrito aos admins do banco geral. O código precisa ser enviado para o repositório remoto do Hub no GitHub (`https://github.com/pedrolalala/central-lucenera.git`) para isso. Depois que essa base estiver estável, o plano é remover, sistema por sistema, a verificação de acesso duplicada que cada um mantém hoje (RH, Logística, Ubiqua etc. têm `is_admin()`/checagens próprias — ver seção 4) e passar a consultar o Hub. Isso não cancela `TI-01` a `TI-14` como destino final — só muda onde a implementação mora nesta rodada.

Nenhuma das 14 tasks abaixo foi iniciada como sistema separado (a decisão de fronteira final está tomada; a implementação V1 acontece no Hub, ver adendo acima). Este é o maior bloqueador transversal: Hub (02/04/05/06/12), RH-03, Logística-10, Ubiqua-02/03 e a permissão definitiva de Financeiro (pendência 6 da SPEC-001) dependem dele.

- [ ] **TI-10** Criar o repositório/pasta próprio do Sistema de TI e registrar no índice do portfólio — decisão de fronteira final mantida, mas **adiada para depois da V1** (ver adendo de 26/06/2026 acima); a implementação V1 acontece no Hub.
- [ ] **TI-01** Catálogo configurável de sistemas (consolidar `systems` + ambientes/módulos/responsáveis).
- [ ] **TI-02** Módulos e ações por sistema (`sistema_modulos`, `modulo_acoes`) — **V1 desenhada em `SPEC-006_Permissoes_Granulares_no_Hub.md` (26/06/2026)** como `modulos`/`modulo_acoes` dentro do Hub; falta implementar.
- [ ] **TI-03** Papéis e permissões configuráveis (`papeis`, `permissoes`, `papel_permissoes`, `usuario_papeis`) — **com granularidade decidida em 25/06/2026**: (a) escopo de visibilidade por papel — sistema inteiro ("ver tudo") ou só abas/módulos específicos; (b) escopo de ação dentro de cada módulo liberado — `criar`/`editar`/`deletar`/`visualizar` concedidos separadamente, não um único toggle. **V1 desenhada em `SPEC-006` (26/06/2026)**, com RPC `hub_pode_executar`; falta implementar.
- [ ] **TI-04** Exceções individuais de permissão (`usuario_permissao_excecoes`), com a mesma granularidade de módulo/ação de TI-03. **V1 desenhada em `SPEC-006` (26/06/2026)**; falta implementar.
- [ ] **TI-05** Saúde dos sistemas (`sistema_health_checks`, `sistema_health_events`).
- [ ] **TI-06** Atualização manual de saúde (incidente/manutenção/degradação).
- [ ] **TI-07** Monitoramento de integrações (`integracoes`, `integracao_execucoes`).
- [ ] **TI-08** Auditoria administrativa de alterações de configuração (permissão, cadastro de sistema, exceção) — **V1 desenhada em `SPEC-006` (26/06/2026)** como tabela `auditoria_permissoes` dentro do Hub; falta implementar.
- [ ] **TI-09** Contratos publicados para Hub e demais aplicativos (listar sistemas permitidos, verificar ação, saúde resumida, registrar execução) — parte de continuidade de sessão **desenhada em `SPEC-007_Token_Acesso_Compartilhado_Entre_Sistemas.md` (26/06/2026)**; a parte de verificação de ação está em `SPEC-006`. Saúde/integrações continuam pendentes (dependem de TI-05/TI-07).
- [ ] **TI-11** Gestão administrativa de credencial de usuário — reset de senha, alteração de e-mail e bloqueio/reativação de conta, para usuários de **todos** os sistemas (inclusive Central e o próprio TI). Distinto do autoatendimento de perfil do Hub (HUB-12).
- [ ] **TI-12** Histórico de acesso e atividade por sistema — consolida login/abertura de sistema (evento de acesso, HUB-06) e ações relevantes (criar/editar/deletar) executadas em cada sistema, consultável por usuário ou por sistema.
- [ ] **TI-13** Auto-governança — as regras de permissão/saúde/auditoria do TI cobrem também os módulos internos da Central e do próprio Sistema de TI; nenhum sistema fica fora da matriz só por ser quem a administra. **V1 desenhada em `SPEC-006` (26/06/2026)**: o próprio módulo de permissões do Hub entra no cadastro de módulos/ações; falta implementar.
- [ ] **TI-14** Diferenciação entre sistemas monitorados/regidos por permissão (todos, sempre) e sistemas exibidos como card na Central (subconjunto configurável, eventualmente por papel) — requer estender `systems` com os dois atributos separados e ajustar a consulta do Hub (HUB-01) para filtrar só pelo atributo de visibilidade de card.

### 3.3 Cadastro (`cadastro-lucenera-b86fe`, v0.0.27)

- [~] **CAD-01** Cadastro canônico de contatos — parcial. Já usa `contatos`/`marcas`/`categorias_produto`, mas ainda há sobreposição de papéis com CRM e Estoque/Compras.
- [ ] **CAD-02** Qualidade e conciliação dos clientes — pendente. 504 sem documento, 1.255 sem e-mail e 151 documentos repetidos ainda não tratados.
- [~] **CAD-03** Cadastro mestre de produtos — parcial. `codigo_legado` já é usado para conciliar (1.287/1.508), mas 221 produtos da planilha de vendas ainda não encontram correspondência. **SPEC-018 implementada em homologação** permite criar produto a partir do modal de Orçamentos, gravando no cadastro canônico `produtos` via RPC `criar_produto_orcamento`, sem criar catálogo paralelo.
- [ ] **CAD-04** Cadastro mestre de fornecedores — pendente. Sem tela dedicada de fornecedor baseada no cadastro canônico.
- [~] **CAD-05** Separação entre cadastro e operação — parcial. Ainda há leitura/edição de dados operacionais de estoque na mesma tela. A criação de produto implementada na **SPEC-018** é escrita cadastral em `produtos`, não movimento/reserva/compra.
- [~] **CAD-06** Projetos fora da responsabilidade de Cadastro — parcial, **avançou em 30/06/2026**. As rotas `/clientes` e `/projetos` agora redirecionam para `/pecas` (commit `Refactor: Remove projects and clients modules`); os módulos saíram da navegação, mas os dados e o código-fonte de `Clientes`/`Projetos` ainda existem no repositório. Falta remover qualquer edição concorrente residual e confirmar que nenhuma tela de Cadastro grava mais em `projetos`.
- [ ] **CAD-07** Importação e origem — pendente. Sem exibição de origem/última importação na ficha cadastral.
- [ ] **CAD-08** Remoção de mocks residuais — pendente. **Confirmado no código**: `src/stores/use-data-store.tsx` e `src/lib/mock-data.ts` ainda contêm dados `MOCK_*` em rotas de produção.

### 3.4 CRM (`lucenera-crm-3bd29 (1)`, v0.0.252)

- [ ] **CRM-01** Definição visual do fluxo — pendente. **Confirmado no código**: não existem tabelas `crm_fluxos`, `crm_etapas` ou `crm_substatus` em nenhuma migration do projeto.
- [ ] **CRM-02** Versionamento do fluxo — pendente (depende de CRM-01).
- [ ] **CRM-03** Migração manual entre versões — pendente (depende de CRM-01/02).
- [ ] **CRM-04** Execução de etapas e sub-status — pendente. Continua no enum fixo de status.
- [ ] **CRM-05** Checklists e tarefas — pendente.
- [ ] **CRM-06** Paralelismo, sequência e bloqueio — pendente.
- [ ] **CRM-07** Responsáveis configuráveis — pendente.
- [ ] **CRM-08** SLA configurável — pendente.
- [ ] **CRM-09** Exceções por projeto — pendente.
- [~] **CRM-10** Timeline única — parcial. Usuários e RPCs (`criar_usuario`, `admin_update_user_status`) existem, mas não há modelo de evento consolidando Orçamentos/Estoque/Financeiro/Logística.
- [~] **CRM-11** Itens aprovados do projeto — **parcial, avançou com a SPEC-001 e a SPEC-014**. Itens de orçamentos aprovados no novo fluxo já chegam em `projeto_itens` com `orcamento_id` (ver SPEC-001, §4 e §5). **Atualização 07/07/2026**: a SPEC-014 foi implementada no CRM em `ProjectDetail.tsx`; o detalhe do projeto agora carrega `projeto_itens(*)` e exibe o Card "Itens Aprovados do Projeto" com estado vazio, origem por orçamento e badge `Cancelado`/`Ativo`. **Ainda pendente após a SPEC-014**: badges ricos de `Reservado`, `Entrega futura`, `Separado` e `Entregue` quando a leitura de `vw_estoque_saldos_projeto_item` da SPEC-010 estiver liberada para o CRM, além da carga histórica das 16.621 linhas `VENDAS` da planilha (M04). **Achado em 07/07/2026**: o commit da SPEC-014 estava pronto no working tree do CRM mas nunca tinha sido commitado — commitado nesta rodada (`dbda401`). **Novo em 07/07/2026**: botão "Gerar Orçamento" em `ProjectDetail.tsx` abre o sistema de Orçamentos com o projeto pré-selecionado via `?projeto_id=` (fecha parte de `ORC-06`/integração CRM→Orçamentos). Como a SPEC-007 (SSO entre sistemas) ainda não existe, o link pode pedir login de novo — mesma limitação já registrada em `ORC-05`.
- [ ] **CRM-12** Registro manual de aceite/documento — pendente. Para esta versão, basta tarefa/checklist manual de aceite. A integração real com DocuSign (3 gates já mapeados: contrato de projeto, contrato de sinal, faturamento de venda padrão) fica registrada como **plano futuro de baixa prioridade** — não é item descartado, só não entra nesta versão (ver Escopo CRM, SPEC-CRM-12).
- [~] **CRM-13** Projeto como cadastro único — parcial. Cadastro ainda lê/exibe projeto via `vw_projetos_dashboard` (ver CAD-06). **Atualização 01/07/2026**: coluna `responsavel_obra_id` adicionada a `projetos`, com FK para `usuarios` (migration `20260701134423_add_responsavel_obra_id.sql`), formalizando o vínculo projeto↔responsável que antes causava erro `PGRST200`. **Achado novo, não coberto por SPEC-CRM**: no mesmo commit em que corrigiu esse schema, o CRM implementou **login próprio via Supabase Auth** — em tensão com a `SPEC-HUB-05`/`SPEC-007` (sessão central única via Hub); avaliar se o CRM deve migrar para o token compartilhado quando a SPEC-007 for implementada, em vez de manter autenticação própria.

### 3.5 Orçamentos (`gestao-financeira-clone-544cb (1)`, v0.0.273 no Skip / `dcd3442`)

> Este é o sistema mais diretamente afetado pelas SPECs de aprovação de orçamento (`SPEC-001` a `SPEC-004`).

- [x] **ORC-01** Projeto obrigatório — concluído. Bloqueio de salvamento sem projeto já implementado.
- [~] **ORC-02** Reutilização dos dados canônicos — parcial. Consome `projetos`/`contatos`/`produtos`/`usuarios`. A **SPEC-018 foi implementada** para criar um produto ausente sem sair do orçamento, gravando em `produtos` via RPC canônica e usando `marcas`/`categorias_produto`/fornecedores como tabelas auxiliares, sem cadastro paralelo do sistema.
- [ ] **ORC-03** Versionamento — pendente. Não há duplicação controlada de versão nem proteção formal contra sobrescrita de versão aprovada (a aprovação trava edição, mas isso não é o mesmo que versionamento).
- [x] **ORC-04** Itens e valores históricos — **concluído pela SPEC-001**. `aprovar_orcamento_financeiro` grava snapshot de quantidade, preço unitário, desconto e subtotal em `projeto_itens` no momento da aprovação (SPEC-001, §3 e Etapa 3).
- [~] **ORC-05** Comando de aprovação — **parcial, avançou com as SPECs 001-005 e 009/016/017**. RPCs transacionais existem e o snapshot real de 06/07/2026 confirma colunas/funções de aprovação do cliente (`enviar_orcamento_para_cliente`, `cliente_aprovar_orcamento`, `cliente_recusar_orcamento`, `adm_aprovar_pelo_cliente`). **Contrato consolidado e implementado:** `enviado_cliente → Aprovação Financeira → Orçamento Aprovado`; `aprovado_cliente`, `aprovado` e `aprovado_financeiro` ficam como legados/compatibilidade. A **SPEC-017 foi implementada em homologação**: o frontend lista orçamentos na fila financeira, edita/ver pelo fluxo normal de orçamento e aprova por `orcamento_id`, não por `project_id`. **Atualização 07/07/2026**: a experiência de envio/link para cliente já está implementada (`ClientApprovalTab.tsx` em `gestao-financeira-clone-544cb (1)` — `handleEnviar`/`buildClientApprovalLink`/`handleCopyLink`/`handleAprovarManual`); o item estava marcado como pendente neste documento por engano. **Pendente real**: só falta homologar o fluxo real ponta a ponta.
- [~] **ORC-06** Integração com CRM — parcial. Itens aparecem em `projeto_itens`, mas não há publicação padronizada de eventos de criação/revisão/cancelamento para a timeline do CRM (depende de CRM-10).
- [~] **ORC-07** Integração com Estoque/Compras — **parcial, avançou em 30/06/2026 e 07/07/2026 por fora do sistema-alvo**. A migration `20260630_010_reserva_estoque_aprovacao` incrementa `estoque_itens.quantidade_reservada` e a SPEC-010 já foi confirmada no Supabase real com `estoque_saldos_projeto_item`/`estoque_movimentos_projeto_item`. **SPEC-010** é a modelagem canônica para saldos operacionais por `projeto_item_id`; **SPEC-013** foi absorvida e não cria migration própria. Falta aplicar o hardening `20260707_023`, reconciliar o agregado, definir RLS e só então liberar consumo operacional amplo.
- [~] **ORC-08** Condições e parcelas previstas — **parcial, avançou com as SPECs 001-005 e SPEC-017**. Cálculo automático de parcelas/vencimentos a partir de forma de pagamento e prazo estruturado já foi implementado; as parcelas com `orcamento_id` têm unicidade própria e o trigger legado que bloqueava inserção foi ajustado. Com a **SPEC-017**, a edição financeira passou a reutilizar o editor normal de orçamento para conferir frete, prazo e pagamento antes da aprovação final. **Pendentes**: homologação operacional do fluxo completo.
- [~] **ORC-09** Cancelamento, aditivo e substituição — **parcial, avançou em 02/07/2026**. `cancelar_orcamento(orcamento_id, motivo)` implementada em duas etapas (migrations `20260702_015` e `20260702_016`): reverte a reserva de estoque, cancela parcelas e boletos pendentes, e invalida `projeto_itens` (soft-cancel, sem apagar nada, para preservar auditoria). Idempotente. **Pendente**: aditivo e substituição pós-aprovação continuam sem operação explícita — apenas cancelamento total foi coberto.
- [ ] **ORC-10** Limpeza da identidade antiga — pendente. Resíduos de dashboard/tabela `transactions` ainda não removidos.

### 3.6 Financeiro / Administração Bancária (`retorno-bancario-bradesco-5392a`, v0.0.40)

> Recebeu a outra metade da SPEC-001 (Boletos, Notas Fiscais, Remessa).

- [ ] **FIN-01** Nova identidade e navegação (Financeiro) — pendente. Navegação/rotas ainda identificadas como Administração Bancária.
- [ ] **FIN-02** Previsões financeiras — pendente. Não existe tabela `previsoes_financeiras`; a SPEC-001 criou boletos diretamente, sem etapa formal de previsão.
- [ ] **FIN-03** Contas a pagar — pendente. 13.863 linhas em `staging_conta_pagar` não promovidas para títulos operacionais.
- [ ] **FIN-04** Contas a receber — pendente. 4.357 linhas em `staging_conta_receber`; nenhum dos 2.042 `CodVenda` aprovados foi reconciliado com `vendas.cod_venda`.
- [ ] **FIN-05** Integração com pedidos de compra — pendente. Depende do Estoque/Compras.
- [~] **FIN-06** Integração com vendas e orçamentos — **parcial, avançou com as SPECs 001-005** para o fluxo novo. Boletos/notas/parcelas usam `orcamento_id` como vínculo operacional principal; histórico obrigatório, unicidade parcial e desbloqueio dos triggers legados já foram implementados. **Pendentes**: vínculo do histórico importado da planilha de vendas, homologação operacional e snapshot pós-SPEC-005.
- [~] **FIN-07** Boletos — parcial. Estados `pendente_registro` implementados pela SPEC-001; falta rotina oficial de geração de `nosso_numero` (hoje é um identificador provisório rastreável, ver SPEC-001 §5).
- [~] **FIN-08** Remessa CNAB — parcial. Gerador CNAB 400 com header/detalhe/trailer de 400 posições implementado e fluxo manual em lote criado (SPEC-001 §9.3). **Bloqueado por decisão**: homologação com dados bancários reais (agência, conta, carteira, convênio, sequencial oficial) ainda não feita — não usar em produção sem isso.
- [x] **FIN-09** Retorno bancário — **concluído em 07/07/2026**. `SPEC-008` implementada: `RetornoBoletos.tsx` não tem mais dados de exemplo, chama a RPC transacional `processar_retorno_bancario` (hash SHA-256, baixa/divergência/não-encontrado, lançamento em `transacoes`). Achado durante a implementação: um trigger órfão em `projeto_parcelas` quebrava qualquer `UPDATE` nessa tabela (coluna `updated_at` referenciada não existe) — corrigido, com aprovação explícita do usuário, na mesma migration. Falta apenas homologação com arquivo de retorno real (depende também de `FIN-08`).
- [x] **FIN-10** Conciliação — **concluído em 07/07/2026** pela mesma `SPEC-008`: divergência (valor pago ≠ esperado) fica registrada sem dar baixa, reprocessamento do mesmo arquivo é bloqueado por hash (com opção explícita de forçar), e o botão "Log" abre o histórico real de `retorno_bancario_arquivos`/`retorno_bancario_registros`.
- [ ] **FIN-11** 🔒 Notas fiscais e documentos — **parcial / bloqueado por decisão**. Upload manual real de PDF no bucket `notas_fiscais` e cadastro com `orcamento_id` já implementados (SPEC-001 §9.2). **Pendente crítico, citado explicitamente como pendência futura na SPEC-001 (§2.1, item 2)**: escolher o provedor/API de emissão de nota fiscal e implementar a função real de emissão (`numero_nf`, `serie`, `chave`, `protocolo`, `status`, `XML`/DANFE). Hoje toda NF é só cadastro manual — nenhuma é emitida automaticamente, por decisão correta (não simular emissão).
- [ ] **FIN-12** Visão financeira por projeto — pendente.
- [ ] **FIN-13** Rotinas administrativas essenciais (Lana/Caroline: tarifas, impostos, transferências) — pendente.
- [ ] **FIN-14** Reconciliação das parcelas históricas com backup — pendente.

### 3.7 Estoque e Compras (sistema novo — nada implementado)

Nenhuma pasta em `Sistema/` existe para este sistema. Todas as 16 tasks abaixo estão pendentes; é o maior bloco de trabalho restante do ecossistema.

> **Decisão de 26/06/2026**: o sistema **não nasce do zero**. A lógica operacional (reserva, hierarquia de transferência, cotação, pedido, recebimento, garantia/troca) já está mapeada em `Mapeamento de Processos/` e nas explicações da Connect (ver `05_ADENDO_REGRAS_VIDEOS_CONNECT.md`) — a próxima SPEC detalhada deve partir desses documentos em vez de desenhar o domínio do zero.

- [ ] **EST-01** Reutilização dos cadastros canônicos (produtos/fornecedores do Cadastro).
- [ ] **EST-02** Informações operacionais de produto/fornecedor (`produto_fornecedores`, custo, prazo).
- [ ] **EST-03** Locais e saldo (`estoque_locais`, `estoque_movimentos`, ledger).
- [ ] **EST-04** Importação dos movimentos históricos (as 5.550 linhas não-`VENDAS` da planilha: troca, remessa, garantia, bonificação, etc.).
- [~] **EST-05** Recebimento dos itens aprovados — **parcial, avançou em 06/07/2026 e 07/07/2026**. A migration `20260706_022_saldos_estoque_projeto_item` (SPEC-010) já foi confirmada no Supabase real e cria `estoque_saldos_projeto_item`/`estoque_movimentos_projeto_item`, com `aprovar_orcamento_financeiro_base_spec001` dividindo `q_reserva`/`q_entrega_futura` por item. Falta aplicar `20260707_023_spec010_hardening`, definir RLS, reextrair `db/current/` e importar historicamente as 16.621 linhas `VENDAS`. Continua fora do futuro sistema de Estoque/Compras — nasce dentro da RPC de Orçamentos, como ponte temporária (pendência de decisão registrada na seção 4).
- [x] **EST-06** Reserva e transferência entre itens de projeto — **concluído no backend em 07/07/2026**. Hardening `20260707_023` aplicado, RLS de leitura definida (`20260707_024`). **SPEC-011** (transferência, migration `20260707_026`) e **SPEC-012** (views de entrega futura/necessidade de compra, migration `20260707_025`) implementadas e testadas em transação com rollback. Falta apenas frontend/tela que consuma isso — nenhum sistema de Estoque/Compras existe ainda para hospedar essa UI.
- [ ] **EST-07** Necessidade de compra agregada por produto. A reunião 08 confirmou que compra/reposição não deve ficar amarrada ao cliente; a visualização por cliente é informativa para prioridade, não vínculo de compra.
- [ ] **EST-08** Cotações (`cotacoes_compra`, `cotacao_itens`).
- [ ] **EST-09** Pedido de compra com itens próprios (`pedidos_compra`, `pedido_compra_itens`).
- [ ] **EST-10** Aprovação do pedido e previsão financeira (evento idempotente para o Financeiro).
- [ ] **EST-11** Prazos e acompanhamento (atraso, revisões).
- [ ] **EST-12** Recebimento de material com divergências (`recebimentos_compra`).
- [ ] **EST-13** Confirmação da conta a pagar após nota/recebimento.
- [ ] **EST-14** Liberação para Logística (fila estruturada, substituindo PDF/Teams manual).
- [ ] **EST-15** Garantia, troca e devolução com hierarquia `E. Futura → Reserva → Entregue`. **SPEC-015** agora usa os vídeos Connect como regra base e permanece pendente apenas para decisões de aprovação, financeiro e coleta física.
- [ ] **EST-16** Painel operacional (necessidades, cotações, pedidos atrasados, divergências).

### 3.8 Logística (`lucenera-logistics-b7cd1`, v0.0.63 + `lucenera-logistica-atual-backup`)

- [ ] **LOG-01** Origem no Estoque/Compras — pendente. Depende do EST-14, que não existe.
- [~] **LOG-02** Itens e quantidades — parcial. Existe schema de separações (`20260608130000_separacoes_schema.sql`), mas sem ligação completa a `projeto_itens`.
- [ ] **LOG-03** Estados canônicos — pendente. Ainda há nomes divergentes (`Pendente`, `Pronto`, `material_solicitado`, `em_separacao`, `separado`, `finalizado`). **Confirmado em 30/06/2026**: sete commits seguidos (`Fix calendar view enum value mismatch` etc.) corrigiram sintomas desse mesmo problema no calendário/filtro sem consolidar o enum — reforça que a causa raiz segue pendente.
- [~] **LOG-04** Separação parcial — parcial.
- [~] **LOG-05** Agenda e rota — parcial. Calendário existe, mas otimização de rota ainda é simulação visual.
- [ ] **LOG-06** 🔒 Registro de entrega com evidências no OneDrive — **bloqueado por decisão/infra**. **Confirmado no código**: `useSeparacaoArquivos.ts`, `useCreateSeparacao.ts`, `useUpdateSeparacao.ts` e `useSignedUrls.ts` ainda usam Supabase Storage. A migração para Microsoft Graph/OneDrive API (decidida em 24/06) não foi feita.
- [~] **LOG-07** Ocorrências e insucesso — parcial.
- [ ] **LOG-08** Devolução e garantia (tipos `coleta`/`troca`/`entrega de garantia`) — pendente.
- [ ] **LOG-09** Integração com CRM (eventos de timeline) — pendente.
- [ ] **LOG-10** Configurações e acessos pelo Sistema de TI — pendente (depende de TI-03).
- [~] **LOG-11** Painel administrativo real — parcial. **Atualização 30/06/2026**: dashboard de separação e entrega implementado (cards com detalhe expandido, modal de finalização de entrega, upload de arquivos por separação) — ainda usando Supabase Storage para os anexos (ver LOG-06, que permanece bloqueado). RLS ligada pela primeira vez em `separacoes`, `separacao_arquivos` e `entregas_finalizadas`, com policy `USING (true)` para qualquer autenticado (ver pendência 7 e o [Adendo 03/07/2026](../06_ADENDO_ATUALIZACAO_03_07_2026.md)).
- [ ] **LOG-EXTRA** 🔒 Consolidar `lucenera-logistica-atual-backup` (sistema real em uso) e `lucenera-logistics-b7cd1` (destino conectado ao banco) — decisão e plano de corte ainda não definidos; os dois diretórios continuam coexistindo por decisão operacional de 24/06.

### 3.9 RH (`dashboard-rh-lucenera-5fe9c`, v0.0.189)

- [~] **RH-01** Consolidação dos colaboradores — parcial. `funcionarios_novo` é a árvore oficial decidida (D05) e já é referenciada nos `types.ts` de outros sistemas, mas o relatório de correspondência/divergência entre árvores paralelas não foi gerado. **Atualização 29/06/2026**: view `vw_funcionarios_completo` criada (junta `funcionarios_novo` + detalhes + financeiro + benefícios) e RLS ligada nas 4 tabelas pela primeira vez (`20260629120922_vw_funcionarios_completo.sql`). **Alerta de qualidade de dado**: a mesma migration semeia 4 funcionários fictícios com CPF/RG/salário fabricados condicionado a `funcionarios_novo` estar vazia — revisar antes de rodar em ambiente com dados reais (ver pendência 11 e o [Adendo 03/07/2026](../06_ADENDO_ATUALIZACAO_03_07_2026.md)).
- [~] **RH-02** Separação entre funcionário e usuário — parcial.
- [ ] **RH-03** Acessos pelo Sistema de TI — pendente (depende de TI-03).
- [x] **RH-04** Preservação dos módulos úteis (faltas, férias, benefícios, avaliações, folha) — concluído, módulos em operação.
- [~] **RH-05** Folha e integração financeira (evento de fechamento de folha para o Financeiro) — **parcial, avanço inesperado em 30/06/2026**. A migration central `20260630_012_equipe_projetos_comissao` criou a view `vw_comissao_mensal` (percentual da equipe × valor total dos projetos do mês), mas nasceu no banco central via `equipes_projetos`/`funcionarios_financeiro`, não em um commit do sistema de RH — nenhum frontend consome a view ainda, e não há evento de fechamento de folha em si.
- [~] **RH-06** Relatórios — parcial.
- [ ] **RH-07** Eventos e saúde publicados no Hub — pendente (depende de TI-05/TI-07).

### 3.10 Ubiqua (`catalogo-pecas-ubiqua-e6fa0`, v0.0.76) — baixa prioridade de mapeamento

Por decisão de 24/06/2026, Ubiqua segue ativo operacionalmente, mas **não deve receber decisões estruturais nesta rodada**. As tasks abaixo ficam registradas para quando a abrangência for definida, sem prioridade imediata.

- [ ] **UBI-01** Preservação do contexto separado (documentar fronteiras de `revenda_ubiqua`, `empresa_ubiqua`, etc.).
- [ ] **UBI-02** Identidade central e perfil de negócio (depende de TI).
- [ ] **UBI-03** Permissões pelo Sistema de TI (depende de TI).
- [ ] **UBI-04** Preservar fluxo próprio de orçamentos Ubiqua sem mistura com Orçamentos Lucenera.
- [ ] **UBI-05** Validar consistência de catálogo/imagens/slugs.
- [ ] **UBI-06** Saúde e integrações publicadas no Hub.
- [ ] **UBI-07** Documentar tabelas exclusivas do Ubiqua antes de qualquer limpeza futura.

## 4. Automações de banco e integração (transversais)

Da seção 6 do Relatório do Banco de Dados.

**Necessárias, ainda pendentes** (exceto onde indicado):

- [x] Aprovação idempotente de orçamento → criação de itens aprovados — **concluído pela SPEC-001** (`aprovar_orcamento_financeiro`).
- [x] Cancelamento idempotente de orçamento aprovado → reversão de reserva, cancelamento de parcelas/boletos, invalidação de itens — **concluído em 02/07/2026** (`cancelar_orcamento`, migrations `20260702_015` e `20260702_016`, ver [Adendo 03/07/2026](../06_ADENDO_ATUALIZACAO_03_07_2026.md)).
- [ ] Promoção controlada de staging (CP/CR/pedido de compra) para tabelas operacionais.
- [~] Geração de reserva e necessidade de compra a partir de `projeto_itens` — **parcial desde 30/06/2026**. Reserva simples (`estoque_itens.quantidade_reservada`) já é gerada na aprovação do orçamento; necessidade de compra formal (déficit → `necessidades_compra`) ainda não existe.
- [ ] Criação de previsão financeira a partir de pedido de compra aprovado.
- [ ] Confirmação ou ajuste do título financeiro após nota/recebimento.
- [ ] Liberação para Logística a partir de reserva/atendimento do Estoque.
- [ ] Processamento idempotente de remessa e retorno bancário (parcialmente coberto por FIN-08/FIN-09).
- [ ] Execução de health checks (depende de TI-05).
- [ ] Registro de execução/falha de integrações (depende de TI-07).

**A revisar ou substituir:**

- [x] Triggers/scheduler antigos de aprovação e billing automation — **concluído em 26/06/2026**. `trg_aprovar_orcamento`/`fn_aprovar_orcamento()` foram removidos pela SPEC-005 (confirmado no snapshot reextraído); `sync-fechamentos-automatica` foi descontinuada/removida pela SPEC-004; `process-billing-automation` foi removida do remoto após confirmação de que não havia chamador algum — nem trigger/função no banco, nem frontend, nem `pg_cron`/`pg_net`/database webhooks (extensões nem instaladas no projeto).
- [ ] Demais triggers que avançam processo só por mudança de texto de status (CRM, Logística) — ainda não revisadas.
- [ ] Automações que criam estoque/separação/entrega sem `projeto_item` — ainda não revisadas (Estoque/Compras não existe para corrigir isso).
- [ ] Funções de usuário repetidas entre sistemas (RH, Logística, Ubiqua têm verificações próprias) — não consolidadas.

## 5. Pendências críticas e decisões abertas (bloqueiam produção)

Esta seção existe para que nenhuma pendência relevante fique escondida dentro de um sistema só. São as decisões que, enquanto não tomadas, impedem que as tasks correspondentes avancem.

1. **🔒 Emissão de Nota Fiscal** — decidir qual provedor/API será usado para emissão, assinatura, consulta de status, cancelamento e armazenamento do DANFE/XML, e então implementar `FIN-11`. Hoje a NF é só cadastro manual por decisão (não simular emissão), exatamente como registrado na pendência 2 da SPEC-001.
2. **🔒 Homologação bancária do CNAB** — `FIN-08` está implementado tecnicamente, mas não pode ir a produção sem agência, conta, carteira, convênio/código da empresa e sequencial oficial homologados com o Bradesco.
3. **🔒 Migração de arquivos para OneDrive/SharePoint** — afeta `FIN-11` (PDFs de NF, hoje no bucket `notas_fiscais` do Supabase) e `LOG-06` (fotos/comprovantes de entrega, hoje ainda em Supabase Storage). Requer decisão/configuração de credenciais Microsoft Graph antes de implementar.
4. ~~**🔒 Fronteira de implementação do Sistema de TI**~~ — **decidido em 25/06/2026, com adendo de escopo em 26/06/2026**: o destino final é TI como sistema separado da Central, regendo permissão/saúde/auditoria de todo o ecossistema (inclusive Central e ele mesmo). **Para a V1, porém, essa lógica é implementada dentro do próprio Hub/Central** (mesma granularidade de módulo/aba/ação prevista em `TI-03`/`TI-04`, acesso restrito a admins do banco geral), com o código enviado ao repositório remoto do Hub no GitHub. A remoção da checagem de acesso duplicada de cada sistema (RH, Logística, Ubiqua etc.) acontece depois, por lógica, quando essa base no Hub estiver pronta. Continua bloqueando `HUB-02/04/05/06/12`, `RH-03`, `LOG-10`, `UBI-02/03` e a substituição da permissão provisória por `role` (pendência 6 da SPEC-001) até a implementação V1 existir.
5. ~~**Sistema de Estoque e Compras**~~ — **decidido em 26/06/2026**: não nasce do zero; reaproveita a lógica já mapeada em `Mapeamento de Processos/` e nas explicações da Connect antes de iniciar `EST-01` a `EST-16`. Continua sendo o maior bloco de trabalho ainda não iniciado do ecossistema, mas agora com ponto de partida definido.
6. ~~**Consolidação da Logística**~~ — **decidido em 26/06/2026**: `lucenera-logistica-atual-backup` é desligado quando `lucenera-logistics-b7cd1` replicar exatamente tudo o que o backup faz hoje, com a diferença de que a integração de evidências/documentos passa a ser pelo SharePoint/OneDrive (não pelo mecanismo atual do backup) — ver também `LOG-06` e pendência crítica 3.
7. **Análise de segurança do banco (RLS)** — adendo de segurança do Relatório de Banco (§9): após o modelo estabilizar, é obrigatória uma revisão específica de RLS, policies e grants. Achados anteriores (policies antigas permissivas anulando as novas, `anon` com grants de escrita direta) ainda não têm confirmação de correção nesta rodada. **Reforçado negativamente em 29/06–30/06/2026**: toda policy RLS nova criada nessa janela (RH: 4 tabelas de funcionário; CRM: `projetos`; Logística: `separacoes`/`separacao_arquivos`/`entregas_finalizadas`; Orçamentos: `logs_auditoria`) usa `USING (true)` para qualquer usuário autenticado, sem checar papel — o mesmo padrão permissivo já apontado como achado antigo está sendo reproduzido em código novo. Única exceção: o Hub usa `is_admin()` para `systems`/`usuarios`. Ver [Adendo 03/07/2026](../06_ADENDO_ATUALIZACAO_03_07_2026.md).
8. **Linhas não conciliadas da planilha de vendas** — decidir o tratamento de 2.688 linhas `VENDAS` sem código de projeto, 706 com código sem correspondência, 51 códigos de projeto e 221 códigos de produto ainda não encontrados, antes de rodar `M04`.
9. **Data de corte do Connect** — por decisão D08, não há prazo fixo; o corte só ocorre quando todo o ecossistema estiver interligado e validado por `M12`.
10. **Troca/Garantia de luminária** — gap de processo confirmado (hoje 100% e-mail/presença física, zero rastreamento de caso); decisão de prioridade e abordagem (módulo dentro de Gestão de Processos vs. extensão de `EST-15`/Logística) **fica explicitamente pendente** por decisão de 26/06/2026 — registrado para não ficar esquecido, sem compromisso de quando entra.
11. **🔒 Credencial em texto plano commitada ao GitHub** — achado novo de 03/07/2026. A senha `Skip@Pass` do usuário `pedro@lucenera.com.br` foi escrita em texto plano em 3 migrations SQL diferentes (CRM, Hub/Central, RH — ver [Adendo 03/07/2026](../06_ADENDO_ATUALIZACAO_03_07_2026.md), seção 5). Deve ser tratada como exposta independentemente de troca futura, porque o histórico do Git preserva o valor original. **Ação necessária**: rotacionar a senha e revisar se algum outro segredo (chave de API, token) foi commitado da mesma forma. Relacionado à pendência 7, mas tratado à parte por ser uma exposição concreta, não um padrão de policy.
12. **Migration de RH com dados fictícios condicionados** — a migration `20260629120922_vw_funcionarios_completo.sql` semeia 4 funcionários inventados (nome, CPF, RG, endereço, salário) caso `funcionarios_novo` esteja vazia. Decidir se esse seed deve ser removido do script de produção ou isolado como fixture de desenvolvimento antes da carga real de colaboradores (RH-01).

## 6. Referência cruzada

- A [SPEC-001](SPECs/SPEC-001_Aprovacao_Orcamento_para_Administracao_Bancaria.md) é o modelo de detalhamento a seguir: ela cobriu **ORC-04, ORC-05, ORC-08, FIN-06, FIN-07 (parcial), FIN-08 (parcial), FIN-09 (parcial), FIN-11 (parcial)** e deixou suas próprias pendências numeradas, que foram incorporadas na seção 5 deste documento.
- As [SPEC-002](SPECs/SPEC-002_Prazo_Inicio_Cobranca_Orcamento.md), [SPEC-003](SPECs/SPEC-003_Validacao_Coleta_Frete_Orcamento.md), [SPEC-004](SPECs/SPEC-004_Auditoria_Parcelas_Orcamento_Aprovado.md) e [SPEC-005](SPECs/SPEC-005_Remocao_Triggers_Legados_Bloqueio_Aprovacao.md) fecharam lacunas do fluxo novo de aprovação. Homologação operacional confirmada em 26/06/2026 (aprovação real pela UI); reextração do snapshot pós-SPEC-005 também feita em 26/06/2026. Resta: orçamentos antigos sem dados estruturados.
- A [SPEC-006](SPECs/SPEC-006_Permissoes_Granulares_no_Hub.md) (permissões granulares no Hub — V1 de `TI-02/03/04/08/13`), a [SPEC-007](SPECs/SPEC-007_Token_Acesso_Compartilhado_Entre_Sistemas.md) (SSO sem novo login entre sistemas, resolve a continuidade de sessão do bug do boleto em `ORC-05`) e a [SPEC-008](SPECs/SPEC-008_Conciliacao_Retorno_Bancario_Baixa_Parcelas.md) (fecha o ciclo financeiro: retorno bancário → baixa de parcela → lançamento em `transacoes`, cobre `FIN-09`/`FIN-10`) foram escritas em 26/06/2026, com o desenho de banco/RPC/Edge Functions definido, mas **ainda não implementadas** — são a próxima frente de trabalho a executar.
- Falta ainda uma SPEC para `HUB-06`/`TI-12` (evento de acesso e histórico de atividade) para fechar completamente o tripé de TI (permissão + sessão + rastreabilidade) — não escrita nesta rodada, fica registrada como próximo candidato natural depois de SPEC-006/007/008.
- O [Adendo de 03/07/2026](../06_ADENDO_ATUALIZACAO_03_07_2026.md) registra, sem SPEC formal própria, os 7 grupos de migration do banco central que avançaram `ORC-07`, `ORC-09`, `EST-05`, `EST-06` e `RH-05` entre 30/06 e 02/07/2026 (reserva de estoque na aprovação, cancelamento de orçamento, comissão por equipe), o fluxo de aprovação financeira de Orçamentos, e o achado crítico de segurança da pendência 11.
- A sequência publicada no GitHub em 06/07/2026 ocupa `SPEC-009` a `SPEC-012`; a reavaliação consolidou `SPEC-010` como fonte canônica para saldos por `projeto_item_id`, absorveu `SPEC-013`, manteve `SPEC-014` para leitura de itens no CRM e atualizou `SPEC-015` como devolução implementável baseada nos vídeos Connect.
- As [SPEC-016](SPECs/SPEC-016_Normalizacao_Aprovacao_Financeira_Orcamento.md), [SPEC-017](SPECs/SPEC-017_Modal_Unificado_Aprovacao_Financeira_Orcamento.md) e [SPEC-018](SPECs/SPEC-018_Criar_Produto_no_Modal_de_Orcamento.md) foram implementadas em 06/07/2026 no banco e na UI de Orçamentos: aprovação financeira obrigatória antes de disparos, modal/edição financeira igual ao fluxo normal de orçamento e criação de produto dentro do modal de orçamento. **Achado em 07/07/2026**: essa implementação do frontend estava pronta no working tree de `gestao-financeira-clone-544cb (1)` mas nunca tinha sido commitada (10 arquivos modificados, 2 novos) — commitada nesta rodada (`775b66f`). Seguinte passo: homologação operacional/visual no preview Skip.
- **SPEC-008, SPEC-011, SPEC-012 e SPEC-015 foram implementadas em 07/07/2026** (backend completo, testado em transação com rollback contra dados reais): conciliação de retorno bancário com baixa automática (`SPEC-008`, inclui correção de um bug pré-existente que quebrava qualquer `UPDATE` em `projeto_parcelas`), transferência de reserva entre itens de projeto (`SPEC-011`), views de entrega futura/necessidade de compra (`SPEC-012`) e devolução de estoque (`SPEC-015`). Nenhuma delas tem frontend além de `SPEC-008` (que já reescreveu `RetornoBoletos.tsx`); `SPEC-011/012/015` ficam prontas para consumo quando existir o sistema de Estoque/Compras.
- A [SPEC-010](SPECs/SPEC-010_Saldos_Estoque_por_Item_de_Projeto.md) precisa estar aplicada e endurecida antes da [SPEC-011](SPECs/SPEC-011_Transferencia_Reserva_Entre_Itens_de_Projeto.md), [SPEC-012](SPECs/SPEC-012_Entrega_Futura_Necessidade_Compra.md), [SPEC-015](SPECs/SPEC-015_Devolucao_Estoque_por_Item_de_Projeto.md) e dos badges ricos da [SPEC-014](SPECs/SPEC-014_Aba_Itens_Aprovados_CRM.md). **Atualização 07/07/2026**: a migration `20260706_022_saldos_estoque_projeto_item` foi confirmada no Supabase real, mas a revisão encontrou exposição de views, quatro divergências no agregado `quantidade_reservada` e entrega direta de `q_entrega_futura`; a migration `20260707_023_spec010_hardening` foi escrita para corrigir isso antes de destravar 011/012/014/015.
- Ao escrever a próxima SPEC detalhada depois de SPEC-006/007/008/009/010/011/012/013/014/015/016/017/018 (sugestão: evento de acesso/`TI-12`, confirmação do deploy real do Financeiro, ou Estoque e Compras partindo do Mapeamento de Processos e dos adendos de Vídeos Connect), some uma entrada nova em `Planos de Ação/SPECs/` e atualize o checklist correspondente aqui.
