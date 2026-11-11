-- SPEC-258 Fase 4c-2: MOTOR DO RT DO ARQUITETO (decisoes da reuniao 45, 10/11/2026 - Vinicius).
-- Regras: RT = percentual do arquiteto (10% padrao; excecoes por arquiteto) sobre o valor LIQUIDO, SO das pecas da categoria LUMINARIA, proporcional ao que o cliente PAGOU.
--   * cada recebimento (baixa) de parcela de venda gera uma parcela de RT a pagar (firme) com vencimento no MES SEGUINTE ao do pagamento (dia 10 por padrao; regra.dia_fixo troca);
--   * mais de um arquiteto na venda: divide em partes iguais ENTRE TODOS os arquitetos da venda (decisao 10/11: 'vai como metade'); a parte de quem tem "NR" no nome ou esta inativo no RT NAO e paga (nem gera conta a pagar), e nao passa para o outro;
--   * estorno do recebimento: parcela de RT ainda nao paga e cancelada; ja paga vira parcela NEGATIVA (abate no mes);
--   * arquitetos da venda: orcamento_arquitetos, senao projeto_arquitetos do projeto do orcamento; RT manual para o que nao tem vinculo (financeiro_rt_lancar_manual).
-- NAO faz (pendente, depende do fluxo de compensacao da devolucao): RT negativo por devolucao baixada.
-- Nunca bloqueia o recebimento: se o motor falhar, a falha vai para financeiro_ponte_falhas (origem rt_baixa) e a regra 'rt: falhas do motor' acusa.

-- ---------------------------------------------------------------- colunas e tabela de apoio
ALTER TABLE public.financeiro_regras_repasse ADD COLUMN IF NOT EXISTS categoria_id uuid REFERENCES public.categorias_produto(id);
COMMENT ON COLUMN public.financeiro_regras_repasse.categoria_id IS 'Categoria de produto sobre a qual a regra incide (NULL = usa a da regra padrao; padrao NULL = todas).';

ALTER TABLE public.financeiro_parcelas ADD COLUMN IF NOT EXISTS baixa_origem_id uuid REFERENCES public.financeiro_baixas(id);
COMMENT ON COLUMN public.financeiro_parcelas.baixa_origem_id IS 'Baixa (recebimento ou estorno) que gerou esta parcela de RT/comissao; garante idempotencia (uma parcela por baixa e por titulo/beneficiario).';
CREATE UNIQUE INDEX IF NOT EXISTS financeiro_parcelas_uq_baixa_origem ON public.financeiro_parcelas (baixa_origem_id, titulo_id) WHERE baixa_origem_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.financeiro_rt_arquitetos_config (
    contato_id     uuid PRIMARY KEY REFERENCES public.contatos(id),
    recebe_rt      boolean NOT NULL DEFAULT true,
    motivo         text,
    atualizado_em  timestamptz NOT NULL DEFAULT now(),
    atualizado_por uuid
);
ALTER TABLE public.financeiro_rt_arquitetos_config ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.financeiro_rt_arquitetos_config FROM PUBLIC, anon;
REVOKE INSERT, UPDATE, DELETE ON public.financeiro_rt_arquitetos_config FROM authenticated;
GRANT SELECT ON public.financeiro_rt_arquitetos_config TO authenticated;
CREATE POLICY rt_config_leitura ON public.financeiro_rt_arquitetos_config FOR SELECT TO authenticated
    USING ((SELECT public.pode_acessar_sistema('financeiro')));

-- a regra padrao passa a incidir so em LUMINARIA, sobre o liquido (decisao 10/11)
UPDATE public.financeiro_regras_repasse
   SET categoria_id = (SELECT id FROM public.categorias_produto WHERE nome = 'LUMINARIA' LIMIT 1), base_calculo = 'liquido'
 WHERE tipo = 'rt_arquiteto' AND escopo = 'padrao' AND ativo;

-- ---------------------------------------------------------------- ajudantes
CREATE OR REPLACE FUNCTION public.financeiro_rt_eh_nr(p_nome text) RETURNS boolean
LANGUAGE sql IMMUTABLE AS $$ SELECT coalesce(p_nome ~ '(^|[^A-Za-z])NR([^A-Za-z]|$)', false) $$;

