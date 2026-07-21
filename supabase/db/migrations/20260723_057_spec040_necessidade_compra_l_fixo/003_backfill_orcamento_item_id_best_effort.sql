-- Migration 20260723_057 - SPEC-040 - Item 3/4
--
-- Backfill best-effort de projeto_itens.orcamento_item_id/l_fixo para os
-- projeto_itens ja existentes (aprovados antes de 002_aprovar_orcamento_
-- financeiro_l_fixo.sql passar a gravar esse vinculo em novas aprovacoes).
--
-- Decisao do usuario (P-05, 21/07/2026): so preenche automaticamente os
-- casos INEQUIVOCOS -- quando o par (orcamento_id, produto_id) aparece
-- EXATAMENTE UMA VEZ em orcamento_itens para aquele orcamento. Quando o
-- mesmo produto aparece em 2+ posicoes do mesmo orcamento (ex.: L01 e L35
-- do exemplo de validacao da SPEC), nao ha como saber retroativamente qual
-- projeto_item corresponde a qual orcamento_item -- esses casos ficam
-- orcamento_item_id/l_fixo NULL PERMANENTEMENTE, sem adivinhar e sem gerar
-- relatorio de conferencia adicional (nao pedido pelo usuario).
--
-- Idempotente: o UPDATE so afeta linhas com orcamento_item_id IS NULL, entao
-- rodar esta migration novamente nao sobrescreve valores ja preenchidos
-- (nem os gravados por uma aprovacao nova via 002, nem os de uma execucao
-- anterior deste proprio backfill).
--
-- Pre-requisito: 001_projeto_itens_orcamento_item_id.sql aplicada.

WITH pares_unicos AS (
    -- Um par (orcamento_id, produto_id) e "inequivoco" quando aparece
    -- exatamente 1 vez em orcamento_itens para aquele orcamento. GROUP BY
    -- trata produto_id NULL como um valor igual a outro produto_id NULL, o
    -- que e o comportamento desejado aqui (2 itens de orcamento sem produto
    -- vinculado no mesmo orcamento tambem sao ambiguos entre si).
    -- MIN()/MAX() não existem para uuid neste Postgres — como HAVING COUNT(*) = 1
    -- garante exatamente 1 linha por grupo, (array_agg(...))[1] extrai o único
    -- valor existente sem precisar de um agregado de ordenação.
    SELECT
        oi.orcamento_id,
        oi.produto_id,
        (array_agg(oi.id))[1]        AS orcamento_item_id,
        (array_agg(oi.custom_id))[1] AS l_fixo
    FROM public.orcamento_itens oi
    GROUP BY oi.orcamento_id, oi.produto_id
    HAVING COUNT(*) = 1
)
UPDATE public.projeto_itens pi
SET orcamento_item_id = pu.orcamento_item_id,
    l_fixo = pu.l_fixo
FROM pares_unicos pu
WHERE pi.orcamento_id = pu.orcamento_id
  AND pi.produto_id IS NOT DISTINCT FROM pu.produto_id
  AND pi.orcamento_item_id IS NULL;
