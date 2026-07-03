-- Migration 20260701_014 — Parte 1
-- Copia codigo_legado -> codigo_produto em todos os produtos onde codigo_produto é NULL.
--
-- Contexto: o frontend busca por codigo_produto, mas os dados históricos foram
-- importados apenas em codigo_legado. Ambos representam o mesmo identificador.

UPDATE public.produtos
SET codigo_produto = codigo_legado
WHERE codigo_produto IS NULL
  AND codigo_legado  IS NOT NULL;
