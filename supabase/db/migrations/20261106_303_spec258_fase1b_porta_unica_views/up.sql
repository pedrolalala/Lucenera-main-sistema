-- SPEC-258 Fase 1B: porta única de gravação (funções) + views de leitura + view de integridade.
-- Só ACRESCENTA: não altera nenhuma tabela/view existente. As tabelas da 1A seguem sem dados.
-- Toda gravação financeira nova passa por estas funções (SECURITY DEFINER). Ninguém escreve direto na tabela.

-- ===================================================================== permissão (interna)
-- Usuário logado: precisa do sistema 'financeiro' (ou 'rh' para salário/comissão). Sem usuário (service_role/migração): liberado.
-- EXECUTE só para authenticated e service_role; anon nunca chama.
CREATE OR REPLACE FUNCTION public.financeiro_exige(p_especie public.fin_especie) RETURNS void
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $f$
BEGIN
    IF auth.uid() IS NULL THEN RETURN; END IF;
    IF p_especie IN ('salario', 'comissao') THEN
        IF NOT public.pode_acessar_sistema('rh') THEN
            RAISE EXCEPTION 'Sem permissão para lançar salário/comissão.' USING ERRCODE = '42501';
        END IF;
    ELSIF NOT public.pode_acessar_sistema('financeiro') THEN
        RAISE EXCEPTION 'Sem permissão no financeiro.' USING ERRCODE = '42501';
    END IF;
END $f$;

-- ===================================================================== criar título + parcelas
-- p_titulo: json com as colunas do título (natureza, origem_tipo, origem FK, especie, empresa_id, contato_id, plano_contas_id, ...).
-- p_parcelas: json array [{vencimento, valor, situacao ('prevista'|'firme'), forma_prevista, observacao}]
CREATE OR REPLACE FUNCTION public.financeiro_criar_titulo(p_titulo jsonb, p_parcelas jsonb) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
DECLARE r public.financeiro_titulos; v_id uuid; p jsonb; n int := 0; v_sit public.fin_situacao;
BEGIN
    r := jsonb_populate_record(NULL::public.financeiro_titulos, p_titulo);
    PERFORM public.financeiro_exige(r.especie);
    IF p_parcelas IS NULL OR jsonb_typeof(p_parcelas) <> 'array' OR jsonb_array_length(p_parcelas) = 0 THEN
        RAISE EXCEPTION 'Título precisa de ao menos uma parcela.' USING ERRCODE = 'P0001';
    END IF;
    IF r.origem_tipo = 'legado_connect' THEN
        RAISE EXCEPTION 'Origem legado_connect só entra pela migração.' USING ERRCODE = 'P0001';
    END IF;
    INSERT INTO public.financeiro_titulos (natureza, origem_tipo, origem_seq, orcamento_id, pedido_compra_id, nota_fiscal_compra_id, folha_pagamento_id,
            custo_recorrente_id, regra_repasse_id, especie, empresa_id, perfil, contato_id, funcionario_id, plano_contas_id, projeto_id, documento, descricao,
            substitui_titulo_id, titulo_base_id, titulo_compensado_id, criado_por)
    VALUES (r.natureza, r.origem_tipo, coalesce(r.origem_seq, 1), r.orcamento_id, r.pedido_compra_id, r.nota_fiscal_compra_id, r.folha_pagamento_id,
            r.custo_recorrente_id, r.regra_repasse_id, r.especie, r.empresa_id, r.perfil, r.contato_id, r.funcionario_id, r.plano_contas_id, r.projeto_id,
            r.documento, r.descricao, r.substitui_titulo_id, r.titulo_base_id, r.titulo_compensado_id, auth.uid())
    RETURNING id INTO v_id;
    FOR p IN SELECT * FROM jsonb_array_elements(p_parcelas) LOOP
        n := n + 1;
        v_sit := coalesce((p->>'situacao')::public.fin_situacao, 'prevista');
        IF v_sit NOT IN ('prevista', 'firme') THEN
            RAISE EXCEPTION 'Parcela nova só pode nascer prevista ou firme.' USING ERRCODE = 'P0001';
        END IF;
        IF coalesce((p->>'valor')::numeric, 0) <= 0 THEN
            RAISE EXCEPTION 'Parcela % com valor inválido.', n USING ERRCODE = 'P0001';
        END IF;
        INSERT INTO public.financeiro_parcelas (titulo_id, numero, vencimento, valor, situacao, confirmada_em, confirmada_por, forma_prevista, observacao, criado_por)
        VALUES (v_id, n, (p->>'vencimento')::date, (p->>'valor')::numeric, v_sit,
                CASE WHEN v_sit = 'firme' THEN now() END, CASE WHEN v_sit = 'firme' THEN auth.uid() END,
                p->>'forma_prevista', p->>'observacao', auth.uid());
    END LOOP;
    RETURN v_id;
