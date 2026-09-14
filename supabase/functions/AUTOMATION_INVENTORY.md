# Inventário de automações Supabase — Lucenera

Atualizado em 2026-06-26.

Este arquivo dá a visão completa das automações ligadas ao Supabase:

- Edge Functions;
- RPCs/funções Postgres;
- triggers/automações internas do banco.

## Fontes

- Edge Functions remotas: `supabase functions list --project-ref vcvcwzmbiftcawncibke`.
- Código das Edge Functions: `supabase/functions/<nome>/index.ts`.
- RPCs/funções Postgres: `supabase/db/current/03_functions.sql`.
- Triggers: `supabase/db/current/04_triggers.sql`.
- Correções pós-snapshot: `supabase/db/migrations/20260626_009_spec005_remocao_triggers_legados_aprovacao/`.

## Edge Functions

| Função | Status | Observação |
|---|---|---|
| `salvar-projeto` | ativa | Cria/salva projeto via Edge Function. |
| `update-project` | ativa | Atualiza projeto via Edge Function. |
| `chat-consulta` | ativa | Consulta/assistente. |
| `chat-agent` | ativa | Encaminha chat/agente para webhook externo. |
| `welcome-email` | ativa | E-mail de boas-vindas. |
| `generate-report` | ativa | Relatórios/exportações. |
| `sync-sharepoint` | **removida (2026-09-14)** | Descontinuada pela SPEC-130 — lia "Organização Projetos" **e** "Tabelas de Preços"; substituída por `sharepoint-projetos-push`/`sharepoint-projetos-pull`, que só tocam "Organização Projetos". Botão manual removido de `Sync.tsx` (Dashboard, Skip 41135). |
| `sharepoint-projetos-push` | ativa | SPEC-130 — push sistema→SharePoint (só lista "Organização Projetos"), disparada por trigger em `projetos`. |
| `sharepoint-projetos-pull` | ativa | SPEC-130 — pull SharePoint→sistema (só lista "Organização Projetos"), agendada via pg_cron a cada 5 min. |
| `sync-teams` | ativa | Integração/simulação Microsoft Teams. |
| `enviar-confirmacao-email` | ativa | Confirmação por e-mail de orçamento; revisar envio real. |
| `parse-budget-pdf` | ativa | Leitura/processamento inicial de PDF de orçamento. |
| `process-budget-pdf` | ativa | Processamento/geração/envio relacionado a PDF de orçamento. |
| `process-remittance` | ativa | Apoio ao fluxo de remessa; acionamento deve continuar manual/autorizado. |
| `process-billing-automation` | **removida em 26/06/2026** | Substituída funcionalmente pela RPC `aprovar_orcamento_financeiro`. Confirmado que não havia nenhum chamador (banco, frontend, cron ou webhook — `pg_cron`/`pg_net` nem estavam instalados neste projeto) antes da remoção. Ver `process-billing-automation/README.md`. |

### Edge Functions descontinuadas

| Função | Status | Motivo |
|---|---|---|
| `sync-fechamentos-automatica` | ausente no remoto | Descontinuada pela SPEC-004; `projetos_fechados` não é mais mecanismo paralelo de fechamento. |

## RPCs / funções Postgres

Estas funções estão no banco. Algumas são RPCs chamadas por UI/API; outras são funções internas usadas por triggers ou manutenção.

### Orçamentos, financeiro e projetos

- `public._lucenera_parse_prazo_pagamento(p_condicoes_pagamento text, p_prazo_pagamento_dias integer[])`
- `public.aprovar_orcamento_financeiro(p_orcamento_id uuid)`
- `public.aprovar_orcamento_financeiro_base_spec001(p_orcamento_id uuid)`
- `public.fn_auto_numero_orcamento()`
- `public.fn_gerar_numero_orcamento()`
- `public.fn_update_orcamento_timestamp()`
- `public.gerenciar_fluxo_projeto()`
- `public.set_orcamento_numero()`
- `public.sync_projeto_valor_total()`
- `public.sync_responsavel_nome()`
- `public.trigger_fechar_projeto()`
- `public.trigger_proteger_fechamento()`
- `public.trigger_proteger_parcelas()`
- `public.trigger_reserva_estoque()`

Nota SPEC-005: `public.fn_aprovar_orcamento()` foi removida do banco remoto depois do snapshot de 2026-06-25. Se ela ainda aparecer em `db/current/03_functions.sql`, trate como resíduo do snapshot antigo.

### Usuários, papéis e acesso

- `public.admin_update_user_password(p_user_id uuid, p_new_password text)`
- `public.admin_update_user_role(p_user_id uuid, p_role text)`
- `public.admin_update_user_status(p_user_id uuid, p_ativo boolean)`
- `public.criar_usuario(p_email text, p_password text, p_nome text, p_role usuario_role)`
- `public.get_user_role()`
- `public.handle_new_auth_user()`
- `public.handle_new_user()`
- `public.is_admin()`
- `public.is_ubiqua_admin()`

### Dashboards, relatórios e consultas

- `public.get_dashboard_crm_by_closing(data_inicial date, data_final date)`
- `public.get_dashboard_kpi(p_date_now date)`
- `public.get_dashboard_stats()`
- `public.get_faltas_injustificadas(p_funcionario_id uuid, p_inicio date, p_fim date)`
- `public.get_latest_transaction_id()`
- `public.get_vendedores()`
- `public.stats_datacenter()`

