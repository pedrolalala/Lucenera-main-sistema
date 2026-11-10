-- SPEC-269: ajuste do papel da Caroline (assistente_administrativa) conforme a reuniao de 10/11/2026 + acesso proprio "LT/comissao".
-- RASCUNHO: NAO aplicado. Rodar dry-run em ROLLBACK e testar como a Caroline e como quem emite RT antes de aplicar.
-- Sem BEGIN/COMMIT de proposito (dry-run do revisor nao pode commitar).
--
-- Decisoes da reuniao: Contas a Pagar/Receber, Financeiro, Orcamentos, Vendas, Venda Parcial = tudo (acordos incluidos);
-- Cadastro/produto = so consultar; Showroom = consultar; Central de Solicitacoes = ver+criar;
-- Necessidade de Compra, Garantia, Producao, CRM, RH, Entregas, Fichas, Dashboard, Memoria, Movimentacao = NAO.
-- LT e comissao: a rotina de emitir NAO; o titulo de comissao ja gerado aparece normal no Contas a Pagar.

-- ===================================================================== 1. acesso proprio "financeiro-rt-comissao"
-- Nao e card do Hub (visivel_no_hub = false): serve so de chave em Acesso a Sistemas.
INSERT INTO public.systems (name, description, link, icon_name, display_order, slug, visivel_no_hub)
SELECT 'Financeiro - LT e Comissao (RT)',
       'SPEC-269: quem pode emitir/lancar RT e comissao e ver o relatorio de comissao. Chave de permissao, sem card no Hub.',
       'https://contas-pagar-lucenera.pages.dev/', 'Lock', 99, 'financeiro-rt-comissao', false
WHERE NOT EXISTS (SELECT 1 FROM public.systems WHERE slug = 'financeiro-rt-comissao');

-- quem ja tem o financeiro continua emitindo, EXCETO a Caroline
INSERT INTO public.user_system_access (user_id, system_id)
SELECT a.user_id, n.id
  FROM public.user_system_access a
  JOIN public.systems f ON f.id = a.system_id AND f.slug = 'financeiro'
  JOIN public.systems n ON n.slug = 'financeiro-rt-comissao'
  JOIN public.usuarios u ON u.id = a.user_id
 WHERE lower(u.email) <> 'caroline@lucenera.com.br'
ON CONFLICT (user_id, system_id) DO NOTHING;

-- ===================================================================== 2. portas de gravacao e leitura do RT
-- Trava SO da EMISSAO/CONFIGURACAO de RT. financeiro_exige (baixar, estornar, pagar, listar) NAO muda:
-- a Caroline continua pagando/baixando titulo de RT que ja existe (revisor, aviso 1).
CREATE OR REPLACE FUNCTION public.financeiro_exige_rt() RETURNS void
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $f$
BEGIN
    IF auth.uid() IS NULL THEN RETURN; END IF;
    IF NOT (public.pode_acessar_sistema('financeiro') AND public.pode_acessar_sistema('financeiro-rt-comissao')) THEN
        RAISE EXCEPTION 'Sem permissão para emitir LT/comissão (RT).' USING ERRCODE = '42501';
    END IF;
END $f$;
REVOKE ALL ON FUNCTION public.financeiro_exige_rt() FROM PUBLIC, anon, authenticated;

-- troca a chamada de trava dentro das funcoes que emitem/configuram RT (le a definicao real do banco; aborta se nao achar o trecho)
DO $$
DECLARE r record; v_def text; v_novo text; n int := 0;
BEGIN
  FOR r IN SELECT p.oid, p.proname FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace AND ns.nspname = 'public'
            WHERE p.proname IN ('financeiro_definir_rt', 'financeiro_rt_lancar_manual', 'financeiro_rt_definir_ativo') LOOP
    v_def := pg_get_functiondef(r.oid);
    v_novo := regexp_replace(v_def, 'financeiro_exige\(\s*''rt_arquiteto''[^)]*\)', 'financeiro_exige_rt()', 'g');
    IF v_novo = v_def THEN RAISE EXCEPTION 'SPEC-269: trava rt_arquiteto nao encontrada em %', r.proname; END IF;
    EXECUTE v_novo; n := n + 1;
  END LOOP;
  IF n <> 3 THEN RAISE EXCEPTION 'SPEC-269: esperava 3 funcoes de RT, achei %', n; END IF;
  -- criacao generica de titulo: RT so para quem emite
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace AND ns.nspname = 'public'
   WHERE p.proname = 'financeiro_criar_titulo' LIMIT 1;
  v_novo := regexp_replace(v_def, '(PERFORM public\.financeiro_exige\(r\.especie\);)', E'\\1\n    IF r.especie = ''rt_arquiteto'' THEN PERFORM public.financeiro_exige_rt(); END IF;', 'g');
  IF v_novo = v_def THEN RAISE EXCEPTION 'SPEC-269: trava nao encontrada em financeiro_criar_titulo'; END IF;
  EXECUTE v_novo;
