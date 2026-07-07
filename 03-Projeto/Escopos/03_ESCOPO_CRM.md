# Escopo — CRM Lucenera

## Versão atual

Pacote analisado: `lucenera-crm-3bd29 (1)`  
Versão declarada após atualização: `0.0.252`

O CRM atual possui:

- dashboard;
- projetos;
- criação e detalhe do projeto;
- clientes, arquitetos, engenheiros e eletricistas;
- parcelas do projeto;
- usuários e configurações;
- status fixos de projeto.

A versão atual já possui gestão de usuários no CRM, usando `usuarios` e RPCs como `criar_usuario` e `admin_update_user_status`. O módulo interno de Orçamentos ainda é uma área de navegação, mas o editor real de orçamento está no sistema próprio de Orçamentos.

No Supabase atual ainda não existem tabelas específicas de fluxo configurável, como `crm_fluxos`, `crm_etapas`, `crm_substatus` ou `crm_tarefas_modelo`. Existem status e views de acompanhamento, mas não o modelo versionado decidido.

## Objetivo da evolução

Tornar o CRM a interface principal para:

- projeto e seus participantes;
- responsável interno;
- execução do fluxo;
- timeline;
- etapas e sub-status;
- checklists e tarefas;
- SLA;
- exceções por projeto;
- histórico dos itens aprovados;
- visão consolidada dos demais sistemas.

O CRM não será dividido em espaços. Cada projeto executará uma versão de um fluxo configurado.

## SPEC-CRM-01 — Definição visual do fluxo

**Achado:** os status atuais continuam sendo valores fixos e não há tabelas de fluxo configurável no Supabase atual.

**Evolução:** permitir que administradores criem e ordenem etapas, sub-status e checklists pela interface.

**Justificativa:** o processo muda e não deve exigir alteração no código.

**Relação com o banco:** criar `crm_fluxos`, `crm_fluxo_versoes`, `crm_etapas`, `crm_substatus` e `crm_tarefas_modelo`, preservando o status legado atual para conferência.

**Ação a ser realizada:** criar um editor visual de fluxo com rascunho, validação e publicação.

**Critério de aceite:** uma nova etapa pode ser configurada e publicada sem migration ou deploy.

## SPEC-CRM-02 — Versionamento do fluxo

**Achado:** alterar uma configuração global não pode modificar silenciosamente projetos em andamento.

**Evolução:** cada publicação gera uma versão imutável.

**Justificativa:** preserva a regra usada por cada projeto.

**Relação com o banco:** projeto ou execução do CRM referencia a versão publicada.

**Ação a ser realizada:** impedir edição direta de versão publicada; usar clonagem para nova versão.

**Critério de aceite:** projetos antigos continuam na versão anterior após uma nova publicação.

## SPEC-CRM-03 — Migração manual entre versões

**Achado:** em casos específicos, um projeto em andamento precisará adotar a versão nova.

**Evolução:** oferecer migração manual, com prévia do impacto.

**Justificativa:** mudanças de etapas e tarefas podem deixar dados sem correspondência.

**Relação com o banco:** registro da versão anterior/nova, mapeamento de etapas/tarefas, autor, motivo e data.

**Ação a ser realizada:** criar assistente que exija o mapeamento dos itens incompatíveis antes de confirmar.

**Critério de aceite:** toda migração possui histórico e pode ser explicada posteriormente.

## SPEC-CRM-04 — Execução de etapas e sub-status

**Achado:** uma etapa pode ter estados internos diferentes.

**Evolução:** o projeto mantém etapa e sub-status atuais de acordo com sua versão.

**Justificativa:** oferece leitura simples da timeline sem criar vários CRMs.

**Relação com o banco:** `crm_execucoes`, etapa atual, sub-status atual e eventos de transição.

**Ação a ser realizada:** trocar os selects baseados no enum de projeto pelo runtime do fluxo.

**Critério de aceite:** somente sub-status pertencentes à etapa atual podem ser selecionados.

## SPEC-CRM-05 — Checklists e tarefas

**Achado:** o processo mapeado contém reuniões, documentos, revisões, visitas, cobranças e entregas.

**Evolução:** cada etapa pode criar tarefas/checklists configuráveis.

**Justificativa:** status isolado não informa o que falta para avançar.

**Relação com o banco:** tarefas modelo e tarefas executadas por projeto.

