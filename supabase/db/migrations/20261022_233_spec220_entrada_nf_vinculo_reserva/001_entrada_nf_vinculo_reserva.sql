-- SPEC-220 (reunião Vinicius 21/10, pedido do usuário 22/10): Entrada de Nota Fiscal completa.
-- A. vínculo com o cliente: o que chegou sai da ENTREGA FUTURA e vai para a RESERVA do L (estoque_saldos_projeto_item),
--    com limitador (nunca mais do que chegou nem do que o L espera). Decisão 22/10: só o saldo dos L (nosso, nasce na
--    aprovação do orçamento); o estoque físico que vem da Connect (produtos.estoque_*, estoque_itens) não é tocado.
-- B. apropriação (plano de contas; padrão COMPRAS - REVENDA) nas parcelas da nota no Contas a Pagar.
-- C. chave de acesso e datas da nota. D. valores por item, desconto e despesas acessórias.
-- O cancelamento (SPEC-218) passa a desfazer o vínculo (reserva volta para entrega futura).
BEGIN;

-- 1. Colunas ------------------------------------------------------------------------------------------------------
ALTER TABLE public.notas_fiscais_compra
  ADD COLUMN IF NOT EXISTS chave_acesso text,
  ADD COLUMN IF NOT EXISTS data_entrega date,
  ADD COLUMN IF NOT EXISTS data_entrada date,
  ADD COLUMN IF NOT EXISTS plano_contas_id uuid REFERENCES public.plano_de_contas(id),
  ADD COLUMN IF NOT EXISTS valor_desconto numeric(14,2),
  ADD COLUMN IF NOT EXISTS valor_despesas_acessorias numeric(14,2);
ALTER TABLE public.notas_fiscais_compra
  ADD CONSTRAINT notas_fiscais_compra_chave_acesso_check
  CHECK (chave_acesso IS NULL OR chave_acesso ~ '^\d{44}$');
COMMENT ON COLUMN public.notas_fiscais_compra.plano_contas_id IS 'SPEC-220: apropriação das parcelas da nota (padrão COMPRAS - REVENDA).';

ALTER TABLE public.nota_fiscal_compra_itens
  ADD COLUMN IF NOT EXISTS valor_unitario numeric(14,4),
  ADD COLUMN IF NOT EXISTS valor_ipi numeric(14,4),
  ADD COLUMN IF NOT EXISTS valor_icms numeric(14,4),
  ADD COLUMN IF NOT EXISTS valor_st numeric(14,4);
COMMENT ON COLUMN public.nota_fiscal_compra_itens.valor_unitario IS 'SPEC-220: valor unitário do item na nota (sem IPI/ST); IPI, ICMS e ST também por unidade.';

-- 2. Vínculo com o cliente -----------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.nota_fiscal_compra_vinculos (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nota_id         uuid NOT NULL REFERENCES public.notas_fiscais_compra(id) ON DELETE CASCADE,
  produto_id      uuid NOT NULL REFERENCES public.produtos(id),
  projeto_item_id uuid NOT NULL REFERENCES public.projeto_itens(id),
  quantidade      numeric(10,3) NOT NULL CHECK (quantidade > 0),
  criado_por      uuid DEFAULT auth.uid(),
  criado_em       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (nota_id, projeto_item_id)
);
COMMENT ON TABLE public.nota_fiscal_compra_vinculos IS
  'SPEC-220: quanto de cada peça da nota foi da entrega futura para a reserva de cada L. Gravada só pela RPC da entrada.';
CREATE INDEX IF NOT EXISTS idx_nf_compra_vinculos_projeto_item ON public.nota_fiscal_compra_vinculos (projeto_item_id);

ALTER TABLE public.nota_fiscal_compra_vinculos ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.nota_fiscal_compra_vinculos FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.nota_fiscal_compra_vinculos FROM authenticated;
GRANT SELECT ON public.nota_fiscal_compra_vinculos TO authenticated;
CREATE POLICY nota_fiscal_compra_vinculos_select ON public.nota_fiscal_compra_vinculos
  FOR SELECT TO authenticated
  USING ((SELECT public.pode_acessar_sistema('necessidade-de-compra'))
         OR (SELECT public.pode_acessar_sistema('separacao-parcial'))
         OR (SELECT public.pode_acessar_sistema('logistica')));

