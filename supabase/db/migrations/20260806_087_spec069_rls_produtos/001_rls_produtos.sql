-- SPEC-069: continuação do achado técnico crítico — `produtos` tinha o
-- mesmo padrão de `contas_bancarias`: já existia uma policy restrita
-- (prod_insert/update/delete, admin/gerente) mas policies PERMISSIVE
-- `authenticated_*_produtos USING/WITH CHECK (true)` neutralizavam ela
-- (Postgres combina PERMISSIVE com OR). Isso permitia cadastrar produto
-- direto pelo Cadastro (fora do fluxo de Orçamento, que já foi corrigido na
-- migration 086 via guard na RPC criar_produto_orcamento).
--
-- slug 'cadastro' hoje tem 'criar' para admin_geral e administracao_comercial
-- (Carol); equipe_projetos e compras_e_entregas têm só editar/visualizar
-- (sem criar) — corresponde exatamente a "Editar sem cadastrar"/"Consultar".

DROP POLICY IF EXISTS "Permitir leitura para autenticados" ON public.produtos;
DROP POLICY IF EXISTS authenticated_delete_produtos ON public.produtos;
DROP POLICY IF EXISTS authenticated_insert_produtos ON public.produtos;
DROP POLICY IF EXISTS authenticated_select_produtos ON public.produtos;
DROP POLICY IF EXISTS authenticated_update_produtos ON public.produtos;
DROP POLICY IF EXISTS prod_select ON public.produtos;
DROP POLICY IF EXISTS prod_insert ON public.produtos;
DROP POLICY IF EXISTS prod_update ON public.produtos;
DROP POLICY IF EXISTS prod_delete ON public.produtos;
-- "Permitir tudo para service_role" fica intacta — Edge Functions/scripts
-- administrativos continuam funcionando (service_role sempre ignora RLS,
-- mas mantemos a policy explícita como estava).

CREATE POLICY spec069_produtos_select ON public.produtos FOR SELECT
  USING (
    public.hub_pode_executar(auth.uid(), 'cadastro', NULL, 'visualizar')
    OR public.hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'visualizar')
    OR public.hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'visualizar')
  );
CREATE POLICY spec069_produtos_insert ON public.produtos FOR INSERT
  WITH CHECK (
    public.hub_pode_executar(auth.uid(), 'cadastro', NULL, 'criar')
    OR public.hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'criar')
  );
CREATE POLICY spec069_produtos_update ON public.produtos FOR UPDATE
  USING (
    public.hub_pode_executar(auth.uid(), 'cadastro', NULL, 'editar')
    OR public.hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'editar')
    OR public.hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar')
  )
  WITH CHECK (
    public.hub_pode_executar(auth.uid(), 'cadastro', NULL, 'editar')
    OR public.hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'editar')
    OR public.hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar')
  );
CREATE POLICY spec069_produtos_delete ON public.produtos FOR DELETE
  USING (public.hub_pode_executar(auth.uid(), 'cadastro', NULL, 'deletar'));