### Produtos, catálogo e Ubiqua

- `public.fn_atualizar_preco_venda()`
- `public.generate_product_slug(nome text, preco numeric)`
- `public.get_next_sku(prefix text)`
- `public.trigger_update_revenda_ubiqua_slug()`
- `public.update_revenda_ubiqua_ordem(payload jsonb)`
- `public.update_revenda_ubiqua_updated_at()`

### Contatos, nomes e sincronizações internas

- `public.handle_contato_tipo()`
- `public.propagate_contato_nome()`
- `public.propagate_projeto_codigo()`
- `public.propagate_usuario_nome()`
- `public.sync_separacao_cliente()`
- `public.sync_separacao_codigo_obra()`
- `public.trigger_separacao_pronta()`
- `public.track_reagendamento()`

### Auditoria, updated_at e utilitários

- `public.fn_atualiza_updated_at()`
- `public.fn_log_auditoria()`
- `public.handle_updated_at()`
- `public.limpar_staging_processados()`
- `public.set_updated_at()`
- `public.unaccent(regdictionary, text)`
- `public.unaccent(text)`
- `public.unaccent_init(internal)`
- `public.unaccent_lexize(internal, internal, internal, internal)`
- `public.update_updated_at_column()`

## Triggers / automações internas

Triggers ligam eventos de tabela a funções do banco. O código completo do snapshot está em `supabase/db/current/04_triggers.sql`.

Atenção: a SPEC-005 removeu `public.orcamentos.trg_aprovar_orcamento` e ajustou `public.projeto_parcelas.trg_proteger_parcelas` depois do snapshot.

### Auth

- `auth.users.on_auth_user_created`

### Cadastros e contatos

- `public.contatos.contatos_updated_at`
- `public.contatos.on_contato_created`
- `public.contatos.trg_propagate_contato_nome`
- `public.fornecedores.trg_fornecedores_auditoria`
- `public.fornecedores.trg_fornecedores_updated_at`
- `public.funcionarios.funcionarios_updated_at`
- `public.usuarios.trg_propagate_usuario_nome`
- `public.usuarios.usuarios_updated_at`

### Orçamentos, projetos e financeiro

- `public.contas_bancarias.contas_updated_at`
- `public.custos_recorrentes.custos_rec_updated_at`
- `public.orcamentos.trigger_set_orcamento_numero`
- `public.orcamentos_revenda_ubiqua.trigger_auto_numero_orcamento`
- `public.orcamentos_revenda_ubiqua.trigger_orcamento_updated_at`
- `public.projeto_itens.projeto_itens_updated_at`
- `public.projeto_itens.trg_sync_valor_total`
- `public.projeto_parcelas.trg_proteger_parcelas`
- `public.projeto_parcelas.update_parcelas_updated_at`
- `public.projeto_sinal.projeto_sinal_updated_at`
- `public.projetos.projetos_updated_at`
- `public.projetos.trg_fechar_projeto`
- `public.projetos.trg_gerenciar_fluxo_projeto`
- `public.projetos.trg_propagate_projeto_codigo`
- `public.projetos.trg_proteger_fechamento`
- `public.projetos.trg_reserva_estoque`
- `public.projetos.trg_sync_responsavel_nome`
- `public.projetos.update_projetos_updated_at`
- `public.remessas.trg_remessas_auditoria`
- `public.remessas.trg_remessas_updated_at`
- `public.vendas.update_vendas_updated_at`

### Produtos, catálogo e Ubiqua

- `public.produtos.produtos_updated_at`
- `public.produtos.trg_atualizar_preco_venda`
- `public.produtos.trg_calculo_preco_venda`
- `public.produtos.update_produtos_updated_at`
- `public.revenda_ubiqua.trg_revenda_ubiqua_slug`
- `public.revenda_ubiqua.trigger_revenda_ubiqua_updated_at`

### Logística

- `public.entregas.entregas_updated_at`
- `public.separacoes.separacoes_updated_at`
- `public.separacoes.trg_separacao_pronta`
- `public.separacoes.trg_sync_sep_cliente`
- `public.separacoes.trg_sync_sep_codigo_obra`
- `public.separacoes.trg_track_reagendamento`

### Storage

- `storage.buckets.enforce_bucket_name_length_trigger`
- `storage.buckets.protect_buckets_delete`
- `storage.objects.protect_objects_delete`
- `storage.objects.update_objects_updated_at`

## Decisões e próximos passos

1. O fluxo novo de orçamento aprovado deve usar a RPC `public.aprovar_orcamento_financeiro(p_orcamento_id uuid)`.
2. ~~Confirmar se `process-billing-automation` tem scheduler/webhook externo~~ — confirmado em 26/06/2026 que não há chamador no banco real nem no frontend; falta só checar Cron Jobs no painel e então remover a função remota.
3. Reextrair `db/current/` para remover resíduos do snapshot pré-SPEC-005.
4. Functions da Logística backup devem ser analisadas durante a replicação do backup para o novo sistema de Logística.
5. Functions/RPCs encontradas apenas em projetos isolados não devem ser promovidas como fonte de verdade sem revisão.
