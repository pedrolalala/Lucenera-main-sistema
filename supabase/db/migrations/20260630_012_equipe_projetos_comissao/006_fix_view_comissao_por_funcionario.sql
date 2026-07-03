-- Migration 20260630_012 — Parte 6
-- Corrige vw_comissao_mensal para:
--   1. Usar data_entrada como base do mês (não created_at)
--   2. Detalhar por funcionário dentro da equipe (cada um com seu comissao_percentual)
--
-- Uma equipe pode ter N funcionários, cada um com % diferente.
-- Cada linha = 1 funcionário + 1 mês + soma dos projetos da equipe naquele mês.

DROP VIEW IF EXISTS public.vw_comissao_mensal;

CREATE VIEW public.vw_comissao_mensal AS
SELECT
  fn.id                                          AS funcionario_id,
  fn.nome                                        AS funcionario,
  ep.id                                          AS equipe_id,
  ep.equipes                                     AS equipe,
  ff.comissao_percentual,
  DATE_TRUNC('month', p.data_entrada)::date      AS mes,
  COUNT(p.id)                                    AS total_projetos,
  ROUND(SUM(p.valor_total), 2)                   AS valor_total_projetos,
  ROUND(
    SUM(p.valor_total * COALESCE(ff.comissao_percentual, 0) / 100.0),
    2
  )                                              AS comissao_calculada
FROM   public.projetos               p
JOIN   public.equipes_projetos       ep ON ep.id = p.equipe_id
JOIN   public.funcionarios_financeiro ff ON ff.equipes_id = ep.id
JOIN   public.funcionarios_novo       fn ON fn.id = ff.funcionario_id
WHERE  p.valor_total   > 0
  AND  p.data_entrada IS NOT NULL
  AND  fn.ativo IS TRUE
GROUP  BY
  fn.id,
  fn.nome,
  ep.id,
  ep.equipes,
  ff.comissao_percentual,
  DATE_TRUNC('month', p.data_entrada);

COMMENT ON VIEW public.vw_comissao_mensal IS
  'Comissão mensal por funcionário agrupada por data_entrada do projeto. '
  'Cada funcionário da equipe recebe sua própria % sobre o total da equipe no mês.';
