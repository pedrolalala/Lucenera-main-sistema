-- Tabelas com RLS habilitado (public, auth, storage)

-- auth.audit_log_entries

-- auth.flow_state

-- auth.identities

-- auth.instances

-- auth.mfa_amr_claims

-- auth.mfa_challenges

-- auth.mfa_factors

-- auth.one_time_tokens

-- auth.refresh_tokens

-- auth.saml_providers

-- auth.saml_relay_states

-- auth.schema_migrations

-- auth.sessions

-- auth.sso_domains

-- auth.sso_providers

-- auth.users

-- public.boletos

-- public.categorias_financeiras

-- public.categorias_produto

-- public.contas_bancarias

-- public.contato_origens

-- public.contato_tipos

-- public.contatos

-- public.contatos_revisao

-- public.controle_falta

-- public.custos_recorrentes

-- public.custos_recorrentes_lancamentos

-- public.departamentos

-- public.empresa_ubiqua

-- public.empresas

-- public.entregas

-- public.entregas_finalizadas

-- public.estoque_itens

-- public.ferias

-- public.folha_pagamento

-- public.fornecedores

-- public.funcionarios_beneficios_empresas

-- public.funcionarios_detalhes

-- public.funcionarios_financeiro

-- public.funcionarios_novo

-- public.historico_status_orcamento

-- public.historico_status_orcamentos

-- public.informacoes_cliente_ubiqua

-- public.itens_orcamento_ubiqua

-- public.logs_auditoria

-- public.logs_operacoes

-- public.marcas

-- public.negociacoes

-- public.notas_fiscais

-- public.orcamento_itens

-- public.orcamentos

-- public.orcamentos_revenda_ubiqua

-- public.pedido_compra

-- public.plano_de_contas

-- public.produtos

-- public.projeto_itens

-- public.projeto_parcelas

-- public.projeto_parcelas_backup_migration

-- public.projeto_produtos

-- public.projeto_sinal

-- public.projetos

-- public.projetos_fechados

-- public.quote_history

-- public.quotes

-- public.remessas

-- public.retornos_processados

-- public.revenda_ubiqua

-- public.separacao_arquivos

-- public.separacao_itens

-- public.separacoes

-- public.separacoes_arquivos

-- public.solicitacoes_compra

-- public.sync_history

-- public.systems

-- public.transacoes

-- public.user_roles_separacao

-- public.user_system_access

-- public.usuarios

-- public.usuarios_ubiqua

-- public.vendas

-- public.vendas_marca

-- storage.buckets

-- storage.buckets_analytics

-- storage.buckets_vectors

-- storage.migrations

-- storage.objects

-- storage.s3_multipart_uploads

-- storage.s3_multipart_uploads_parts

-- storage.vector_indexes


-- Policies

-- Policy: public.boletos.authenticated_all_boletos
permissive=PERMISSIVE roles=authenticated cmd=ALL
qual: true
with_check: true

-- Policy: public.boletos.authenticated_delete_boletos
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: true
with_check: (none)

-- Policy: public.boletos.authenticated_insert_boletos
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: true

-- Policy: public.boletos.authenticated_select_boletos
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.boletos.authenticated_update_boletos
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: true
with_check: true

-- Policy: public.categorias_financeiras.catfin_delete
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.categorias_financeiras.catfin_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))

-- Policy: public.categorias_financeiras.catfin_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.categorias_financeiras.catfin_update
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.categorias_produto.categorias_produto_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.categorias_produto.categorias_produto_write
permissive=PERMISSIVE roles=service_role cmd=ALL
qual: true
with_check: (none)

-- Policy: public.contas_bancarias.contas_delete
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = 'admin'::usuario_role))))
with_check: (none)

-- Policy: public.contas_bancarias.contas_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = 'admin'::usuario_role))))

-- Policy: public.contas_bancarias.contas_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role])))))
with_check: (none)

-- Policy: public.contas_bancarias.contas_update
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = 'admin'::usuario_role))))
with_check: (none)

-- Policy: public.contato_origens.contato_origens_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.contato_origens.contato_origens_write
permissive=PERMISSIVE roles=service_role cmd=ALL
qual: true
with_check: (none)

