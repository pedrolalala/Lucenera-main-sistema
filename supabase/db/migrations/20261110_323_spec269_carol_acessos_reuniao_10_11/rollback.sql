-- Rollback SPEC-269: volta ao estado da migration 311 (papel) e 321 (RT sob 'financeiro').
-- funcoes: volta a trava para financeiro_exige('rt_arquiteto') (= sistema financeiro)
DO $$
DECLARE r record; v_def text; v_novo text;
BEGIN
  FOR r IN SELECT p.oid FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace AND ns.nspname = 'public'
            WHERE p.proname IN ('financeiro_definir_rt', 'financeiro_rt_lancar_manual', 'financeiro_rt_definir_ativo') LOOP
    v_def := pg_get_functiondef(r.oid);
    EXECUTE replace(v_def, 'financeiro_exige_rt()', 'financeiro_exige(''rt_arquiteto''::public.fin_especie)');
  END LOOP;
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace AND ns.nspname = 'public' WHERE p.proname = 'financeiro_criar_titulo' LIMIT 1;
  v_novo := regexp_replace(v_def, E'\\n\\s*IF r\\.especie = ''rt_arquiteto'' THEN PERFORM public\\.financeiro_exige_rt\\(\\); END IF;', '', 'g');
  EXECUTE v_novo;
END $$;
DROP FUNCTION IF EXISTS public.financeiro_exige_rt();

-- views: corpo da migration 321 (portao 'financeiro')
CREATE OR REPLACE VIEW public.vw_financeiro_rt_arquitetos WITH (security_invoker = true) AS
SELECT c.id AS contato_id, c.nome, r.id AS regra_id, r.percentual, r.base_calculo, r.gatilho, r.dia_fixo, r.exige_nota_fiscal, r.observacao, r.vigencia_inicio,
       (r.id IS NOT NULL) AS tem_regra,
       (coalesce(cfg.recebe_rt, true) AND NOT public.financeiro_rt_eh_nr(c.nome)) AS recebe_rt,
       public.financeiro_rt_eh_nr(c.nome) AS eh_nr
FROM public.contatos c
LEFT JOIN LATERAL (
    SELECT x.* FROM public.financeiro_regras_repasse x
     WHERE x.tipo = 'rt_arquiteto' AND x.ativo AND x.escopo = 'beneficiario' AND x.beneficiario_contato_id = c.id
       AND x.vigencia_inicio <= current_date AND (x.vigencia_fim IS NULL OR x.vigencia_fim >= current_date)
     ORDER BY x.vigencia_inicio DESC, x.criado_em DESC LIMIT 1
) r ON true
LEFT JOIN public.financeiro_rt_arquitetos_config cfg ON cfg.contato_id = c.id
WHERE c.tipo = 'arquiteto';

CREATE OR REPLACE VIEW public.vw_financeiro_rt_relatorio WITH (security_invoker = true) AS
SELECT pr.id AS parcela_rt_id, t.id AS titulo_rt_id, t.empresa_id, t.perfil, t.contato_id AS arquiteto_id, c.nome AS arquiteto,
       tv.id AS titulo_venda_id, tv.orcamento_id, tv.documento AS nota_venda,
       bx.data AS data_pagamento_cliente, bx.valor AS valor_recebido,
       pv.numero AS parcela_numero, (SELECT count(*) FROM public.financeiro_parcelas z WHERE z.titulo_id = tv.id AND z.situacao <> 'cancelada') AS parcelas_total,
       pv.valor AS valor_parcela_venda, pr.valor AS comissao, pr.vencimento AS pagar_em, pr.situacao, pr.valor_liquidado AS ja_pago,
       (pr.valor - pr.valor_liquidado) AS saldo, pr.observacao AS memoria_de_calculo
FROM public.financeiro_parcelas pr
JOIN public.financeiro_titulos t ON t.id = pr.titulo_id AND t.especie = 'rt_arquiteto' AND t.cancelado_em IS NULL
JOIN public.contatos c ON c.id = t.contato_id
LEFT JOIN public.financeiro_titulos tv ON tv.id = t.titulo_base_id
LEFT JOIN public.financeiro_baixas bx ON bx.id = pr.baixa_origem_id AND bx.tipo = 'recebimento'
LEFT JOIN public.financeiro_parcelas pv ON pv.id = bx.parcela_id
WHERE pr.situacao <> 'cancelada' AND (SELECT public.pode_acessar_sistema('financeiro'));

