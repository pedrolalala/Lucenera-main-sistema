-- SPEC-258 Fase 2: copia o legado da Connect para o modelo novo. SÓ COPIA: nenhuma tabela antiga é alterada ou apagada.
-- Regra: a Connect (planilha de 05/11/2026 = connect_contas_espelho) é a verdade do legado.
--   * ATIVAS  = as parcelas da v_financeiro_realizado (18.316 hoje; já batem 1:1 com o espelho).
--   * CANCELADAS = parcelas canceladas no banco que o espelho TAMBÉM mostra como canceladas (pago = 2), uma por código de parcela.
--   * NÃO migram: extras que não estão na Connect (pagas/canceladas fora do espelho) e as canceladas-com-pagamento sem origem (1.527, ficam na conferência do Financeiro).
-- Baixas: pago com valor -> recebimento/pagamento (excesso sobre a parcela vira juros; falta vira abatimento); pago com valor ZERO -> baixa_interna.
-- Cancelada NUNCA vira baixa. Itens duvidosos entram em financeiro_pendencias.

-- 0) trava: só roda com as tabelas novas vazias (Fase 2 é carga única)
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM public.financeiro_titulos) OR EXISTS (SELECT 1 FROM public.financeiro_parcelas) THEN
        RAISE EXCEPTION 'Fase 2 já executada ou tabelas novas com dados: não rodar de novo.';
    END IF;
END $$;

-- 1) o que será copiado
CREATE TEMP TABLE _f2_ativas ON COMMIT DROP AS
SELECT t.id AS transacao_id, 'ativa'::text AS classe FROM public.transacoes t WHERE t.id IN (SELECT id FROM public.v_financeiro_realizado);

CREATE TEMP TABLE _f2_canc ON COMMIT DROP AS
SELECT DISTINCT ON (t.cod_itens_duplicata, t.tipo) t.id AS transacao_id, 'cancelada'::text AS classe
FROM public.transacoes t
WHERE t.status_pago = 2
  AND EXISTS (SELECT 1 FROM public.connect_contas_espelho e WHERE e.cod_itens_duplicata = t.cod_itens_duplicata AND e.tipo = t.tipo::text AND e.pago = 2)
  AND t.id NOT IN (SELECT transacao_id FROM _f2_ativas)
  AND NOT EXISTS (SELECT 1 FROM _f2_ativas a JOIN public.transacoes x ON x.id = a.transacao_id WHERE x.cod_itens_duplicata = t.cod_itens_duplicata AND x.tipo = t.tipo)
ORDER BY t.cod_itens_duplicata, t.tipo, t.created_at DESC, t.id;

CREATE TEMP TABLE _f2_linhas ON COMMIT DROP AS
SELECT o.transacao_id, o.classe, t.negociacao_id, n.empresa_id, n.cod_duplicata, t.tipo::text AS tipo,
       CASE WHEN t.tipo::text = 'receita' THEN 'receber'::public.fin_natureza ELSE 'pagar'::public.fin_natureza END AS natureza,
       t.cod_itens_duplicata, t.num_parc, t.dt_vencimento, coalesce(t.vl_parcela, 0) AS vl_parcela, coalesce(t.vl_pago, 0) AS vl_pago, coalesce(t.vl_desconto, 0) AS vl_desconto,
       t.status_pago, t.dt_pagamento, t.tipo_pagamento, t.conta_id, t.comprovante_url, t.created_at
FROM (SELECT * FROM _f2_ativas UNION ALL SELECT * FROM _f2_canc) o
JOIN public.transacoes t ON t.id = o.transacao_id
JOIN public.negociacoes n ON n.id = t.negociacao_id;

-- 2) um título por (empresa, número da duplicata, natureza); atributos vêm da negociação preferida (a das ativas, depois a mais recente)
CREATE TEMP TABLE _f2_chave ON COMMIT DROP AS
SELECT DISTINCT ON (l.empresa_id, l.cod_duplicata, l.natureza) l.empresa_id, l.cod_duplicata, l.natureza, l.negociacao_id,
       bool_or(l.classe = 'ativa') OVER (PARTITION BY l.empresa_id, l.cod_duplicata, l.natureza) AS tem_ativa
