-- SPEC-248 item 3 (opção B confirmada em 06/11): "Previsão" nasce em `transacoes`, a fonte única do financeiro nativo (SPEC-246).
-- Previsão = conta cujo valor e data de pagamento ainda podem mudar; serve para ter visão prévia no fluxo de caixa, em coluna própria.
-- Esta migration entrega só a BASE DE DADOS (marca, coluna na view do fluxo e função para marcar/firmar); a tela do Fluxo Futuro e o
-- cadastro nativo do Contas a Pagar (que grava duplicata e parcelas aqui) vêm depois, junto com o passo 4 da SPEC-246.
--   * `transacoes.previsao` (padrão false): nada que já existe vira previsão.
--   * `v_financeiro_realizado` ganha a coluna `previsao` no FIM: só é verdadeira para parcela EM ABERTO (status_pago = 0);
--     Pago e Cancelado nunca aparecem como previsão, mesmo que a marca tenha ficado ligada.
--   * `definir_previsao_transacoes(ids, previsao, motivo)`: marca ou desmarca (a conta vira firme) parcelas em aberto; quem pode =
--     quem edita o financeiro (pode_acessar_sistema('financeiro')); a auditoria da tabela registra antes/depois.
ALTER TABLE public.transacoes ADD COLUMN IF NOT EXISTS previsao boolean NOT NULL DEFAULT false;
COMMENT ON COLUMN public.transacoes.previsao IS
  'SPEC-248: conta de previsão (valor/data de pagamento podem mudar). Só conta no fluxo enquanto a parcela está em aberto.';

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
    perfil,
    previsao
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
            x.perfil,
            x.previsao
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
                           FROM ((pc p3
                             LEFT JOIN pc p2 ON ((p2.id = p3.parent_id)))
                             LEFT JOIN pc p1 ON ((p1.id = p2.parent_id)))
                        ), negociacao_preferida AS (
                         SELECT n.id,
                            n.cod_duplicata,
                            n.tipo,
                            n.plano_contas_id,
                            n.empresa_id,
                            row_number() OVER (PARTITION BY
                                CASE
                                    WHEN ((v.cod_duplicata IS NOT NULL) AND (n.created_at <= COALESCE(( SELECT e.encerrado_em
                                       FROM connect_financeiro_encerrado e
                                     LIMIT 1), 'infinity'::timestamp with time zone))) THEN (n.cod_duplicata)::text
                                    ELSE (n.id)::text
                                END, n.tipo ORDER BY n.created_at) AS rn
                           FROM (negociacoes n
                             LEFT JOIN stg_duplicatas_vigentes v ON (((v.cod_duplicata = n.cod_duplicata) AND (v.tipo = n.tipo))))
                          WHERE (((v.cod_duplicata IS NOT NULL) AND (n.created_at <= COALESCE(( SELECT e.encerrado_em
                                   FROM connect_financeiro_encerrado e
                                 LIMIT 1), 'infinity'::timestamp with time zone))) OR (n.created_at > COALESCE(( SELECT e.encerrado_em
                                   FROM connect_financeiro_encerrado e
                                 LIMIT 1), 'infinity'::timestamp with time zone)))
                        )
                 SELECT t.id,
                    t.tipo,
                    t.descricao,
                    h.desc_sub_grupo,
                    h.desc_grupo,
                        CASE
                            WHEN ((t.tipo = 'despesa'::transacao_tipo) AND ((h.desc_sub_grupo ~~* '%FILIPPO%'::text) OR (h.desc_sub_grupo ~~* '%MANOELLA%'::text) OR (t.descricao ~~* '%RETIRADA LUCRO%'::text) OR (t.descricao ~~* '%RETIRADA DE LUCRO%'::text) OR (t.descricao ~~* '%LUCRO DISTRIB%'::text))) THEN 'distribuicao_lucro'::text
                            WHEN (t.tipo = 'despesa'::transacao_tipo) THEN 'despesa_operacional'::text
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
                            WHEN (t.tipo <> 'despesa'::transacao_tipo) THEN NULL::text
                            WHEN (h.desc_sub_grupo = ANY (ARRAY['FIXAS'::text, 'COM PESSOAL'::text, 'ADMINISTRATIVAS'::text, 'BANCARIAS'::text, 'VEICULOS'::text])) THEN 'fixo'::text
                            WHEN (h.desc_sub_grupo = ANY (ARRAY['COM VENDAS'::text, 'PRODUTOS'::text])) THEN 'variavel'::text
                            ELSE 'outro'::text
                        END AS tipo_custo,
                    t.perfil,
                    (t.previsao AND t.status_pago = 0) AS previsao
                   FROM ((transacoes t
                     JOIN negociacao_preferida np ON (((np.id = t.negociacao_id) AND (np.rn = 1))))
                     LEFT JOIN hierarquia h ON ((h.plano_contas_id = np.plano_contas_id)))
                  WHERE (t.status_pago <> 2)) x
          WHERE ((x.natureza IS DISTINCT FROM 'distribuicao_lucro'::text) OR ( SELECT pode_ver_distribuicao_lucro() AS pode_ver_distribuicao_lucro))) y
  WHERE ( SELECT pode_acessar_sistema('dashboard-financeiro'::text) AS pode_acessar_sistema);

CREATE OR REPLACE FUNCTION public.definir_previsao_transacoes(
    p_ids      uuid[],
    p_previsao boolean,
    p_motivo   text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_total   integer;
    v_abertas integer;
    v_n       integer;
BEGIN
    IF NOT (SELECT public.pode_acessar_sistema('financeiro')) THEN
        RAISE EXCEPTION 'Sem permissão para alterar o financeiro.' USING ERRCODE = '42501';
    END IF;
    IF p_ids IS NULL OR cardinality(p_ids) = 0 THEN
        RAISE EXCEPTION 'Informe as parcelas.' USING ERRCODE = 'P0001';
    END IF;
    IF p_previsao IS NULL THEN
        RAISE EXCEPTION 'Informe se é previsão ou conta firme.' USING ERRCODE = 'P0001';
    END IF;

    SELECT count(*), count(*) FILTER (WHERE status_pago = 0) INTO v_total, v_abertas
      FROM public.transacoes WHERE id = ANY (p_ids);
    IF v_total <> cardinality(p_ids) THEN
        RAISE EXCEPTION 'Parcela não encontrada (% de % informadas).', cardinality(p_ids) - v_total, cardinality(p_ids) USING ERRCODE = 'P0001';
    END IF;
    IF v_abertas <> v_total THEN
        RAISE EXCEPTION '% parcela(s) já paga(s) ou cancelada(s): só parcela em aberto pode ser previsão.', v_total - v_abertas USING ERRCODE = 'P0001';
    END IF;

    UPDATE public.transacoes SET previsao = p_previsao WHERE id = ANY (p_ids) AND previsao IS DISTINCT FROM p_previsao;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN jsonb_build_object('previsao', p_previsao, 'parcelas', v_total, 'alteradas', v_n);
END;
$function$;

REVOKE ALL ON FUNCTION public.definir_previsao_transacoes(uuid[], boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.definir_previsao_transacoes(uuid[], boolean, text) TO authenticated;
