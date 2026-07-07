# Inventário do schema Supabase

Atualizado a partir do Supabase real em: 2026-07-07.

Fonte: `supabase/db/current/01_schema_full.sql`, `03_functions.sql`, `05_views.sql` e consulta direta via `psql` usando `SUPABASE_DB_URL` local.

## Resumo

- `public`: 74 tabelas, 42 views/materialized views, 116 objetos relacionais inventariados.
- `auth`: 23 tabelas, 0 views/materialized views, 23 objetos relacionais inventariados.
- `storage`: 8 tabelas, 0 views/materialized views, 8 objetos relacionais inventariados.

## Objetos por schema

### `public`

- `boletos` — Tabela
- `categorias_financeiras` — Tabela
- `categorias_produto` — Tabela
- `contas_bancarias` — Tabela
- `contato_origens` — Tabela
- `contato_tipos` — Tabela
- `contatos` — Tabela
- `contatos_revisao` — Tabela
- `controle_falta` — Tabela
- `custos_recorrentes` — Tabela
- `custos_recorrentes_lancamentos` — Tabela
- `departamentos` — Tabela
- `empresa_ubiqua` — Tabela
- `empresas` — Tabela
- `entregas` — Tabela
- `entregas_finalizadas` — Tabela
- `equipes_projetos` — Tabela
- `estoque_itens` — Tabela
- `estoque_movimentos_projeto_item` — Tabela
- `estoque_saldos_projeto_item` — Tabela
- `ferias` — Tabela
- `folha_pagamento` — Tabela
- `fornecedores` — Tabela
- `funcionarios` — Tabela
- `funcionarios_beneficios_empresas` — Tabela
- `funcionarios_detalhes` — Tabela
- `funcionarios_financeiro` — Tabela
- `funcionarios_novo` — Tabela
- `historico_status_orcamentos` — Tabela
- `informacoes_cliente_ubiqua` — Tabela
- `itens_orcamento_ubiqua` — Tabela
- `logs_auditoria` — Tabela
- `logs_operacoes` — Tabela
- `marcas` — Tabela
- `negociacoes` — Tabela
- `notas_fiscais` — Tabela
- `orcamento_itens` — Tabela
- `orcamentos` — Tabela
- `orcamentos_revenda_ubiqua` — Tabela
- `pedido_compra` — Tabela
- `periodos_aquisitivos` — Tabela
- `plano_de_contas` — Tabela
- `produtos` — Tabela
- `projeto_itens` — Tabela
- `projeto_parcelas` — Tabela
- `projeto_parcelas_backup_migration` — Tabela
- `projeto_produtos` — Tabela
- `projeto_sinal` — Tabela
- `projetos` — Tabela
- `projetos_fechados` — Tabela
- `quote_history` — Tabela
- `quotes` — Tabela
- `remessas` — Tabela
- `retornos_processados` — Tabela
- `revenda_ubiqua` — Tabela
- `separacao_arquivos` — Tabela
- `separacao_itens` — Tabela
- `separacoes` — Tabela
- `separacoes_arquivos` — Tabela
- `solicitacoes_compra` — Tabela
- `staging_conta_pagar` — Tabela
- `staging_conta_receber` — Tabela
- `staging_import_bruto` — Tabela
- `staging_pedido_compra` — Tabela
- `staging_produtos` — Tabela
- `sync_history` — Tabela
- `systems` — Tabela
- `transacoes` — Tabela
- `user_roles_separacao` — Tabela
- `user_system_access` — Tabela
- `usuarios` — Tabela
- `usuarios_ubiqua` — Tabela
- `vendas` — Tabela
- `vendas_marca` — Tabela
- `v_cash_flow_lucenera` — View
- `vw_catalogo_ubiqua` — View
- `vw_catalogo_unificado` — View
- `vw_comissao_mensal` — View
- `vw_conferencia_financeira` — View
- `vw_controle_ferias_clt` — View
- `vw_custos_pendentes_mes` — View
- `vw_dashboard_crm_fechamento` — View
- `vw_detalhe_produto_estoque` — View
- `vw_estoque_liquido` — View
- `vw_estoque_por_marca` — View
- `vw_estoque_por_produto_projeto` — View
- `vw_estoque_produtos` — View
- `vw_estoque_resumo` — View
- `vw_estoque_saldos_projeto_item` — View
- `vw_financeiro_projetos` — View
- `vw_fluxo_caixa_projetado` — View
- `vw_fornecedores_remessas` — View
- `vw_fornecedores_resumo` — View
- `vw_funcionarios_completo` — View
- `vw_historico_faltas` — View
- `vw_logs_auditoria_recentes` — View
- `vw_orcamentos_aprovacao_financeira_auditoria` — View
- `vw_produtos_estoque_detalhado` — View
- `vw_produtos_estoque_por_local` — View
- `vw_projetos_dashboard` — View
- `vw_projetos_pipeline` — View
- `vw_projetos_por_responsavel` — View
- `vw_projetos_por_status` — View
- `vw_projetos_resumo` — View
- `vw_projetos_sem_empresa` — View
- `vw_projetos_sem_responsavel` — View
- `vw_projetos_status_enum` — View
- `vw_remessas_completa` — View
- `vw_remessas_resumo_status` — View
- `vw_remessas_vencimento` — View
- `vw_separacoes_agenda` — View
- `vw_staging_resumo` — View
- `vw_transacoes_completas` — View
- `vw_vendas_loja` — View
- `vw_vendas_por_projeto` — View
- `vw_vendas_produtos` — View

### `auth`

- `audit_log_entries` — Tabela
- `custom_oauth_providers` — Tabela
- `flow_state` — Tabela
- `identities` — Tabela
- `instances` — Tabela
- `mfa_amr_claims` — Tabela
- `mfa_challenges` — Tabela
- `mfa_factors` — Tabela
- `oauth_authorizations` — Tabela
- `oauth_client_states` — Tabela
- `oauth_clients` — Tabela
- `oauth_consents` — Tabela
- `one_time_tokens` — Tabela
- `refresh_tokens` — Tabela
- `saml_providers` — Tabela
- `saml_relay_states` — Tabela
- `schema_migrations` — Tabela
- `sessions` — Tabela
- `sso_domains` — Tabela
- `sso_providers` — Tabela
- `users` — Tabela
- `webauthn_challenges` — Tabela
- `webauthn_credentials` — Tabela

### `storage`

- `buckets` — Tabela
- `buckets_analytics` — Tabela
- `buckets_vectors` — Tabela
- `migrations` — Tabela
- `objects` — Tabela
- `s3_multipart_uploads` — Tabela
- `s3_multipart_uploads_parts` — Tabela
- `vector_indexes` — Tabela

## Colunas por tabela/view

### `auth.audit_log_entries`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `instance_id` | uuid | YES |  |
| `id` | uuid | NO |  |
| `payload` | json | YES |  |
| `created_at` | timestamp with time zone | YES |  |
| `ip_address` | character varying | NO | ''::character varying |

### `auth.custom_oauth_providers`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `provider_type` | text | NO |  |
| `identifier` | text | NO |  |
| `name` | text | NO |  |
| `client_id` | text | NO |  |
| `client_secret` | text | NO |  |
| `acceptable_client_ids` | ARRAY | NO | '{}'::text[] |
| `scopes` | ARRAY | NO | '{}'::text[] |
| `pkce_enabled` | boolean | NO | true |
| `attribute_mapping` | jsonb | NO | '{}'::jsonb |
| `authorization_params` | jsonb | NO | '{}'::jsonb |
| `enabled` | boolean | NO | true |
| `email_optional` | boolean | NO | false |
| `issuer` | text | YES |  |
| `discovery_url` | text | YES |  |
| `skip_nonce_check` | boolean | NO | false |
| `cached_discovery` | jsonb | YES |  |
| `discovery_cached_at` | timestamp with time zone | YES |  |
| `authorization_url` | text | YES |  |
| `token_url` | text | YES |  |
| `userinfo_url` | text | YES |  |
| `jwks_uri` | text | YES |  |
| `created_at` | timestamp with time zone | NO | now() |
| `updated_at` | timestamp with time zone | NO | now() |
| `custom_claims_allowlist` | ARRAY | NO | '{}'::text[] |

### `auth.flow_state`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO |  |
| `user_id` | uuid | YES |  |
| `auth_code` | text | YES |  |
| `code_challenge_method` | USER-DEFINED | YES |  |
| `code_challenge` | text | YES |  |
| `provider_type` | text | NO |  |
| `provider_access_token` | text | YES |  |
| `provider_refresh_token` | text | YES |  |
| `created_at` | timestamp with time zone | YES |  |
| `updated_at` | timestamp with time zone | YES |  |
| `authentication_method` | text | NO |  |
| `auth_code_issued_at` | timestamp with time zone | YES |  |
| `invite_token` | text | YES |  |
| `referrer` | text | YES |  |
| `oauth_client_state_id` | uuid | YES |  |
| `linking_target_id` | uuid | YES |  |
| `email_optional` | boolean | NO | false |

### `auth.identities`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `provider_id` | text | NO |  |
| `user_id` | uuid | NO |  |
| `identity_data` | jsonb | NO |  |
| `provider` | text | NO |  |
| `last_sign_in_at` | timestamp with time zone | YES |  |
| `created_at` | timestamp with time zone | YES |  |
| `updated_at` | timestamp with time zone | YES |  |
| `email` | text | YES |  |
| `id` | uuid | NO | gen_random_uuid() |

### `auth.instances`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO |  |
| `uuid` | uuid | YES |  |
| `raw_base_config` | text | YES |  |
| `created_at` | timestamp with time zone | YES |  |
| `updated_at` | timestamp with time zone | YES |  |

### `auth.mfa_amr_claims`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `session_id` | uuid | NO |  |
| `created_at` | timestamp with time zone | NO |  |
| `updated_at` | timestamp with time zone | NO |  |
| `authentication_method` | text | NO |  |
| `id` | uuid | NO |  |

### `auth.mfa_challenges`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO |  |
| `factor_id` | uuid | NO |  |
| `created_at` | timestamp with time zone | NO |  |
| `verified_at` | timestamp with time zone | YES |  |
| `ip_address` | inet | NO |  |
| `otp_code` | text | YES |  |
| `web_authn_session_data` | jsonb | YES |  |

### `auth.mfa_factors`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO |  |
| `user_id` | uuid | NO |  |
| `friendly_name` | text | YES |  |
| `factor_type` | USER-DEFINED | NO |  |
| `status` | USER-DEFINED | NO |  |
| `created_at` | timestamp with time zone | NO |  |
| `updated_at` | timestamp with time zone | NO |  |
| `secret` | text | YES |  |
| `phone` | text | YES |  |
| `last_challenged_at` | timestamp with time zone | YES |  |
| `web_authn_credential` | jsonb | YES |  |
| `web_authn_aaguid` | uuid | YES |  |
| `last_webauthn_challenge_data` | jsonb | YES |  |

### `auth.oauth_authorizations`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO |  |
| `authorization_id` | text | NO |  |
| `client_id` | uuid | NO |  |
| `user_id` | uuid | YES |  |
| `redirect_uri` | text | NO |  |
| `scope` | text | NO |  |
| `state` | text | YES |  |
| `resource` | text | YES |  |
| `code_challenge` | text | YES |  |
| `code_challenge_method` | USER-DEFINED | YES |  |
| `response_type` | USER-DEFINED | NO | 'code'::auth.oauth_response_type |
| `status` | USER-DEFINED | NO | 'pending'::auth.oauth_authorization_status |
| `authorization_code` | text | YES |  |
| `created_at` | timestamp with time zone | NO | now() |
| `expires_at` | timestamp with time zone | NO | (now() + '00:03:00'::interval) |
| `approved_at` | timestamp with time zone | YES |  |
| `nonce` | text | YES |  |

### `auth.oauth_client_states`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO |  |
| `provider_type` | text | NO |  |
| `code_verifier` | text | YES |  |
| `created_at` | timestamp with time zone | NO |  |

### `auth.oauth_clients`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO |  |
| `client_secret_hash` | text | YES |  |
| `registration_type` | USER-DEFINED | NO |  |
| `redirect_uris` | text | NO |  |
| `grant_types` | text | NO |  |
| `client_name` | text | YES |  |
| `client_uri` | text | YES |  |
| `logo_uri` | text | YES |  |
| `created_at` | timestamp with time zone | NO | now() |
| `updated_at` | timestamp with time zone | NO | now() |
| `deleted_at` | timestamp with time zone | YES |  |
| `client_type` | USER-DEFINED | NO | 'confidential'::auth.oauth_client_type |
| `token_endpoint_auth_method` | text | NO |  |

### `auth.oauth_consents`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO |  |
| `user_id` | uuid | NO |  |
| `client_id` | uuid | NO |  |
| `scopes` | text | NO |  |
| `granted_at` | timestamp with time zone | NO | now() |
| `revoked_at` | timestamp with time zone | YES |  |

### `auth.one_time_tokens`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO |  |
| `user_id` | uuid | NO |  |
| `token_type` | USER-DEFINED | NO |  |
| `token_hash` | text | NO |  |
| `relates_to` | text | NO |  |
| `created_at` | timestamp without time zone | NO | now() |
| `updated_at` | timestamp without time zone | NO | now() |

### `auth.refresh_tokens`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `instance_id` | uuid | YES |  |
| `id` | bigint | NO | nextval('auth.refresh_tokens_id_seq'::regclass) |
| `token` | character varying | YES |  |
| `user_id` | character varying | YES |  |
| `revoked` | boolean | YES |  |
| `created_at` | timestamp with time zone | YES |  |
| `updated_at` | timestamp with time zone | YES |  |
| `parent` | character varying | YES |  |
| `session_id` | uuid | YES |  |

### `auth.saml_providers`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO |  |
| `sso_provider_id` | uuid | NO |  |
| `entity_id` | text | NO |  |
| `metadata_xml` | text | NO |  |
| `metadata_url` | text | YES |  |
| `attribute_mapping` | jsonb | YES |  |
| `created_at` | timestamp with time zone | YES |  |
| `updated_at` | timestamp with time zone | YES |  |
| `name_id_format` | text | YES |  |

