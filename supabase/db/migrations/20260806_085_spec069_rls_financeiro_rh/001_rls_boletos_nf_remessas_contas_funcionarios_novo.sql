-- SPEC-069: primeiro incremento de enforcement real de RLS (não só frontend).
--
-- Escopo desta migration — só as tabelas onde confirmei, consultando
-- pg_policies ao vivo (não o snapshot desatualizado de
-- supabase/db/current/07_rls_policies.sql), que existe policy PERMISSIVE
-- `USING (true)`/`WITH CHECK (true)` redundante que neutraliza qualquer
-- policy nova (Postgres combina PERMISSIVE com OR):
--
--   - Administração Bancária: boletos, notas_fiscais, remessas, contas_bancarias
--   - RH: funcionarios_novo
--
-- Deliberadamente NÃO tocado nesta migration (já protegidas corretamente
-- por checagem de usuarios.role/get_user_role(), incluindo autoatendimento
-- do funcionário via funcionario_id = get_my_funcionario_id() — substituir
-- por hub_pode_executar aqui quebraria esse autoatendimento sem necessidade):
-- ferias, controle_falta, periodos_aquisitivos, funcionarios, custos_recorrentes.
-- feriados (calendário compartilhado, baixa sensibilidade) também não tocado.
--
-- slug 'financeiro' hoje só tem grant TOTAL para admin_geral (Vinícius) —
-- corresponde exatamente a "Administração Bancária exclusiva do
-- Administrador Geral". slug 'rh' tem TOTAL para admin_geral + rh_administracao
-- (Vinícius + Lana) — corresponde a "única pessoa, além do administrador
-- geral, com acesso ao RH".

-- boletos
DROP POLICY IF EXISTS authenticated_all_boletos ON public.boletos;
DROP POLICY IF EXISTS authenticated_delete_boletos ON public.boletos;
DROP POLICY IF EXISTS authenticated_insert_boletos ON public.boletos;
DROP POLICY IF EXISTS authenticated_select_boletos ON public.boletos;
DROP POLICY IF EXISTS authenticated_update_boletos ON public.boletos;

CREATE POLICY spec069_boletos_select ON public.boletos FOR SELECT
  USING (public.hub_pode_executar(auth.uid(), 'financeiro', NULL, 'visualizar'));
CREATE POLICY spec069_boletos_insert ON public.boletos FOR INSERT
  WITH CHECK (public.hub_pode_executar(auth.uid(), 'financeiro', NULL, 'criar'));
CREATE POLICY spec069_boletos_update ON public.boletos FOR UPDATE
  USING (public.hub_pode_executar(auth.uid(), 'financeiro', NULL, 'editar'))
  WITH CHECK (public.hub_pode_executar(auth.uid(), 'financeiro', NULL, 'editar'));
CREATE POLICY spec069_boletos_delete ON public.boletos FOR DELETE
  USING (public.hub_pode_executar(auth.uid(), 'financeiro', NULL, 'deletar'));

-- notas_fiscais
DROP POLICY IF EXISTS authenticated_all_notas_fiscais ON public.notas_fiscais;
DROP POLICY IF EXISTS authenticated_delete_nf ON public.notas_fiscais;
DROP POLICY IF EXISTS authenticated_insert_nf ON public.notas_fiscais;
DROP POLICY IF EXISTS authenticated_select_nf ON public.notas_fiscais;
DROP POLICY IF EXISTS authenticated_update_nf ON public.notas_fiscais;

CREATE POLICY spec069_notas_fiscais_select ON public.notas_fiscais FOR SELECT
  USING (public.hub_pode_executar(auth.uid(), 'financeiro', NULL, 'visualizar'));
CREATE POLICY spec069_notas_fiscais_insert ON public.notas_fiscais FOR INSERT
  WITH CHECK (public.hub_pode_executar(auth.uid(), 'financeiro', NULL, 'criar'));
CREATE POLICY spec069_notas_fiscais_update ON public.notas_fiscais FOR UPDATE
  USING (public.hub_pode_executar(auth.uid(), 'financeiro', NULL, 'editar'))
  WITH CHECK (public.hub_pode_executar(auth.uid(), 'financeiro', NULL, 'editar'));
CREATE POLICY spec069_notas_fiscais_delete ON public.notas_fiscais FOR DELETE
  USING (public.hub_pode_executar(auth.uid(), 'financeiro', NULL, 'deletar'));

