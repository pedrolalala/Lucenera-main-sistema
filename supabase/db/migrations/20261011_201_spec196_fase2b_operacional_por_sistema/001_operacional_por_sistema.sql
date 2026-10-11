-- SPEC-196 Fase 2b (11/10/2026): tabelas do dia a dia só para quem usa o sistema que precisa delas
-- (Acesso a Sistemas; admin passa). Fecha, entre outros, a leitura dos orçamentos da Lucenera pelos
-- representantes Ubiqua (logados no catálogo, sem nenhum sistema interno).
--   orçamentos/histórico: quem tem algum sistema interno; separações/entregas: Logística ou Separação Parcial;
--   garantia: Controle de Garantia; projetos_fechados: RH/CRM/financeiro lêem, RH ou admin gravam;
--   contato_tipos: quem cadastra contato (Orçamentos, CRM, Compras, Adm. Bancária, Cadastro);
--   empresas: todos lêem, só admin altera. contatos: continua legível por quem tem login (9 sistemas usam);
--   a gravação já era por papel/Hub.

CREATE OR REPLACE FUNCTION public.pode_acessar_algum(p_slugs text[])
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE
    WHEN coalesce(nullif(current_setting('request.jwt.claims', true), ''), '') = '' THEN true
    WHEN coalesce(auth.role(), '') = 'service_role' THEN true
    ELSE EXISTS (SELECT 1 FROM public.usuarios u WHERE u.id = auth.uid() AND u.role = 'admin' AND u.ativo)
      OR EXISTS (SELECT 1 FROM public.user_system_access a JOIN public.systems s ON s.id = a.system_id
                 WHERE a.user_id = auth.uid() AND s.slug = ANY (p_slugs))
  END
$$;
REVOKE ALL ON FUNCTION public.pode_acessar_algum(text[]) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.pode_acessar_algum(text[]) TO authenticated, service_role;


-- orcamentos
DROP POLICY IF EXISTS "orcamentos_select" ON public.orcamentos;
DROP POLICY IF EXISTS "authenticated_select_orcamentos_approval" ON public.orcamentos;
DROP POLICY IF EXISTS "anon_can_read_orcamento_by_token" ON public.orcamentos;
DROP POLICY IF EXISTS "authenticated_select_orcamentos_financial" ON public.orcamentos;
DROP POLICY IF EXISTS "anon_insert_orcamentos" ON public.orcamentos;
DROP POLICY IF EXISTS "authenticated_select_orcamentos" ON public.orcamentos;
CREATE POLICY spec196_orcamentos_select ON public.orcamentos FOR SELECT TO authenticated
  USING ((SELECT public.pode_acessar_algum(ARRAY['orcamentos', 'crm', 'financeiro', 'dashboard-financeiro', 'separacao-parcial', 'vendas', 'logistica', 'necessidade-de-compra', 'controle-producao', 'controle-garantia', 'cadastro', 'rh', 'solicitacoes'])));

-- historico_status_orcamentos
DROP POLICY IF EXISTS "authenticated_select_historico_status_orcamentos" ON public.historico_status_orcamentos;
DROP POLICY IF EXISTS "authenticated_insert_historico_status_orcamentos" ON public.historico_status_orcamentos;
DROP POLICY IF EXISTS "authenticated_update_historico_status_orcamentos" ON public.historico_status_orcamentos;
CREATE POLICY spec196_hist_orc_select ON public.historico_status_orcamentos FOR SELECT TO authenticated
  USING ((SELECT public.pode_acessar_algum(ARRAY['orcamentos', 'crm', 'financeiro', 'dashboard-financeiro', 'separacao-parcial', 'vendas', 'logistica', 'necessidade-de-compra', 'controle-producao', 'controle-garantia', 'cadastro', 'rh', 'solicitacoes'])));
CREATE POLICY spec196_hist_orc_insert ON public.historico_status_orcamentos FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.pode_acessar_algum(ARRAY['orcamentos', 'crm', 'financeiro', 'dashboard-financeiro', 'separacao-parcial', 'vendas', 'logistica', 'necessidade-de-compra', 'controle-producao', 'controle-garantia', 'cadastro', 'rh', 'solicitacoes'])));

