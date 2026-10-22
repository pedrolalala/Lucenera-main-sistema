-- Rollback SPEC-222 (migration 235): funções de volta como estavam; remove a RPC nova e a coluna.
-- Sem BEGIN/COMMIT.

DROP FUNCTION IF EXISTS public.voltar_pedido_compra_para_edicao(uuid, text);

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
  v_est       record;
  v_tirado    numeric := 0;
BEGIN
  IF NOT public.hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar') THEN
    RAISE EXCEPTION 'Sem permissao para cancelar entrada de nota fiscal.' USING ERRCODE = '42501';
  END IF;
  IF v_motivo IS NULL THEN
    RAISE EXCEPTION 'Informe o motivo do cancelamento.' USING ERRCODE = 'P0001';
  END IF;

  SELECT id, numero_nf, pedido_compra_id, cancelada_em, estoque_somado_em INTO v_nota
    FROM public.notas_fiscais_compra WHERE id = p_nota_id FOR UPDATE;
  IF v_nota.id IS NULL THEN
    RAISE EXCEPTION 'Nota fiscal nao encontrada.' USING ERRCODE = 'P0001';
  END IF;
  IF v_nota.cancelada_em IS NOT NULL THEN
    RAISE EXCEPTION 'A nota % ja foi cancelada.', v_nota.numero_nf USING ERRCODE = 'P0001';
  END IF;

  -- SPEC-222: tira do estoque físico o que esta nota somou (notas anteriores à 234 não somaram nada).
  IF v_nota.estoque_somado_em IS NOT NULL THEN
    FOR v_est IN
      SELECT pi.produto_id, p.codigo_produto, sum(x.quantidade) AS quantidade
        FROM public.nota_fiscal_compra_itens x
        JOIN public.pedido_compra_itens pi ON pi.id = x.pedido_item_id
        JOIN public.produtos p ON p.id = pi.produto_id
       WHERE x.nota_id = p_nota_id
       GROUP BY pi.produto_id, p.codigo_produto
    LOOP
      SELECT quantidade INTO v_reserva FROM public.estoque_itens
       WHERE produto_id = v_est.produto_id AND local = 'Estoque'::public.estoque_local FOR UPDATE;
      IF coalesce(v_reserva, 0) < v_est.quantidade THEN
        RAISE EXCEPTION 'A peca % tem % no estoque e esta nota deu entrada em %: parte ja saiu. Acerte o estoque antes de cancelar.',
          v_est.codigo_produto, coalesce(v_reserva, 0), v_est.quantidade USING ERRCODE = 'P0001';
      END IF;
      UPDATE public.estoque_itens
         SET quantidade = quantidade - v_est.quantidade, atualizado_em = now()
       WHERE produto_id = v_est.produto_id AND local = 'Estoque'::public.estoque_local;
      v_tirado := v_tirado + v_est.quantidade;
    END LOOP;
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
                            'antecipacao_devolvida', v_antecip, 'reserva_desfeita', v_desfeito,
                            'estoque_retirado', v_tirado);
END;
$function$;

CREATE OR REPLACE FUNCTION public._lucenera_datas_parcelas(p_condicoes text, p_prazo_dias integer[], p_base date)
 RETURNS date[]
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
DECLARE
  v_txt    text := trim(coalesce(p_condicoes, ''));
  v_grupos text[];
  v_g      text;
  v_n      text[];
  v_eh_data boolean := false;
  v_datas  date[] := ARRAY[]::date[];
  v_d      date;
  v_ano    int;
  v_dias   integer[];
BEGIN
  -- Grupos separados por vírgula, ponto e vírgula, espaço ou " e ".
  -- É data quando todo grupo é "dd/mm" ou "dd/mm/aaaa" e (tem ano, ou há mais de um grupo, ou o mês
  -- é menor que o dia: "15/11"). "30/60/90" e "30/60" continuam sendo dias.
  v_grupos := regexp_split_to_array(regexp_replace(lower(v_txt), '\s+e\s+', ',', 'g'), '[,;\s]+');
  v_grupos := array_remove(v_grupos, '');
  IF coalesce(array_length(v_grupos, 1), 0) > 0 THEN
    v_eh_data := true;
    FOREACH v_g IN ARRAY v_grupos LOOP
      IF v_g !~ '^\d{1,2}/\d{1,2}(/\d{2,4})?$' THEN v_eh_data := false; EXIT; END IF;
      v_n := regexp_split_to_array(v_g, '/');
      IF v_n[2]::int < 1 OR v_n[2]::int > 12 OR v_n[1]::int < 1 OR v_n[1]::int > 31 THEN v_eh_data := false; EXIT; END IF;
    END LOOP;
    IF v_eh_data AND array_length(v_grupos, 1) = 1 AND v_grupos[1] !~ '/\d{2,4}$' THEN
      v_n := regexp_split_to_array(v_grupos[1], '/');
      v_eh_data := v_n[2]::int < v_n[1]::int;
    END IF;
  END IF;

  IF v_eh_data THEN
    FOREACH v_g IN ARRAY v_grupos LOOP
      v_n := regexp_split_to_array(v_g, '/');
      v_ano := CASE WHEN v_n[3] IS NULL THEN extract(year FROM p_base)::int
                    WHEN length(v_n[3]) = 2 THEN 2000 + v_n[3]::int
                    ELSE v_n[3]::int END;
      v_d := make_date(v_ano, v_n[2]::int, v_n[1]::int);
      IF v_n[3] IS NULL AND v_d < p_base THEN
        v_d := (v_d + interval '1 year')::date;
      END IF;
      v_datas := v_datas || v_d;
    END LOOP;
    RETURN v_datas;
  END IF;

  v_dias := public._lucenera_parse_prazo_pagamento(p_condicoes, p_prazo_dias);
  SELECT coalesce(array_agg(p_base + d ORDER BY ord), ARRAY[]::date[]) INTO v_datas
    FROM unnest(v_dias) WITH ORDINALITY AS t(d, ord);
  RETURN v_datas;
