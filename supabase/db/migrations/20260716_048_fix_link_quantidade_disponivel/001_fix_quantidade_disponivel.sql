-- Migration 20260716_048 — Parte 1
-- Correção do link produtos <-> estoque_itens (pedido do usuário, reforçado
-- em 2026-07-16): a migration 20260716_046 criou o trigger de sincronização
-- mas só setava estoque_itens.quantidade e quantidade_reservada. A coluna
-- estoque_itens.quantidade_disponivel NÃO é uma coluna gerada/computada —
-- é uma coluna normal, própria, que o trigger nunca preenchia. Resultado:
-- ficou NULL nas 4.725 linhas de local='Estoque' (confirmado por query
-- direta com IS DISTINCT FROM — a checagem anterior usava "<>", que trata
-- comparação com NULL como "sem diferença" e escondeu o bug).
--
-- Fix: o trigger agora seta quantidade_disponivel = produtos.estoque_disponivel
-- diretamente (fonte da verdade), e quantidade_reservada passa a ser
-- derivada como quantidade - quantidade_disponivel (em vez do inverso),
-- garantindo por construção que quantidade - quantidade_reservada =
-- quantidade_disponivel = estoque_disponivel sempre.

CREATE OR REPLACE FUNCTION public.fn_sync_estoque_itens_from_produtos()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
BEGIN
  INSERT INTO public.estoque_itens (produto_id, local, quantidade, quantidade_disponivel, quantidade_reservada)
  VALUES (
    NEW.id,
    'Estoque',
    COALESCE(NEW.estoque_total, 0),
    COALESCE(NEW.estoque_disponivel, 0),
    COALESCE(NEW.estoque_total, 0) - COALESCE(NEW.estoque_disponivel, 0)
  )
  ON CONFLICT (produto_id, local) DO UPDATE
  SET quantidade = EXCLUDED.quantidade,
      quantidade_disponivel = EXCLUDED.quantidade_disponivel,
      quantidade_reservada = EXCLUDED.quantidade_reservada,
      atualizado_em = now();

  -- Zera qualquer linha de Showroom remanescente deste produto (quantidade,
  -- disponível e reservada), para não inflar somas que agregam todos os locais.
  UPDATE public.estoque_itens
  SET quantidade = 0, quantidade_disponivel = 0, quantidade_reservada = 0, atualizado_em = now()
  WHERE produto_id = NEW.id AND local = 'Showroom'
    AND (quantidade <> 0 OR quantidade_disponivel IS DISTINCT FROM 0 OR quantidade_reservada <> 0);

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.fn_sync_estoque_itens_from_produtos IS
  'Mantém estoque_itens (local=Estoque) sempre igual a produtos.estoque_total/'
  'estoque_disponivel — link permanente pedido pelo usuário em 2026-07-16. '
  'Fix 20260716_048: quantidade_disponivel agora é setada diretamente (não é '
  'coluna gerada) — antes ficava NULL indefinidamente.';

-- Backfill: aplica a correção a todas as linhas já existentes.
WITH alvo AS (
  SELECT id, estoque_total, estoque_disponivel FROM public.produtos
)
INSERT INTO public.estoque_itens (produto_id, local, quantidade, quantidade_disponivel, quantidade_reservada)
SELECT
  id,
  'Estoque',
  COALESCE(estoque_total, 0),
  COALESCE(estoque_disponivel, 0),
  COALESCE(estoque_total, 0) - COALESCE(estoque_disponivel, 0)
FROM alvo
ON CONFLICT (produto_id, local) DO UPDATE
SET quantidade = EXCLUDED.quantidade,
    quantidade_disponivel = EXCLUDED.quantidade_disponivel,
    quantidade_reservada = EXCLUDED.quantidade_reservada,
    atualizado_em = now();

UPDATE public.estoque_itens
SET quantidade = 0, quantidade_disponivel = 0, quantidade_reservada = 0, atualizado_em = now()
WHERE local = 'Showroom'
  AND (quantidade <> 0 OR quantidade_disponivel IS DISTINCT FROM 0 OR quantidade_reservada <> 0);