### `auth.saml_relay_states`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO |  |
| `sso_provider_id` | uuid | NO |  |
| `request_id` | text | NO |  |
| `for_email` | text | YES |  |
| `redirect_to` | text | YES |  |
| `created_at` | timestamp with time zone | YES |  |
| `updated_at` | timestamp with time zone | YES |  |
| `flow_state_id` | uuid | YES |  |

### `auth.schema_migrations`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `version` | character varying | NO |  |

### `auth.sessions`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO |  |
| `user_id` | uuid | NO |  |
| `created_at` | timestamp with time zone | YES |  |
| `updated_at` | timestamp with time zone | YES |  |
| `factor_id` | uuid | YES |  |
| `aal` | USER-DEFINED | YES |  |
| `not_after` | timestamp with time zone | YES |  |
| `refreshed_at` | timestamp without time zone | YES |  |
| `user_agent` | text | YES |  |
| `ip` | inet | YES |  |
| `tag` | text | YES |  |
| `oauth_client_id` | uuid | YES |  |
| `refresh_token_hmac_key` | text | YES |  |
| `refresh_token_counter` | bigint | YES |  |
| `scopes` | text | YES |  |

### `auth.sso_domains`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO |  |
| `sso_provider_id` | uuid | NO |  |
| `domain` | text | NO |  |
| `created_at` | timestamp with time zone | YES |  |
| `updated_at` | timestamp with time zone | YES |  |

### `auth.sso_providers`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO |  |
| `resource_id` | text | YES |  |
| `created_at` | timestamp with time zone | YES |  |
| `updated_at` | timestamp with time zone | YES |  |
| `disabled` | boolean | YES |  |

### `auth.users`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `instance_id` | uuid | YES |  |
| `id` | uuid | NO |  |
| `aud` | character varying | YES |  |
| `role` | character varying | YES |  |
| `email` | character varying | YES |  |
| `encrypted_password` | character varying | YES |  |
| `email_confirmed_at` | timestamp with time zone | YES |  |
| `invited_at` | timestamp with time zone | YES |  |
| `confirmation_token` | character varying | YES |  |
| `confirmation_sent_at` | timestamp with time zone | YES |  |
| `recovery_token` | character varying | YES |  |
| `recovery_sent_at` | timestamp with time zone | YES |  |
| `email_change_token_new` | character varying | YES |  |
| `email_change` | character varying | YES |  |
| `email_change_sent_at` | timestamp with time zone | YES |  |
| `last_sign_in_at` | timestamp with time zone | YES |  |
| `raw_app_meta_data` | jsonb | YES |  |
| `raw_user_meta_data` | jsonb | YES |  |
| `is_super_admin` | boolean | YES |  |
| `created_at` | timestamp with time zone | YES |  |
| `updated_at` | timestamp with time zone | YES |  |
| `phone` | text | YES | NULL::character varying |
| `phone_confirmed_at` | timestamp with time zone | YES |  |
| `phone_change` | text | YES | ''::character varying |
| `phone_change_token` | character varying | YES | ''::character varying |
| `phone_change_sent_at` | timestamp with time zone | YES |  |
| `confirmed_at` | timestamp with time zone | YES |  |
| `email_change_token_current` | character varying | YES | ''::character varying |
| `email_change_confirm_status` | smallint | YES | 0 |
| `banned_until` | timestamp with time zone | YES |  |
| `reauthentication_token` | character varying | YES | ''::character varying |
| `reauthentication_sent_at` | timestamp with time zone | YES |  |
| `is_sso_user` | boolean | NO | false |
| `deleted_at` | timestamp with time zone | YES |  |
| `is_anonymous` | boolean | NO | false |

### `auth.webauthn_challenges`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `user_id` | uuid | YES |  |
| `challenge_type` | text | NO |  |
| `session_data` | jsonb | NO |  |
| `created_at` | timestamp with time zone | NO | now() |
| `expires_at` | timestamp with time zone | NO |  |

### `auth.webauthn_credentials`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `user_id` | uuid | NO |  |
| `credential_id` | bytea | NO |  |
| `public_key` | bytea | NO |  |
| `attestation_type` | text | NO | ''::text |
| `aaguid` | uuid | YES |  |
| `sign_count` | bigint | NO | 0 |
| `transports` | jsonb | NO | '[]'::jsonb |
| `backup_eligible` | boolean | NO | false |
| `backed_up` | boolean | NO | false |
| `friendly_name` | text | NO | ''::text |
| `created_at` | timestamp with time zone | NO | now() |
| `updated_at` | timestamp with time zone | NO | now() |
| `last_used_at` | timestamp with time zone | YES |  |

### `public.boletos`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `nosso_numero` | text | NO |  |
| `nome_pagador` | text | YES |  |
| `valor` | numeric | YES |  |
| `vencimento` | date | YES |  |
| `data_pagamento` | date | YES |  |
| `valor_pago` | numeric | YES |  |
| `status` | text | NO | 'Pendente'::text |
| `empresa_id` | uuid | YES |  |
| `numero_documento` | text | YES |  |
| `tipo` | text | YES | 'Normal'::text |
| `parcela_id` | uuid | YES |  |
| `tipo_operacao` | text | YES | 'CR'::text |
| `num_parcela` | integer | YES | 1 |
| `total_parcelas` | integer | YES | 1 |
| `venda` | text | YES |  |
| `fatura` | text | YES |  |
| `emissao` | date | YES | CURRENT_DATE |
| `comprovante_url` | text | YES |  |
| `orcamento_id` | uuid | YES |  |

### `public.categorias_financeiras`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `nome` | text | NO |  |
| `tipo` | USER-DEFINED | NO |  |
| `grupo` | text | NO |  |
| `icone` | text | YES |  |
| `ativo` | boolean | NO | true |
| `created_at` | timestamp with time zone | NO | now() |

### `public.categorias_produto`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `codigo_connect` | integer | NO |  |
| `nome` | text | NO |  |
| `ativo` | boolean | NO | true |
| `created_at` | timestamp with time zone | NO | now() |

### `public.contas_bancarias`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `nome` | text | NO |  |
| `tipo` | USER-DEFINED | NO |  |
| `saldo` | numeric | NO | 0 |
| `banco` | text | YES |  |
| `agencia` | character varying | YES |  |
| `conta` | character varying | YES |  |
| `status` | text | NO | 'Ativa'::text |
| `created_at` | timestamp with time zone | NO | now() |
| `updated_at` | timestamp with time zone | NO | now() |
| `empresa_id` | uuid | YES |  |
| `codigo_connect` | integer | YES |  |
| `nome_connect` | text | YES |  |

### `public.contato_origens`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `contato_id` | uuid | NO |  |
| `origem` | text | NO |  |
| `codigo_legado` | integer | NO |  |

### `public.contato_tipos`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `contato_id` | uuid | NO |  |
| `tipo` | text | NO |  |

### `public.contatos`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `codigo_legado` | bigint | YES |  |
| `tipo` | USER-DEFINED | NO |  |
| `nome` | text | NO |  |
| `nome_empresa` | text | YES |  |
| `cpf_cnpj` | character varying | YES |  |
| `rg` | character varying | YES |  |
| `email` | character varying | YES |  |
| `email_financeiro` | character varying | YES |  |
| `telefone` | character varying | YES |  |
| `celular` | character varying | YES |  |
| `endereco` | text | YES |  |
| `bairro` | character varying | YES |  |
| `cep` | character varying | YES |  |
| `cidade` | character varying | YES |  |
| `estado` | character varying | YES |  |
| `data_nascimento` | date | YES |  |
| `observacoes` | text | YES |  |
| `ativo` | boolean | YES | true |
| `created_at` | timestamp with time zone | YES | now() |
| `created_by` | uuid | YES |  |
| `endereco_comercial` | text | YES |  |
| `bairro_comercial` | character varying | YES |  |
| `cep_comercial` | character varying | YES |  |
| `cidade_comercial` | character varying | YES |  |
| `estado_comercial` | character varying | YES |  |
| `especialidade` | text | YES |  |
| `updated_at` | timestamp with time zone | YES |  |
| `canonical_id` | uuid | YES |  |
| `tipo_pessoa` | character varying | YES |  |
| `cpf` | character varying | YES |  |
| `cnpj` | character varying | YES |  |
| `empresa_id` | uuid | YES |  |
| `nao_residente` | boolean | NO | false |
| `razao_social` | text | YES |  |
| `inscricao_estadual` | text | YES |  |
| `inscricao_municipal` | text | YES |  |
| `limite_credito` | numeric | YES |  |
| `regime_apuracao` | text | YES |  |
| `email_alternativo` | text | YES |  |
| `vendedor_id` | uuid | YES |  |
| `numero` | text | YES |  |
| `cep_entrega` | text | YES |  |
| `endereco_entrega` | text | YES |  |
| `numero_entrega` | text | YES |  |
| `bairro_entrega` | text | YES |  |
| `cidade_entrega` | text | YES |  |
| `estado_entrega` | text | YES |  |
| `cep_cobranca` | text | YES |  |
| `endereco_cobranca` | text | YES |  |
| `numero_cobranca` | text | YES |  |
| `bairro_cobranca` | text | YES |  |
| `cidade_cobranca` | text | YES |  |
| `estado_cobranca` | text | YES |  |
| `vendedor_padrao_id` | uuid | YES |  |
| `status_comercial` | text | YES | 'Ativo'::text |

### `public.contatos_revisao`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `id_a` | uuid | NO |  |
| `id_b` | uuid | NO |  |
| `score` | numeric | NO |  |
| `decisao` | text | NO | 'pendente'::text |
| `criado_em` | timestamp with time zone | NO | now() |
| `revisado_em` | timestamp with time zone | YES |  |

### `public.controle_falta`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `funcionario_id` | uuid | NO |  |
| `data` | date | NO |  |
| `hora_entrada` | time without time zone | YES |  |
| `hora_saida` | time without time zone | YES |  |
| `total_horas` | numeric | YES |  |
| `status` | text | YES |  |
| `justificativa` | text | YES |  |
| `created_at` | timestamp with time zone | NO | now() |

### `public.custos_recorrentes`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `categoria_id` | uuid | YES |  |
| `conta_id` | uuid | YES |  |
| `descricao` | text | NO |  |
| `valor` | numeric | NO |  |
| `dia_vencimento` | integer | YES |  |
| `frequencia` | USER-DEFINED | NO | 'mensal'::frequencia_tipo |
| `data_inicio` | date | NO |  |
| `data_fim` | date | YES |  |
| `ativo` | boolean | NO | true |
| `created_by` | uuid | YES |  |
| `created_at` | timestamp with time zone | NO | now() |
| `updated_at` | timestamp with time zone | NO | now() |

### `public.custos_recorrentes_lancamentos`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `custo_id` | uuid | NO |  |
| `competencia` | date | NO |  |
| `data_vencimento` | date | NO |  |
| `data_pagamento` | date | YES |  |
| `valor_original` | numeric | NO |  |
| `valor_pago` | numeric | YES |  |
| `juros` | numeric | NO | 0 |
| `multa` | numeric | NO | 0 |
| `desconto` | numeric | NO | 0 |
| `status` | USER-DEFINED | NO | 'pendente'::lancamento_status |
| `transacao_id` | uuid | YES |  |
| `created_at` | timestamp with time zone | NO | now() |

### `public.departamentos`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `nome` | text | NO |  |
| `descricao` | text | YES |  |
| `ativo` | boolean | NO | true |
| `created_at` | timestamp with time zone | NO | now() |

### `public.empresa_ubiqua`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `nome_fantasia` | text | NO |  |
| `razao_social` | text | YES |  |
| `cnpj` | text | NO |  |
| `cidade` | text | NO |  |
| `estado` | text | NO |  |
| `created_at` | timestamp with time zone | NO | now() |

### `public.empresas`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `codigo` | integer | NO |  |
| `nome` | text | NO |  |
| `razao_social` | text | YES |  |
| `cnpj` | character varying | YES |  |
| `cidade` | text | NO | 'Ribeirão Preto'::text |
| `estado` | character varying | NO | 'SP'::character varying |
| `ativo` | boolean | NO | true |
| `created_at` | timestamp with time zone | NO | now() |
| `updated_at` | timestamp with time zone | NO | now() |
| `inscricao_estadual` | text | YES |  |
| `logradouro` | text | YES |  |
| `numero` | text | YES |  |
| `complemento` | text | YES |  |
| `bairro` | text | YES |  |
| `cep` | text | YES |  |
| `cor_hex` | text | YES |  |
| `regime_tributario` | text | YES |  |

### `public.entregas`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `separacao_id` | uuid | YES |  |
| `projeto_id` | uuid | YES |  |
| `entregador_id` | uuid | YES |  |
| `endereco_entrega` | text | YES |  |
| `contato_destino` | text | YES |  |
| `delivery_type` | text | NO | 'flexible'::text |
| `scheduled_time` | time without time zone | YES |  |
| `data_prevista` | date | YES |  |
| `data_entrega` | date | YES |  |
| `status` | USER-DEFINED | NO | 'Pendente'::entrega_status |
| `comprovante_url` | text | YES |  |
| `avaliacao` | integer | YES |  |
| `observacoes` | text | YES |  |
| `created_at` | timestamp with time zone | NO | now() |
| `updated_at` | timestamp with time zone | NO | now() |

### `public.entregas_finalizadas`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `separacao_id` | uuid | YES |  |
| `cliente` | text | YES |  |
| `codigo_obra` | text | YES |  |
| `data_entrega_real` | timestamp with time zone | YES |  |
| `endereco` | text | YES |  |
| `recebido_por` | text | YES |  |
| `telefone` | text | YES |  |
| `material_tipo` | text | YES |  |
| `material_conteudo` | text | YES |  |
| `fotos_urls` | text | YES |  |
| `observacoes` | text | YES |  |
| `created_at` | timestamp with time zone | YES | now() |
| `numero_pedido` | text | YES |  |
| `vendedor` | text | YES |  |
| `observacoes_internas` | text | YES |  |
| `gestora_equipe` | text | YES |  |
| `numero_entrega` | text | YES |  |
| `data_solicitacao` | timestamp with time zone | YES |  |

