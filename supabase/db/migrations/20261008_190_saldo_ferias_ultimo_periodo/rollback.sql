-- Rollback da 20261008_190: definição anterior (saldo por periodos_aquisitivos cadastrados).
DROP VIEW IF EXISTS public.vw_controle_ferias_clt;
CREATE VIEW public.vw_controle_ferias_clt AS
 WITH resumo_periodos AS (
         SELECT pa.funcionario_id,
            f.nome AS funcionario_nome,
            count(pa.id) * 30 AS direito_total_acumulado,
            COALESCE(( SELECT sum(fer.dias) AS sum
                   FROM ferias fer
                  WHERE fer.funcionario_id = pa.funcionario_id AND fer.status = 'Aprovado'::text), 0::bigint) AS total_gozado
           FROM periodos_aquisitivos pa
             JOIN funcionarios f ON pa.funcionario_id = f.id
          GROUP BY pa.funcionario_id, f.nome
        )
 SELECT funcionario_id,
    funcionario_nome,
    direito_total_acumulado,
    total_gozado,
    direito_total_acumulado - total_gozado AS saldo_disponivel
   FROM resumo_periodos;
GRANT ALL ON public.vw_controle_ferias_clt TO anon, authenticated, service_role;
NOTIFY pgrst, 'reload schema';