END;
$function$;

CREATE OR REPLACE FUNCTION public.gerar_parcelas_pedido_compra(p_pedido_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_pedido          public.pedidos_compra%ROWTYPE;
    v_datas           date[];
    v_qtd_parcelas    integer;
    v_valor_base      numeric(12,2);
    v_valor_acumulado numeric(12,2) := 0;
    v_valor_parcela   numeric(12,2);
    v_i               integer;
    v_criadas         integer := 0;
BEGIN
    SELECT * INTO v_pedido FROM public.pedidos_compra WHERE id = p_pedido_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pedido de compra % nao encontrado.', p_pedido_id USING ERRCODE = 'P0001';
    END IF;

    IF v_pedido.valor_total IS NULL OR v_pedido.valor_total <= 0 THEN
        RAISE EXCEPTION 'Pedido % nao possui valor_total valido.', v_pedido.numero USING ERRCODE = 'P0001';
    END IF;

    -- SPEC-209 C1: dias ("30/60/90") contados da data do pedido, ou datas digitadas ("15/11, 15/12")
    v_datas := public._lucenera_datas_parcelas(
        v_pedido.condicoes_pagamento, v_pedido.prazo_pagamento_dias, COALESCE(v_pedido.data_emissao, CURRENT_DATE)
    );
    v_qtd_parcelas := COALESCE(array_length(v_datas, 1), 0);

    IF v_qtd_parcelas = 0 THEN
        RAISE EXCEPTION 'Nao foi possivel interpretar condicoes_pagamento/prazo_pagamento_dias do pedido %.', v_pedido.numero
            USING ERRCODE = 'P0001';
    END IF;

    -- Idempotente: nao duplica se ja houver parcelas geradas
    IF EXISTS (SELECT 1 FROM public.pedido_compra_parcelas WHERE pedido_id = p_pedido_id) THEN
        RAISE EXCEPTION 'Pedido % ja possui parcelas geradas.', v_pedido.numero USING ERRCODE = 'P0001';
    END IF;

    v_valor_base := round(v_pedido.valor_total / v_qtd_parcelas, 2);

    FOR v_i IN 1..v_qtd_parcelas LOOP
        v_valor_parcela := CASE
            WHEN v_i < v_qtd_parcelas THEN v_valor_base
            ELSE v_pedido.valor_total - v_valor_acumulado
        END;

        INSERT INTO public.pedido_compra_parcelas (
            pedido_id, numero_parcela, valor, data_vencimento, status
        ) VALUES (
            p_pedido_id, v_i, v_valor_parcela,
            v_datas[v_i],
            'pendente'
        );

        v_valor_acumulado := v_valor_acumulado + v_valor_parcela;
        v_criadas := v_criadas + 1;
    END LOOP;

    RETURN jsonb_build_object('pedido_id', p_pedido_id, 'parcelas_criadas', v_criadas);
END;
$function$;

CREATE OR REPLACE FUNCTION public.aprovar_pedido_compra(p_pedido_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_status   text;
  v_numero   text;
  v_cond     text;
  v_parcelas integer;
BEGIN
  IF NOT hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar') THEN
    RAISE EXCEPTION 'Sem permissao para aprovar pedido de compra.' USING ERRCODE = '42501';
  END IF;

  SELECT status, numero, condicoes_pagamento INTO v_status, v_numero, v_cond
    FROM public.pedidos_compra WHERE id = p_pedido_id FOR UPDATE;
  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Pedido de compra % nao encontrado.', p_pedido_id USING ERRCODE = 'P0001';
  END IF;
  IF v_status <> 'aguardando_aprovar' THEN
    RAISE EXCEPTION 'So pedido em "Aguardando aprovar" pode ser aprovado (pedido % esta em %).', v_numero, v_status
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.pedidos_compra
     SET status = 'aprovado', aprovado_por = auth.uid(), aprovado_em = now(), atualizado_em = now()
   WHERE id = p_pedido_id;

  SELECT count(*) INTO v_parcelas FROM public.pedido_compra_parcelas
   WHERE pedido_id = p_pedido_id AND status <> 'cancelado';
  IF v_parcelas = 0 AND NULLIF(trim(coalesce(v_cond, '')), '') IS NOT NULL THEN
    BEGIN
      v_parcelas := (public.gerar_parcelas_pedido_compra(p_pedido_id)->>'parcelas_criadas')::integer;
    EXCEPTION WHEN OTHERS THEN
      v_parcelas := 0;
    END;
  END IF;

  RETURN jsonb_build_object('pedido_id', p_pedido_id, 'numero', v_numero, 'status', 'aprovado',
                            'parcelas', v_parcelas);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.gerar_parcelas_pedido_compra(uuid) TO PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public._lucenera_datas_parcelas(text, integer[], date) TO PUBLIC, anon;

ALTER TABLE public.usuarios DROP COLUMN IF EXISTS copias_pedido_compra;
