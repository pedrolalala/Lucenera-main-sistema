# Domínio: CRM

## Papel no ecossistema

O CRM controla etapas, timeline, sub-status, checklists, responsáveis e SLA do fluxo comercial/operacional.

## Decisão atual

As etapas do CRM devem ser configuráveis pela UI.

Não hardcodar regra de negócio fixa no banco ou no código para:

- etapas;
- sub-status;
- checklists;
- bloqueios;
- tarefas paralelas;
- tarefas sequenciais;
- responsáveis;
- SLA ativo/inativo;
- exceções editáveis por caso.

## Fluxo esperado

Cada projeto/orçamento anda por uma timeline. Dentro de cada etapa, a interface permite configurar sub-status, checklists e regras de execução.

## Automações atuais

Automatizações identificadas no Supabase real relacionadas ao CRM/Pipeline:

- `public.get_dashboard_crm_by_closing(data_inicial date, data_final date)`: consulta projetos por fechamento no período.
- `public.get_dashboard_kpi(p_date_now date)`: métricas/KPIs de dashboard.
- `public.get_dashboard_stats()`: estatísticas de dashboard.
- `public.gerenciar_fluxo_projeto()`: automação atual de fluxo/status de projeto.
- `public.sync_responsavel_nome()`: sincroniza nome do responsável.
- `public.trigger_fechar_projeto()`: automação de fechamento.
- `public.trigger_proteger_fechamento()`: proteção de fechamento.

Triggers relacionadas:

- `public.projetos.trg_gerenciar_fluxo_projeto`
- `public.projetos.trg_fechar_projeto`
- `public.projetos.trg_proteger_fechamento`
- `public.projetos.trg_sync_responsavel_nome`
- `public.projetos.update_projetos_updated_at`
- `public.projetos.trg_projetos_stamp_sync_meta` (BEFORE) e `public.projetos.trg_projetos_sharepoint_push` (AFTER) — ver seção "SPEC-130" abaixo, **leia antes de rodar qualquer UPDATE em massa em `projetos`**.

Edge Functions relacionadas:

- `generate-report`: relatórios/exportações.

Edge Functions descontinuadas:

- `sync-fechamentos-automatica`: removida do projeto Supabase remoto e da pasta central pela SPEC-004. O status "projeto fechado" não é mais tratado como sincronização paralela; deve decorrer do fluxo de orçamento aprovado e das regras atuais de projeto.

Observação: apesar de existirem automações atuais de fluxo/status, a decisão de produto é evoluir CRM para configuração pela UI, sem hardcode de etapas/sub-status/checklists.

Observação sobre itens aprovados: a SPEC-014 prevê leitura de `projeto_itens` no detalhe do projeto. A SPEC-010 já existe no banco, mas o CRM só deve enriquecer a situação do item lendo a view de saldos por `projeto_item_id` (`q_reserva`, `q_entrega_futura`, `q_separado`, `q_entregue`) depois do hardening `20260707_023` e da policy de RLS. Até lá, deve usar rótulo genérico para itens válidos.

## SPEC-045 — Link do SharePoint no projeto

- `projetos.link_sharepoint` (text, nullable) — link da pasta raiz do projeto no SharePoint (subpastas padrão: WhatsApp, Projetos, Originais, Orçamentos, Fotos, Email, DocuSign). Preenchido manualmente pelo usuário no CRM (`/projeto/:id`), sem sincronização automática. Migration `20260724_061_link_sharepoint_projeto`.
- Não confundir com a Edge Function `sync-sharepoint` (acima) — essa sincroniza LISTAS de um site SharePoint diferente (`LUCENERAPROJETOS345`) para popular `projetos`/`tabela_precos` em massa; `link_sharepoint` é só um campo de texto livre, sem integração.

## SPEC-061 — Cadastro de cliente: e-mail obrigatório, complemento, projeto exige cliente (2026-08-05)