-- Policy: public.contato_tipos.authenticated_all
permissive=PERMISSIVE roles=authenticated cmd=ALL
qual: true
with_check: true

-- Policy: public.contato_tipos.contato_tipos_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.contato_tipos.contato_tipos_write
permissive=PERMISSIVE roles=service_role cmd=ALL
qual: true
with_check: (none)

-- Policy: public.contatos.authenticated_all_contatos
permissive=PERMISSIVE roles=authenticated cmd=ALL
qual: true
with_check: true

-- Policy: public.contatos.authenticated_delete
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: true
with_check: (none)

-- Policy: public.contatos.authenticated_delete_contatos
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: true
with_check: (none)

-- Policy: public.contatos.authenticated_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: true

-- Policy: public.contatos.authenticated_insert_contatos
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: true

-- Policy: public.contatos.authenticated_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.contatos.authenticated_select_contatos
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.contatos.authenticated_update
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: true
with_check: (none)

-- Policy: public.contatos.authenticated_update_contatos
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: true
with_check: true

-- Policy: public.contatos.contatos_delete_admin
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.contatos.contatos_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role])))))

-- Policy: public.contatos.contatos_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.contatos.contatos_update
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role])))))
with_check: (none)

-- Policy: public.contatos_revisao.contatos_revisao_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.contatos_revisao.contatos_revisao_write
permissive=PERMISSIVE roles=service_role cmd=ALL
qual: true
with_check: (none)

-- Policy: public.controle_falta.ponto_delete_admin
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.controle_falta.ponto_insert_admin
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))

-- Policy: public.controle_falta.ponto_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))) OR (funcionario_id IN ( SELECT funcionarios.id
   FROM funcionarios
  WHERE (funcionarios.usuario_id = ( SELECT auth.uid() AS uid)))))
with_check: (none)

-- Policy: public.controle_falta.ponto_update_admin
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.custos_recorrentes.custos_rec_delete
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.custos_recorrentes.custos_rec_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))

-- Policy: public.custos_recorrentes.custos_rec_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role])))))
with_check: (none)

-- Policy: public.custos_recorrentes.custos_rec_update
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.custos_recorrentes_lancamentos.lanc_delete
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.custos_recorrentes_lancamentos.lanc_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))

-- Policy: public.custos_recorrentes_lancamentos.lanc_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role])))))
with_check: (none)

-- Policy: public.custos_recorrentes_lancamentos.lanc_update
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.departamentos.dept_delete_admin
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.departamentos.dept_insert_admin
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))

-- Policy: public.departamentos.dept_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.departamentos.dept_update_admin
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.empresa_ubiqua.empresa_ubiqua_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: true

-- Policy: public.empresa_ubiqua.empresa_ubiqua_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.empresa_ubiqua.empresa_ubiqua_update
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: (id IN ( SELECT usuarios_ubiqua.empresa_id
   FROM usuarios_ubiqua
  WHERE (usuarios_ubiqua.id = auth.uid())))
with_check: (id IN ( SELECT usuarios_ubiqua.empresa_id
   FROM usuarios_ubiqua
  WHERE (usuarios_ubiqua.id = auth.uid())))

-- Policy: public.empresas.anon_select_empresas
permissive=PERMISSIVE roles=anon,authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.empresas.authenticated_select_empresas
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.empresas.empresas_delete_auth
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: true
with_check: (none)

-- Policy: public.empresas.empresas_insert
permissive=PERMISSIVE roles=service_role cmd=INSERT
qual: (none)
with_check: true

-- Policy: public.empresas.empresas_insert_auth
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: true

-- Policy: public.empresas.empresas_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.empresas.empresas_update
permissive=PERMISSIVE roles=service_role cmd=UPDATE
qual: true
with_check: (none)

-- Policy: public.empresas.empresas_update_auth
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: true
with_check: (none)

-- Policy: public.entregas.entregas_delete_admin
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.entregas.entregas_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role])))))

-- Policy: public.entregas.entregas_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.entregas.entregas_update
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role])))))
with_check: (none)

