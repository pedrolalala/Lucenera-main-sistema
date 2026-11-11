-- SPEC-258 Fase 4e: custos recorrentes no modelo novo (origem 'custo_recorrente'). So ASCII.
-- Achados (09/11): custos_recorrentes e custos_recorrentes_lancamentos existem VAZIAS (0 linhas). O historico de Contas a Pagar (12 meses) mostra 38 combinacoes
-- empresa + fornecedor + plano de contas que se repetem todo mes (escopo escolhido: custo fixo operacional; vale transporte fica na folha; salario, premio, compras, RT
-- e impostos variaveis pertencem a outras origens).
--  1) O cadastro custos_recorrentes ganha empresa, fornecedor (contato), plano de contas, perfil e a origem do cadastro (manual | historico). Unico por empresa+fornecedor+plano (ativos).
--  2) Carga inicial a partir do historico (valor = mediana dos ultimos 3 meses, dia = dia tipico de vencimento). Consorcio e emprestimo ficam de fora: sao contratos com fim,
--     cujas parcelas ja estao na agenda.
--  3) financeiro_recorrentes_gerar_interno(p_meses): para cada custo ativo cria UM titulo por mes (origem_seq = (ano-2000)*12 + mes) com UMA parcela PREVISTA no vencimento do mes,
--     do mes corrente ate p_meses a frente. NAO cria previsao quando ja existe conta real (prevista ou firme, outra origem) do mesmo fornecedor e plano no mes (ex.: parcela de
--     seguro ja lancada); se a conta real chegar depois, cancela a previsao ainda sem baixa. Acompanha mudanca de valor/dia do cadastro enquanto a parcela for prevista; custo
--     inativo ou fora da vigencia tem a previsao futura cancelada. Idempotente. Parcela confirmada (firme) ou com baixa nunca e alterada.
--  4) financeiro_gerar_recorrentes(p_meses) = o mesmo com o portao financeiro_exige('despesa') para a tela; o interno (sem portao) so roda pelo agendamento diario (pg_cron 06:40).
--  5) vw_financeiro_recorrentes_integridade: 4 testes (previsao em mes com conta real; valor diferente do cadastro; previsao de custo inativo; titulo com mais de 1 parcela).
-- Aditivo: nenhuma funcao/tabela existente muda (so colunas novas em custos_recorrentes).

ALTER TABLE public.custos_recorrentes
    ADD COLUMN IF NOT EXISTS empresa_id uuid REFERENCES public.empresas(id),
    ADD COLUMN IF NOT EXISTS contato_id uuid REFERENCES public.contatos(id),
    ADD COLUMN IF NOT EXISTS plano_contas_id uuid REFERENCES public.plano_de_contas(id),
    ADD COLUMN IF NOT EXISTS perfil text,
    ADD COLUMN IF NOT EXISTS origem text NOT NULL DEFAULT 'manual';
ALTER TABLE public.custos_recorrentes DROP CONSTRAINT IF EXISTS custos_recorrentes_perfil_check;
ALTER TABLE public.custos_recorrentes ADD CONSTRAINT custos_recorrentes_perfil_check CHECK (perfil IS NULL OR perfil IN ('ribeirao', 'sao_paulo'));
ALTER TABLE public.custos_recorrentes DROP CONSTRAINT IF EXISTS custos_recorrentes_origem_check;
ALTER TABLE public.custos_recorrentes ADD CONSTRAINT custos_recorrentes_origem_check CHECK (origem IN ('manual', 'historico'));
CREATE UNIQUE INDEX IF NOT EXISTS custos_recorrentes_uq_ativo ON public.custos_recorrentes (empresa_id, coalesce(contato_id, '00000000-0000-0000-0000-000000000000'::uuid), plano_contas_id) WHERE ativo;

