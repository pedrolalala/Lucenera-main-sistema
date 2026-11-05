-- SPEC-247 fase 2: grava o pedido de compra lido do PDF da Connect (cabecalho + ITENS), com previa.
-- Tres casos: (a) pedido "N CONNECT" ja existe SEM itens (os da planilha) -> completa; (b) nao existe -> cria;
-- (c) ja tem itens -> nao grava. Peca nao cadastrada (codigo_produto) bloqueia tudo (nada e gravado).
-- Nao gera parcelas nem Contas a Pagar (o financeiro vem da Connect, SPEC-245).
-- Sem BEGIN/COMMIT aqui dentro (quem aplica controla a transacao).

CREATE OR REPLACE FUNCTION public.importar_pedido_connect_pdf(
  p_pedido jsonb,
  p_aplicar boolean DEFAULT false
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_uid          uuid := auth.uid();
  v_num          integer;
  v_forn_txt     text;
  v_emp_txt      text;
  v_emissao      date;
  v_entrega      date;
  v_pagto        text;
  v_total        numeric(12,2);
  v_itens        jsonb;
  v_it           jsonb;
  v_cod          integer;
  v_qtd          numeric;
  v_unit         numeric;
  v_ref_pdf      text;
  v_prod_id      uuid;
  v_prod_ref     text;
  v_soma         numeric := 0;
  v_faltam       jsonb := '[]'::jsonb;
  v_avisos       jsonb := '[]'::jsonb;
  v_pedido_id    uuid;
  v_ped_forn     uuid;
  v_ped_valor    numeric;
  v_ped_status   text;
  v_forn_id      uuid;
  v_forn_nome    text;
  v_forn_qtd     integer;
  v_emp_id       uuid;
  v_n_itens      integer;
  v_acao         text;
  v_bloqueado    boolean := false;
  v_inseridos    integer := 0;
  v_norm_forn    text;
  v_obs          constant text := 'Importado da Connect (PDF do pedido).';
BEGIN
  IF v_uid IS NULL OR NOT hub_pode_executar(v_uid, 'necessidade-de-compra', NULL, 'criar') THEN
    RAISE EXCEPTION 'Sem permissao para importar pedido de compra.' USING ERRCODE = '42501';
  END IF;

  BEGIN
    v_num      := (p_pedido->>'numero')::integer;
    v_forn_txt := btrim(coalesce(p_pedido->>'fornecedor', ''));
    v_emp_txt  := btrim(coalesce(p_pedido->>'empresa', ''));
    v_emissao  := (p_pedido->>'emissao')::date;
    v_entrega  := nullif(p_pedido->>'entrega', '')::date;
    v_pagto    := nullif(btrim(coalesce(p_pedido->>'pagamento', '')), '');
    v_total    := round((p_pedido->>'total')::numeric, 2);
    v_itens    := p_pedido->'itens';
  EXCEPTION WHEN others THEN
    RAISE EXCEPTION 'Dados do pedido invalidos.' USING ERRCODE = 'P0001';
  END;
  IF v_num IS NULL OR v_num <= 0 OR v_forn_txt = '' OR v_emissao IS NULL
     OR v_itens IS NULL OR jsonb_typeof(v_itens) <> 'array'
     OR jsonb_array_length(v_itens) = 0 OR jsonb_array_length(v_itens) > 300 THEN
    RAISE EXCEPTION 'Dados do pedido invalidos (numero, fornecedor, emissao e de 1 a 300 itens).' USING ERRCODE = 'P0001';
  END IF;

  -- valida itens, soma e confere se cada codigo_produto existe
  FOR v_it IN SELECT * FROM jsonb_array_elements(v_itens) LOOP
    BEGIN
      v_cod     := (v_it->>'codigo_produto')::integer;
      v_qtd     := (v_it->>'quantidade')::numeric;
      v_unit    := (v_it->>'valor_unitario')::numeric;
      v_ref_pdf := nullif(btrim(coalesce(v_it->>'referencia', '')), '');
    EXCEPTION WHEN others THEN
      RAISE EXCEPTION 'Item invalido: %', left(v_it::text, 200) USING ERRCODE = 'P0001';
    END;
    IF v_cod IS NULL OR v_qtd IS NULL OR v_qtd <= 0 OR v_unit IS NULL OR v_unit < 0 THEN
      RAISE EXCEPTION 'Item invalido: %', left(v_it::text, 200) USING ERRCODE = 'P0001';
    END IF;
    v_soma := v_soma + round(v_qtd * v_unit, 2);

    SELECT p.id, p.referencia INTO v_prod_id, v_prod_ref FROM public.produtos p WHERE p.codigo_produto = v_cod;
    IF v_prod_id IS NULL THEN
      v_faltam := v_faltam || jsonb_build_object('codigo', v_cod, 'referencia', v_ref_pdf);
    ELSIF v_ref_pdf IS NOT NULL AND v_prod_ref IS NOT NULL
          AND upper(btrim(v_prod_ref)) <> upper(v_ref_pdf) THEN
      v_avisos := v_avisos || to_jsonb(format('Peca %s: referencia do PDF (%s) difere do cadastro (%s).', v_cod, v_ref_pdf, v_prod_ref));
    END IF;
  END LOOP;

  IF v_total IS NOT NULL AND abs(v_soma - v_total) > 0.05 THEN
    v_avisos := v_avisos || to_jsonb(format('A soma dos itens (%s) nao bate com o Total da Nota (%s).', v_soma, v_total));
  END IF;

  -- empresa (LUCE NERA = MANOELLA, regra fixa da Connect)
  IF v_emp_txt <> '' THEN
    SELECT e.id INTO v_emp_id FROM public.empresas e
     WHERE upper(public.unaccent(btrim(e.nome))) =
           CASE WHEN upper(public.unaccent(v_emp_txt)) = 'LUCE NERA' THEN 'MANOELLA' ELSE upper(public.unaccent(v_emp_txt)) END
     LIMIT 1;
    IF v_emp_id IS NULL THEN
      v_avisos := v_avisos || to_jsonb(format('Empresa "%s" nao encontrada; o pedido fica sem empresa.', v_emp_txt));
    END IF;
  END IF;

  v_norm_forn := btrim(regexp_replace(regexp_replace(upper(public.unaccent(v_forn_txt)), '[^A-Z0-9 ]', ' ', 'g'), '\s+', ' ', 'g'));

  -- pedido ja existe? ("N CONNECT", "N" ou "PC-LEGADO-N")
  SELECT p.id, p.fornecedor_id, p.valor_total, p.status
    INTO v_pedido_id, v_ped_forn, v_ped_valor, v_ped_status
    FROM public.pedidos_compra p
   WHERE p.numero IN (v_num::text || ' CONNECT', v_num::text, 'PC-LEGADO-' || v_num::text)
   ORDER BY (p.numero = v_num::text || ' CONNECT') DESC
   LIMIT 1
   FOR UPDATE;

  IF v_pedido_id IS NOT NULL THEN
    SELECT count(*) INTO v_n_itens FROM public.pedido_compra_itens WHERE pedido_id = v_pedido_id;
    IF v_n_itens > 0 THEN
      v_acao := 'ja_tem_itens';
      v_bloqueado := true;
    ELSIF v_ped_status IN ('cancelado', 'recebido') THEN
      v_acao := 'pedido_fechado';
      v_bloqueado := true;
    ELSE
      v_acao := 'completar';
      SELECT c.nome INTO v_forn_nome FROM public.contatos c WHERE c.id = v_ped_forn;
      IF btrim(regexp_replace(regexp_replace(upper(public.unaccent(coalesce(v_forn_nome, ''))), '[^A-Z0-9 ]', ' ', 'g'), '\s+', ' ', 'g')) <> v_norm_forn THEN
        v_avisos := v_avisos || to_jsonb(format('Fornecedor do PDF (%s) difere do fornecedor do pedido (%s).', v_forn_txt, v_forn_nome));
      END IF;
      IF v_ped_valor IS NOT NULL AND v_total IS NOT NULL AND abs(v_ped_valor - v_total) > 0.05 THEN
        v_avisos := v_avisos || to_jsonb(format('Valor do pedido (%s) difere do Total da Nota do PDF (%s); o valor do pedido nao e alterado.', v_ped_valor, v_total));
      END IF;
    END IF;
  ELSE
    v_acao := 'criar';
    SELECT x.id, x.nome, x.total INTO v_forn_id, v_forn_nome, v_forn_qtd
      FROM (
        SELECT c.id, c.nome, count(*) OVER () AS total,
               (SELECT count(*) FROM public.pedidos_compra p WHERE p.fornecedor_id = c.id) AS pedidos
          FROM public.contatos c
         WHERE c.tipo = 'fornecedor'
           AND btrim(regexp_replace(regexp_replace(upper(public.unaccent(c.nome)), '[^A-Z0-9 ]', ' ', 'g'), '\s+', ' ', 'g')) = v_norm_forn
         ORDER BY 4 DESC, c.id
         LIMIT 1
      ) x;
    IF v_forn_id IS NULL THEN
      v_acao := 'sem_fornecedor';
      v_bloqueado := true;
    ELSIF coalesce(v_forn_qtd, 1) > 1 THEN
      v_avisos := v_avisos || to_jsonb(format('Fornecedor %s tem cadastro duplicado; usado o que ja tem mais pedidos.', v_forn_nome));
    END IF;
  END IF;

  IF jsonb_array_length(v_faltam) > 0 THEN
    v_bloqueado := true;
  END IF;

  IF p_aplicar AND NOT v_bloqueado THEN
    IF v_acao = 'criar' THEN
      INSERT INTO public.pedidos_compra
        (numero, fornecedor_id, status, data_emissao, data_prevista_entrega, condicoes_pagamento, valor_total,
         observacao, empresa_id, criado_por, aprovado_por, aprovado_em)
      VALUES
        (v_num::text || ' CONNECT', v_forn_id, 'aprovado', v_emissao, v_entrega, v_pagto, coalesce(v_total, v_soma),
         v_obs, v_emp_id, v_uid, v_uid, now())
      RETURNING id INTO v_pedido_id;
    ELSE
      -- completar: so preenche o que esta vazio, nunca troca valor/fornecedor/status
      UPDATE public.pedidos_compra SET
        data_prevista_entrega = coalesce(data_prevista_entrega, v_entrega),
        condicoes_pagamento   = coalesce(condicoes_pagamento, v_pagto),
        empresa_id            = coalesce(empresa_id, v_emp_id),
        valor_total           = coalesce(valor_total, v_total, v_soma),
        atualizado_em         = now()
      WHERE id = v_pedido_id;
    END IF;

    INSERT INTO public.pedido_compra_itens (pedido_id, produto_id, quantidade, custo_unitario)
    SELECT v_pedido_id, p.id, (i->>'quantidade')::numeric, (i->>'valor_unitario')::numeric
      FROM jsonb_array_elements(v_itens) i
      JOIN public.produtos p ON p.codigo_produto = (i->>'codigo_produto')::integer;
    GET DIAGNOSTICS v_inseridos = ROW_COUNT;
  END IF;

  RETURN jsonb_build_object(
    'aplicado', p_aplicar AND NOT v_bloqueado,
    'acao', v_acao,
    'bloqueado', v_bloqueado,
    'numero', v_num::text || ' CONNECT',
    'pedido_id', v_pedido_id,
    'fornecedor', coalesce(v_forn_nome, v_forn_txt),
    'itens_pdf', jsonb_array_length(v_itens),
    'itens_inseridos', v_inseridos,
    'soma_itens', v_soma,
    'total_pdf', v_total,
    'valor_pedido', v_ped_valor,
    'pecas_nao_cadastradas', v_faltam,
    'avisos', v_avisos
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.importar_pedido_connect_pdf(jsonb, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.importar_pedido_connect_pdf(jsonb, boolean) TO authenticated;

COMMENT ON FUNCTION public.importar_pedido_connect_pdf(jsonb, boolean) IS
  'SPEC-247 fase 2: grava o pedido do PDF da Connect (completa "N CONNECT" sem itens ou cria). p_aplicar=false = previa. Nao gera parcelas nem Contas a Pagar.';
