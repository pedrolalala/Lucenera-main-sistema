-- Migration 20260718_052 (SPEC-036)
-- Isolamento de clientes do Catalogo Ubiqua por representante individual.
-- Adiciona informacoes_cliente_ubiqua.cadastrado_por_usuario_id (FK usuarios_ubiqua.id)
-- e substitui as policies antigas (USING true, abertas para anon/authenticated)
-- por policies SELECT/INSERT/UPDATE/DELETE restritas ao dono do cadastro ou a
-- usuarios_ubiqua.nivel_acesso IN ('admin','interno'). A policy pre-existente
-- "Permitir leitura admin_gerente" (staff central Lucenera) e mantida sem alteracao.
-- Clientes cadastrados antes desta migration ficam com cadastrado_por_usuario_id
-- NULL (sem backfill automatico) ate decisao manual de atribuicao.

BEGIN;

ALTER TABLE public.informacoes_cliente_ubiqua
  ADD COLUMN IF NOT EXISTS cadastrado_por_usuario_id uuid REFERENCES public.usuarios_ubiqua(id);

CREATE INDEX IF NOT EXISTS idx_informacoes_cliente_ubiqua_dono
  ON public.informacoes_cliente_ubiqua (cadastrado_por_usuario_id);

-- Remove policies antigas, abertas demais para anon/authenticated sem filtro por dono
DROP POLICY IF EXISTS "Permitir leitura anon e auth" ON public.informacoes_cliente_ubiqua;
DROP POLICY IF EXISTS all_select_informacoes_cliente ON public.informacoes_cliente_ubiqua;
DROP POLICY IF EXISTS anon_insert_informacoes_cliente ON public.informacoes_cliente_ubiqua;
DROP POLICY IF EXISTS anon_update_informacoes_cliente ON public.informacoes_cliente_ubiqua;
DROP POLICY IF EXISTS auth_insert_informacoes_cliente ON public.informacoes_cliente_ubiqua;
DROP POLICY IF EXISTS auth_update_informacoes_cliente ON public.informacoes_cliente_ubiqua;
-- Mantem "Permitir leitura admin_gerente" (staff central Lucenera admin/gerente) sem alteracao.

CREATE POLICY select_informacoes_cliente_por_representante
  ON public.informacoes_cliente_ubiqua
  FOR SELECT TO authenticated
  USING (
    cadastrado_por_usuario_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.usuarios_ubiqua u
      WHERE u.id = auth.uid() AND u.nivel_acesso = ANY (ARRAY['admin','interno']::public.nivel_acesso_tipo[])
    )
  );

CREATE POLICY insert_informacoes_cliente_por_representante
  ON public.informacoes_cliente_ubiqua
  FOR INSERT TO authenticated
  WITH CHECK (cadastrado_por_usuario_id = auth.uid());

CREATE POLICY update_informacoes_cliente_por_representante
  ON public.informacoes_cliente_ubiqua
  FOR UPDATE TO authenticated
  USING (
    cadastrado_por_usuario_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.usuarios_ubiqua u
      WHERE u.id = auth.uid() AND u.nivel_acesso = ANY (ARRAY['admin','interno']::public.nivel_acesso_tipo[])
    )
  )
  WITH CHECK (
    cadastrado_por_usuario_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.usuarios_ubiqua u
      WHERE u.id = auth.uid() AND u.nivel_acesso = ANY (ARRAY['admin','interno']::public.nivel_acesso_tipo[])
    )
  );

CREATE POLICY delete_informacoes_cliente_por_representante
  ON public.informacoes_cliente_ubiqua
  FOR DELETE TO authenticated
  USING (
    cadastrado_por_usuario_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.usuarios_ubiqua u
      WHERE u.id = auth.uid() AND u.nivel_acesso = ANY (ARRAY['admin','interno']::public.nivel_acesso_tipo[])
    )
  );

COMMIT;
