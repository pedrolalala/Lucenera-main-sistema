-- Trigger: auth.users.on_auth_user_created
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Trigger: public.contas_bancarias.contas_updated_at
CREATE TRIGGER contas_updated_at BEFORE UPDATE ON public.contas_bancarias FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Trigger: public.contatos.contatos_updated_at
CREATE TRIGGER contatos_updated_at BEFORE UPDATE ON public.contatos FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Trigger: public.contatos.on_contato_created
CREATE TRIGGER on_contato_created AFTER INSERT OR UPDATE ON public.contatos FOR EACH ROW EXECUTE FUNCTION handle_contato_tipo();

-- Trigger: public.contatos.trg_propagate_contato_nome
CREATE TRIGGER trg_propagate_contato_nome AFTER UPDATE OF nome ON public.contatos FOR EACH ROW EXECUTE FUNCTION propagate_contato_nome();

-- Trigger: public.custos_recorrentes.custos_rec_updated_at
CREATE TRIGGER custos_rec_updated_at BEFORE UPDATE ON public.custos_recorrentes FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Trigger: public.entregas.entregas_updated_at
CREATE TRIGGER entregas_updated_at BEFORE UPDATE ON public.entregas FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Trigger: public.fornecedores.trg_fornecedores_auditoria
CREATE TRIGGER trg_fornecedores_auditoria AFTER INSERT OR DELETE OR UPDATE ON public.fornecedores FOR EACH ROW EXECUTE FUNCTION fn_log_auditoria();

-- Trigger: public.fornecedores.trg_fornecedores_updated_at
CREATE TRIGGER trg_fornecedores_updated_at BEFORE UPDATE ON public.fornecedores FOR EACH ROW EXECUTE FUNCTION fn_atualiza_updated_at();

-- Trigger: public.funcionarios.funcionarios_updated_at
CREATE TRIGGER funcionarios_updated_at BEFORE UPDATE ON public.funcionarios FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Trigger: public.orcamentos.trigger_set_orcamento_numero
CREATE TRIGGER trigger_set_orcamento_numero BEFORE INSERT ON public.orcamentos FOR EACH ROW EXECUTE FUNCTION set_orcamento_numero();

-- Trigger: public.orcamentos_revenda_ubiqua.trigger_auto_numero_orcamento
CREATE TRIGGER trigger_auto_numero_orcamento BEFORE INSERT ON public.orcamentos_revenda_ubiqua FOR EACH ROW EXECUTE FUNCTION fn_auto_numero_orcamento();

-- Trigger: public.orcamentos_revenda_ubiqua.trigger_orcamento_updated_at
CREATE TRIGGER trigger_orcamento_updated_at BEFORE UPDATE ON public.orcamentos_revenda_ubiqua FOR EACH ROW EXECUTE FUNCTION fn_update_orcamento_timestamp();

-- Trigger: public.produtos.produtos_updated_at
CREATE TRIGGER produtos_updated_at BEFORE UPDATE ON public.produtos FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Trigger: public.produtos.trg_atualizar_preco_venda
CREATE TRIGGER trg_atualizar_preco_venda BEFORE INSERT OR UPDATE OF preco_custo, porc_desconto, icms_entrada, ipi_entrada, porc_despesas ON public.produtos FOR EACH ROW EXECUTE FUNCTION fn_atualizar_preco_venda();

-- Trigger: public.produtos.trg_calculo_preco_venda
CREATE TRIGGER trg_calculo_preco_venda BEFORE INSERT OR UPDATE ON public.produtos FOR EACH ROW EXECUTE FUNCTION fn_atualizar_preco_venda();

-- Trigger: public.produtos.update_produtos_updated_at
CREATE TRIGGER update_produtos_updated_at BEFORE UPDATE ON public.produtos FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger: public.projeto_itens.projeto_itens_updated_at
CREATE TRIGGER projeto_itens_updated_at BEFORE UPDATE ON public.projeto_itens FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Trigger: public.projeto_itens.trg_set_projeto_itens_descricao
CREATE TRIGGER trg_set_projeto_itens_descricao BEFORE INSERT OR UPDATE ON public.projeto_itens FOR EACH ROW EXECUTE FUNCTION set_projeto_itens_descricao();

-- Trigger: public.projeto_itens.trg_sync_valor_total
CREATE TRIGGER trg_sync_valor_total AFTER INSERT OR DELETE OR UPDATE ON public.projeto_itens FOR EACH ROW EXECUTE FUNCTION sync_projeto_valor_total();

-- Trigger: public.projeto_parcelas.trg_proteger_parcelas
CREATE TRIGGER trg_proteger_parcelas BEFORE INSERT ON public.projeto_parcelas FOR EACH ROW EXECUTE FUNCTION trigger_proteger_parcelas();

-- Trigger: public.projeto_parcelas.update_parcelas_updated_at
CREATE TRIGGER update_parcelas_updated_at BEFORE UPDATE ON public.projeto_parcelas FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger: public.projeto_sinal.projeto_sinal_updated_at
CREATE TRIGGER projeto_sinal_updated_at BEFORE UPDATE ON public.projeto_sinal FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Trigger: public.projetos.projetos_updated_at
CREATE TRIGGER projetos_updated_at BEFORE UPDATE ON public.projetos FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Trigger: public.projetos.trg_fechar_projeto
CREATE TRIGGER trg_fechar_projeto AFTER UPDATE OF status ON public.projetos FOR EACH ROW EXECUTE FUNCTION trigger_fechar_projeto();


