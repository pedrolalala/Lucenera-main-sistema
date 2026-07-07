-- Migration 20260707_024 - Parte 1
-- Define a policy de negocio de leitura para as tabelas/views da SPEC-010
-- que o hardening 20260707_023 deixou fechadas (REVOKE ALL de anon/authenticated)
-- ate essa decisao ser tomada.
--
-- Decisao: leitura ampla para qualquer usuario autenticado, no mesmo padrao
-- ja usado em projeto_itens (`pi_select ... FOR SELECT TO authenticated USING (true)`).
-- Escrita continua exclusiva das RPCs SECURITY DEFINER (aprovar_orcamento_financeiro,
-- e as novas RPCs das SPEC-011/012/015), que bypassam RLS pelo dono da funcao -
-- nao existe (e nao deve existir) policy de INSERT/UPDATE/DELETE para authenticated
-- nestas tabelas.
--
-- Papel/role granular por modulo e acao (Hub/SPEC-006) fica para quando a UI de
-- permissoes existir; esta migration nao antecipa isso.

GRANT SELECT ON TABLE public.estoque_saldos_projeto_item TO authenticated;
GRANT SELECT ON TABLE public.estoque_movimentos_projeto_item TO authenticated;
GRANT SELECT ON TABLE public.vw_estoque_saldos_projeto_item TO authenticated;
GRANT SELECT ON TABLE public.vw_estoque_por_produto_projeto TO authenticated;
GRANT SELECT ON TABLE public.vw_estoque_resumo TO authenticated;

CREATE POLICY authenticated_select_estoque_saldos_projeto_item
  ON public.estoque_saldos_projeto_item
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);

CREATE POLICY authenticated_select_estoque_movimentos_projeto_item
  ON public.estoque_movimentos_projeto_item
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