-- Policy: public.entregas_finalizadas.entregas_finalizadas_authenticated_all
permissive=PERMISSIVE roles=authenticated cmd=ALL
qual: true
with_check: true

-- Policy: public.estoque_itens.authenticated_delete_estoque_itens
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: true
with_check: (none)

-- Policy: public.estoque_itens.authenticated_insert_estoque_itens
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: true

-- Policy: public.estoque_itens.authenticated_select_estoque_itens
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.estoque_itens.authenticated_update_estoque_itens
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: true
with_check: true

-- Policy: public.estoque_itens.estoque_delete
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role])))))
with_check: (none)

-- Policy: public.estoque_itens.estoque_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role])))))

-- Policy: public.estoque_itens.estoque_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.estoque_itens.estoque_update
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role])))))
with_check: (none)

-- Policy: public.ferias.ferias_delete_admin
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.ferias.ferias_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: ((funcionario_id IN ( SELECT funcionarios.id
   FROM funcionarios
  WHERE (funcionarios.usuario_id = ( SELECT auth.uid() AS uid)))) OR (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))))

-- Policy: public.ferias.ferias_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))) OR (funcionario_id IN ( SELECT funcionarios.id
   FROM funcionarios
  WHERE (funcionarios.usuario_id = ( SELECT auth.uid() AS uid)))))
with_check: (none)

-- Policy: public.ferias.ferias_update_admin
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.folha_pagamento.folha_delete
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.folha_pagamento.folha_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))

-- Policy: public.folha_pagamento.folha_own
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))) OR (funcionario_id IN ( SELECT funcionarios.id
   FROM funcionarios
  WHERE (funcionarios.usuario_id = ( SELECT auth.uid() AS uid)))))
with_check: (none)

-- Policy: public.folha_pagamento.folha_update
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.fornecedores.fornecedores_delete_policy
permissive=PERMISSIVE roles=public cmd=DELETE
qual: true
with_check: (none)

-- Policy: public.fornecedores.fornecedores_insert_policy
permissive=PERMISSIVE roles=public cmd=INSERT
qual: (none)
with_check: (auth.uid() IS NOT NULL)

-- Policy: public.fornecedores.fornecedores_select_policy
permissive=PERMISSIVE roles=public cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.fornecedores.fornecedores_update_policy
permissive=PERMISSIVE roles=public cmd=UPDATE
qual: true
with_check: (auth.uid() IS NOT NULL)

-- Policy: public.funcionarios.authenticated_select_funcionarios
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.funcionarios.func_delete_admin
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.funcionarios.func_insert_admin
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))

-- Policy: public.funcionarios.func_select_admin
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))) OR (usuario_id = ( SELECT auth.uid() AS uid)))
with_check: (none)

-- Policy: public.funcionarios.func_update_admin
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.funcionarios_beneficios_empresas.funcionarios_beneficios_empresas_authenticated_all
permissive=PERMISSIVE roles=authenticated cmd=ALL
qual: true
with_check: true

-- Policy: public.funcionarios_detalhes.funcionarios_detalhes_authenticated_all
permissive=PERMISSIVE roles=authenticated cmd=ALL
qual: true
with_check: true

-- Policy: public.funcionarios_financeiro.funcionarios_financeiro_authenticated_all
permissive=PERMISSIVE roles=authenticated cmd=ALL
qual: true
with_check: true

-- Policy: public.funcionarios_novo.funcionarios_novo_authenticated_all
permissive=PERMISSIVE roles=authenticated cmd=ALL
qual: true
with_check: true

-- Policy: public.historico_status_orcamento.authenticated_insert_historico_status_orcamento
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: true

-- Policy: public.historico_status_orcamento.authenticated_select_historico_status_orcamento
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.historico_status_orcamento.historico_status_orcamento_authenticated_all
permissive=PERMISSIVE roles=authenticated cmd=ALL
qual: true
with_check: true

-- Policy: public.historico_status_orcamentos.authenticated_insert_historico_status_orcamentos
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: true

