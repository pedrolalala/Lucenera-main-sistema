-- Migration 20260630_012 — Parte 3
-- View de comissão mensal por funcionário.
--
-- Lógica:
--   Para cada projeto vinculado a uma equipe, cada funcionário daquela equipe
--   recebe comissao_percentual % sobre o valor_total do projeto.
--
-- Agrupamento mensal por data_entrada do projeto (ou created_at se nula).
-- Apenas projetos com equipe_id preenchido entram no cálculo.

CREATE OR REPLACE VIEW public.vw_comissao_mensal AS
SELECT
  fn.id                                                        AS funcionario_id,
  fn.nome                                                      AS funcionario,
  ep.id                                                        AS equipe_id,
  ep.equipes                                                   AS equipe,
  ff.comissao_percentual,
  DATE_TRUNC('month',
    COALESCE(p.data_entrada::timestamptz, p.created_at))::date AS mes,
  COUNT(p.id)                                                  AS total_projetos,
  ROUND(SUM(p.valor_total), 2)                                 AS valor_total_projetos,
  ROUND(
    SUM(p.valor_total * COALESCE(ff.comissao_percentual, 0) / 100.0),
    2
  )                                                            AS comissao_calculada
FROM   public.projetos p
JOIN   public.equipes_projetos        ep ON ep.id = p.equipe_id
JOIN   public.funcionarios_financeiro ff ON ff.equipes_id = ep.id
JOIN   public.funcionarios_novo       fn ON fn.id = ff.funcionario_id
WHERE  p.valor_total > 0
  AND  fn.ativo IS TRUE
GROUP  BY
  fn.id,
  fn.nome,
  ep.id,
  ep.equipes,
  ff.comissao_percentual,
  DATE_TRUNC('month', COALESCE(p.data_entrada::timestamptz, p.created_at));

COMMENT ON VIEW public.vw_comissao_mensal IS
  'Comissão mensal por funcionário calculada sobre valor_total dos projetos '
  'vinculados à equipe do funcionário. Requer projetos.equipe_id preenchido.';