-- Carga inicial a partir do historico (uma vez; so insere o que ainda nao existe)
INSERT INTO public.custos_recorrentes (descricao, valor, dia_vencimento, frequencia, data_inicio, ativo, empresa_id, contato_id, plano_contas_id, perfil, origem)
SELECT left(coalesce(c.nome, 'Custo') || ' - ' || pc.nome, 120), round(g.mediana::numeric, 2), g.dia, 'mensal', g.inicio, true, g.empresa_id, g.contato_id, g.plano_contas_id, NULL, 'historico'
  FROM (
        SELECT t.empresa_id, t.contato_id, t.plano_contas_id,
               count(DISTINCT to_char(p.vencimento, 'YYYY-MM')) AS meses,
               max(to_char(p.vencimento, 'YYYY-MM')) AS ultimo,
               percentile_cont(0.5) WITHIN GROUP (ORDER BY p.valor) FILTER (WHERE p.vencimento >= date '2026-08-01') AS mediana,
               least(28, greatest(1, round(avg(extract(day FROM p.vencimento))))::int) AS dia,
               date_trunc('month', min(p.vencimento))::date AS inicio
          FROM public.financeiro_titulos t
          JOIN public.financeiro_parcelas p ON p.titulo_id = t.id
          JOIN public.plano_de_contas pc2 ON pc2.id = t.plano_contas_id
         WHERE t.natureza = 'pagar' AND t.especie = 'despesa' AND t.cancelado_em IS NULL AND t.origem_tipo <> 'custo_recorrente'
           AND p.situacao = 'firme' AND p.valor > 0
           AND p.vencimento >= date '2025-11-01' AND p.vencimento < date '2026-11-01'
           AND pc2.nome ILIKE ANY (ARRAY['ALUGUEL', 'PUBLICIDADE', 'CONTABILIDADE', 'SINDICATO', 'SEGURO', 'SEGURO PATRIMONIAL%', 'TELEFONE E INTERNET',
                                         'CLUBE MAIS MENSAL', 'CLUBE MAIS PONTOS', 'CLUBE MAIS VIAGENS', 'ASSIST_NCIA SOFTWARE', 'ENERGIA EL_TRICA',
                                         'AUTOMA__ES - IA', 'SEGURAN_A'])
         GROUP BY t.empresa_id, t.contato_id, t.plano_contas_id
       ) g
  JOIN public.plano_de_contas pc ON pc.id = g.plano_contas_id
  LEFT JOIN public.contatos c ON c.id = g.contato_id
 WHERE g.meses >= 6 AND g.ultimo >= '2026-09' AND g.mediana > 0
   AND NOT EXISTS (SELECT 1 FROM public.custos_recorrentes x WHERE x.ativo AND x.empresa_id = g.empresa_id
                      AND coalesce(x.contato_id, '00000000-0000-0000-0000-000000000000'::uuid) = coalesce(g.contato_id, '00000000-0000-0000-0000-000000000000'::uuid)
                      AND x.plano_contas_id = g.plano_contas_id);

CREATE OR REPLACE FUNCTION public.financeiro_recorrentes_gerar_interno(p_meses integer DEFAULT 6)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
    c public.custos_recorrentes; m date; v_venc date; v_seq integer; v_tit uuid; v_real boolean; v_passo integer; v_fim_mes date;
    v_par public.financeiro_parcelas; t record;
    v_criadas integer := 0; v_atualizadas integer := 0; v_canceladas integer := 0;
