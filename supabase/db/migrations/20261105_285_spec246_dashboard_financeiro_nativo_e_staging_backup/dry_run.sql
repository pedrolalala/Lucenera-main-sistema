-- Dry-run da 285: compara a view ANTES x DEPOIS (sem o filtro de permissão), prova que lançamento novo do sistema aparece e DESFAZ. Termina em ROLLBACK.
BEGIN;
CREATE TEMP VIEW _vfr_antes AS
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
          WHERE x.natureza IS DISTINCT FROM 'distribuicao_lucro'::text OR ( SELECT pode_ver_distribuicao_lucro() AS pode_ver_distribuicao_lucro)) y;

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
                            row_number() OVER (PARTITION BY CASE WHEN v.cod_duplicata IS NOT NULL AND n.created_at <= coalesce((SELECT e.encerrado_em FROM connect_financeiro_encerrado e LIMIT 1), 'infinity'::timestamptz) THEN n.cod_duplicata::text ELSE n.id::text END, n.tipo ORDER BY n.created_at) AS rn
                           FROM negociacoes n
                             LEFT JOIN stg_duplicatas_vigentes v ON v.cod_duplicata = n.cod_duplicata AND v.tipo = n.tipo
                          WHERE (v.cod_duplicata IS NOT NULL AND n.created_at <= coalesce((SELECT e.encerrado_em FROM connect_financeiro_encerrado e LIMIT 1), 'infinity'::timestamptz))
                             OR n.created_at > coalesce((SELECT e.encerrado_em FROM connect_financeiro_encerrado e LIMIT 1), 'infinity'::timestamptz)
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

ALTER TABLE public.staging_conta_pagar SET SCHEMA backup;
ALTER TABLE public.staging_conta_receber SET SCHEMA backup;

CREATE OR REPLACE FUNCTION public.limpar_staging_processados()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    total_deletado INTEGER := 0;
BEGIN
    -- staging_conta_pagar / staging_conta_receber foram para o schema backup (SPEC-246); aqui só as duas que ainda são staging.
    DELETE FROM staging_produtos
    WHERE processado = TRUE
    AND importado_em < NOW() - INTERVAL '30 days';
    GET DIAGNOSTICS total_deletado = ROW_COUNT;

    DELETE FROM staging_pedido_compra
    WHERE processado = TRUE
    AND importado_em < NOW() - INTERVAL '30 days';

    RETURN total_deletado;
END;
$function$;

CREATE TEMP VIEW _vfr_depois AS
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
                            row_number() OVER (PARTITION BY CASE WHEN v.cod_duplicata IS NOT NULL AND n.created_at <= coalesce((SELECT e.encerrado_em FROM connect_financeiro_encerrado e LIMIT 1), 'infinity'::timestamptz) THEN n.cod_duplicata::text ELSE n.id::text END, n.tipo ORDER BY n.created_at) AS rn
                           FROM negociacoes n
                             LEFT JOIN stg_duplicatas_vigentes v ON v.cod_duplicata = n.cod_duplicata AND v.tipo = n.tipo
                          WHERE (v.cod_duplicata IS NOT NULL AND n.created_at <= coalesce((SELECT e.encerrado_em FROM connect_financeiro_encerrado e LIMIT 1), 'infinity'::timestamptz))
                             OR n.created_at > coalesce((SELECT e.encerrado_em FROM connect_financeiro_encerrado e LIMIT 1), 'infinity'::timestamptz)
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
          WHERE x.natureza IS DISTINCT FROM 'distribuicao_lucro'::text OR ( SELECT pode_ver_distribuicao_lucro() AS pode_ver_distribuicao_lucro)) y;