-- separacoes
DROP POLICY IF EXISTS "separacoes_select" ON public.separacoes;
DROP POLICY IF EXISTS "sep_select_auth" ON public.separacoes;
CREATE POLICY spec196_separacoes_select ON public.separacoes FOR SELECT TO authenticated
  USING ((SELECT public.pode_acessar_algum(ARRAY['logistica', 'separacao-parcial'])));

-- separacao_arquivos
DROP POLICY IF EXISTS "separacao_arquivos_authenticated_all" ON public.separacao_arquivos;
DROP POLICY IF EXISTS "separacao_arquivos_select" ON public.separacao_arquivos;
DROP POLICY IF EXISTS "separacao_arquivos_insert" ON public.separacao_arquivos;
DROP POLICY IF EXISTS "separacao_arquivos_update" ON public.separacao_arquivos;
DROP POLICY IF EXISTS "separacao_arquivos_delete" ON public.separacao_arquivos;
DROP POLICY IF EXISTS "sep_arq_select_auth" ON public.separacao_arquivos;
DROP POLICY IF EXISTS "sep_arq_insert_auth" ON public.separacao_arquivos;
DROP POLICY IF EXISTS "sep_arq_update_auth" ON public.separacao_arquivos;
DROP POLICY IF EXISTS "sep_arq_delete_auth" ON public.separacao_arquivos;
CREATE POLICY spec196_sep_arquivos_all ON public.separacao_arquivos FOR ALL TO authenticated
  USING ((SELECT public.pode_acessar_algum(ARRAY['logistica', 'separacao-parcial'])))
  WITH CHECK ((SELECT public.pode_acessar_algum(ARRAY['logistica', 'separacao-parcial'])));

-- entregas_pendentes
DROP POLICY IF EXISTS "entregas_pendentes_select_auth" ON public.entregas_pendentes;
DROP POLICY IF EXISTS "entregas_pendentes_insert_auth" ON public.entregas_pendentes;
DROP POLICY IF EXISTS "entregas_pendentes_update_auth" ON public.entregas_pendentes;
DROP POLICY IF EXISTS "entregas_pendentes_delete_auth" ON public.entregas_pendentes;
CREATE POLICY spec196_entregas_pend_all ON public.entregas_pendentes FOR ALL TO authenticated
  USING ((SELECT public.pode_acessar_algum(ARRAY['logistica', 'separacao-parcial'])))
  WITH CHECK ((SELECT public.pode_acessar_algum(ARRAY['logistica', 'separacao-parcial'])));

-- entregas_finalizadas
DROP POLICY IF EXISTS "entregas_finalizadas_authenticated_all" ON public.entregas_finalizadas;
DROP POLICY IF EXISTS "entregas_finalizadas_select" ON public.entregas_finalizadas;
DROP POLICY IF EXISTS "entregas_finalizadas_insert" ON public.entregas_finalizadas;
DROP POLICY IF EXISTS "entregas_finalizadas_update" ON public.entregas_finalizadas;
DROP POLICY IF EXISTS "entregas_finalizadas_delete" ON public.entregas_finalizadas;
DROP POLICY IF EXISTS "ent_fin_select_auth" ON public.entregas_finalizadas;
DROP POLICY IF EXISTS "ent_fin_insert_auth" ON public.entregas_finalizadas;
DROP POLICY IF EXISTS "ent_fin_update_auth" ON public.entregas_finalizadas;
DROP POLICY IF EXISTS "ent_fin_delete_auth" ON public.entregas_finalizadas;
CREATE POLICY spec196_entregas_fin_all ON public.entregas_finalizadas FOR ALL TO authenticated
  USING ((SELECT public.pode_acessar_algum(ARRAY['logistica', 'separacao-parcial'])))
  WITH CHECK ((SELECT public.pode_acessar_algum(ARRAY['logistica', 'separacao-parcial'])));