FROM _f2_linhas l
ORDER BY l.empresa_id, l.cod_duplicata, l.natureza, (l.classe = 'ativa') DESC, l.created_at DESC, l.negociacao_id;

INSERT INTO public.financeiro_titulos (natureza, origem_tipo, especie, empresa_id, perfil, contato_id, funcionario_id, plano_contas_id, projeto_id, documento, descricao,
                                       legado_cod_duplicata, cancelado_em, motivo_cancelamento)
SELECT k.natureza, 'legado_connect',
       CASE WHEN n.dev_troca THEN 'outro'::public.fin_especie WHEN k.natureza = 'receber' THEN 'venda'::public.fin_especie ELSE 'despesa'::public.fin_especie END,
       k.empresa_id,
       (SELECT t.perfil FROM public.transacoes t JOIN _f2_linhas l ON l.transacao_id = t.id WHERE l.empresa_id = k.empresa_id AND l.cod_duplicata = k.cod_duplicata AND l.natureza = k.natureza AND t.perfil IN ('ribeirao', 'sao_paulo') LIMIT 1),
       n.contato_id, CASE WHEN n.contato_id IS NULL THEN n.funcionario_id END, n.plano_contas_id, n.projeto_id, n.num_nota::text, n.observacao,
       k.cod_duplicata,
       CASE WHEN NOT k.tem_ativa THEN now() END,
       CASE WHEN NOT k.tem_ativa THEN 'Todas as parcelas canceladas na Connect (carga de 05/11/2026)' END
FROM _f2_chave k JOIN public.negociacoes n ON n.id = k.negociacao_id;

-- 3) parcelas (numero = num_parc da Connect; se repetir dentro do título, soma 1000 por repetição para não colidir)
INSERT INTO public.financeiro_parcelas (titulo_id, numero, vencimento, valor, situacao, legado_cod_itens_duplicata, observacao)
SELECT ti.id,
       l.num_parc + 1000 * (row_number() OVER (PARTITION BY ti.id, l.num_parc ORDER BY l.cod_itens_duplicata) - 1)::int,
       l.dt_vencimento, l.vl_parcela,
       CASE WHEN l.status_pago = 2 THEN 'cancelada'::public.fin_situacao ELSE 'firme'::public.fin_situacao END,
       l.cod_itens_duplicata,
       'Connect: parcela ' || l.num_parc || ' do código de parcela ' || l.cod_itens_duplicata
FROM _f2_linhas l
JOIN public.financeiro_titulos ti ON ti.empresa_id = l.empresa_id AND ti.legado_cod_duplicata = l.cod_duplicata AND ti.natureza = l.natureza;

-- 4) baixas das parcelas pagas (ativas, status_pago = 1)
CREATE TEMP TABLE _f2_par ON COMMIT DROP AS
SELECT l.*, p.id AS parcela_id, t.projeto_id
FROM _f2_linhas l
JOIN public.financeiro_titulos t ON t.empresa_id = l.empresa_id AND t.legado_cod_duplicata = l.cod_duplicata AND t.natureza = l.natureza
JOIN public.financeiro_parcelas p ON p.titulo_id = t.id AND p.legado_cod_itens_duplicata = l.cod_itens_duplicata;

-- 4a) pago com valor: recebimento/pagamento (limitado ao valor da parcela; excesso = juros)
INSERT INTO public.financeiro_baixas (parcela_id, tipo, data, valor, juros, desconto, forma, conta_bancaria_id, comprovante_url, motivo, origem_baixa)
SELECT f.parcela_id, CASE WHEN f.natureza = 'receber' THEN 'recebimento'::public.fin_baixa_tipo ELSE 'pagamento'::public.fin_baixa_tipo END,
       coalesce(f.dt_pagamento, f.dt_vencimento), least(f.vl_pago, f.vl_parcela), greatest(f.vl_pago - f.vl_parcela, 0), greatest(f.vl_desconto, 0),
       nullif(f.tipo_pagamento, ''), f.conta_id, f.comprovante_url, NULL, 'legado'
FROM _f2_par f WHERE f.classe = 'ativa' AND f.status_pago = 1 AND f.vl_pago > 0;