-- Policy: public.historico_status_orcamentos.authenticated_select_historico_status_orcamentos
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.informacoes_cliente_ubiqua.Permitir leitura admin_gerente
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.informacoes_cliente_ubiqua.Permitir leitura anon e auth
permissive=PERMISSIVE roles=anon,authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.informacoes_cliente_ubiqua.all_select_informacoes_cliente
permissive=PERMISSIVE roles=anon,authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.informacoes_cliente_ubiqua.anon_insert_informacoes_cliente
permissive=PERMISSIVE roles=anon cmd=INSERT
qual: (none)
with_check: true

-- Policy: public.informacoes_cliente_ubiqua.anon_update_informacoes_cliente
permissive=PERMISSIVE roles=anon cmd=UPDATE
qual: true
with_check: true

-- Policy: public.informacoes_cliente_ubiqua.auth_insert_informacoes_cliente
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: true

-- Policy: public.informacoes_cliente_ubiqua.auth_update_informacoes_cliente
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: true
with_check: true

-- Policy: public.itens_orcamento_ubiqua.all_select_itens_orcamento_ubiqua
permissive=PERMISSIVE roles=public cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.itens_orcamento_ubiqua.anon_insert_itens_orcamento_ubiqua
permissive=PERMISSIVE roles=anon cmd=INSERT
qual: (none)
with_check: true

-- Policy: public.itens_orcamento_ubiqua.auth_insert_itens_orcamento_ubiqua
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: true

-- Policy: public.itens_orcamento_ubiqua.authenticated_all_itens_orcamento_ubiqua
permissive=PERMISSIVE roles=authenticated cmd=ALL
qual: true
with_check: true

-- Policy: public.logs_auditoria.admin_all_logs
permissive=PERMISSIVE roles=authenticated cmd=ALL
qual: is_admin()
with_check: is_admin()

-- Policy: public.logs_auditoria.logs_auditoria_delete_policy
permissive=PERMISSIVE roles=public cmd=DELETE
qual: false
with_check: (none)

-- Policy: public.logs_auditoria.logs_auditoria_insert_policy
permissive=PERMISSIVE roles=public cmd=INSERT
qual: (none)
with_check: false

-- Policy: public.logs_auditoria.logs_auditoria_select_policy
permissive=PERMISSIVE roles=public cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.logs_auditoria.logs_auditoria_update_policy
permissive=PERMISSIVE roles=public cmd=UPDATE
qual: false
with_check: (none)

-- Policy: public.logs_auditoria.user_insert_logs
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (usuario_id = auth.uid())

-- Policy: public.marcas.marcas_delete
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.marcas.marcas_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))

-- Policy: public.marcas.marcas_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.marcas.marcas_update
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.negociacoes.negociacoes_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.negociacoes.negociacoes_write
permissive=PERMISSIVE roles=service_role cmd=ALL
qual: true
with_check: (none)

-- Policy: public.notas_fiscais.authenticated_all_notas_fiscais
permissive=PERMISSIVE roles=authenticated cmd=ALL
qual: true
with_check: true

-- Policy: public.notas_fiscais.authenticated_delete_nf
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: true
with_check: (none)

-- Policy: public.notas_fiscais.authenticated_insert_nf
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: true

-- Policy: public.notas_fiscais.authenticated_select_nf
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.notas_fiscais.authenticated_update_nf
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: true
with_check: true

-- Policy: public.orcamento_itens.anon_insert_orcamento_itens
permissive=PERMISSIVE roles=anon,authenticated cmd=INSERT
qual: (none)
with_check: true

-- Policy: public.orcamento_itens.authenticated_delete_orcamento_itens
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: true
with_check: (none)

-- Policy: public.orcamento_itens.authenticated_insert_orcamento_itens
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: true

-- Policy: public.orcamento_itens.authenticated_select_orcamento_itens
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.orcamento_itens.authenticated_update_orcamento_itens
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: true
with_check: true

-- Policy: public.orcamento_itens.orcamento_itens_delete
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: true
with_check: (none)

-- Policy: public.orcamento_itens.orcamento_itens_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: true

-- Policy: public.orcamento_itens.orcamento_itens_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.orcamento_itens.orcamento_itens_update
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: true
with_check: (none)

