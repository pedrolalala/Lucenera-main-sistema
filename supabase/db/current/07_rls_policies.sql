-- Policy: admin_select_auditoria_permissoes ON auditoria_permissoes
CREATE POLICY admin_select_auditoria_permissoes ON public.auditoria_permissoes AS PERMISSIVE FOR SELECT TO authenticated
  USING (is_admin());
-- Policy: authenticated_all_boletos ON boletos
CREATE POLICY authenticated_all_boletos ON public.boletos AS PERMISSIVE FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: authenticated_delete_boletos ON boletos
CREATE POLICY authenticated_delete_boletos ON public.boletos AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: authenticated_insert_boletos ON boletos
CREATE POLICY authenticated_insert_boletos ON public.boletos AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: authenticated_select_boletos ON boletos
CREATE POLICY authenticated_select_boletos ON public.boletos AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: authenticated_update_boletos ON boletos
CREATE POLICY authenticated_update_boletos ON public.boletos AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: authenticated_insert_categorias_financeiras ON categorias_financeiras
CREATE POLICY authenticated_insert_categorias_financeiras ON public.categorias_financeiras AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: authenticated_select_categorias_financeiras ON categorias_financeiras
CREATE POLICY authenticated_select_categorias_financeiras ON public.categorias_financeiras AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: authenticated_update_categorias_financeiras ON categorias_financeiras
CREATE POLICY authenticated_update_categorias_financeiras ON public.categorias_financeiras AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: catfin_delete ON categorias_financeiras
CREATE POLICY catfin_delete ON public.categorias_financeiras AS PERMISSIVE FOR DELETE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: catfin_insert ON categorias_financeiras
CREATE POLICY catfin_insert ON public.categorias_financeiras AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: catfin_select ON categorias_financeiras
CREATE POLICY catfin_select ON public.categorias_financeiras AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: catfin_update ON categorias_financeiras
CREATE POLICY catfin_update ON public.categorias_financeiras AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: authenticated_select_categorias_produto ON categorias_produto
CREATE POLICY authenticated_select_categorias_produto ON public.categorias_produto AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: categorias_produto_select ON categorias_produto
CREATE POLICY categorias_produto_select ON public.categorias_produto AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: categorias_produto_write ON categorias_produto
CREATE POLICY categorias_produto_write ON public.categorias_produto AS PERMISSIVE FOR ALL TO service_role
  USING (true);
-- Policy: authenticated_insert_contas_bancarias ON contas_bancarias
CREATE POLICY authenticated_insert_contas_bancarias ON public.contas_bancarias AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: authenticated_select_contas_bancarias ON contas_bancarias
CREATE POLICY authenticated_select_contas_bancarias ON public.contas_bancarias AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: authenticated_update_contas_bancarias ON contas_bancarias
CREATE POLICY authenticated_update_contas_bancarias ON public.contas_bancarias AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: contas_delete ON contas_bancarias
CREATE POLICY contas_delete ON public.contas_bancarias AS PERMISSIVE FOR DELETE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = 'admin'::usuario_role)))));
-- Policy: contas_insert ON contas_bancarias
CREATE POLICY contas_insert ON public.contas_bancarias AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = 'admin'::usuario_role)))));
-- Policy: contas_select ON contas_bancarias
CREATE POLICY contas_select ON public.contas_bancarias AS PERMISSIVE FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
-- Policy: contas_update ON contas_bancarias
CREATE POLICY contas_update ON public.contas_bancarias AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = 'admin'::usuario_role)))));
-- Policy: contato_origens_select ON contato_origens
CREATE POLICY contato_origens_select ON public.contato_origens AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: contato_origens_write ON contato_origens
CREATE POLICY contato_origens_write ON public.contato_origens AS PERMISSIVE FOR ALL TO service_role
  USING (true);
-- Policy: authenticated_all ON contato_tipos
CREATE POLICY authenticated_all ON public.contato_tipos AS PERMISSIVE FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: contato_tipos_select ON contato_tipos
CREATE POLICY contato_tipos_select ON public.contato_tipos AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: contato_tipos_write ON contato_tipos
CREATE POLICY contato_tipos_write ON public.contato_tipos AS PERMISSIVE FOR ALL TO service_role
  USING (true);
-- Policy: authenticated_all_contatos ON contatos
CREATE POLICY authenticated_all_contatos ON public.contatos AS PERMISSIVE FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: authenticated_delete ON contatos
CREATE POLICY authenticated_delete ON public.contatos AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: authenticated_delete_contatos ON contatos
CREATE POLICY authenticated_delete_contatos ON public.contatos AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: authenticated_insert ON contatos
CREATE POLICY authenticated_insert ON public.contatos AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: authenticated_insert_contatos ON contatos
CREATE POLICY authenticated_insert_contatos ON public.contatos AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: authenticated_select ON contatos
CREATE POLICY authenticated_select ON public.contatos AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: authenticated_select_contatos ON contatos
CREATE POLICY authenticated_select_contatos ON public.contatos AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: authenticated_select_contatos_financial ON contatos
CREATE POLICY authenticated_select_contatos_financial ON public.contatos AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: authenticated_update ON contatos
CREATE POLICY authenticated_update ON public.contatos AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true);
-- Policy: authenticated_update_contatos ON contatos
CREATE POLICY authenticated_update_contatos ON public.contatos AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: contatos_delete_admin ON contatos
CREATE POLICY contatos_delete_admin ON public.contatos AS PERMISSIVE FOR DELETE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: contatos_insert ON contatos
CREATE POLICY contatos_insert ON public.contatos AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
-- Policy: contatos_select ON contatos
CREATE POLICY contatos_select ON public.contatos AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: contatos_update ON contatos
CREATE POLICY contatos_update ON public.contatos AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
-- Policy: contatos_revisao_select ON contatos_revisao
CREATE POLICY contatos_revisao_select ON public.contatos_revisao AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: contatos_revisao_write ON contatos_revisao
CREATE POLICY contatos_revisao_write ON public.contatos_revisao AS PERMISSIVE FOR ALL TO service_role
  USING (true);
-- Policy: controle_falta_delete ON controle_falta
CREATE POLICY controle_falta_delete ON public.controle_falta AS PERMISSIVE FOR DELETE TO authenticated
  USING ((get_user_role() = ANY (ARRAY['admin'::text, 'gerente'::text])));
-- Policy: controle_falta_insert ON controle_falta
CREATE POLICY controle_falta_insert ON public.controle_falta AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (((get_user_role() = ANY (ARRAY['admin'::text, 'gerente'::text])) OR (funcionario_id = get_my_funcionario_id())));
-- Policy: controle_falta_select ON controle_falta
CREATE POLICY controle_falta_select ON public.controle_falta AS PERMISSIVE FOR SELECT TO authenticated
  USING (((get_user_role() = ANY (ARRAY['admin'::text, 'gerente'::text])) OR (funcionario_id = get_my_funcionario_id())));
-- Policy: controle_falta_update ON controle_falta
CREATE POLICY controle_falta_update ON public.controle_falta AS PERMISSIVE FOR UPDATE TO authenticated
  USING (((get_user_role() = ANY (ARRAY['admin'::text, 'gerente'::text])) OR (funcionario_id = get_my_funcionario_id())));
