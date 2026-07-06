-- Migration 20260704_018 — Parte 5
-- Backfill de compatibilidade para orçamentos existentes.
--
-- Problema: com o guard ativado (004), orçamentos em 'aguardando_aprovacao'
-- ficam bloqueados para aprovação financeira até que passem por 'aprovado_cliente'.
--
-- Solução: orçamentos que JÁ FORAM processados (têm projeto_itens) ficam em 'aprovado'.
-- Orçamentos NÃO processados ainda ficam em 'aguardando_aprovacao' — precisarão
-- passar pelo fluxo de aprovação do cliente antes de avançar.
--
-- Este script NÃO força nenhum orçamento para 'aprovado_cliente' sem validação humana.
-- O vendedor deve usar enviar_orcamento_para_cliente() ou adm_aprovar_pelo_cliente()
-- para cada orçamento pendente que o cliente já confirmou verbalmente.

-- Verificação: quantos orçamentos estão em cada status
SELECT
    status,
    count(*) AS total
FROM public.orcamentos
GROUP BY status
ORDER BY total DESC;

-- Verificação: orçamentos em 'aguardando_aprovacao' que ainda NÃO foram processados
-- (não têm projeto_itens vinculados) — estes precisarão de ação manual
SELECT
    o.id,
    o.numero,
    o.status,
    o.created_at::date AS criado_em,
    coalesce(o.valor_total, 0) AS valor,
    count(pi.id) AS itens_projeto
FROM public.orcamentos o
LEFT JOIN public.projeto_itens pi ON pi.orcamento_id = o.id
WHERE o.status = 'aguardando_aprovacao'
GROUP BY o.id, o.numero, o.status, o.created_at, o.valor_total
ORDER BY o.created_at DESC;