CREATE OR REPLACE FUNCTION public.financeiro_rt_definir_ativo(p_contato uuid, p_recebe boolean, p_motivo text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
BEGIN
    IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sem usuario autenticado.' USING ERRCODE = '42501'; END IF;
    PERFORM public.financeiro_exige('rt_arquiteto'::public.fin_especie);
    IF NOT EXISTS (SELECT 1 FROM public.contatos WHERE id = p_contato AND tipo = 'arquiteto') THEN
        RAISE EXCEPTION 'O contato informado nao e um arquiteto.' USING ERRCODE = 'P0001';
    END IF;
    INSERT INTO public.financeiro_rt_arquitetos_config (contato_id, recebe_rt, motivo, atualizado_por)
    VALUES (p_contato, coalesce(p_recebe, true), p_motivo, auth.uid())
    ON CONFLICT (contato_id) DO UPDATE SET recebe_rt = EXCLUDED.recebe_rt, motivo = EXCLUDED.motivo, atualizado_em = now(), atualizado_por = auth.uid();
END $fn$;

-- fracao do valor da venda que e da categoria (por valor, nao por quantidade); categoria NULL = 1
CREATE OR REPLACE FUNCTION public.financeiro_rt_fracao_categoria(p_orcamento uuid, p_categoria uuid) RETURNS numeric
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
    SELECT CASE WHEN p_categoria IS NULL THEN 1::numeric
                WHEN coalesce(sum(i.quantidade * i.preco_unitario), 0) = 0 THEN 0::numeric
                ELSE coalesce(sum(i.quantidade * i.preco_unitario) FILTER (WHERE p.categoria_id = p_categoria), 0) / sum(i.quantidade * i.preco_unitario) END
      FROM public.orcamento_itens i LEFT JOIN public.produtos p ON p.id = i.produto_id
     WHERE i.orcamento_id = p_orcamento
$$;

-- regra vigente para o arquiteto: a dele; senao a padrao
CREATE OR REPLACE FUNCTION public.financeiro_rt_regra(p_contato uuid, p_data date) RETURNS public.financeiro_regras_repasse
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
    SELECT r.* FROM public.financeiro_regras_repasse r
     WHERE r.tipo = 'rt_arquiteto' AND r.ativo AND r.vigencia_inicio <= p_data AND (r.vigencia_fim IS NULL OR r.vigencia_fim >= p_data)
       AND ((r.escopo = 'beneficiario' AND r.beneficiario_contato_id = p_contato) OR r.escopo = 'padrao')
     ORDER BY (r.escopo = 'beneficiario') DESC, r.vigencia_inicio DESC, r.criado_em DESC LIMIT 1
$$;

CREATE OR REPLACE FUNCTION public.financeiro_rt_vencimento(p_data date, p_dia smallint) RETURNS date
LANGUAGE sql IMMUTABLE AS $$ SELECT (date_trunc('month', p_data) + interval '1 month' + (least(coalesce(p_dia, 10), 28) - 1) * interval '1 day')::date $$;

-- ---------------------------------------------------------------- o motor (interno)
CREATE OR REPLACE FUNCTION public.financeiro_rt_processar_baixa(p_baixa uuid) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
    b public.financeiro_baixas; p public.financeiro_parcelas; tv public.financeiro_titulos; o_proj uuid;
    v_plano uuid; a uuid; v_n int; v_feitas int := 0; r public.financeiro_regras_repasse; pad public.financeiro_regras_repasse;
    v_cat uuid; v_frac numeric; v_valor numeric; v_tit uuid; v_num int; v_seq int; v_nome text; v_orig public.financeiro_parcelas;
    v_elegiveis uuid[]; v_todos uuid[];
BEGIN
    SELECT * INTO b FROM public.financeiro_baixas WHERE id = p_baixa;
    IF NOT FOUND THEN RETURN 0; END IF;

    -- ESTORNO de um recebimento: acerta a parcela de RT que ele tinha gerado
    IF b.tipo = 'estorno' THEN
        FOR v_orig IN SELECT * FROM public.financeiro_parcelas WHERE baixa_origem_id = b.estorno_de LOOP
            IF v_orig.valor_liquidado = 0 AND v_orig.situacao = 'firme' THEN
                UPDATE public.financeiro_parcelas SET situacao = 'cancelada', observacao = coalesce(observacao || ' | ', '') || 'cancelada: recebimento estornado' WHERE id = v_orig.id;
                v_feitas := v_feitas + 1;
            ELSIF v_orig.valor > 0 AND v_orig.situacao = 'firme' THEN
                INSERT INTO public.financeiro_parcelas (titulo_id, numero, vencimento, valor, situacao, confirmada_em, observacao, baixa_origem_id)
                SELECT v_orig.titulo_id, coalesce(max(numero), 0) + 1, public.financeiro_rt_vencimento(b.data, NULL), -v_orig.valor, 'firme', now(),
                       'RT negativo: recebimento estornado depois do RT pago', b.id
                  FROM public.financeiro_parcelas WHERE titulo_id = v_orig.titulo_id;
                v_feitas := v_feitas + 1;
            END IF;
        END LOOP;
        RETURN v_feitas;
    END IF;

    IF b.tipo <> 'recebimento' OR b.valor <= 0 THEN RETURN 0; END IF;
    IF EXISTS (SELECT 1 FROM public.financeiro_parcelas WHERE baixa_origem_id = b.id) THEN RETURN 0; END IF;   -- idempotente

    SELECT * INTO p FROM public.financeiro_parcelas WHERE id = b.parcela_id;
    SELECT * INTO tv FROM public.financeiro_titulos WHERE id = p.titulo_id;
    IF tv.origem_tipo <> 'orcamento' OR tv.especie <> 'venda' OR tv.natureza <> 'receber' OR tv.cancelado_em IS NOT NULL THEN RETURN 0; END IF;

    SELECT id INTO v_plano FROM public.plano_de_contas WHERE codigo_connect = 2030010 AND nome = 'RT' LIMIT 1;
    IF v_plano IS NULL THEN RAISE EXCEPTION 'Plano de contas RT nao encontrado.'; END IF;
    SELECT projeto_id INTO o_proj FROM public.orcamentos WHERE id = tv.orcamento_id;
    o_proj := coalesce(tv.projeto_id, o_proj);

    -- arquitetos da venda: todos entram na divisao; so os elegiveis (nao NR, nao inativos) recebem
    SELECT array_agg(DISTINCT x.arquiteto_id) INTO v_todos FROM (
        SELECT arquiteto_id FROM public.orcamento_arquitetos WHERE orcamento_id = tv.orcamento_id
        UNION
        SELECT arquiteto_id FROM public.projeto_arquitetos WHERE projeto_id = o_proj
         AND NOT EXISTS (SELECT 1 FROM public.orcamento_arquitetos WHERE orcamento_id = tv.orcamento_id)
    ) x JOIN public.contatos c ON c.id = x.arquiteto_id AND c.tipo = 'arquiteto';
    v_n := coalesce(array_length(v_todos, 1), 0);
    IF v_n = 0 THEN RETURN 0; END IF;
    SELECT array_agg(c.id) INTO v_elegiveis FROM public.contatos c
      LEFT JOIN public.financeiro_rt_arquitetos_config cfg ON cfg.contato_id = c.id
     WHERE c.id = ANY (v_todos) AND NOT public.financeiro_rt_eh_nr(c.nome) AND coalesce(cfg.recebe_rt, true);
    IF coalesce(array_length(v_elegiveis, 1), 0) = 0 THEN RETURN 0; END IF;

    FOREACH a IN ARRAY v_elegiveis LOOP
        r := public.financeiro_rt_regra(a, b.data);
        IF r.id IS NULL THEN
            IF NOT EXISTS (SELECT 1 FROM public.financeiro_pendencias WHERE tipo = 'rt_sem_regra' AND titulo_id = tv.id AND status = 'aberta' AND descricao LIKE '%' || a::text || '%') THEN
                INSERT INTO public.financeiro_pendencias (titulo_id, baixa_id, tipo, descricao, responsavel)
                VALUES (tv.id, b.id, 'rt_sem_regra', 'Arquiteto ' || a::text || ' sem regra de RT (nem padrao) na venda.', 'financeiro');
            END IF;
            CONTINUE;
        END IF;
        SELECT * INTO pad FROM public.financeiro_regras_repasse WHERE tipo = 'rt_arquiteto' AND escopo = 'padrao' AND ativo ORDER BY vigencia_inicio DESC LIMIT 1;
        v_cat := coalesce(r.categoria_id, pad.categoria_id);
        v_frac := public.financeiro_rt_fracao_categoria(tv.orcamento_id, v_cat);
        v_valor := round(b.valor * v_frac * (r.percentual / 100) / v_n, 2);
        IF v_valor <= 0 THEN CONTINUE; END IF;

        SELECT id INTO v_tit FROM public.financeiro_titulos
         WHERE titulo_base_id = tv.id AND contato_id = a AND especie = 'rt_arquiteto' AND origem_tipo = 'regra_repasse' AND cancelado_em IS NULL LIMIT 1;
        IF v_tit IS NULL THEN
            SELECT coalesce(max(origem_seq), 0) + 1 INTO v_seq FROM public.financeiro_titulos WHERE regra_repasse_id = r.id AND titulo_base_id = tv.id;
            SELECT nome INTO v_nome FROM public.contatos WHERE id = a;
            INSERT INTO public.financeiro_titulos (natureza, origem_tipo, origem_seq, regra_repasse_id, especie, empresa_id, perfil, contato_id, plano_contas_id, projeto_id, titulo_base_id, descricao)
            VALUES ('pagar', 'regra_repasse', v_seq, r.id, 'rt_arquiteto', tv.empresa_id, tv.perfil, a, v_plano, o_proj, tv.id, 'RT ' || coalesce(v_nome, '') || ' (venda ' || coalesce(tv.documento, tv.id::text) || ')')
            RETURNING id INTO v_tit;
        END IF;
        SELECT coalesce(max(numero), 0) + 1 INTO v_num FROM public.financeiro_parcelas WHERE titulo_id = v_tit;
        INSERT INTO public.financeiro_parcelas (titulo_id, numero, vencimento, valor, situacao, confirmada_em, observacao, baixa_origem_id)
        VALUES (v_tit, v_num, public.financeiro_rt_vencimento(b.data, r.dia_fixo), v_valor, 'firme', now(),
                'RT ' || r.percentual || '% x ' || round(v_frac * 100, 2) || '% luminaria sobre recebimento de ' || b.valor, b.id);
        v_feitas := v_feitas + 1;
    END LOOP;
    RETURN v_feitas;
END $fn$;

CREATE OR REPLACE FUNCTION public.trg_financeiro_rt_baixa() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
BEGIN
    IF NEW.tipo IN ('recebimento', 'estorno') THEN
        BEGIN
            PERFORM public.financeiro_rt_processar_baixa(NEW.id);
        EXCEPTION WHEN OTHERS THEN
            INSERT INTO public.financeiro_ponte_falhas (transacao_id, erro, origem) VALUES (NEW.id, SQLERRM, 'rt_baixa');
        END;
    END IF;
    RETURN NEW;
END $fn$;
DROP TRIGGER IF EXISTS trg_zz_financeiro_rt_baixa ON public.financeiro_baixas;
CREATE TRIGGER trg_zz_financeiro_rt_baixa AFTER INSERT ON public.financeiro_baixas FOR EACH ROW EXECUTE FUNCTION public.trg_financeiro_rt_baixa();

-- ---------------------------------------------------------------- RT manual (arquiteto sem vinculo no projeto, ou ajuste)
CREATE OR REPLACE FUNCTION public.financeiro_rt_lancar_manual(p_orcamento uuid, p_arquiteto uuid, p_valor numeric, p_vencimento date, p_obs text DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE tv public.financeiro_titulos; v_plano uuid; v_tit uuid;
BEGIN
    IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sem usuario autenticado.' USING ERRCODE = '42501'; END IF;
    PERFORM public.financeiro_exige('rt_arquiteto'::public.fin_especie);
    IF p_valor IS NULL OR p_valor <= 0 THEN RAISE EXCEPTION 'Valor do RT invalido.' USING ERRCODE = 'P0001'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.contatos WHERE id = p_arquiteto AND tipo = 'arquiteto') THEN RAISE EXCEPTION 'O contato informado nao e um arquiteto.' USING ERRCODE = 'P0001'; END IF;
    SELECT * INTO tv FROM public.financeiro_titulos WHERE origem_tipo = 'orcamento' AND orcamento_id = p_orcamento AND cancelado_em IS NULL ORDER BY origem_seq LIMIT 1;
    IF tv.id IS NULL THEN RAISE EXCEPTION 'A venda ainda nao tem titulo a receber (aprovacao financeira pendente).' USING ERRCODE = 'P0001'; END IF;
    SELECT id INTO v_plano FROM public.plano_de_contas WHERE codigo_connect = 2030010 AND nome = 'RT' LIMIT 1;
    INSERT INTO public.financeiro_titulos (natureza, origem_tipo, especie, empresa_id, perfil, contato_id, plano_contas_id, projeto_id, titulo_base_id, descricao, criado_por)
    VALUES ('pagar', 'manual', 'rt_arquiteto', tv.empresa_id, tv.perfil, p_arquiteto, v_plano, tv.projeto_id, tv.id, coalesce(p_obs, 'RT manual'), auth.uid())
    RETURNING id INTO v_tit;
    INSERT INTO public.financeiro_parcelas (titulo_id, numero, vencimento, valor, situacao, confirmada_em, confirmada_por, observacao, criado_por)
    VALUES (v_tit, 1, p_vencimento, p_valor, 'firme', now(), auth.uid(), 'RT lancado manualmente', auth.uid());
    RETURN v_tit;
END $fn$;

-- ---------------------------------------------------------------- views
-- vw_financeiro_rt_arquitetos: mantem as colunas e acrescenta recebe_rt / eh_nr
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

-- relatorio de comissao (visao por LIQUIDEZ: o que o cliente pagou e gerou RT); a Lana imprime por empresa/arquiteto/periodo
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

REVOKE ALL ON public.vw_financeiro_rt_arquitetos, public.vw_financeiro_rt_relatorio, public.vw_financeiro_rt_previsto_venda FROM PUBLIC, anon;
GRANT SELECT ON public.vw_financeiro_rt_arquitetos, public.vw_financeiro_rt_relatorio, public.vw_financeiro_rt_previsto_venda TO authenticated;

-- funcoes: so quem tem o sistema financeiro (as de dentro, so o banco)
REVOKE ALL ON FUNCTION public.financeiro_rt_definir_ativo(uuid, boolean, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.financeiro_rt_lancar_manual(uuid, uuid, numeric, date, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.financeiro_rt_processar_baixa(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.trg_financeiro_rt_baixa() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.financeiro_rt_fracao_categoria(uuid, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.financeiro_rt_regra(uuid, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.financeiro_rt_definir_ativo(uuid, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.financeiro_rt_lancar_manual(uuid, uuid, numeric, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.financeiro_rt_fracao_categoria(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.financeiro_rt_regra(uuid, date) TO authenticated;

-- integridade do motor
CREATE OR REPLACE VIEW public.vw_financeiro_ponte_rt_integridade WITH (security_invoker = true) AS
SELECT 'rt: falhas do motor abertas'::text AS teste, count(*)::bigint AS violacoes FROM public.financeiro_ponte_falhas WHERE origem = 'rt_baixa' AND resolvida_em IS NULL
UNION ALL
SELECT 'rt: parcela de RT automatico sem baixa de origem', count(*) FROM public.financeiro_parcelas p JOIN public.financeiro_titulos t ON t.id = p.titulo_id
 WHERE t.especie = 'rt_arquiteto' AND t.origem_tipo = 'regra_repasse' AND p.baixa_origem_id IS NULL;
REVOKE ALL ON public.vw_financeiro_ponte_rt_integridade FROM PUBLIC, anon;
GRANT SELECT ON public.vw_financeiro_ponte_rt_integridade TO authenticated;