-- Policy: custos_rec_delete ON custos_recorrentes
CREATE POLICY custos_rec_delete ON public.custos_recorrentes AS PERMISSIVE FOR DELETE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: custos_rec_insert ON custos_recorrentes
CREATE POLICY custos_rec_insert ON public.custos_recorrentes AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: custos_rec_select ON custos_recorrentes
CREATE POLICY custos_rec_select ON public.custos_recorrentes AS PERMISSIVE FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
-- Policy: custos_rec_update ON custos_recorrentes
CREATE POLICY custos_rec_update ON public.custos_recorrentes AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: lanc_delete ON custos_recorrentes_lancamentos
CREATE POLICY lanc_delete ON public.custos_recorrentes_lancamentos AS PERMISSIVE FOR DELETE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: lanc_insert ON custos_recorrentes_lancamentos
CREATE POLICY lanc_insert ON public.custos_recorrentes_lancamentos AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: lanc_select ON custos_recorrentes_lancamentos
CREATE POLICY lanc_select ON public.custos_recorrentes_lancamentos AS PERMISSIVE FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
-- Policy: lanc_update ON custos_recorrentes_lancamentos
CREATE POLICY lanc_update ON public.custos_recorrentes_lancamentos AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: departamentos_select_all ON departamentos
CREATE POLICY departamentos_select_all ON public.departamentos AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: authenticated_select_devolucoes_estoque ON devolucoes_estoque
CREATE POLICY authenticated_select_devolucoes_estoque ON public.devolucoes_estoque AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: empresa_ubiqua_insert ON empresa_ubiqua
CREATE POLICY empresa_ubiqua_insert ON public.empresa_ubiqua AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: empresa_ubiqua_select ON empresa_ubiqua
CREATE POLICY empresa_ubiqua_select ON public.empresa_ubiqua AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: empresa_ubiqua_update ON empresa_ubiqua
CREATE POLICY empresa_ubiqua_update ON public.empresa_ubiqua AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((id IN ( SELECT usuarios_ubiqua.empresa_id
   FROM usuarios_ubiqua
  WHERE (usuarios_ubiqua.id = auth.uid()))))
  WITH CHECK ((id IN ( SELECT usuarios_ubiqua.empresa_id
   FROM usuarios_ubiqua
  WHERE (usuarios_ubiqua.id = auth.uid()))));
-- Policy: anon_select_empresas ON empresas
CREATE POLICY anon_select_empresas ON public.empresas AS PERMISSIVE FOR SELECT TO anon, authenticated
  USING (true);
-- Policy: authenticated_select_empresas ON empresas
CREATE POLICY authenticated_select_empresas ON public.empresas AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: empresas_delete_auth ON empresas
CREATE POLICY empresas_delete_auth ON public.empresas AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: empresas_insert ON empresas
CREATE POLICY empresas_insert ON public.empresas AS PERMISSIVE FOR INSERT TO service_role
  WITH CHECK (true);
-- Policy: empresas_insert_auth ON empresas
CREATE POLICY empresas_insert_auth ON public.empresas AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: empresas_select ON empresas
CREATE POLICY empresas_select ON public.empresas AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: empresas_update ON empresas
CREATE POLICY empresas_update ON public.empresas AS PERMISSIVE FOR UPDATE TO service_role
  USING (true);
-- Policy: empresas_update_auth ON empresas
CREATE POLICY empresas_update_auth ON public.empresas AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true);
-- Policy: entregas_delete_admin ON entregas
CREATE POLICY entregas_delete_admin ON public.entregas AS PERMISSIVE FOR DELETE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: entregas_insert ON entregas
CREATE POLICY entregas_insert ON public.entregas AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
-- Policy: entregas_select ON entregas
CREATE POLICY entregas_select ON public.entregas AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: entregas_update ON entregas
CREATE POLICY entregas_update ON public.entregas AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
-- Policy: ent_fin_delete_auth ON entregas_finalizadas
CREATE POLICY ent_fin_delete_auth ON public.entregas_finalizadas AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: ent_fin_insert_auth ON entregas_finalizadas
CREATE POLICY ent_fin_insert_auth ON public.entregas_finalizadas AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: ent_fin_select_auth ON entregas_finalizadas
CREATE POLICY ent_fin_select_auth ON public.entregas_finalizadas AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: ent_fin_update_auth ON entregas_finalizadas
CREATE POLICY ent_fin_update_auth ON public.entregas_finalizadas AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: entregas_finalizadas_authenticated_all ON entregas_finalizadas
CREATE POLICY entregas_finalizadas_authenticated_all ON public.entregas_finalizadas AS PERMISSIVE FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: entregas_finalizadas_delete ON entregas_finalizadas
CREATE POLICY entregas_finalizadas_delete ON public.entregas_finalizadas AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: entregas_finalizadas_insert ON entregas_finalizadas
CREATE POLICY entregas_finalizadas_insert ON public.entregas_finalizadas AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: entregas_finalizadas_select ON entregas_finalizadas
CREATE POLICY entregas_finalizadas_select ON public.entregas_finalizadas AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: entregas_finalizadas_update ON entregas_finalizadas
CREATE POLICY entregas_finalizadas_update ON public.entregas_finalizadas AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: authenticated_delete_estoque_itens ON estoque_itens
CREATE POLICY authenticated_delete_estoque_itens ON public.estoque_itens AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: authenticated_insert_estoque_itens ON estoque_itens
CREATE POLICY authenticated_insert_estoque_itens ON public.estoque_itens AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: authenticated_select_estoque_itens ON estoque_itens
CREATE POLICY authenticated_select_estoque_itens ON public.estoque_itens AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: authenticated_update_estoque_itens ON estoque_itens
CREATE POLICY authenticated_update_estoque_itens ON public.estoque_itens AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: estoque_delete ON estoque_itens
CREATE POLICY estoque_delete ON public.estoque_itens AS PERMISSIVE FOR DELETE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
-- Policy: estoque_insert ON estoque_itens
CREATE POLICY estoque_insert ON public.estoque_itens AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
-- Policy: estoque_select ON estoque_itens
CREATE POLICY estoque_select ON public.estoque_itens AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: estoque_update ON estoque_itens
CREATE POLICY estoque_update ON public.estoque_itens AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
-- Policy: authenticated_select_estoque_movimentos_projeto_item ON estoque_movimentos_projeto_item
CREATE POLICY authenticated_select_estoque_movimentos_projeto_item ON public.estoque_movimentos_projeto_item AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: authenticated_select_estoque_saldos_projeto_item ON estoque_saldos_projeto_item
CREATE POLICY authenticated_select_estoque_saldos_projeto_item ON public.estoque_saldos_projeto_item AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: ferias_delete ON ferias
CREATE POLICY ferias_delete ON public.ferias AS PERMISSIVE FOR DELETE TO authenticated
  USING ((get_user_role() = ANY (ARRAY['admin'::text, 'gerente'::text])));
-- Policy: ferias_insert ON ferias
CREATE POLICY ferias_insert ON public.ferias AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (((get_user_role() = ANY (ARRAY['admin'::text, 'gerente'::text])) OR (funcionario_id = get_my_funcionario_id())));
-- Policy: ferias_select ON ferias
CREATE POLICY ferias_select ON public.ferias AS PERMISSIVE FOR SELECT TO authenticated
  USING (((get_user_role() = ANY (ARRAY['admin'::text, 'gerente'::text])) OR (funcionario_id = get_my_funcionario_id())));
-- Policy: ferias_update ON ferias
CREATE POLICY ferias_update ON public.ferias AS PERMISSIVE FOR UPDATE TO authenticated
  USING (((get_user_role() = ANY (ARRAY['admin'::text, 'gerente'::text])) OR (funcionario_id = get_my_funcionario_id())));
