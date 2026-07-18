-- Migration 20260715_041 — Parte 1
-- SPEC-026 (reunião Filippo/Pedro 13-07-2026): prazo de entrega por marca/produto,
-- múltiplo de compra (MOQ / "caixa fechada") e estoque mínimo (ponto de reposição).
--
-- Nenhuma dessas colunas existia no schema antes desta migration — confirmado
-- por busca em 01_schema_full.sql. Valores ficam NULL/default até serem
-- preenchidos manualmente (a IA não tem os prazos reais por marca/fornecedor).

ALTER TABLE public.marcas
  ADD COLUMN IF NOT EXISTS prazo_entrega_dias integer;

COMMENT ON COLUMN public.marcas.prazo_entrega_dias IS
  'Prazo médio de entrega em dias úteis para produtos desta marca/fornecedor. '
  'Usado como fallback quando produtos.prazo_entrega_dias é nulo. SPEC-026.';

ALTER TABLE public.produtos
  ADD COLUMN IF NOT EXISTS prazo_entrega_dias integer,
  ADD COLUMN IF NOT EXISTS multiplo_compra integer DEFAULT 1 NOT NULL,
  ADD COLUMN IF NOT EXISTS estoque_minimo numeric(15,3) DEFAULT 0 NOT NULL;

COMMENT ON COLUMN public.produtos.prazo_entrega_dias IS
  'Prazo de entrega em dias úteis específico deste produto (override de marcas.prazo_entrega_dias). SPEC-026.';
COMMENT ON COLUMN public.produtos.multiplo_compra IS
  'Múltiplo de compra / MOQ ("caixa fechada") — pedidos devem ser arredondados '
  'para o múltiplo mais próximo deste valor. Default 1 (sem restrição). SPEC-026.';
COMMENT ON COLUMN public.produtos.estoque_minimo IS
  'Ponto de reposição — quando estoque_disponivel cair abaixo deste valor, '
  'o produto deve gerar alerta de compra independente de venda pendente. SPEC-026.';

ALTER TABLE public.produtos
  ADD CONSTRAINT chk_produtos_multiplo_compra_positivo CHECK (multiplo_compra >= 1);
