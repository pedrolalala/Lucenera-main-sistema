-- Migration 20260721_055 - Correcao retroativa de base (achado pre-SPEC-038)
-- Contexto: supabase/db/migrations/20260710_031_spec020_operacionalizacao_compras/004_pedidos_compra.sql
-- foi redigida em 2026-07-10 mas nunca havia sido aplicada no banco real ate 2026-07-21
-- (achado durante a implementacao da SPEC-038). Como pedido_compra_itens ja existia
-- (criada por outra migration anterior, sem a tabela pedidos_compra), a FK inline do
-- 004_pedidos_compra.sql nao pegou retroativamente. Esta migration adiciona a FK que
-- faltava, agora que pedidos_compra existe.
-- Idempotente: verifica se a constraint ja existe antes de criar.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'pedido_compra_itens_pedido_id_fkey'
      AND conrelid = 'public.pedido_compra_itens'::regclass
  ) THEN
    ALTER TABLE public.pedido_compra_itens
      ADD CONSTRAINT pedido_compra_itens_pedido_id_fkey
      FOREIGN KEY (pedido_id) REFERENCES public.pedidos_compra(id) ON DELETE CASCADE;
  END IF;
END $$;