-- garantia_itens
DROP POLICY IF EXISTS "garantia_itens_select" ON public.garantia_itens;
DROP POLICY IF EXISTS "garantia_itens_insert" ON public.garantia_itens;
DROP POLICY IF EXISTS "garantia_itens_update" ON public.garantia_itens;
CREATE POLICY spec196_garantia_itens_all ON public.garantia_itens FOR ALL TO authenticated
  USING ((SELECT public.pode_acessar_algum(ARRAY['controle-garantia'])))
  WITH CHECK ((SELECT public.pode_acessar_algum(ARRAY['controle-garantia'])));

-- garantia_protocolos
DROP POLICY IF EXISTS "garantia_protocolos_select" ON public.garantia_protocolos;
DROP POLICY IF EXISTS "garantia_protocolos_insert" ON public.garantia_protocolos;
DROP POLICY IF EXISTS "garantia_protocolos_update" ON public.garantia_protocolos;
CREATE POLICY spec196_garantia_prot_all ON public.garantia_protocolos FOR ALL TO authenticated
  USING ((SELECT public.pode_acessar_algum(ARRAY['controle-garantia'])))
  WITH CHECK ((SELECT public.pode_acessar_algum(ARRAY['controle-garantia'])));

-- projetos_fechados
DROP POLICY IF EXISTS "projetos_fechados_select" ON public.projetos_fechados;
DROP POLICY IF EXISTS "projetos_fechados_insert" ON public.projetos_fechados;
DROP POLICY IF EXISTS "projetos_fechados_update" ON public.projetos_fechados;
DROP POLICY IF EXISTS "projetos_fechados_delete" ON public.projetos_fechados;
CREATE POLICY spec196_proj_fech_select ON public.projetos_fechados FOR SELECT TO authenticated
  USING ((SELECT public.pode_acessar_algum(ARRAY['rh', 'crm', 'dashboard-financeiro', 'financeiro'])));
CREATE POLICY spec196_proj_fech_write ON public.projetos_fechados FOR ALL TO authenticated
  USING ((SELECT public.is_admin()) OR (SELECT public.pode_acessar_algum(ARRAY['rh'])))
  WITH CHECK ((SELECT public.is_admin()) OR (SELECT public.pode_acessar_algum(ARRAY['rh'])));

-- contato_tipos
DROP POLICY IF EXISTS "authenticated_insert_contato_tipos" ON public.contato_tipos;
DROP POLICY IF EXISTS "authenticated_delete_contato_tipos" ON public.contato_tipos;
DROP POLICY IF EXISTS "authenticated_all" ON public.contato_tipos;
CREATE POLICY spec196_contato_tipos_insert ON public.contato_tipos FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.pode_acessar_algum(ARRAY['orcamentos', 'crm', 'necessidade-de-compra', 'financeiro', 'cadastro'])));
CREATE POLICY spec196_contato_tipos_update ON public.contato_tipos FOR UPDATE TO authenticated
  USING ((SELECT public.pode_acessar_algum(ARRAY['orcamentos', 'crm', 'necessidade-de-compra', 'financeiro', 'cadastro'])))
  WITH CHECK ((SELECT public.pode_acessar_algum(ARRAY['orcamentos', 'crm', 'necessidade-de-compra', 'financeiro', 'cadastro'])));
CREATE POLICY spec196_contato_tipos_delete ON public.contato_tipos FOR DELETE TO authenticated
  USING ((SELECT public.pode_acessar_algum(ARRAY['orcamentos', 'crm', 'necessidade-de-compra', 'financeiro', 'cadastro'])));

-- empresas
DROP POLICY IF EXISTS "empresas_insert_auth" ON public.empresas;
DROP POLICY IF EXISTS "empresas_update_auth" ON public.empresas;
DROP POLICY IF EXISTS "empresas_delete_auth" ON public.empresas;
DROP POLICY IF EXISTS "auth_empresas" ON public.empresas;
DROP POLICY IF EXISTS "anon_select_empresas" ON public.empresas;
CREATE POLICY spec196_empresas_write ON public.empresas FOR ALL TO authenticated
  USING ((SELECT public.is_admin()))
  WITH CHECK ((SELECT public.is_admin()));