-- visao por VENDA: quanto vai gerar de RT mesmo sem o cliente ter pago ainda
CREATE OR REPLACE VIEW public.vw_financeiro_rt_previsto_venda WITH (security_invoker = true) AS
WITH vendas AS (
    SELECT tv.id AS titulo_venda_id, tv.orcamento_id, tv.empresa_id, tv.perfil, tv.documento,
           coalesce(tv.projeto_id, o.projeto_id) AS projeto_id,
           (SELECT sum(valor) FROM public.financeiro_parcelas z WHERE z.titulo_id = tv.id AND z.situacao <> 'cancelada') AS valor_venda
    FROM public.financeiro_titulos tv JOIN public.orcamentos o ON o.id = tv.orcamento_id
    WHERE tv.origem_tipo = 'orcamento' AND tv.especie = 'venda' AND tv.cancelado_em IS NULL
), arqs AS (
    SELECT v.*, a.arquiteto_id, f.recebe FROM vendas v
    JOIN LATERAL (
        SELECT arquiteto_id FROM public.orcamento_arquitetos WHERE orcamento_id = v.orcamento_id
        UNION
        SELECT arquiteto_id FROM public.projeto_arquitetos WHERE projeto_id = v.projeto_id AND NOT EXISTS (SELECT 1 FROM public.orcamento_arquitetos WHERE orcamento_id = v.orcamento_id)
    ) a ON true
    JOIN public.contatos c ON c.id = a.arquiteto_id AND c.tipo = 'arquiteto'
    LEFT JOIN public.financeiro_rt_arquitetos_config cfg ON cfg.contato_id = c.id
    -- todos os arquitetos entram na divisao; recebe = nao NR e nao inativo
    CROSS JOIN LATERAL (SELECT (NOT public.financeiro_rt_eh_nr(c.nome) AND coalesce(cfg.recebe_rt, true)) AS recebe) f
), calc AS (
    SELECT a.*, count(*) OVER (PARTITION BY a.titulo_venda_id) AS n_arq, (public.financeiro_rt_regra(a.arquiteto_id, current_date)).percentual AS pct,
           public.financeiro_rt_fracao_categoria(a.orcamento_id, coalesce((public.financeiro_rt_regra(a.arquiteto_id, current_date)).categoria_id,
               (SELECT categoria_id FROM public.financeiro_regras_repasse WHERE tipo = 'rt_arquiteto' AND escopo = 'padrao' AND ativo ORDER BY vigencia_inicio DESC LIMIT 1))) AS fracao
    FROM arqs a
)
SELECT c.titulo_venda_id, c.orcamento_id, c.empresa_id, c.perfil, c.documento AS nota_venda, c.arquiteto_id, ct.nome AS arquiteto, c.pct AS percentual,
       round(c.fracao * 100, 2) AS pct_luminaria, c.valor_venda,
       round(c.valor_venda * c.fracao * (c.pct / 100) / c.n_arq, 2) AS rt_previsto_total,
       coalesce((SELECT sum(p.valor) FROM public.financeiro_parcelas p JOIN public.financeiro_titulos t ON t.id = p.titulo_id
                  WHERE t.titulo_base_id = c.titulo_venda_id AND t.contato_id = c.arquiteto_id AND t.especie = 'rt_arquiteto' AND t.cancelado_em IS NULL AND p.situacao <> 'cancelada'), 0) AS rt_gerado
FROM calc c JOIN public.contatos ct ON ct.id = c.arquiteto_id
WHERE c.recebe AND c.pct IS NOT NULL AND (SELECT public.pode_acessar_sistema('financeiro'));


-- previsao por venda: corpo da 321
CREATE OR REPLACE VIEW public.vw_financeiro_rt_previsto_venda WITH (security_invoker = true) AS
WITH vendas AS (
    SELECT tv.id AS titulo_venda_id, tv.orcamento_id, tv.empresa_id, tv.perfil, tv.documento,
           coalesce(tv.projeto_id, o.projeto_id) AS projeto_id,
           (SELECT sum(valor) FROM public.financeiro_parcelas z WHERE z.titulo_id = tv.id AND z.situacao <> 'cancelada') AS valor_venda
    FROM public.financeiro_titulos tv JOIN public.orcamentos o ON o.id = tv.orcamento_id
    WHERE tv.origem_tipo = 'orcamento' AND tv.especie = 'venda' AND tv.cancelado_em IS NULL
), arqs AS (
    SELECT v.*, a.arquiteto_id, f.recebe FROM vendas v
    JOIN LATERAL (
        SELECT arquiteto_id FROM public.orcamento_arquitetos WHERE orcamento_id = v.orcamento_id
        UNION
        SELECT arquiteto_id FROM public.projeto_arquitetos WHERE projeto_id = v.projeto_id AND NOT EXISTS (SELECT 1 FROM public.orcamento_arquitetos WHERE orcamento_id = v.orcamento_id)
    ) a ON true
    JOIN public.contatos c ON c.id = a.arquiteto_id AND c.tipo = 'arquiteto'
    LEFT JOIN public.financeiro_rt_arquitetos_config cfg ON cfg.contato_id = c.id
    -- todos os arquitetos entram na divisao; recebe = nao NR e nao inativo
    CROSS JOIN LATERAL (SELECT (NOT public.financeiro_rt_eh_nr(c.nome) AND coalesce(cfg.recebe_rt, true)) AS recebe) f
), calc AS (
    SELECT a.*, count(*) OVER (PARTITION BY a.titulo_venda_id) AS n_arq, (public.financeiro_rt_regra(a.arquiteto_id, current_date)).percentual AS pct,
           public.financeiro_rt_fracao_categoria(a.orcamento_id, coalesce((public.financeiro_rt_regra(a.arquiteto_id, current_date)).categoria_id,
               (SELECT categoria_id FROM public.financeiro_regras_repasse WHERE tipo = 'rt_arquiteto' AND escopo = 'padrao' AND ativo ORDER BY vigencia_inicio DESC LIMIT 1))) AS fracao
    FROM arqs a
)
SELECT c.titulo_venda_id, c.orcamento_id, c.empresa_id, c.perfil, c.documento AS nota_venda, c.arquiteto_id, ct.nome AS arquiteto, c.pct AS percentual,
       round(c.fracao * 100, 2) AS pct_luminaria, c.valor_venda,
       round(c.valor_venda * c.fracao * (c.pct / 100) / c.n_arq, 2) AS rt_previsto_total,
       coalesce((SELECT sum(p.valor) FROM public.financeiro_parcelas p JOIN public.financeiro_titulos t ON t.id = p.titulo_id
                  WHERE t.titulo_base_id = c.titulo_venda_id AND t.contato_id = c.arquiteto_id AND t.especie = 'rt_arquiteto' AND t.cancelado_em IS NULL AND p.situacao <> 'cancelada'), 0) AS rt_gerado
