-- rollback SPEC-268: volta ao teste de role antigo
BEGIN;

CREATE OR REPLACE FUNCTION public.criar_produto_orcamento(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user_role text;
  v_nome text;
  v_marca_id uuid;
  v_categoria_id uuid;
  v_fornecedor_id uuid;
  v_produto public.produtos%ROWTYPE;
BEGIN
  IF p_payload IS NULL THEN
    RAISE EXCEPTION 'Payload do produto é obrigatório.' USING ERRCODE = 'P0001';
  END IF;

  IF COALESCE(auth.role(), '') <> 'service_role' THEN
    SELECT u.role::text INTO v_user_role
    FROM public.usuarios u
    WHERE u.id = auth.uid()
      AND COALESCE(u.ativo, true) = true;

    IF v_user_role IS NULL THEN
      RAISE EXCEPTION 'Usuário não autenticado ou sem cadastro operacional.'
        USING ERRCODE = 'P0001';
    END IF;

    IF v_user_role NOT IN ('admin', 'gerente', 'operador') THEN
      RAISE EXCEPTION 'Permissão negada para criar produto. Role atual: %', v_user_role
        USING ERRCODE = 'P0001';
    END IF;

    -- SPEC-069: camada adicional sobre a matriz de papéis granular — quem
    -- tem "Editar sem cadastrar" (ex.: equipe_projetos) passa no role legado
    -- mas não tem a ação 'criar', então é bloqueado aqui.
    IF NOT (
      public.hub_pode_executar(auth.uid(), 'cadastro', NULL, 'criar')
      OR public.hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'criar')
    ) THEN
      RAISE EXCEPTION 'Permissão negada para criar produto (matriz de papéis).'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  v_nome := NULLIF(btrim(COALESCE(p_payload->>'nome', '')), '');
  v_marca_id := NULLIF(p_payload->>'marca_id', '')::uuid;
  v_categoria_id := NULLIF(p_payload->>'categoria_id', '')::uuid;
  v_fornecedor_id := NULLIF(NULLIF(p_payload->>'fornecedor_principal_id', ''), 'none')::uuid;

  IF v_nome IS NULL THEN
    RAISE EXCEPTION 'Nome do produto é obrigatório.' USING ERRCODE = 'P0001';
  END IF;

  IF v_marca_id IS NULL THEN
    RAISE EXCEPTION 'Marca do produto é obrigatória.' USING ERRCODE = 'P0001';
  END IF;

  -- SPEC-158 (P2.2): categoria deixou de ser obrigatória -- só validada
  -- (precisa existir) quando informada. produtos.categoria_id é nullable.

  IF NOT EXISTS (SELECT 1 FROM public.marcas WHERE id = v_marca_id) THEN
    RAISE EXCEPTION 'Marca informada não existe.' USING ERRCODE = 'P0001';
  END IF;

  IF v_categoria_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.categorias_produto WHERE id = v_categoria_id) THEN
    RAISE EXCEPTION 'Categoria informada não existe.' USING ERRCODE = 'P0001';
  END IF;

  IF v_fornecedor_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.contatos WHERE id = v_fornecedor_id) THEN
    RAISE EXCEPTION 'Fornecedor informado não existe.' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.produtos (
    nome,
    referencia,
    marca_id,
    categoria_id,
    fornecedor_principal_id,
    unidade,
    preco_custo,
    preco_venda,
    valor_venda,
    descricao_tecnica,
    ncm,
    tipo_fiscal,
    cst,
    cest,
    porc_frete,
    porc_despesas,
    porc_bdi,
    porc_st,
    porc_desconto,
    icms_entrada,
    ipi_entrada,
    margem_lucro,
    custo_total,
    mascara_produto,
    status_comercial,
    ativo
  ) VALUES (
    v_nome,
    NULLIF(btrim(COALESCE(p_payload->>'referencia', '')), ''),
    v_marca_id,
    v_categoria_id,
    v_fornecedor_id,
    COALESCE(NULLIF(btrim(COALESCE(p_payload->>'unidade', '')), ''), 'UN'),
    COALESCE(NULLIF(p_payload->>'preco_custo', '')::numeric, 0),
    COALESCE(NULLIF(p_payload->>'preco_venda', '')::numeric, 0),
    COALESCE(NULLIF(p_payload->>'valor_venda', '')::numeric, NULLIF(p_payload->>'preco_venda', '')::numeric, 0),
    NULLIF(btrim(COALESCE(p_payload->>'descricao_tecnica', '')), ''),
    NULLIF(btrim(COALESCE(p_payload->>'ncm', '')), ''),
    NULLIF(btrim(COALESCE(p_payload->>'tipo_fiscal', '')), ''),
    NULLIF(btrim(COALESCE(p_payload->>'cst', '')), ''),
    NULLIF(btrim(COALESCE(p_payload->>'cest', '')), ''),
    COALESCE(NULLIF(p_payload->>'porc_frete', '')::numeric, 0),
    COALESCE(NULLIF(p_payload->>'porc_despesas', '')::numeric, 0),
    COALESCE(NULLIF(p_payload->>'porc_bdi', '')::numeric, 0),
    COALESCE(NULLIF(p_payload->>'porc_st', '')::numeric, 0),
    COALESCE(NULLIF(p_payload->>'porc_desconto', '')::numeric, 0),
    COALESCE(NULLIF(p_payload->>'icms_entrada', '')::numeric, 0),
    COALESCE(NULLIF(p_payload->>'ipi_entrada', '')::numeric, 0),
    COALESCE(NULLIF(p_payload->>'margem_lucro', '')::numeric, NULLIF(p_payload->>'percentual_lucro', '')::numeric, 150),
    COALESCE(NULLIF(p_payload->>'custo_total', '')::numeric, 0),
    NULLIF(btrim(COALESCE(p_payload->>'mascara_produto', '')), ''),
    COALESCE(NULLIF(btrim(COALESCE(p_payload->>'status_comercial', '')), ''), 'Normal'),
    true
  )
  RETURNING * INTO v_produto;

  IF COALESCE(v_produto.valor_venda, 0) = 0 AND COALESCE(v_produto.preco_venda, 0) > 0 THEN
    UPDATE public.produtos
    SET valor_venda = v_produto.preco_venda
    WHERE id = v_produto.id
    RETURNING * INTO v_produto;
  END IF;

  RETURN to_jsonb(v_produto) || jsonb_build_object('source', 'produtos');
END;
$function$;

REVOKE ALL ON FUNCTION public.criar_produto_orcamento(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.criar_produto_orcamento(jsonb) TO authenticated;

COMMIT;