END $$;

-- relatorio de comissao e previsao por venda: portao passa a ser o acesso novo (corpo identico ao da migration 321)
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
WHERE pr.situacao <> 'cancelada' AND (SELECT public.pode_acessar_sistema('financeiro-rt-comissao'));

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
WHERE c.recebe AND c.pct IS NOT NULL AND (SELECT public.pode_acessar_sistema('financeiro-rt-comissao'));

-- vw_financeiro_rt_arquitetos (lista de arquitetos + percentuais): so quem emite
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
WHERE c.tipo = 'arquiteto' AND (SELECT public.pode_acessar_sistema('financeiro-rt-comissao'));

REVOKE ALL ON public.vw_financeiro_rt_arquitetos, public.vw_financeiro_rt_relatorio, public.vw_financeiro_rt_previsto_venda FROM PUBLIC, anon;
GRANT SELECT ON public.vw_financeiro_rt_arquitetos, public.vw_financeiro_rt_relatorio, public.vw_financeiro_rt_previsto_venda TO authenticated;

-- config de RT por arquiteto (recebe/nao recebe): so quem emite
DROP POLICY IF EXISTS rt_config_leitura ON public.financeiro_rt_arquitetos_config;
CREATE POLICY rt_config_leitura ON public.financeiro_rt_arquitetos_config FOR SELECT TO authenticated
    USING ((SELECT public.pode_acessar_sistema('financeiro-rt-comissao')));

-- ===================================================================== 3. papel da Caroline (ajuste da migration 311)
-- sai: Necessidade de Compra, Garantia, Producao
DELETE FROM public.papel_permissoes pp
 USING public.papeis p, public.systems s
 WHERE pp.papel_id = p.id AND pp.system_id = s.id AND p.nome = 'assistente_administrativa'
   AND s.slug IN ('necessidade-de-compra', 'controle-garantia', 'controle-producao');

-- Cadastro: so consultar (apaga a linha "todas as acoes", fica so visualizar)
DELETE FROM public.papel_permissoes pp
 USING public.papeis p, public.systems s
 WHERE pp.papel_id = p.id AND pp.system_id = s.id AND p.nome = 'assistente_administrativa'
   AND s.slug = 'cadastro' AND pp.modulo_id IS NULL AND pp.acao IS NULL;

INSERT INTO public.papel_permissoes (papel_id, system_id, modulo_id, acao)
SELECT p.id, s.id, NULL, v.acao
  FROM public.papeis p
  JOIN (VALUES ('cadastro', 'visualizar'), ('showroom', 'visualizar'), ('separacao-parcial', NULL)) AS v(slug, acao) ON true
  JOIN public.systems s ON s.slug = v.slug
 WHERE p.nome = 'assistente_administrativa'
   AND NOT EXISTS (SELECT 1 FROM public.papel_permissoes x
                    WHERE x.papel_id = p.id AND x.system_id = s.id AND x.modulo_id IS NULL AND x.acao IS NOT DISTINCT FROM v.acao);

UPDATE public.papeis SET descricao =
  'SPEC-260/269: Assistente administrativa — Financeiro (Contas a Pagar/Receber, acordos), Orcamentos, Vendas e Venda Parcial; so consulta em Cadastro/produto e Showroom; Central de Solicitacoes sem aprovar; NAO emite LT/comissao.'
 WHERE nome = 'assistente_administrativa';

-- ===================================================================== 4. Acesso a Sistemas (cards/RLS) da Caroline
DELETE FROM public.user_system_access a
 USING public.usuarios u, public.systems s
 WHERE a.user_id = u.id AND a.system_id = s.id AND lower(u.email) = 'caroline@lucenera.com.br'
   AND s.slug IN ('necessidade-de-compra', 'controle-garantia', 'controle-producao', 'financeiro-rt-comissao');

INSERT INTO public.user_system_access (user_id, system_id)
SELECT u.id, s.id FROM public.usuarios u JOIN public.systems s ON s.slug IN ('separacao-parcial', 'showroom')
 WHERE lower(u.email) = 'caroline@lucenera.com.br'
ON CONFLICT (user_id, system_id) DO NOTHING;

-- ===================================================================== 5. tira o papel administracao_comercial SO da Caroline
-- Esse papel soma Cadastro criar/editar, Necessidade de Compra e Garantia/Producao e anularia o "so consultar".
-- Efeito colateral aceito: pode_editar_caixa_fechada() olha esse papel; ela perde a edicao de caixa fechada
-- (se precisar, entra em produto_caixa_editores). Filippo e financeiro@ mantem o papel.
-- Obs.: a politica de produtos tambem aceita 'orcamentos' criar/editar; o bloqueio de editar produto fica so na tela do Cadastro.
DELETE FROM public.usuario_papeis up
 USING public.usuarios u, public.papeis p
 WHERE up.usuario_id = u.id AND up.papel_id = p.id
   AND lower(u.email) = 'caroline@lucenera.com.br' AND p.nome = 'administracao_comercial';
