-- Migration 20260716_046 — Parte 1
-- Pedido do usuário: estoque_itens.quantidade (local='Estoque') deve sempre
-- ser igual a produtos.estoque_total, e (quantidade - quantidade_reservada)
-- deve sempre ser igual a produtos.estoque_disponivel — de forma permanente,
-- não só numa sincronização pontual.
--
-- Causa raiz do desalinhamento encontrado: vw_necessidade_compra soma
-- estoque_itens.quantidade de TODOS os locais por produto (Estoque +
-- Showroom). O script de import anterior só atualizava/criava a linha de
-- Showroom quando o novo valor era > 0 — quando um produto deixava de ter
-- showroom, a linha antiga ficava com quantidade desatualizada, inflando a
-- soma. Esta migration consolida tudo na linha local='Estoque' (que passa a
-- representar o estoque_total inteiro) e zera qualquer linha de Showroom
-- remanescente, para a soma nunca mais divergir do total.

CREATE OR REPLACE FUNCTION public.fn_sync_estoque_itens_from_produtos()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
BEGIN
  -- Sem GREATEST(0, ...) de propósito: quando a planilha de origem tem
  -- Disponível > Total (inconsistência do dado de origem), a única forma de
  -- manter quantidade - quantidade_reservada = estoque_disponivel sempre
  -- verdadeiro é deixar quantidade_reservada ficar negativa nesses casos.
  INSERT INTO public.estoque_itens (produto_id, local, quantidade, quantidade_reservada)
  VALUES (
    NEW.id,
    'Estoque',
    COALESCE(NEW.estoque_total, 0),
    COALESCE(NEW.estoque_total, 0) - COALESCE(NEW.estoque_disponivel, 0)
  )
  ON CONFLICT (produto_id, local) DO UPDATE
  SET quantidade = EXCLUDED.quantidade,
      quantidade_reservada = EXCLUDED.quantidade_reservada,
      atualizado_em = now();

  -- Zera qualquer linha de Showroom remanescente deste produto, para não
  -- inflar a soma usada por vw_necessidade_compra (que agrega todos os locais).
  UPDATE public.estoque_itens
  SET quantidade = 0, atualizado_em = now()
  WHERE produto_id = NEW.id AND local = 'Showroom' AND quantidade <> 0;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.fn_sync_estoque_itens_from_produtos IS
  'Mantém estoque_itens (local=Estoque) sempre igual a produtos.estoque_total/'
  'estoque_disponivel — link permanente pedido pelo usuário em 2026-07-16.';

DROP TRIGGER IF EXISTS trg_sync_estoque_itens_from_produtos ON public.produtos;
CREATE TRIGGER trg_sync_estoque_itens_from_produtos
  AFTER INSERT OR UPDATE OF estoque_total, estoque_disponivel
  ON public.produtos
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_sync_estoque_itens_from_produtos();

-- Backfill: aplica a mesma regra a todos os produtos já existentes.
WITH alvo AS (
  SELECT id, estoque_total, estoque_disponivel FROM public.produtos
)
INSERT INTO public.estoque_itens (produto_id, local, quantidade, quantidade_reservada)
SELECT
  id,
  'Estoque',
  COALESCE(estoque_total, 0),
  COALESCE(estoque_total, 0) - COALESCE(estoque_disponivel, 0)
FROM alvo
ON CONFLICT (produto_id, local) DO UPDATE
SET quantidade = EXCLUDED.quantidade,
    quantidade_reservada = EXCLUDED.quantidade_reservada,
    atualizado_em = now();

UPDATE public.estoque_itens
SET quantidade = 0, atualizado_em = now()
WHERE local = 'Showroom' AND quantidade <> 0;