### `public.equipes_projetos`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `equipes` | text | YES |  |
| `created_at` | timestamp with time zone | NO | now() |

### `public.estoque_itens`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `produto_id` | uuid | NO |  |
| `local` | USER-DEFINED | NO | 'Estoque'::estoque_local |
| `quantidade` | numeric | NO | 0 |
| `atualizado_por` | uuid | YES |  |
| `atualizado_em` | timestamp with time zone | NO | now() |
| `quantidade_reservada` | numeric | NO | 0 |

### `public.estoque_movimentos_projeto_item`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `projeto_item_id` | uuid | NO |  |
| `projeto_item_destino_id` | uuid | YES |  |
| `tipo` | text | NO |  |
| `quantidade` | numeric | NO |  |
| `origem` | text | YES |  |
| `referencia_id` | uuid | YES |  |
| `observacao` | text | YES |  |
| `criado_por` | uuid | YES |  |
| `criado_em` | timestamp with time zone | NO | now() |

### `public.estoque_saldos_projeto_item`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `projeto_item_id` | uuid | NO |  |
| `q_reserva` | numeric | NO | 0 |
| `q_entrega_futura` | numeric | NO | 0 |
| `q_ag_separar` | numeric | NO | 0 |
| `q_separado` | numeric | NO | 0 |
| `q_entregue` | numeric | NO | 0 |
| `q_devolvida` | numeric | NO | 0 |
| `q_transferida_saida` | numeric | NO | 0 |
| `status_operacional` | text | NO | 'ativo'::text |
| `criado_em` | timestamp with time zone | NO | now() |
| `atualizado_em` | timestamp with time zone | NO | now() |

### `public.ferias`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `funcionario_id` | uuid | NO |  |
| `data_inicio` | date | NO |  |
| `data_fim` | date | NO |  |
| `dias` | integer | NO |  |
| `status` | text | NO | 'Pendente'::text |
| `aprovado_por` | uuid | YES |  |
| `observacoes` | text | YES |  |
| `created_at` | timestamp with time zone | NO | now() |
| `periodo_aquisitivo_id` | uuid | NO |  |

### `public.folha_pagamento`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `funcionario_id` | uuid | NO |  |
| `mes` | integer | NO |  |
| `ano` | integer | NO |  |
| `salario_base` | numeric | NO |  |
| `descontos` | numeric | NO | 0 |
| `adicionais` | numeric | NO | 0 |
| `salario_liquido` | numeric | NO |  |
| `data_geracao` | timestamp with time zone | NO | now() |
| `comissao` | numeric | NO | 0 |
| `dias_trabalhados` | integer | YES | 0 |
| `dias_abonados` | integer | YES | 0 |
| `dias_falta` | integer | YES | 0 |
| `valor_vr_vt` | numeric | YES | 0 |
| `empresa_id` | uuid | YES |  |

### `public.fornecedores`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `created_at` | timestamp with time zone | YES | now() |
| `updated_at` | timestamp with time zone | YES | now() |
| `empresa_id` | uuid | YES |  |
| `nome` | text | NO |  |
| `cnpj_cpf` | text | YES |  |
| `email` | text | YES |  |
| `telefone` | text | YES |  |
| `endereco` | text | YES |  |
| `cidade` | text | YES |  |
| `estado` | text | YES |  |
| `cep` | text | YES |  |
| `banco` | text | YES |  |
| `agencia` | text | YES |  |
| `conta` | text | YES |  |
| `chave_pix` | text | YES |  |
| `categoria` | text | YES |  |
| `status` | text | YES | 'ativo'::text |
| `observacoes` | text | YES |  |
| `user_id` | uuid | YES | auth.uid() |

### `public.funcionarios`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `usuario_id` | uuid | YES |  |
| `departamento_id` | uuid | YES |  |
| `nome` | text | NO |  |
| `cargo` | text | YES |  |
| `data_admissao` | date | YES |  |
| `data_demissao` | date | YES |  |
| `status` | text | NO | 'Ativo'::text |
| `created_at` | timestamp with time zone | NO | now() |
| `updated_at` | timestamp with time zone | NO | now() |
| `empresa` | text | YES |  |
| `tipo_contratacao` | text | YES |  |
| `data_elegibilidade_ferias` | date | YES |  |
| `empresa_id` | uuid | YES |  |
| `codigo_legado` | integer | YES |  |
| `nm_connect` | text | YES |  |
| `email` | text | YES |  |

### `public.funcionarios_beneficios_empresas`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `funcionario_id` | uuid | NO |  |
| `empresa` | character varying | NO |  |
| `valor_vt_dia` | numeric | YES | 0 |

### `public.funcionarios_detalhes`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `funcionario_id` | uuid | NO |  |
| `cpf` | character varying | YES |  |
| `rg` | character varying | YES |  |
| `data_nascimento` | date | YES |  |
| `endereco` | text | YES |  |
| `telefone` | character varying | YES |  |
| `email` | character varying | YES |  |

### `public.funcionarios_financeiro`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `funcionario_id` | uuid | NO |  |
| `salario_base` | numeric | NO | 0 |
| `salario_por_fora` | numeric | NO | 0 |
| `comissao_percentual` | numeric | YES | 0 |
| `salario_liquido` | numeric | YES |  |
| `equipes_id` | uuid | YES |  |

### `public.funcionarios_novo`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `nome` | character varying | NO |  |
| `cargo` | character varying | YES |  |
| `data_admissao` | date | YES |  |
| `ativo` | boolean | YES | true |
| `created_at` | timestamp with time zone | YES | now() |

### `public.historico_status_orcamentos`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `orcamento_id` | uuid | NO |  |
| `status_anterior` | text | YES |  |
| `status_novo` | text | NO |  |
| `usuario` | text | YES |  |
| `observacao` | text | YES |  |
| `created_at` | timestamp with time zone | YES | now() |

### `public.informacoes_cliente_ubiqua`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `nome` | text | NO |  |
| `email` | text | YES |  |
| `telefone` | text | YES |  |
| `created_at` | timestamp with time zone | YES | now() |
| `cpf_cnpj` | text | NO |  |

### `public.itens_orcamento_ubiqua`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `orcamento_id` | uuid | NO |  |
| `produto_id` | integer | NO |  |
| `quantidade` | integer | NO |  |
| `valor_unitario` | numeric | NO |  |
| `desconto_item` | numeric | YES | 0 |
| `observacao_item` | text | YES |  |
| `referencia_snapshot` | text | YES |  |
| `descricao_snapshot` | text | YES |  |
| `marca_snapshot` | text | YES |  |
| `created_at` | timestamp with time zone | YES | now() |
| `ordem` | integer | YES | 0 |
| `valor_total` | numeric | YES |  |

### `public.logs_auditoria`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `created_at` | timestamp with time zone | YES | now() |
| `tabela` | text | NO |  |
| `operacao` | text | NO |  |
| `registro_id` | uuid | YES |  |
| `usuario_id` | uuid | YES | auth.uid() |
| `dados_anteriores` | jsonb | YES |  |
| `dados_novos` | jsonb | YES |  |
| `ip` | text | YES |  |
| `observacao` | text | YES |  |

### `public.logs_operacoes`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `projeto_id` | uuid | YES |  |
| `usuario_id` | uuid | YES |  |
| `acao` | text | NO |  |
| `dados_anteriores` | jsonb | YES |  |
| `dados_novos` | jsonb | YES |  |
| `created_at` | timestamp with time zone | YES | now() |

### `public.marcas`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `nome` | text | NO |  |
| `ativo` | boolean | NO | true |
| `created_at` | timestamp with time zone | NO | now() |
| `codigo_legado` | integer | YES |  |

### `public.negociacoes`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `empresa_id` | uuid | NO |  |
| `contato_id` | uuid | YES |  |
| `funcionario_id` | uuid | YES |  |
| `plano_contas_id` | uuid | YES |  |
| `projeto_id` | uuid | YES |  |
| `tipo` | USER-DEFINED | NO |  |
| `cod_duplicata` | integer | NO |  |
| `cod_venda` | integer | YES |  |
| `total_parc` | smallint | NO | 1 |
| `dev_troca` | boolean | NO | false |
| `observacao` | text | YES |  |
| `created_at` | timestamp with time zone | NO | now() |
| `cod_pessoa` | integer | YES |  |

### `public.notas_fiscais`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `numero_nf` | text | NO |  |
| `serie` | text | YES |  |
| `data_emissao` | date | YES |  |
| `valor` | numeric | YES |  |
| `arquivo_url` | text | YES |  |
| `fornecedor` | text | YES |  |
| `arquiteto` | text | YES |  |
| `boleto_id` | uuid | YES |  |
| `created_at` | timestamp with time zone | YES | now() |
| `updated_at` | timestamp with time zone | YES | now() |
| `orcamento_id` | uuid | YES |  |

### `public.orcamento_itens`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `orcamento_id` | uuid | NO |  |
| `produto_id` | uuid | YES |  |
| `quantidade` | numeric | YES | 1 |
| `preco_unitario` | numeric | YES |  |
| `desconto` | numeric | YES | 0 |
| `item_pai_id` | uuid | YES |  |
| `created_at` | timestamp with time zone | YES | now() |
| `custom_id` | text | YES |  |
| `descricao` | text | YES |  |
| `ordem` | integer | YES | 0 |
| `sub_ordem` | integer | YES | 0 |
| `peca_nova` | boolean | YES | false |

### `public.orcamentos`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `empresa_id` | uuid | NO |  |
| `cliente_id` | uuid | YES |  |
| `arquiteto_id` | uuid | YES |  |
| `vendedor_id` | uuid | YES |  |
| `status` | text | YES | 'rascunho'::text |
| `data_emissao` | timestamp with time zone | YES | now() |
| `validade` | date | YES |  |
| `valor_total` | numeric | YES | 0 |
| `created_at` | timestamp with time zone | YES | now() |
| `numero` | text | YES |  |
| `observacoes` | text | YES |  |
| `condicoes_pagamento` | text | YES |  |
| `desconto_global` | numeric | YES | 0 |
| `forma_pagamento` | USER-DEFINED | YES |  |
| `informacoes_cliente_id` | uuid | YES |  |
| `projeto_id` | uuid | YES |  |
| `frete_tipo` | text | YES |  |
| `frete_valor` | numeric | YES | 0 |
| `prazo_pagamento_dias` | ARRAY | YES |  |
| `data_base_vencimento` | text | YES | 'aprovacao'::text |
| `prazo_inicio_cobranca_dias` | integer | YES |  |
| `requer_revisao_financeira` | boolean | YES | false |
| `enviado_cliente_em` | timestamp with time zone | YES |  |
| `enviado_cliente_por` | uuid | YES |  |
| `aprovado_cliente_em` | timestamp with time zone | YES |  |
| `recusado_cliente_em` | timestamp with time zone | YES |  |
| `motivo_recusa_cliente` | text | YES |  |
| `token_aprovacao_cliente` | text | YES |  |

### `public.orcamentos_revenda_ubiqua`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `cliente_id` | uuid | NO |  |
| `numero_orcamento` | text | NO |  |
| `status` | text | NO | 'rascunho'::text |
| `data_validade` | date | NO | (CURRENT_DATE + '30 days'::interval) |
| `desconto_percentual` | numeric | YES | 0 |
| `valor_subtotal` | numeric | NO | 0 |
| `valor_desconto` | numeric | NO | 0 |
| `valor_total` | numeric | NO | 0 |
| `observacoes` | text | YES |  |
| `condicoes_pagamento` | text | YES |  |
| `prazo_entrega` | text | YES |  |
| `enviado_em` | timestamp with time zone | YES |  |
| `aprovado_em` | timestamp with time zone | YES |  |
| `aprovado_por` | text | YES |  |
| `rejeitado_em` | timestamp with time zone | YES |  |
| `motivo_rejeicao` | text | YES |  |
| `cancelado_em` | timestamp with time zone | YES |  |
| `motivo_cancelamento` | text | YES |  |
| `created_at` | timestamp with time zone | YES | now() |
| `updated_at` | timestamp with time zone | YES | now() |
| `created_by` | text | YES |  |
| `updated_by` | text | YES |  |
| `versao` | integer | YES | 1 |

### `public.pedido_compra`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `codigo_pedido` | integer | NO |  |
| `cod_fornecedor` | integer | NO |  |
| `nome_fornecedor` | text | NO |  |
| `valor_nota` | numeric | NO | 0 |
| `valor_duplicata` | numeric | YES | 0 |
| `numero_parcela` | integer | YES |  |
| `data_emissao` | date | NO |  |
| `data_vencimento` | date | YES |  |
| `status` | text | YES | 'Pendente'::text |
| `created_at` | timestamp with time zone | YES | now() |
| `updated_at` | timestamp with time zone | YES | now() |

### `public.periodos_aquisitivos`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `funcionario_id` | uuid | NO |  |
| `data_inicio` | date | NO |  |
| `data_fim` | date | NO |  |
| `data_limite_gozo` | date | NO |  |
| `status` | text | YES | 'Ativo'::text |
| `created_at` | timestamp with time zone | YES | now() |

### `public.plano_de_contas`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `codigo_connect` | bigint | NO |  |
| `nome` | text | NO |  |
| `nivel` | smallint | NO |  |
| `parent_id` | uuid | YES |  |
| `tipo` | text | YES |  |
| `ativo` | boolean | NO | true |
| `created_at` | timestamp with time zone | NO | now() |