-- 4b) pago com valor ABAIXO da parcela: a diferença é um abatimento (a parcela fica quitada, com a diferença explicada)
INSERT INTO public.financeiro_baixas (parcela_id, tipo, data, valor, forma, motivo, origem_baixa)
SELECT f.parcela_id, 'abatimento', coalesce(f.dt_pagamento, f.dt_vencimento), f.vl_parcela - f.vl_pago, nullif(f.tipo_pagamento, ''),
       'Diferença entre o valor da parcela e o valor pago na Connect (carga de 05/11/2026)', 'legado'
FROM _f2_par f WHERE f.classe = 'ativa' AND f.status_pago = 1 AND f.vl_pago > 0 AND f.vl_pago < f.vl_parcela;

-- 4c) "pago" com valor ZERO: baixa interna (nenhum dinheiro se moveu; a Connect só marcou como quitada)
INSERT INTO public.financeiro_baixas (parcela_id, tipo, data, valor, forma, motivo, origem_baixa)
SELECT f.parcela_id, 'baixa_interna', coalesce(f.dt_pagamento, f.dt_vencimento), f.vl_parcela, nullif(f.tipo_pagamento, ''),
       'Baixa sem movimento de caixa na Connect (pago com valor zero; forma: ' || coalesce(nullif(f.tipo_pagamento, ''), 'não informada') || '; carga de 05/11/2026)', 'legado'
FROM _f2_par f WHERE f.classe = 'ativa' AND f.status_pago = 1 AND f.vl_pago <= 0;

-- 5) de-para de ids (id antigo -> id novo)
INSERT INTO public.financeiro_legado_ids (tabela_antiga, id_antigo, tabela_nova, id_novo)
SELECT 'transacoes', f.transacao_id, 'financeiro_parcelas', f.parcela_id FROM _f2_par f;
INSERT INTO public.financeiro_legado_ids (tabela_antiga, id_antigo, tabela_nova, id_novo)
SELECT 'negociacoes', k.negociacao_id, 'financeiro_titulos', ti.id
FROM _f2_chave k JOIN public.financeiro_titulos ti ON ti.empresa_id = k.empresa_id AND ti.legado_cod_duplicata = k.cod_duplicata AND ti.natureza = k.natureza;

-- 6) pendências: nada fica solto
INSERT INTO public.financeiro_pendencias (titulo_id, tipo, descricao, responsavel)
SELECT t.id, 'titulo_sem_plano_de_contas', 'Duplicata da Connect sem conta do plano de contas: informar para entrar nos relatórios por conta.', 'Financeiro'
FROM public.financeiro_titulos t WHERE t.origem_tipo = 'legado_connect' AND t.plano_contas_id IS NULL;

INSERT INTO public.financeiro_pendencias (baixa_id, tipo, descricao, responsavel)
SELECT b.id, 'baixa_sem_conta_bancaria', 'Pagamento/recebimento da Connect sem conta bancária: informar a conta (saldo bancário depende disso).', 'Financeiro'
FROM public.financeiro_baixas b WHERE b.movimenta_caixa AND b.conta_bancaria_id IS NULL;

INSERT INTO public.financeiro_pendencias (parcela_id, tipo, descricao, responsavel)
SELECT f.parcela_id, 'baixa_sem_data_pagamento', 'Parcela paga na Connect sem data de pagamento: usada a data de vencimento; informar a data real.', 'Financeiro'
FROM _f2_par f WHERE f.classe = 'ativa' AND f.status_pago = 1 AND f.dt_pagamento IS NULL;

INSERT INTO public.financeiro_pendencias (baixa_id, parcela_id, tipo, descricao, responsavel)
SELECT b.id, b.parcela_id, 'pago_menor_que_parcela', 'Parcela quitada na Connect com valor pago menor que o da parcela: confirmar se foi desconto/acordo.', 'Financeiro'
FROM public.financeiro_baixas b WHERE b.tipo = 'abatimento' AND b.origem_baixa = 'legado';

ANALYZE public.financeiro_titulos; ANALYZE public.financeiro_parcelas; ANALYZE public.financeiro_baixas;
