-- SPEC-247: importar pedidos da Connect (planilha PedidoCompra, so cabecalho) pela tela do Compras.
-- Funcao unica: p_aplicar = false devolve so a previa; true grava. Nao cria itens, parcelas nem Contas a Pagar.
-- Sem BEGIN/COMMIT aqui dentro (quem aplica controla a transacao).

CREATE OR REPLACE FUNCTION public.importar_pedidos_connect_cabecalho(
  p_pedidos jsonb,
  p_aplicar boolean DEFAULT false
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_uid        uuid := auth.uid();
  v_item       jsonb;
  v_cod        integer;
  v_nome       text;
  v_valor      numeric(12,2);
  v_data       date;
  v_forn_id    uuid;
  v_forn_nome  text;
  v_forn_qtd   integer;
  v_vistos     integer[] := '{}';
  v_novos      jsonb := '[]'::jsonb;
  v_existem    jsonb := '[]'::jsonb;
  v_sem_forn   jsonb := '[]'::jsonb;
  v_inseridos  integer := 0;
  v_linhas     integer;
  v_obs        constant text := 'Importado da Connect (planilha) - so cabecalho, sem itens.';
BEGIN
  IF v_uid IS NULL OR NOT hub_pode_executar(v_uid, 'necessidade-de-compra', NULL, 'criar') THEN
    RAISE EXCEPTION 'Sem permissao para importar pedido de compra.' USING ERRCODE = '42501';
  END IF;

  IF p_pedidos IS NULL OR jsonb_typeof(p_pedidos) <> 'array' OR jsonb_array_length(p_pedidos) = 0 THEN
    RAISE EXCEPTION 'A planilha nao trouxe nenhum pedido.' USING ERRCODE = 'P0001';
  END IF;
  IF jsonb_array_length(p_pedidos) > 500 THEN
    RAISE EXCEPTION 'Muitos pedidos de uma vez (maximo 500).' USING ERRCODE = 'P0001';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_pedidos) LOOP
    BEGIN
      v_cod   := (v_item->>'codigo_pedido')::integer;
      v_nome  := btrim(coalesce(v_item->>'nm_fornecedor', ''));
      v_valor := round((v_item->>'vl_nota')::numeric, 2);
      v_data  := (v_item->>'emissao_pedido')::date;
    EXCEPTION WHEN others THEN
      RAISE EXCEPTION 'Linha invalida na planilha: %', left(v_item::text, 200) USING ERRCODE = 'P0001';
    END;
    IF v_cod IS NULL OR v_cod <= 0 OR v_nome = '' OR v_valor IS NULL OR v_valor < 0 OR v_data IS NULL THEN
      RAISE EXCEPTION 'Linha invalida na planilha: %', left(v_item::text, 200) USING ERRCODE = 'P0001';
    END IF;

    -- repetido na propria planilha: conta uma vez
    IF v_cod = ANY (v_vistos) THEN
      CONTINUE;
    END IF;
    v_vistos := v_vistos || v_cod;

    -- ja existe como "N", "N CONNECT" ou "PC-LEGADO-N"
    IF EXISTS (
      SELECT 1 FROM public.pedidos_compra
       WHERE numero IN (v_cod::text, v_cod::text || ' CONNECT', 'PC-LEGADO-' || v_cod::text)
    ) THEN
      v_existem := v_existem || to_jsonb(v_cod);
      CONTINUE;
    END IF;

    -- fornecedor pelo nome normalizado (contatos.codigo_legado e de CLIENTE, nao serve)
    SELECT x.id, x.nome, x.total
      INTO v_forn_id, v_forn_nome, v_forn_qtd
      FROM (
        SELECT c.id, c.nome,
               count(*) OVER () AS total,
               (SELECT count(*) FROM public.pedidos_compra p WHERE p.fornecedor_id = c.id) AS pedidos
          FROM public.contatos c
         WHERE c.tipo = 'fornecedor'
           AND btrim(regexp_replace(regexp_replace(upper(public.unaccent(c.nome)), '[^A-Z0-9 ]', ' ', 'g'), '\s+', ' ', 'g'))
             = btrim(regexp_replace(regexp_replace(upper(public.unaccent(v_nome)),  '[^A-Z0-9 ]', ' ', 'g'), '\s+', ' ', 'g'))
         ORDER BY 4 DESC, c.id
         LIMIT 1
      ) x;

    IF v_forn_id IS NULL THEN
      v_sem_forn := v_sem_forn || jsonb_build_object('codigo', v_cod, 'fornecedor', v_nome, 'valor', v_valor);
      CONTINUE;
    END IF;

    v_novos := v_novos || jsonb_build_object(
      'codigo', v_cod, 'fornecedor', v_forn_nome, 'valor', v_valor,
      'emissao', v_data, 'duplicado', coalesce(v_forn_qtd, 1) > 1
    );

    IF p_aplicar THEN
      INSERT INTO public.pedidos_compra
        (numero, fornecedor_id, status, data_emissao, valor_total, observacao, criado_por, aprovado_por, aprovado_em)
      VALUES
        (v_cod::text || ' CONNECT', v_forn_id, 'aprovado', v_data, v_valor, v_obs, v_uid, v_uid, now())
      ON CONFLICT (numero) DO NOTHING;
      GET DIAGNOSTICS v_linhas = ROW_COUNT;
      v_inseridos := v_inseridos + v_linhas;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'aplicado', p_aplicar,
    'inseridos', v_inseridos,
    'novos', v_novos,
    'ja_existem', v_existem,
    'sem_fornecedor', v_sem_forn
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.importar_pedidos_connect_cabecalho(jsonb, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.importar_pedidos_connect_cabecalho(jsonb, boolean) TO authenticated;

COMMENT ON FUNCTION public.importar_pedidos_connect_cabecalho(jsonb, boolean) IS
  'SPEC-247: importa pedidos da Connect (so cabecalho) para pedidos_compra. p_aplicar=false = previa. Nao gera itens, parcelas nem Contas a Pagar.';