### `public.produtos`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `marca_id` | uuid | YES |  |
| `nome` | text | NO |  |
| `sku` | text | YES |  |
| `categoria` | text | YES |  |
| `preco_custo` | numeric | YES |  |
| `preco_venda` | numeric | YES |  |
| `ativo` | boolean | NO | true |
| `created_at` | timestamp with time zone | NO | now() |
| `updated_at` | timestamp with time zone | NO | now() |
| `codigo_produto` | integer | YES |  |
| `referencia` | text | YES |  |
| `estoque_total` | numeric | YES | 0 |
| `estoque_showroom` | integer | YES | 0 |
| `estoque_disponivel` | numeric | YES | 0 |
| `unidade` | text | YES | 'UN'::text |
| `custo_total` | numeric | YES | 0 |
| `percentual_lucro` | numeric | YES | 0 |
| `valor_venda` | numeric | YES | 0 |
| `codigo_legado` | integer | YES |  |
| `categoria_id` | uuid | YES |  |
| `fornecedor_principal_id` | uuid | YES |  |
| `descricao_tecnica` | text | YES |  |
| `icms_entrada` | numeric | YES | 0 |
| `ipi_entrada` | numeric | YES | 0 |
| `porc_frete` | numeric | YES | 0 |
| `porc_despesas` | numeric | YES | 0 |
| `vl_custo_indireto` | numeric | YES |  |
| `margem_lucro` | numeric | YES |  |
| `ncm` | character varying | YES |  |
| `tipo_fiscal` | text | YES |  |
| `cst` | text | YES |  |
| `cest` | text | YES |  |
| `porc_bdi` | numeric | YES |  |
| `status_comercial` | text | YES |  |
| `mascara_produto` | text | YES |  |
| `porc_st` | numeric | YES | 0 |
| `porc_desconto` | numeric | YES | 0 |

### `public.projeto_itens`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `projeto_id` | uuid | NO |  |
| `produto_id` | uuid | YES |  |
| `descricao` | text | NO |  |
| `quantidade` | numeric | NO |  |
| `preco_unitario` | numeric | NO |  |
| `desconto` | numeric | NO | 0 |
| `subtotal` | numeric | YES |  |
| `validado` | boolean | NO | false |
| `created_at` | timestamp with time zone | NO | now() |
| `updated_at` | timestamp with time zone | NO | now() |
| `orcamento_id` | uuid | YES |  |

### `public.projeto_parcelas`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `projeto_id` | uuid | NO |  |
| `numero_parcela` | integer | NO |  |
| `valor` | numeric | NO |  |
| `data_fechamento` | date | YES |  |
| `created_at` | timestamp with time zone | YES | now() |
| `status` | USER-DEFINED | NO | 'pendente'::parcela_status |
| `data_vencimento` | date | YES |  |
| `data_pagamento` | date | YES |  |
| `valor_pago` | numeric | YES |  |
| `juros` | numeric | NO | 0 |
| `multa` | numeric | NO | 0 |
| `desconto` | numeric | NO | 0 |
| `forma_pagamento` | USER-DEFINED | YES |  |
| `comprovante_url` | text | YES |  |
| `observacoes` | text | YES |  |
| `transacao_id` | uuid | YES |  |
| `descricao` | text | YES |  |
| `orcamento_id` | uuid | YES |  |

### `public.projeto_parcelas_backup_migration`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | YES |  |
| `projeto_id` | uuid | YES |  |
| `numero_parcela` | integer | YES |  |
| `valor` | numeric | YES |  |
| `data_fechamento` | date | YES |  |
| `created_at` | timestamp with time zone | YES |  |
| `status` | USER-DEFINED | YES |  |
| `data_vencimento` | date | YES |  |
| `data_pagamento` | date | YES |  |
| `valor_pago` | numeric | YES |  |
| `juros` | numeric | YES |  |
| `multa` | numeric | YES |  |
| `desconto` | numeric | YES |  |
| `forma_pagamento` | USER-DEFINED | YES |  |
| `comprovante_url` | text | YES |  |
| `observacoes` | text | YES |  |
| `transacao_id` | uuid | YES |  |
| `descricao` | text | YES |  |

### `public.projeto_produtos`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `projeto_id` | uuid | YES |  |
| `produto_id` | uuid | YES |  |
| `quantidade` | numeric | NO | 1 |
| `valor_unitario` | numeric | YES |  |
| `valor_total` | numeric | YES |  |
| `created_at` | timestamp with time zone | YES | now() |

### `public.projeto_sinal`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `projeto_id` | uuid | NO |  |
| `valor` | numeric | NO |  |
| `data_pagamento` | date | YES |  |
| `forma_pagamento` | USER-DEFINED | YES |  |
| `status` | USER-DEFINED | NO | 'pendente'::sinal_status |
| `transacao_id` | uuid | YES |  |
| `comprovante_url` | text | YES |  |
| `observacoes` | text | YES |  |
| `created_at` | timestamp with time zone | NO | now() |
| `updated_at` | timestamp with time zone | NO | now() |

### `public.projetos`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `codigo` | character varying | NO |  |
| `nome` | text | NO |  |
| `nivel_estrategico` | USER-DEFINED | YES |  |
| `status` | USER-DEFINED | YES | 'Estudo Inicial'::projeto_status |
| `cidade` | character varying | YES |  |
| `estado` | character varying | YES |  |
| `data_entrada` | date | YES |  |
| `arquivado` | boolean | YES | false |
| `cliente_id` | uuid | YES |  |
| `arquiteto_id` | uuid | YES |  |
| `responsavel_id` | uuid | YES |  |
| `created_at` | timestamp with time zone | YES | now() |
| `historico` | jsonb | NO | '[]'::jsonb |
| `responsavel_nome` | text | YES |  |
| `created_by` | uuid | YES |  |
| `equipe_responsavel_obra_id` | uuid | YES |  |
| `updated_at` | timestamp with time zone | NO | now() |
| `client_id` | uuid | YES |  |
| `area_do_projeto` | jsonb | YES |  |
| `Nome Arquiteto` | text | YES |  |
| `codigo_legado` | integer | YES |  |
| `empresa_id` | uuid | YES |  |
| `valor_total` | numeric | NO | 0 |
| `equipe_id` | uuid | YES |  |
| `responsavel_obra_id` | uuid | YES |  |

### `public.projetos_fechados`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `cod` | text | YES |  |
| `valor_fechado` | numeric | YES |  |
| `data_fechamento` | date | YES |  |
| `created_at` | timestamp with time zone | YES | now() |

### `public.quote_history`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `quote_id` | uuid | NO |  |
| `acao` | text | NO |  |
| `created_at` | timestamp with time zone | NO | now() |
| `created_by` | uuid | YES |  |

### `public.quotes`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `empresa` | text | YES |  |
| `valor_total` | numeric | NO | 0 |
| `status` | text | NO | 'aberto'::text |
| `observacoes` | text | YES |  |
| `items` | jsonb | NO | '[]'::jsonb |
| `data_aprovacao` | timestamp with time zone | YES |  |
| `created_at` | timestamp with time zone | NO | now() |

### `public.remessas`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `created_at` | timestamp with time zone | YES | now() |
| `updated_at` | timestamp with time zone | YES | now() |
| `empresa_id` | uuid | YES |  |
| `fornecedor_id` | uuid | YES |  |
| `descricao` | text | NO |  |
| `valor` | numeric | NO | 0 |
| `vencimento` | date | YES |  |
| `status` | text | YES | 'pendente'::text |
| `linha_digitavel` | text | YES |  |
| `codigo_barras` | text | YES |  |
| `nosso_numero` | text | YES |  |
| `arquivo_remessa` | text | YES |  |
| `arquivo_retorno` | text | YES |  |
| `data_pagamento` | date | YES |  |
| `valor_pago` | numeric | YES | 0 |
| `observacoes` | text | YES |  |
| `user_id` | uuid | YES | auth.uid() |

### `public.retornos_processados`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `nome_arquivo` | text | NO |  |
| `data_upload` | timestamp with time zone | NO | now() |
| `empresa_id` | uuid | YES |  |
| `quantidade_liquidacoes` | integer | YES |  |
| `quantidade_confirmacoes` | integer | YES |  |
| `processado` | boolean | YES | true |

### `public.revenda_ubiqua`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | integer | NO | nextval('revenda_ubiqua_id_seq'::regclass) |
| `referencia` | text | NO |  |
| `descricao` | text | YES |  |
| `valor_revenda` | numeric | YES |  |
| `cod_produto` | integer | YES |  |
| `desc_produto` | text | YES |  |
| `cod_marca` | integer | YES |  |
| `desc_marca` | text | YES |  |
| `cod_fornecedor` | integer | YES |  |
| `nm_fornecedor` | text | YES |  |
| `itens_vendidos` | integer | YES | 0 |
| `estoque` | integer | YES | 0 |
| `disponivel` | integer | YES | 0 |
| `vl_custo_produto` | numeric | YES |  |
| `vl_custo_indireto` | numeric | YES |  |
| `vl_venda_produto` | numeric | YES |  |
| `vl_custo_total_tabela` | numeric | YES |  |
| `imagem_catalogo_url` | text | YES |  |
| `fonte_planilha1` | boolean | YES | false |
| `fonte_planilha2` | boolean | YES | false |
| `fonte_planilha3` | boolean | YES | false |
| `created_at` | timestamp with time zone | YES | now() |
| `updated_at` | timestamp with time zone | YES | now() |
| `cor` | text | YES |  |
| `empresa_id` | uuid | YES |  |
| `ordem` | integer | YES | 0 |
| `slug` | text | YES |  |

### `public.separacao_arquivos`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `separacao_id` | uuid | YES |  |
| `nome_arquivo` | text | YES |  |
| `tipo_arquivo` | text | YES |  |
| `url_arquivo` | text | YES |  |
| `tamanho_bytes` | bigint | YES |  |
| `ordem` | integer | YES |  |
| `created_at` | timestamp with time zone | YES | now() |

### `public.separacao_itens`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `separacao_id` | uuid | NO |  |
| `descricao` | text | NO |  |
| `quantidade` | numeric | NO | 1 |
| `unidade` | character varying | YES |  |
| `observacoes` | text | YES |  |
| `separado` | boolean | NO | false |
| `created_at` | timestamp with time zone | NO | now() |
| `produto_id` | uuid | YES |  |

### `public.separacoes`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `projeto_id` | uuid | YES |  |
| `responsavel_id` | uuid | YES |  |
| `status` | USER-DEFINED | NO | 'Pendente'::separacao_status |
| `observacoes` | text | YES |  |
| `created_at` | timestamp with time zone | NO | now() |
| `updated_at` | timestamp with time zone | NO | now() |
| `endereco_entrega` | text | YES |  |
| `delivery_type` | text | YES | 'flexible'::text |
| `scheduled_time` | time without time zone | YES |  |
| `data_entrega` | date | YES |  |
| `cliente` | text | YES |  |
| `codigo_obra` | text | YES |  |
| `data_entrega_original` | date | YES |  |
| `reagendamentos` | integer | NO | 0 |
| `cliente_id` | uuid | YES |  |
| `responsavel_recebimento` | text | YES |  |
| `telefone` | text | YES |  |
| `endereco` | text | YES |  |
| `material_tipo` | text | YES |  |
| `material_conteudo` | jsonb | YES |  |
| `solicitante` | text | YES |  |
| `order_in_route` | boolean | YES | false |
| `observacoes_internas` | text | YES |  |
| `gestora_equipe` | text | YES |  |
| `separacoes_parciais` | jsonb | YES |  |
| `nivel_complexidade` | text | YES |  |
| `tipo_entrega` | text | YES |  |
| `transportadora_nome` | text | YES |  |
| `codigo_rastreamento` | text | YES |  |
| `numero_venda` | text | YES |  |
| `numero_entrega` | text | YES |  |
| `data_inicio_separacao` | timestamp with time zone | YES |  |
| `tipo_pedido` | text | YES |  |
| `garantia_detalhes` | text | YES |  |
| `inclui_garantia` | boolean | YES | false |
| `garantia_peca` | text | YES |  |
| `garantia_motivo` | text | YES |  |

### `public.separacoes_arquivos`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `cliente` | text | YES |  |
| `codigo_obra` | text | YES |  |
| `data_entrega` | timestamp with time zone | YES |  |
| `responsavel_recebimento` | text | YES |  |
| `telefone` | text | YES |  |
| `endereco` | text | YES |  |
| `status` | text | YES |  |
| `material_tipo` | text | YES |  |
| `material_conteudo` | text | YES |  |
| `created_at` | timestamp with time zone | YES | now() |
| `updated_at` | timestamp with time zone | YES | now() |
| `solicitante` | text | YES |  |
| `delivery_type` | text | YES |  |
| `scheduled_time` | text | YES |  |
| `order_in_route` | text | YES |  |
| `observacoes_internas` | text | YES |  |
| `gestora_equipe` | text | YES |  |
| `separacoes_parciais` | text | YES |  |
| `nivel_complexidade` | text | YES |  |
| `tipo_entrega` | text | YES |  |
| `transportadora_nome` | text | YES |  |
| `codigo_rastreamento` | text | YES |  |
| `numero_venda` | text | YES |  |
| `numero_entrega` | text | YES |  |
| `data_inicio_separacao` | timestamp with time zone | YES |  |
| `tipo_pedido` | text | YES |  |
| `garantia_detalhes` | text | YES |  |
| `inclui_garantia` | boolean | YES | false |
| `garantia_peca` | text | YES |  |
| `garantia_motivo` | text | YES |  |

### `public.solicitacoes_compra`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `projeto_id` | uuid | NO |  |
| `produto_id` | uuid | NO |  |
| `quantidade_pedida` | numeric | NO |  |
| `status` | text | NO | 'Pendente'::text |
| `created_at` | timestamp with time zone | YES | now() |

### `public.staging_conta_pagar`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `tipo_operacao` | text | YES |  |
| `cod_empresa` | integer | YES |  |
| `nm_empresa` | text | YES |  |
| `cod_duplicata` | integer | YES |  |
| `cod_venda` | numeric | YES |  |
| `num_nota` | text | YES |  |
| `cod_pessoa` | integer | YES |  |
| `nm_pessoa` | text | YES |  |
| `nm_funcionario` | text | YES |  |
| `razaosocial` | text | YES |  |
| `fantasia` | text | YES |  |
| `cpf_cnpj` | text | YES |  |
| `rgie` | text | YES |  |
| `logradouro` | text | YES |  |
| `numero` | text | YES |  |
| `complemento` | text | YES |  |
| `bairro` | text | YES |  |
| `cidade` | text | YES |  |
| `estado` | text | YES |  |
| `cep` | text | YES |  |
| `telefone` | text | YES |  |
| `celular` | text | YES |  |
| `email` | text | YES |  |
| `email_financeiro` | text | YES |  |
| `desc_apropriacao` | text | YES |  |
| `tipo_pagamento` | text | YES |  |
| `dt_emissao` | text | YES |  |
| `dt_vencimento` | text | YES |  |
| `dt_pagamento` | text | YES |  |
| `data_baixa` | text | YES |  |
| `dt_ultimo_pgto` | text | YES |  |
| `vl_duplicata` | numeric | YES |  |
| `vl_parcela` | numeric | YES |  |
| `vl_desconto` | numeric | YES |  |
| `vl_juros` | numeric | YES |  |
| `vl_pago` | numeric | YES |  |
| `pago` | integer | YES |  |
| `vl_frete` | numeric | YES |  |
| `vl_ipi` | numeric | YES |  |
| `vl_st` | numeric | YES |  |
| `num_parc` | integer | YES |  |
| `total_parc` | integer | YES |  |
| `lancamento` | integer | YES |  |
| `layout_boleto` | numeric | YES |  |
| `nosso_numero` | integer | YES |  |
| `observacao` | text | YES |  |
| `importado_em` | timestamp with time zone | YES | now() |
| `processado` | boolean | YES | false |
| `linha_excel` | integer | YES |  |

