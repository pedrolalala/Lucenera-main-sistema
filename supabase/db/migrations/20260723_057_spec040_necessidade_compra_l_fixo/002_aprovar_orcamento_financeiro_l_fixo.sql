-- Migration 20260723_057 - SPEC-040 - Item 2/4
--
-- ATENCAO CRITICA: esta migration recria public.aprovar_orcamento_financeiro,
-- que e a RPC transacional central do dominio Orcamentos/Financeiro
-- (SPEC-016), NAO do dominio Compras. Qualquer sistema que dependa do
-- comportamento de aprovacao financeira de orcamento (projeto_itens,
-- projeto_parcelas, boletos) e afetado por esta migration, mesmo que o
-- motivo da mudanca seja uma necessidade do sistema de Compras
-- (compras-lucenera-3o23t98ee).
--
-- ACHADO CRITICO (orquestrador, 21/07/2026, antes de aplicar): a versao
-- rascunhada originalmente pelo implementador desta migration foi baseada em
-- supabase/db/migrations/20260706_020_normalizacao_aprovacao_financeira_orcamento/
-- e em supabase/db/current/03_functions.sql -- mas nenhuma das duas fontes
-- bate com a funcao REAL rodando em producao. Confirmado via
-- `SELECT pg_get_functiondef('public.aprovar_orcamento_financeiro(uuid)'::regprocedure)`
-- direto no Supabase real: a funcao ao vivo NAO TEM a checagem de permissao
-- (admin/gerente), NAO TEM a validacao de frete_tipo, e NAO TEM o passo de
-- reserva automatica em estoque_itens que a migration 20260706_020 e o
-- db/current descrevem -- ou seja, a migration 20260706_020 nunca foi
-- aplicada neste banco real (mesmo padrao de bug ja encontrado com a tabela
-- pedidos_compra na SPEC-038: arquivo de migration redigido, nunca
-- executado, e db/current documentando um estado que so existe no papel).
-- Em contrapartida, a funcao ao vivo TEM colunas/logica (subtotal calculado,
-- fallback de descricao para oi.custom_id) que NAO aparecem em nenhuma
-- migration deste repositorio -- sinal de um hotfix aplicado direto no
-- banco real, nunca capturado em arquivo. Isso e uma pendencia separada,
-- fora do escopo desta SPEC (ver supabase/db/domains, achado a documentar).
--
-- Por isso, o corpo abaixo NAO copia a migration 20260706_020 nem o
-- db/current -- copia o retorno real de pg_get_functiondef obtido em
-- 21/07/2026, com a UNICA mudanca sendo o INSERT INTO public.projeto_itens
-- ganhando duas colunas novas (orcamento_item_id, l_fixo), gravando
-- oi.id/oi.custom_id que ja estao disponiveis no mesmo SELECT. Nenhuma
-- checagem de permissao, validacao de frete ou reserva de estoque e
-- adicionada ou removida por esta migration -- o comportamento ao vivo de
-- hoje e preservado integralmente, so acrescido do necessario para a
-- SPEC-040.
--
-- A assinatura de parametros nao muda (aprovar_orcamento_financeiro(uuid)),
-- entao CREATE OR REPLACE FUNCTION e suficiente, sem DROP FUNCTION.
--
-- Pre-requisito: 001_projeto_itens_orcamento_item_id.sql (colunas
-- orcamento_item_id/l_fixo em projeto_itens) ja aplicada.
--
-- Passo manual do usuario, mesmo assim, antes de aplicar em producao: rodar
-- `SELECT pg_get_functiondef('public.aprovar_orcamento_financeiro(uuid)'::regprocedure);`
-- de novo no momento de aplicar, e conferir que ainda bate com o corpo
-- abaixo (o achado acima mostra que este dominio tem historico de drift
-- entre codigo/arquivo e banco real).

