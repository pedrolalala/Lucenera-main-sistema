-- SPEC-195 A (11/10/2026) — Orçamento de VÍNCULO de venda já aprovada na Connect.
-- Liga peças e valor ao projeto (projeto_itens) SEM reserva de estoque, SEM parcela/boleto e SEM nota.
-- Decisões do usuário (11/10): número da venda = número da Connect (VENDA-<cod>), a sequência própria
-- continua depois dele (aprovar_orcamento_financeiro já usa MAX+1); sem status próprio —
-- 'Orçamento Aprovado' + orcamentos.vinculo_connect = true. Nasce do import de XML (SPEC-050).
-- Consumidores de estoque/compra (vw_necessidade_compra*, entrega futura, re-reserva, estoque_resumo,
-- Separação) passam por estoque_saldos_projeto_item; o vínculo não cria saldo, então ficam de fora sozinhos.

ALTER TABLE public.orcamentos
  ADD COLUMN IF NOT EXISTS vinculo_connect boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.orcamentos.vinculo_connect IS
  'SPEC-195: venda aprovada na Connect só vinculada aqui (projeto_itens sem reserva, sem financeiro, sem nota).';

-- número da venda não pode repetir (o vínculo usa o número da Connect).
CREATE UNIQUE INDEX IF NOT EXISTS orcamentos_numero_venda_uidx
  ON public.orcamentos (numero_venda) WHERE numero_venda IS NOT NULL;

CREATE OR REPLACE FUNCTION public.vincular_orcamento_connect(p_orcamento_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_o public.orcamentos%ROWTYPE;
  v_numero text;
  v_numero_venda text;
  v_itens integer := 0;
BEGIN
  IF COALESCE(auth.role(), '') <> 'service_role'
     AND NOT public.hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'aprovar') THEN
    RAISE EXCEPTION 'Permissão negada para vincular venda da Connect.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_o FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento % não encontrado.', p_orcamento_id USING ERRCODE = 'P0001';
  END IF;
  v_numero := coalesce(v_o.numero, left(p_orcamento_id::text, 8));

  -- idempotente: já vinculado
  IF v_o.vinculo_connect AND v_o.status = 'Orçamento Aprovado' THEN
    RETURN jsonb_build_object('orcamento_id', p_orcamento_id, 'numero_venda', v_o.numero_venda,
      'projeto_itens_criados', 0, 'ja_vinculado', true);
  END IF;

  IF v_o.origem_connect_cod_orcamento IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não veio da Connect (importe pelo XML da Connect).', v_numero USING ERRCODE = 'P0001';
  END IF;
  IF v_o.natureza_operacao IS DISTINCT FROM 'venda' THEN
    RAISE EXCEPTION 'Orçamento % não é de venda.', v_numero USING ERRCODE = 'P0001';
  END IF;
  IF v_o.status IN ('Orçamento Aprovado', 'Aprovação Financeira', 'cancelado') THEN
    RAISE EXCEPTION 'Orçamento % está em "%" — não pode ser vinculado.', v_numero, v_o.status USING ERRCODE = 'P0001';
  END IF;
  IF v_o.projeto_id IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui projeto vinculado.', v_numero USING ERRCODE = 'P0001';
  END IF;
  IF v_o.empresa_id IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui empresa vinculada.', v_numero USING ERRCODE = 'P0001';
  END IF;
  IF v_o.cliente_id IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui cliente vinculado.', v_numero USING ERRCODE = 'P0001';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.orcamento_itens WHERE orcamento_id = p_orcamento_id) THEN
    RAISE EXCEPTION 'Orçamento % não possui itens.', v_numero USING ERRCODE = 'P0001';
  END IF;
  IF EXISTS (SELECT 1 FROM public.orcamento_itens WHERE orcamento_id = p_orcamento_id AND produto_id IS NULL) THEN
    RAISE EXCEPTION 'Orçamento % possui item sem produto cadastrado — cadastre/vincule a peça antes.', v_numero USING ERRCODE = 'P0001';
  END IF;
  IF EXISTS (SELECT 1 FROM public.orcamento_itens WHERE orcamento_id = p_orcamento_id
             AND (coalesce(quantidade, 0) <= 0 OR preco_unitario IS NULL OR preco_unitario < 0)) THEN
    RAISE EXCEPTION 'Orçamento % possui item sem quantidade ou preço válido.', v_numero USING ERRCODE = 'P0001';
  END IF;
  IF EXISTS (SELECT 1 FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id) THEN
    RAISE EXCEPTION 'Orçamento % já tem itens no projeto — processamento inconsistente.', v_numero USING ERRCODE = 'P0001';
  END IF;

  v_numero_venda := 'VENDA-' || lpad(v_o.origem_connect_cod_orcamento::text, 4, '0');
  IF EXISTS (SELECT 1 FROM public.orcamentos WHERE numero_venda = v_numero_venda AND id <> p_orcamento_id) THEN
    RAISE EXCEPTION 'O número de venda % já existe no sistema — confira o número da Connect.', v_numero_venda USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.orcamentos
  SET status = 'Orçamento Aprovado', vinculo_connect = true, numero_venda = v_numero_venda,
      requer_revisao_financeira = false
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (p_orcamento_id, v_o.status, 'Orçamento Aprovado', auth.uid()::text,
    format('Vínculo de venda aprovada na Connect nº %s — sem reserva de estoque, sem financeiro e sem nota (SPEC-195)',
           v_o.origem_connect_cod_orcamento));

  INSERT INTO public.projeto_itens (
    projeto_id, produto_id, descricao, quantidade, preco_unitario, desconto, validado, orcamento_id,
    orcamento_item_id, l_fixo
  )
  SELECT v_o.projeto_id, oi.produto_id, coalesce(oi.descricao, p.nome, oi.custom_id, 'Item do Orçamento'),
    oi.quantidade, oi.preco_unitario, coalesce(oi.desconto, 0), true, p_orcamento_id, oi.id, oi.custom_id
  FROM public.orcamento_itens oi LEFT JOIN public.produtos p ON p.id = oi.produto_id
  WHERE oi.orcamento_id = p_orcamento_id;
  GET DIAGNOSTICS v_itens = ROW_COUNT;

  RETURN jsonb_build_object('orcamento_id', p_orcamento_id, 'numero_venda', v_numero_venda,
    'projeto_itens_criados', v_itens, 'ja_vinculado', false);
END;
$$;