-- Policy: public.orcamentos.anon_insert_orcamentos
permissive=PERMISSIVE roles=anon,authenticated cmd=INSERT
qual: (none)
with_check: true

-- Policy: public.orcamentos.authenticated_delete_orcamentos
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: true
with_check: (none)

-- Policy: public.orcamentos.authenticated_insert_orcamentos
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: true

-- Policy: public.orcamentos.authenticated_select_orcamentos
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.orcamentos.authenticated_update_orcamentos
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: true
with_check: true

-- Policy: public.orcamentos.orcamentos_delete
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: true
with_check: (none)

-- Policy: public.orcamentos.orcamentos_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: true

-- Policy: public.orcamentos.orcamentos_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.orcamentos.orcamentos_update
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: true
with_check: (none)

-- Policy: public.orcamentos_revenda_ubiqua.all_select_orcamentos_revenda_ubiqua
permissive=PERMISSIVE roles=public cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.orcamentos_revenda_ubiqua.anon_insert_orcamentos_revenda_ubiqua
permissive=PERMISSIVE roles=anon cmd=INSERT
qual: (none)
with_check: true

-- Policy: public.orcamentos_revenda_ubiqua.auth_insert_orcamentos_revenda_ubiqua
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: true

-- Policy: public.orcamentos_revenda_ubiqua.authenticated_all_orcamentos_revenda_ubiqua
permissive=PERMISSIVE roles=authenticated cmd=ALL
qual: true
with_check: true

-- Policy: public.orcamentos_revenda_ubiqua.authenticated_update_orcamentos_revenda_ubiqua
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: true
with_check: true

-- Policy: public.orcamentos_revenda_ubiqua.update_orcamentos_revenda_ubiqua
permissive=PERMISSIVE roles=anon,authenticated cmd=UPDATE
qual: true
with_check: true

-- Policy: public.pedido_compra.Permitir leitura para autenticados
permissive=PERMISSIVE roles=public cmd=SELECT
qual: (auth.role() = 'authenticated'::text)
with_check: (none)

-- Policy: public.pedido_compra.Permitir tudo para service_role
permissive=PERMISSIVE roles=public cmd=ALL
qual: (auth.role() = 'service_role'::text)
with_check: (none)

-- Policy: public.plano_de_contas.plano_contas_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.plano_de_contas.plano_contas_write
permissive=PERMISSIVE roles=service_role cmd=ALL
qual: true
with_check: (none)

-- Policy: public.produtos.Permitir leitura para autenticados
permissive=PERMISSIVE roles=public cmd=SELECT
qual: (auth.role() = 'authenticated'::text)
with_check: (none)

-- Policy: public.produtos.Permitir tudo para service_role
permissive=PERMISSIVE roles=public cmd=ALL
qual: (auth.role() = 'service_role'::text)
with_check: (none)

-- Policy: public.produtos.authenticated_delete_produtos
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: true
with_check: (none)

-- Policy: public.produtos.authenticated_insert_produtos
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: true

-- Policy: public.produtos.authenticated_select_produtos
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.produtos.authenticated_update_produtos
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: true
with_check: true

-- Policy: public.produtos.prod_delete
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.produtos.prod_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))

-- Policy: public.produtos.prod_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.produtos.prod_update
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.projeto_itens.pi_delete_admin
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.projeto_itens.pi_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role])))))

-- Policy: public.projeto_itens.pi_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.projeto_itens.pi_update
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role])))))
with_check: (none)

-- Policy: public.projeto_parcelas.Permitir leitura para autenticados
permissive=PERMISSIVE roles=public cmd=SELECT
qual: (auth.role() = 'authenticated'::text)
with_check: (none)

-- Policy: public.projeto_parcelas.Permitir tudo para service_role
permissive=PERMISSIVE roles=public cmd=ALL
qual: (auth.role() = 'service_role'::text)
with_check: (none)

-- Policy: public.projeto_parcelas.authenticated_all_projeto_parcelas
permissive=PERMISSIVE roles=authenticated cmd=ALL
qual: true
with_check: true

-- Policy: public.projeto_parcelas.parcelas_delete_admin
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.projeto_parcelas.parcelas_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role])))))