CREATE OR REPLACE FUNCTION public.aprovar_orcamento_financeiro(p_orcamento_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_orcamento public.orcamentos%ROWTYPE;
  v_cliente_nome text;
  v_status_anterior text;
  v_prazos integer[];
  v_qtd_parcelas integer;
  v_i integer;
  v_valor_total numeric;
  v_valor_base numeric;
  v_valor_parcela numeric;
  v_valor_acumulado numeric := 0;
  v_data_base date := current_date;
  v_itens_existentes integer := 0;
  v_parcelas_existentes integer := 0;
  v_boletos_existentes integer := 0;
  v_itens_criados integer := 0;
  v_parcelas_criadas integer := 0;
  v_boletos_criados integer := 0;
  v_numero_orcamento text;
BEGIN
  SELECT * INTO v_orcamento FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento % não encontrado.', p_orcamento_id USING ERRCODE = 'P0001';
  END IF;

  v_status_anterior := v_orcamento.status;
  v_numero_orcamento := coalesce(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.projeto_id IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui projeto vinculado.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;
  IF v_orcamento.empresa_id IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui empresa vinculada.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;
  IF v_orcamento.cliente_id IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui cliente vinculado.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;
  IF coalesce(v_orcamento.valor_total, 0) <= 0 THEN
    RAISE EXCEPTION 'Orçamento % possui valor total inválido.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;
  IF v_orcamento.forma_pagamento IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui forma de pagamento estruturada.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.orcamento_itens oi WHERE oi.orcamento_id = p_orcamento_id) THEN
    RAISE EXCEPTION 'Orçamento % não possui itens.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.orcamento_itens oi
    WHERE oi.orcamento_id = p_orcamento_id AND (coalesce(oi.quantidade, 0) <= 0 OR coalesce(oi.preco_unitario, 0) <= 0)
  ) THEN
    RAISE EXCEPTION 'Orçamento % possui item sem quantidade ou preço válido.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;

  v_prazos := public._lucenera_parse_prazo_pagamento(v_orcamento.condicoes_pagamento, v_orcamento.prazo_pagamento_dias);
  v_qtd_parcelas := coalesce(array_length(v_prazos, 1), 0);
  IF v_qtd_parcelas = 0 THEN
    RAISE EXCEPTION 'Orçamento % não possui prazo de pagamento interpretável.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;

  SELECT nome INTO v_cliente_nome FROM public.contatos WHERE id = v_orcamento.cliente_id;

  SELECT count(*) INTO v_itens_existentes FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id;
  SELECT count(*) INTO v_parcelas_existentes FROM public.projeto_parcelas WHERE orcamento_id = p_orcamento_id;
  SELECT count(*) INTO v_boletos_existentes FROM public.boletos WHERE orcamento_id = p_orcamento_id;

  IF v_itens_existentes > 0 AND v_parcelas_existentes = v_qtd_parcelas AND v_boletos_existentes = v_qtd_parcelas THEN
    UPDATE public.orcamentos SET status = 'Orçamento Aprovado' WHERE id = p_orcamento_id;
    RETURN jsonb_build_object(
      'orcamento_id', p_orcamento_id, 'status', 'Orçamento Aprovado', 'projeto_id', v_orcamento.projeto_id,
      'projeto_itens_criados', 0, 'parcelas_criadas', 0, 'boletos_criados', 0,
      'nota_fiscal_status', 'pendente_api', 'ja_processado', true
    );
  END IF;

  IF v_itens_existentes > 0 OR v_parcelas_existentes > 0 OR v_boletos_existentes > 0 THEN
    RAISE EXCEPTION 'Orçamento % possui processamento parcial inconsistente: itens %, parcelas %, boletos %.',
      v_numero_orcamento, v_itens_existentes, v_parcelas_existentes, v_boletos_existentes USING ERRCODE = 'P0001';
  END IF;

  IF v_orcamento.status != 'Aprovação Financeira' THEN
    RAISE EXCEPTION 'Orçamento % não está aguardando aprovação financeira. Status atual: %', v_numero_orcamento, v_status_anterior
      USING ERRCODE = 'P0003';
  END IF;

  UPDATE public.orcamentos SET status = 'Orçamento Aprovado', requer_revisao_financeira = false WHERE id = p_orcamento_id;

  BEGIN
    INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
    VALUES (p_orcamento_id, v_status_anterior, 'Orçamento Aprovado', auth.uid()::text, 'Aprovação financeira — processamento de itens, parcelas e boletos');
  EXCEPTION
    WHEN undefined_table OR undefined_column OR foreign_key_violation THEN
      NULL;
  END;

  INSERT INTO public.projeto_itens (
    projeto_id, produto_id, descricao, quantidade, preco_unitario, desconto, subtotal, validado, orcamento_id,
    orcamento_item_id, l_fixo
  )
  SELECT v_orcamento.projeto_id, oi.produto_id, coalesce(oi.descricao, oi.custom_id, p.nome, 'Item do Orçamento'),
    coalesce(oi.quantidade, 0), coalesce(oi.preco_unitario, 0), coalesce(oi.desconto, 0),
    round(coalesce(oi.quantidade, 0) * coalesce(oi.preco_unitario, 0) * (1 - coalesce(oi.desconto, 0) / 100), 2),
    true, p_orcamento_id,
    oi.id, oi.custom_id
  FROM public.orcamento_itens oi LEFT JOIN public.produtos p ON p.id = oi.produto_id
  WHERE oi.orcamento_id = p_orcamento_id;
  GET DIAGNOSTICS v_itens_criados = ROW_COUNT;

  v_valor_total := coalesce(v_orcamento.valor_total, 0);
  v_valor_base := round(v_valor_total / v_qtd_parcelas, 2);

  FOR v_i IN 1..v_qtd_parcelas LOOP
    IF v_i = v_qtd_parcelas THEN
      v_valor_parcela := v_valor_total - v_valor_acumulado;
    ELSE
      v_valor_parcela := v_valor_base;
      v_valor_acumulado := v_valor_acumulado + v_valor_parcela;
    END IF;
    INSERT INTO public.projeto_parcelas (projeto_id, numero_parcela, valor, data_fechamento, data_vencimento, status, forma_pagamento, orcamento_id, descricao)
    VALUES (v_orcamento.projeto_id, v_i, v_valor_parcela, current_date, v_data_base + v_prazos[v_i], 'pendente', v_orcamento.forma_pagamento, p_orcamento_id, 'Parcela gerada pelo orçamento ' || v_numero_orcamento);
    v_parcelas_criadas := v_parcelas_criadas + 1;
  END LOOP;

  INSERT INTO public.boletos (nosso_numero, numero_documento, parcela_id, orcamento_id, empresa_id, valor, vencimento, nome_pagador, status, tipo, venda, num_parcela, total_parcelas, emissao)
  SELECT 'ORC-' || regexp_replace(v_numero_orcamento, '[^a-zA-Z0-9]', '', 'g') || '-P' || pp.numero_parcela,
    v_numero_orcamento || '-P' || pp.numero_parcela, pp.id, p_orcamento_id, v_orcamento.empresa_id,
    pp.valor, pp.data_vencimento, coalesce(v_cliente_nome, 'Cliente do orçamento'), 'pendente_registro', 'Nota Fiscal', NULL,
    pp.numero_parcela, v_qtd_parcelas, current_date
  FROM public.projeto_parcelas pp WHERE pp.orcamento_id = p_orcamento_id
  ON CONFLICT (nosso_numero) DO NOTHING;
  GET DIAGNOSTICS v_boletos_criados = ROW_COUNT;

  RETURN jsonb_build_object(
    'orcamento_id', p_orcamento_id, 'status', 'Orçamento Aprovado', 'projeto_id', v_orcamento.projeto_id,
    'projeto_itens_criados', v_itens_criados, 'parcelas_criadas', v_parcelas_criadas, 'boletos_criados', v_boletos_criados,
    'nota_fiscal_status', 'pendente_api', 'ja_processado', false
  );
END;
$function$;

COMMENT ON FUNCTION public.aprovar_orcamento_financeiro(uuid) IS
'SPEC-016: aprovacao financeira transacional por orcamento_id. Aceita apenas
status Aprovação Financeira e finaliza em Orçamento Aprovado. SPEC-040:
INSERT INTO projeto_itens passou a gravar orcamento_item_id (FK) e l_fixo
(snapshot de orcamento_itens.custom_id), habilitando a granularidade por
item de orcamento no Fluxo B da tela Necessidade de Compra
(compras-lucenera-3o23t98ee). Corpo baseado na definicao real confirmada via
pg_get_functiondef em 21/07/2026, nao na migration 20260706_020 (que nunca
foi aplicada neste banco -- ver nota no topo deste arquivo), preservando
integralmente o comportamento ao vivo (sem checagem de role, sem validacao
de frete_tipo, sem reserva automatica em estoque_itens).';
