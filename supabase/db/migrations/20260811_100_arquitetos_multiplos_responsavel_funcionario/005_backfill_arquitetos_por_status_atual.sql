-- Migration 20260811_100 — Parte 5
-- Backfill determinístico: cada projeto/orçamento com arquiteto_id
-- preenchido hoje vira 1 linha de 100% na tabela de junção nova — sem
-- ambiguidade, porque hoje só existe 1 arquiteto por registro.
--
-- NÃO inclui backfill de projetos.responsavel_funcionario_id: o texto
-- livre responsavel_nome tem só o primeiro nome (~15 valores distintos,
-- ex. "Marina", "Thairine"), e casar isso por nome contra funcionarios
-- é ambíguo demais pra rodar cego em produção — fica pra um passo manual
-- revisado à parte, fora desta migration.

INSERT INTO public.projeto_arquitetos (projeto_id, arquiteto_id, percentual)
SELECT id, arquiteto_id, 100
FROM public.projetos
WHERE arquiteto_id IS NOT NULL
ON CONFLICT (projeto_id, arquiteto_id) DO NOTHING;

INSERT INTO public.orcamento_arquitetos (orcamento_id, arquiteto_id, percentual)
SELECT id, arquiteto_id, 100
FROM public.orcamentos
WHERE arquiteto_id IS NOT NULL
ON CONFLICT (orcamento_id, arquiteto_id) DO NOTHING;