-- 3. Quem espera cada peça (entrega futura), para escolher na entrada -----------------------------------------------
CREATE OR REPLACE FUNCTION public.entregas_futuras_para_entrada(p_produto_ids uuid[])
 RETURNS TABLE(projeto_item_id uuid, produto_id uuid, venda_numero text, orcamento_numero text, projeto_codigo text,
               cliente_nome text, l_fixo text, empresa_nome text, q_entrega_futura numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, NULL) THEN
    RAISE EXCEPTION 'Sem permissao.' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT s.projeto_item_id, pi.produto_id, o.numero_venda::text, o.numero::text, pr.codigo::text,
         coalesce(c.nome, '—')::text, pi.l_fixo, e.nome::text, s.q_entrega_futura
    FROM public.estoque_saldos_projeto_item s
    JOIN public.projeto_itens pi ON pi.id = s.projeto_item_id
    LEFT JOIN public.orcamentos o ON o.id = pi.orcamento_id
    LEFT JOIN public.projetos pr ON pr.id = pi.projeto_id
    LEFT JOIN public.contatos c ON c.id = coalesce(o.cliente_id, pr.cliente_id)
    LEFT JOIN public.empresas e ON e.id = o.empresa_id
   WHERE pi.produto_id = ANY (p_produto_ids)
     AND s.q_entrega_futura > 0
   ORDER BY o.numero_venda NULLS LAST, pi.l_fixo;
