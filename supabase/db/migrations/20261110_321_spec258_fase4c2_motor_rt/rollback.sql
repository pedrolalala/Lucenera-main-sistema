-- Rollback 321: remove o motor. Titulos/parcelas de RT ja gerados NAO sao apagados (nada se apaga): so e seguro enquanto nenhum RT foi gerado.
DROP TRIGGER IF EXISTS trg_zz_financeiro_rt_baixa ON public.financeiro_baixas;
DROP VIEW IF EXISTS public.vw_financeiro_ponte_rt_integridade, public.vw_financeiro_rt_previsto_venda, public.vw_financeiro_rt_relatorio;
-- volta a view de arquitetos ao formato da migration 312 (sem recebe_rt/eh_nr)
DROP VIEW IF EXISTS public.vw_financeiro_rt_arquitetos;
CREATE VIEW public.vw_financeiro_rt_arquitetos WITH (security_invoker = true) AS
SELECT c.id AS contato_id, c.nome, r.id AS regra_id, r.percentual, r.base_calculo, r.gatilho, r.dia_fixo, r.exige_nota_fiscal, r.observacao, r.vigencia_inicio, (r.id IS NOT NULL) AS tem_regra
FROM public.contatos c LEFT JOIN LATERAL (
    SELECT x.* FROM public.financeiro_regras_repasse x
     WHERE x.tipo = 'rt_arquiteto' AND x.ativo AND x.escopo = 'beneficiario' AND x.beneficiario_contato_id = c.id
       AND x.vigencia_inicio <= current_date AND (x.vigencia_fim IS NULL OR x.vigencia_fim >= current_date)
     ORDER BY x.vigencia_inicio DESC, x.criado_em DESC LIMIT 1) r ON true
WHERE c.tipo = 'arquiteto';
REVOKE ALL ON public.vw_financeiro_rt_arquitetos FROM PUBLIC, anon;
GRANT SELECT ON public.vw_financeiro_rt_arquitetos TO authenticated;
DROP FUNCTION IF EXISTS public.financeiro_rt_lancar_manual(uuid, uuid, numeric, date, text);
DROP FUNCTION IF EXISTS public.financeiro_rt_processar_baixa(uuid);
DROP FUNCTION IF EXISTS public.trg_financeiro_rt_baixa();
DROP FUNCTION IF EXISTS public.financeiro_rt_vencimento(date, smallint);
DROP FUNCTION IF EXISTS public.financeiro_rt_regra(uuid, date);
DROP FUNCTION IF EXISTS public.financeiro_rt_fracao_categoria(uuid, uuid);
DROP FUNCTION IF EXISTS public.financeiro_rt_definir_ativo(uuid, boolean, text);
DROP FUNCTION IF EXISTS public.financeiro_rt_eh_nr(text);
DROP TABLE IF EXISTS public.financeiro_rt_arquitetos_config;
UPDATE public.financeiro_regras_repasse SET categoria_id = NULL WHERE tipo = 'rt_arquiteto';
DROP INDEX IF EXISTS public.financeiro_parcelas_uq_baixa_origem;
ALTER TABLE public.financeiro_parcelas DROP COLUMN IF EXISTS baixa_origem_id;
ALTER TABLE public.financeiro_regras_repasse DROP COLUMN IF EXISTS categoria_id;
