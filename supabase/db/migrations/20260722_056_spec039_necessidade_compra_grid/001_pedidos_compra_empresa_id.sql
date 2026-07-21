-- Migration 20260722_056 - SPEC-039 (P-03) - Item 1/4
--
-- Decisao do usuario (P-03, 21/07/2026): Alternativa A -- nova coluna
-- pedidos_compra.empresa_id, preenchida automaticamente dentro das RPCs de
-- criacao de pedido (002_criar_pedido_compra_empresa_automatica.sql), sem
-- input manual no frontend. Mesmo padrao ja usado por orcamentos.empresa_id/
-- projetos.empresa_id/boletos.empresa_id (FK direta para empresas(id)).

ALTER TABLE public.pedidos_compra
  ADD COLUMN IF NOT EXISTS empresa_id uuid REFERENCES public.empresas(id);

COMMENT ON COLUMN public.pedidos_compra.empresa_id IS
'SPEC-039 (P-03). Empresa/filial que efetuou a compra -- preenchida
automaticamente pela RPC (criar_pedido_compra_de_necessidade/
criar_pedido_compra_lote) a partir de usuarios.empresa_id do usuario
autenticado (auth.uid()). Nao ha input manual no frontend para este campo.';

CREATE INDEX IF NOT EXISTS idx_pc_empresa ON public.pedidos_compra (empresa_id);
