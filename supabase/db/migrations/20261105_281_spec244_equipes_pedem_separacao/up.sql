-- SPEC-244 (05/11): as equipes de projetos pedem a separação no sistema novo (Venda Parcial -> "Criar Separação").
-- ERRO ENCONTRADO: ao criar a separação a tela insere em `separacoes` (liberado por permissão do Hub: criar em separacao-parcial/logistica) e depois em
-- `separacao_itens`, cuja política de INSERT só aceitava usuario.role = admin/gerente/operador. Todas as equipes de projetos têm role `funcionario`
-- (não existe nenhum `operador`), então a segunda inserção falhava com "new row violates row-level security policy for table separacao_itens" e a
-- limpeza (`DELETE` em `separacoes`, que exige o 'deletar' do Hub) também falhava: ficavam separações vazias "material_solicitado" na Logística.
-- CORREÇÃO: a mesma regra de `separacoes` (permissão do Hub) passa a valer em `separacao_itens` (criar/editar), e quem criou uma separação VAZIA pode
-- desfazê-la (só a própria e só sem itens). Não mexe em quantidade, estoque nem saldo.
BEGIN;

DROP POLICY IF EXISTS sep_itens_insert_hub ON public.separacao_itens;
CREATE POLICY sep_itens_insert_hub ON public.separacao_itens
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.hub_pode_executar((SELECT auth.uid()), 'separacao-parcial'::text, NULL::text, 'criar'::text))
              OR (SELECT public.hub_pode_executar((SELECT auth.uid()), 'logistica'::text, NULL::text, 'criar'::text)));

DROP POLICY IF EXISTS sep_itens_update_hub ON public.separacao_itens;
CREATE POLICY sep_itens_update_hub ON public.separacao_itens
  FOR UPDATE TO authenticated
  USING ((SELECT public.hub_pode_executar((SELECT auth.uid()), 'separacao-parcial'::text, NULL::text, 'editar'::text))
         OR (SELECT public.hub_pode_executar((SELECT auth.uid()), 'logistica'::text, NULL::text, 'editar'::text)))
  WITH CHECK ((SELECT public.hub_pode_executar((SELECT auth.uid()), 'separacao-parcial'::text, NULL::text, 'editar'::text))
              OR (SELECT public.hub_pode_executar((SELECT auth.uid()), 'logistica'::text, NULL::text, 'editar'::text)));

DROP POLICY IF EXISTS separacoes_delete_vazia_propria ON public.separacoes;
CREATE POLICY separacoes_delete_vazia_propria ON public.separacoes
  FOR DELETE TO authenticated
  USING (responsavel_id = (SELECT auth.uid())
         AND NOT EXISTS (SELECT 1 FROM public.separacao_itens i WHERE i.separacao_id = separacoes.id));

COMMIT;
