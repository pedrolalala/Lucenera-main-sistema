-- SPEC-324 (18/11/2026): importar a Folha da contabilidade (holerite mensal .xlsx) e gerar o Contas a Pagar.
-- O navegador le o Excel e manda o JSON; o servidor REVALIDA tudo (soma dos holerites x Totais da contabilidade).
-- Nada de salario individual fora do RH: tabelas sem policy (so por funcao) e salario so com pode_acessar_sistema('rh').
-- Nao mexe em folha_pagamento (771 linhas de teste legadas) nem em outros sistemas.
BEGIN;

-- ---------------------------------------------------------------- tabelas
CREATE TABLE IF NOT EXISTS public.folha_importacoes (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id        uuid NOT NULL REFERENCES public.empresas(id),
  codigo_empresa    text,                       -- codigo da contabilidade (0043/0120/0200)
  ano               int  NOT NULL CHECK (ano BETWEEN 2020 AND 2100),
  mes               int  NOT NULL CHECK (mes BETWEEN 1 AND 12),
  situacao          text NOT NULL DEFAULT 'conferida' CHECK (situacao IN ('conferida','gerada','cancelada')),
  sem_holerites     boolean NOT NULL DEFAULT false,  -- veio so o arquivo de Totais
  perfil            text,
  arquivos          jsonb NOT NULL DEFAULT '[]'::jsonb,   -- [{nome, hash}]
  totais            jsonb NOT NULL,                       -- lido do arquivo Totais
  conferencia       jsonb,                                -- relatorio calculado no servidor
  criado_por        uuid, criado_em timestamptz NOT NULL DEFAULT now(),
  gerada_por        uuid, gerada_em timestamptz,
  cancelada_por     uuid, cancelada_em timestamptz, motivo_cancelamento text
);
CREATE UNIQUE INDEX IF NOT EXISTS folha_importacoes_uq_hash ON public.folha_importacoes (empresa_id, ano, mes, (arquivos::text)) WHERE situacao <> 'cancelada';

CREATE TABLE IF NOT EXISTS public.folha_holerites (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  importacao_id    uuid NOT NULL REFERENCES public.folha_importacoes(id) ON DELETE CASCADE,
  matricula        text NOT NULL,
  nome             text NOT NULL,
  cpf              text,
  cargo            text,
  admissao         date, demissao date,
  vencimentos      numeric(14,2) NOT NULL,
  descontos        numeric(14,2) NOT NULL,
  liquido          numeric(14,2) NOT NULL,
  rubricas         jsonb NOT NULL DEFAULT '[]'::jsonb,   -- [{cod, desc, tipo, ref, valor}]
  funcionario_id   uuid REFERENCES public.funcionarios(id),
  situacao         text NOT NULL DEFAULT 'ok' CHECK (situacao IN ('ok','pendente_cadastro','excluido')),
  motivo_exclusao  text,
  titulo_id        uuid REFERENCES public.financeiro_titulos(id),
  UNIQUE (importacao_id, matricula)
);
CREATE INDEX IF NOT EXISTS folha_holerites_imp_idx ON public.folha_holerites (importacao_id);

CREATE TABLE IF NOT EXISTS public.folha_guias (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  importacao_id   uuid NOT NULL REFERENCES public.folha_importacoes(id) ON DELETE CASCADE,
  empresa_id      uuid NOT NULL,
  ano int NOT NULL, mes int NOT NULL,
  tipo            text NOT NULL CHECK (tipo IN ('gps_inss','fgts','irrf','sindicato','consignado')),
  valor           numeric(14,2) NOT NULL CHECK (valor > 0),
  vencimento      date,
  titulo_id       uuid REFERENCES public.financeiro_titulos(id)
);
-- uma guia ativa por empresa/mes/tipo (reimportar nao duplica)
CREATE UNIQUE INDEX IF NOT EXISTS folha_guias_uq ON public.folha_guias (empresa_id, ano, mes, tipo) WHERE titulo_id IS NOT NULL;