END $f$;

-- ===================================================================== confirmar previsão (prevista -> firme)
CREATE OR REPLACE FUNCTION public.financeiro_confirmar_parcelas(p_titulo uuid) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
DECLARE v_esp public.fin_especie; v_n integer;
BEGIN
    SELECT especie INTO v_esp FROM public.financeiro_titulos WHERE id = p_titulo AND cancelado_em IS NULL;
    IF v_esp IS NULL THEN RAISE EXCEPTION 'Título inexistente ou cancelado.' USING ERRCODE = 'P0001'; END IF;
    PERFORM public.financeiro_exige(v_esp);
    UPDATE public.financeiro_parcelas SET situacao = 'firme', confirmada_em = now(), confirmada_por = auth.uid()
     WHERE titulo_id = p_titulo AND situacao = 'prevista';
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $f$;

-- ===================================================================== substituir a previsão (as previstas viram 'substituida'; entram parcelas novas)
CREATE OR REPLACE FUNCTION public.financeiro_substituir_previsao(p_titulo uuid, p_parcelas jsonb) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
DECLARE v_esp public.fin_especie; p jsonb; v_max int; n int := 0; v_sit public.fin_situacao;
BEGIN
    SELECT especie INTO v_esp FROM public.financeiro_titulos WHERE id = p_titulo AND cancelado_em IS NULL;
    IF v_esp IS NULL THEN RAISE EXCEPTION 'Título inexistente ou cancelado.' USING ERRCODE = 'P0001'; END IF;
    PERFORM public.financeiro_exige(v_esp);
    IF p_parcelas IS NULL OR jsonb_typeof(p_parcelas) <> 'array' OR jsonb_array_length(p_parcelas) = 0 THEN
        RAISE EXCEPTION 'Informe as parcelas novas.' USING ERRCODE = 'P0001';
    END IF;
    UPDATE public.financeiro_parcelas SET situacao = 'substituida' WHERE titulo_id = p_titulo AND situacao = 'prevista';
    SELECT coalesce(max(numero), 0) INTO v_max FROM public.financeiro_parcelas WHERE titulo_id = p_titulo;
    FOR p IN SELECT * FROM jsonb_array_elements(p_parcelas) LOOP
        n := n + 1;
        v_sit := coalesce((p->>'situacao')::public.fin_situacao, 'prevista');
        IF v_sit NOT IN ('prevista', 'firme') OR coalesce((p->>'valor')::numeric, 0) <= 0 THEN
            RAISE EXCEPTION 'Parcela nova inválida (situação/valor).' USING ERRCODE = 'P0001';
        END IF;
        INSERT INTO public.financeiro_parcelas (titulo_id, numero, vencimento, valor, situacao, confirmada_em, confirmada_por, forma_prevista, observacao, criado_por)
        VALUES (p_titulo, v_max + n, (p->>'vencimento')::date, (p->>'valor')::numeric, v_sit,
                CASE WHEN v_sit = 'firme' THEN now() END, CASE WHEN v_sit = 'firme' THEN auth.uid() END,
                p->>'forma_prevista', p->>'observacao', auth.uid());
    END LOOP;
    RETURN n;