-- Policy: folha_delete ON folha_pagamento
CREATE POLICY folha_delete ON public.folha_pagamento AS PERMISSIVE FOR DELETE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: folha_insert ON folha_pagamento
CREATE POLICY folha_insert ON public.folha_pagamento AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: folha_own ON folha_pagamento
CREATE POLICY folha_own ON public.folha_pagamento AS PERMISSIVE FOR SELECT TO authenticated
  USING (((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))) OR (funcionario_id IN ( SELECT funcionarios.id
   FROM funcionarios
  WHERE (funcionarios.usuario_id = ( SELECT auth.uid() AS uid))))));
-- Policy: folha_update ON folha_pagamento
CREATE POLICY folha_update ON public.folha_pagamento AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: fornecedores_delete_policy ON fornecedores
CREATE POLICY fornecedores_delete_policy ON public.fornecedores AS PERMISSIVE FOR DELETE TO public
  USING (true);
-- Policy: fornecedores_insert_policy ON fornecedores
CREATE POLICY fornecedores_insert_policy ON public.fornecedores AS PERMISSIVE FOR INSERT TO public
  WITH CHECK ((auth.uid() IS NOT NULL));
-- Policy: fornecedores_select_policy ON fornecedores
CREATE POLICY fornecedores_select_policy ON public.fornecedores AS PERMISSIVE FOR SELECT TO public
  USING (true);
-- Policy: fornecedores_update_policy ON fornecedores
CREATE POLICY fornecedores_update_policy ON public.fornecedores AS PERMISSIVE FOR UPDATE TO public
  USING (true)
  WITH CHECK ((auth.uid() IS NOT NULL));
-- Policy: authenticated_select_funcionarios ON funcionarios
CREATE POLICY authenticated_select_funcionarios ON public.funcionarios AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: func_delete_admin ON funcionarios
CREATE POLICY func_delete_admin ON public.funcionarios AS PERMISSIVE FOR DELETE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: func_insert_admin ON funcionarios
CREATE POLICY func_insert_admin ON public.funcionarios AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: func_select_admin ON funcionarios
CREATE POLICY func_select_admin ON public.funcionarios AS PERMISSIVE FOR SELECT TO authenticated
  USING (((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))) OR (usuario_id = ( SELECT auth.uid() AS uid))));
-- Policy: func_update_admin ON funcionarios
CREATE POLICY func_update_admin ON public.funcionarios AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: fn_ben_delete_auth ON funcionarios_beneficios_empresas
CREATE POLICY fn_ben_delete_auth ON public.funcionarios_beneficios_empresas AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: fn_ben_insert_auth ON funcionarios_beneficios_empresas
CREATE POLICY fn_ben_insert_auth ON public.funcionarios_beneficios_empresas AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: fn_ben_select_auth ON funcionarios_beneficios_empresas
CREATE POLICY fn_ben_select_auth ON public.funcionarios_beneficios_empresas AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: fn_ben_update_auth ON funcionarios_beneficios_empresas
CREATE POLICY fn_ben_update_auth ON public.funcionarios_beneficios_empresas AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: funcionarios_beneficios_empresas_authenticated_all ON funcionarios_beneficios_empresas
CREATE POLICY funcionarios_beneficios_empresas_authenticated_all ON public.funcionarios_beneficios_empresas AS PERMISSIVE FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: fn_det_delete_auth ON funcionarios_detalhes
CREATE POLICY fn_det_delete_auth ON public.funcionarios_detalhes AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: fn_det_insert_auth ON funcionarios_detalhes
CREATE POLICY fn_det_insert_auth ON public.funcionarios_detalhes AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: fn_det_select_auth ON funcionarios_detalhes
CREATE POLICY fn_det_select_auth ON public.funcionarios_detalhes AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: fn_det_update_auth ON funcionarios_detalhes
CREATE POLICY fn_det_update_auth ON public.funcionarios_detalhes AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: funcionarios_detalhes_authenticated_all ON funcionarios_detalhes
CREATE POLICY funcionarios_detalhes_authenticated_all ON public.funcionarios_detalhes AS PERMISSIVE FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: fn_fin_delete_auth ON funcionarios_financeiro
CREATE POLICY fn_fin_delete_auth ON public.funcionarios_financeiro AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: fn_fin_insert_auth ON funcionarios_financeiro
CREATE POLICY fn_fin_insert_auth ON public.funcionarios_financeiro AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: fn_fin_select_auth ON funcionarios_financeiro
CREATE POLICY fn_fin_select_auth ON public.funcionarios_financeiro AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: fn_fin_update_auth ON funcionarios_financeiro
CREATE POLICY fn_fin_update_auth ON public.funcionarios_financeiro AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: funcionarios_financeiro_authenticated_all ON funcionarios_financeiro
CREATE POLICY funcionarios_financeiro_authenticated_all ON public.funcionarios_financeiro AS PERMISSIVE FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: fn_novo_delete_auth ON funcionarios_novo
CREATE POLICY fn_novo_delete_auth ON public.funcionarios_novo AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: fn_novo_insert_auth ON funcionarios_novo
CREATE POLICY fn_novo_insert_auth ON public.funcionarios_novo AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: fn_novo_select_auth ON funcionarios_novo
CREATE POLICY fn_novo_select_auth ON public.funcionarios_novo AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: fn_novo_update_auth ON funcionarios_novo
CREATE POLICY fn_novo_update_auth ON public.funcionarios_novo AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: funcionarios_novo_authenticated_all ON funcionarios_novo
CREATE POLICY funcionarios_novo_authenticated_all ON public.funcionarios_novo AS PERMISSIVE FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: authenticated_insert_historico_status_orcamentos ON historico_status_orcamentos
CREATE POLICY authenticated_insert_historico_status_orcamentos ON public.historico_status_orcamentos AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: authenticated_select_historico_status_orcamentos ON historico_status_orcamentos
CREATE POLICY authenticated_select_historico_status_orcamentos ON public.historico_status_orcamentos AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: authenticated_update_historico_status_orcamentos ON historico_status_orcamentos
CREATE POLICY authenticated_update_historico_status_orcamentos ON public.historico_status_orcamentos AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: Permitir leitura admin_gerente ON informacoes_cliente_ubiqua
CREATE POLICY "Permitir leitura admin_gerente" ON public.informacoes_cliente_ubiqua AS PERMISSIVE FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: Permitir leitura anon e auth ON informacoes_cliente_ubiqua
CREATE POLICY "Permitir leitura anon e auth" ON public.informacoes_cliente_ubiqua AS PERMISSIVE FOR SELECT TO anon, authenticated
  USING (true);
-- Policy: all_select_informacoes_cliente ON informacoes_cliente_ubiqua
CREATE POLICY all_select_informacoes_cliente ON public.informacoes_cliente_ubiqua AS PERMISSIVE FOR SELECT TO anon, authenticated
  USING (true);
-- Policy: anon_insert_informacoes_cliente ON informacoes_cliente_ubiqua
CREATE POLICY anon_insert_informacoes_cliente ON public.informacoes_cliente_ubiqua AS PERMISSIVE FOR INSERT TO anon
  WITH CHECK (true);
-- Policy: anon_update_informacoes_cliente ON informacoes_cliente_ubiqua
CREATE POLICY anon_update_informacoes_cliente ON public.informacoes_cliente_ubiqua AS PERMISSIVE FOR UPDATE TO anon
  USING (true)
  WITH CHECK (true);