BEGIN
    IF p_meses IS NULL OR p_meses < 1 OR p_meses > 24 THEN
        RAISE EXCEPTION 'Informe de 1 a 24 meses.' USING ERRCODE = 'P0001';
    END IF;

    -- previsao de custo inativo ou fora da vigencia: cancela a que ainda e so previsao (sem parcela firme/baixada)
    FOR t IN
        SELECT ti.id FROM public.financeiro_titulos ti JOIN public.custos_recorrentes cr ON cr.id = ti.custo_recorrente_id
         WHERE ti.cancelado_em IS NULL AND (NOT cr.ativo OR (cr.data_fim IS NOT NULL AND cr.data_fim < current_date))
           AND NOT EXISTS (SELECT 1 FROM public.financeiro_parcelas p WHERE p.titulo_id = ti.id AND (p.situacao <> 'prevista' OR p.valor_liquidado <> 0))
    LOOP
        UPDATE public.financeiro_parcelas SET situacao = 'cancelada' WHERE titulo_id = t.id AND situacao = 'prevista';
        UPDATE public.financeiro_titulos SET cancelado_em = now(), cancelado_por = auth.uid(), motivo_cancelamento = 'Custo recorrente inativo ou encerrado.' WHERE id = t.id;
        v_canceladas := v_canceladas + 1;
    END LOOP;

    FOR c IN SELECT * FROM public.custos_recorrentes WHERE ativo AND empresa_id IS NOT NULL AND plano_contas_id IS NOT NULL
                  AND (data_fim IS NULL OR data_fim >= current_date) ORDER BY created_at, id
    LOOP
        v_passo := CASE c.frequencia::text WHEN 'mensal' THEN 1 WHEN 'trimestral' THEN 3 WHEN 'semestral' THEN 6 ELSE 12 END;
        FOR m IN SELECT g::date FROM generate_series(date_trunc('month', current_date), date_trunc('month', current_date) + make_interval(months => p_meses), interval '1 month') g LOOP
            IF m < date_trunc('month', c.data_inicio)::date THEN CONTINUE; END IF;
            IF c.data_fim IS NOT NULL AND m > c.data_fim THEN CONTINUE; END IF;
            IF (((extract(year FROM m) * 12 + extract(month FROM m)) - (extract(year FROM c.data_inicio) * 12 + extract(month FROM c.data_inicio)))::int % v_passo) <> 0 THEN CONTINUE; END IF;
            v_fim_mes := (m + interval '1 month - 1 day')::date;
            v_venc := m + (least(c.dia_vencimento, extract(day FROM v_fim_mes)::int) - 1);
            v_seq := (extract(year FROM m)::int - 2000) * 12 + extract(month FROM m)::int;

            SELECT EXISTS (
                SELECT 1 FROM public.financeiro_parcelas p JOIN public.financeiro_titulos ti ON ti.id = p.titulo_id
                 WHERE ti.natureza = 'pagar' AND ti.cancelado_em IS NULL AND ti.origem_tipo <> 'custo_recorrente'
                   AND ti.empresa_id = c.empresa_id AND ti.contato_id IS NOT DISTINCT FROM c.contato_id AND ti.plano_contas_id = c.plano_contas_id
                   AND p.situacao IN ('prevista', 'firme') AND p.vencimento >= m AND p.vencimento <= v_fim_mes
            ) INTO v_real;

            SELECT id INTO v_tit FROM public.financeiro_titulos WHERE custo_recorrente_id = c.id AND origem_seq = v_seq;

            IF v_real THEN
                IF v_tit IS NOT NULL AND EXISTS (SELECT 1 FROM public.financeiro_titulos WHERE id = v_tit AND cancelado_em IS NULL)
                   AND NOT EXISTS (SELECT 1 FROM public.financeiro_parcelas p WHERE p.titulo_id = v_tit AND (p.situacao <> 'prevista' OR p.valor_liquidado <> 0)) THEN
                    UPDATE public.financeiro_parcelas SET situacao = 'cancelada' WHERE titulo_id = v_tit AND situacao = 'prevista';
                    UPDATE public.financeiro_titulos SET cancelado_em = now(), cancelado_por = auth.uid(), motivo_cancelamento = 'Conta real lancada para este mes.' WHERE id = v_tit;
                    v_canceladas := v_canceladas + 1;
                END IF;
                CONTINUE;
            END IF;

            IF v_tit IS NULL THEN
                IF v_venc < current_date THEN CONTINUE; END IF;   -- dia do mes corrente que ja passou: nao nasce previsao vencida
                INSERT INTO public.financeiro_titulos (natureza, origem_tipo, origem_seq, custo_recorrente_id, especie, empresa_id, perfil, contato_id, plano_contas_id, descricao, criado_por)
                VALUES ('pagar', 'custo_recorrente', v_seq, c.id, 'despesa', c.empresa_id, c.perfil, c.contato_id, c.plano_contas_id, c.descricao, auth.uid())
                RETURNING id INTO v_tit;
                INSERT INTO public.financeiro_parcelas (titulo_id, numero, vencimento, valor, situacao, observacao, criado_por)
                VALUES (v_tit, 1, v_venc, c.valor, 'prevista', 'Previsao de custo recorrente', auth.uid());
                v_criadas := v_criadas + 1;
            ELSE
                SELECT p.* INTO v_par FROM public.financeiro_parcelas p JOIN public.financeiro_titulos ti ON ti.id = p.titulo_id
                 WHERE p.titulo_id = v_tit AND p.numero = 1 AND ti.cancelado_em IS NULL AND p.situacao = 'prevista' AND p.valor_liquidado = 0;
                IF FOUND AND (v_par.valor <> c.valor OR v_par.vencimento <> v_venc) THEN
                    UPDATE public.financeiro_parcelas SET valor = c.valor, vencimento = v_venc WHERE id = v_par.id;
                    v_atualizadas := v_atualizadas + 1;
                END IF;
            END IF;
        END LOOP;
    END LOOP;
    RETURN jsonb_build_object('criadas', v_criadas, 'atualizadas', v_atualizadas, 'canceladas', v_canceladas);