`contatos` ganhou `complemento`/`complemento_entrega`/`complemento_cobranca` (text, nullable) — os 3 blocos de endereço só tinham número, sem complemento. `clientSchema` (`ClientFormFields.tsx`, usado por `Clientes.tsx` e `NewContactModal.tsx`) passa a exigir e-mail no formulário (coluna do banco continua nullable, sem quebrar dados legados). `ProjectNew.tsx`: Cliente agora é obrigatório de verdade na criação de projeto — achado: a validação existente (`z.string().min(1)`) nunca bloqueava nada, porque o valor "não selecionado" é a string `'null'` (sentinela do combobox), que passa em `min(1)`. `contatos.vendedor_id`/`vendedor_padrao_id`: FK trocada de `auth.users(id)` para `funcionarios(id)` (decisão do usuário; 0 linhas afetadas). Skip `projectId 24580`.

## SPEC-064 — Perfil Ribeirão/São Paulo (2026-08-05)

`contatos.perfil` e `projetos.perfil` (`text`, `CHECK IN ('ribeirao','sao_paulo')`, nullable) — rótulo puramente informativo para a filial que a Lucenera está abrindo em São Paulo. **Não influencia nenhuma lógica de negócio.** Cliente e projeto têm cada um seu próprio campo, preenchido manualmente, sem herança/derivação entre eles — um projeto pode ter perfil diferente do cliente vinculado. Implementado em `ClientFormFields.tsx`/`ContatoDetail.tsx` (cliente) e `ProjectDetail.tsx` (projeto), Skip `projectId 24580`.

## SPEC-077 — Arquitetos múltiplos com % + Responsável vinculado a Funcionários (2026-08-11)

Duas mudanças de modelagem no cadastro de projeto:

- **`projeto_arquitetos`** (nova tabela de junção): `projeto_id` FK `projetos(id) ON DELETE CASCADE`, `arquiteto_id` FK `contatos(id)`, `percentual numeric(5,2) CHECK (percentual > 0 AND percentual <= 100)`, `UNIQUE(projeto_id, arquiteto_id)`. Substitui o antigo campo único `projetos.arquiteto_id` como fonte de verdade para divisão de lucro entre vários arquitetos no mesmo projeto — a coluna singular `arquiteto_id` continua existindo e é mantida sincronizada (arquiteto de maior percentual) só por compatibilidade com telas/relatórios que ainda a leem diretamente. Escrita só via RPC `SECURITY DEFINER` `replace_projeto_arquitetos(p_projeto_id, p_arquitetos jsonb)` (delete+insert atômico, valida soma=100% quando array não vazio e sem arquiteto duplicado, mesmo guard de permissão de `projetos_update`). RLS só libera `SELECT` para `authenticated`.
- **`projetos.responsavel_funcionario_id`** (nova coluna, FK `funcionarios(id) ON DELETE SET NULL`) — Responsável passa a ser uma seleção real de funcionário em vez de texto livre. **Achado crítico**: o texto livre `responsavel_nome` continua sendo gravado junto (mesmo INSERT/UPDATE) porque o trigger `fn_sync_equipe_por_responsavel` (`BEFORE UPDATE OF responsavel_nome`) usa esse texto para achar a equipe em `equipes_projetos`, que alimenta `vw_comissao_mensal` — um trigger encadeado que setasse `responsavel_nome` por trás não dispararia essa cláusula `OF`. O frontend sempre grava os dois campos juntos (nome vem do funcionário selecionado no dropdown). A coluna legada `projetos.responsavel_id` (FK morta para `usuarios`, sempre `null` na prática) foi deixada intocada — não repurposed, não removida.
- Backfill (`20260811_100_arquitetos_multiplos_responsavel_funcionario/005`): 2272 projetos com `arquiteto_id` preenchido migrados para `projeto_arquitetos` com 100%. Backfill de `responsavel_funcionario_id` a partir de `responsavel_nome` (texto livre, ~15 nomes distintos) **não foi automatizado** — ambíguo demais para confiar cegamente, fica pendente como revisão manual.
- Responsável e ao menos 1 arquiteto passam a ser obrigatórios na criação de projeto (`salvar-projeto` Edge Function e `ProjectDetail.tsx`), diferente do comportamento anterior (ambos opcionais — 1430/3702 projetos não tinham arquiteto).
- Escopo confirmado com o usuário: só Arquiteto ganha percentual/múltiplos; Engenheiro (`responsavel_obra_id`) e Responsável continuam vínculo único, sem divisão.
- Mesmo padrão replicado em Orçamentos (`orcamento_arquitetos` + `replace_orcamento_arquitetos`, sem campo Responsável — esse sistema não tem esse conceito). `vw_comissao_mensal` não depende de `arquiteto_id`, confirmado antes da mudança — trocar a cardinalidade desse campo não afeta comissão.