-- Policy: auth_insert_informacoes_cliente ON informacoes_cliente_ubiqua
CREATE POLICY auth_insert_informacoes_cliente ON public.informacoes_cliente_ubiqua AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: auth_update_informacoes_cliente ON informacoes_cliente_ubiqua
CREATE POLICY auth_update_informacoes_cliente ON public.informacoes_cliente_ubiqua AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: all_select_itens_orcamento_ubiqua ON itens_orcamento_ubiqua
CREATE POLICY all_select_itens_orcamento_ubiqua ON public.itens_orcamento_ubiqua AS PERMISSIVE FOR SELECT TO public
  USING (true);
-- Policy: anon_insert_itens_orcamento_ubiqua ON itens_orcamento_ubiqua
CREATE POLICY anon_insert_itens_orcamento_ubiqua ON public.itens_orcamento_ubiqua AS PERMISSIVE FOR INSERT TO anon
  WITH CHECK (true);
-- Policy: auth_insert_itens_orcamento_ubiqua ON itens_orcamento_ubiqua
CREATE POLICY auth_insert_itens_orcamento_ubiqua ON public.itens_orcamento_ubiqua AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: authenticated_all_itens_orcamento_ubiqua ON itens_orcamento_ubiqua
CREATE POLICY authenticated_all_itens_orcamento_ubiqua ON public.itens_orcamento_ubiqua AS PERMISSIVE FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: admin_all_logs ON logs_auditoria
CREATE POLICY admin_all_logs ON public.logs_auditoria AS PERMISSIVE FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());
-- Policy: authenticated_insert_logs_auditoria ON logs_auditoria
CREATE POLICY authenticated_insert_logs_auditoria ON public.logs_auditoria AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: authenticated_select_logs_auditoria ON logs_auditoria
CREATE POLICY authenticated_select_logs_auditoria ON public.logs_auditoria AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: logs_auditoria_delete_policy ON logs_auditoria
CREATE POLICY logs_auditoria_delete_policy ON public.logs_auditoria AS PERMISSIVE FOR DELETE TO public
  USING (false);
-- Policy: logs_auditoria_insert_policy ON logs_auditoria
CREATE POLICY logs_auditoria_insert_policy ON public.logs_auditoria AS PERMISSIVE FOR INSERT TO public
  WITH CHECK (false);
-- Policy: logs_auditoria_select_policy ON logs_auditoria
CREATE POLICY logs_auditoria_select_policy ON public.logs_auditoria AS PERMISSIVE FOR SELECT TO public
  USING (true);
-- Policy: logs_auditoria_update_policy ON logs_auditoria
CREATE POLICY logs_auditoria_update_policy ON public.logs_auditoria AS PERMISSIVE FOR UPDATE TO public
  USING (false);
-- Policy: user_insert_logs ON logs_auditoria
CREATE POLICY user_insert_logs ON public.logs_auditoria AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((usuario_id = auth.uid()));
-- Policy: authenticated_select_marcas ON marcas
CREATE POLICY authenticated_select_marcas ON public.marcas AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: marcas_delete ON marcas
CREATE POLICY marcas_delete ON public.marcas AS PERMISSIVE FOR DELETE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: marcas_insert ON marcas
CREATE POLICY marcas_insert ON public.marcas AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: marcas_select ON marcas
CREATE POLICY marcas_select ON public.marcas AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: marcas_update ON marcas
CREATE POLICY marcas_update ON public.marcas AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: admin_all_modulo_acoes ON modulo_acoes
CREATE POLICY admin_all_modulo_acoes ON public.modulo_acoes AS PERMISSIVE FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());
-- Policy: admin_all_modulos ON modulos
CREATE POLICY admin_all_modulos ON public.modulos AS PERMISSIVE FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());
-- Policy: negociacoes_select ON negociacoes
CREATE POLICY negociacoes_select ON public.negociacoes AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: negociacoes_write ON negociacoes
CREATE POLICY negociacoes_write ON public.negociacoes AS PERMISSIVE FOR ALL TO service_role
  USING (true);
-- Policy: authenticated_all_notas_fiscais ON notas_fiscais
CREATE POLICY authenticated_all_notas_fiscais ON public.notas_fiscais AS PERMISSIVE FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: authenticated_delete_nf ON notas_fiscais
CREATE POLICY authenticated_delete_nf ON public.notas_fiscais AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: authenticated_insert_nf ON notas_fiscais
CREATE POLICY authenticated_insert_nf ON public.notas_fiscais AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: authenticated_select_nf ON notas_fiscais
CREATE POLICY authenticated_select_nf ON public.notas_fiscais AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: authenticated_update_nf ON notas_fiscais
CREATE POLICY authenticated_update_nf ON public.notas_fiscais AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: anon_insert_orcamento_itens ON orcamento_itens
CREATE POLICY anon_insert_orcamento_itens ON public.orcamento_itens AS PERMISSIVE FOR INSERT TO anon, authenticated
  WITH CHECK (true);
-- Policy: authenticated_delete_orcamento_itens ON orcamento_itens
CREATE POLICY authenticated_delete_orcamento_itens ON public.orcamento_itens AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: authenticated_insert_orcamento_itens ON orcamento_itens
CREATE POLICY authenticated_insert_orcamento_itens ON public.orcamento_itens AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: authenticated_select_orcamento_itens ON orcamento_itens
CREATE POLICY authenticated_select_orcamento_itens ON public.orcamento_itens AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: authenticated_select_orcamento_itens_financial ON orcamento_itens
CREATE POLICY authenticated_select_orcamento_itens_financial ON public.orcamento_itens AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: authenticated_update_orcamento_itens ON orcamento_itens
CREATE POLICY authenticated_update_orcamento_itens ON public.orcamento_itens AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: orcamento_itens_delete ON orcamento_itens
CREATE POLICY orcamento_itens_delete ON public.orcamento_itens AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: orcamento_itens_insert ON orcamento_itens
CREATE POLICY orcamento_itens_insert ON public.orcamento_itens AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: orcamento_itens_select ON orcamento_itens
CREATE POLICY orcamento_itens_select ON public.orcamento_itens AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: orcamento_itens_update ON orcamento_itens
CREATE POLICY orcamento_itens_update ON public.orcamento_itens AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: anon_can_read_orcamento_by_token ON orcamentos
CREATE POLICY anon_can_read_orcamento_by_token ON public.orcamentos AS PERMISSIVE FOR SELECT TO anon, authenticated
  USING ((token_aprovacao_cliente IS NOT NULL));
-- Policy: anon_insert_orcamentos ON orcamentos
CREATE POLICY anon_insert_orcamentos ON public.orcamentos AS PERMISSIVE FOR INSERT TO anon, authenticated
  WITH CHECK (true);