END $f$;

-- ===================================================================== cancelar título (nunca apaga; com baixa, estorne antes)
CREATE OR REPLACE FUNCTION public.financeiro_cancelar_titulo(p_titulo uuid, p_motivo text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
DECLARE v_esp public.fin_especie;
BEGIN
    IF length(btrim(coalesce(p_motivo, ''))) = 0 THEN RAISE EXCEPTION 'Informe o motivo do cancelamento.' USING ERRCODE = 'P0001'; END IF;
    SELECT especie INTO v_esp FROM public.financeiro_titulos WHERE id = p_titulo AND cancelado_em IS NULL;
    IF v_esp IS NULL THEN RAISE EXCEPTION 'Título inexistente ou já cancelado.' USING ERRCODE = 'P0001'; END IF;
    PERFORM public.financeiro_exige(v_esp);
    IF EXISTS (SELECT 1 FROM public.financeiro_parcelas WHERE titulo_id = p_titulo AND valor_liquidado <> 0) THEN
        RAISE EXCEPTION 'Há baixa nas parcelas: estorne as baixas antes de cancelar o título.' USING ERRCODE = 'P0001';
    END IF;
    UPDATE public.financeiro_parcelas SET situacao = 'cancelada' WHERE titulo_id = p_titulo AND situacao IN ('prevista', 'firme');
    UPDATE public.financeiro_titulos SET cancelado_em = now(), cancelado_por = auth.uid(), motivo_cancelamento = p_motivo WHERE id = p_titulo;
END $f$;

-- ===================================================================== baixar (receber/pagar/compensar/abater/baixa interna)
CREATE OR REPLACE FUNCTION public.financeiro_baixar(
    p_parcela uuid, p_tipo public.fin_baixa_tipo, p_valor numeric, p_data date DEFAULT current_date,
    p_conta_bancaria uuid DEFAULT NULL, p_forma text DEFAULT NULL, p_motivo text DEFAULT NULL,
    p_juros numeric DEFAULT 0, p_multa numeric DEFAULT 0, p_desconto numeric DEFAULT 0,
    p_empresa_pagadora uuid DEFAULT NULL, p_comprovante_url text DEFAULT NULL, p_origem text DEFAULT 'manual') RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
DECLARE v_par public.financeiro_parcelas; v_tit public.financeiro_titulos; v_id uuid;
BEGIN
    IF p_tipo = 'estorno' THEN RAISE EXCEPTION 'Para estornar use financeiro_estornar.' USING ERRCODE = 'P0001'; END IF;
    IF p_origem = 'legado' THEN RAISE EXCEPTION 'Origem legado só pela migração.' USING ERRCODE = 'P0001'; END IF;
    SELECT * INTO v_par FROM public.financeiro_parcelas WHERE id = p_parcela FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Parcela inexistente.' USING ERRCODE = 'P0001'; END IF;
    SELECT * INTO v_tit FROM public.financeiro_titulos WHERE id = v_par.titulo_id;
    PERFORM public.financeiro_exige(v_tit.especie);
    IF v_tit.cancelado_em IS NOT NULL THEN RAISE EXCEPTION 'Título cancelado.' USING ERRCODE = 'P0001'; END IF;
    IF (p_tipo = 'recebimento' AND v_tit.natureza <> 'receber') OR (p_tipo = 'pagamento' AND v_tit.natureza <> 'pagar') THEN
        RAISE EXCEPTION 'Tipo % não combina com título a %.', p_tipo, v_tit.natureza USING ERRCODE = 'P0001';
    END IF;
    IF p_valor > v_par.valor - v_par.valor_liquidado THEN
        RAISE EXCEPTION 'Valor da baixa (%) maior que o saldo da parcela (%).', p_valor, v_par.valor - v_par.valor_liquidado USING ERRCODE = 'P0001';
    END IF;
    INSERT INTO public.financeiro_baixas (parcela_id, tipo, data, valor, juros, multa, desconto, forma, conta_bancaria_id, empresa_pagadora_id, comprovante_url, motivo, origem_baixa, criado_por)
    VALUES (p_parcela, p_tipo, p_data, p_valor, coalesce(p_juros, 0), coalesce(p_multa, 0), coalesce(p_desconto, 0), p_forma, p_conta_bancaria, p_empresa_pagadora,
            p_comprovante_url, p_motivo, p_origem, auth.uid())
    RETURNING id INTO v_id;
    RETURN v_id;
END $f$;

-- ===================================================================== estornar (nunca edita nem apaga a baixa)
CREATE OR REPLACE FUNCTION public.financeiro_estornar(p_baixa uuid, p_motivo text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
DECLARE b public.financeiro_baixas; v_esp public.fin_especie; v_id uuid;
BEGIN
    IF length(btrim(coalesce(p_motivo, ''))) = 0 THEN RAISE EXCEPTION 'Informe o motivo do estorno.' USING ERRCODE = 'P0001'; END IF;
    SELECT * INTO b FROM public.financeiro_baixas WHERE id = p_baixa;
    IF NOT FOUND OR b.tipo = 'estorno' THEN RAISE EXCEPTION 'Baixa inexistente ou já é um estorno.' USING ERRCODE = 'P0001'; END IF;
    SELECT t.especie INTO v_esp FROM public.financeiro_parcelas p JOIN public.financeiro_titulos t ON t.id = p.titulo_id WHERE p.id = b.parcela_id;
    PERFORM public.financeiro_exige(v_esp);
    PERFORM 1 FROM public.financeiro_parcelas WHERE id = b.parcela_id FOR UPDATE;
    IF EXISTS (SELECT 1 FROM public.financeiro_baixas WHERE estorno_de = p_baixa) THEN
        RAISE EXCEPTION 'Esta baixa já foi estornada.' USING ERRCODE = 'P0001';
    END IF;
    INSERT INTO public.financeiro_baixas (parcela_id, tipo, data, valor, forma, conta_bancaria_id, empresa_pagadora_id, motivo, origem_baixa, estorno_de, criado_por)
    VALUES (b.parcela_id, 'estorno', current_date, b.valor, b.forma, b.conta_bancaria_id, b.empresa_pagadora_id, p_motivo, 'manual', p_baixa, auth.uid())
    RETURNING id INTO v_id;
    RETURN v_id;
END $f$;

-- ===================================================================== pendências: abrir / resolver / aceitar
CREATE OR REPLACE FUNCTION public.financeiro_abrir_pendencia(p_tipo text, p_descricao text, p_titulo uuid DEFAULT NULL, p_parcela uuid DEFAULT NULL, p_baixa uuid DEFAULT NULL, p_responsavel text DEFAULT NULL) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
DECLARE v_id uuid;
BEGIN
    PERFORM public.financeiro_exige('outro');
    INSERT INTO public.financeiro_pendencias (titulo_id, parcela_id, baixa_id, tipo, descricao, responsavel) VALUES (p_titulo, p_parcela, p_baixa, p_tipo, p_descricao, p_responsavel) RETURNING id INTO v_id;
    RETURN v_id;
END $f$;

CREATE OR REPLACE FUNCTION public.financeiro_resolver_pendencia(p_pendencia uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
BEGIN
    PERFORM public.financeiro_exige('outro');
    UPDATE public.financeiro_pendencias SET status = 'resolvida', resolvida_em = now(), resolvida_por = auth.uid() WHERE id = p_pendencia AND status = 'aberta';
    IF NOT FOUND THEN RAISE EXCEPTION 'Pendência inexistente ou já tratada.' USING ERRCODE = 'P0001'; END IF;
END $f$;

-- "aceitar" = decidir conviver com o problema: exige motivo e é só de administrador
CREATE OR REPLACE FUNCTION public.financeiro_aceitar_pendencia(p_pendencia uuid, p_motivo text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
BEGIN
    PERFORM public.financeiro_exige('outro');
    IF auth.uid() IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.usuarios u WHERE u.id = auth.uid() AND u.role = 'admin') THEN
        RAISE EXCEPTION 'Só administrador aceita uma pendência.' USING ERRCODE = '42501';
    END IF;
    IF length(btrim(coalesce(p_motivo, ''))) = 0 THEN RAISE EXCEPTION 'Informe o motivo do aceite.' USING ERRCODE = 'P0001'; END IF;
    UPDATE public.financeiro_pendencias SET status = 'aceita', motivo_aceite = p_motivo, aceita_por = coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid), aceita_em = now()
     WHERE id = p_pendencia AND status = 'aberta';
    IF NOT FOUND THEN RAISE EXCEPTION 'Pendência inexistente ou já tratada.' USING ERRCODE = 'P0001'; END IF;
END $f$;

REVOKE ALL ON FUNCTION public.financeiro_exige(public.fin_especie), public.financeiro_criar_titulo(jsonb, jsonb), public.financeiro_confirmar_parcelas(uuid),
    public.financeiro_substituir_previsao(uuid, jsonb), public.financeiro_cancelar_titulo(uuid, text),
    public.financeiro_baixar(uuid, public.fin_baixa_tipo, numeric, date, uuid, text, text, numeric, numeric, numeric, uuid, text, text),
    public.financeiro_estornar(uuid, text), public.financeiro_abrir_pendencia(text, text, uuid, uuid, uuid, text),
    public.financeiro_resolver_pendencia(uuid), public.financeiro_aceitar_pendencia(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.financeiro_criar_titulo(jsonb, jsonb), public.financeiro_confirmar_parcelas(uuid),
    public.financeiro_substituir_previsao(uuid, jsonb), public.financeiro_cancelar_titulo(uuid, text),
    public.financeiro_baixar(uuid, public.fin_baixa_tipo, numeric, date, uuid, text, text, numeric, numeric, numeric, uuid, text, text),
    public.financeiro_estornar(uuid, text), public.financeiro_abrir_pendencia(text, text, uuid, uuid, uuid, text),
    public.financeiro_resolver_pendencia(uuid), public.financeiro_aceitar_pendencia(uuid, text) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.financeiro_exige(public.fin_especie) FROM authenticated;

-- ===================================================================== views de leitura (security_invoker: valem as regras de acesso das tabelas)
CREATE OR REPLACE VIEW public.vw_financeiro_parcelas WITH (security_invoker = true) AS
SELECT p.id AS parcela_id, t.id AS titulo_id, t.natureza, t.origem_tipo, t.especie, t.empresa_id, t.perfil, t.contato_id, c.nome AS contato_nome,
       t.funcionario_id, t.plano_contas_id, t.projeto_id, t.documento, t.descricao, t.legado_cod_duplicata,
       p.numero, p.vencimento, p.valor, p.valor_liquidado, (p.valor - p.valor_liquidado) AS saldo, p.situacao, p.forma_prevista,
       (p.situacao = 'prevista') AS e_previsao,
       CASE WHEN p.situacao IN ('cancelada', 'substituida', 'renegociada') THEN p.situacao::text
            WHEN p.valor_liquidado >= p.valor THEN 'quitada'
            WHEN p.valor_liquidado > 0 THEN 'parcial'
            WHEN p.vencimento < current_date THEN 'vencida'
            ELSE 'a_vencer' END AS status
FROM public.financeiro_parcelas p
JOIN public.financeiro_titulos t ON t.id = p.titulo_id
LEFT JOIN public.contatos c ON c.id = t.contato_id;

CREATE OR REPLACE VIEW public.vw_contas_a_receber WITH (security_invoker = true) AS
SELECT * FROM public.vw_financeiro_parcelas WHERE natureza = 'receber' AND situacao IN ('prevista', 'firme');
CREATE OR REPLACE VIEW public.vw_contas_a_pagar WITH (security_invoker = true) AS
SELECT * FROM public.vw_financeiro_parcelas WHERE natureza = 'pagar' AND situacao IN ('prevista', 'firme');

-- histórico: tudo que foi pago/recebido (e estornado), com sinal
CREATE OR REPLACE VIEW public.vw_historico_baixas WITH (security_invoker = true) AS
SELECT b.id AS baixa_id, b.parcela_id, t.id AS titulo_id, t.natureza, t.especie, t.empresa_id, t.contato_id, c.nome AS contato_nome, t.documento,
       b.tipo, b.data, b.valor, CASE WHEN b.tipo = 'estorno' THEN -b.valor ELSE b.valor END AS valor_com_sinal,
       b.juros, b.multa, b.desconto, b.forma, b.conta_bancaria_id, b.empresa_pagadora_id, b.motivo, b.origem_baixa, b.estorno_de, b.criado_em, b.criado_por
FROM public.financeiro_baixas b
JOIN public.financeiro_parcelas p ON p.id = b.parcela_id
JOIN public.financeiro_titulos t ON t.id = p.titulo_id
LEFT JOIN public.contatos c ON c.id = t.contato_id;

-- fluxo de caixa: realizado (dinheiro que entrou/saiu) + previsto/firme (saldo em aberto por vencimento).
-- Folha (salário/comissão) aparece SOMADA, sem nomes: por isso a view roda com os direitos do dono e confere a permissão do financeiro.
CREATE OR REPLACE VIEW public.vw_fluxo_caixa AS
WITH realizado AS (
    SELECT b.data AS data, t.natureza, 'realizado'::text AS situacao_fluxo, t.empresa_id,
           CASE WHEN t.especie IN ('salario', 'comissao') THEN 'folha' ELSE t.especie::text END AS grupo,
           sum(CASE WHEN b.tipo = 'estorno' THEN -b.valor ELSE b.valor END) AS valor
    FROM public.financeiro_baixas b
    JOIN public.financeiro_parcelas p ON p.id = b.parcela_id
    JOIN public.financeiro_titulos t ON t.id = p.titulo_id
    LEFT JOIN public.financeiro_baixas o ON o.id = b.estorno_de
    WHERE (b.tipo IN ('recebimento', 'pagamento')) OR (b.tipo = 'estorno' AND o.tipo IN ('recebimento', 'pagamento'))
    GROUP BY 1, 2, 4, 5
), aberto AS (
    SELECT p.vencimento AS data, t.natureza, CASE WHEN p.situacao = 'prevista' THEN 'previsto' ELSE 'firme' END AS situacao_fluxo, t.empresa_id,
           CASE WHEN t.especie IN ('salario', 'comissao') THEN 'folha' ELSE t.especie::text END AS grupo,
           sum(p.valor - p.valor_liquidado) AS valor
    FROM public.financeiro_parcelas p JOIN public.financeiro_titulos t ON t.id = p.titulo_id
    WHERE p.situacao IN ('prevista', 'firme') AND p.valor_liquidado < p.valor AND t.cancelado_em IS NULL
    GROUP BY 1, 2, 3, 4, 5
)
SELECT * FROM (SELECT * FROM realizado UNION ALL SELECT * FROM aberto) f
WHERE (SELECT public.pode_acessar_sistema('financeiro'));

-- integridade: cada linha é uma regra; violacoes deve ser sempre 0 (pendencias_abertas é informativo)
CREATE OR REPLACE VIEW public.vw_financeiro_novo_integridade AS
SELECT teste, violacoes FROM (
    SELECT 'parcela com liquidado diferente da soma das baixas'::text AS teste, count(*)::bigint AS violacoes FROM public.financeiro_parcelas p
      WHERE p.valor_liquidado <> coalesce((SELECT sum(CASE WHEN b.tipo = 'estorno' THEN -b.valor ELSE b.valor END) FROM public.financeiro_baixas b WHERE b.parcela_id = p.id), 0)
    UNION ALL SELECT 'parcela liquidada acima do valor', count(*) FROM public.financeiro_parcelas WHERE valor_liquidado > valor
    UNION ALL SELECT 'parcela com liquidado negativo', count(*) FROM public.financeiro_parcelas WHERE valor_liquidado < 0
    UNION ALL SELECT 'titulo sem nenhuma parcela', count(*) FROM public.financeiro_titulos t WHERE NOT EXISTS (SELECT 1 FROM public.financeiro_parcelas p WHERE p.titulo_id = t.id)
    UNION ALL SELECT 'titulo cancelado com parcela ativa', count(*) FROM public.financeiro_parcelas p JOIN public.financeiro_titulos t ON t.id = p.titulo_id
      WHERE t.cancelado_em IS NOT NULL AND p.situacao IN ('prevista', 'firme')
    UNION ALL SELECT 'parcela cancelada/substituida com saldo liquidado', count(*) FROM public.financeiro_parcelas WHERE situacao IN ('cancelada', 'substituida') AND valor_liquidado <> 0
    UNION ALL SELECT 'baixa estornada mais de uma vez', count(*) FROM (SELECT estorno_de FROM public.financeiro_baixas WHERE estorno_de IS NOT NULL GROUP BY 1 HAVING count(*) > 1) x
    UNION ALL SELECT 'estorno com valor diferente da baixa original', count(*) FROM public.financeiro_baixas e JOIN public.financeiro_baixas o ON o.id = e.estorno_de WHERE e.valor <> o.valor
    UNION ALL SELECT 'recebimento em titulo a pagar (ou pagamento em a receber)', count(*) FROM public.financeiro_baixas b JOIN public.financeiro_parcelas p ON p.id = b.parcela_id JOIN public.financeiro_titulos t ON t.id = p.titulo_id
      WHERE (b.tipo = 'recebimento' AND t.natureza <> 'receber') OR (b.tipo = 'pagamento' AND t.natureza <> 'pagar')
    UNION ALL SELECT 'titulo sem evento de criacao no historico permanente', count(*) FROM public.financeiro_titulos t
      WHERE NOT EXISTS (SELECT 1 FROM public.financeiro_eventos e WHERE e.tabela = 'financeiro_titulos' AND e.registro_id = t.id AND e.operacao = 'INSERT')
    UNION ALL SELECT 'baixa sem evento de criacao no historico permanente', count(*) FROM public.financeiro_baixas b
      WHERE NOT EXISTS (SELECT 1 FROM public.financeiro_eventos e WHERE e.tabela = 'financeiro_baixas' AND e.registro_id = b.id AND e.operacao = 'INSERT')
    UNION ALL SELECT 'parcela firme sem confirmacao nem codigo da Connect', count(*) FROM public.financeiro_parcelas WHERE situacao = 'firme' AND confirmada_em IS NULL AND legado_cod_itens_duplicata IS NULL
    UNION ALL SELECT 'titulo nativo sem plano de contas', count(*) FROM public.financeiro_titulos WHERE origem_tipo <> 'legado_connect' AND plano_contas_id IS NULL
    UNION ALL SELECT 'regra_repasse sem titulo base', count(*) FROM public.financeiro_titulos WHERE origem_tipo = 'regra_repasse' AND titulo_base_id IS NULL
    UNION ALL SELECT 'pendencias abertas (informativo, nao e erro)', count(*) FROM public.financeiro_pendencias WHERE status = 'aberta'
) z
WHERE (SELECT public.pode_acessar_sistema('financeiro'));

GRANT SELECT ON public.vw_financeiro_parcelas, public.vw_contas_a_receber, public.vw_contas_a_pagar, public.vw_historico_baixas,
                public.vw_fluxo_caixa, public.vw_financeiro_novo_integridade TO authenticated;
REVOKE ALL ON public.vw_financeiro_parcelas, public.vw_contas_a_receber, public.vw_contas_a_pagar, public.vw_historico_baixas,
              public.vw_fluxo_caixa, public.vw_financeiro_novo_integridade FROM anon;