-- Policy: public.projeto_parcelas.parcelas_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.projeto_parcelas.parcelas_update
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role])))))
with_check: (none)

-- Policy: public.projeto_parcelas_backup_migration.authenticated_all
permissive=PERMISSIVE roles=authenticated cmd=ALL
qual: true
with_check: true

-- Policy: public.projeto_produtos.Permitir leitura para autenticados
permissive=PERMISSIVE roles=public cmd=SELECT
qual: (auth.role() = 'authenticated'::text)
with_check: (none)

-- Policy: public.projeto_produtos.Permitir tudo para service_role
permissive=PERMISSIVE roles=public cmd=ALL
qual: (auth.role() = 'service_role'::text)
with_check: (none)

-- Policy: public.projeto_sinal.sinal_delete_admin
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.projeto_sinal.sinal_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role])))))

-- Policy: public.projeto_sinal.sinal_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.projeto_sinal.sinal_update
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role])))))
with_check: (none)

-- Policy: public.projetos.Permitir leitura para autenticados
permissive=PERMISSIVE roles=public cmd=SELECT
qual: (auth.role() = 'authenticated'::text)
with_check: (none)

-- Policy: public.projetos.Permitir tudo para service_role
permissive=PERMISSIVE roles=public cmd=ALL
qual: (auth.role() = 'service_role'::text)
with_check: (none)

-- Policy: public.projetos.authenticated_all_projetos
permissive=PERMISSIVE roles=authenticated cmd=ALL
qual: true
with_check: true

-- Policy: public.projetos.authenticated_delete_projetos
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: true
with_check: (none)

-- Policy: public.projetos.authenticated_insert_projetos
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: true

-- Policy: public.projetos.authenticated_select_projetos
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.projetos.authenticated_update_projetos
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: true
with_check: true

-- Policy: public.projetos.projetos_delete_admin
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.projetos.projetos_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role])))))

-- Policy: public.projetos.projetos_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.projetos.projetos_update
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role])))))
with_check: (none)

-- Policy: public.projetos_fechados.projetos_fechados_delete
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: true
with_check: (none)

-- Policy: public.projetos_fechados.projetos_fechados_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: true

-- Policy: public.projetos_fechados.projetos_fechados_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.projetos_fechados.projetos_fechados_update
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: true
with_check: true

-- Policy: public.quote_history.all_quote_history_auth
permissive=PERMISSIVE roles=public cmd=ALL
qual: true
with_check: (none)

-- Policy: public.quotes.all_quotes_auth
permissive=PERMISSIVE roles=public cmd=ALL
qual: true
with_check: true

-- Policy: public.remessas.remessas_delete_policy
permissive=PERMISSIVE roles=public cmd=DELETE
qual: true
with_check: (none)

-- Policy: public.remessas.remessas_insert_policy
permissive=PERMISSIVE roles=public cmd=INSERT
qual: (none)
with_check: (auth.uid() IS NOT NULL)

-- Policy: public.remessas.remessas_select_policy
permissive=PERMISSIVE roles=public cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.remessas.remessas_update_policy
permissive=PERMISSIVE roles=public cmd=UPDATE
qual: true
with_check: (auth.uid() IS NOT NULL)

-- Policy: public.retornos_processados.authenticated_all_retornos
permissive=PERMISSIVE roles=authenticated cmd=ALL
qual: true
with_check: true

-- Policy: public.retornos_processados.authenticated_delete_retornos
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: true
with_check: (none)

-- Policy: public.retornos_processados.authenticated_insert_retornos
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: true

-- Policy: public.retornos_processados.authenticated_select_retornos
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.retornos_processados.authenticated_update_retornos
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: true
with_check: true

-- Policy: public.revenda_ubiqua.authenticated_select_revenda
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.revenda_ubiqua.revenda_ubiqua_delete
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.revenda_ubiqua.revenda_ubiqua_delete_admin_ubiqua
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: ((EXISTS ( SELECT 1
   FROM usuarios_ubiqua u
  WHERE ((u.id = auth.uid()) AND (u.nivel_acesso = 'admin'::nivel_acesso_tipo)))) OR (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))))
