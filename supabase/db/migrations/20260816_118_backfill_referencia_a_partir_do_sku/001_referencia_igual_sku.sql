-- Backfill de produtos.referencia a partir de produtos.sku.
--
-- Contexto: a coluna "referencia" está vazia em praticamente todo o
-- catálogo (0 de 4726 peças preenchidas). Desde 2026-08-11 (commits
-- 34943b6/2955d42, reafirmado em 76ad3a9), o rótulo "Referência" na UI do
-- Cadastro Lucenera lê/grava a coluna "sku", não "referencia" — por isso o
-- campo nunca tinha sido preenchido de fato. Outros sistemas que leiam
-- "referencia" diretamente (fora do Cadastro Lucenera) ficariam sem esse
-- dado. Este backfill espelha sku -> referencia (somente onde referencia
-- está vazia, sem sobrescrever nenhum valor existente) para que o dado
-- apareça consistente em qualquer sistema que consulte a coluna real.
--
-- Não altera nenhuma UI/frontend — é só sincronização de dado.

UPDATE produtos
SET referencia = sku
WHERE sku IS NOT NULL
  AND sku <> ''
  AND (referencia IS NULL OR referencia = '');