**Ação a ser realizada:** permitir título, descrição, obrigatoriedade, tipo de evidência, responsável e prazo.

**Critério de aceite:** ao entrar na etapa, as tarefas correspondentes são criadas para o projeto.

## SPEC-CRM-06 — Paralelismo, sequência e bloqueio

**Achado:** algumas tarefas podem ocorrer juntas; outras dependem de conclusão anterior.

**Evolução:** configurar dependências sequenciais ou paralelas e indicar o que bloqueia o avanço.

**Justificativa:** reproduz a lógica real sem hardcode.

**Relação com o banco:** dependências entre tarefas/etapas e regras de conclusão.

**Ação a ser realizada:** criar configuração de predecessores e validador de avanço.

**Critério de aceite:** o sistema bloqueia somente quando a regra publicada assim determinar.

## SPEC-CRM-07 — Responsáveis configuráveis

**Achado:** a maioria das ações usa o responsável do projeto, mas tarefas específicas podem ter outros responsáveis.

**Evolução:** configurar herança do projeto, usuário, papel, equipe ou definição manual.

**Justificativa:** evita duplicar o responsável quando não é necessário e permite delegações reais.

**Relação com o banco:** política do responsável no modelo e responsável resolvido na tarefa executada.

**Ação a ser realizada:** implementar resolução de responsável no momento da criação da tarefa.

**Critério de aceite:** uma tarefa pode herdar o responsável do projeto ou ser atribuída a outro usuário conforme configuração.

## SPEC-CRM-08 — SLA configurável

**Achado:** algumas tarefas possuem prazo operacional; outras não.

**Evolução:** permitir SLA ativado ou desativado por etapa/tarefa.

**Justificativa:** evita alertas artificiais em atividades que não possuem prazo fixo.

**Relação com o banco:** duração, calendário aplicável, início, vencimento, pausa e conclusão.

**Ação a ser realizada:** calcular prazo somente quando a versão do fluxo ativar SLA.

**Critério de aceite:** tarefas sem SLA não aparecem como atrasadas.

## SPEC-CRM-09 — Exceções por projeto

**Achado:** casos específicos podem precisar alterar bloqueio, sequência, responsável ou SLA.

**Evolução:** permitir exceções controladas na execução do projeto.

**Justificativa:** mantém flexibilidade sem alterar a versão global.

**Relação com o banco:** override por projeto/tarefa, valor original, valor novo, justificativa e autor.

**Ação a ser realizada:** criar ação de exceção com permissão específica e histórico.

**Critério de aceite:** a exceção afeta somente o projeto selecionado.

## SPEC-CRM-10 — Timeline única

**Achado:** o projeto precisa reunir evolução do processo e eventos dos sistemas.

**Evolução:** mostrar mudanças de etapa, tarefas, aprovações, compras, recebimentos, financeiro, separações e entregas.

**Justificativa:** oferece contexto sem permitir que o CRM edite dados pertencentes a outros domínios.

**Relação com o banco:** eventos locais e contratos de leitura/eventos publicados pelos demais sistemas.

**Ação a ser realizada:** criar um modelo de evento com tipo, origem, data, ator, resumo e referência ao registro de origem.

**Critério de aceite:** o usuário abre o projeto e entende sua história em ordem cronológica.

## SPEC-CRM-11 — Itens aprovados do projeto

**Achado:** o usuário precisa consultar o que foi vendido/aprovado. No Supabase atual, `projeto_itens` ainda está vazio.

**Evolução:** exibir itens históricos importados e itens produzidos por novas aprovações.

**Justificativa:** conecta o CRM à execução de estoque, compras e logística.

**Relação com o banco:** `projeto_itens`, venda, orçamento, produto, quantidade e snapshots de valor. A primeira carga virá da planilha `Vendas 01012025 a 23062026.xlsx`, usando apenas `GrupoCFOP = VENDAS`.

**Ação a ser realizada:** criar aba de itens somente para leitura operacional, com origem e situação de atendimento. Informar se o item veio de orçamento aprovado no novo sistema ou da importação histórica de vendas.

**Critério de aceite:** cada item informa origem, quantidade aprovada e situação atual.