-- Policy: authenticated_delete_orcamentos ON orcamentos
CREATE POLICY authenticated_delete_orcamentos ON public.orcamentos AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: authenticated_insert_orcamentos ON orcamentos
CREATE POLICY authenticated_insert_orcamentos ON public.orcamentos AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: authenticated_insert_orcamentos_approval ON orcamentos
CREATE POLICY authenticated_insert_orcamentos_approval ON public.orcamentos AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: authenticated_select_orcamentos ON orcamentos
CREATE POLICY authenticated_select_orcamentos ON public.orcamentos AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: authenticated_select_orcamentos_approval ON orcamentos
CREATE POLICY authenticated_select_orcamentos_approval ON public.orcamentos AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: authenticated_select_orcamentos_financial ON orcamentos
CREATE POLICY authenticated_select_orcamentos_financial ON public.orcamentos AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: authenticated_update_orcamentos ON orcamentos
CREATE POLICY authenticated_update_orcamentos ON public.orcamentos AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: authenticated_update_orcamentos_approval ON orcamentos
CREATE POLICY authenticated_update_orcamentos_approval ON public.orcamentos AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: orcamentos_delete ON orcamentos
CREATE POLICY orcamentos_delete ON public.orcamentos AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: orcamentos_insert ON orcamentos
CREATE POLICY orcamentos_insert ON public.orcamentos AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: orcamentos_select ON orcamentos
CREATE POLICY orcamentos_select ON public.orcamentos AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: orcamentos_update ON orcamentos
CREATE POLICY orcamentos_update ON public.orcamentos AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true);
-- Policy: all_select_orcamentos_revenda_ubiqua ON orcamentos_revenda_ubiqua
CREATE POLICY all_select_orcamentos_revenda_ubiqua ON public.orcamentos_revenda_ubiqua AS PERMISSIVE FOR SELECT TO public
  USING (true);
-- Policy: anon_insert_orcamentos_revenda_ubiqua ON orcamentos_revenda_ubiqua
CREATE POLICY anon_insert_orcamentos_revenda_ubiqua ON public.orcamentos_revenda_ubiqua AS PERMISSIVE FOR INSERT TO anon
  WITH CHECK (true);
-- Policy: auth_insert_orcamentos_revenda_ubiqua ON orcamentos_revenda_ubiqua
CREATE POLICY auth_insert_orcamentos_revenda_ubiqua ON public.orcamentos_revenda_ubiqua AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: authenticated_all_orcamentos_revenda_ubiqua ON orcamentos_revenda_ubiqua
CREATE POLICY authenticated_all_orcamentos_revenda_ubiqua ON public.orcamentos_revenda_ubiqua AS PERMISSIVE FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: authenticated_update_orcamentos_revenda_ubiqua ON orcamentos_revenda_ubiqua
CREATE POLICY authenticated_update_orcamentos_revenda_ubiqua ON public.orcamentos_revenda_ubiqua AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: update_orcamentos_revenda_ubiqua ON orcamentos_revenda_ubiqua
CREATE POLICY update_orcamentos_revenda_ubiqua ON public.orcamentos_revenda_ubiqua AS PERMISSIVE FOR UPDATE TO anon, authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: admin_all_papeis ON papeis
CREATE POLICY admin_all_papeis ON public.papeis AS PERMISSIVE FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());
-- Policy: admin_all_papel_permissoes ON papel_permissoes
CREATE POLICY admin_all_papel_permissoes ON public.papel_permissoes AS PERMISSIVE FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());
-- Policy: Permitir leitura para autenticados ON pedido_compra
CREATE POLICY "Permitir leitura para autenticados" ON public.pedido_compra AS PERMISSIVE FOR SELECT TO public
  USING ((auth.role() = 'authenticated'::text));
-- Policy: Permitir tudo para service_role ON pedido_compra
CREATE POLICY "Permitir tudo para service_role" ON public.pedido_compra AS PERMISSIVE FOR ALL TO public
  USING ((auth.role() = 'service_role'::text));
-- Policy: periodos_aquis_delete ON periodos_aquisitivos
CREATE POLICY periodos_aquis_delete ON public.periodos_aquisitivos AS PERMISSIVE FOR DELETE TO authenticated
  USING ((get_user_role() = ANY (ARRAY['admin'::text, 'gerente'::text])));
-- Policy: periodos_aquis_insert ON periodos_aquisitivos
CREATE POLICY periodos_aquis_insert ON public.periodos_aquisitivos AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((get_user_role() = ANY (ARRAY['admin'::text, 'gerente'::text])));
-- Policy: periodos_aquis_select ON periodos_aquisitivos
CREATE POLICY periodos_aquis_select ON public.periodos_aquisitivos AS PERMISSIVE FOR SELECT TO authenticated
  USING (((get_user_role() = ANY (ARRAY['admin'::text, 'gerente'::text])) OR (funcionario_id = get_my_funcionario_id())));
-- Policy: periodos_aquis_update ON periodos_aquisitivos
CREATE POLICY periodos_aquis_update ON public.periodos_aquisitivos AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((get_user_role() = ANY (ARRAY['admin'::text, 'gerente'::text])));
-- Policy: plano_contas_select ON plano_de_contas
CREATE POLICY plano_contas_select ON public.plano_de_contas AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: plano_contas_write ON plano_de_contas
CREATE POLICY plano_contas_write ON public.plano_de_contas AS PERMISSIVE FOR ALL TO service_role
  USING (true);
-- Policy: Permitir leitura para autenticados ON produtos
CREATE POLICY "Permitir leitura para autenticados" ON public.produtos AS PERMISSIVE FOR SELECT TO public
  USING ((auth.role() = 'authenticated'::text));
-- Policy: Permitir tudo para service_role ON produtos
CREATE POLICY "Permitir tudo para service_role" ON public.produtos AS PERMISSIVE FOR ALL TO public
  USING ((auth.role() = 'service_role'::text));
-- Policy: authenticated_delete_produtos ON produtos
CREATE POLICY authenticated_delete_produtos ON public.produtos AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: authenticated_insert_produtos ON produtos
CREATE POLICY authenticated_insert_produtos ON public.produtos AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: authenticated_select_produtos ON produtos
CREATE POLICY authenticated_select_produtos ON public.produtos AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: authenticated_update_produtos ON produtos
CREATE POLICY authenticated_update_produtos ON public.produtos AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: prod_delete ON produtos
CREATE POLICY prod_delete ON public.produtos AS PERMISSIVE FOR DELETE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: prod_insert ON produtos
CREATE POLICY prod_insert ON public.produtos AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: prod_select ON produtos
CREATE POLICY prod_select ON public.produtos AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: prod_update ON produtos
CREATE POLICY prod_update ON public.produtos AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: pi_delete_admin ON projeto_itens
CREATE POLICY pi_delete_admin ON public.projeto_itens AS PERMISSIVE FOR DELETE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: pi_insert ON projeto_itens
CREATE POLICY pi_insert ON public.projeto_itens AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
-- Policy: pi_select ON projeto_itens
CREATE POLICY pi_select ON public.projeto_itens AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: pi_update ON projeto_itens
CREATE POLICY pi_update ON public.projeto_itens AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
-- Policy: Permitir leitura para autenticados ON projeto_parcelas
CREATE POLICY "Permitir leitura para autenticados" ON public.projeto_parcelas AS PERMISSIVE FOR SELECT TO public
  USING ((auth.role() = 'authenticated'::text));
-- Policy: Permitir tudo para service_role ON projeto_parcelas
CREATE POLICY "Permitir tudo para service_role" ON public.projeto_parcelas AS PERMISSIVE FOR ALL TO public
  USING ((auth.role() = 'service_role'::text));
