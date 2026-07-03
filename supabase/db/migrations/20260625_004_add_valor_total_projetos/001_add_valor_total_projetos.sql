-- Migration central: adicionar `projetos.valor_total`.
--
-- Motivo:
-- - `public.projeto_itens.trg_sync_valor_total` chama
--   `public.sync_projeto_valor_total()`.
-- - Essa função atualiza `public.projetos.valor_total` com a soma dos
--   subtotais de `public.projeto_itens`.

BEGIN;

ALTER TABLE public.projetos
  ADD COLUMN IF NOT EXISTS valor_total numeric(15,2);

ALTER TABLE public.projetos
  ALTER COLUMN valor_total SET DEFAULT 0;

UPDATE public.projetos
SET valor_total = 0
WHERE valor_total IS NULL;

UPDATE public.projetos p
SET valor_total = coalesce(pi.valor_total, 0)
FROM (
  SELECT
    projeto_id,
    sum(coalesce(subtotal, 0)) AS valor_total
  FROM public.projeto_itens
  GROUP BY projeto_id
) pi
WHERE p.id = pi.projeto_id
  AND p.valor_total IS DISTINCT FROM coalesce(pi.valor_total, 0);

ALTER TABLE public.projetos
  ALTER COLUMN valor_total SET NOT NULL;

COMMENT ON COLUMN public.projetos.valor_total IS
  'Valor total denormalizado do projeto, sincronizado por public.sync_projeto_valor_total() a partir de public.projeto_itens.';

COMMIT;
