-- Rollback SPEC-191 / migration 194.
DROP POLICY IF EXISTS producao_pedidos_insert ON public.producao_pedidos;
CREATE POLICY producao_pedidos_insert ON public.producao_pedidos FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS producao_pedidos_update ON public.producao_pedidos;
CREATE POLICY producao_pedidos_update ON public.producao_pedidos FOR UPDATE TO authenticated USING (true);
DROP POLICY IF EXISTS producao_pedido_anexos_insert ON public.producao_pedido_anexos;
CREATE POLICY producao_pedido_anexos_insert ON public.producao_pedido_anexos FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS producao_pedido_anexos_delete ON public.producao_pedido_anexos;
CREATE POLICY producao_pedido_anexos_delete ON public.producao_pedido_anexos FOR DELETE TO authenticated USING (true);
DROP POLICY IF EXISTS producao_pedido_edicoes_insert ON public.producao_pedido_edicoes;
CREATE POLICY producao_pedido_edicoes_insert ON public.producao_pedido_edicoes FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS producao_pedido_handoffs_insert ON public.producao_pedido_handoffs;
CREATE POLICY producao_pedido_handoffs_insert ON public.producao_pedido_handoffs FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS producao_pedido_ocorrencias_insert ON public.producao_pedido_ocorrencias;
CREATE POLICY producao_pedido_ocorrencias_insert ON public.producao_pedido_ocorrencias FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS producao_pedido_ocorrencias_update ON public.producao_pedido_ocorrencias;
CREATE POLICY producao_pedido_ocorrencias_update ON public.producao_pedido_ocorrencias FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS producao_pedido_prazo_alteracoes_insert ON public.producao_pedido_prazo_alteracoes;
CREATE POLICY producao_pedido_prazo_alteracoes_insert ON public.producao_pedido_prazo_alteracoes FOR INSERT TO authenticated WITH CHECK (true);
DROP FUNCTION IF EXISTS public.producao_pode_alterar();
DROP TABLE IF EXISTS public.producao_editores;
-- Colunas de inativação e data_venda da view ficam (inofensivas); para tirar a coluna da view,
-- reaplicar 20261006_185_cadastro_peca_abas_setores/001 depois de DROP VIEW.
