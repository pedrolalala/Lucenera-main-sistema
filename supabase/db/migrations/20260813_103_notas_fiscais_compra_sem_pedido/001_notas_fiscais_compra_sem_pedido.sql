-- SPEC-088: permite registrar entrada de nota fiscal de compra sem pedido
-- de compra vinculado.
--
-- Contexto: EntradaNotaFiscal.tsx (Necessidade de Compra) hoje só libera o
-- formulário de registro depois de localizar um pedido de compra existente
-- (pedido_compra_id era NOT NULL). Relato do usuário (reunião 11/08/2026):
-- existem compras que chegam fisicamente sem nunca terem passado por um
-- pedido formal no sistema, e mesmo assim precisam de entrada de NF.
--
-- Fix: pedido_compra_id vira nullable; fornecedor_id/empresa_id/produto_id
-- novos, preenchidos só no modo avulso (sem pedido) — mesmo padrão de FK já
-- usado em pedidos_compra (empresa_id, fornecedor_id -> contatos).
-- produto_id fica opcional mesmo no modo avulso (pode ser vinculado depois).

ALTER TABLE public.notas_fiscais_compra
  ALTER COLUMN pedido_compra_id DROP NOT NULL,
  ADD COLUMN fornecedor_id uuid REFERENCES public.contatos(id),
  ADD COLUMN empresa_id uuid REFERENCES public.empresas(id),
  ADD COLUMN produto_id uuid REFERENCES public.produtos(id),
  ADD CONSTRAINT notas_fiscais_compra_origem_check
    CHECK (pedido_compra_id IS NOT NULL OR fornecedor_id IS NOT NULL);
