-- Trigger: on_auth_user_created ON users
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_user();
-- Trigger: contas_updated_at ON contas_bancarias
CREATE TRIGGER contas_updated_at BEFORE UPDATE ON public.contas_bancarias FOR EACH ROW EXECUTE FUNCTION set_updated_at();
-- Trigger: contatos_updated_at ON contatos
CREATE TRIGGER contatos_updated_at BEFORE UPDATE ON public.contatos FOR EACH ROW EXECUTE FUNCTION set_updated_at();
-- Trigger: on_contato_created ON contatos
CREATE TRIGGER on_contato_created AFTER INSERT OR UPDATE ON public.contatos FOR EACH ROW EXECUTE FUNCTION handle_contato_tipo();
-- Trigger: trg_propagate_contato_nome ON contatos
CREATE TRIGGER trg_propagate_contato_nome AFTER UPDATE OF nome ON public.contatos FOR EACH ROW EXECUTE FUNCTION propagate_contato_nome();
-- Trigger: custos_rec_updated_at ON custos_recorrentes
CREATE TRIGGER custos_rec_updated_at BEFORE UPDATE ON public.custos_recorrentes FOR EACH ROW EXECUTE FUNCTION set_updated_at();
-- Trigger: entregas_updated_at ON entregas
CREATE TRIGGER entregas_updated_at BEFORE UPDATE ON public.entregas FOR EACH ROW EXECUTE FUNCTION set_updated_at();
-- Trigger: trg_atualizar_estoque_saldos_projeto_item ON estoque_saldos_projeto_item
CREATE TRIGGER trg_atualizar_estoque_saldos_projeto_item BEFORE UPDATE ON public.estoque_saldos_projeto_item FOR EACH ROW EXECUTE FUNCTION trg_estoque_saldos_projeto_item_atualizado_em();
-- Trigger: trg_validar_saldo_projeto_item ON estoque_saldos_projeto_item
CREATE TRIGGER trg_validar_saldo_projeto_item BEFORE INSERT OR UPDATE ON public.estoque_saldos_projeto_item FOR EACH ROW EXECUTE FUNCTION fn_validar_saldo_projeto_item();
-- Trigger: trg_fornecedores_auditoria ON fornecedores
CREATE TRIGGER trg_fornecedores_auditoria AFTER INSERT OR DELETE OR UPDATE ON public.fornecedores FOR EACH ROW EXECUTE FUNCTION fn_log_auditoria();
-- Trigger: trg_fornecedores_updated_at ON fornecedores
CREATE TRIGGER trg_fornecedores_updated_at BEFORE UPDATE ON public.fornecedores FOR EACH ROW EXECUTE FUNCTION fn_atualiza_updated_at();
-- Trigger: funcionarios_updated_at ON funcionarios
CREATE TRIGGER funcionarios_updated_at BEFORE UPDATE ON public.funcionarios FOR EACH ROW EXECUTE FUNCTION set_updated_at();
-- Trigger: trg_orcamento_item_workflow ON orcamento_itens
CREATE TRIGGER trg_orcamento_item_workflow AFTER INSERT ON public.orcamento_itens FOR EACH ROW EXECUTE FUNCTION handle_orcamento_item_workflow();
-- Trigger: trg_normalize_orcamento_status ON orcamentos
CREATE TRIGGER trg_normalize_orcamento_status BEFORE INSERT OR UPDATE OF status ON public.orcamentos FOR EACH ROW EXECUTE FUNCTION normalize_orcamento_status();
-- Trigger: trg_orcamento_workflow ON orcamentos
CREATE TRIGGER trg_orcamento_workflow BEFORE INSERT OR UPDATE ON public.orcamentos FOR EACH ROW EXECUTE FUNCTION handle_orcamento_workflow();
-- Trigger: trg_sync_contact_type_on_budget ON orcamentos
CREATE TRIGGER trg_sync_contact_type_on_budget AFTER INSERT OR UPDATE OF cliente_id ON public.orcamentos FOR EACH ROW EXECUTE FUNCTION sync_contact_type_on_budget();
-- Trigger: trigger_set_orcamento_numero ON orcamentos
CREATE TRIGGER trigger_set_orcamento_numero BEFORE INSERT ON public.orcamentos FOR EACH ROW EXECUTE FUNCTION set_orcamento_numero();
-- Trigger: trigger_auto_numero_orcamento ON orcamentos_revenda_ubiqua
CREATE TRIGGER trigger_auto_numero_orcamento BEFORE INSERT ON public.orcamentos_revenda_ubiqua FOR EACH ROW EXECUTE FUNCTION fn_auto_numero_orcamento();
-- Trigger: trigger_orcamento_updated_at ON orcamentos_revenda_ubiqua
CREATE TRIGGER trigger_orcamento_updated_at BEFORE UPDATE ON public.orcamentos_revenda_ubiqua FOR EACH ROW EXECUTE FUNCTION fn_update_orcamento_timestamp();
-- Trigger: trg_auditoria_papeis ON papeis
CREATE TRIGGER trg_auditoria_papeis AFTER INSERT OR DELETE OR UPDATE ON public.papeis FOR EACH ROW EXECUTE FUNCTION fn_auditoria_permissoes();
-- Trigger: trg_auditoria_papel_permissoes ON papel_permissoes
CREATE TRIGGER trg_auditoria_papel_permissoes AFTER INSERT OR DELETE OR UPDATE ON public.papel_permissoes FOR EACH ROW EXECUTE FUNCTION fn_auditoria_permissoes();
-- Trigger: produtos_updated_at ON produtos
CREATE TRIGGER produtos_updated_at BEFORE UPDATE ON public.produtos FOR EACH ROW EXECUTE FUNCTION set_updated_at();
-- Trigger: trg_atualizar_preco_venda ON produtos
CREATE TRIGGER trg_atualizar_preco_venda BEFORE INSERT OR UPDATE OF preco_custo, porc_desconto, icms_entrada, ipi_entrada, porc_despesas ON public.produtos FOR EACH ROW EXECUTE FUNCTION fn_atualizar_preco_venda();
-- Trigger: trg_calculo_preco_venda ON produtos
CREATE TRIGGER trg_calculo_preco_venda BEFORE INSERT OR UPDATE ON public.produtos FOR EACH ROW EXECUTE FUNCTION fn_atualizar_preco_venda();
-- Trigger: update_produtos_updated_at ON produtos
CREATE TRIGGER update_produtos_updated_at BEFORE UPDATE ON public.produtos FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
-- Trigger: projeto_itens_updated_at ON projeto_itens
CREATE TRIGGER projeto_itens_updated_at BEFORE UPDATE ON public.projeto_itens FOR EACH ROW EXECUTE FUNCTION set_updated_at();
-- Trigger: trg_set_projeto_itens_descricao ON projeto_itens
CREATE TRIGGER trg_set_projeto_itens_descricao BEFORE INSERT OR UPDATE ON public.projeto_itens FOR EACH ROW EXECUTE FUNCTION set_projeto_itens_descricao();
-- Trigger: trg_sync_valor_total ON projeto_itens
CREATE TRIGGER trg_sync_valor_total AFTER INSERT OR DELETE OR UPDATE ON public.projeto_itens FOR EACH ROW EXECUTE FUNCTION sync_projeto_valor_total();
-- Trigger: trg_proteger_parcelas ON projeto_parcelas
CREATE TRIGGER trg_proteger_parcelas BEFORE INSERT ON public.projeto_parcelas FOR EACH ROW EXECUTE FUNCTION trigger_proteger_parcelas();
-- Trigger: projeto_sinal_updated_at ON projeto_sinal
CREATE TRIGGER projeto_sinal_updated_at BEFORE UPDATE ON public.projeto_sinal FOR EACH ROW EXECUTE FUNCTION set_updated_at();
-- Trigger: projetos_updated_at ON projetos
CREATE TRIGGER projetos_updated_at BEFORE UPDATE ON public.projetos FOR EACH ROW EXECUTE FUNCTION set_updated_at();
-- Trigger: trg_fechar_projeto ON projetos
CREATE TRIGGER trg_fechar_projeto AFTER UPDATE OF status ON public.projetos FOR EACH ROW EXECUTE FUNCTION trigger_fechar_projeto();
-- Trigger: trg_propagate_projeto_codigo ON projetos
CREATE TRIGGER trg_propagate_projeto_codigo AFTER UPDATE OF codigo ON public.projetos FOR EACH ROW EXECUTE FUNCTION propagate_projeto_codigo();
-- Trigger: trg_proteger_fechamento ON projetos
CREATE TRIGGER trg_proteger_fechamento BEFORE UPDATE OF status ON public.projetos FOR EACH ROW EXECUTE FUNCTION trigger_proteger_fechamento();
-- Trigger: trg_sync_equipe_por_responsavel ON projetos
CREATE TRIGGER trg_sync_equipe_por_responsavel BEFORE INSERT OR UPDATE OF responsavel_nome ON public.projetos FOR EACH ROW EXECUTE FUNCTION fn_sync_equipe_por_responsavel();
-- Trigger: trg_sync_responsavel_nome ON projetos
CREATE TRIGGER trg_sync_responsavel_nome BEFORE INSERT OR UPDATE OF responsavel_id ON public.projetos FOR EACH ROW EXECUTE FUNCTION sync_responsavel_nome();
-- Trigger: update_projetos_updated_at ON projetos
CREATE TRIGGER update_projetos_updated_at BEFORE UPDATE ON public.projetos FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
-- Trigger: trg_remessas_auditoria ON remessas
CREATE TRIGGER trg_remessas_auditoria AFTER INSERT OR DELETE OR UPDATE ON public.remessas FOR EACH ROW EXECUTE FUNCTION fn_log_auditoria();
-- Trigger: trg_remessas_updated_at ON remessas
CREATE TRIGGER trg_remessas_updated_at BEFORE UPDATE ON public.remessas FOR EACH ROW EXECUTE FUNCTION fn_atualiza_updated_at();
-- Trigger: trg_revenda_ubiqua_slug ON revenda_ubiqua
CREATE TRIGGER trg_revenda_ubiqua_slug BEFORE INSERT OR UPDATE OF desc_produto, descricao, valor_revenda ON public.revenda_ubiqua FOR EACH ROW EXECUTE FUNCTION trigger_update_revenda_ubiqua_slug();
-- Trigger: trigger_revenda_ubiqua_updated_at ON revenda_ubiqua
CREATE TRIGGER trigger_revenda_ubiqua_updated_at BEFORE UPDATE ON public.revenda_ubiqua FOR EACH ROW EXECUTE FUNCTION update_revenda_ubiqua_updated_at();
-- Trigger: separacoes_updated_at ON separacoes
CREATE TRIGGER separacoes_updated_at BEFORE UPDATE ON public.separacoes FOR EACH ROW EXECUTE FUNCTION set_updated_at();
-- Trigger: trg_separacao_pronta ON separacoes
CREATE TRIGGER trg_separacao_pronta AFTER UPDATE OF status, data_entrega ON public.separacoes FOR EACH ROW EXECUTE FUNCTION trigger_separacao_pronta();
-- Trigger: trg_sync_sep_cliente ON separacoes
CREATE TRIGGER trg_sync_sep_cliente BEFORE INSERT OR UPDATE OF cliente_id ON public.separacoes FOR EACH ROW EXECUTE FUNCTION sync_separacao_cliente();
-- Trigger: trg_sync_sep_codigo_obra ON separacoes
CREATE TRIGGER trg_sync_sep_codigo_obra BEFORE INSERT OR UPDATE OF projeto_id ON public.separacoes FOR EACH ROW EXECUTE FUNCTION sync_separacao_codigo_obra();
-- Trigger: trg_track_reagendamento ON separacoes
CREATE TRIGGER trg_track_reagendamento BEFORE UPDATE OF data_entrega ON public.separacoes FOR EACH ROW EXECUTE FUNCTION track_reagendamento();
-- Trigger: trg_auditoria_usuario_papeis ON usuario_papeis
CREATE TRIGGER trg_auditoria_usuario_papeis AFTER INSERT OR DELETE OR UPDATE ON public.usuario_papeis FOR EACH ROW EXECUTE FUNCTION fn_auditoria_usuario_papeis();
-- Trigger: trg_auditoria_usuario_permissao_excecoes ON usuario_permissao_excecoes
CREATE TRIGGER trg_auditoria_usuario_permissao_excecoes AFTER INSERT OR DELETE OR UPDATE ON public.usuario_permissao_excecoes FOR EACH ROW EXECUTE FUNCTION fn_auditoria_permissoes();
-- Trigger: trg_log_can_approve_quotes ON usuarios
CREATE TRIGGER trg_log_can_approve_quotes AFTER UPDATE OF can_approve_quotes ON public.usuarios FOR EACH ROW EXECUTE FUNCTION log_can_approve_quotes_change();
-- Trigger: trg_propagate_usuario_nome ON usuarios
CREATE TRIGGER trg_propagate_usuario_nome AFTER UPDATE OF nome ON public.usuarios FOR EACH ROW EXECUTE FUNCTION propagate_usuario_nome();
-- Trigger: usuarios_updated_at ON usuarios
CREATE TRIGGER usuarios_updated_at BEFORE UPDATE ON public.usuarios FOR EACH ROW EXECUTE FUNCTION set_updated_at();
-- Trigger: update_vendas_updated_at ON vendas
CREATE TRIGGER update_vendas_updated_at BEFORE UPDATE ON public.vendas FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
-- Trigger: enforce_bucket_name_length_trigger ON buckets
CREATE TRIGGER enforce_bucket_name_length_trigger BEFORE INSERT OR UPDATE OF name ON storage.buckets FOR EACH ROW EXECUTE FUNCTION storage.enforce_bucket_name_length();
-- Trigger: protect_buckets_delete ON buckets
CREATE TRIGGER protect_buckets_delete BEFORE DELETE ON storage.buckets FOR EACH STATEMENT EXECUTE FUNCTION storage.protect_delete();
-- Trigger: protect_objects_delete ON objects
CREATE TRIGGER protect_objects_delete BEFORE DELETE ON storage.objects FOR EACH STATEMENT EXECUTE FUNCTION storage.protect_delete();
-- Trigger: update_objects_updated_at ON objects
CREATE TRIGGER update_objects_updated_at BEFORE UPDATE ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.update_updated_at_column();