END $fn$;

CREATE OR REPLACE FUNCTION public.financeiro_gerar_recorrentes(p_meses integer DEFAULT 6)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
BEGIN
    PERFORM public.financeiro_exige('despesa');
    RETURN public.financeiro_recorrentes_gerar_interno(p_meses);
END $fn$;

REVOKE ALL ON FUNCTION public.financeiro_recorrentes_gerar_interno(integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.financeiro_gerar_recorrentes(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.financeiro_gerar_recorrentes(integer) TO authenticated;

CREATE OR REPLACE VIEW public.vw_financeiro_recorrentes_integridade WITH (security_invoker = true) AS
SELECT teste, violacoes FROM (
    SELECT 'recorrente: previsao em mes que ja tem conta real'::text AS teste, count(*) AS violacoes
      FROM public.financeiro_parcelas p JOIN public.financeiro_titulos ti ON ti.id = p.titulo_id JOIN public.custos_recorrentes cr ON cr.id = ti.custo_recorrente_id
     WHERE ti.origem_tipo = 'custo_recorrente' AND ti.cancelado_em IS NULL AND p.situacao = 'prevista'
       AND EXISTS (SELECT 1 FROM public.financeiro_parcelas p2 JOIN public.financeiro_titulos t2 ON t2.id = p2.titulo_id
                    WHERE t2.natureza = 'pagar' AND t2.cancelado_em IS NULL AND t2.origem_tipo <> 'custo_recorrente' AND t2.empresa_id = cr.empresa_id
                      AND t2.contato_id IS NOT DISTINCT FROM cr.contato_id AND t2.plano_contas_id = cr.plano_contas_id AND p2.situacao IN ('prevista', 'firme')
                      AND date_trunc('month', p2.vencimento) = date_trunc('month', p.vencimento))
    UNION ALL
    SELECT 'recorrente: previsao com valor diferente do cadastro', count(*)
      FROM public.financeiro_parcelas p JOIN public.financeiro_titulos ti ON ti.id = p.titulo_id JOIN public.custos_recorrentes cr ON cr.id = ti.custo_recorrente_id
     WHERE ti.origem_tipo = 'custo_recorrente' AND ti.cancelado_em IS NULL AND p.situacao = 'prevista' AND cr.ativo AND p.valor <> cr.valor
    UNION ALL
    SELECT 'recorrente: previsao futura de custo inativo', count(*)
      FROM public.financeiro_parcelas p JOIN public.financeiro_titulos ti ON ti.id = p.titulo_id JOIN public.custos_recorrentes cr ON cr.id = ti.custo_recorrente_id
     WHERE ti.origem_tipo = 'custo_recorrente' AND ti.cancelado_em IS NULL AND p.situacao = 'prevista' AND NOT cr.ativo
    UNION ALL
    SELECT 'recorrente: titulo com mais de uma parcela', count(*) FROM (
        SELECT ti.id FROM public.financeiro_titulos ti JOIN public.financeiro_parcelas p ON p.titulo_id = ti.id
         WHERE ti.origem_tipo = 'custo_recorrente' GROUP BY ti.id HAVING count(*) > 1) x
) q;
GRANT SELECT ON public.vw_financeiro_recorrentes_integridade TO authenticated;

-- geracao diaria (06:40); idempotente
DO $do$
BEGIN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'financeiro_recorrentes_gerar') THEN PERFORM cron.unschedule('financeiro_recorrentes_gerar'); END IF;
    PERFORM cron.schedule('financeiro_recorrentes_gerar', '40 6 * * *', 'select public.financeiro_recorrentes_gerar_interno(6)');
END $do$;

-- primeira geracao
SELECT public.financeiro_recorrentes_gerar_interno(6);