## SPEC-130 — Sincronização em duas vias com a lista SharePoint "Organização Projetos" (2026-09-11)

`projetos` tem uma trigger `AFTER INSERT OR UPDATE` (`trg_projetos_sharepoint_push`, function `trg_projetos_sharepoint_push_fn()`) que manda cada criação/edição relevante pra uma lista real do SharePoint via Microsoft Graph (Edge Functions `sharepoint-projetos-push`/`sharepoint-projetos-pull`, migrations em `supabase/db/migrations/20260911_132_sharepoint_projetos_sync_2via/`). Documentação completa: SPEC-130 e SPEC-131 em `03-Projeto/Planos de Ação/SPECs/`.

**⚠️ ANTES DE RODAR QUALQUER `UPDATE` EM MASSA EM `projetos`** (correção de dado, migração, script de limpeza): essa trigger dispara **uma chamada real pro Graph por linha afetada**. Um `UPDATE` em centenas/milhares de linhas de uma vez gera centenas/milhares de chamadas simultâneas — já aconteceu (2026-09-14) de um `UPDATE` de limpeza em 801 linhas floodar o Graph (throttling, ~430 erros). Pra qualquer correção em massa: ou (a) rode por um script com ritmo controlado/paginado (ver `scripts/backfill_sharepoint_projetos.py` como modelo), ou (b) desabilite a trigger antes e reabilite depois (`ALTER TABLE projetos DISABLE/ENABLE TRIGGER trg_projetos_sharepoint_push`).

**⚠️ Guarda de segurança existente, não remover sem entender por quê**: a function só dispara push quando `codigo` bate com o formato real de projeto (`^\d{2}\.\d+$`, ex. `26.267`). Isso é **proposital** — `projetos` também guarda registros internos que não são projeto de cliente (ex. `codigo` tipo `COM-1`..`COM-15` "Projeto Comissão N", `PRJ-TESTE`), e sem essa guarda esses registros quase viraram itens reais na lista de produção do SharePoint durante o incidente citado acima. Se um dia esses registros internos saírem de `projetos` para uma tabela própria, essa guarda pode ser reavaliada — até lá, ela é a única proteção contra isso.

Outras tabelas/RPCs relacionadas: `sharepoint_sync_log` (auditoria de cada push/pull), `sharepoint_status_map`, `sharepoint_estado_map`, `sharepoint_sync_state`, `gerar_codigo_provisorio_projeto()` (SPEC-228: `gerar_codigo_projeto()` removido — código oficial vem só do SharePoint; projeto nasce `PROV-NNNN`), `confirmar_push_sharepoint()`, `aplicar_pull_sharepoint()`, `aplicar_planilha_projetos()`.

## Ação a ser realizada

Modelar tabelas de configuração para etapas, sub-status, checklists, regras de bloqueio, paralelismo/sequência, SLA e responsáveis. O código deve ler essas configurações da UI, não codificar regras fixas por etapa.