### `public.staging_conta_receber`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `tipo_operacao` | text | YES |  |
| `cod_empresa` | integer | YES |  |
| `nm_empresa` | text | YES |  |
| `cod_duplicata` | integer | YES |  |
| `cod_venda` | numeric | YES |  |
| `num_nota` | text | YES |  |
| `cod_pessoa` | integer | YES |  |
| `nm_pessoa` | text | YES |  |
| `nm_funcionario` | text | YES |  |
| `razaosocial` | text | YES |  |
| `fantasia` | text | YES |  |
| `cpf_cnpj` | text | YES |  |
| `rgie` | text | YES |  |
| `logradouro` | text | YES |  |
| `numero` | text | YES |  |
| `complemento` | text | YES |  |
| `bairro` | text | YES |  |
| `cidade` | text | YES |  |
| `estado` | text | YES |  |
| `cep` | text | YES |  |
| `telefone` | text | YES |  |
| `celular` | text | YES |  |
| `email` | text | YES |  |
| `email_financeiro` | text | YES |  |
| `desc_apropriacao` | text | YES |  |
| `tipo_pagamento` | text | YES |  |
| `dt_emissao` | text | YES |  |
| `dt_vencimento` | text | YES |  |
| `dt_pagamento` | text | YES |  |
| `data_baixa` | text | YES |  |
| `dt_ultimo_pgto` | text | YES |  |
| `vl_duplicata` | numeric | YES |  |
| `vl_parcela` | numeric | YES |  |
| `vl_desconto` | numeric | YES |  |
| `vl_juros` | numeric | YES |  |
| `vl_pago` | numeric | YES |  |
| `pago` | integer | YES |  |
| `vl_frete` | numeric | YES |  |
| `vl_ipi` | numeric | YES |  |
| `vl_st` | numeric | YES |  |
| `num_parc` | integer | YES |  |
| `total_parc` | integer | YES |  |
| `lancamento` | integer | YES |  |
| `layout_boleto` | numeric | YES |  |
| `nosso_numero` | integer | YES |  |
| `observacao` | text | YES |  |
| `importado_em` | timestamp with time zone | YES | now() |
| `processado` | boolean | YES | false |
| `linha_excel` | integer | YES |  |

### `public.staging_import_bruto`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `COD` | text | YES |  |
| `CLIENTE` | text | YES |  |
| `PARCELA/COLUNA3` | text | YES |  |
| `DATA` | text | YES |  |
| `PROJETISTA` | text | YES |  |
| `VALOR FECHADO` | text | YES |  |
| `CAUSA PAGAMENTO` | text | YES |  |
| `FORMA PAGAMENTO` | text | YES |  |
| `DATA FECHAMENTO` | text | YES |  |
| `ARQUITETO` | text | YES |  |
| `LINHA ORIGINAL` | text | YES |  |

### `public.staging_pedido_compra`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `codigo_pedido` | integer | YES |  |
| `cod_fornecedor` | integer | YES |  |
| `nm_fornecedor` | text | YES |  |
| `emissao_pedido` | text | YES |  |
| `vl_nota` | numeric | YES |  |
| `num_parc` | numeric | YES |  |
| `dt_vencimento` | text | YES |  |
| `vl_duplicata` | numeric | YES |  |
| `importado_em` | timestamp with time zone | YES | now() |
| `processado` | boolean | YES | false |
| `linha_excel` | integer | YES |  |

### `public.staging_produtos`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `codproduto` | integer | YES |  |
| `referencia` | text | YES |  |
| `descproduto` | text | YES |  |
| `codmarca` | numeric | YES |  |
| `descmarca` | text | YES |  |
| `codcategoria` | integer | YES |  |
| `desccategoria` | text | YES |  |
| `estoquetotal` | numeric | YES |  |
| `showroom` | integer | YES |  |
| `disponivel` | numeric | YES |  |
| `unidade` | text | YES |  |
| `custototal` | text | YES |  |
| `lucro` | numeric | YES |  |
| `valorvenda` | numeric | YES |  |
| `importado_em` | timestamp with time zone | YES | now() |
| `processado` | boolean | YES | false |
| `linha_excel` | integer | YES |  |

### `public.sync_history`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | bigint | NO |  |
| `status` | text | YES |  |
| `mensagem` | text | YES |  |
| `created_at` | timestamp with time zone | YES | now() |
| `registros_atualizados` | integer | NO | 0 |
| `registros_inseridos` | integer | NO | 0 |
| `registros_erro` | integer | NO | 0 |
| `executado_por` | uuid | YES |  |
| `origem` | text | YES |  |
| `tipo` | text | YES |  |

### `public.systems`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `name` | text | NO |  |
| `description` | text | NO |  |
| `link` | text | NO |  |
| `icon_name` | text | YES |  |
| `display_order` | integer | YES | 0 |

### `public.transacoes`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `conta_id` | uuid | YES |  |
| `projeto_id` | uuid | YES |  |
| `parcela_id` | uuid | YES |  |
| `tipo` | USER-DEFINED | NO |  |
| `descricao` | text | NO |  |
| `valor` | numeric | NO |  |
| `data_transacao` | date | NO |  |
| `comprovante_url` | text | YES |  |
| `created_by` | uuid | YES |  |
| `created_at` | timestamp with time zone | NO | now() |
| `categoria_id` | uuid | YES |  |
| `negociacao_id` | uuid | YES |  |
| `cod_itens_duplicata` | integer | YES |  |
| `num_parc` | smallint | YES |  |
| `dt_emissao` | date | YES |  |
| `dt_vencimento` | date | YES |  |
| `dt_pagamento` | date | YES |  |
| `vl_parcela` | numeric | YES |  |
| `vl_desconto` | numeric | YES | 0 |
| `vl_juros` | numeric | YES | 0 |
| `vl_pago` | numeric | YES |  |
| `vl_frete` | numeric | YES | 0 |
| `vl_ipi` | numeric | YES | 0 |
| `status_pago` | smallint | YES | 0 |
| `tipo_pagamento` | text | YES |  |
| `acordo` | integer | YES |  |
| `empresa_id` | uuid | YES |  |
| `funcionario_id` | uuid | YES |  |

### `public.user_roles_separacao`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `user_id` | uuid | YES |  |
| `nome_completo` | text | NO |  |
| `email` | text | NO |  |
| `funcao` | USER-DEFINED | YES |  |
| `sistema` | text | YES | 'Separação e Entregas'::text |
| `created_at` | timestamp with time zone | YES | now() |
| `role` | text | YES |  |
| `updated_at` | timestamp with time zone | YES | now() |

### `public.user_system_access`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `user_id` | uuid | NO |  |
| `system_id` | uuid | NO |  |
| `created_at` | timestamp with time zone | NO | now() |

### `public.usuarios`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO |  |
| `email` | text | NO |  |
| `nome` | text | NO |  |
| `role` | USER-DEFINED | YES |  |
| `ativo` | boolean | YES | true |
| `created_at` | timestamp with time zone | YES | now() |
| `avatar_url` | text | YES |  |
| `updated_at` | timestamp with time zone | YES |  |
| `onboarding_completado` | boolean | NO | false |
| `empresa_id` | uuid | YES |  |
| `telefone` | text | YES |  |
| `can_approve_quotes` | boolean | YES | false |

### `public.usuarios_ubiqua`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO |  |
| `empresa_id` | uuid | YES |  |
| `nome` | text | NO |  |
| `email` | text | NO |  |
| `telefone` | text | YES |  |
| `onboarding_completado` | boolean | NO | false |
| `created_at` | timestamp with time zone | NO | now() |
| `nivel_acesso` | USER-DEFINED | NO | 'revendedor'::nivel_acesso_tipo |

### `public.v_cash_flow_lucenera`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `dt_pagamento` | date | YES |  |
| `dt_vencimento` | date | YES |  |
| `tipo` | text | YES |  |
| `categoria_fluxo` | text | YES |  |
| `vl_pago` | numeric | YES |  |
| `descricao` | text | YES |  |
| `status_pago` | smallint | YES |  |

### `public.vendas`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `cod_venda` | integer | YES |  |
| `num_nota` | text | YES |  |
| `projeto_id` | uuid | YES |  |
| `cod_cliente` | integer | YES |  |
| `nome_cliente` | text | NO |  |
| `valor_total` | numeric | NO | 0 |
| `valor_pago` | numeric | YES | 0 |
| `valor_pendente` | numeric | YES | 0 |
| `total_parcelas` | integer | YES | 1 |
| `parcelas_pagas` | integer | YES | 0 |
| `data_emissao` | date | YES |  |
| `data_vencimento` | date | YES |  |
| `data_pagamento` | timestamp without time zone | YES |  |
| `status_pagamento` | USER-DEFINED | YES | 'Pendente'::status_pagamento |
| `tipo_pagamento` | text | YES |  |
| `desc_apropriacao` | text | YES |  |
| `observacao` | text | YES |  |
| `created_at` | timestamp with time zone | YES | now() |
| `updated_at` | timestamp with time zone | YES | now() |

### `public.vendas_marca`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `marca_id` | uuid | NO |  |
| `mes` | integer | NO |  |
| `ano` | integer | NO |  |
| `valor_custo` | numeric | NO | 0 |
| `valor_venda` | numeric | NO | 0 |
| `created_at` | timestamp with time zone | NO | now() |

### `public.vw_catalogo_ubiqua`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `nome_exibicao` | text | YES |  |
| `cores_disponiveis` | ARRAY | YES |  |
| `estoque_total` | bigint | YES |  |
| `valor_revenda` | numeric | YES |  |
| `imagem_principal` | text | YES |  |
| `detalhes_por_cor` | ARRAY | YES |  |

### `public.vw_catalogo_unificado`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `referencia_base` | text | YES |  |
| `nome_exibicao` | text | YES |  |
| `estoque_total` | bigint | YES |  |
| `cores_disponiveis` | ARRAY | YES |  |
| `imagem_principal` | text | YES |  |
| `valor_minimo` | numeric | YES |  |

### `public.vw_comissao_mensal`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `funcionario_id` | uuid | YES |  |
| `funcionario` | character varying | YES |  |
| `equipe_id` | uuid | YES |  |
| `equipe` | text | YES |  |
| `comissao_percentual` | numeric | YES |  |
| `mes` | date | YES |  |
| `total_projetos` | bigint | YES |  |
| `valor_total_projetos` | numeric | YES |  |
| `comissao_calculada` | numeric | YES |  |

### `public.vw_conferencia_financeira`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `data_transacao` | date | YES |  |
| `descricao` | text | YES |  |
| `valor` | numeric | YES |  |
| `nome_empresa` | text | YES |  |
| `nome_fornecedor` | text | YES |  |
| `status_pago` | smallint | YES |  |
| `dt_vencimento` | date | YES |  |

### `public.vw_controle_ferias_clt`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `funcionario_id` | uuid | YES |  |
| `funcionario_nome` | text | YES |  |
| `direito_total_acumulado` | bigint | YES |  |
| `total_gozado` | bigint | YES |  |
| `saldo_disponivel` | bigint | YES |  |

### `public.vw_custos_pendentes_mes`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `descricao` | text | YES |  |
| `categoria` | text | YES |  |
| `data_vencimento` | date | YES |  |
| `valor_original` | numeric | YES |  |
| `status` | USER-DEFINED | YES |  |
| `conta` | text | YES |  |

### `public.vw_dashboard_crm_fechamento`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `mes` | timestamp with time zone | YES |  |
| `total_projetos` | bigint | YES |  |
| `total_clientes` | bigint | YES |  |
| `valor_total` | numeric | YES |  |
| `projetos_residenciais` | bigint | YES |  |
| `projetos_corporativos` | bigint | YES |  |
| `projetos_comerciais` | bigint | YES |  |
| `projetos_paisagismo` | bigint | YES |  |

### `public.vw_detalhe_produto_estoque`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `produto_id` | uuid | YES |  |
| `estoque_total` | numeric | YES |  |
| `estoque_disponivel` | numeric | YES |  |
| `estoque_reservado` | numeric | YES |  |

### `public.vw_estoque_liquido`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `produto_id` | uuid | YES |  |
| `produto` | text | YES |  |
| `sku` | text | YES |  |
| `marca` | text | YES |  |
| `categoria` | text | YES |  |
| `preco_custo` | numeric | YES |  |
| `preco_venda` | numeric | YES |  |
| `qtd_fisico` | numeric | YES |  |
| `qtd_reservado` | numeric | YES |  |
| `qtd_showroom` | numeric | YES |  |
| `qtd_em_transito` | numeric | YES |  |
| `qtd_disponivel` | numeric | YES |  |
| `alerta_estoque` | text | YES |  |
| `valor_estoque_total` | numeric | YES |  |
| `valor_reservado_total` | numeric | YES |  |

### `public.vw_estoque_por_marca`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `marca` | text | YES |  |
| `skus_total` | bigint | YES |  |
| `qtd_estoque` | numeric | YES |  |
| `qtd_showroom` | numeric | YES |  |
| `valor_disponivel_venda` | numeric | YES |  |