CREATE OR REPLACE FUNCTION public.desvincular_orcamento_connect(p_orcamento_id uuid, p_motivo text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_o public.orcamentos%ROWTYPE;
  v_numero text;
  v_itens integer := 0;
BEGIN
  IF p_motivo IS NULL OR btrim(p_motivo) = '' THEN
    RAISE EXCEPTION 'Informe o motivo para desfazer o vínculo.' USING ERRCODE = 'P0001';
  END IF;
  IF COALESCE(auth.role(), '') <> 'service_role'
     AND NOT public.hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'aprovar') THEN
    RAISE EXCEPTION 'Permissão negada para desfazer vínculo.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_o FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento % não encontrado.', p_orcamento_id USING ERRCODE = 'P0001';
  END IF;
  v_numero := coalesce(v_o.numero, left(p_orcamento_id::text, 8));
  IF NOT v_o.vinculo_connect THEN
    RAISE EXCEPTION 'Orçamento % não é vínculo da Connect.', v_numero USING ERRCODE = 'P0001';
  END IF;

  -- nada pode ter sido feito em cima dos itens (no vínculo não deveria haver nada disso)
  IF EXISTS (SELECT 1 FROM public.projeto_itens pi
             WHERE pi.orcamento_id = p_orcamento_id
               AND (EXISTS (SELECT 1 FROM public.estoque_saldos_projeto_item s WHERE s.projeto_item_id = pi.id)
                    OR EXISTS (SELECT 1 FROM public.estoque_movimentos_projeto_item m WHERE m.projeto_item_id = pi.id)
                    OR EXISTS (SELECT 1 FROM public.orcamento_itens d WHERE d.projeto_item_origem_id = pi.id))) THEN
    RAISE EXCEPTION 'Orçamento % já tem movimento sobre os itens do vínculo — não pode desfazer.', v_numero USING ERRCODE = 'P0001';
  END IF;
  IF EXISTS (SELECT 1 FROM public.projeto_parcelas WHERE orcamento_id = p_orcamento_id)
     OR EXISTS (SELECT 1 FROM public.boletos WHERE orcamento_id = p_orcamento_id) THEN
    RAISE EXCEPTION 'Orçamento % tem financeiro lançado — não pode desfazer o vínculo.', v_numero USING ERRCODE = 'P0001';
  END IF;

  DELETE FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id;
  GET DIAGNOSTICS v_itens = ROW_COUNT;

  UPDATE public.orcamentos
  SET status = 'rascunho', vinculo_connect = false, numero_venda = NULL
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (p_orcamento_id, v_o.status, 'rascunho', auth.uid()::text, 'Vínculo Connect desfeito: ' || p_motivo);

  RETURN jsonb_build_object('orcamento_id', p_orcamento_id, 'projeto_itens_apagados', v_itens);
END;
$$;