-- remessas
DROP POLICY IF EXISTS remessas_delete_policy ON public.remessas;
DROP POLICY IF EXISTS remessas_insert_policy ON public.remessas;
DROP POLICY IF EXISTS remessas_select_policy ON public.remessas;
DROP POLICY IF EXISTS remessas_update_policy ON public.remessas;

CREATE POLICY spec069_remessas_select ON public.remessas FOR SELECT
  USING (public.hub_pode_executar(auth.uid(), 'financeiro', NULL, 'visualizar'));
CREATE POLICY spec069_remessas_insert ON public.remessas FOR INSERT
  WITH CHECK (public.hub_pode_executar(auth.uid(), 'financeiro', NULL, 'criar'));
CREATE POLICY spec069_remessas_update ON public.remessas FOR UPDATE
  USING (public.hub_pode_executar(auth.uid(), 'financeiro', NULL, 'editar'))
  WITH CHECK (public.hub_pode_executar(auth.uid(), 'financeiro', NULL, 'editar'));
CREATE POLICY spec069_remessas_delete ON public.remessas FOR DELETE
  USING (public.hub_pode_executar(auth.uid(), 'financeiro', NULL, 'deletar'));

-- contas_bancarias: já tinha policies restritas (contas_select/insert/update/delete,
-- admin/gerente/operador) só drop das PERMISSIVE "true" redundantes que as neutralizavam.
DROP POLICY IF EXISTS authenticated_insert_contas_bancarias ON public.contas_bancarias;
DROP POLICY IF EXISTS authenticated_select_contas_bancarias ON public.contas_bancarias;
DROP POLICY IF EXISTS authenticated_update_contas_bancarias ON public.contas_bancarias;
DROP POLICY IF EXISTS contas_select ON public.contas_bancarias;
DROP POLICY IF EXISTS contas_insert ON public.contas_bancarias;
DROP POLICY IF EXISTS contas_update ON public.contas_bancarias;
DROP POLICY IF EXISTS contas_delete ON public.contas_bancarias;

CREATE POLICY spec069_contas_bancarias_select ON public.contas_bancarias FOR SELECT
  USING (public.hub_pode_executar(auth.uid(), 'financeiro', NULL, 'visualizar'));
CREATE POLICY spec069_contas_bancarias_insert ON public.contas_bancarias FOR INSERT
  WITH CHECK (public.hub_pode_executar(auth.uid(), 'financeiro', NULL, 'criar'));
CREATE POLICY spec069_contas_bancarias_update ON public.contas_bancarias FOR UPDATE
  USING (public.hub_pode_executar(auth.uid(), 'financeiro', NULL, 'editar'))
  WITH CHECK (public.hub_pode_executar(auth.uid(), 'financeiro', NULL, 'editar'));
CREATE POLICY spec069_contas_bancarias_delete ON public.contas_bancarias FOR DELETE
  USING (public.hub_pode_executar(auth.uid(), 'financeiro', NULL, 'deletar'));

-- funcionarios_novo (RH) — hoje totalmente aberto para qualquer authenticated.
DROP POLICY IF EXISTS fn_novo_delete_auth ON public.funcionarios_novo;
DROP POLICY IF EXISTS fn_novo_insert_auth ON public.funcionarios_novo;
DROP POLICY IF EXISTS fn_novo_select_auth ON public.funcionarios_novo;
DROP POLICY IF EXISTS fn_novo_update_auth ON public.funcionarios_novo;
DROP POLICY IF EXISTS funcionarios_novo_authenticated_all ON public.funcionarios_novo;

CREATE POLICY spec069_funcionarios_novo_select ON public.funcionarios_novo FOR SELECT
  USING (public.hub_pode_executar(auth.uid(), 'rh', NULL, 'visualizar'));
CREATE POLICY spec069_funcionarios_novo_insert ON public.funcionarios_novo FOR INSERT
  WITH CHECK (public.hub_pode_executar(auth.uid(), 'rh', NULL, 'criar'));
CREATE POLICY spec069_funcionarios_novo_update ON public.funcionarios_novo FOR UPDATE
  USING (public.hub_pode_executar(auth.uid(), 'rh', NULL, 'editar'))
  WITH CHECK (public.hub_pode_executar(auth.uid(), 'rh', NULL, 'editar'));
CREATE POLICY spec069_funcionarios_novo_delete ON public.funcionarios_novo FOR DELETE
  USING (public.hub_pode_executar(auth.uid(), 'rh', NULL, 'deletar'));