### `public.vw_estoque_por_produto_projeto`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `projeto_item_id` | uuid | YES |  |
| `projeto_id` | uuid | YES |  |
| `orcamento_id` | uuid | YES |  |
| `produto_id` | uuid | YES |  |
| `cliente_id` | uuid | YES |  |
| `produto` | text | YES |  |
| `produto_codigo` | integer | YES |  |
| `projeto_codigo` | character varying | YES |  |
| `orcamento_numero` | text | YES |  |
| `q_venda` | numeric | YES |  |
| `q_reserva` | numeric | YES |  |
| `q_entrega_futura` | numeric | YES |  |
| `q_ag_separar` | numeric | YES |  |
| `q_separado` | numeric | YES |  |
| `q_entregue` | numeric | YES |  |
| `q_devolvida` | numeric | YES |  |
| `q_transferida_saida` | numeric | YES |  |
| `status_operacional` | text | YES |  |
| `atualizado_em` | timestamp with time zone | YES |  |

### `public.vw_estoque_produtos`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `codigo_produto` | integer | YES |  |
| `referencia` | text | YES |  |
| `descricao` | text | YES |  |
| `marca` | text | YES |  |
| `categoria` | text | YES |  |
| `estoque_total` | numeric | YES |  |
| `estoque_showroom` | integer | YES |  |
| `estoque_disponivel` | numeric | YES |  |
| `valor_venda` | numeric | YES |  |
| `status_estoque` | text | YES |  |

### `public.vw_estoque_resumo`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `produto_id` | uuid | YES |  |
| `produto` | text | YES |  |
| `produto_codigo` | integer | YES |  |
| `qtd_total` | numeric | YES |  |
| `qtd_comprometida` | numeric | YES |  |
| `qtd_disponivel` | numeric | YES |  |
| `qtd_entrega_futura` | numeric | YES |  |

### `public.vw_estoque_saldos_projeto_item`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `projeto_item_id` | uuid | YES |  |
| `projeto_id` | uuid | YES |  |
| `orcamento_id` | uuid | YES |  |
| `produto_id` | uuid | YES |  |
| `cliente_id` | uuid | YES |  |
| `produto` | text | YES |  |
| `produto_codigo` | integer | YES |  |
| `projeto_codigo` | character varying | YES |  |
| `orcamento_numero` | text | YES |  |
| `q_venda` | numeric | YES |  |
| `q_reserva` | numeric | YES |  |
| `q_entrega_futura` | numeric | YES |  |
| `q_ag_separar` | numeric | YES |  |
| `q_separado` | numeric | YES |  |
| `q_entregue` | numeric | YES |  |
| `q_devolvida` | numeric | YES |  |
| `q_transferida_saida` | numeric | YES |  |
| `status_operacional` | text | YES |  |
| `atualizado_em` | timestamp with time zone | YES |  |

### `public.vw_financeiro_projetos`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | YES |  |
| `codigo` | character varying | YES |  |
| `nome` | text | YES |  |
| `status` | USER-DEFINED | YES |  |
| `client_id` | uuid | YES |  |
| `cliente_nome` | text | YES |  |
| `valor_total` | numeric | YES |  |
| `valor_recebido` | numeric | YES |  |
| `valor_pendente` | numeric | YES |  |
| `total_parcelas` | bigint | YES |  |
| `parcelas_pagas` | bigint | YES |  |
| `parcelas_pendentes` | bigint | YES |  |

### `public.vw_fluxo_caixa_projetado`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `mes` | timestamp with time zone | YES |  |
| `a_receber` | numeric | YES |  |
| `recebido` | numeric | YES |  |
| `atrasado` | numeric | YES |  |
| `qtd_pendente` | bigint | YES |  |
| `qtd_atrasado` | bigint | YES |  |

### `public.vw_fornecedores_remessas`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | YES |  |
| `nome` | text | YES |  |
| `cnpj_cpf` | text | YES |  |
| `status` | text | YES |  |
| `empresa_id` | uuid | YES |  |
| `empresa_nome` | text | YES |  |
| `total_remessas` | bigint | YES |  |
| `total_valor_remessas` | numeric | YES |  |
| `total_pago` | numeric | YES |  |

### `public.vw_fornecedores_resumo`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | YES |  |
| `nome` | text | YES |  |
| `cnpj_cpf` | text | YES |  |
| `email` | text | YES |  |
| `telefone` | text | YES |  |
| `status` | text | YES |  |
| `categoria` | text | YES |  |
| `empresa_id` | uuid | YES |  |
| `empresa_nome` | text | YES |  |
| `created_at` | timestamp with time zone | YES |  |
| `updated_at` | timestamp with time zone | YES |  |

### `public.vw_funcionarios_completo`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | YES |  |
| `nome` | character varying | YES |  |
| `cargo` | character varying | YES |  |
| `ativo` | boolean | YES |  |
| `data_admissao` | date | YES |  |
| `created_at` | timestamp with time zone | YES |  |
| `cpf` | character varying | YES |  |
| `rg` | character varying | YES |  |
| `data_nascimento` | date | YES |  |
| `endereco` | text | YES |  |
| `telefone` | character varying | YES |  |
| `email` | character varying | YES |  |
| `salario_base` | numeric | YES |  |
| `salario_por_fora` | numeric | YES |  |
| `comissao_percentual` | numeric | YES |  |
| `salario_liquido` | numeric | YES |  |
| `empresa` | character varying | YES |  |
| `valor_vt_dia` | numeric | YES |  |

### `public.vw_historico_faltas`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `funcionario_id` | uuid | YES |  |
| `funcionario_nome` | text | YES |  |
| `data_falta` | date | YES |  |
| `status` | text | YES |  |
| `justificativa` | text | YES |  |
| `periodo_id` | uuid | YES |  |
| `data_inicio` | date | YES |  |
| `data_fim` | date | YES |  |

### `public.vw_logs_auditoria_recentes`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | YES |  |
| `created_at` | timestamp with time zone | YES |  |
| `tabela` | text | YES |  |
| `operacao` | text | YES |  |
| `registro_id` | uuid | YES |  |
| `usuario_id` | uuid | YES |  |
| `dados_anteriores` | jsonb | YES |  |
| `dados_novos` | jsonb | YES |  |
| `observacao` | text | YES |  |

### `public.vw_orcamentos_aprovacao_financeira_auditoria`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `orcamento_id` | uuid | YES |  |
| `numero` | text | YES |  |
| `status` | text | YES |  |
| `projeto_id` | uuid | YES |  |
| `cliente_id` | uuid | YES |  |
| `valor_total` | numeric | YES |  |
| `requer_revisao_financeira` | boolean | YES |  |
| `aprovado_cliente_em` | timestamp with time zone | YES |  |
| `projeto_itens_por_orcamento` | bigint | YES |  |
| `parcelas_por_orcamento` | bigint | YES |  |
| `boletos_por_orcamento` | bigint | YES |  |
| `classificacao_fluxo` | text | YES |  |

### `public.vw_produtos_estoque_detalhado`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | YES |  |
| `codigo_produto` | integer | YES |  |
| `nome` | text | YES |  |
| `sku` | text | YES |  |
| `preco_venda` | numeric | YES |  |
| `estoque_geral` | numeric | YES |  |
| `reserva` | numeric | YES |  |
| `separacao` | numeric | YES |  |
| `disponivel` | numeric | YES |  |

### `public.vw_produtos_estoque_por_local`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `codigo_produto` | integer | YES |  |
| `nome` | text | YES |  |
| `unidade` | text | YES |  |
| `preco_venda` | numeric | YES |  |
| `cst` | text | YES |  |
| `cest` | text | YES |  |
| `porc_bdi` | numeric | YES |  |
| `status_comercial` | text | YES |  |
| `mascara_produto` | text | YES |  |
| `setor` | USER-DEFINED | YES |  |
| `quantidade` | numeric | YES |  |
| `quantidade_reservada` | numeric | YES |  |

### `public.vw_projetos_dashboard`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | YES |  |
| `codigo` | character varying | YES |  |
| `nome` | text | YES |  |
| `status` | USER-DEFINED | YES |  |
| `nivel_estrategico` | USER-DEFINED | YES |  |
| `data_entrada` | date | YES |  |
| `cidade` | character varying | YES |  |
| `estado` | character varying | YES |  |
| `arquivado` | boolean | YES |  |
| `responsavel_id` | uuid | YES |  |
| `responsavel_nome` | text | YES |  |
| `responsavel_email` | text | YES |  |
| `cliente_id` | uuid | YES |  |
| `cliente_nome` | text | YES |  |
| `cliente_tipo` | USER-DEFINED | YES |  |
| `arquiteto_id` | uuid | YES |  |
| `arquiteto_nome` | text | YES |  |
| `empresa_id` | uuid | YES |  |
| `empresa_nome` | text | YES |  |
| `empresa_codigo` | integer | YES |  |
| `area_do_projeto` | jsonb | YES |  |
| `tipo_projeto` | text | YES |  |
| `created_at` | timestamp with time zone | YES |  |
| `updated_at` | timestamp with time zone | YES |  |

### `public.vw_projetos_pipeline`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | YES |  |
| `codigo` | character varying | YES |  |
| `nome` | text | YES |  |
| `status` | USER-DEFINED | YES |  |
| `data_entrada` | date | YES |  |
| `tipo_projeto` | text | YES |  |
| `client_id` | uuid | YES |  |
| `cliente_nome` | text | YES |  |
| `valor_total` | numeric | YES |  |

### `public.vw_projetos_por_responsavel`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `usuario_id` | uuid | YES |  |
| `responsavel` | text | YES |  |
| `total_projetos` | bigint | YES |  |
| `projetos_ativos` | bigint | YES |  |
| `projetos_arquivados` | bigint | YES |  |

### `public.vw_projetos_por_status`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `status` | USER-DEFINED | YES |  |
| `total_projetos` | bigint | YES |  |
| `total_clientes` | bigint | YES |  |
| `valor_total` | numeric | YES |  |

### `public.vw_projetos_resumo`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | YES |  |
| `codigo` | character varying | YES |  |
| `status` | USER-DEFINED | YES |  |
| `total_vendas` | bigint | YES |  |
| `valor_total_vendas` | numeric | YES |  |
| `valor_pago` | numeric | YES |  |
| `valor_pendente` | numeric | YES |  |

### `public.vw_projetos_sem_empresa`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | YES |  |
| `codigo` | character varying | YES |  |
| `nome` | text | YES |  |
| `status` | USER-DEFINED | YES |  |
| `responsavel_nome` | text | YES |  |
| `data_entrada` | date | YES |  |
| `created_at` | timestamp with time zone | YES |  |

### `public.vw_projetos_sem_responsavel`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | YES |  |
| `codigo` | character varying | YES |  |
| `nome` | text | YES |  |
| `status` | USER-DEFINED | YES |  |
| `data_entrada` | date | YES |  |
| `created_at` | timestamp with time zone | YES |  |
| `cliente_id` | uuid | YES |  |
| `arquiteto_id` | uuid | YES |  |

### `public.vw_projetos_status_enum`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `status` | USER-DEFINED | YES |  |
| `total` | bigint | YES |  |

### `public.vw_remessas_completa`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | YES |  |
| `descricao` | text | YES |  |
| `valor` | numeric | YES |  |
| `vencimento` | date | YES |  |
| `status` | text | YES |  |
| `nosso_numero` | text | YES |  |
| `linha_digitavel` | text | YES |  |
| `data_pagamento` | date | YES |  |
| `valor_pago` | numeric | YES |  |
| `observacoes` | text | YES |  |
| `fornecedor_id` | uuid | YES |  |
| `fornecedor_nome` | text | YES |  |
| `fornecedor_cnpj_cpf` | text | YES |  |
| `empresa_id` | uuid | YES |  |
| `empresa_nome` | text | YES |  |
| `created_at` | timestamp with time zone | YES |  |
| `updated_at` | timestamp with time zone | YES |  |

### `public.vw_remessas_resumo_status`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `empresa_id` | uuid | YES |  |
| `empresa_nome` | text | YES |  |
| `status` | text | YES |  |
| `quantidade` | bigint | YES |  |
| `valor_total` | numeric | YES |  |
| `valor_pago_total` | numeric | YES |  |

### `public.vw_remessas_vencimento`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | YES |  |
| `created_at` | timestamp with time zone | YES |  |
| `updated_at` | timestamp with time zone | YES |  |
| `empresa_id` | uuid | YES |  |
| `fornecedor_id` | uuid | YES |  |
| `descricao` | text | YES |  |
| `valor` | numeric | YES |  |
| `vencimento` | date | YES |  |
| `status` | text | YES |  |
| `linha_digitavel` | text | YES |  |
| `codigo_barras` | text | YES |  |
| `nosso_numero` | text | YES |  |
| `arquivo_remessa` | text | YES |  |
| `arquivo_retorno` | text | YES |  |
| `data_pagamento` | date | YES |  |
| `valor_pago` | numeric | YES |  |
| `observacoes` | text | YES |  |
| `user_id` | uuid | YES |  |
| `fornecedor_nome` | text | YES |  |
| `empresa_nome` | text | YES |  |
| `situacao_vencimento` | text | YES |  |

### `public.vw_separacoes_agenda`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `separacao_id` | uuid | YES |  |
| `separacao_status` | USER-DEFINED | YES |  |
| `data_entrega` | date | YES |  |
| `data_entrega_original` | date | YES |  |
| `reagendamentos` | integer | YES |  |
| `codigo_obra` | text | YES |  |
| `cliente` | text | YES |  |
| `endereco_entrega` | text | YES |  |
| `delivery_type` | text | YES |  |
| `scheduled_time` | time without time zone | YES |  |
| `observacoes` | text | YES |  |
| `projeto_id` | uuid | YES |  |
| `projeto_codigo` | character varying | YES |  |
| `projeto_nome` | text | YES |  |
| `projeto_status` | USER-DEFINED | YES |  |
| `cliente_nome` | text | YES |  |
| `entrega_id` | uuid | YES |  |
| `entrega_status` | USER-DEFINED | YES |  |
| `entregador_id` | uuid | YES |  |
| `entregador_nome` | text | YES |  |
| `total_itens` | bigint | YES |  |
| `itens_separados` | bigint | YES |  |
| `dias_ate_entrega` | integer | YES |  |
| `urgencia` | text | YES |  |
| `created_at` | timestamp with time zone | YES |  |
| `updated_at` | timestamp with time zone | YES |  |