with_check: (none)

-- Policy: public.revenda_ubiqua.revenda_ubiqua_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))

-- Policy: public.revenda_ubiqua.revenda_ubiqua_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.revenda_ubiqua.revenda_ubiqua_select_anon
permissive=PERMISSIVE roles=anon cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.revenda_ubiqua.revenda_ubiqua_update
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))

-- Policy: public.separacao_arquivos.separacao_arquivos_authenticated_all
permissive=PERMISSIVE roles=authenticated cmd=ALL
qual: true
with_check: true

-- Policy: public.separacao_itens.sep_itens_delete
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.separacao_itens.sep_itens_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role])))))

-- Policy: public.separacao_itens.sep_itens_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.separacao_itens.sep_itens_update
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role])))))
with_check: (none)

-- Policy: public.separacoes.separacoes_delete_admin
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.separacoes.separacoes_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role])))))

-- Policy: public.separacoes.separacoes_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.separacoes.separacoes_update
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role])))))
with_check: (none)

-- Policy: public.separacoes_arquivos.separacoes_arquivos_authenticated_all
permissive=PERMISSIVE roles=authenticated cmd=ALL
qual: true
with_check: true

-- Policy: public.solicitacoes_compra.authenticated_delete_solicitacoes_compra
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: true
with_check: (none)

-- Policy: public.solicitacoes_compra.authenticated_insert_solicitacoes_compra
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: true

-- Policy: public.solicitacoes_compra.authenticated_select_solicitacoes_compra
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.solicitacoes_compra.authenticated_update_solicitacoes_compra
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: true
with_check: true

-- Policy: public.sync_history.sync_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role])))))

-- Policy: public.sync_history.sync_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.systems.authenticated_select_systems
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.transacoes.authenticated_all_transacoes
permissive=PERMISSIVE roles=authenticated cmd=ALL
qual: true
with_check: true

-- Policy: public.transacoes.trans_delete_admin
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = 'admin'::usuario_role))))
with_check: (none)

-- Policy: public.transacoes.trans_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role])))))

-- Policy: public.transacoes.trans_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role])))))
with_check: (none)

-- Policy: public.transacoes.trans_update_admin
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = 'admin'::usuario_role))))
with_check: (none)

-- Policy: public.user_roles_separacao.Permitir leitura para usuarios autenticados
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.user_system_access.admin_all_usa
permissive=PERMISSIVE roles=authenticated cmd=ALL
qual: is_admin()
with_check: is_admin()

-- Policy: public.user_system_access.user_select_usa
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: (user_id = auth.uid())
with_check: (none)

-- Policy: public.usuarios.admin_all_usuarios
permissive=PERMISSIVE roles=authenticated cmd=ALL
qual: is_admin()
with_check: is_admin()

-- Policy: public.usuarios.authenticated_select_self
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: (auth.uid() = id)
with_check: (none)

-- Policy: public.usuarios.authenticated_select_usuarios
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.usuarios.usuarios_delete_admin
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = 'admin'::usuario_role))))
with_check: (none)

-- Policy: public.usuarios.usuarios_insert_admin
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = 'admin'::usuario_role))))

-- Policy: public.usuarios.usuarios_select_own
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: true
with_check: (none)

-- Policy: public.usuarios.usuarios_update_own
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: ((id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = auth.uid()) AND (u.role = 'admin'::usuario_role)))))
with_check: (none)

-- Policy: public.usuarios_ubiqua.usuarios_ubiqua_delete
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: ((id = auth.uid()) OR is_ubiqua_admin())
with_check: (none)

-- Policy: public.usuarios_ubiqua.usuarios_ubiqua_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: ((id = auth.uid()) OR is_ubiqua_admin())

-- Policy: public.usuarios_ubiqua.usuarios_ubiqua_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: ((id = auth.uid()) OR is_ubiqua_admin())
with_check: (none)

-- Policy: public.usuarios_ubiqua.usuarios_ubiqua_update
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: ((id = auth.uid()) OR is_ubiqua_admin())
with_check: ((id = auth.uid()) OR is_ubiqua_admin())

