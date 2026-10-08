-- SPEC-186 (08/10/2026): saldo de férias vinha 0 para quase todos — a view só somava 30 dias por
-- linha cadastrada à mão em periodos_aquisitivos (7 pessoas, 1 período cada).
-- Regra provisória aprovada pelo usuário (até o controle em PDF definir a regra completa):
--   * período aquisitivo = cada 12 meses a partir de funcionarios.data_admissao;
--   * conta só o ÚLTIMO período completo: 30 dias de direito;
--   * gozado = férias Aprovadas com data_inicio depois do fim desse período;
--   * menos de 1 ano de casa, PJ, sem admissão ou admissão inválida (< 1950) = fora da view
--     (a tela trata ausência como saldo 0).
-- Colunas antigas mantidas com os mesmos nomes/tipos; novas no fim (data_limite_gozo já era
-- lida pelo aviso "férias a vencer" da página inicial e não existia).
-- DROP + CREATE: a view nova tem colunas a mais no fim (CREATE OR REPLACE aceitaria, mas o
-- tipo das antigas é fixado aqui explicitamente). Sem BEGIN/COMMIT no texto.
DROP VIEW IF EXISTS public.vw_controle_ferias_clt;
CREATE VIEW public.vw_controle_ferias_clt AS
WITH base AS (
  SELECT f.id AS funcionario_id,
         f.nome AS funcionario_nome,
         f.data_admissao,
         date_part('year', age(current_date, f.data_admissao))::int AS anos_completos
    FROM funcionarios f
   WHERE f.status = 'Ativo'
     AND f.data_admissao >= DATE '1950-01-01'
     AND f.data_admissao <= current_date
     AND COALESCE(f.tipo_contratacao, 'CLT') <> 'PJ'
), periodo AS (
  SELECT b.*,
         (b.data_admissao + make_interval(years => b.anos_completos - 1))::date AS periodo_inicio,
         (b.data_admissao + make_interval(years => b.anos_completos) - interval '1 day')::date AS periodo_fim
    FROM base b
   WHERE b.anos_completos >= 1
), resumo AS (
  SELECT p.*,
         COALESCE((SELECT sum(fer.dias)
                     FROM ferias fer
                    WHERE fer.funcionario_id = p.funcionario_id
                      AND fer.status = 'Aprovado'
                      AND fer.data_inicio > p.periodo_fim), 0)::bigint AS gozado
    FROM periodo p
)
SELECT r.funcionario_id,
       r.funcionario_nome,
       30::bigint AS direito_total_acumulado,
       r.gozado AS total_gozado,
       (30 - r.gozado)::bigint AS saldo_disponivel,
       r.periodo_inicio,
       r.periodo_fim,
       (r.periodo_fim + interval '12 months')::date AS data_limite_gozo
  FROM resumo r;

GRANT ALL ON public.vw_controle_ferias_clt TO anon, authenticated, service_role;
NOTIFY pgrst, 'reload schema';
