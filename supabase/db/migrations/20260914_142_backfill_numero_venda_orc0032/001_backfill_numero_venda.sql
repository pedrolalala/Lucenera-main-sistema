-- SPEC-136: backfill de numero_venda para orcamentos ja aprovados ANTES da
-- migration da SPEC-136 (aplicada 2026-09-14) -- o trigger/RPC so gera
-- numero_venda no momento da aprovacao, entao quem ja tinha aprovado antes
-- ficou sem. Confirmado com o usuario e pela query direta no banco: o
-- UNICO orcamento em 'Orcamento Aprovado' sem numero_venda hoje e o
-- ORC-0032 (natureza_operacao = 'venda').
--
-- Mesma logica de geracao usada dentro de aprovar_orcamento_financeiro
-- (sequencia global, formato VENDA-0001) -- so que aqui roda pra um
-- orcamento que ja esta aprovado, sem reprocessar itens/parcelas/boletos
-- (que ja existem e nao devem ser tocados).
--
-- Generico o suficiente pra cobrir qualquer outro caso igual que apareca
-- no futuro (orcamento 'Orcamento Aprovado', natureza_operacao = 'venda',
-- numero_venda NULL) -- nao trava especificamente no ORC-0032.

BEGIN;

WITH alvo AS (
  SELECT id,
    'VENDA-' || LPAD(
      (
        ROW_NUMBER() OVER (ORDER BY created_at)
        + COALESCE((
            SELECT MAX(CAST(SUBSTRING(numero_venda FROM 7) AS INTEGER))
            FROM public.orcamentos
            WHERE numero_venda LIKE 'VENDA-%' AND numero_venda ~ '^VENDA-\d+$'
          ), 0)
      )::text,
      4, '0'
    ) AS novo_numero_venda
  FROM public.orcamentos
  WHERE status = 'Orçamento Aprovado'
    -- mesma checagem da RPC (aprovar_orcamento_financeiro): só o ramo
    -- 'devolucao' é excluído; NULL/qualquer outro valor conta como venda.
    AND COALESCE(natureza_operacao, 'venda') <> 'devolucao'
    AND numero_venda IS NULL
)
UPDATE public.orcamentos o
SET numero_venda = alvo.novo_numero_venda
FROM alvo
WHERE o.id = alvo.id;

COMMIT;