**Atualização 07/07/2026:** a SPEC-014 detalha o card de itens aprovados e a SPEC-010 já existe no banco real. O CRM deve diferenciar `Reservado`, `Entrega futura`, `Separado`, `Entregue` e `Cancelado` lendo a view de saldos por `projeto_item_id` somente depois do hardening `20260707_023` e da policy de RLS; até lá, pode usar o rótulo genérico `Ativo` para itens válidos sem rastreabilidade detalhada.

## SPEC-CRM-12 — Registro manual de aceite/documento

**Achado:** a integração com DocSign não entra nesta versão, mas continua mapeada como plano futuro de baixa prioridade — não é um item descartado, apenas adiado. O processo, enquanto isso, precisa registrar que um documento foi concluído.

**Evolução:** permitir tarefa ou evento manual de aceite, com anexo opcional, nesta fase. Quando a prioridade permitir, mapear SPEC própria para integrar a assinatura real via webhook do DocuSign como gate de etapa do fluxo (conforme os 3 gates já identificados no processo comercial: contrato de projeto, contrato de sinal e faturamento de venda padrão).

**Justificativa:** mantém o processo funcionando sem criar a integração de assinatura agora, sem fechar a porta para implementá-la depois.

**Relação com o banco:** nesta fase, tarefa/checklist e anexo, sem estruturas específicas de envelope DocSign. A SPEC futura de baixa prioridade deve adicionar campos de envelope/status de assinatura quando for priorizada.

**Ação a ser realizada:** configurar o aceite como tarefa normal do fluxo nesta versão. Registrar a integração DocSign no backlog de baixa prioridade, não removê-la do roadmap.

**Critério de aceite:** o processo avança conforme a regra do checklist, sem chamar serviço externo, nesta fase; a integração futura com DocSign permanece documentada como pendência de baixa prioridade, não como item descartado.

## SPEC-CRM-13 — Projeto como cadastro único

**Achado:** Cadastro e CRM possuem telas de projeto.

**Evolução:** CRM será a única interface de criação e edição do projeto.

**Justificativa:** evita divergência de cliente, responsável e fluxo.

**Relação com o banco:** `projetos`, participantes, responsável e execução do fluxo.

**Ação a ser realizada:** manter APIs/comandos de projeto no CRM e tornar outras telas apenas consultas ou atalhos.

**Critério de aceite:** não existe segunda interface alterando o mesmo projeto de forma concorrente.

**Atualização 01/07/2026:** coluna `responsavel_obra_id` adicionada a `projetos`, com FK para `usuarios` (migration `20260701134423_add_responsavel_obra_id.sql`), corrigindo o erro `PGRST200` ao buscar o engenheiro responsável — formaliza o vínculo projeto↔responsável. Cadastro removeu Clientes/Projetos da navegação no mesmo período (ver `02_ESCOPO_CADASTRO.md`, SPEC-CAD-06), avançando esta SPEC pelo lado do Cadastro.

**Achado novo, fora do escopo desta SPEC:** no mesmo período, o CRM implementou **login próprio via Supabase Auth** (migration `20260701133912_seed_pedro_user_skip_pass.sql`), em vez de consumir a sessão central do Hub prevista em `01_ESCOPO_HUB_TI.md` (SPEC-HUB-05) e na `SPEC-007_Token_Acesso_Compartilhado_Entre_Sistemas.md`. A mesma migration commitou a senha do usuário seed em texto plano no repositório — ver [Adendo 03/07/2026](../06_ADENDO_ATUALIZACAO_03_07_2026.md), seção 5, e a pendência 11 do checklist geral.

## Itens removidos ou adiados

- espaços de CRM;
- enum fixo como regra futura;
- workflow hardcoded no frontend;
- automação DocSign (baixa prioridade — mapear como plano futuro, ver SPEC-CRM-12; não é item descartado);
- portal do cliente;
- motor genérico de IA.

## Fundamentação

- `Sistema/lucenera-crm-3bd29 (1)/src/pages/ProjectDetail.tsx`
- `Sistema/lucenera-crm-3bd29 (1)/src/pages/Projetos.tsx`
- `Sistema/lucenera-crm-3bd29 (1)/src/pages/Orcamentos.tsx`
- `Consolidação/Mapeamento de Processos/Mapeamento Markdown/05_projeto_luminotecnico.md`
- `Consolidação/Mapeamento de Processos/Mapeamento Markdown/09_troca_garantia_luminaria.md`