DO $$
DECLARE a bigint; d bigint; sa numeric; sd numeric; n1 uuid; n2 uuid; n3 uuid; e3 uuid; k bigint;
BEGIN
  SELECT count(*), coalesce(sum(vl_pago),0) INTO a, sa FROM _vfr_antes;
  SELECT count(*), coalesce(sum(vl_pago),0) INTO d, sd FROM _vfr_depois;
  RAISE NOTICE 'dados existentes: antes % linhas / pago % | depois % linhas / pago % -> %', a, sa, d, sd, CASE WHEN a = d AND sa = sd THEN 'IGUAL (ok)' ELSE 'DIFERENTE (ERRO)' END;
  -- duas duplicatas NOVAS do sistema, sem cod_duplicata legado, com a mesma empresa/tipo: as duas precisam aparecer
  INSERT INTO public.negociacoes (empresa_id, tipo, total_parc, cod_duplicata) SELECT empresa_id, 'receita', 1, 999001 FROM public.negociacoes LIMIT 1 RETURNING id INTO n1;
  INSERT INTO public.negociacoes (empresa_id, tipo, total_parc, cod_duplicata) SELECT empresa_id, 'receita', 1, 999002 FROM public.negociacoes LIMIT 1 RETURNING id INTO n2;
  -- terceira: MESMO numero de uma duplicata antiga (vigente), mas de outra empresa
  SELECT x.cod_duplicata, (SELECT e.id FROM public.empresas e WHERE e.id <> x.empresa_id AND NOT EXISTS (SELECT 1 FROM public.negociacoes y WHERE y.empresa_id = e.id AND y.cod_duplicata = x.cod_duplicata AND y.tipo = x.tipo) LIMIT 1)
    INTO k, e3 FROM public.negociacoes x JOIN public.stg_duplicatas_vigentes v ON v.cod_duplicata = x.cod_duplicata AND v.tipo = x.tipo WHERE x.tipo = 'receita' LIMIT 1;
  INSERT INTO public.negociacoes (empresa_id, tipo, total_parc, cod_duplicata) VALUES (e3, 'receita', 1, k) RETURNING id INTO n3;
  INSERT INTO public.transacoes (data_transacao, descricao, tipo, valor, vl_parcela, vl_pago, status_pago, negociacao_id, dt_vencimento, dt_pagamento) VALUES (current_date, 'teste dry-run', 'receita', 100, 100, 100, 1, n1, current_date, current_date);
  INSERT INTO public.transacoes (data_transacao, descricao, tipo, valor, vl_parcela, vl_pago, status_pago, negociacao_id, dt_vencimento, dt_pagamento) VALUES (current_date, 'teste dry-run', 'receita', 250, 250, 250, 1, n2, current_date, current_date);
  INSERT INTO public.transacoes (data_transacao, descricao, tipo, valor, vl_parcela, vl_pago, status_pago, negociacao_id, dt_vencimento, dt_pagamento) VALUES (current_date, 'teste dry-run', 'receita', 330, 330, 330, 1, n3, current_date, current_date);
  SELECT count(*), coalesce(sum(vl_pago),0) INTO d, sd FROM _vfr_depois;
  RAISE NOTICE 'apos os 3 lancamentos novos: linhas % (esperado % +3) | pago % (esperado % +680)', d, a, sd, sa;
  SELECT count(*) INTO k FROM _vfr_depois WHERE vl_parcela IN (100, 250, 330) AND dt_vencimento = current_date AND status_pago = 1;
  RAISE NOTICE 'lancamentos novos do sistema visiveis na view nova: % de 3 | na antiga: %', k, (SELECT count(*) FROM _vfr_antes WHERE vl_parcela IN (100, 250, 330) AND dt_vencimento = current_date AND status_pago = 1);
  RAISE NOTICE 'staging no public: %, no backup: %', (SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('staging_conta_pagar','staging_conta_receber')),
     (SELECT count(*) FROM information_schema.tables WHERE table_schema='backup' AND table_name IN ('staging_conta_pagar','staging_conta_receber'));
  RAISE NOTICE 'vw_staging_resumo ainda responde: %', (SELECT count(*) FROM public.vw_staging_resumo);
  RAISE NOTICE 'grants da view: %', (SELECT string_agg(grantee, ',') FROM information_schema.role_table_grants WHERE table_schema='public' AND table_name='v_financeiro_realizado' AND privilege_type='SELECT');
END $$;
ROLLBACK;