-- Policy: authenticated_all_projeto_parcelas ON projeto_parcelas
CREATE POLICY authenticated_all_projeto_parcelas ON public.projeto_parcelas AS PERMISSIVE FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: authenticated_insert_projeto_parcelas ON projeto_parcelas
CREATE POLICY authenticated_insert_projeto_parcelas ON public.projeto_parcelas AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: authenticated_select_projeto_parcelas ON projeto_parcelas
CREATE POLICY authenticated_select_projeto_parcelas ON public.projeto_parcelas AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: authenticated_update_projeto_parcelas ON projeto_parcelas
CREATE POLICY authenticated_update_projeto_parcelas ON public.projeto_parcelas AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: parcelas_delete_admin ON projeto_parcelas
CREATE POLICY parcelas_delete_admin ON public.projeto_parcelas AS PERMISSIVE FOR DELETE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: parcelas_insert ON projeto_parcelas
CREATE POLICY parcelas_insert ON public.projeto_parcelas AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
-- Policy: parcelas_select ON projeto_parcelas
CREATE POLICY parcelas_select ON public.projeto_parcelas AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: parcelas_update ON projeto_parcelas
CREATE POLICY parcelas_update ON public.projeto_parcelas AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
-- Policy: authenticated_all ON projeto_parcelas_backup_migration
CREATE POLICY authenticated_all ON public.projeto_parcelas_backup_migration AS PERMISSIVE FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: Permitir leitura para autenticados ON projeto_produtos
CREATE POLICY "Permitir leitura para autenticados" ON public.projeto_produtos AS PERMISSIVE FOR SELECT TO public
  USING ((auth.role() = 'authenticated'::text));
-- Policy: Permitir tudo para service_role ON projeto_produtos
CREATE POLICY "Permitir tudo para service_role" ON public.projeto_produtos AS PERMISSIVE FOR ALL TO public
  USING ((auth.role() = 'service_role'::text));
-- Policy: sinal_delete_admin ON projeto_sinal
CREATE POLICY sinal_delete_admin ON public.projeto_sinal AS PERMISSIVE FOR DELETE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: sinal_insert ON projeto_sinal
CREATE POLICY sinal_insert ON public.projeto_sinal AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
-- Policy: sinal_select ON projeto_sinal
CREATE POLICY sinal_select ON public.projeto_sinal AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: sinal_update ON projeto_sinal
CREATE POLICY sinal_update ON public.projeto_sinal AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
-- Policy: Permitir leitura para autenticados ON projetos
CREATE POLICY "Permitir leitura para autenticados" ON public.projetos AS PERMISSIVE FOR SELECT TO public
  USING ((auth.role() = 'authenticated'::text));
-- Policy: Permitir tudo para service_role ON projetos
CREATE POLICY "Permitir tudo para service_role" ON public.projetos AS PERMISSIVE FOR ALL TO public
  USING ((auth.role() = 'service_role'::text));
-- Policy: authenticated_all_projetos ON projetos
CREATE POLICY authenticated_all_projetos ON public.projetos AS PERMISSIVE FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: authenticated_delete_projetos ON projetos
CREATE POLICY authenticated_delete_projetos ON public.projetos AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: authenticated_delete_projetos_v2 ON projetos
CREATE POLICY authenticated_delete_projetos_v2 ON public.projetos AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: authenticated_insert_projetos ON projetos
CREATE POLICY authenticated_insert_projetos ON public.projetos AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: authenticated_insert_projetos_v2 ON projetos
CREATE POLICY authenticated_insert_projetos_v2 ON public.projetos AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: authenticated_select_projetos ON projetos
CREATE POLICY authenticated_select_projetos ON public.projetos AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: authenticated_select_projetos_financial ON projetos
CREATE POLICY authenticated_select_projetos_financial ON public.projetos AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: authenticated_select_projetos_v2 ON projetos
CREATE POLICY authenticated_select_projetos_v2 ON public.projetos AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: authenticated_update_projetos ON projetos
CREATE POLICY authenticated_update_projetos ON public.projetos AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: authenticated_update_projetos_v2 ON projetos
CREATE POLICY authenticated_update_projetos_v2 ON public.projetos AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: projetos_delete_admin ON projetos
CREATE POLICY projetos_delete_admin ON public.projetos AS PERMISSIVE FOR DELETE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: projetos_insert ON projetos
CREATE POLICY projetos_insert ON public.projetos AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
-- Policy: projetos_select ON projetos
CREATE POLICY projetos_select ON public.projetos AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: projetos_update ON projetos
CREATE POLICY projetos_update ON public.projetos AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
-- Policy: projetos_fechados_delete ON projetos_fechados
CREATE POLICY projetos_fechados_delete ON public.projetos_fechados AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: projetos_fechados_insert ON projetos_fechados
CREATE POLICY projetos_fechados_insert ON public.projetos_fechados AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: projetos_fechados_select ON projetos_fechados
CREATE POLICY projetos_fechados_select ON public.projetos_fechados AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: projetos_fechados_update ON projetos_fechados
CREATE POLICY projetos_fechados_update ON public.projetos_fechados AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: all_quote_history_auth ON quote_history
CREATE POLICY all_quote_history_auth ON public.quote_history AS PERMISSIVE FOR ALL TO public
  USING (true);
-- Policy: all_quotes_auth ON quotes
CREATE POLICY all_quotes_auth ON public.quotes AS PERMISSIVE FOR ALL TO public
  USING (true)
  WITH CHECK (true);
-- Policy: remessas_delete_policy ON remessas
CREATE POLICY remessas_delete_policy ON public.remessas AS PERMISSIVE FOR DELETE TO public
  USING (true);
-- Policy: remessas_insert_policy ON remessas
CREATE POLICY remessas_insert_policy ON public.remessas AS PERMISSIVE FOR INSERT TO public
  WITH CHECK ((auth.uid() IS NOT NULL));
-- Policy: remessas_select_policy ON remessas
CREATE POLICY remessas_select_policy ON public.remessas AS PERMISSIVE FOR SELECT TO public
  USING (true);
-- Policy: remessas_update_policy ON remessas
CREATE POLICY remessas_update_policy ON public.remessas AS PERMISSIVE FOR UPDATE TO public
  USING (true)
  WITH CHECK ((auth.uid() IS NOT NULL));
-- Policy: authenticated_select_retorno_bancario_arquivos ON retorno_bancario_arquivos
CREATE POLICY authenticated_select_retorno_bancario_arquivos ON public.retorno_bancario_arquivos AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: authenticated_select_retorno_bancario_registros ON retorno_bancario_registros
CREATE POLICY authenticated_select_retorno_bancario_registros ON public.retorno_bancario_registros AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: authenticated_all_retornos ON retornos_processados
CREATE POLICY authenticated_all_retornos ON public.retornos_processados AS PERMISSIVE FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: authenticated_delete_retornos ON retornos_processados
CREATE POLICY authenticated_delete_retornos ON public.retornos_processados AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: authenticated_insert_retornos ON retornos_processados
CREATE POLICY authenticated_insert_retornos ON public.retornos_processados AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: authenticated_select_retornos ON retornos_processados
CREATE POLICY authenticated_select_retornos ON public.retornos_processados AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: authenticated_update_retornos ON retornos_processados
CREATE POLICY authenticated_update_retornos ON public.retornos_processados AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: authenticated_select_revenda ON revenda_ubiqua
CREATE POLICY authenticated_select_revenda ON public.revenda_ubiqua AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: revenda_ubiqua_delete ON revenda_ubiqua
CREATE POLICY revenda_ubiqua_delete ON public.revenda_ubiqua AS PERMISSIVE FOR DELETE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: revenda_ubiqua_delete_admin_ubiqua ON revenda_ubiqua
CREATE POLICY revenda_ubiqua_delete_admin_ubiqua ON public.revenda_ubiqua AS PERMISSIVE FOR DELETE TO authenticated
  USING (((EXISTS ( SELECT 1
   FROM usuarios_ubiqua u
  WHERE ((u.id = auth.uid()) AND (u.nivel_acesso = 'admin'::nivel_acesso_tipo)))) OR (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role])))))));