-- Policy: public.vendas.Permitir leitura para autenticados
permissive=PERMISSIVE roles=public cmd=SELECT
qual: (auth.role() = 'authenticated'::text)
with_check: (none)

-- Policy: public.vendas.Permitir tudo para service_role
permissive=PERMISSIVE roles=public cmd=ALL
qual: (auth.role() = 'service_role'::text)
with_check: (none)

-- Policy: public.vendas_marca.vendas_delete
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: public.vendas_marca.vendas_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))

-- Policy: public.vendas_marca.vendas_select
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role])))))
with_check: (none)

-- Policy: public.vendas_marca.vendas_update
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))
with_check: (none)

-- Policy: storage.objects.Admin Delete
permissive=PERMISSIVE roles=authenticated cmd=DELETE
qual: (bucket_id = 'revenda-ubiqua-images'::text)
with_check: (none)

-- Policy: storage.objects.Admin Update
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: (bucket_id = 'revenda-ubiqua-images'::text)
with_check: (none)

-- Policy: storage.objects.Admin Upload
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (bucket_id = 'revenda-ubiqua-images'::text)

-- Policy: storage.objects.Anon can upload
permissive=PERMISSIVE roles=anon cmd=INSERT
qual: (none)
with_check: (bucket_id = 'orcamentos'::text)

-- Policy: storage.objects.Anon public read for catalogos
permissive=PERMISSIVE roles=anon cmd=SELECT
qual: (bucket_id = 'revenda-ubiqua-images'::text)
with_check: (none)

-- Policy: storage.objects.Authenticated Users can upload
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (bucket_id = 'orcamentos'::text)

-- Policy: storage.objects.Authenticated public read for catalogos
permissive=PERMISSIVE roles=authenticated cmd=SELECT
qual: (bucket_id = 'revenda-ubiqua-images'::text)
with_check: (none)

-- Policy: storage.objects.Give anon users access to JPG images in folder 1ps91ds_0
permissive=PERMISSIVE roles=public cmd=INSERT
qual: (none)
with_check: ((bucket_id = 'revenda-ubiqua-images'::text) AND (storage.extension(name) = 'jpg'::text) AND (lower((storage.foldername(name))[1]) = 'public'::text) AND (auth.role() = 'anon'::text))

-- Policy: storage.objects.Give anon users access to JPG images in folder 1ps91ds_1
permissive=PERMISSIVE roles=public cmd=UPDATE
qual: ((bucket_id = 'revenda-ubiqua-images'::text) AND (storage.extension(name) = 'jpg'::text) AND (lower((storage.foldername(name))[1]) = 'public'::text) AND (auth.role() = 'anon'::text))
with_check: (none)

-- Policy: storage.objects.Give anon users access to JPG images in folder 1ps91ds_2
permissive=PERMISSIVE roles=public cmd=SELECT
qual: ((bucket_id = 'revenda-ubiqua-images'::text) AND (storage.extension(name) = 'jpg'::text) AND (lower((storage.foldername(name))[1]) = 'public'::text) AND (auth.role() = 'anon'::text))
with_check: (none)

-- Policy: storage.objects.Public Access
permissive=PERMISSIVE roles=public cmd=SELECT
qual: (bucket_id = 'orcamentos'::text)
with_check: (none)

-- Policy: storage.objects.orcamentos_anon_insert
permissive=PERMISSIVE roles=anon cmd=INSERT
qual: (none)
with_check: (bucket_id = 'orcamentos'::text)

-- Policy: storage.objects.orcamentos_authenticated_insert
permissive=PERMISSIVE roles=authenticated cmd=INSERT
qual: (none)
with_check: (bucket_id = 'orcamentos'::text)

-- Policy: storage.objects.orcamentos_authenticated_update
permissive=PERMISSIVE roles=authenticated cmd=UPDATE
qual: (bucket_id = 'orcamentos'::text)
with_check: (none)

-- Policy: storage.objects.orcamentos_public_read
permissive=PERMISSIVE roles=public cmd=SELECT
qual: (bucket_id = 'orcamentos'::text)
with_check: (none)

