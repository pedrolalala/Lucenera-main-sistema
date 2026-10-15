-- 15/10/2026 (Catálogo Ubiqua): orçamento da Ubiqua só é visível para o representante dono.
-- Antes: orcamentos_revenda_ubiqua e itens_orcamento_ubiqua tinham políticas USING (true) —
-- qualquer usuário logado (inclusive outro representante) lia e alterava todos.
-- Regra nova: vê/altera o orçamento quem enxerga o CLIENTE dele. A RLS de
-- informacoes_cliente_ubiqua já define isso: representante = clientes que cadastrou;
-- admin/interno da Ubiqua (usuarios_ubiqua) e admin/gerente da Lucenera (usuarios) = todos.
-- Itens seguem o orçamento. Edge Functions com service role não são afetadas.
-- anon já não tem GRANT nessas tabelas (SPEC-196); as políticas de anon saem também.
BEGIN;

DROP POLICY IF EXISTS all_select_orcamentos_revenda_ubiqua ON public.orcamentos_revenda_ubiqua;
DROP POLICY IF EXISTS anon_insert_orcamentos_revenda_ubiqua ON public.orcamentos_revenda_ubiqua;
DROP POLICY IF EXISTS auth_insert_orcamentos_revenda_ubiqua ON public.orcamentos_revenda_ubiqua;
DROP POLICY IF EXISTS authenticated_all_orcamentos_revenda_ubiqua ON public.orcamentos_revenda_ubiqua;
DROP POLICY IF EXISTS authenticated_update_orcamentos_revenda_ubiqua ON public.orcamentos_revenda_ubiqua;
DROP POLICY IF EXISTS update_orcamentos_revenda_ubiqua ON public.orcamentos_revenda_ubiqua;

CREATE POLICY orcamentos_ubiqua_do_representante ON public.orcamentos_revenda_ubiqua
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.informacoes_cliente_ubiqua c WHERE c.id = cliente_id))
  WITH CHECK (EXISTS (SELECT 1 FROM public.informacoes_cliente_ubiqua c WHERE c.id = cliente_id));

DROP POLICY IF EXISTS all_select_itens_orcamento_ubiqua ON public.itens_orcamento_ubiqua;
DROP POLICY IF EXISTS anon_insert_itens_orcamento_ubiqua ON public.itens_orcamento_ubiqua;
DROP POLICY IF EXISTS auth_insert_itens_orcamento_ubiqua ON public.itens_orcamento_ubiqua;
DROP POLICY IF EXISTS authenticated_all_itens_orcamento_ubiqua ON public.itens_orcamento_ubiqua;

CREATE POLICY itens_orcamento_ubiqua_do_representante ON public.itens_orcamento_ubiqua
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.orcamentos_revenda_ubiqua o WHERE o.id = orcamento_id))
  WITH CHECK (EXISTS (SELECT 1 FROM public.orcamentos_revenda_ubiqua o WHERE o.id = orcamento_id));

REVOKE ALL ON public.orcamentos_revenda_ubiqua, public.itens_orcamento_ubiqua FROM anon;

-- O número ORC-AAAA-NNNNNN é o MAX + 1 do que a função enxerga. Com a RLS nova o representante
-- só enxergaria os próprios e repetiria números: a função passa a ler a tabela inteira
-- (devolve só o próximo número, nenhum dado de orçamento).
ALTER FUNCTION public.fn_gerar_numero_orcamento() SECURITY DEFINER SET search_path = public;

COMMIT;