-- Trigger: public.projetos.trg_propagate_projeto_codigo
CREATE TRIGGER trg_propagate_projeto_codigo AFTER UPDATE OF codigo ON public.projetos FOR EACH ROW EXECUTE FUNCTION propagate_projeto_codigo();

-- Trigger: public.projetos.trg_proteger_fechamento
CREATE TRIGGER trg_proteger_fechamento BEFORE UPDATE OF status ON public.projetos FOR EACH ROW EXECUTE FUNCTION trigger_proteger_fechamento();


-- Trigger: public.projetos.trg_sync_responsavel_nome
CREATE TRIGGER trg_sync_responsavel_nome BEFORE INSERT OR UPDATE OF responsavel_id ON public.projetos FOR EACH ROW EXECUTE FUNCTION sync_responsavel_nome();

-- Trigger: public.projetos.update_projetos_updated_at
CREATE TRIGGER update_projetos_updated_at BEFORE UPDATE ON public.projetos FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger: public.remessas.trg_remessas_auditoria
CREATE TRIGGER trg_remessas_auditoria AFTER INSERT OR DELETE OR UPDATE ON public.remessas FOR EACH ROW EXECUTE FUNCTION fn_log_auditoria();

-- Trigger: public.remessas.trg_remessas_updated_at
CREATE TRIGGER trg_remessas_updated_at BEFORE UPDATE ON public.remessas FOR EACH ROW EXECUTE FUNCTION fn_atualiza_updated_at();

-- Trigger: public.revenda_ubiqua.trg_revenda_ubiqua_slug
CREATE TRIGGER trg_revenda_ubiqua_slug BEFORE INSERT OR UPDATE OF desc_produto, descricao, valor_revenda ON public.revenda_ubiqua FOR EACH ROW EXECUTE FUNCTION trigger_update_revenda_ubiqua_slug();

-- Trigger: public.revenda_ubiqua.trigger_revenda_ubiqua_updated_at
CREATE TRIGGER trigger_revenda_ubiqua_updated_at BEFORE UPDATE ON public.revenda_ubiqua FOR EACH ROW EXECUTE FUNCTION update_revenda_ubiqua_updated_at();

-- Trigger: public.separacoes.separacoes_updated_at
CREATE TRIGGER separacoes_updated_at BEFORE UPDATE ON public.separacoes FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Trigger: public.separacoes.trg_separacao_pronta
CREATE TRIGGER trg_separacao_pronta AFTER UPDATE OF status, data_entrega ON public.separacoes FOR EACH ROW EXECUTE FUNCTION trigger_separacao_pronta();

-- Trigger: public.separacoes.trg_sync_sep_cliente
CREATE TRIGGER trg_sync_sep_cliente BEFORE INSERT OR UPDATE OF cliente_id ON public.separacoes FOR EACH ROW EXECUTE FUNCTION sync_separacao_cliente();

-- Trigger: public.separacoes.trg_sync_sep_codigo_obra
CREATE TRIGGER trg_sync_sep_codigo_obra BEFORE INSERT OR UPDATE OF projeto_id ON public.separacoes FOR EACH ROW EXECUTE FUNCTION sync_separacao_codigo_obra();

-- Trigger: public.separacoes.trg_track_reagendamento
CREATE TRIGGER trg_track_reagendamento BEFORE UPDATE OF data_entrega ON public.separacoes FOR EACH ROW EXECUTE FUNCTION track_reagendamento();

-- Trigger: public.usuarios.trg_propagate_usuario_nome
CREATE TRIGGER trg_propagate_usuario_nome AFTER UPDATE OF nome ON public.usuarios FOR EACH ROW EXECUTE FUNCTION propagate_usuario_nome();

-- Trigger: public.usuarios.usuarios_updated_at
CREATE TRIGGER usuarios_updated_at BEFORE UPDATE ON public.usuarios FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Trigger: public.vendas.update_vendas_updated_at
CREATE TRIGGER update_vendas_updated_at BEFORE UPDATE ON public.vendas FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger: storage.buckets.enforce_bucket_name_length_trigger
CREATE TRIGGER enforce_bucket_name_length_trigger BEFORE INSERT OR UPDATE OF name ON storage.buckets FOR EACH ROW EXECUTE FUNCTION storage.enforce_bucket_name_length();

-- Trigger: storage.buckets.protect_buckets_delete
CREATE TRIGGER protect_buckets_delete BEFORE DELETE ON storage.buckets FOR EACH STATEMENT EXECUTE FUNCTION storage.protect_delete();

-- Trigger: storage.objects.protect_objects_delete
CREATE TRIGGER protect_objects_delete BEFORE DELETE ON storage.objects FOR EACH STATEMENT EXECUTE FUNCTION storage.protect_delete();

-- Trigger: storage.objects.update_objects_updated_at
CREATE TRIGGER update_objects_updated_at BEFORE UPDATE ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.update_updated_at_column();