### `public.vw_staging_resumo`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `tabela` | text | YES |  |
| `total` | bigint | YES |  |
| `processados` | bigint | YES |  |
| `pendentes` | bigint | YES |  |
| `primeira_importacao` | timestamp with time zone | YES |  |
| `ultima_importacao` | timestamp with time zone | YES |  |

### `public.vw_transacoes_completas`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | YES |  |
| `negociacao_id` | uuid | YES |  |
| `cod_duplicata` | integer | YES |  |
| `cod_itens_duplicata` | integer | YES |  |
| `tipo` | USER-DEFINED | YES |  |
| `dev_troca` | boolean | YES |  |
| `num_parc` | smallint | YES |  |
| `total_parc` | smallint | YES |  |
| `dt_emissao` | date | YES |  |
| `dt_vencimento` | date | YES |  |
| `dt_pagamento` | date | YES |  |
| `data_transacao` | date | YES |  |
| `valor` | numeric | YES |  |
| `vl_parcela` | numeric | YES |  |
| `vl_desconto` | numeric | YES |  |
| `vl_juros` | numeric | YES |  |
| `vl_pago` | numeric | YES |  |
| `vl_frete` | numeric | YES |  |
| `vl_ipi` | numeric | YES |  |
| `status_pago` | smallint | YES |  |
| `tipo_pagamento` | text | YES |  |
| `acordo` | integer | YES |  |
| `empresa_id` | uuid | YES |  |
| `empresa_nome` | text | YES |  |
| `contato_id` | uuid | YES |  |
| `contato_nome` | text | YES |  |
| `contato_tipo` | USER-DEFINED | YES |  |
| `funcionario_id` | uuid | YES |  |
| `funcionario_nome` | text | YES |  |
| `plano_contas_id` | uuid | YES |  |
| `plano_apropriacao` | text | YES |  |
| `plano_sub_grupo` | text | YES |  |
| `plano_grupo` | text | YES |  |
| `conta_bancaria_id` | uuid | YES |  |
| `conta_bancaria_nome` | text | YES |  |
| `projeto_id` | uuid | YES |  |
| `projeto_codigo` | character varying | YES |  |
| `projeto_nome` | text | YES |  |
| `cod_venda` | integer | YES |  |
| `parcela_crm_id` | uuid | YES |  |
| `parcela_crm_numero` | integer | YES |  |
| `descricao` | text | YES |  |
| `comprovante_url` | text | YES |  |
| `created_by` | uuid | YES |  |

### `public.vw_vendas_loja`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `produto_id` | uuid | YES |  |
| `produto` | text | YES |  |
| `sku` | text | YES |  |
| `marca` | text | YES |  |
| `categoria` | text | YES |  |
| `quantidade` | numeric | YES |  |
| `preco_custo` | numeric | YES |  |
| `preco_venda` | numeric | YES |  |
| `margem_total` | numeric | YES |  |
| `separacao_id` | uuid | YES |  |
| `data_venda` | timestamp with time zone | YES |  |
| `cliente` | text | YES |  |
| `observacoes` | text | YES |  |

### `public.vw_vendas_por_projeto`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `produto_id` | uuid | YES |  |
| `produto` | text | YES |  |
| `sku` | text | YES |  |
| `marca` | text | YES |  |
| `categoria` | text | YES |  |
| `quantidade` | numeric | YES |  |
| `preco_custo` | numeric | YES |  |
| `preco_venda` | numeric | YES |  |
| `margem_total` | numeric | YES |  |
| `separacao_id` | uuid | YES |  |
| `data_separacao` | timestamp with time zone | YES |  |
| `projeto_id` | uuid | YES |  |
| `projeto_codigo` | character varying | YES |  |
| `projeto_nome` | text | YES |  |
| `projeto_status` | USER-DEFINED | YES |  |
| `cliente` | text | YES |  |
| `projeto_cidade` | character varying | YES |  |
| `projeto_estado` | character varying | YES |  |

### `public.vw_vendas_produtos`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `origem` | text | YES |  |
| `produto_id` | uuid | YES |  |
| `produto` | text | YES |  |
| `sku` | text | YES |  |
| `marca` | text | YES |  |
| `categoria` | text | YES |  |
| `quantidade` | numeric | YES |  |
| `preco_custo` | numeric | YES |  |
| `preco_venda` | numeric | YES |  |
| `margem_total` | numeric | YES |  |
| `data_venda` | timestamp with time zone | YES |  |
| `projeto_codigo` | character varying | YES |  |
| `projeto_nome` | text | YES |  |
| `cliente` | text | YES |  |

### `storage.buckets`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | text | NO |  |
| `name` | text | NO |  |
| `owner` | uuid | YES |  |
| `created_at` | timestamp with time zone | YES | now() |
| `updated_at` | timestamp with time zone | YES | now() |
| `public` | boolean | YES | false |
| `avif_autodetection` | boolean | YES | false |
| `file_size_limit` | bigint | YES |  |
| `allowed_mime_types` | ARRAY | YES |  |
| `owner_id` | text | YES |  |
| `type` | USER-DEFINED | NO | 'STANDARD'::storage.buckettype |

### `storage.buckets_analytics`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `name` | text | NO |  |
| `type` | USER-DEFINED | NO | 'ANALYTICS'::storage.buckettype |
| `format` | text | NO | 'ICEBERG'::text |
| `created_at` | timestamp with time zone | NO | now() |
| `updated_at` | timestamp with time zone | NO | now() |
| `id` | uuid | NO | gen_random_uuid() |
| `deleted_at` | timestamp with time zone | YES |  |

### `storage.buckets_vectors`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | text | NO |  |
| `type` | USER-DEFINED | NO | 'VECTOR'::storage.buckettype |
| `created_at` | timestamp with time zone | NO | now() |
| `updated_at` | timestamp with time zone | NO | now() |

### `storage.migrations`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | integer | NO |  |
| `name` | character varying | NO |  |
| `hash` | character varying | NO |  |
| `executed_at` | timestamp without time zone | YES | CURRENT_TIMESTAMP |

### `storage.objects`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `bucket_id` | text | YES |  |
| `name` | text | YES |  |
| `owner` | uuid | YES |  |
| `created_at` | timestamp with time zone | YES | now() |
| `updated_at` | timestamp with time zone | YES | now() |
| `last_accessed_at` | timestamp with time zone | YES | now() |
| `metadata` | jsonb | YES |  |
| `path_tokens` | ARRAY | YES |  |
| `version` | text | YES |  |
| `owner_id` | text | YES |  |
| `user_metadata` | jsonb | YES |  |

### `storage.s3_multipart_uploads`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | text | NO |  |
| `in_progress_size` | bigint | NO | 0 |
| `upload_signature` | text | NO |  |
| `bucket_id` | text | NO |  |
| `key` | text | NO |  |
| `version` | text | NO |  |
| `owner_id` | text | YES |  |
| `created_at` | timestamp with time zone | NO | now() |
| `user_metadata` | jsonb | YES |  |
| `metadata` | jsonb | YES |  |

### `storage.s3_multipart_uploads_parts`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | uuid | NO | gen_random_uuid() |
| `upload_id` | text | NO |  |
| `size` | bigint | NO | 0 |
| `part_number` | integer | NO |  |
| `bucket_id` | text | NO |  |
| `key` | text | NO |  |
| `etag` | text | NO |  |
| `owner_id` | text | YES |  |
| `version` | text | NO |  |
| `created_at` | timestamp with time zone | NO | now() |

### `storage.vector_indexes`

| Coluna | Tipo | Nulo | Default |
|---|---|---|---|
| `id` | text | NO | gen_random_uuid() |
| `name` | text | NO |  |
| `bucket_id` | text | NO |  |
| `data_type` | text | NO |  |
| `dimension` | integer | NO |  |
| `distance_metric` | text | NO |  |
| `metadata_configuration` | jsonb | YES |  |
| `created_at` | timestamp with time zone | NO | now() |
| `updated_at` | timestamp with time zone | NO | now() |

## Foreign keys