ALTER TABLE public.folha_importacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.folha_holerites   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.folha_guias       ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.folha_importacoes, public.folha_holerites, public.folha_guias FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------- util
CREATE OR REPLACE FUNCTION public.folha_exige_rh() RETURNS void
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF NOT coalesce(public.pode_acessar_sistema('rh'), false) THEN
    RAISE EXCEPTION 'Sem permissao no RH.' USING ERRCODE = '42501';
  END IF;
END $$;
REVOKE ALL ON FUNCTION public.folha_exige_rh() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.folha_exige_rh() TO authenticated;

CREATE OR REPLACE FUNCTION public.folha_digitos(p text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$ SELECT nullif(regexp_replace(coalesce(p,''), '\D', '', 'g'), '') $$;

-- guias calculadas a partir dos Totais (o servidor recalcula; nao confia em "guias" vindas do navegador)
CREATE OR REPLACE FUNCTION public.folha_guias_dos_totais(p_totais jsonb) RETURNS TABLE(tipo text, valor numeric)
LANGUAGE sql IMMUTABLE AS $$
  SELECT x.tipo, x.valor FROM (VALUES
    ('gps_inss',   coalesce((p_totais->>'gps')::numeric, 0)),
    ('fgts',       coalesce((p_totais->>'fgts')::numeric, 0)),
    ('irrf',       coalesce((p_totais->>'irrf')::numeric, 0)),
    ('sindicato',  coalesce((p_totais->>'assistencial')::numeric, 0)),
    ('consignado', coalesce((p_totais->>'consignado')::numeric, 0))
  ) AS x(tipo, valor) WHERE x.valor > 0
$$;

-- ---------------------------------------------------------------- 1. conferir (grava e devolve relatorio)
-- p_importacao: {empresa_id, codigo_empresa, ano, mes, perfil, arquivos:[{nome,hash}],
--   totais:{liquido, vencimentos, descontos, ativos, gps, fgts, irrf, assistencial, consignado},
--   holerites:[{matricula, nome, cpf, cargo, admissao, demissao, vencimentos, descontos, liquido, rubricas:[...]}]}
CREATE OR REPLACE FUNCTION public.folha_importar_conferir(p_importacao jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_emp uuid := (p_importacao->>'empresa_id')::uuid;
  v_ano int := (p_importacao->>'ano')::int;
  v_mes int := (p_importacao->>'mes')::int;
  v_tot jsonb := p_importacao->'totais';
  v_hol jsonb := coalesce(p_importacao->'holerites', '[]'::jsonb);
  v_id uuid; h jsonb;
  v_sum_liq numeric := 0; v_n int := 0; v_sem_cad int := 0; v_func uuid;
  v_dif numeric; v_ok boolean; v_guias numeric := 0; v_conf jsonb; v_sem_hol boolean;
BEGIN
  PERFORM public.folha_exige_rh();
  IF v_emp IS NULL OR v_ano IS NULL OR v_mes IS NULL OR v_tot IS NULL THEN
    RAISE EXCEPTION 'Importacao incompleta (empresa, mes e Totais sao obrigatorios).' USING ERRCODE = 'P0001';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.empresas WHERE id = v_emp) THEN
    RAISE EXCEPTION 'Empresa inexistente.' USING ERRCODE = 'P0001';
  END IF;
  v_sem_hol := jsonb_array_length(v_hol) = 0;

  -- ja existe importacao gerada deste mes?
  IF EXISTS (SELECT 1 FROM public.folha_importacoes WHERE empresa_id = v_emp AND ano = v_ano AND mes = v_mes
             AND situacao = 'gerada' AND NOT sem_holerites)
     OR (v_sem_hol AND EXISTS (SELECT 1 FROM public.folha_importacoes WHERE empresa_id = v_emp AND ano = v_ano AND mes = v_mes AND situacao = 'gerada')) THEN
    RAISE EXCEPTION 'Esta empresa/mes ja foi gerado no Contas a Pagar. Cancele a importacao anterior antes de importar de novo.' USING ERRCODE = 'P0001';
  END IF;
  -- conferencia anterior ainda nao gerada: substituida (nunca apaga, vira cancelada)
  UPDATE public.folha_importacoes SET situacao = 'cancelada', cancelada_por = auth.uid(), cancelada_em = now(),
         motivo_cancelamento = 'Substituida por nova conferencia'
   WHERE empresa_id = v_emp AND ano = v_ano AND mes = v_mes AND situacao = 'conferida';

  INSERT INTO public.folha_importacoes (empresa_id, codigo_empresa, ano, mes, sem_holerites, perfil, arquivos, totais, criado_por)
  VALUES (v_emp, p_importacao->>'codigo_empresa', v_ano, v_mes, v_sem_hol, nullif(p_importacao->>'perfil',''),
          coalesce(p_importacao->'arquivos','[]'::jsonb), v_tot, auth.uid())
  RETURNING id INTO v_id;

  FOR h IN SELECT * FROM jsonb_array_elements(v_hol) LOOP
    IF abs((h->>'vencimentos')::numeric - (h->>'descontos')::numeric - (h->>'liquido')::numeric) > 0.02 THEN
      RAISE EXCEPTION 'Holerite % nao fecha (vencimentos - descontos <> liquido).', h->>'matricula' USING ERRCODE = 'P0001';
    END IF;
    v_func := NULL;
    IF public.folha_digitos(h->>'cpf') IS NOT NULL THEN
      SELECT d.funcionario_id INTO v_func FROM public.funcionarios_detalhes d
       WHERE public.folha_digitos(d.cpf) = public.folha_digitos(h->>'cpf') LIMIT 1;
    END IF;
    INSERT INTO public.folha_holerites (importacao_id, matricula, nome, cpf, cargo, admissao, demissao, vencimentos, descontos, liquido,
                                        rubricas, funcionario_id, situacao)
    VALUES (v_id, h->>'matricula', h->>'nome', public.folha_digitos(h->>'cpf'), h->>'cargo',
            nullif(h->>'admissao','')::date, nullif(h->>'demissao','')::date,
            (h->>'vencimentos')::numeric, (h->>'descontos')::numeric, (h->>'liquido')::numeric,
            coalesce(h->'rubricas','[]'::jsonb), v_func, CASE WHEN v_func IS NULL THEN 'pendente_cadastro' ELSE 'ok' END);
    v_sum_liq := v_sum_liq + (h->>'liquido')::numeric; v_n := v_n + 1;
    IF v_func IS NULL THEN v_sem_cad := v_sem_cad + 1; END IF;
  END LOOP;

  v_dif := round(v_sum_liq - coalesce((v_tot->>'liquido')::numeric, 0), 2);
  v_ok := v_sem_hol OR abs(v_dif) <= 0.05;
  SELECT coalesce(sum(valor), 0) INTO v_guias FROM public.folha_guias_dos_totais(v_tot);
  v_conf := jsonb_build_object(
    'holerites_lidos', v_n, 'funcionarios_totais', (v_tot->>'ativos')::int, 'soma_liquido_holerites', v_sum_liq,
    'liquido_totais', (v_tot->>'liquido')::numeric, 'diferenca', v_dif, 'confere', v_ok,
    'sem_cadastro', v_sem_cad, 'guias', (SELECT coalesce(jsonb_object_agg(tipo, valor), '{}'::jsonb) FROM public.folha_guias_dos_totais(v_tot)),
    'total_guias', v_guias, 'total_empresa', coalesce((v_tot->>'liquido')::numeric, 0) + v_guias, 'sem_holerites', v_sem_hol);
  UPDATE public.folha_importacoes SET conferencia = v_conf WHERE id = v_id;
  RETURN jsonb_build_object('importacao_id', v_id) || v_conf;
END $$;

-- ---------------------------------------------------------------- 2. pendencias: vincular / excluir
CREATE OR REPLACE FUNCTION public.folha_importar_vincular(p_holerite uuid, p_funcionario uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  PERFORM public.folha_exige_rh();
  IF NOT EXISTS (SELECT 1 FROM public.funcionarios WHERE id = p_funcionario) THEN RAISE EXCEPTION 'Funcionario inexistente.' USING ERRCODE = 'P0001'; END IF;
  UPDATE public.folha_holerites h SET funcionario_id = p_funcionario, situacao = 'ok', motivo_exclusao = NULL
   WHERE h.id = p_holerite AND h.titulo_id IS NULL
     AND EXISTS (SELECT 1 FROM public.folha_importacoes i WHERE i.id = h.importacao_id AND i.situacao = 'conferida');
  IF NOT FOUND THEN RAISE EXCEPTION 'Holerite nao encontrado ou importacao ja gerada.' USING ERRCODE = 'P0001'; END IF;
  -- grava o CPF no cadastro se ainda nao tem (para a proxima importacao casar sozinha)
  UPDATE public.funcionarios_detalhes d SET cpf = h.cpf
    FROM public.folha_holerites h WHERE h.id = p_holerite AND d.funcionario_id = p_funcionario AND d.cpf IS NULL AND h.cpf IS NOT NULL;
END $$;

CREATE OR REPLACE FUNCTION public.folha_importar_excluir_holerite(p_holerite uuid, p_motivo text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  PERFORM public.folha_exige_rh();
  IF length(btrim(coalesce(p_motivo,''))) = 0 THEN RAISE EXCEPTION 'Informe o motivo.' USING ERRCODE = 'P0001'; END IF;
  UPDATE public.folha_holerites h SET situacao = 'excluido', motivo_exclusao = p_motivo
   WHERE h.id = p_holerite AND h.titulo_id IS NULL
     AND EXISTS (SELECT 1 FROM public.folha_importacoes i WHERE i.id = h.importacao_id AND i.situacao = 'conferida');
  IF NOT FOUND THEN RAISE EXCEPTION 'Holerite nao encontrado ou importacao ja gerada.' USING ERRCODE = 'P0001'; END IF;
END $$;

-- ---------------------------------------------------------------- 3. gerar titulos (tudo ou nada, idempotente)
-- p_venc: {salario:'YYYY-MM-DD', gps_inss:..., fgts:..., irrf:..., sindicato:..., consignado:...}
-- p_salario_pago_em: se informado, o salario ja nasce com baixa interna (folha paga antes da importacao).
CREATE OR REPLACE FUNCTION public.folha_importar_gerar_titulos(p_importacao uuid, p_venc jsonb, p_salario_pago_em date DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  i public.folha_importacoes; h public.folha_holerites; g record; v_fp uuid; v_sal_base numeric;
  v_tit uuid; v_par uuid; v_pl_sal uuid; v_pl uuid; v_perfil text; v_doc text; v_n_sal int := 0; v_n_guia int := 0; v_skip int := 0;
  v_tot_sal numeric := 0; v_tot_guia numeric := 0; v_venc date; v_nome text;
BEGIN
  PERFORM public.folha_exige_rh();
  SELECT * INTO i FROM public.folha_importacoes WHERE id = p_importacao FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Importacao inexistente.' USING ERRCODE = 'P0001'; END IF;
  IF i.situacao <> 'conferida' THEN RAISE EXCEPTION 'Importacao esta %; so gera a que esta conferida.', i.situacao USING ERRCODE = 'P0001'; END IF;
  IF NOT coalesce((i.conferencia->>'confere')::boolean, false) THEN
    RAISE EXCEPTION 'Os holerites nao batem com os Totais da contabilidade; corrija o arquivo antes de gerar.' USING ERRCODE = 'P0001';
  END IF;
  IF EXISTS (SELECT 1 FROM public.folha_holerites WHERE importacao_id = i.id AND situacao = 'pendente_cadastro') THEN
    RAISE EXCEPTION 'Ha holerites sem cadastro: ligue ao funcionario ou exclua com motivo.' USING ERRCODE = 'P0001';
  END IF;
  -- excluidos nao podem sumir do total em silencio
  IF EXISTS (SELECT 1 FROM public.folha_holerites WHERE importacao_id = i.id AND situacao = 'excluido') AND NOT coalesce((p_venc->>'aceita_excluidos')::boolean, false) THEN
    RAISE EXCEPTION 'Ha holerites excluidos: confirme que o total gerado fica menor que o da contabilidade.' USING ERRCODE = 'P0001';
  END IF;
  v_perfil := coalesce(nullif(i.perfil,''), 'ribeirao');
  v_doc := 'FOLHA ' || lpad(i.mes::text, 2, '0') || '/' || i.ano;

  SELECT id INTO v_pl_sal FROM public.plano_de_contas WHERE codigo_connect = 2010001 AND nome ILIKE 'SALARIOS%' LIMIT 1;
  IF v_pl_sal IS NULL THEN RAISE EXCEPTION 'Plano de contas SALARIOS E ORDENADOS nao encontrado.' USING ERRCODE = 'P0001'; END IF;

  -- salario por funcionario
  FOR h IN SELECT * FROM public.folha_holerites WHERE importacao_id = i.id AND situacao = 'ok' AND titulo_id IS NULL ORDER BY nome LOOP
    IF h.liquido <= 0 THEN v_skip := v_skip + 1; CONTINUE; END IF;
    v_venc := (p_venc->>'salario')::date;
    IF v_venc IS NULL THEN RAISE EXCEPTION 'Informe o vencimento do salario.' USING ERRCODE = 'P0001'; END IF;
    -- origem 'folha' exige folha_pagamento_id (check do financeiro): grava/atualiza a linha do mes
    SELECT coalesce(sum((r->>'valor')::numeric), 0) INTO v_sal_base FROM jsonb_array_elements(h.rubricas) r WHERE r->>'cod' = '00001';
    INSERT INTO public.folha_pagamento (funcionario_id, mes, ano, salario_base, descontos, adicionais, salario_liquido, empresa_id)
    VALUES (h.funcionario_id, i.mes, i.ano, v_sal_base, h.descontos, h.vencimentos - v_sal_base, h.liquido, i.empresa_id)
    ON CONFLICT (funcionario_id, mes, ano) DO UPDATE SET salario_base = EXCLUDED.salario_base, descontos = EXCLUDED.descontos,
        adicionais = EXCLUDED.adicionais, salario_liquido = EXCLUDED.salario_liquido, empresa_id = EXCLUDED.empresa_id
    RETURNING id INTO v_fp;
    v_tit := public.financeiro_criar_titulo(
      jsonb_build_object('natureza','pagar','origem_tipo','folha','origem_seq',1,'folha_pagamento_id',v_fp,'especie','salario','empresa_id',i.empresa_id,
                         'perfil',v_perfil,'funcionario_id',h.funcionario_id,'plano_contas_id',v_pl_sal,'documento',v_doc,
                         'descricao','Folha '||lpad(i.mes::text,2,'0')||'/'||i.ano||' - '||h.nome||' (mat. '||h.matricula||')'),
      jsonb_build_array(jsonb_build_object('vencimento',v_venc,'valor',h.liquido,'situacao','firme','observacao','Importado da folha da contabilidade')));
    UPDATE public.folha_holerites SET titulo_id = v_tit WHERE id = h.id;
    IF p_salario_pago_em IS NOT NULL THEN
      SELECT id INTO v_par FROM public.financeiro_parcelas WHERE titulo_id = v_tit LIMIT 1;
      PERFORM public.financeiro_baixar(v_par, 'baixa_interna', h.liquido, p_salario_pago_em, NULL, NULL,
                                       'Folha paga antes da importacao (SPEC-324)', 0, 0, 0, NULL, NULL, 'manual');
    END IF;
    v_n_sal := v_n_sal + 1; v_tot_sal := v_tot_sal + h.liquido;
  END LOOP;

  -- guias por empresa (INSS/FGTS/IRRF/sindicato/consignado); pula a que ja existe (complemento de importacao so com Totais)
  FOR g IN SELECT * FROM public.folha_guias_dos_totais(i.totais) LOOP
    IF EXISTS (SELECT 1 FROM public.folha_guias x WHERE x.empresa_id = i.empresa_id AND x.ano = i.ano AND x.mes = i.mes AND x.tipo = g.tipo AND x.titulo_id IS NOT NULL) THEN
      v_skip := v_skip + 1; CONTINUE;
    END IF;
    v_venc := (p_venc->>g.tipo)::date;
    IF v_venc IS NULL THEN RAISE EXCEPTION 'Informe o vencimento de %.', g.tipo USING ERRCODE = 'P0001'; END IF;
    SELECT id INTO v_pl FROM public.plano_de_contas WHERE ativo AND (
        (g.tipo = 'gps_inss'   AND codigo_connect = 90000018) OR
        (g.tipo = 'fgts'       AND codigo_connect = 2010012) OR
        (g.tipo = 'irrf'       AND codigo_connect = 2010016) OR
        (g.tipo = 'sindicato'  AND codigo_connect = 2010014) OR
        (g.tipo = 'consignado' AND codigo_connect = 2020041)) LIMIT 1;
    v_nome := CASE g.tipo WHEN 'gps_inss' THEN 'GPS (INSS)' WHEN 'fgts' THEN 'FGTS' WHEN 'irrf' THEN 'IRRF (DARF)'
                          WHEN 'sindicato' THEN 'Contribuicao assistencial (sindicato)' ELSE 'Consignado (repasse ao banco)' END;
    v_tit := public.financeiro_criar_titulo(
      jsonb_build_object('natureza','pagar','origem_tipo','manual','origem_seq',1,'especie','despesa','empresa_id',i.empresa_id,
                         'perfil',v_perfil,'plano_contas_id',v_pl,'documento',v_doc,
                         'descricao',v_nome||' - folha '||lpad(i.mes::text,2,'0')||'/'||i.ano),
      jsonb_build_array(jsonb_build_object('vencimento',v_venc,'valor',g.valor,'situacao','firme','observacao','Importado da folha da contabilidade')));
    INSERT INTO public.folha_guias (importacao_id, empresa_id, ano, mes, tipo, valor, vencimento, titulo_id)
    VALUES (i.id, i.empresa_id, i.ano, i.mes, g.tipo, g.valor, v_venc, v_tit);
    v_n_guia := v_n_guia + 1; v_tot_guia := v_tot_guia + g.valor;
  END LOOP;

  UPDATE public.folha_importacoes SET situacao = 'gerada', gerada_por = auth.uid(), gerada_em = now() WHERE id = i.id;
  RETURN jsonb_build_object('titulos_salario', v_n_sal, 'total_salario', v_tot_sal, 'titulos_guias', v_n_guia, 'total_guias', v_tot_guia, 'pulados', v_skip);
END $$;

-- ---------------------------------------------------------------- 4. cancelar (bloqueia se houver baixa)
CREATE OR REPLACE FUNCTION public.folha_importar_cancelar(p_importacao uuid, p_motivo text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE i public.folha_importacoes; t uuid;
BEGIN
  PERFORM public.folha_exige_rh();
  IF length(btrim(coalesce(p_motivo,''))) = 0 THEN RAISE EXCEPTION 'Informe o motivo do cancelamento.' USING ERRCODE = 'P0001'; END IF;
  SELECT * INTO i FROM public.folha_importacoes WHERE id = p_importacao FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Importacao inexistente.' USING ERRCODE = 'P0001'; END IF;
  IF i.situacao = 'cancelada' THEN RAISE EXCEPTION 'Importacao ja cancelada.' USING ERRCODE = 'P0001'; END IF;
  FOR t IN SELECT titulo_id FROM public.folha_holerites WHERE importacao_id = i.id AND titulo_id IS NOT NULL
           UNION SELECT titulo_id FROM public.folha_guias WHERE importacao_id = i.id AND titulo_id IS NOT NULL LOOP
    PERFORM public.financeiro_cancelar_titulo(t, 'Folha cancelada: ' || p_motivo);   -- barra se houver baixa
  END LOOP;
  UPDATE public.folha_guias SET titulo_id = NULL WHERE importacao_id = i.id;          -- libera a chave unica (historico fica no titulo cancelado)
  UPDATE public.folha_importacoes SET situacao = 'cancelada', cancelada_por = auth.uid(), cancelada_em = now(), motivo_cancelamento = p_motivo WHERE id = i.id;
END $$;

-- ---------------------------------------------------------------- 5. leitura para a tela
CREATE OR REPLACE FUNCTION public.folha_importar_listar(p_limite int DEFAULT 60) RETURNS TABLE(
  id uuid, empresa_id uuid, empresa text, ano int, mes int, situacao text, sem_holerites boolean, criado_em timestamptz, gerada_em timestamptz,
  holerites int, pendentes int, total_liquido numeric, conferencia jsonb)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  PERFORM public.folha_exige_rh();
  RETURN QUERY
  SELECT i.id, i.empresa_id, e.nome::text, i.ano, i.mes, i.situacao, i.sem_holerites, i.criado_em, i.gerada_em,
         (SELECT count(*)::int FROM public.folha_holerites h WHERE h.importacao_id = i.id),
         (SELECT count(*)::int FROM public.folha_holerites h WHERE h.importacao_id = i.id AND h.situacao = 'pendente_cadastro'),
         (SELECT coalesce(sum(h.liquido),0) FROM public.folha_holerites h WHERE h.importacao_id = i.id),
         i.conferencia
    FROM public.folha_importacoes i JOIN public.empresas e ON e.id = i.empresa_id
   ORDER BY i.ano DESC, i.mes DESC, i.criado_em DESC LIMIT greatest(p_limite, 1);
END $$;

CREATE OR REPLACE FUNCTION public.folha_importar_detalhe(p_importacao uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE r jsonb;
BEGIN
  PERFORM public.folha_exige_rh();
  SELECT jsonb_build_object(
    'importacao', to_jsonb(i) - 'arquivos',
    'holerites', (SELECT coalesce(jsonb_agg(jsonb_build_object('id',h.id,'matricula',h.matricula,'nome',h.nome,'cpf',h.cpf,'cargo',h.cargo,
                    'vencimentos',h.vencimentos,'descontos',h.descontos,'liquido',h.liquido,'situacao',h.situacao,'motivo_exclusao',h.motivo_exclusao,
                    'funcionario_id',h.funcionario_id,'titulo_id',h.titulo_id) ORDER BY h.nome), '[]'::jsonb) FROM public.folha_holerites h WHERE h.importacao_id = i.id),
    'guias', (SELECT coalesce(jsonb_agg(jsonb_build_object('tipo',tipo,'valor',valor,'vencimento',vencimento,'titulo_id',titulo_id)), '[]'::jsonb) FROM public.folha_guias WHERE importacao_id = i.id),
    'guias_previstas', (SELECT coalesce(jsonb_agg(jsonb_build_object('tipo',tipo,'valor',valor)), '[]'::jsonb) FROM public.folha_guias_dos_totais(i.totais)))
  INTO r FROM public.folha_importacoes i WHERE i.id = p_importacao;
  IF r IS NULL THEN RAISE EXCEPTION 'Importacao inexistente.' USING ERRCODE = 'P0001'; END IF;
  RETURN r;
END $$;

-- ---------------------------------------------------------------- permissoes das funcoes
DO $$ DECLARE f text; BEGIN
  FOREACH f IN ARRAY ARRAY[
    'folha_importar_conferir(jsonb)', 'folha_importar_vincular(uuid,uuid)', 'folha_importar_excluir_holerite(uuid,text)',
    'folha_importar_gerar_titulos(uuid,jsonb,date)', 'folha_importar_cancelar(uuid,text)', 'folha_importar_listar(int)',
    'folha_importar_detalhe(uuid)', 'folha_guias_dos_totais(jsonb)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated', f);
  END LOOP;
END $$;

COMMIT;