-- Policy: revenda_ubiqua_insert ON revenda_ubiqua
CREATE POLICY revenda_ubiqua_insert ON public.revenda_ubiqua AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: revenda_ubiqua_select ON revenda_ubiqua
CREATE POLICY revenda_ubiqua_select ON public.revenda_ubiqua AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: revenda_ubiqua_select_anon ON revenda_ubiqua
CREATE POLICY revenda_ubiqua_select_anon ON public.revenda_ubiqua AS PERMISSIVE FOR SELECT TO anon
  USING (true);
-- Policy: revenda_ubiqua_update ON revenda_ubiqua
CREATE POLICY revenda_ubiqua_update ON public.revenda_ubiqua AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: sep_arq_delete_auth ON separacao_arquivos
CREATE POLICY sep_arq_delete_auth ON public.separacao_arquivos AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: sep_arq_insert_auth ON separacao_arquivos
CREATE POLICY sep_arq_insert_auth ON public.separacao_arquivos AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: sep_arq_select_auth ON separacao_arquivos
CREATE POLICY sep_arq_select_auth ON public.separacao_arquivos AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: sep_arq_update_auth ON separacao_arquivos
CREATE POLICY sep_arq_update_auth ON public.separacao_arquivos AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: separacao_arquivos_authenticated_all ON separacao_arquivos
CREATE POLICY separacao_arquivos_authenticated_all ON public.separacao_arquivos AS PERMISSIVE FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: separacao_arquivos_delete ON separacao_arquivos
CREATE POLICY separacao_arquivos_delete ON public.separacao_arquivos AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: separacao_arquivos_insert ON separacao_arquivos
CREATE POLICY separacao_arquivos_insert ON public.separacao_arquivos AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: separacao_arquivos_select ON separacao_arquivos
CREATE POLICY separacao_arquivos_select ON public.separacao_arquivos AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: separacao_arquivos_update ON separacao_arquivos
CREATE POLICY separacao_arquivos_update ON public.separacao_arquivos AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: sep_itens_delete ON separacao_itens
CREATE POLICY sep_itens_delete ON public.separacao_itens AS PERMISSIVE FOR DELETE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: sep_itens_insert ON separacao_itens
CREATE POLICY sep_itens_insert ON public.separacao_itens AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
-- Policy: sep_itens_select ON separacao_itens
CREATE POLICY sep_itens_select ON public.separacao_itens AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: sep_itens_update ON separacao_itens
CREATE POLICY sep_itens_update ON public.separacao_itens AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
-- Policy: sep_delete_auth ON separacoes
CREATE POLICY sep_delete_auth ON public.separacoes AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: sep_insert_auth ON separacoes
CREATE POLICY sep_insert_auth ON public.separacoes AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: sep_select_auth ON separacoes
CREATE POLICY sep_select_auth ON public.separacoes AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: sep_update_auth ON separacoes
CREATE POLICY sep_update_auth ON public.separacoes AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: separacoes_delete ON separacoes
CREATE POLICY separacoes_delete ON public.separacoes AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: separacoes_delete_admin ON separacoes
CREATE POLICY separacoes_delete_admin ON public.separacoes AS PERMISSIVE FOR DELETE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: separacoes_insert ON separacoes
CREATE POLICY separacoes_insert ON public.separacoes AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: separacoes_select ON separacoes
CREATE POLICY separacoes_select ON public.separacoes AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: separacoes_update ON separacoes
CREATE POLICY separacoes_update ON public.separacoes AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: separacoes_arquivos_authenticated_all ON separacoes_arquivos
CREATE POLICY separacoes_arquivos_authenticated_all ON public.separacoes_arquivos AS PERMISSIVE FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: separacoes_arquivos_delete ON separacoes_arquivos
CREATE POLICY separacoes_arquivos_delete ON public.separacoes_arquivos AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: separacoes_arquivos_insert ON separacoes_arquivos
CREATE POLICY separacoes_arquivos_insert ON public.separacoes_arquivos AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: separacoes_arquivos_select ON separacoes_arquivos
CREATE POLICY separacoes_arquivos_select ON public.separacoes_arquivos AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: separacoes_arquivos_update ON separacoes_arquivos
CREATE POLICY separacoes_arquivos_update ON public.separacoes_arquivos AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: authenticated_delete_solicitacoes_compra ON solicitacoes_compra
CREATE POLICY authenticated_delete_solicitacoes_compra ON public.solicitacoes_compra AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: authenticated_insert_solicitacoes_compra ON solicitacoes_compra
CREATE POLICY authenticated_insert_solicitacoes_compra ON public.solicitacoes_compra AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: authenticated_select_solicitacoes_compra ON solicitacoes_compra
CREATE POLICY authenticated_select_solicitacoes_compra ON public.solicitacoes_compra AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: authenticated_update_solicitacoes_compra ON solicitacoes_compra
CREATE POLICY authenticated_update_solicitacoes_compra ON public.solicitacoes_compra AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: sync_insert ON sync_history
CREATE POLICY sync_insert ON public.sync_history AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
-- Policy: sync_select ON sync_history
CREATE POLICY sync_select ON public.sync_history AS PERMISSIVE FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: admin_all_systems ON systems
CREATE POLICY admin_all_systems ON public.systems AS PERMISSIVE FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());
-- Policy: authenticated_select_systems ON systems
CREATE POLICY authenticated_select_systems ON public.systems AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: authenticated_all_transacoes ON transacoes
CREATE POLICY authenticated_all_transacoes ON public.transacoes AS PERMISSIVE FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: authenticated_delete_transacoes ON transacoes
CREATE POLICY authenticated_delete_transacoes ON public.transacoes AS PERMISSIVE FOR DELETE TO authenticated
  USING (true);
-- Policy: authenticated_insert_transacoes ON transacoes
CREATE POLICY authenticated_insert_transacoes ON public.transacoes AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: authenticated_select_transacoes ON transacoes
CREATE POLICY authenticated_select_transacoes ON public.transacoes AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: authenticated_update_transacoes ON transacoes
CREATE POLICY authenticated_update_transacoes ON public.transacoes AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: trans_delete_admin ON transacoes
CREATE POLICY trans_delete_admin ON public.transacoes AS PERMISSIVE FOR DELETE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = 'admin'::usuario_role)))));
-- Policy: trans_insert ON transacoes
CREATE POLICY trans_insert ON public.transacoes AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
-- Policy: trans_select ON transacoes
CREATE POLICY trans_select ON public.transacoes AS PERMISSIVE FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
-- Policy: trans_update_admin ON transacoes
CREATE POLICY trans_update_admin ON public.transacoes AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = 'admin'::usuario_role)))));
-- Policy: authenticated_select_transferencias_estoque ON transferencias_estoque
CREATE POLICY authenticated_select_transferencias_estoque ON public.transferencias_estoque AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: Permitir leitura para usuarios autenticados ON user_roles_separacao
CREATE POLICY "Permitir leitura para usuarios autenticados" ON public.user_roles_separacao AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: user_role_sep_insert_auth ON user_roles_separacao
CREATE POLICY user_role_sep_insert_auth ON public.user_roles_separacao AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);
-- Policy: user_role_sep_select_auth ON user_roles_separacao
CREATE POLICY user_role_sep_select_auth ON public.user_roles_separacao AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: user_role_sep_update_auth ON user_roles_separacao
CREATE POLICY user_role_sep_update_auth ON public.user_roles_separacao AS PERMISSIVE FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
-- Policy: admin_all_usa ON user_system_access
CREATE POLICY admin_all_usa ON public.user_system_access AS PERMISSIVE FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());
-- Policy: user_select_usa ON user_system_access
CREATE POLICY user_select_usa ON public.user_system_access AS PERMISSIVE FOR SELECT TO authenticated
  USING ((user_id = auth.uid()));