REVOKE ALL ON FUNCTION public.vincular_orcamento_connect(uuid) FROM public, anon;
REVOKE ALL ON FUNCTION public.desvincular_orcamento_connect(uuid, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.vincular_orcamento_connect(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.desvincular_orcamento_connect(uuid, text) TO authenticated, service_role;

-- Proteção: orçamento vinculado não muda itens/valores (o ciclo de aprovação reiniciaria e
-- deixaria projeto_itens órfãos) e item de vínculo não serve de origem de devolução
-- (a devolução dessas vendas é feita na Connect).
CREATE OR REPLACE FUNCTION public.proteger_orcamento_vinculo_connect()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_orc uuid;
BEGIN
  IF TG_TABLE_NAME = 'orcamentos' THEN
    IF OLD.vinculo_connect AND OLD.status = 'Orçamento Aprovado' AND NEW.vinculo_connect AND NEW.status = OLD.status
       AND (NEW.valor_total IS DISTINCT FROM OLD.valor_total
            OR NEW.projeto_id IS DISTINCT FROM OLD.projeto_id
            OR NEW.cliente_id IS DISTINCT FROM OLD.cliente_id
            OR NEW.empresa_id IS DISTINCT FROM OLD.empresa_id
            OR NEW.desconto_global IS DISTINCT FROM OLD.desconto_global
            OR NEW.frete_valor IS DISTINCT FROM OLD.frete_valor
            OR NEW.numero_venda IS DISTINCT FROM OLD.numero_venda) THEN
      RAISE EXCEPTION 'Orçamento % é vínculo de venda da Connect — desfaça o vínculo antes de alterar.', coalesce(OLD.numero, OLD.id::text)
        USING ERRCODE = 'P0001';
    END IF;
    RETURN NEW;
  END IF;

  -- orcamento_itens
  v_orc := COALESCE(NEW.orcamento_id, OLD.orcamento_id);
  IF EXISTS (SELECT 1 FROM public.orcamentos o WHERE o.id = v_orc AND o.vinculo_connect AND o.status = 'Orçamento Aprovado') THEN
    RAISE EXCEPTION 'Orçamento é vínculo de venda da Connect — desfaça o vínculo antes de alterar os itens.'
      USING ERRCODE = 'P0001';
  END IF;
  IF TG_OP <> 'DELETE' AND NEW.projeto_item_origem_id IS NOT NULL AND EXISTS (
       SELECT 1 FROM public.projeto_itens pi JOIN public.orcamentos o ON o.id = pi.orcamento_id
       WHERE pi.id = NEW.projeto_item_origem_id AND o.vinculo_connect) THEN
    RAISE EXCEPTION 'Peça de venda vinculada da Connect — a devolução dessa venda é feita na Connect.'
      USING ERRCODE = 'P0001';
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

-- nome com "0" para rodar ANTES de trg_orcamento_workflow (BEFORE triggers rodam em ordem alfabética)
DROP TRIGGER IF EXISTS trg_0_proteger_vinculo_connect ON public.orcamentos;
CREATE TRIGGER trg_0_proteger_vinculo_connect BEFORE UPDATE ON public.orcamentos
  FOR EACH ROW EXECUTE FUNCTION public.proteger_orcamento_vinculo_connect();

DROP TRIGGER IF EXISTS trg_0_proteger_vinculo_connect ON public.orcamento_itens;
CREATE TRIGGER trg_0_proteger_vinculo_connect BEFORE INSERT OR UPDATE OR DELETE ON public.orcamento_itens
  FOR EACH ROW EXECUTE FUNCTION public.proteger_orcamento_vinculo_connect();

-- Correção junto (achada no teste): o recálculo de projetos.valor_total usava só NEW, então
-- em DELETE (desfazer vínculo / desfazer aprovação) o valor do projeto ficava velho.
CREATE OR REPLACE FUNCTION public.sync_projeto_valor_total()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  UPDATE projetos
  SET valor_total = (SELECT COALESCE(SUM(subtotal), 0) FROM projeto_itens WHERE projeto_id = projetos.id)
  WHERE id IN (NEW.projeto_id, OLD.projeto_id);
  RETURN COALESCE(NEW, OLD);
END;
$$;

-- Guards nas funções existentes (definições vivas de 11/10 + um IF logo depois do "não encontrado").
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
  v_numero_venda text;
  v_seq_venda integer;
  v_item record;
  v_estoque_fisico numeric(10,2);
  v_estoque_reservado_atual numeric(10,2);
  v_disponivel_fisico numeric(10,3);
  v_q_reserva numeric(10,3);
  v_q_entrega_futura numeric(10,3);
  v_reservas_criadas integer := 0;
  v_saldos_criados integer := 0;
  v_devolucoes_processadas integer := 0;
  v_plano jsonb;
  v_usar_plano boolean := false;
  v_elem jsonb;
  v_valores numeric[];
  v_dias_offsets integer[];
  v_formas text[];
  v_permuta_ids uuid[];
  v_soma_plano numeric;
  v_qtd_boletos_esperados integer;
  v_plano_contas_permuta_id uuid;
  v_permuta_criados integer := 0;
BEGIN
  IF COALESCE(auth.role(), '') <> 'service_role'
     AND NOT public.hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'aprovar') THEN
    RAISE EXCEPTION 'Permissão negada para aprovar orçamento financeiramente.'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_orcamento FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento % não encontrado.', p_orcamento_id USING ERRCODE = 'P0001';
  END IF;

  -- SPEC-195: vínculo de venda da Connect não passa pela aprovação financeira (não gera
  -- reserva, parcela nem boleto). Para aprovar de verdade, desfaça o vínculo antes.
  IF v_orcamento.vinculo_connect THEN
    RAISE EXCEPTION 'Orçamento % é vínculo de venda da Connect — não pode ser aprovado financeiramente. Desfaça o vínculo antes.', coalesce(v_orcamento.numero, p_orcamento_id::text)
      USING ERRCODE = 'P0001';
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

  -- =====================================================================
  -- SPEC-152: monta v_qtd_parcelas + arrays (valor/dias_offset/forma de
  -- pagamento/fornecedor de permuta) por parcela -- de plano_parcelas
  -- quando presente, senão do jeito legado (parse de prazo + divisão
  -- igual + forma de pagamento única do orçamento).
  -- =====================================================================
  v_plano := v_orcamento.plano_parcelas;
  v_valor_total := coalesce(v_orcamento.valor_total, 0);

  IF v_plano IS NOT NULL AND jsonb_typeof(v_plano) = 'array' AND jsonb_array_length(v_plano) > 0 THEN
    v_usar_plano := true;
    v_qtd_parcelas := jsonb_array_length(v_plano);
    v_valores := ARRAY[]::numeric[];
    v_dias_offsets := ARRAY[]::integer[];
    v_formas := ARRAY[]::text[];
    v_permuta_ids := ARRAY[]::uuid[];

    FOR v_i IN 0..v_qtd_parcelas - 1 LOOP
      v_elem := v_plano -> v_i;
      v_valores := v_valores || round(coalesce((v_elem->>'valor')::numeric, 0), 2);
      v_dias_offsets := v_dias_offsets || coalesce((v_elem->>'dias_offset')::integer, 0);
      v_formas := v_formas || coalesce(nullif(v_elem->>'forma_pagamento', ''), v_orcamento.forma_pagamento::text);
      v_permuta_ids := v_permuta_ids || nullif(v_elem->>'permuta_fornecedor_id', '')::uuid;
    END LOOP;

    -- Regra dura (decisão do usuário, 2026-09-17): soma das parcelas deve
    -- ser EXATAMENTE igual ao valor a pagar -- nunca arredonda
    -- silenciosamente. O frontend já valida isso antes de salvar o
    -- orçamento (BudgetFormPage.tsx); esta é a validação de segurança no
    -- backend, fonte de verdade final.
    SELECT coalesce(sum(v), 0) INTO v_soma_plano FROM unnest(v_valores) AS v;
    IF abs(v_soma_plano - v_valor_total) > 0.01 THEN
      RAISE EXCEPTION 'Soma do plano de parcelas (%) não bate com o valor total do orçamento (%).',
        v_soma_plano, v_valor_total USING ERRCODE = 'P0001';
    END IF;
  ELSE
    v_prazos := public._lucenera_parse_prazo_pagamento(v_orcamento.condicoes_pagamento, v_orcamento.prazo_pagamento_dias);
    v_qtd_parcelas := coalesce(array_length(v_prazos, 1), 0);
    IF v_qtd_parcelas = 0 THEN
      RAISE EXCEPTION 'Orçamento % não possui prazo de pagamento interpretável.', v_numero_orcamento USING ERRCODE = 'P0001';
    END IF;

    v_dias_offsets := v_prazos;
    v_formas := ARRAY(SELECT v_orcamento.forma_pagamento::text FROM generate_series(1, v_qtd_parcelas));
    v_permuta_ids := ARRAY(SELECT NULL::uuid FROM generate_series(1, v_qtd_parcelas));

    v_valor_base := round(v_valor_total / v_qtd_parcelas, 2);
    v_valores := ARRAY[]::numeric[];
    v_valor_acumulado := 0;
    FOR v_i IN 1..v_qtd_parcelas LOOP
      IF v_i = v_qtd_parcelas THEN
        v_valores := v_valores || round(v_valor_total - v_valor_acumulado, 2);
      ELSE
        v_valores := v_valores || v_valor_base;
        v_valor_acumulado := v_valor_acumulado + v_valor_base;
      END IF;
    END LOOP;
  END IF;

  -- SPEC-156: parcela de permuta exige contato real, fornecedor OU cliente
  -- (antes só aceitava tipo='fornecedor' -- às vezes a contraparte da
  -- permuta é o próprio cliente oferecendo produto/serviço em troca).
  FOR v_i IN 1..v_qtd_parcelas LOOP
    IF v_formas[v_i] = 'permuta' THEN
      IF v_permuta_ids[v_i] IS NULL THEN
        RAISE EXCEPTION 'Parcela % está marcada como permuta mas não tem fornecedor/cliente definido.', v_i
          USING ERRCODE = 'P0001';
      END IF;
      IF NOT EXISTS (SELECT 1 FROM public.contatos WHERE id = v_permuta_ids[v_i] AND tipo IN ('fornecedor', 'cliente')) THEN
        RAISE EXCEPTION 'Parcela % de permuta precisa de um fornecedor ou cliente válido (contatos.tipo IN (fornecedor, cliente)).', v_i
          USING ERRCODE = 'P0001';
      END IF;
    END IF;
  END LOOP;

  -- Quantidade de boletos esperada quando o processamento já rodou antes
  -- (idempotência) -- carteira/permuta não geram boleto, então já não é
  -- igual a v_qtd_parcelas como no comportamento legado.
  SELECT count(*) INTO v_qtd_boletos_esperados FROM unnest(v_formas) AS f WHERE f NOT IN ('carteira', 'permuta');

  SELECT nome INTO v_cliente_nome FROM public.contatos WHERE id = v_orcamento.cliente_id;

  -- =====================================================================
  -- SPEC-071: ramo de DEVOLUÇÃO — não cria projeto_itens/reserva de estoque
  -- positiva; devolve estoque via registrar_devolucao_projeto_item (SPEC-015)
  -- e lança crédito financeiro negativo em vez de cobrança.
  -- SPEC-136: devolução não gera numero_venda — é crédito sobre uma venda já
  -- existente, não uma venda nova.
  -- =====================================================================
  IF v_orcamento.natureza_operacao = 'devolucao' THEN
    IF EXISTS (
      SELECT 1 FROM public.orcamento_itens oi
      WHERE oi.orcamento_id = p_orcamento_id AND oi.projeto_item_origem_id IS NULL
    ) THEN
      RAISE EXCEPTION 'Orçamento de devolução % possui item sem venda de origem vinculada.', v_numero_orcamento
        USING ERRCODE = 'P0001';
    END IF;

    -- SPEC-182 (05/10): a devolução se liga ao CÓDIGO DO PROJETO (substitui a
    -- venda única da SPEC-181): cada item precisa vir de uma venda efetivada
    -- do mesmo projeto e da mesma empresa da devolução; pode misturar vendas.
    IF EXISTS (
      SELECT 1 FROM public.orcamento_itens oi
      JOIN public.projeto_itens pi ON pi.id = oi.projeto_item_origem_id
      LEFT JOIN public.orcamentos vo ON vo.id = pi.orcamento_id
      WHERE oi.orcamento_id = p_orcamento_id
        AND (vo.id IS NULL
             OR vo.numero_venda IS NULL
             OR vo.projeto_id IS DISTINCT FROM v_orcamento.projeto_id
             OR pi.projeto_id IS DISTINCT FROM v_orcamento.projeto_id
             OR vo.empresa_id IS DISTINCT FROM v_orcamento.empresa_id)
    ) THEN
      RAISE EXCEPTION 'Orçamento de devolução % possui item que não é de uma venda efetivada deste projeto e desta empresa.', v_numero_orcamento
        USING ERRCODE = 'P0001';
    END IF;
    -- SPEC-182 (D6): peça em separação não se devolve — cancelar a separação antes.
    IF EXISTS (
      SELECT 1 FROM public.orcamento_itens oi
      WHERE oi.orcamento_id = p_orcamento_id AND oi.setor_origem = 'em_separacao'
    ) THEN
      RAISE EXCEPTION 'Orçamento de devolução % tem peça em separação. Cancele a separação antes de devolver.', v_numero_orcamento
        USING ERRCODE = 'P0001';
    END IF;

    SELECT count(*) INTO v_parcelas_existentes FROM public.projeto_parcelas WHERE orcamento_id = p_orcamento_id;
    SELECT count(*) INTO v_boletos_existentes FROM public.boletos WHERE orcamento_id = p_orcamento_id AND tipo_operacao IS DISTINCT FROM 'CP';

    IF v_parcelas_existentes = v_qtd_parcelas AND v_boletos_existentes = v_qtd_boletos_esperados THEN
      UPDATE public.orcamentos SET status = 'Orçamento Aprovado' WHERE id = p_orcamento_id;
      RETURN jsonb_build_object(
        'orcamento_id', p_orcamento_id, 'status', 'Orçamento Aprovado', 'natureza_operacao', 'devolucao',
        'projeto_id', v_orcamento.projeto_id,
        'devolucoes_processadas', 0, 'parcelas_criadas', 0, 'boletos_criados', 0, 'ja_processado', true
      );
    END IF;

    IF v_parcelas_existentes > 0 OR v_boletos_existentes > 0 THEN
      RAISE EXCEPTION 'Orçamento de devolução % possui processamento parcial inconsistente: parcelas %, boletos %.',
        v_numero_orcamento, v_parcelas_existentes, v_boletos_existentes USING ERRCODE = 'P0001';
    END IF;

    IF v_orcamento.status != 'Aprovação Financeira' THEN
      RAISE EXCEPTION 'Orçamento % não está aguardando aprovação financeira. Status atual: %', v_numero_orcamento, v_status_anterior
        USING ERRCODE = 'P0003';
    END IF;

    UPDATE public.orcamentos SET status = 'Orçamento Aprovado', requer_revisao_financeira = false WHERE id = p_orcamento_id;

    BEGIN
      INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
      VALUES (p_orcamento_id, v_status_anterior, 'Orçamento Aprovado', auth.uid()::text, 'Aprovação financeira de devolução — estoque devolvido e crédito lançado');
    EXCEPTION
      WHEN undefined_table OR undefined_column OR foreign_key_violation THEN
        NULL;
    END;

    -- SPEC-178: linha com setor_origem devolve exatamente daquele setor
    -- (uma linha por setor); linha antiga sem setor segue a cascata original.
    FOR v_item IN
      SELECT oi.projeto_item_origem_id AS projeto_item_id, oi.quantidade, oi.descricao, oi.setor_origem
      FROM public.orcamento_itens oi
      WHERE oi.orcamento_id = p_orcamento_id
    LOOP
      IF v_item.setor_origem IS NOT NULL THEN
        PERFORM public.registrar_devolucao_projeto_item_setor(
          v_item.projeto_item_id,
          v_item.setor_origem,
          v_item.quantidade,
          format('Devolução via orçamento %s%s', v_numero_orcamento,
            CASE WHEN v_item.descricao IS NOT NULL THEN ' — ' || v_item.descricao ELSE '' END)
        );
      ELSE
        PERFORM public.registrar_devolucao_projeto_item(
          v_item.projeto_item_id,
          v_item.quantidade,
          format('Devolução via orçamento %s%s', v_numero_orcamento,
            CASE WHEN v_item.descricao IS NOT NULL THEN ' — ' || v_item.descricao ELSE '' END)
        );
      END IF;
      v_devolucoes_processadas := v_devolucoes_processadas + 1;
    END LOOP;

    FOR v_i IN 1..v_qtd_parcelas LOOP
      v_valor_parcela := v_valores[v_i];
      INSERT INTO public.projeto_parcelas (
        projeto_id, numero_parcela, valor, data_fechamento, data_vencimento, status,
        forma_pagamento, orcamento_id, descricao, permuta_fornecedor_id
      )
      VALUES (
        v_orcamento.projeto_id, v_i, -v_valor_parcela, current_date, v_data_base + v_dias_offsets[v_i],
        (CASE WHEN v_formas[v_i] = 'permuta' THEN 'paga' ELSE 'pendente' END)::public.parcela_status,
        v_formas[v_i]::public.pagamento_forma, p_orcamento_id,
        'Crédito de devolução gerado pelo orçamento ' || v_numero_orcamento,
        v_permuta_ids[v_i]
      );
      v_parcelas_criadas := v_parcelas_criadas + 1;
    END LOOP;

    -- SPEC-152: carteira/permuta não geram "boleto" (nota de crédito, no
    -- ramo devolução) -- ver comentário no topo do arquivo.
    INSERT INTO public.boletos (nosso_numero, numero_documento, parcela_id, orcamento_id, empresa_id, valor, vencimento, nome_pagador, status, tipo, venda, num_parcela, total_parcelas, emissao)
    SELECT 'DEV-' || regexp_replace(v_numero_orcamento, '[^a-zA-Z0-9]', '', 'g') || '-P' || pp.numero_parcela,
      v_numero_orcamento || '-P' || pp.numero_parcela, pp.id, p_orcamento_id, v_orcamento.empresa_id,
      pp.valor, pp.data_vencimento, coalesce(v_cliente_nome, 'Cliente do orçamento'), 'pendente_registro', 'Nota de Crédito', NULL,
      pp.numero_parcela, v_qtd_parcelas, current_date
    FROM public.projeto_parcelas pp
    WHERE pp.orcamento_id = p_orcamento_id AND pp.forma_pagamento NOT IN ('carteira', 'permuta')
    ON CONFLICT (nosso_numero) DO NOTHING;
    GET DIAGNOSTICS v_boletos_criados = ROW_COUNT;

    -- SPEC-152: contrapartida automática de Contas a Pagar pra cada
    -- parcela de permuta (mesmo padrão manual de "Cadastrar Duplicatas",
    -- SPEC-073: boletos.tipo_operacao = 'CP' + apropriacao_id).
    SELECT id INTO v_plano_contas_permuta_id FROM public.plano_de_contas WHERE nome = 'PERMUTA/CONTRAPARTIDA' AND nivel = 3 LIMIT 1;
    INSERT INTO public.boletos (
      nosso_numero, numero_documento, orcamento_id, empresa_id, apropriacao_id,
      tipo_operacao, valor, vencimento, nome_pagador, status, tipo, num_parcela, total_parcelas, emissao, observacao
    )
    SELECT
      'PERM-' || regexp_replace(v_numero_orcamento, '[^a-zA-Z0-9]', '', 'g') || '-P' || pp.numero_parcela,
      v_numero_orcamento || '-PERMUTA-P' || pp.numero_parcela,
      p_orcamento_id, v_orcamento.empresa_id, v_plano_contas_permuta_id,
      'CP', abs(pp.valor), pp.data_vencimento,
      coalesce(f.razao_social, f.nome, 'Contraparte da permuta'),
      'Pendente', 'Normal', pp.numero_parcela, v_qtd_parcelas, current_date,
      'Contrapartida automática de permuta gerada pela aprovação do orçamento ' || v_numero_orcamento
    FROM public.projeto_parcelas pp
    LEFT JOIN public.contatos f ON f.id = pp.permuta_fornecedor_id
    WHERE pp.orcamento_id = p_orcamento_id AND pp.forma_pagamento = 'permuta'
    ON CONFLICT (nosso_numero) DO NOTHING;
    GET DIAGNOSTICS v_permuta_criados = ROW_COUNT;

    RETURN jsonb_build_object(
      'orcamento_id', p_orcamento_id, 'status', 'Orçamento Aprovado', 'natureza_operacao', 'devolucao',
      'projeto_id', v_orcamento.projeto_id,
      'devolucoes_processadas', v_devolucoes_processadas,
      'parcelas_criadas', v_parcelas_criadas, 'boletos_criados', v_boletos_criados,
      'contrapartidas_permuta_criadas', v_permuta_criados,
      'ja_processado', false
    );
  END IF;

  -- =====================================================================
  -- Ramo VENDA — comportamento original, exceto pela correção de prioridade
  -- da descrição do item (ver cabeçalho da migration).
  -- =====================================================================
  -- SPEC-135: bloqueia aprovação (faturamento) quando existe item sem
  -- produto cadastrado — sem isso, vira uma venda "fantasma" sem controle
  -- de estoque nenhum (o loop abaixo já pula reserva pra item sem
  -- produto_id, mas antes disso deixava aprovar e gerar parcela/boleto
  -- normalmente). O item precisa ser vinculado a um produto real (cadastro)
  -- antes desta aprovação — não se aplica à devolução, que já retorna acima.
  IF EXISTS (
    SELECT 1 FROM public.orcamento_itens oi
    WHERE oi.orcamento_id = p_orcamento_id AND oi.produto_id IS NULL
  ) THEN
    RAISE EXCEPTION 'Orçamento % possui item sem produto cadastrado (peça sem código interno) — cadastre o produto antes de aprovar financeiramente.', v_numero_orcamento
      USING ERRCODE = 'P0001';
  END IF;

  SELECT count(*) INTO v_itens_existentes FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id;
  SELECT count(*) INTO v_parcelas_existentes FROM public.projeto_parcelas WHERE orcamento_id = p_orcamento_id;
  SELECT count(*) INTO v_boletos_existentes FROM public.boletos WHERE orcamento_id = p_orcamento_id AND tipo_operacao IS DISTINCT FROM 'CP';

  IF v_itens_existentes > 0 AND v_parcelas_existentes = v_qtd_parcelas AND v_boletos_existentes = v_qtd_boletos_esperados THEN
    UPDATE public.orcamentos SET status = 'Orçamento Aprovado' WHERE id = p_orcamento_id;
    RETURN jsonb_build_object(
      'orcamento_id', p_orcamento_id, 'status', 'Orçamento Aprovado', 'projeto_id', v_orcamento.projeto_id,
      'numero_venda', v_orcamento.numero_venda,
      'projeto_itens_criados', 0, 'parcelas_criadas', 0, 'boletos_criados', 0,
      'reservas_estoque_aplicadas', 0, 'saldos_operacionais_criados', 0,
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

  -- SPEC-136: numero da venda, gerado uma unica vez, sequencia global
  -- "VENDA-0001" no mesmo padrao de set_orcamento_numero() para ORC-XXXX.
  IF v_orcamento.numero_venda IS NULL THEN
    SELECT COALESCE(MAX(CAST(SUBSTRING(numero_venda FROM 7) AS INTEGER)), 0) + 1
    INTO v_seq_venda
    FROM public.orcamentos
    WHERE numero_venda LIKE 'VENDA-%' AND numero_venda ~ '^VENDA-\d+$';
    v_numero_venda := 'VENDA-' || LPAD(v_seq_venda::text, 4, '0');
  ELSE
    v_numero_venda := v_orcamento.numero_venda;
  END IF;

  UPDATE public.orcamentos
  SET status = 'Orçamento Aprovado', requer_revisao_financeira = false, numero_venda = v_numero_venda
  WHERE id = p_orcamento_id;

  BEGIN
    INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
    VALUES (p_orcamento_id, v_status_anterior, 'Orçamento Aprovado', auth.uid()::text, 'Aprovação financeira — processamento de itens, parcelas e boletos');
  EXCEPTION
    WHEN undefined_table OR undefined_column OR foreign_key_violation THEN
      NULL;
  END;

  FOR v_item IN
    INSERT INTO public.projeto_itens (
      projeto_id, produto_id, descricao, quantidade, preco_unitario, desconto, validado, orcamento_id,
      orcamento_item_id, l_fixo
    )
    SELECT v_orcamento.projeto_id, oi.produto_id, coalesce(oi.descricao, p.nome, oi.custom_id, 'Item do Orçamento'),
      coalesce(oi.quantidade, 0), coalesce(oi.preco_unitario, 0), coalesce(oi.desconto, 0),
      true, p_orcamento_id,
      oi.id, oi.custom_id
    FROM public.orcamento_itens oi LEFT JOIN public.produtos p ON p.id = oi.produto_id
    WHERE oi.orcamento_id = p_orcamento_id
    RETURNING id, produto_id, quantidade
  LOOP
    v_itens_criados := v_itens_criados + 1;

    CONTINUE WHEN v_item.produto_id IS NULL OR coalesce(v_item.quantidade, 0) <= 0;

    INSERT INTO public.estoque_itens (produto_id, local, quantidade, quantidade_reservada, atualizado_em)
    VALUES (v_item.produto_id, 'Estoque'::public.estoque_local, 0, 0, NOW())
    ON CONFLICT (produto_id, local) DO NOTHING;

    SELECT quantidade, quantidade_reservada
      INTO v_estoque_fisico, v_estoque_reservado_atual
    FROM public.estoque_itens
    WHERE produto_id = v_item.produto_id AND local = 'Estoque'::public.estoque_local
    FOR UPDATE;

    v_disponivel_fisico := GREATEST(0, coalesce(v_estoque_fisico, 0) - coalesce(v_estoque_reservado_atual, 0));
    v_q_reserva := LEAST(v_item.quantidade, v_disponivel_fisico);
    v_q_entrega_futura := GREATEST(0, v_item.quantidade - v_q_reserva);

    UPDATE public.estoque_itens
    SET quantidade_reservada = quantidade_reservada + v_item.quantidade, atualizado_em = NOW()
    WHERE produto_id = v_item.produto_id AND local = 'Estoque'::public.estoque_local;

    v_reservas_criadas := v_reservas_criadas + 1;

    INSERT INTO public.estoque_saldos_projeto_item (projeto_item_id, q_reserva, q_entrega_futura)
    VALUES (v_item.id, v_q_reserva, v_q_entrega_futura)
    ON CONFLICT (projeto_item_id) DO NOTHING;

    v_saldos_criados := v_saldos_criados + 1;

    INSERT INTO public.estoque_movimentos_projeto_item (
      projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por
    )
    VALUES (
      v_item.id, 'aprovacao_orcamento', v_item.quantidade, 'aprovar_orcamento_financeiro', p_orcamento_id,
      format('Reserva %s / entrega futura %s na aprovação do orçamento %s', v_q_reserva, v_q_entrega_futura, v_numero_orcamento),
      auth.uid()
    );
  END LOOP;

  FOR v_i IN 1..v_qtd_parcelas LOOP
    v_valor_parcela := v_valores[v_i];
    INSERT INTO public.projeto_parcelas (
      projeto_id, numero_parcela, valor, data_fechamento, data_vencimento, status,
      forma_pagamento, orcamento_id, descricao, permuta_fornecedor_id
    )
    VALUES (
      v_orcamento.projeto_id, v_i, v_valor_parcela, current_date, v_data_base + v_dias_offsets[v_i],
      (CASE WHEN v_formas[v_i] = 'permuta' THEN 'paga' ELSE 'pendente' END)::public.parcela_status,
      v_formas[v_i]::public.pagamento_forma, p_orcamento_id,
      'Parcela gerada pelo orçamento ' || v_numero_orcamento,
      v_permuta_ids[v_i]
    );
    v_parcelas_criadas := v_parcelas_criadas + 1;
  END LOOP;

  -- SPEC-152: carteira/permuta não geram boleto de cobrança pro cliente
  -- (ver comentário no topo do arquivo).
  INSERT INTO public.boletos (nosso_numero, numero_documento, parcela_id, orcamento_id, empresa_id, valor, vencimento, nome_pagador, status, tipo, venda, num_parcela, total_parcelas, emissao)
  SELECT 'ORC-' || regexp_replace(v_numero_orcamento, '[^a-zA-Z0-9]', '', 'g') || '-P' || pp.numero_parcela,
    v_numero_orcamento || '-P' || pp.numero_parcela, pp.id, p_orcamento_id, v_orcamento.empresa_id,
    pp.valor, pp.data_vencimento, coalesce(v_cliente_nome, 'Cliente do orçamento'), 'pendente_registro', 'Nota Fiscal', NULL,
    pp.numero_parcela, v_qtd_parcelas, current_date
  FROM public.projeto_parcelas pp
  WHERE pp.orcamento_id = p_orcamento_id AND pp.forma_pagamento NOT IN ('carteira', 'permuta')
  ON CONFLICT (nosso_numero) DO NOTHING;
  GET DIAGNOSTICS v_boletos_criados = ROW_COUNT;

  -- SPEC-152: contrapartida automática de Contas a Pagar pra cada parcela
  -- de permuta (mesmo padrão manual de "Cadastrar Duplicatas", SPEC-073:
  -- boletos.tipo_operacao = 'CP' + apropriacao_id -- rastreado até a
  -- origem por boletos.orcamento_id, já existente).
  SELECT id INTO v_plano_contas_permuta_id FROM public.plano_de_contas WHERE nome = 'PERMUTA/CONTRAPARTIDA' AND nivel = 3 LIMIT 1;
  INSERT INTO public.boletos (
    nosso_numero, numero_documento, orcamento_id, empresa_id, apropriacao_id,
    tipo_operacao, valor, vencimento, nome_pagador, status, tipo, num_parcela, total_parcelas, emissao, observacao
  )
  SELECT
    'PERM-' || regexp_replace(v_numero_orcamento, '[^a-zA-Z0-9]', '', 'g') || '-P' || pp.numero_parcela,
    v_numero_orcamento || '-PERMUTA-P' || pp.numero_parcela,
    p_orcamento_id, v_orcamento.empresa_id, v_plano_contas_permuta_id,
    'CP', abs(pp.valor), pp.data_vencimento,
    coalesce(f.razao_social, f.nome, 'Contraparte da permuta'),
    'Pendente', 'Normal', pp.numero_parcela, v_qtd_parcelas, current_date,
    'Contrapartida automática de permuta gerada pela aprovação do orçamento ' || v_numero_orcamento
  FROM public.projeto_parcelas pp
  LEFT JOIN public.contatos f ON f.id = pp.permuta_fornecedor_id
  WHERE pp.orcamento_id = p_orcamento_id AND pp.forma_pagamento = 'permuta'
  ON CONFLICT (nosso_numero) DO NOTHING;
  GET DIAGNOSTICS v_permuta_criados = ROW_COUNT;

  RETURN jsonb_build_object(
    'orcamento_id', p_orcamento_id, 'status', 'Orçamento Aprovado', 'projeto_id', v_orcamento.projeto_id,
    'numero_venda', v_numero_venda,
    'projeto_itens_criados', v_itens_criados, 'parcelas_criadas', v_parcelas_criadas, 'boletos_criados', v_boletos_criados,
    'contrapartidas_permuta_criadas', v_permuta_criados,
    'reservas_estoque_aplicadas', v_reservas_criadas, 'saldos_operacionais_criados', v_saldos_criados,
    'nota_fiscal_status', 'pendente_api', 'ja_processado', false
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.desfazer_aprovacao_financeira(p_orcamento_id uuid, p_motivo text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_orcamento public.orcamentos%ROWTYPE;
  v_status_anterior text;
  v_numero text;
  v_user_role text;
  v_item record;
  v_itens_apagados integer := 0;
  v_parcelas_apagadas integer := 0;
  v_boletos_apagados integer := 0;
BEGIN
  IF p_motivo IS NULL OR btrim(p_motivo) = '' THEN
    RAISE EXCEPTION 'Informe o motivo antes de desfazer a aprovação financeira.' USING ERRCODE = 'P0001';
  END IF;

  SELECT u.role INTO v_user_role FROM public.usuarios u WHERE u.id = auth.uid();

  IF NOT (
    COALESCE(auth.role(), '') = 'service_role'
    OR v_user_role IN ('admin', 'gerente')
  ) THEN
    RAISE EXCEPTION 'Apenas admin ou gerente podem desfazer uma aprovação financeira.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_orcamento FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento não encontrado.' USING ERRCODE = 'P0001';
  END IF;

  -- SPEC-195: vínculo Connect não tem reserva para estornar — usar desvincular_orcamento_connect.
  IF v_orcamento.vinculo_connect THEN
    RAISE EXCEPTION 'Orçamento % é vínculo de venda da Connect — use "Desfazer vínculo".', coalesce(v_orcamento.numero, p_orcamento_id::text)
      USING ERRCODE = 'P0001';
  END IF;

  v_status_anterior := v_orcamento.status;
  v_numero := COALESCE(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.status <> 'Orçamento Aprovado' THEN
    RAISE EXCEPTION 'Orçamento % não está em Orçamento Aprovado. Status atual: %', v_numero, v_status_anterior
      USING ERRCODE = 'P0002';
  END IF;

  IF v_orcamento.natureza_operacao = 'devolucao' THEN
    RAISE EXCEPTION 'Orçamento % é de devolução — desfazer aprovação financeira de devolução não é suportado.', v_numero
      USING ERRCODE = 'P0001';
  END IF;

  -- Bloqueios: algo já consumiu o que essa aprovação criou.
  IF EXISTS (
    SELECT 1 FROM public.boletos b WHERE b.orcamento_id = p_orcamento_id AND b.status <> 'pendente_registro'
  ) THEN
    RAISE EXCEPTION 'Orçamento % tem boleto com status diferente de "pendente_registro" — não pode desfazer (já foi remessado/pago).', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.notas_fiscais nf
    JOIN public.boletos b ON b.id = nf.boleto_id
    WHERE b.orcamento_id = p_orcamento_id
  ) THEN
    RAISE EXCEPTION 'Orçamento % já tem nota fiscal emitida sobre um dos boletos — não pode desfazer.', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.retorno_bancario_registros rbr
    WHERE rbr.boleto_id IN (SELECT id FROM public.boletos WHERE orcamento_id = p_orcamento_id)
       OR rbr.parcela_id IN (SELECT id FROM public.projeto_parcelas WHERE orcamento_id = p_orcamento_id)
  ) THEN
    RAISE EXCEPTION 'Orçamento % já tem retorno bancário registrado — não pode desfazer.', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.projeto_parcelas pp WHERE pp.orcamento_id = p_orcamento_id AND pp.status <> 'pendente'
  ) THEN
    RAISE EXCEPTION 'Orçamento % tem parcela com status diferente de "pendente" — não pode desfazer.', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.transacoes t
    WHERE t.parcela_id IN (SELECT id FROM public.projeto_parcelas WHERE orcamento_id = p_orcamento_id)
  ) THEN
    RAISE EXCEPTION 'Orçamento % já tem transação financeira lançada — não pode desfazer.', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.devolucoes_estoque de
    WHERE de.projeto_item_id IN (SELECT id FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id)
  ) THEN
    RAISE EXCEPTION 'Orçamento % já teve item devolvido ao estoque — não pode desfazer.', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.separacao_itens si
    WHERE si.projeto_item_id IN (SELECT id FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id)
  ) THEN
    RAISE EXCEPTION 'Orçamento % já teve item separado para entrega — não pode desfazer.', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.transferencias_estoque te
    WHERE te.origem_projeto_item_id IN (SELECT id FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id)
       OR te.destino_projeto_item_id IN (SELECT id FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id)
  ) THEN
    RAISE EXCEPTION 'Orçamento % já teve item usado em transferência de estoque — não pode desfazer.', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.pedido_compra_item_origem pio
    WHERE pio.projeto_item_id IN (SELECT id FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id)
  ) THEN
    RAISE EXCEPTION 'Orçamento % já teve item usado como origem de pedido de compra — não pode desfazer.', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.orcamento_itens oi
    WHERE oi.projeto_item_origem_id IN (SELECT id FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id)
  ) THEN
    RAISE EXCEPTION 'Orçamento % já teve item usado como origem de um orçamento de devolução — não pode desfazer.', v_numero
      USING ERRCODE = 'P0002';
  END IF;

  -- Nenhum bloqueio: desfaz reserva de estoque item a item, depois apaga em cascata manual.
  FOR v_item IN
    SELECT id, produto_id, quantidade FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id
  LOOP
    IF v_item.produto_id IS NOT NULL AND COALESCE(v_item.quantidade, 0) > 0 THEN
      UPDATE public.estoque_itens
      SET quantidade_reservada = GREATEST(0, quantidade_reservada - v_item.quantidade),
          atualizado_em = NOW()
      WHERE produto_id = v_item.produto_id AND local = 'Estoque'::public.estoque_local;

      INSERT INTO public.estoque_movimentos_projeto_item (
        projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por
      ) VALUES (
        v_item.id, 'estorno_aprovacao_orcamento', v_item.quantidade, 'desfazer_aprovacao_financeira', p_orcamento_id,
        format('Estorno de reserva ao desfazer aprovação do orçamento %s: %s', v_numero, p_motivo),
        auth.uid()
      );
    END IF;
  END LOOP;

  DELETE FROM public.estoque_saldos_projeto_item
  WHERE projeto_item_id IN (SELECT id FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id);

  DELETE FROM public.boletos WHERE orcamento_id = p_orcamento_id;
  GET DIAGNOSTICS v_boletos_apagados = ROW_COUNT;

  DELETE FROM public.projeto_parcelas WHERE orcamento_id = p_orcamento_id;
  GET DIAGNOSTICS v_parcelas_apagadas = ROW_COUNT;

  DELETE FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id;
  GET DIAGNOSTICS v_itens_apagados = ROW_COUNT;

  UPDATE public.orcamentos
  SET status = 'Aprovação Financeira',
      requer_revisao_financeira = true
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (p_orcamento_id, v_status_anterior, 'Aprovação Financeira', auth.uid()::text, p_motivo);

  RETURN jsonb_build_object(
    'orcamento_id', p_orcamento_id,
    'numero', v_numero,
    'status', 'Aprovação Financeira',
    'projeto_itens_apagados', v_itens_apagados,
    'parcelas_apagadas', v_parcelas_apagadas,
    'boletos_apagados', v_boletos_apagados
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.cancelar_orcamento(p_orcamento_id uuid, p_motivo text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_orcamento           public.orcamentos%ROWTYPE;
    v_status_anterior     text;
    v_numero_orcamento    text;
    v_reservas_revertidas integer := 0;
    v_parcelas_canceladas integer := 0;
    v_boletos_cancelados  integer := 0;
    v_itens_invalidados   integer := 0;
    v_saldos_cancelados   integer := 0;
BEGIN
    -- 1. Carregar e travar o orçamento
    SELECT * INTO v_orcamento
    FROM public.orcamentos
    WHERE id = p_orcamento_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Orçamento % não encontrado.', p_orcamento_id
            USING ERRCODE = 'P0001';
    END IF;

    -- SPEC-195: vínculo Connect se desfaz por desvincular_orcamento_connect (apaga os itens do projeto).
    IF v_orcamento.vinculo_connect AND v_orcamento.status = 'Orçamento Aprovado' THEN
        RAISE EXCEPTION 'Orçamento % é vínculo de venda da Connect — use "Desfazer vínculo" antes de cancelar.', coalesce(v_orcamento.numero, p_orcamento_id::text)
            USING ERRCODE = 'P0001';
    END IF;

    v_status_anterior  := v_orcamento.status;
    v_numero_orcamento := coalesce(v_orcamento.numero, left(p_orcamento_id::text, 8));

    -- 2. Idempotência: já cancelado
    IF v_status_anterior = 'cancelado' THEN
        RETURN jsonb_build_object(
            'orcamento_id',          p_orcamento_id,
            'numero',                v_numero_orcamento,
            'status',                'cancelado',
            'reservas_revertidas',   0,
            'parcelas_canceladas',   0,
            'boletos_cancelados',    0,
            'itens_invalidados',     0,
            'saldos_cancelados',     0,
            'ja_cancelado',          true
        );
    END IF;

    -- 3. Se estava aprovado → desfazer todos os efeitos da aprovação
    IF v_status_anterior = 'aprovado' THEN

        -- 3a. Reverter reservas de estoque físico (estoque_itens), pelo saldo
        --     aberto real do item (SPEC-010: q_reserva + q_entrega_futura +
        --     q_ag_separar + q_separado) — não mais pela quantidade original
        --     do orçamento, para não reverter em dobro um item que já tenha
        --     sido parcialmente entregue/transferido antes do cancelamento.
        UPDATE public.estoque_itens ei
        SET quantidade_reservada = GREATEST(0, ei.quantidade_reservada - aberto.qtd_aberta),
            atualizado_em        = NOW()
        FROM (
            SELECT pi.produto_id,
                   SUM(esp.q_reserva + esp.q_entrega_futura + esp.q_ag_separar + esp.q_separado) AS qtd_aberta
            FROM public.projeto_itens pi
            JOIN public.estoque_saldos_projeto_item esp ON esp.projeto_item_id = pi.id
            WHERE pi.orcamento_id = p_orcamento_id
              AND esp.status_operacional = 'ativo'
            GROUP BY pi.produto_id
        ) aberto
        WHERE ei.produto_id = aberto.produto_id
          AND ei.local      = 'Estoque'::public.estoque_local
          AND aberto.qtd_aberta > 0;

        GET DIAGNOSTICS v_reservas_revertidas = ROW_COUNT;

        -- 3b. Cancelar parcelas financeiras
        UPDATE public.projeto_parcelas
        SET status = 'cancelada'::public.parcela_status
        WHERE orcamento_id = p_orcamento_id
          AND status = 'pendente'::public.parcela_status;

        GET DIAGNOSTICS v_parcelas_canceladas = ROW_COUNT;

        -- 3c. Cancelar boletos
        UPDATE public.boletos
        SET status = 'cancelado'
        WHERE orcamento_id = p_orcamento_id
          AND status IN ('pendente_registro', 'Pendente', 'pendente');

        GET DIAGNOSTICS v_boletos_cancelados = ROW_COUNT;

        -- 3d. Invalidar projeto_itens (preservar histórico, apenas desmarca validado)
        UPDATE public.projeto_itens
        SET validado = false
        WHERE orcamento_id = p_orcamento_id
          AND validado = true;

        GET DIAGNOSTICS v_itens_invalidados = ROW_COUNT;

        -- 3e. Encerrar o saldo operacional do item (SPEC-010): zera as
        --     posições abertas, preserva q_entregue/q_devolvida para
        --     auditoria, e registra o movimento de cancelamento com a
        --     quantidade que estava aberta antes de zerar.
        WITH antes AS (
            SELECT esp.projeto_item_id,
                   (esp.q_reserva + esp.q_entrega_futura + esp.q_ag_separar + esp.q_separado) AS qtd_aberta
            FROM public.estoque_saldos_projeto_item esp
            JOIN public.projeto_itens pi ON pi.id = esp.projeto_item_id
            WHERE pi.orcamento_id = p_orcamento_id
              AND esp.status_operacional = 'ativo'
        ),
        cancelados AS (
            UPDATE public.estoque_saldos_projeto_item esp
            SET status_operacional = 'cancelado',
                q_reserva           = 0,
                q_entrega_futura    = 0,
                q_ag_separar        = 0,
                q_separado          = 0
            FROM public.projeto_itens pi
            WHERE pi.id = esp.projeto_item_id
              AND pi.orcamento_id = p_orcamento_id
              AND esp.status_operacional = 'ativo'
            RETURNING esp.projeto_item_id
        )
        INSERT INTO public.estoque_movimentos_projeto_item (
            projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por
        )
        SELECT
            c.projeto_item_id,
            'cancelamento',
            antes.qtd_aberta,
            'cancelar_orcamento',
            p_orcamento_id,
            coalesce(p_motivo, 'Cancelamento do orçamento ' || v_numero_orcamento),
            auth.uid()
        FROM cancelados c
        JOIN antes ON antes.projeto_item_id = c.projeto_item_id
        WHERE antes.qtd_aberta > 0;

        GET DIAGNOSTICS v_saldos_cancelados = ROW_COUNT;

    END IF;

    -- 4. Atualizar status do orçamento
    UPDATE public.orcamentos
    SET status = 'cancelado'
    WHERE id = p_orcamento_id;

    -- 5. Registrar histórico
    INSERT INTO public.historico_status_orcamentos (
        orcamento_id,
        status_anterior,
        status_novo,
        usuario,
        observacao
    ) VALUES (
        p_orcamento_id,
        v_status_anterior,
        'cancelado',
        auth.uid()::text,
        coalesce(p_motivo, 'Cancelamento via RPC cancelar_orcamento')
    );

    RETURN jsonb_build_object(
        'orcamento_id',        p_orcamento_id,
        'numero',              v_numero_orcamento,
        'status',              'cancelado',
        'status_anterior',     v_status_anterior,
        'reservas_revertidas', v_reservas_revertidas,
        'parcelas_canceladas', v_parcelas_canceladas,
        'boletos_cancelados',  v_boletos_cancelados,
        'itens_invalidados',   v_itens_invalidados,
        'saldos_cancelados',   v_saldos_cancelados,
        'ja_cancelado',        false
    );
END;
$function$;
