-- Migration 20260719_053 — Parte 1
-- SPEC-037: rastreio de necessidade de importação no catálogo Ubiqua.
--
-- Snapshot no momento do pedido de se a variante escolhida estava sem
-- estoque (revenda_ubiqua.disponivel <= 0). Não é recalculado depois —
-- necessário porque revenda_ubiqua.disponivel muda com reposição de
-- estoque, e perderíamos o histórico de demanda de backorder se
-- olhássemos só o disponivel atual.

ALTER TABLE public.itens_orcamento_ubiqua
  ADD COLUMN IF NOT EXISTS sem_estoque_no_pedido boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.itens_orcamento_ubiqua.sem_estoque_no_pedido IS
  'Snapshot no momento do pedido: true quando revenda_ubiqua.disponivel da variante '
  'escolhida era <= 0 no momento em que o item foi salvo no orçamento. Não é '
  'recalculado depois — não usar revenda_ubiqua.disponivel atual para saber se um '
  'pedido antigo era backorder. SPEC-037.';