-- Policy: admin_all_usuario_papeis ON usuario_papeis
CREATE POLICY admin_all_usuario_papeis ON public.usuario_papeis AS PERMISSIVE FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());
-- Policy: admin_all_usuario_permissao_excecoes ON usuario_permissao_excecoes
CREATE POLICY admin_all_usuario_permissao_excecoes ON public.usuario_permissao_excecoes AS PERMISSIVE FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());
-- Policy: usuarios_delete_admin ON usuarios
CREATE POLICY usuarios_delete_admin ON public.usuarios AS PERMISSIVE FOR DELETE TO authenticated
  USING ((get_user_role() = 'admin'::text));
-- Policy: usuarios_select_all ON usuarios
CREATE POLICY usuarios_select_all ON public.usuarios AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
-- Policy: usuarios_select_own_or_funcionario ON usuarios
CREATE POLICY usuarios_select_own_or_funcionario ON public.usuarios AS PERMISSIVE FOR SELECT TO authenticated
  USING (((id = auth.uid()) OR current_user_is_funcionario()));
-- Policy: usuarios_update_own ON usuarios
CREATE POLICY usuarios_update_own ON public.usuarios AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((id = auth.uid()))
  WITH CHECK ((id = auth.uid()));
-- Policy: usuarios_ubiqua_delete ON usuarios_ubiqua
CREATE POLICY usuarios_ubiqua_delete ON public.usuarios_ubiqua AS PERMISSIVE FOR DELETE TO authenticated
  USING (((id = auth.uid()) OR is_ubiqua_admin()));
-- Policy: usuarios_ubiqua_insert ON usuarios_ubiqua
CREATE POLICY usuarios_ubiqua_insert ON public.usuarios_ubiqua AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (((id = auth.uid()) OR is_ubiqua_admin()));
-- Policy: usuarios_ubiqua_select ON usuarios_ubiqua
CREATE POLICY usuarios_ubiqua_select ON public.usuarios_ubiqua AS PERMISSIVE FOR SELECT TO authenticated
  USING (((id = auth.uid()) OR is_ubiqua_admin()));
-- Policy: usuarios_ubiqua_update ON usuarios_ubiqua
CREATE POLICY usuarios_ubiqua_update ON public.usuarios_ubiqua AS PERMISSIVE FOR UPDATE TO authenticated
  USING (((id = auth.uid()) OR is_ubiqua_admin()))
  WITH CHECK (((id = auth.uid()) OR is_ubiqua_admin()));
-- Policy: Permitir leitura para autenticados ON vendas
CREATE POLICY "Permitir leitura para autenticados" ON public.vendas AS PERMISSIVE FOR SELECT TO public
  USING ((auth.role() = 'authenticated'::text));
-- Policy: Permitir tudo para service_role ON vendas
CREATE POLICY "Permitir tudo para service_role" ON public.vendas AS PERMISSIVE FOR ALL TO public
  USING ((auth.role() = 'service_role'::text));
-- Policy: vendas_delete ON vendas_marca
CREATE POLICY vendas_delete ON public.vendas_marca AS PERMISSIVE FOR DELETE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: vendas_insert ON vendas_marca
CREATE POLICY vendas_insert ON public.vendas_marca AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: vendas_select ON vendas_marca
CREATE POLICY vendas_select ON public.vendas_marca AS PERMISSIVE FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
-- Policy: vendas_update ON vendas_marca
CREATE POLICY vendas_update ON public.vendas_marca AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
-- Policy: Admin Delete ON objects
CREATE POLICY "Admin Delete" ON storage.objects AS PERMISSIVE FOR DELETE TO authenticated
  USING ((bucket_id = 'revenda-ubiqua-images'::text));
-- Policy: Admin Update ON objects
CREATE POLICY "Admin Update" ON storage.objects AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((bucket_id = 'revenda-ubiqua-images'::text));
-- Policy: Admin Upload ON objects
CREATE POLICY "Admin Upload" ON storage.objects AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((bucket_id = 'revenda-ubiqua-images'::text));
-- Policy: Anon can upload ON objects
CREATE POLICY "Anon can upload" ON storage.objects AS PERMISSIVE FOR INSERT TO anon
  WITH CHECK ((bucket_id = 'orcamentos'::text));
-- Policy: Anon public read for catalogos ON objects
CREATE POLICY "Anon public read for catalogos" ON storage.objects AS PERMISSIVE FOR SELECT TO anon
  USING ((bucket_id = 'revenda-ubiqua-images'::text));
-- Policy: Authenticated Users can upload ON objects
CREATE POLICY "Authenticated Users can upload" ON storage.objects AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((bucket_id = 'orcamentos'::text));
-- Policy: Authenticated public read for catalogos ON objects
CREATE POLICY "Authenticated public read for catalogos" ON storage.objects AS PERMISSIVE FOR SELECT TO authenticated
  USING ((bucket_id = 'revenda-ubiqua-images'::text));
-- Policy: Give anon users access to JPG images in folder 1ps91ds_0 ON objects
CREATE POLICY "Give anon users access to JPG images in folder 1ps91ds_0" ON storage.objects AS PERMISSIVE FOR INSERT TO public
  WITH CHECK (((bucket_id = 'revenda-ubiqua-images'::text) AND (storage.extension(name) = 'jpg'::text) AND (lower((storage.foldername(name))[1]) = 'public'::text) AND (auth.role() = 'anon'::text)));
-- Policy: Give anon users access to JPG images in folder 1ps91ds_1 ON objects
CREATE POLICY "Give anon users access to JPG images in folder 1ps91ds_1" ON storage.objects AS PERMISSIVE FOR UPDATE TO public
  USING (((bucket_id = 'revenda-ubiqua-images'::text) AND (storage.extension(name) = 'jpg'::text) AND (lower((storage.foldername(name))[1]) = 'public'::text) AND (auth.role() = 'anon'::text)));
-- Policy: Give anon users access to JPG images in folder 1ps91ds_2 ON objects
CREATE POLICY "Give anon users access to JPG images in folder 1ps91ds_2" ON storage.objects AS PERMISSIVE FOR SELECT TO public
  USING (((bucket_id = 'revenda-ubiqua-images'::text) AND (storage.extension(name) = 'jpg'::text) AND (lower((storage.foldername(name))[1]) = 'public'::text) AND (auth.role() = 'anon'::text)));
-- Policy: Public Access ON objects
CREATE POLICY "Public Access" ON storage.objects AS PERMISSIVE FOR SELECT TO public
  USING ((bucket_id = 'orcamentos'::text));
-- Policy: orcamentos_anon_insert ON objects
CREATE POLICY orcamentos_anon_insert ON storage.objects AS PERMISSIVE FOR INSERT TO anon
  WITH CHECK ((bucket_id = 'orcamentos'::text));
-- Policy: orcamentos_authenticated_insert ON objects
CREATE POLICY orcamentos_authenticated_insert ON storage.objects AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((bucket_id = 'orcamentos'::text));
-- Policy: orcamentos_authenticated_update ON objects
CREATE POLICY orcamentos_authenticated_update ON storage.objects AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((bucket_id = 'orcamentos'::text));
-- Policy: orcamentos_public_read ON objects
CREATE POLICY orcamentos_public_read ON storage.objects AS PERMISSIVE FOR SELECT TO public
  USING ((bucket_id = 'orcamentos'::text));
