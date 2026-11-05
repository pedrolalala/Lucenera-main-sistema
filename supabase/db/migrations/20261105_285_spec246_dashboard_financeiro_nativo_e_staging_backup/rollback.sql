-- Rollback da 285: volta a view ao join antigo com stg_duplicatas_vigentes, devolve as 2 tabelas ao schema public e restaura a função.
BEGIN;
CREATE OR REPLACE VIEW public.v_financeiro_realizado AS
 SELECT id,
    tipo,
    descricao,
    desc_sub_grupo,
    desc_grupo,
    natureza,
    status_pago,
    dt_pagamento,
    dt_vencimento,
    dt_emissao,
    vl_pago,
    vl_parcela,
    vl_desconto,
    empresa_id,
    cod_duplicata,
    tipo_custo,
    perfil
   FROM ( SELECT x.id,
            x.tipo,
            x.descricao,
            x.desc_sub_grupo,
            x.desc_grupo,
            x.natureza,
            x.status_pago,
            x.dt_pagamento,
            x.dt_vencimento,
            x.dt_emissao,
            x.vl_pago,
            x.vl_parcela,
            x.vl_desconto,
            x.empresa_id,
            x.cod_duplicata,
            x.tipo_custo,
            x.perfil
           FROM ( WITH pc AS (
                         SELECT plano_de_contas.id,
                            plano_de_contas.codigo_connect,
                            plano_de_contas.nome,
                            plano_de_contas.nivel,
                            plano_de_contas.parent_id
                           FROM plano_de_contas
                        ), hierarquia AS (
                         SELECT p3.id AS plano_contas_id,
                            COALESCE(p2.nome, p3.nome) AS desc_sub_grupo,
                            COALESCE(p1.nome, p2.nome, p3.nome) AS desc_grupo
                           FROM pc p3
                             LEFT JOIN pc p2 ON p2.id = p3.parent_id
                             LEFT JOIN pc p1 ON p1.id = p2.parent_id
                        ), negociacao_preferida AS (
                         SELECT n.id,
                            n.cod_duplicata,
                            n.tipo,
                            n.plano_contas_id,
                            n.empresa_id,
                            row_number() OVER (PARTITION BY n.cod_duplicata, n.tipo ORDER BY n.created_at) AS rn
                           FROM negociacoes n
                             JOIN stg_duplicatas_vigentes v ON v.cod_duplicata = n.cod_duplicata AND v.tipo = n.tipo
                        )
                 SELECT t.id,
                    t.tipo,
                    t.descricao,
                    h.desc_sub_grupo,
                    h.desc_grupo,
                        CASE
                            WHEN t.tipo = 'despesa'::transacao_tipo AND (h.desc_sub_grupo ~~* '%FILIPPO%'::text OR h.desc_sub_grupo ~~* '%MANOELLA%'::text OR t.descricao ~~* '%RETIRADA LUCRO%'::text OR t.descricao ~~* '%RETIRADA DE LUCRO%'::text OR t.descricao ~~* '%LUCRO DISTRIB%'::text) THEN 'distribuicao_lucro'::text
                            WHEN t.tipo = 'despesa'::transacao_tipo THEN 'despesa_operacional'::text
                            ELSE NULL::text
                        END AS natureza,
                    t.status_pago,
                    t.dt_pagamento,
                    t.dt_vencimento,
                    t.dt_emissao,
                    t.vl_pago,
                    t.vl_parcela,
                    t.vl_desconto,
                    np.empresa_id,
                    np.cod_duplicata,
                        CASE
                            WHEN t.tipo <> 'despesa'::transacao_tipo THEN NULL::text
                            WHEN h.desc_sub_grupo = ANY (ARRAY['FIXAS'::text, 'COM PESSOAL'::text, 'ADMINISTRATIVAS'::text, 'BANCARIAS'::text, 'VEICULOS'::text]) THEN 'fixo'::text
                            WHEN h.desc_sub_grupo = ANY (ARRAY['COM VENDAS'::text, 'PRODUTOS'::text]) THEN 'variavel'::text
                            ELSE 'outro'::text
                        END AS tipo_custo,
                    t.perfil
                   FROM transacoes t
                     JOIN negociacao_preferida np ON np.id = t.negociacao_id AND np.rn = 1
                     LEFT JOIN hierarquia h ON h.plano_contas_id = np.plano_contas_id
                  WHERE t.status_pago <> 2) x
          WHERE x.natureza IS DISTINCT FROM 'distribuicao_lucro'::text OR ( SELECT pode_ver_distribuicao_lucro() AS pode_ver_distribuicao_lucro)) y
  WHERE ( SELECT pode_acessar_sistema('dashboard-financeiro'::text) AS pode_acessar_sistema);
ALTER TABLE backup.staging_conta_pagar SET SCHEMA public;
ALTER TABLE backup.staging_conta_receber SET SCHEMA public;
CREATE OR REPLACE FUNCTION public.limpar_staging_processados()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    total_deletado INTEGER := 0;
BEGIN
    DELETE FROM staging_conta_pagar WHERE processado = TRUE AND importado_em < NOW() - INTERVAL '30 days';
    GET DIAGNOSTICS total_deletado = ROW_COUNT;
    DELETE FROM staging_conta_receber WHERE processado = TRUE AND importado_em < NOW() - INTERVAL '30 days';
    DELETE FROM staging_produtos WHERE processado = TRUE AND importado_em < NOW() - INTERVAL '30 days';
    DELETE FROM staging_pedido_compra WHERE processado = TRUE AND importado_em < NOW() - INTERVAL '30 days';
    RETURN total_deletado;
END;
$function$;
COMMIT;