END;
$function$;
REVOKE ALL ON FUNCTION public.entregas_futuras_para_entrada(uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.entregas_futuras_para_entrada(uuid[]) TO authenticated;

-- 4. Entrada da nota: + valores por item, dados da nota e vínculos ---------------------------------------------------
-- Assinatura nova (2 parâmetros a mais, com padrão): a antiga é apagada para não ficar sobrecarga (overload).
DROP FUNCTION IF EXISTS public.registrar_entrada_nota_compra(uuid, jsonb, jsonb, jsonb, jsonb, uuid);

-- p_itens: [{pedido_item_id, quantidade, valor_unitario?, valor_ipi?, valor_icms?, valor_st?}]
-- p_nota: {numero_nf, data_emissao, valor, valor_st, arquivo_url, observacao,
--          chave_acesso?, data_entrega?, data_entrada?, plano_contas_id?, valor_desconto?, valor_despesas_acessorias?}
-- p_vinculos: [{produto_id, projeto_item_id, quantidade}]  (entrega futura -> reserva)
CREATE OR REPLACE FUNCTION public.registrar_entrada_nota_compra(
  p_pedido_id uuid, p_itens jsonb, p_nota jsonb, p_parcelas jsonb DEFAULT '[]'::jsonb,
  p_antecipacoes jsonb DEFAULT '[]'::jsonb, p_fornecedor_id uuid DEFAULT NULL, p_vinculos jsonb DEFAULT '[]'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_ped        record;
  v_forn       uuid;
  v_numero_nf  text := nullif(trim(coalesce(p_nota->>'numero_nf', '')), '');
  v_valor      numeric := round(coalesce(nullif(p_nota->>'valor', '')::numeric, 0), 2);
  v_chave      text := nullif(regexp_replace(coalesce(p_nota->>'chave_acesso', ''), '\D', '', 'g'), '');
  v_plano      uuid := nullif(p_nota->>'plano_contas_id', '')::uuid;
  v_nota_id    uuid;
  v_res        jsonb;
  v_el         jsonb;
  v_n          integer := 0;
  v_soma_parc  numeric := 0;
  v_aplicado   numeric := 0;
  v_pag        record;
  v_saldo      numeric;
  v_qtd        numeric;
  v_vinc       record;
  v_reservado  numeric := 0;
BEGIN
  IF NOT public.hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar') THEN
    RAISE EXCEPTION 'Sem permissao para dar entrada em pedido de compra.' USING ERRCODE = '42501';
  END IF;

  SELECT id, numero, status, fornecedor_id, empresa_id INTO v_ped
    FROM public.pedidos_compra WHERE id = p_pedido_id FOR UPDATE;
  IF v_ped.id IS NULL THEN
    RAISE EXCEPTION 'Pedido de compra nao encontrado.' USING ERRCODE = 'P0001';
  END IF;
  IF v_numero_nf IS NULL THEN
    RAISE EXCEPTION 'Informe o numero da nota fiscal.' USING ERRCODE = 'P0001';
  END IF;
  IF v_valor <= 0 THEN
    RAISE EXCEPTION 'Informe o valor total da nota.' USING ERRCODE = 'P0001';
  END IF;
  IF v_chave IS NOT NULL AND length(v_chave) <> 44 THEN
    RAISE EXCEPTION 'A chave de acesso tem 44 numeros (veio com %).', length(v_chave) USING ERRCODE = 'P0001';
  END IF;
  IF EXISTS (SELECT 1 FROM public.notas_fiscais_compra
              WHERE pedido_compra_id = p_pedido_id AND trim(numero_nf) = v_numero_nf AND cancelada_em IS NULL) THEN
    RAISE EXCEPTION 'A nota % ja foi registrada neste pedido.', v_numero_nf USING ERRCODE = 'P0001';
  END IF;
  -- Apropriação: a informada ou COMPRAS - REVENDA
  IF v_plano IS NULL THEN
    SELECT id INTO v_plano FROM public.plano_de_contas WHERE codigo_connect = 2050001;
  ELSIF NOT EXISTS (SELECT 1 FROM public.plano_de_contas WHERE id = v_plano) THEN
    RAISE EXCEPTION 'Apropriacao (plano de contas) nao encontrada.' USING ERRCODE = 'P0001';
  END IF;

  -- Fornecedor da nota diferente do pedido (ex.: pedido Emétris, nota Spot LED): o pedido passa a ser dele.
  v_forn := v_ped.fornecedor_id;
  IF p_fornecedor_id IS NOT NULL AND p_fornecedor_id IS DISTINCT FROM v_ped.fornecedor_id THEN
    IF NOT EXISTS (SELECT 1 FROM public.contatos WHERE id = p_fornecedor_id) THEN
      RAISE EXCEPTION 'Fornecedor nao encontrado.' USING ERRCODE = 'P0001';
    END IF;
    UPDATE public.pedidos_compra SET fornecedor_id = p_fornecedor_id, atualizado_em = now() WHERE id = p_pedido_id;
    v_forn := p_fornecedor_id;
  END IF;

  -- Quantidades (mesmas regras de antes; muda o status do pedido)
  v_res := public.registrar_entrada_pedido_compra(p_pedido_id, p_itens);

  INSERT INTO public.notas_fiscais_compra
    (pedido_compra_id, numero_nf, data_emissao, valor, valor_st, arquivo_url, observacao,
     criado_por, fornecedor_id, empresa_id,
     chave_acesso, data_entrega, data_entrada, plano_contas_id, valor_desconto, valor_despesas_acessorias)
  VALUES (p_pedido_id, v_numero_nf, nullif(p_nota->>'data_emissao', '')::date, v_valor,
          nullif(round(coalesce(nullif(p_nota->>'valor_st', '')::numeric, 0), 2), 0),
          nullif(p_nota->>'arquivo_url', ''), nullif(trim(coalesce(p_nota->>'observacao', '')), ''),
          auth.uid(), v_forn, v_ped.empresa_id,
          v_chave, nullif(p_nota->>'data_entrega', '')::date,
          coalesce(nullif(p_nota->>'data_entrada', '')::date, current_date), v_plano,
          nullif(round(coalesce(nullif(p_nota->>'valor_desconto', '')::numeric, 0), 2), 0),
          nullif(round(coalesce(nullif(p_nota->>'valor_despesas_acessorias', '')::numeric, 0), 2), 0))
  RETURNING id INTO v_nota_id;

  -- SPEC-218: quanto de cada item entrou por esta nota (o cancelamento devolve). SPEC-220: + valores da nota.
  INSERT INTO public.nota_fiscal_compra_itens
    (nota_id, pedido_item_id, quantidade, valor_unitario, valor_ipi, valor_icms, valor_st)
  SELECT v_nota_id, (e->>'pedido_item_id')::uuid, sum(nullif(e->>'quantidade', '')::numeric),
         max(nullif(e->>'valor_unitario', '')::numeric), max(nullif(e->>'valor_ipi', '')::numeric),
         max(nullif(e->>'valor_icms', '')::numeric), max(nullif(e->>'valor_st', '')::numeric)
    FROM jsonb_array_elements(coalesce(p_itens, '[]'::jsonb)) e
   WHERE coalesce(nullif(e->>'quantidade', '')::numeric, 0) > 0
   GROUP BY (e->>'pedido_item_id')::uuid;

  -- SPEC-220: vínculo com o cliente — entrega futura -> reserva, com limitador por peça e por L.
  FOR v_vinc IN
    SELECT (e->>'produto_id')::uuid AS produto_id, (e->>'projeto_item_id')::uuid AS projeto_item_id,
           sum(round(coalesce(nullif(e->>'quantidade', '')::numeric, 0), 3)) AS quantidade
      FROM jsonb_array_elements(coalesce(p_vinculos, '[]'::jsonb)) e
     GROUP BY 1, 2
  LOOP
    CONTINUE WHEN v_vinc.quantidade = 0;
    IF v_vinc.quantidade < 0 THEN
      RAISE EXCEPTION 'Quantidade vinculada nao pode ser negativa.' USING ERRCODE = 'P0001';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.projeto_itens WHERE id = v_vinc.projeto_item_id AND produto_id = v_vinc.produto_id) THEN
      RAISE EXCEPTION 'Vinculo com um L de outra peca.' USING ERRCODE = 'P0001';
    END IF;
    SELECT q_entrega_futura INTO v_saldo FROM public.estoque_saldos_projeto_item
     WHERE projeto_item_id = v_vinc.projeto_item_id FOR UPDATE;
    IF coalesce(v_saldo, 0) < v_vinc.quantidade THEN
      RAISE EXCEPTION 'O L espera % em entrega futura e foi vinculado %.', coalesce(v_saldo, 0), v_vinc.quantidade
        USING ERRCODE = 'P0001';
    END IF;
    UPDATE public.estoque_saldos_projeto_item
       SET q_entrega_futura = q_entrega_futura - v_vinc.quantidade,
           q_reserva = q_reserva + v_vinc.quantidade,
           atualizado_em = now()
     WHERE projeto_item_id = v_vinc.projeto_item_id;
    INSERT INTO public.estoque_movimentos_projeto_item
      (projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por)
    VALUES (v_vinc.projeto_item_id, 'recebimento_para_reserva', v_vinc.quantidade, 'nota_fiscal_compra', v_nota_id,
            format('NF %s (pedido %s): entrega futura -> reserva', v_numero_nf, v_ped.numero), auth.uid());
    INSERT INTO public.nota_fiscal_compra_vinculos (nota_id, produto_id, projeto_item_id, quantidade, criado_por)
    VALUES (v_nota_id, v_vinc.produto_id, v_vinc.projeto_item_id, v_vinc.quantidade, auth.uid());
    v_reservado := v_reservado + v_vinc.quantidade;
  END LOOP;

  -- Limitador por peça: o vinculado não passa do que chegou nesta nota.
  PERFORM 1
    FROM (SELECT produto_id, sum(quantidade) q FROM public.nota_fiscal_compra_vinculos WHERE nota_id = v_nota_id GROUP BY 1) v
    LEFT JOIN (SELECT pi.produto_id, sum(x.quantidade) q
                 FROM public.nota_fiscal_compra_itens x JOIN public.pedido_compra_itens pi ON pi.id = x.pedido_item_id
                WHERE x.nota_id = v_nota_id GROUP BY 1) c ON c.produto_id = v.produto_id
   WHERE v.q > coalesce(c.q, 0) + 0.0001;
  IF FOUND THEN
    RAISE EXCEPTION 'Vinculado aos clientes mais do que chegou de uma peca.' USING ERRCODE = 'P0001';
  END IF;

  -- Pagamentos antecipados usados nesta nota
  FOR v_el IN SELECT * FROM jsonb_array_elements(coalesce(p_antecipacoes, '[]'::jsonb))
  LOOP
    v_qtd := round(coalesce(nullif(v_el->>'valor', '')::numeric, 0), 2);
    CONTINUE WHEN v_qtd = 0;
    IF v_qtd < 0 THEN
      RAISE EXCEPTION 'Valor da antecipacao nao pode ser negativo.' USING ERRCODE = 'P0001';
    END IF;
    SELECT * INTO v_pag FROM public.pagamentos_antecipados
     WHERE id = (v_el->>'pagamento_id')::uuid FOR UPDATE;
    IF v_pag.id IS NULL OR v_pag.cancelado_em IS NOT NULL THEN
      RAISE EXCEPTION 'Pagamento antecipado nao encontrado ou cancelado.' USING ERRCODE = 'P0001';
    END IF;
    IF NOT (v_pag.fornecedor_id IN (v_ped.fornecedor_id, v_forn) OR v_pag.pedido_compra_id = p_pedido_id) THEN
      RAISE EXCEPTION 'Pagamento antecipado de outro fornecedor.' USING ERRCODE = 'P0001';
    END IF;
    v_saldo := v_pag.valor - coalesce((SELECT sum(valor_aplicado) FROM public.pagamento_antecipado_vinculos
                                        WHERE pagamento_id = v_pag.id), 0);
    IF v_qtd > v_saldo + 0.001 THEN
      RAISE EXCEPTION 'Valor usado (%) maior que o saldo do pagamento antecipado (%).', v_qtd, v_saldo
        USING ERRCODE = 'P0001';
    END IF;
    INSERT INTO public.pagamento_antecipado_vinculos (pagamento_id, nota_id, valor_aplicado, criado_por)
    VALUES (v_pag.id, v_nota_id, v_qtd, auth.uid());
    v_aplicado := v_aplicado + v_qtd;
  END LOOP;

  -- Parcelas da nota (o restante depois da antecipação)
  FOR v_el IN SELECT * FROM jsonb_array_elements(coalesce(p_parcelas, '[]'::jsonb))
  LOOP
    v_qtd := round(coalesce(nullif(v_el->>'valor', '')::numeric, 0), 2);
    IF v_qtd <= 0 THEN
      RAISE EXCEPTION 'Toda parcela precisa ter valor maior que zero.' USING ERRCODE = 'P0001';
    END IF;
    IF nullif(v_el->>'data_vencimento', '') IS NULL THEN
      RAISE EXCEPTION 'Toda parcela precisa ter vencimento.' USING ERRCODE = 'P0001';
    END IF;
    v_n := v_n + 1;
    INSERT INTO public.nota_fiscal_compra_parcelas (nota_id, numero_parcela, data_vencimento, valor)
    VALUES (v_nota_id, v_n, (v_el->>'data_vencimento')::date, v_qtd);
    v_soma_parc := v_soma_parc + v_qtd;
  END LOOP;

  IF v_aplicado > v_valor + 0.001 THEN
    RAISE EXCEPTION 'Antecipacao usada (%) maior que o valor da nota (%).', v_aplicado, v_valor USING ERRCODE = 'P0001';
  END IF;
  IF abs(v_soma_parc + v_aplicado - v_valor) > 0.01 THEN
    RAISE EXCEPTION 'Parcelas (%) + antecipacao (%) nao batem com o valor da nota (%).', v_soma_parc, v_aplicado, v_valor
      USING ERRCODE = 'P0001';
  END IF;

  RETURN v_res || jsonb_build_object('nota_id', v_nota_id, 'parcelas', v_n, 'antecipacao_aplicada', v_aplicado,
                                     'fornecedor_trocado', v_forn IS DISTINCT FROM v_ped.fornecedor_id,
                                     'reservado', v_reservado);
END;
$function$;
REVOKE ALL ON FUNCTION public.registrar_entrada_nota_compra(uuid, jsonb, jsonb, jsonb, jsonb, uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.registrar_entrada_nota_compra(uuid, jsonb, jsonb, jsonb, jsonb, uuid, jsonb) TO authenticated;

-- 5. Cancelar a entrada desfaz o vínculo (reserva -> entrega futura) -------------------------------------------------
CREATE OR REPLACE FUNCTION public.cancelar_entrada_nota_compra(p_nota_id uuid, p_motivo text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_nota      record;
  v_ped       record;
  v_motivo    text := nullif(trim(coalesce(p_motivo, '')), '');
  v_itens     integer := 0;
  v_parcelas  integer := 0;
  v_antecip   numeric := 0;
  v_novo      text;
  v_vinc      record;
  v_reserva   numeric;
  v_desfeito  numeric := 0;
BEGIN
  IF NOT public.hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar') THEN
    RAISE EXCEPTION 'Sem permissao para cancelar entrada de nota fiscal.' USING ERRCODE = '42501';
  END IF;
  IF v_motivo IS NULL THEN
    RAISE EXCEPTION 'Informe o motivo do cancelamento.' USING ERRCODE = 'P0001';
  END IF;

  SELECT id, numero_nf, pedido_compra_id, cancelada_em INTO v_nota
    FROM public.notas_fiscais_compra WHERE id = p_nota_id FOR UPDATE;
  IF v_nota.id IS NULL THEN
    RAISE EXCEPTION 'Nota fiscal nao encontrada.' USING ERRCODE = 'P0001';
  END IF;
  IF v_nota.cancelada_em IS NOT NULL THEN
    RAISE EXCEPTION 'A nota % ja foi cancelada.', v_nota.numero_nf USING ERRCODE = 'P0001';
  END IF;

  -- SPEC-220: o que foi para a reserva volta para a entrega futura (se já foi separado, não dá para cancelar).
  FOR v_vinc IN SELECT * FROM public.nota_fiscal_compra_vinculos WHERE nota_id = p_nota_id
  LOOP
    SELECT q_reserva INTO v_reserva FROM public.estoque_saldos_projeto_item
     WHERE projeto_item_id = v_vinc.projeto_item_id FOR UPDATE;
    IF coalesce(v_reserva, 0) < v_vinc.quantidade THEN
      RAISE EXCEPTION 'Parte do que chegou nesta nota ja saiu da reserva (separacao). Estorne a separacao antes de cancelar.'
        USING ERRCODE = 'P0001';
    END IF;
    UPDATE public.estoque_saldos_projeto_item
       SET q_reserva = q_reserva - v_vinc.quantidade,
           q_entrega_futura = q_entrega_futura + v_vinc.quantidade,
           atualizado_em = now()
     WHERE projeto_item_id = v_vinc.projeto_item_id;
    INSERT INTO public.estoque_movimentos_projeto_item
      (projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por)
    VALUES (v_vinc.projeto_item_id, 'cancelamento', v_vinc.quantidade, 'nota_fiscal_compra', p_nota_id,
            format('Cancelada a NF %s: reserva -> entrega futura (%s)', v_nota.numero_nf, v_motivo), auth.uid());
    v_desfeito := v_desfeito + v_vinc.quantidade;
  END LOOP;
  DELETE FROM public.nota_fiscal_compra_vinculos WHERE nota_id = p_nota_id;

  IF v_nota.pedido_compra_id IS NOT NULL THEN
    SELECT id, numero, status INTO v_ped FROM public.pedidos_compra WHERE id = v_nota.pedido_compra_id FOR UPDATE;

    -- Devolve o que entrou por esta nota
    UPDATE public.pedido_compra_itens i
       SET qtd_recebida = greatest(0, i.qtd_recebida - x.quantidade)
      FROM public.nota_fiscal_compra_itens x
     WHERE x.nota_id = p_nota_id AND x.pedido_item_id = i.id;
    GET DIAGNOSTICS v_itens = ROW_COUNT;

    -- Status pelo que sobrou recebido (a entrada só acontece a partir de "aprovado")
    IF v_ped.status <> 'cancelado' THEN
      SELECT CASE WHEN bool_and(qtd_recebida >= quantidade) THEN 'recebido'
                  WHEN bool_or(qtd_recebida > 0) THEN 'parcialmente_recebido'
                  ELSE 'aprovado' END
        INTO v_novo FROM public.pedido_compra_itens WHERE pedido_id = v_ped.id;
      UPDATE public.pedidos_compra
         SET status = coalesce(v_novo, status),
             recebido_em = CASE WHEN v_novo = 'recebido' THEN recebido_em END,
             primeira_entrada_em = CASE WHEN v_novo = 'aprovado' THEN NULL ELSE primeira_entrada_em END,
             atualizado_em = now()
       WHERE id = v_ped.id;
    END IF;
  END IF;

  -- Parcelas da nota saem do A Pagar; antecipação usada volta a ter saldo
  DELETE FROM public.nota_fiscal_compra_parcelas WHERE nota_id = p_nota_id;
  GET DIAGNOSTICS v_parcelas = ROW_COUNT;
  SELECT coalesce(sum(valor_aplicado), 0) INTO v_antecip FROM public.pagamento_antecipado_vinculos WHERE nota_id = p_nota_id;
  DELETE FROM public.pagamento_antecipado_vinculos WHERE nota_id = p_nota_id;

  UPDATE public.notas_fiscais_compra
     SET cancelada_em = now(), cancelada_por = auth.uid(), motivo_cancelamento = v_motivo
   WHERE id = p_nota_id;

  RETURN jsonb_build_object('nota_id', p_nota_id, 'numero_nf', v_nota.numero_nf,
                            'pedido_numero', v_ped.numero, 'pedido_status', v_novo,
                            'itens_devolvidos', v_itens, 'parcelas_removidas', v_parcelas,
                            'antecipacao_devolvida', v_antecip, 'reserva_desfeita', v_desfeito);
END;
$function$;

-- 6. Espelho da entrada (para o Mateus): nota + itens + para quem foi -------------------------------------------------
CREATE OR REPLACE FUNCTION public.espelho_entrada_nota_compra(p_nota_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v jsonb;
BEGIN
  IF NOT (public.hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, NULL)
          OR public.pode_acessar_sistema('separacao-parcial') OR public.pode_acessar_sistema('logistica')) THEN
    RAISE EXCEPTION 'Sem permissao.' USING ERRCODE = '42501';
  END IF;
  SELECT jsonb_build_object(
    'nota', jsonb_build_object('id', n.id, 'numero_nf', n.numero_nf, 'chave_acesso', n.chave_acesso,
             'data_emissao', n.data_emissao, 'data_entrega', n.data_entrega, 'data_entrada', n.data_entrada,
             'valor', n.valor, 'valor_st', n.valor_st, 'valor_desconto', n.valor_desconto,
             'valor_despesas_acessorias', n.valor_despesas_acessorias, 'observacao', n.observacao,
             'cancelada_em', n.cancelada_em, 'criado_em', n.criado_em,
             'pedido_numero', p.numero, 'fornecedor_nome', f.nome,
             'fornecedor_documento', regexp_replace(coalesce(nullif(f.cnpj, ''), f.cpf_cnpj, ''), '\D', '', 'g'),
             'empresa_nome', e.nome, 'apropriacao', pc.nome, 'lancado_por', u.nome),
    'itens', coalesce((
      SELECT jsonb_agg(jsonb_build_object('produto_id', pi.produto_id, 'codigo', pr.codigo_produto,
               'produto', pr.nome, 'quantidade', x.quantidade, 'valor_unitario', x.valor_unitario,
               'valor_ipi', x.valor_ipi, 'valor_st', x.valor_st) ORDER BY pr.nome)
        FROM public.nota_fiscal_compra_itens x
        JOIN public.pedido_compra_itens pi ON pi.id = x.pedido_item_id
        JOIN public.produtos pr ON pr.id = pi.produto_id
       WHERE x.nota_id = n.id), '[]'::jsonb),
    'vinculos', coalesce((
      SELECT jsonb_agg(jsonb_build_object('produto_id', v.produto_id, 'quantidade', v.quantidade,
               'venda_numero', o.numero_venda, 'orcamento_numero', o.numero, 'cliente_nome', c.nome,
               'l_fixo', pit.l_fixo, 'projeto_codigo', prj.codigo) ORDER BY o.numero_venda, pit.l_fixo)
        FROM public.nota_fiscal_compra_vinculos v
        JOIN public.projeto_itens pit ON pit.id = v.projeto_item_id
        LEFT JOIN public.orcamentos o ON o.id = pit.orcamento_id
        LEFT JOIN public.projetos prj ON prj.id = pit.projeto_id
        LEFT JOIN public.contatos c ON c.id = coalesce(o.cliente_id, prj.cliente_id)
       WHERE v.nota_id = n.id), '[]'::jsonb),
    'parcelas', coalesce((
      SELECT jsonb_agg(jsonb_build_object('numero', np.numero_parcela, 'vencimento', np.data_vencimento,
               'valor', np.valor) ORDER BY np.numero_parcela)
        FROM public.nota_fiscal_compra_parcelas np WHERE np.nota_id = n.id), '[]'::jsonb),
    'antecipacao', coalesce((SELECT sum(valor_aplicado) FROM public.pagamento_antecipado_vinculos WHERE nota_id = n.id), 0))
    INTO v
    FROM public.notas_fiscais_compra n
    LEFT JOIN public.pedidos_compra p ON p.id = n.pedido_compra_id
    LEFT JOIN public.contatos f ON f.id = coalesce(n.fornecedor_id, p.fornecedor_id)
    LEFT JOIN public.empresas e ON e.id = coalesce(n.empresa_id, p.empresa_id)
    LEFT JOIN public.plano_de_contas pc ON pc.id = n.plano_contas_id
    LEFT JOIN public.usuarios u ON u.id = n.criado_por
   WHERE n.id = p_nota_id;
  IF v IS NULL THEN
    RAISE EXCEPTION 'Nota fiscal nao encontrada.' USING ERRCODE = 'P0001';
  END IF;
  RETURN v;
END;
$function$;
REVOKE ALL ON FUNCTION public.espelho_entrada_nota_compra(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.espelho_entrada_nota_compra(uuid) TO authenticated;

-- 7. Contas a Pagar: parcela da nota com a apropriação da nota (igual ao Connect: sub-grupo = pai, grupo = avô) ------
DO $$
DECLARE
  v_def text := pg_get_viewdef('public.vw_contas_pagar_pedidos_compra'::regclass, true);
BEGIN
  IF position('nota_compra' IN v_def) = 0 THEN
    RAISE EXCEPTION 'vw_contas_pagar_pedidos_compra nao tem o trecho das notas (SPEC-215).';
  END IF;
END $$;

CREATE OR REPLACE VIEW public.vw_contas_pagar_pedidos_compra AS
WITH consumo AS (
  SELECT p.id AS pedido_id,
         coalesce((SELECT sum(n.valor) FROM public.notas_fiscais_compra n
                    WHERE n.pedido_compra_id = p.id AND n.cancelada_em IS NULL), 0)
       + coalesce((SELECT sum(a.valor - coalesce((SELECT sum(x.valor_aplicado) FROM public.pagamento_antecipado_vinculos x
                                                   WHERE x.pagamento_id = a.id), 0))
                     FROM public.pagamentos_antecipados a
                    WHERE a.pedido_compra_id = p.id AND a.cancelado_em IS NULL), 0) AS consumido
    FROM public.pedidos_compra p
), parcelas AS (
  SELECT x.*,
         count(*) OVER (PARTITION BY x.pedido_id) AS total_parcelas,
         sum(x.valor) OVER (PARTITION BY x.pedido_id ORDER BY x.numero_parcela
                            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS acumulado
    FROM public.pedido_compra_parcelas x
   WHERE x.status <> 'cancelado'
), previsao AS (
  SELECT x.*, greatest(0, least(x.valor, x.acumulado - coalesce(k.consumido, 0)))::numeric(14,2) AS restante
    FROM parcelas x
    LEFT JOIN consumo k ON k.pedido_id = x.pedido_id
), nota_parcelas AS (
  SELECT np.*, count(*) OVER (PARTITION BY np.nota_id) AS total_parcelas
    FROM public.nota_fiscal_compra_parcelas np
)
SELECT
  ('pc:' || x.id::text)                                        AS id,
  'despesa'::text                                              AS tipo,
  format('Pedido de compra %s — %s (parcela %s/%s)', p.numero, coalesce(c.nome, 'fornecedor'),
         x.numero_parcela, x.total_parcelas)                   AS descricao,
  'PEDIDOS DE COMPRA'::text                                    AS desc_sub_grupo,
  'DESPESAS'::text                                             AS desc_grupo,
  'despesa_operacional'::text                                  AS natureza,
  0                                                            AS status_pago,
  NULL::date                                                   AS dt_pagamento,
  x.data_vencimento                                            AS dt_vencimento,
  p.data_emissao                                               AS dt_emissao,
  0::numeric                                                   AS vl_pago,
  x.restante::numeric                                          AS vl_parcela,
  0::numeric                                                   AS vl_desconto,
  p.empresa_id,
  NULL::integer                                                AS cod_duplicata,
  'variavel'::text                                             AS tipo_custo,
  p.perfil,
  'pedido_compra'::text                                        AS origem,
  p.id                                                         AS pedido_compra_id,
  p.numero                                                     AS pedido_numero,
  p.status                                                     AS pedido_status
FROM previsao x
JOIN public.pedidos_compra p ON p.id = x.pedido_id
LEFT JOIN public.contatos c ON c.id = p.fornecedor_id
WHERE p.status IN ('aprovado', 'parcialmente_recebido')
  AND p.numero NOT LIKE 'PC-LEGADO-%'
  AND x.status IN ('pendente', 'atrasado')
  AND x.data_vencimento IS NOT NULL
  AND x.restante > 0
  AND (SELECT public.pode_acessar_sistema('dashboard-financeiro'::text))

UNION ALL

SELECT
  ('nf:' || np.id::text),
  'despesa'::text,
  format('Nota %s — %s (parcela %s/%s, pedido %s)', n.numero_nf, coalesce(c.nome, 'fornecedor'),
         np.numero_parcela, np.total_parcelas, p.numero),
  coalesce(pc2.nome, pc3.nome, 'PEDIDOS DE COMPRA'),
  coalesce(pc1.nome, pc2.nome, 'DESPESAS'),
  'despesa_operacional'::text,
  0,
  NULL::date,
  np.data_vencimento,
  coalesce(n.data_emissao, p.data_emissao),
  0::numeric,
  np.valor::numeric,
  0::numeric,
  coalesce(n.empresa_id, p.empresa_id),
  NULL::integer,
  'variavel'::text,
  p.perfil,
  'nota_compra'::text,
  p.id,
  p.numero,
  p.status
FROM nota_parcelas np
JOIN public.notas_fiscais_compra n ON n.id = np.nota_id
JOIN public.pedidos_compra p ON p.id = n.pedido_compra_id
LEFT JOIN public.contatos c ON c.id = coalesce(n.fornecedor_id, p.fornecedor_id)
LEFT JOIN public.plano_de_contas pc3 ON pc3.id = n.plano_contas_id
LEFT JOIN public.plano_de_contas pc2 ON pc2.id = pc3.parent_id
LEFT JOIN public.plano_de_contas pc1 ON pc1.id = pc2.parent_id
WHERE p.status <> 'cancelado'
  AND n.cancelada_em IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.negociacoes g
     WHERE g.tipo = 'despesa'
       AND g.empresa_id = coalesce(n.empresa_id, p.empresa_id)
       AND g.num_nota = nullif(regexp_replace(n.numero_nf, '\D', '', 'g'), '')::numeric
       AND abs(coalesce((SELECT sum(t.vl_parcela) FROM public.transacoes t
                          WHERE t.negociacao_id = g.id AND t.status_pago <> 2), 0) - n.valor) <= 1)
  AND (SELECT public.pode_acessar_sistema('dashboard-financeiro'::text))

UNION ALL

SELECT
  ('pa:' || a.id::text),
  'despesa'::text,
  format('Pagamento antecipado — %s%s', coalesce(c.nome, 'fornecedor'),
         CASE WHEN p.numero IS NOT NULL THEN ' (pedido ' || p.numero || ')' ELSE '' END),
  'PAGAMENTO ANTECIPADO'::text,
  'DESPESAS'::text,
  'despesa_operacional'::text,
  1,
  a.data_pagamento,
  a.data_pagamento,
  a.data_pagamento,
  a.valor::numeric,
  a.valor::numeric,
  0::numeric,
  a.empresa_id,
  NULL::integer,
  'variavel'::text,
  p.perfil,
  'pagamento_antecipado'::text,
  p.id,
  p.numero,
  p.status
FROM public.pagamentos_antecipados a
LEFT JOIN public.pedidos_compra p ON p.id = a.pedido_compra_id
LEFT JOIN public.contatos c ON c.id = a.fornecedor_id
WHERE a.cancelado_em IS NULL
  AND (SELECT public.pode_acessar_sistema('dashboard-financeiro'::text));

COMMIT;
