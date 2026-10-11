-- Rollback da 199: recria exatamente as políticas e views de 11/10 (antes da Fase 1).
DELETE FROM public.user_system_access WHERE user_id = (SELECT id FROM public.usuarios WHERE email='pedro@lucenera.com.br') AND system_id = (SELECT id FROM public.systems WHERE slug='dashboard-financeiro') AND created_at >= '2026-10-11';
DROP POLICY IF EXISTS spec196_retorno_registros_select ON public.retorno_bancario_registros;
DROP POLICY IF EXISTS spec196_retorno_arquivos_select ON public.retorno_bancario_arquivos;
DROP POLICY IF EXISTS spec196_retornos_all ON public.retornos_processados;
DROP POLICY IF EXISTS spec196_folha_delete ON public.folha_pagamento;
DROP POLICY IF EXISTS spec196_folha_update ON public.folha_pagamento;
DROP POLICY IF EXISTS spec196_folha_insert ON public.folha_pagamento;
DROP POLICY IF EXISTS spec196_folha_select ON public.folha_pagamento;
DROP POLICY IF EXISTS spec196_func_fin_all ON public.funcionarios_financeiro;
DROP POLICY IF EXISTS spec196_parcelas_delete ON public.projeto_parcelas;
DROP POLICY IF EXISTS spec196_parcelas_update ON public.projeto_parcelas;
DROP POLICY IF EXISTS spec196_parcelas_insert ON public.projeto_parcelas;
DROP POLICY IF EXISTS spec196_parcelas_select ON public.projeto_parcelas;
DROP POLICY IF EXISTS spec196_plano_contas_select ON public.plano_de_contas;
DROP POLICY IF EXISTS spec196_negociacoes_select ON public.negociacoes;
DROP POLICY IF EXISTS spec196_transacoes_delete ON public.transacoes;
DROP POLICY IF EXISTS spec196_transacoes_update ON public.transacoes;
DROP POLICY IF EXISTS spec196_transacoes_insert ON public.transacoes;
DROP POLICY IF EXISTS spec196_transacoes_select ON public.transacoes;
CREATE POLICY "trans_update_admin" ON public.transacoes AS PERMISSIVE FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = 'admin'::usuario_role)))));
CREATE POLICY "trans_delete_admin" ON public.transacoes AS PERMISSIVE FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = 'admin'::usuario_role)))));
CREATE POLICY "trans_insert" ON public.transacoes AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
CREATE POLICY "trans_select" ON public.transacoes AS PERMISSIVE FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
CREATE POLICY "authenticated_select_transacoes" ON public.transacoes AS PERMISSIVE FOR SELECT TO authenticated USING (true);
CREATE POLICY "authenticated_insert_transacoes" ON public.transacoes AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "authenticated_update_transacoes" ON public.transacoes AS PERMISSIVE FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_delete_transacoes" ON public.transacoes AS PERMISSIVE FOR DELETE TO authenticated USING (true);
CREATE POLICY "authenticated_all_transacoes" ON public.transacoes AS PERMISSIVE FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "negociacoes_select" ON public.negociacoes AS PERMISSIVE FOR SELECT TO authenticated USING (true);
CREATE POLICY "plano_contas_select" ON public.plano_de_contas AS PERMISSIVE FOR SELECT TO authenticated USING (true);
CREATE POLICY "parcelas_delete_admin" ON public.projeto_parcelas AS PERMISSIVE FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
CREATE POLICY "parcelas_insert" ON public.projeto_parcelas AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
CREATE POLICY "parcelas_select" ON public.projeto_parcelas AS PERMISSIVE FOR SELECT TO authenticated USING (true);
CREATE POLICY "parcelas_update" ON public.projeto_parcelas AS PERMISSIVE FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role, 'operador'::usuario_role]))))));
CREATE POLICY "authenticated_select_projeto_parcelas" ON public.projeto_parcelas AS PERMISSIVE FOR SELECT TO authenticated USING (true);
CREATE POLICY "authenticated_insert_projeto_parcelas" ON public.projeto_parcelas AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "authenticated_update_projeto_parcelas" ON public.projeto_parcelas AS PERMISSIVE FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all_projeto_parcelas" ON public.projeto_parcelas AS PERMISSIVE FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Permitir leitura para autenticados" ON public.projeto_parcelas AS PERMISSIVE FOR SELECT TO public USING ((auth.role() = 'authenticated'::text));
CREATE POLICY "fn_fin_select_auth" ON public.funcionarios_financeiro AS PERMISSIVE FOR SELECT TO authenticated USING (true);
CREATE POLICY "fn_fin_insert_auth" ON public.funcionarios_financeiro AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "fn_fin_update_auth" ON public.funcionarios_financeiro AS PERMISSIVE FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "fn_fin_delete_auth" ON public.funcionarios_financeiro AS PERMISSIVE FOR DELETE TO authenticated USING (true);
CREATE POLICY "funcionarios_financeiro_authenticated_all" ON public.funcionarios_financeiro AS PERMISSIVE FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "folha_insert" ON public.folha_pagamento AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
CREATE POLICY "folha_update" ON public.folha_pagamento AS PERMISSIVE FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
CREATE POLICY "folha_delete" ON public.folha_pagamento AS PERMISSIVE FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))));
CREATE POLICY "folha_own" ON public.folha_pagamento AS PERMISSIVE FOR SELECT TO authenticated USING (((EXISTS ( SELECT 1
   FROM usuarios u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::usuario_role, 'gerente'::usuario_role]))))) OR (funcionario_id IN ( SELECT funcionarios.id
   FROM funcionarios
  WHERE (funcionarios.usuario_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "authenticated_update_retornos" ON public.retornos_processados AS PERMISSIVE FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_delete_retornos" ON public.retornos_processados AS PERMISSIVE FOR DELETE TO authenticated USING (true);
CREATE POLICY "authenticated_select_retornos" ON public.retornos_processados AS PERMISSIVE FOR SELECT TO authenticated USING (true);
CREATE POLICY "authenticated_insert_retornos" ON public.retornos_processados AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "authenticated_all_retornos" ON public.retornos_processados AS PERMISSIVE FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_select_retorno_bancario_arquivos" ON public.retorno_bancario_arquivos AS PERMISSIVE FOR SELECT TO authenticated USING (true);
CREATE POLICY "authenticated_select_retorno_bancario_registros" ON public.retorno_bancario_registros AS PERMISSIVE FOR SELECT TO authenticated USING (true);
CREATE POLICY "authenticated_insert_categorias_financeiras" ON public.categorias_financeiras AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "authenticated_update_categorias_financeiras" ON public.categorias_financeiras AS PERMISSIVE FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE OR REPLACE VIEW public.v_financeiro_realizado AS
SELECT id,
    tipo,
    descricao,
    desc_sub_grupo,
    desc_grupo,
    natureza,
    status_pago,
    dt_pagamento,
    dt_vencimento,
    dt_emissao,
    vl_pago,
    vl_parcela,
    vl_desconto,
    empresa_id,
    cod_duplicata,
    tipo_custo,
    perfil
   FROM ( WITH pc AS (
                 SELECT plano_de_contas.id,
                    plano_de_contas.codigo_connect,
                    plano_de_contas.nome,
                    plano_de_contas.nivel,
                    plano_de_contas.parent_id
                   FROM plano_de_contas
                ), hierarquia AS (
                 SELECT p3.id AS plano_contas_id,
                    COALESCE(p2.nome, p3.nome) AS desc_sub_grupo,
                    COALESCE(p1.nome, p2.nome, p3.nome) AS desc_grupo
                   FROM ((pc p3
                     LEFT JOIN pc p2 ON ((p2.id = p3.parent_id)))
                     LEFT JOIN pc p1 ON ((p1.id = p2.parent_id)))
                ), negociacao_preferida AS (
                 SELECT n.id,
                    n.cod_duplicata,
                    n.tipo,
                    n.plano_contas_id,
                    n.empresa_id,
                    row_number() OVER (PARTITION BY n.cod_duplicata, n.tipo ORDER BY n.created_at) AS rn
                   FROM (negociacoes n
                     JOIN stg_duplicatas_vigentes v ON (((v.cod_duplicata = n.cod_duplicata) AND (v.tipo = n.tipo))))
                )
         SELECT t.id,
            t.tipo,
            t.descricao,
            h.desc_sub_grupo,
            h.desc_grupo,
                CASE
                    WHEN ((t.tipo = 'despesa'::transacao_tipo) AND ((h.desc_sub_grupo ~~* '%FILIPPO%'::text) OR (h.desc_sub_grupo ~~* '%MANOELLA%'::text) OR (t.descricao ~~* '%RETIRADA LUCRO%'::text) OR (t.descricao ~~* '%RETIRADA DE LUCRO%'::text) OR (t.descricao ~~* '%LUCRO DISTRIB%'::text))) THEN 'distribuicao_lucro'::text
                    WHEN (t.tipo = 'despesa'::transacao_tipo) THEN 'despesa_operacional'::text
                    ELSE NULL::text
                END AS natureza,
            t.status_pago,
            t.dt_pagamento,
            t.dt_vencimento,
            t.dt_emissao,
            t.vl_pago,
            t.vl_parcela,
            t.vl_desconto,
            np.empresa_id,
            np.cod_duplicata,
                CASE
                    WHEN (t.tipo <> 'despesa'::transacao_tipo) THEN NULL::text
                    WHEN (h.desc_sub_grupo = ANY (ARRAY['FIXAS'::text, 'COM PESSOAL'::text, 'ADMINISTRATIVAS'::text, 'BANCARIAS'::text, 'VEICULOS'::text])) THEN 'fixo'::text
                    WHEN (h.desc_sub_grupo = ANY (ARRAY['COM VENDAS'::text, 'PRODUTOS'::text])) THEN 'variavel'::text
                    ELSE 'outro'::text
                END AS tipo_custo,
            t.perfil
           FROM ((transacoes t
             JOIN negociacao_preferida np ON (((np.id = t.negociacao_id) AND (np.rn = 1))))
             LEFT JOIN hierarquia h ON ((h.plano_contas_id = np.plano_contas_id)))
          WHERE (t.status_pago <> 2)) x
  WHERE ((natureza IS DISTINCT FROM 'distribuicao_lucro'::text) OR ( SELECT pode_ver_distribuicao_lucro() AS pode_ver_distribuicao_lucro));
CREATE OR REPLACE VIEW public.v_cash_flow_lucenera AS
SELECT dt_pagamento,
    dt_vencimento,
    tipo,
    categoria_fluxo,
    vl_pago,
    descricao,
    status_pago
   FROM ( SELECT transacoes.dt_pagamento,
            transacoes.dt_vencimento,
            (transacoes.tipo)::text AS tipo,
                CASE
                    WHEN (((transacoes.descricao ~~* '%LUCRO%'::text) OR (transacoes.descricao ~~* '%RETIRADA%'::text)) AND ((transacoes.tipo)::text = 'despesa'::text)) THEN 'distribuicao_lucro'::text
                    ELSE (transacoes.tipo)::text
                END AS categoria_fluxo,
            transacoes.vl_pago,
            transacoes.descricao,
            transacoes.status_pago
           FROM transacoes
          WHERE ((transacoes.status_pago = 1) AND (transacoes.dt_pagamento IS NOT NULL))) x
  WHERE ((categoria_fluxo IS DISTINCT FROM 'distribuicao_lucro'::text) OR ( SELECT pode_ver_distribuicao_lucro() AS pode_ver_distribuicao_lucro));
CREATE OR REPLACE VIEW public.vw_funcionarios_completo AS
SELECT fn.id,
    fn.nome,
    fn.cargo,
    fn.ativo,
    fn.data_admissao,
    fn.created_at,
    fd.cpf,
    fd.rg,
    fd.data_nascimento,
    fd.endereco,
    fd.telefone,
    fd.email,
    ff.salario_base,
    ff.salario_por_fora,
    ff.comissao_percentual,
    ff.salario_liquido,
    fb.empresa,
    fb.valor_vt_dia,
    fn.perfil
   FROM (((funcionarios_novo fn
     LEFT JOIN funcionarios_detalhes fd ON ((fd.funcionario_id = fn.id)))
     LEFT JOIN funcionarios_financeiro ff ON ((ff.funcionario_id = fn.id)))
     LEFT JOIN funcionarios_beneficios_empresas fb ON ((fb.funcionario_id = fn.id)));
CREATE OR REPLACE VIEW public.vw_comissao_mensal AS
SELECT fn.id AS funcionario_id,
    fn.nome AS funcionario,
    ep.id AS equipe_id,
    ep.equipes AS equipe,
    ff.comissao_percentual,
    (date_trunc('month'::text, (p.data_entrada)::timestamp with time zone))::date AS mes,
    count(p.id) AS total_projetos,
    round(sum(p.valor_total), 2) AS valor_total_projetos,
    round(sum(((p.valor_total * COALESCE(ff.comissao_percentual, (0)::numeric)) / 100.0)), 2) AS comissao_calculada
   FROM (((projetos p
     JOIN equipes_projetos ep ON ((ep.id = p.equipe_id)))
     JOIN funcionarios_financeiro ff ON ((ff.equipes_id = ep.id)))
     JOIN funcionarios_novo fn ON ((fn.id = ff.funcionario_id)))
  WHERE ((p.valor_total > (0)::numeric) AND (p.data_entrada IS NOT NULL) AND (fn.ativo IS TRUE))
  GROUP BY fn.id, fn.nome, ep.id, ep.equipes, ff.comissao_percentual, (date_trunc('month'::text, (p.data_entrada)::timestamp with time zone));
DROP FUNCTION IF EXISTS public.pode_acessar_sistema(text);