| Origem | Coluna(s) | Destino | Coluna(s) | Constraint |
|---|---|---|---|---|
| `auth.identities` | `user_id` | `auth.users` | `id` | `identities_user_id_fkey` |
| `auth.mfa_amr_claims` | `session_id` | `auth.sessions` | `id` | `mfa_amr_claims_session_id_fkey` |
| `auth.mfa_challenges` | `factor_id` | `auth.mfa_factors` | `id` | `mfa_challenges_auth_factor_id_fkey` |
| `auth.mfa_factors` | `user_id` | `auth.users` | `id` | `mfa_factors_user_id_fkey` |
| `auth.oauth_authorizations` | `client_id` | `auth.oauth_clients` | `id` | `oauth_authorizations_client_id_fkey` |
| `auth.oauth_authorizations` | `user_id` | `auth.users` | `id` | `oauth_authorizations_user_id_fkey` |
| `auth.oauth_consents` | `client_id` | `auth.oauth_clients` | `id` | `oauth_consents_client_id_fkey` |
| `auth.oauth_consents` | `user_id` | `auth.users` | `id` | `oauth_consents_user_id_fkey` |
| `auth.one_time_tokens` | `user_id` | `auth.users` | `id` | `one_time_tokens_user_id_fkey` |
| `auth.refresh_tokens` | `session_id` | `auth.sessions` | `id` | `refresh_tokens_session_id_fkey` |
| `auth.saml_providers` | `sso_provider_id` | `auth.sso_providers` | `id` | `saml_providers_sso_provider_id_fkey` |
| `auth.saml_relay_states` | `flow_state_id` | `auth.flow_state` | `id` | `saml_relay_states_flow_state_id_fkey` |
| `auth.saml_relay_states` | `sso_provider_id` | `auth.sso_providers` | `id` | `saml_relay_states_sso_provider_id_fkey` |
| `auth.sessions` | `oauth_client_id` | `auth.oauth_clients` | `id` | `sessions_oauth_client_id_fkey` |
| `auth.sessions` | `user_id` | `auth.users` | `id` | `sessions_user_id_fkey` |
| `auth.sso_domains` | `sso_provider_id` | `auth.sso_providers` | `id` | `sso_domains_sso_provider_id_fkey` |
| `auth.webauthn_challenges` | `user_id` | `auth.users` | `id` | `webauthn_challenges_user_id_fkey` |
| `auth.webauthn_credentials` | `user_id` | `auth.users` | `id` | `webauthn_credentials_user_id_fkey` |
| `public.boletos` | `empresa_id` | `public.empresas` | `id` | `boletos_empresa_id_fkey` |
| `public.boletos` | `orcamento_id` | `public.orcamentos` | `id` | `boletos_orcamento_id_fkey` |
| `public.boletos` | `parcela_id` | `public.projeto_parcelas` | `id` | `boletos_parcela_id_fkey` |
| `public.contas_bancarias` | `empresa_id` | `public.empresas` | `id` | `contas_bancarias_empresa_id_fkey` |
| `public.contato_origens` | `contato_id` | `public.contatos` | `id` | `contato_origens_contato_id_fkey` |
| `public.contato_tipos` | `contato_id` | `public.contatos` | `id` | `contato_tipos_contato_id_fkey` |
| `public.contatos` | `canonical_id` | `public.contatos` | `id` | `contatos_canonical_id_fkey` |
| `public.contatos` | `created_by` | `auth.users` | `id` | `contatos_created_by_fkey` |
| `public.contatos` | `empresa_id` | `public.contatos` | `id` | `contatos_empresa_id_fkey` |
| `public.contatos` | `vendedor_id` | `auth.users` | `id` | `contatos_vendedor_id_fkey` |
| `public.contatos` | `vendedor_padrao_id` | `auth.users` | `id` | `contatos_vendedor_padrao_id_fkey` |
| `public.contatos_revisao` | `id_a` | `public.contatos` | `id` | `contatos_revisao_id_a_fkey` |
| `public.contatos_revisao` | `id_b` | `public.contatos` | `id` | `contatos_revisao_id_b_fkey` |
| `public.controle_falta` | `funcionario_id` | `public.funcionarios` | `id` | `controle_ponto_funcionario_id_fkey` |
| `public.custos_recorrentes` | `categoria_id` | `public.categorias_financeiras` | `id` | `custos_recorrentes_categoria_id_fkey` |
| `public.custos_recorrentes` | `conta_id` | `public.contas_bancarias` | `id` | `custos_recorrentes_conta_id_fkey` |
| `public.custos_recorrentes` | `created_by` | `public.usuarios` | `id` | `custos_recorrentes_created_by_fkey` |
| `public.custos_recorrentes_lancamentos` | `custo_id` | `public.custos_recorrentes` | `id` | `custos_recorrentes_lancamentos_custo_id_fkey` |
| `public.custos_recorrentes_lancamentos` | `transacao_id` | `public.transacoes` | `id` | `custos_recorrentes_lancamentos_transacao_id_fkey` |
| `public.entregas` | `entregador_id` | `public.usuarios` | `id` | `entregas_entregador_id_fkey` |
| `public.entregas` | `projeto_id` | `public.projetos` | `id` | `entregas_projeto_id_fkey` |
| `public.entregas` | `separacao_id` | `public.separacoes` | `id` | `entregas_separacao_id_fkey` |
| `public.entregas_finalizadas` | `separacao_id` | `public.separacoes` | `id` | `entregas_finalizadas_separacao_id_fkey` |
| `public.estoque_itens` | `atualizado_por` | `public.usuarios` | `id` | `estoque_itens_atualizado_por_fkey` |
| `public.estoque_itens` | `produto_id` | `public.produtos` | `id` | `estoque_itens_produto_id_fkey` |
| `public.estoque_movimentos_projeto_item` | `criado_por` | `auth.users` | `id` | `estoque_movimentos_projeto_item_criado_por_fkey` |
| `public.estoque_movimentos_projeto_item` | `projeto_item_destino_id` | `public.projeto_itens` | `id` | `estoque_movimentos_projeto_item_projeto_item_destino_id_fkey` |
| `public.estoque_movimentos_projeto_item` | `projeto_item_id` | `public.projeto_itens` | `id` | `estoque_movimentos_projeto_item_projeto_item_id_fkey` |
| `public.estoque_saldos_projeto_item` | `projeto_item_id` | `public.projeto_itens` | `id` | `estoque_saldos_projeto_item_projeto_item_id_fkey` |
| `public.ferias` | `aprovado_por` | `public.usuarios` | `id` | `ferias_aprovado_por_fkey` |
| `public.ferias` | `funcionario_id` | `public.funcionarios` | `id` | `ferias_funcionario_id_fkey` |
| `public.ferias` | `periodo_aquisitivo_id` | `public.periodos_aquisitivos` | `id` | `ferias_periodo_aquisitivo_id_fkey` |
| `public.folha_pagamento` | `empresa_id` | `public.empresas` | `id` | `folha_pagamento_empresa_id_fkey` |
| `public.folha_pagamento` | `funcionario_id` | `public.funcionarios` | `id` | `folha_pagamento_funcionario_id_fkey` |
| `public.fornecedores` | `empresa_id` | `public.empresas` | `id` | `fornecedores_empresa_id_fkey` |
| `public.funcionarios` | `departamento_id` | `public.departamentos` | `id` | `funcionarios_departamento_id_fkey` |
| `public.funcionarios` | `empresa_id` | `public.empresas` | `id` | `funcionarios_empresa_id_fkey` |
| `public.funcionarios` | `usuario_id` | `public.usuarios` | `id` | `funcionarios_usuario_id_fkey` |
| `public.funcionarios_beneficios_empresas` | `funcionario_id` | `public.funcionarios_novo` | `id` | `funcionarios_beneficios_empresas_funcionario_id_fkey` |
| `public.funcionarios_detalhes` | `funcionario_id` | `public.funcionarios_novo` | `id` | `funcionarios_detalhes_funcionario_id_fkey` |
| `public.funcionarios_financeiro` | `equipes_id` | `public.equipes_projetos` | `id` | `funcionarios_financeiro_equipes_id_fkey` |
| `public.funcionarios_financeiro` | `funcionario_id` | `public.funcionarios_novo` | `id` | `funcionarios_financeiro_funcionario_id_fkey` |
| `public.historico_status_orcamentos` | `orcamento_id` | `public.orcamentos` | `id` | `historico_status_orcamentos_orcamento_id_fkey` |
| `public.itens_orcamento_ubiqua` | `orcamento_id` | `public.orcamentos_revenda_ubiqua` | `id` | `itens_orcamento_ubiqua_orcamento_id_fkey` |
| `public.itens_orcamento_ubiqua` | `produto_id` | `public.revenda_ubiqua` | `id` | `itens_orcamento_ubiqua_produto_id_fkey` |
| `public.logs_operacoes` | `usuario_id` | `auth.users` | `id` | `logs_operacoes_usuario_id_fkey` |
| `public.negociacoes` | `contato_id` | `public.contatos` | `id` | `negociacoes_contato_id_fkey` |
| `public.negociacoes` | `empresa_id` | `public.empresas` | `id` | `negociacoes_empresa_id_fkey` |
| `public.negociacoes` | `funcionario_id` | `public.funcionarios` | `id` | `negociacoes_funcionario_id_fkey` |
| `public.negociacoes` | `plano_contas_id` | `public.plano_de_contas` | `id` | `negociacoes_plano_contas_id_fkey` |
| `public.negociacoes` | `projeto_id` | `public.projetos` | `id` | `negociacoes_projeto_id_fkey` |
| `public.notas_fiscais` | `boleto_id` | `public.boletos` | `id` | `notas_fiscais_boleto_id_fkey` |
| `public.notas_fiscais` | `orcamento_id` | `public.orcamentos` | `id` | `notas_fiscais_orcamento_id_fkey` |
| `public.orcamento_itens` | `item_pai_id` | `public.orcamento_itens` | `id` | `orcamento_itens_item_pai_id_fkey` |
| `public.orcamento_itens` | `orcamento_id` | `public.orcamentos` | `id` | `orcamento_itens_orcamento_id_fkey` |
| `public.orcamento_itens` | `produto_id` | `public.produtos` | `id` | `orcamento_itens_produto_id_fkey` |
| `public.orcamentos` | `arquiteto_id` | `public.contatos` | `id` | `orcamentos_arquiteto_id_fkey` |
| `public.orcamentos` | `cliente_id` | `public.contatos` | `id` | `orcamentos_cliente_id_fkey` |
| `public.orcamentos` | `empresa_id` | `public.empresas` | `id` | `orcamentos_empresa_id_fkey` |
| `public.orcamentos` | `enviado_cliente_por` | `auth.users` | `id` | `orcamentos_enviado_cliente_por_fkey` |
| `public.orcamentos` | `informacoes_cliente_id` | `public.informacoes_cliente_ubiqua` | `id` | `orcamentos_informacoes_cliente_id_fkey` |
| `public.orcamentos` | `projeto_id` | `public.projetos` | `id` | `orcamentos_projeto_id_fkey` |
| `public.orcamentos` | `vendedor_id` | `public.funcionarios` | `id` | `orcamentos_vendedor_id_fkey` |
| `public.orcamentos_revenda_ubiqua` | `cliente_id` | `public.informacoes_cliente_ubiqua` | `id` | `orcamentos_revenda_ubiqua_cliente_id_fkey` |
| `public.periodos_aquisitivos` | `funcionario_id` | `public.funcionarios` | `id` | `periodos_aquisitivos_funcionario_id_fkey` |
| `public.plano_de_contas` | `parent_id` | `public.plano_de_contas` | `id` | `plano_de_contas_parent_id_fkey` |
| `public.produtos` | `categoria_id` | `public.categorias_produto` | `id` | `produtos_categoria_id_fkey` |
| `public.produtos` | `fornecedor_principal_id` | `public.contatos` | `id` | `produtos_fornecedor_principal_id_fkey` |
| `public.produtos` | `marca_id` | `public.marcas` | `id` | `produtos_marca_id_fkey` |
| `public.projeto_itens` | `orcamento_id` | `public.orcamentos` | `id` | `projeto_itens_orcamento_id_fkey` |
| `public.projeto_itens` | `produto_id` | `public.produtos` | `id` | `projeto_itens_produto_id_fkey` |
| `public.projeto_itens` | `projeto_id` | `public.projetos` | `id` | `projeto_itens_projeto_id_fkey` |
| `public.projeto_parcelas` | `orcamento_id` | `public.orcamentos` | `id` | `projeto_parcelas_orcamento_id_fkey` |
| `public.projeto_parcelas` | `projeto_id` | `public.projetos` | `id` | `projeto_parcelas_projeto_id_fkey` |
| `public.projeto_parcelas` | `transacao_id` | `public.transacoes` | `id` | `projeto_parcelas_transacao_id_fkey` |
| `public.projeto_produtos` | `produto_id` | `public.produtos` | `id` | `projeto_produtos_produto_id_fkey` |
| `public.projeto_produtos` | `projeto_id` | `public.projetos` | `id` | `projeto_produtos_projeto_id_fkey` |
| `public.projeto_sinal` | `projeto_id` | `public.projetos` | `id` | `projeto_sinal_projeto_id_fkey` |
| `public.projeto_sinal` | `transacao_id` | `public.transacoes` | `id` | `projeto_sinal_transacao_id_fkey` |
| `public.projetos` | `arquiteto_id` | `public.contatos` | `id` | `projetos_arquiteto_id_fkey` |
| `public.projetos` | `client_id` | `public.contatos` | `id` | `projetos_client_id_fkey` |
| `public.projetos` | `cliente_id` | `public.contatos` | `id` | `projetos_cliente_id_fkey` |
| `public.projetos` | `created_by` | `public.usuarios` | `id` | `projetos_created_by_fkey` |
| `public.projetos` | `empresa_id` | `public.empresas` | `id` | `projetos_empresa_id_fkey` |
| `public.projetos` | `equipe_id` | `public.equipes_projetos` | `id` | `projetos_equipe_id_fkey` |
| `public.projetos` | `equipe_responsavel_obra_id` | `public.equipes_projetos` | `id` | `projetos_equipe_responsavel_obra_id_fkey` |
| `public.projetos` | `responsavel_id` | `public.usuarios` | `id` | `projetos_responsavel_id_fkey` |
| `public.projetos` | `responsavel_obra_id` | `public.usuarios` | `id` | `projetos_responsavel_obra_id_fkey` |
| `public.quote_history` | `created_by` | `auth.users` | `id` | `quote_history_created_by_fkey` |
| `public.quote_history` | `quote_id` | `public.quotes` | `id` | `quote_history_quote_id_fkey` |
| `public.remessas` | `empresa_id` | `public.empresas` | `id` | `remessas_empresa_id_fkey` |
| `public.remessas` | `fornecedor_id` | `public.fornecedores` | `id` | `remessas_fornecedor_id_fkey` |
| `public.retornos_processados` | `empresa_id` | `public.empresas` | `id` | `retornos_processados_empresa_id_fkey` |
| `public.revenda_ubiqua` | `empresa_id` | `public.empresas` | `id` | `fk_empresa` |
| `public.separacao_arquivos` | `separacao_id` | `public.separacoes` | `id` | `separacao_arquivos_separacao_id_fkey` |
| `public.separacao_itens` | `produto_id` | `public.produtos` | `id` | `separacao_itens_produto_id_fkey` |
| `public.separacao_itens` | `separacao_id` | `public.separacoes` | `id` | `separacao_itens_separacao_id_fkey` |
| `public.separacoes` | `cliente_id` | `public.contatos` | `id` | `separacoes_cliente_id_fkey` |
| `public.separacoes` | `projeto_id` | `public.projetos` | `id` | `separacoes_projeto_id_fkey` |
| `public.separacoes` | `responsavel_id` | `public.usuarios` | `id` | `separacoes_responsavel_id_fkey` |
| `public.solicitacoes_compra` | `produto_id` | `public.produtos` | `id` | `solicitacoes_compra_produto_id_fkey` |
| `public.solicitacoes_compra` | `projeto_id` | `public.projetos` | `id` | `solicitacoes_compra_projeto_id_fkey` |
| `public.sync_history` | `executado_por` | `public.usuarios` | `id` | `sync_history_executado_por_fkey` |
| `public.transacoes` | `categoria_id` | `public.categorias_financeiras` | `id` | `transacoes_categoria_id_fkey` |
| `public.transacoes` | `conta_id` | `public.contas_bancarias` | `id` | `transacoes_conta_id_fkey` |
| `public.transacoes` | `created_by` | `public.usuarios` | `id` | `transacoes_created_by_fkey` |
| `public.transacoes` | `empresa_id` | `public.empresas` | `id` | `transacoes_empresa_id_fkey` |
| `public.transacoes` | `funcionario_id` | `public.funcionarios` | `id` | `transacoes_funcionario_id_fkey` |
| `public.transacoes` | `negociacao_id` | `public.negociacoes` | `id` | `transacoes_negociacao_id_fkey` |
| `public.transacoes` | `parcela_id` | `public.projeto_parcelas` | `id` | `transacoes_parcela_id_fkey` |
| `public.transacoes` | `projeto_id` | `public.projetos` | `id` | `transacoes_projeto_id_fkey` |
| `public.user_system_access` | `system_id` | `public.systems` | `id` | `user_system_access_system_id_fkey` |
| `public.user_system_access` | `user_id` | `public.usuarios` | `id` | `user_system_access_user_id_fkey` |
| `public.usuarios` | `empresa_id` | `public.empresas` | `id` | `usuarios_empresa_id_fkey` |
| `public.usuarios` | `id` | `auth.users` | `id` | `usuarios_id_fkey` |
| `public.usuarios_ubiqua` | `empresa_id` | `public.empresa_ubiqua` | `id` | `usuarios_ubiqua_empresa_id_fkey` |
| `public.usuarios_ubiqua` | `id` | `auth.users` | `id` | `usuarios_ubiqua_id_fkey` |
| `public.vendas` | `projeto_id` | `public.projetos` | `id` | `vendas_projeto_id_fkey` |
| `public.vendas_marca` | `marca_id` | `public.marcas` | `id` | `vendas_marca_marca_id_fkey` |
| `storage.objects` | `bucket_id` | `storage.buckets` | `id` | `objects_bucketId_fkey` |
| `storage.s3_multipart_uploads` | `bucket_id` | `storage.buckets` | `id` | `s3_multipart_uploads_bucket_id_fkey` |
| `storage.s3_multipart_uploads_parts` | `bucket_id` | `storage.buckets` | `id` | `s3_multipart_uploads_parts_bucket_id_fkey` |
| `storage.s3_multipart_uploads_parts` | `upload_id` | `storage.s3_multipart_uploads` | `id` | `s3_multipart_uploads_parts_upload_id_fkey` |
| `storage.vector_indexes` | `bucket_id` | `storage.buckets_vectors` | `id` | `vector_indexes_bucket_id_fkey` |

## Observações

- `historico_status_orcamentos` (plural) pertence ao fluxo novo Lucenera e referencia `public.orcamentos(id)`.
- `historico_status_orcamento` (singular) permanece ligado ao fluxo Ubiqua/revenda.
- Reextraído em 2026-07-07 via `information_schema.columns`/`pg_constraint`/`pg_class` (psql, `SUPABASE_DB_URL`), já refletindo `20260706_020`, `20260706_021`, `20260706_022` e o hardening `20260707_023_spec010_hardening`: `estoque_saldos_projeto_item`, `estoque_movimentos_projeto_item`, `vw_estoque_por_produto_projeto`, `vw_estoque_resumo`, `vw_estoque_saldos_projeto_item` e `vw_orcamentos_aprovacao_financeira_auditoria` confirmados no banco real, junto com os FKs de `estoque_movimentos_projeto_item`/`estoque_saldos_projeto_item` para `projeto_itens`.
- Confirmado nesta reextração: `vw_estoque_saldos_projeto_item` e as demais views de estoque têm `security_invoker=true` (hardening da SPEC-010 aplicado).
- Correção nesta reextração: as seções `## Foreign keys` e coluna a coluna já cobriam corretamente `public`; nenhuma tabela/view/coluna pré-existente mudou desde 06/07/2026 além das adições da SPEC-010/018/020.