FROM calc c JOIN public.contatos ct ON ct.id = c.arquiteto_id
WHERE c.recebe AND c.pct IS NOT NULL AND (SELECT public.pode_acessar_sistema('financeiro'));

REVOKE ALL ON public.vw_financeiro_rt_arquitetos, public.vw_financeiro_rt_relatorio, public.vw_financeiro_rt_previsto_venda FROM PUBLIC, anon;
GRANT SELECT ON public.vw_financeiro_rt_arquitetos, public.vw_financeiro_rt_relatorio, public.vw_financeiro_rt_previsto_venda TO authenticated;

DROP POLICY IF EXISTS rt_config_leitura ON public.financeiro_rt_arquitetos_config;
CREATE POLICY rt_config_leitura ON public.financeiro_rt_arquitetos_config FOR SELECT TO authenticated
    USING ((SELECT public.pode_acessar_sistema('financeiro')));

DELETE FROM public.user_system_access a USING public.systems s
 WHERE a.system_id = s.id AND s.slug = 'financeiro-rt-comissao';
DELETE FROM public.systems WHERE slug = 'financeiro-rt-comissao';

-- papel: volta Necessidade de Compra (tudo), Cadastro (tudo), Garantia/Producao (visualizar); tira Venda Parcial e Showroom
DELETE FROM public.papel_permissoes pp USING public.papeis p, public.systems s
 WHERE pp.papel_id = p.id AND pp.system_id = s.id AND p.nome = 'assistente_administrativa'
   AND s.slug IN ('cadastro', 'showroom', 'separacao-parcial');
INSERT INTO public.papel_permissoes (papel_id, system_id, modulo_id, acao)
SELECT p.id, s.id, NULL, v.acao FROM public.papeis p
  JOIN (VALUES ('necessidade-de-compra', NULL), ('cadastro', NULL), ('controle-garantia', 'visualizar'), ('controle-producao', 'visualizar')) AS v(slug, acao) ON true
  JOIN public.systems s ON s.slug = v.slug
 WHERE p.nome = 'assistente_administrativa'
   AND NOT EXISTS (SELECT 1 FROM public.papel_permissoes x WHERE x.papel_id = p.id AND x.system_id = s.id AND x.modulo_id IS NULL AND x.acao IS NOT DISTINCT FROM v.acao);

DELETE FROM public.user_system_access a USING public.usuarios u, public.systems s
 WHERE a.user_id = u.id AND a.system_id = s.id AND lower(u.email) = 'caroline@lucenera.com.br' AND s.slug IN ('separacao-parcial', 'showroom');
INSERT INTO public.user_system_access (user_id, system_id)
SELECT u.id, s.id FROM public.usuarios u JOIN public.systems s ON s.slug IN ('necessidade-de-compra', 'controle-garantia', 'controle-producao')
 WHERE lower(u.email) = 'caroline@lucenera.com.br' ON CONFLICT (user_id, system_id) DO NOTHING;

INSERT INTO public.usuario_papeis (usuario_id, papel_id)
SELECT u.id, p.id FROM public.usuarios u, public.papeis p
 WHERE lower(u.email) = 'caroline@lucenera.com.br' AND p.nome = 'administracao_comercial'
   AND NOT EXISTS (SELECT 1 FROM public.usuario_papeis x WHERE x.usuario_id = u.id AND x.papel_id = p.id);
