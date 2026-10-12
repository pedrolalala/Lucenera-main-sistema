-- Rollback da migration 205 (SPEC-193 B3 etapa 2). Devolve as 4 colunas com os dados da cópia de
-- segurança, os índices/constraints/grants e as definições originais das views e funções.
ALTER TABLE public.produtos DROP COLUMN sku;
ALTER TABLE public.produtos
  ADD COLUMN sku text,
  ADD COLUMN categoria text,
  ADD COLUMN codigo_legado integer,
  ADD COLUMN percentual_lucro numeric(9,2) DEFAULT 0;

-- trg_calculo_preco_venda recalcula preco_venda em QUALQUER update (incidente 10/09) e os de updated_at
-- mudariam a data de todas as peças — desligados só durante a restauração.
ALTER TABLE public.produtos DISABLE TRIGGER trg_calculo_preco_venda;
ALTER TABLE public.produtos DISABLE TRIGGER trg_atualizar_preco_venda;
ALTER TABLE public.produtos DISABLE TRIGGER trg_sync_estoque_itens_from_produtos;
ALTER TABLE public.produtos DISABLE TRIGGER produtos_updated_at;
ALTER TABLE public.produtos DISABLE TRIGGER update_produtos_updated_at;
UPDATE public.produtos p
   SET sku = b.sku, categoria = b.categoria, codigo_legado = b.codigo_legado, percentual_lucro = b.percentual_lucro
  FROM public._bkp_spec193_produtos_colunas b
 WHERE b.id = p.id;
ALTER TABLE public.produtos ENABLE TRIGGER trg_calculo_preco_venda;
ALTER TABLE public.produtos ENABLE TRIGGER trg_atualizar_preco_venda;
ALTER TABLE public.produtos ENABLE TRIGGER trg_sync_estoque_itens_from_produtos;
ALTER TABLE public.produtos ENABLE TRIGGER produtos_updated_at;
ALTER TABLE public.produtos ENABLE TRIGGER update_produtos_updated_at;

ALTER TABLE public.produtos ADD CONSTRAINT produtos_sku_key UNIQUE (sku);
ALTER TABLE public.produtos ADD CONSTRAINT produtos_codigo_legado_key UNIQUE (codigo_legado);
CREATE INDEX idx_prod_sku ON public.produtos USING btree (sku);
CREATE INDEX idx_prod_categoria ON public.produtos USING btree (categoria);
CREATE INDEX idx_produtos_codigo_legado ON public.produtos USING btree (codigo_legado);
CREATE UNIQUE INDEX produtos_sku_unique_idx ON public.produtos USING btree (sku) WHERE (sku IS NOT NULL);
GRANT SELECT (sku, categoria, codigo_legado) ON public.produtos TO authenticated;

CREATE OR REPLACE FUNCTION public.buscar_produtos_fuzzy(p_termo text DEFAULT NULL::text, p_marca_id uuid DEFAULT NULL::uuid, p_categoria_id uuid DEFAULT NULL::uuid, p_produto_ids uuid[] DEFAULT NULL::uuid[], p_offset integer DEFAULT 0, p_limit integer DEFAULT 100)
 RETURNS TABLE(id uuid, nome text, sku text, referencia text, codigo_produto integer, preco_venda numeric, valor_venda numeric, marca_nome text, categoria_nome text)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
    v_termo   text := nullif(trim(p_termo), '');
    v_termos  text[];
BEGIN
    IF v_termo IS NOT NULL THEN
        v_termos := regexp_split_to_array(v_termo, '\s+');
    END IF;

    RETURN QUERY
    SELECT sub.id, sub.nome, sub.sku, sub.referencia, sub.codigo_produto,
           sub.preco_venda, sub.valor_venda, sub.marca_nome, sub.categoria_nome
    FROM (
        SELECT DISTINCT
            p.id, p.nome, p.sku, p.referencia, p.codigo_produto,
            p.preco_venda, p.valor_venda,
            m.nome AS marca_nome,
            c.nome AS categoria_nome,
            -- Ranking (inalterado desde 20260819_120): so afeta ORDER BY.
            COALESCE((
                SELECT avg(
                    GREATEST(
                        CASE WHEN t.termo ~ '^\d+$' AND p.codigo_produto = t.termo::int THEN 5.0 ELSE 0 END,
                        CASE WHEN p.referencia ilike '%' || t.termo || '%' THEN 4.0 ELSE 0 END,
                        CASE WHEN p.sku ilike '%' || t.termo || '%' THEN 4.0 ELSE 0 END,
                        CASE WHEN coalesce(m.nome, '') ilike '%' || t.termo || '%'
                                  OR word_similarity(public.immutable_unaccent(lower(t.termo)), public.immutable_unaccent(lower(coalesce(m.nome, '')))) > 0.3
                             THEN 3.0 ELSE 0 END,
                        CASE WHEN p.nome ilike '%' || t.termo || '%'
                                  OR word_similarity(public.immutable_unaccent(lower(t.termo)), public.immutable_unaccent(lower(p.nome))) > 0.3
                             THEN 2.0 ELSE 0 END,
                        CASE WHEN p.descricao_tecnica ilike '%' || t.termo || '%'
                                  OR coalesce(c.nome, '') ilike '%' || t.termo || '%'
                                  OR word_similarity(public.immutable_unaccent(lower(t.termo)), public.immutable_unaccent(lower(coalesce(c.nome, '')))) > 0.3
                                  OR word_similarity(public.immutable_unaccent(lower(t.termo)), public.immutable_unaccent(lower(coalesce(p.descricao_tecnica, '')))) > 0.3
                             THEN 1.0 ELSE 0 END
                    )
                )
                FROM unnest(v_termos) AS t(termo)
            ), 1.0) AS relevancia
        FROM public.produtos p
        LEFT JOIN public.marcas m ON m.id = p.marca_id
        LEFT JOIN public.categorias_produto c ON c.id = p.categoria_id
        WHERE p.ativo = true
          AND (p_marca_id IS NULL OR p.marca_id = p_marca_id)
          AND (p_categoria_id IS NULL OR p.categoria_id = p_categoria_id)
          AND (p_produto_ids IS NULL OR p.id = ANY(p_produto_ids))
          AND (
            v_termos IS NULL
            OR NOT EXISTS (
                -- ELIMINACAO: substring literal, mas normalizada por
                -- acento/caixa (immutable_unaccent+lower nos dois lados) --
                -- continua sem fallback de similaridade/score.
                SELECT 1 FROM unnest(v_termos) AS t(termo)
                WHERE NOT (
                    public.immutable_unaccent(lower(coalesce(p.nome, ''))) ilike '%' || public.immutable_unaccent(lower(t.termo)) || '%'
                    OR public.immutable_unaccent(lower(coalesce(p.sku, ''))) ilike '%' || public.immutable_unaccent(lower(t.termo)) || '%'
                    OR public.immutable_unaccent(lower(coalesce(p.referencia, ''))) ilike '%' || public.immutable_unaccent(lower(t.termo)) || '%'
                    OR public.immutable_unaccent(lower(coalesce(p.descricao_tecnica, ''))) ilike '%' || public.immutable_unaccent(lower(t.termo)) || '%'
                    OR public.immutable_unaccent(lower(coalesce(m.nome, ''))) ilike '%' || public.immutable_unaccent(lower(t.termo)) || '%'
                    OR public.immutable_unaccent(lower(coalesce(c.nome, ''))) ilike '%' || public.immutable_unaccent(lower(t.termo)) || '%'
                    OR (t.termo ~ '^\d+$' AND p.codigo_produto = t.termo::int)
                )
            )
          )
    ) sub
    ORDER BY sub.relevancia DESC, sub.nome
    OFFSET p_offset
    LIMIT p_limit;
END;
$function$;

CREATE OR REPLACE FUNCTION public.garantia_buscar_produtos(p_search text)
 RETURNS TABLE(id uuid, nome text, sku text, referencia text, codigo_produto integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
    SELECT p.id, p.nome, p.sku, p.referencia, p.codigo_produto
    FROM produtos p
    WHERE p.ativo = true
      AND (
        p_search IS NULL OR p_search = '' OR
        p.nome ILIKE '%' || p_search || '%' OR
        p.sku ILIKE '%' || p_search || '%' OR
        p.referencia ILIKE '%' || p_search || '%' OR
        p.codigo_produto::text ILIKE '%' || p_search || '%'
      )
    ORDER BY p.nome
    LIMIT 30;
$function$;

CREATE OR REPLACE FUNCTION public.showroom_listar_produtos_estoque(p_termo text DEFAULT NULL::text)
 RETURNS TABLE(codigo_produto integer, nome text, codigo_legado integer, referencia text, estoque_showroom integer, imagem_showroom_url text, marca text, eh_principal_de_grupo boolean, membro_de_codigo_produto integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select p.codigo_produto, p.nome, p.codigo_legado, p.referencia,
         coalesce(p.estoque_showroom,0), p.imagem_showroom_url, m.nome,
         exists(select 1 from public.showroom_grupo_itens g1 where g1.codigo_produto_principal = p.codigo_produto),
         (select g2.codigo_produto_principal from public.showroom_grupo_itens g2 where g2.codigo_produto_membro = p.codigo_produto)
  from public.produtos p
  left join public.marcas m on m.id = p.marca_id
  where p.ativo
    and coalesce(p.estoque_showroom,0) > 0
    and not exists (select 1 from public.showroom_ocultos o where o.codigo_produto = p.codigo_produto)
    and (
      p_termo is null or p_termo = ''
      or p.nome ilike '%'||p_termo||'%'
      or p.codigo_legado::text ilike '%'||p_termo||'%'
      or p.referencia ilike '%'||p_termo||'%'
      or p.codigo_produto::text = p_termo
    )
  order by (p.imagem_showroom_url is null) desc, p.nome
  limit 1000;
$function$;

CREATE OR REPLACE FUNCTION public.showroom_obter_composicao(p_codigo_produto_principal integer)
 RETURNS TABLE(codigo_produto integer, nome text, codigo_legado integer, estoque_showroom integer, valor_venda numeric, quantidade integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select p.codigo_produto, p.nome, p.codigo_legado, coalesce(p.estoque_showroom,0), coalesce(p.valor_venda,0), g.quantidade
  from public.showroom_grupo_itens g
  join public.produtos p on p.codigo_produto = g.codigo_produto_membro
  where g.codigo_produto_principal = p_codigo_produto_principal
  order by p.nome;
$function$;

CREATE OR REPLACE FUNCTION public.showroom_buscar_produto(p_termo text, p_incluir_ocultos boolean DEFAULT false)
 RETURNS TABLE(codigo_produto integer, nome text, marca text, estoque_showroom integer, valor_venda numeric, eh_principal_de_grupo boolean, membro_de_codigo_produto integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select p.codigo_produto, p.nome, m.nome, coalesce(p.estoque_showroom,0), coalesce(p.valor_venda,0),
         exists(select 1 from public.showroom_grupo_itens g1 where g1.codigo_produto_principal = p.codigo_produto),
         (select g2.codigo_produto_principal from public.showroom_grupo_itens g2 where g2.codigo_produto_membro = p.codigo_produto)
  from public.produtos p
  left join public.marcas m on m.id = p.marca_id
  where p.ativo
    and (p_incluir_ocultos or not exists (select 1 from public.showroom_ocultos o where o.codigo_produto = p.codigo_produto))
    and (
      p.codigo_produto::text = p_termo
      or p.nome ilike '%' || p_termo || '%'
      or p.codigo_legado::text ilike '%' || p_termo || '%'
      or p.referencia ilike '%' || p_termo || '%'
    )
  order by (p.codigo_produto::text = p_termo) desc, p.nome
  limit 20;
$function$;

CREATE OR REPLACE FUNCTION public.criar_produto_orcamento(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user_role text;
  v_nome text;
  v_sku text;
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
  v_sku := NULLIF(btrim(COALESCE(p_payload->>'sku', '')), '');
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

  IF v_sku IS NOT NULL AND EXISTS (SELECT 1 FROM public.produtos WHERE sku = v_sku) THEN
    RAISE EXCEPTION 'SKU % já está em uso.', v_sku
      USING ERRCODE = '23505';
  END IF;

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
    sku,
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
    v_sku,
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

CREATE OR REPLACE VIEW public.vw_produtos_custo_restrito AS
 SELECT id,
    marca_id,
    nome,
    sku,
    categoria,
    preco_venda,
    ativo,
    created_at,
    updated_at,
    codigo_produto,
    referencia,
    estoque_total,
    estoque_showroom,
    estoque_disponivel,
    unidade,
    valor_venda,
    codigo_legado,
    categoria_id,
    fornecedor_principal_id,
    descricao_tecnica,
    ncm,
    tipo_fiscal,
    cst,
    cest,
    status_comercial,
    mascara_produto,
    prazo_entrega_dias,
    multiplo_compra,
    estoque_minimo,
    imagem_showroom_url,
    grupo_fiscal_nao_contribuinte,
    grupo_fiscal_revenda,
    tem_st,
    (
        CASE
            WHEN ( SELECT pode_ver_custo_produto() AS pode_ver_custo_produto) THEN preco_custo
            ELSE NULL::numeric
        END)::numeric(12,2) AS preco_custo,
        CASE
            WHEN ( SELECT pode_ver_custo_produto() AS pode_ver_custo_produto) THEN porc_desconto
            ELSE NULL::numeric
        END AS porc_desconto,
    (
        CASE
            WHEN ( SELECT pode_ver_custo_produto() AS pode_ver_custo_produto) THEN percentual_desconto_compra
            ELSE NULL::numeric
        END)::numeric(5,2) AS percentual_desconto_compra,
    (
        CASE
            WHEN ( SELECT pode_ver_custo_produto() AS pode_ver_custo_produto) THEN porc_frete
            ELSE NULL::numeric
        END)::numeric(5,2) AS porc_frete,
        CASE
            WHEN ( SELECT pode_ver_custo_produto() AS pode_ver_custo_produto) THEN porc_st
            ELSE NULL::numeric
        END AS porc_st,
    (
        CASE
            WHEN ( SELECT pode_ver_custo_produto() AS pode_ver_custo_produto) THEN ipi_entrada
            ELSE NULL::numeric
        END)::numeric(5,2) AS ipi_entrada,
    (
        CASE
            WHEN ( SELECT pode_ver_custo_produto() AS pode_ver_custo_produto) THEN icms_entrada
            ELSE NULL::numeric
        END)::numeric(5,2) AS icms_entrada,
    (
        CASE
            WHEN ( SELECT pode_ver_custo_produto() AS pode_ver_custo_produto) THEN porc_despesas
            ELSE NULL::numeric
        END)::numeric(5,2) AS porc_despesas,
        CASE
            WHEN ( SELECT pode_ver_custo_produto() AS pode_ver_custo_produto) THEN porc_bdi
            ELSE NULL::numeric
        END AS porc_bdi,
    (
        CASE
            WHEN ( SELECT pode_ver_custo_produto() AS pode_ver_custo_produto) THEN vl_custo_indireto
            ELSE NULL::numeric
        END)::numeric(12,2) AS vl_custo_indireto,
    (
        CASE
            WHEN ( SELECT pode_ver_custo_produto() AS pode_ver_custo_produto) THEN custo_total
            ELSE NULL::numeric
        END)::numeric(15,2) AS custo_total,
    (
        CASE
            WHEN ( SELECT pode_ver_custo_produto() AS pode_ver_custo_produto) THEN margem_lucro
            ELSE NULL::numeric
        END)::numeric(8,4) AS margem_lucro,
    (
        CASE
            WHEN ( SELECT pode_ver_custo_produto() AS pode_ver_custo_produto) THEN percentual_lucro
            ELSE NULL::numeric
        END)::numeric(9,2) AS percentual_lucro
   FROM produtos p
  WHERE ( SELECT pode_acessar_algum(ARRAY['cadastro'::text, 'orcamentos'::text, 'necessidade-de-compra'::text, 'dashboard-financeiro'::text, 'separacao-parcial'::text, 'logistica'::text, 'vendas'::text, 'showroom'::text, 'controle-producao'::text, 'controle-garantia'::text]) AS pode_acessar_algum);

CREATE OR REPLACE VIEW public.vw_produtos_custo AS
 SELECT id,
    preco_custo,
    porc_desconto,
    percentual_desconto_compra,
    porc_frete,
    porc_st,
    ipi_entrada,
    icms_entrada,
    porc_despesas,
    porc_bdi,
    vl_custo_indireto,
    custo_total,
    margem_lucro,
    percentual_lucro
   FROM produtos p
  WHERE ( SELECT pode_ver_custo_produto() AS pode_ver_custo_produto);

CREATE OR REPLACE VIEW public.vw_showroom_publico AS
 WITH avulsas AS (
         SELECT p.codigo_produto,
            p.nome,
            m.nome AS marca,
            COALESCE(cp.nome, NULLIF(p.categoria, ''::text)) AS categoria,
            p.estoque_showroom,
            COALESCE(p.valor_venda, (0)::numeric) AS valor_venda,
            NULLIF(p.descricao_tecnica, ''::text) AS descricao_tecnica,
            p.imagem_showroom_url,
            p.updated_at AS atualizado_em
           FROM ((produtos p
             LEFT JOIN marcas m ON ((m.id = p.marca_id)))
             LEFT JOIN categorias_produto cp ON ((cp.id = p.categoria_id)))
          WHERE (p.ativo AND (p.imagem_showroom_url IS NOT NULL) AND (p.imagem_showroom_url <> ''::text) AND (COALESCE(p.estoque_showroom, 0) > 0) AND (NOT (EXISTS ( SELECT 1
                   FROM showroom_grupo_itens g
                  WHERE (g.codigo_produto_membro = p.codigo_produto)))) AND (NOT (EXISTS ( SELECT 1
                   FROM showroom_grupo_itens g
                  WHERE (g.codigo_produto_principal = p.codigo_produto)))) AND (NOT (EXISTS ( SELECT 1
                   FROM showroom_ocultos o
                  WHERE (o.codigo_produto = p.codigo_produto)))))
        ), conjuntos_agregado AS (
         SELECT g.codigo_produto_principal,
            sum((COALESCE(pm.valor_venda, (0)::numeric) * (g.quantidade)::numeric)) AS valor_membros,
            (min(floor(((
                CASE
                    WHEN pm.ativo THEN COALESCE(pm.estoque_showroom, 0)
                    ELSE 0
                END)::numeric / (g.quantidade)::numeric))))::integer AS min_conjuntos_membros
           FROM (showroom_grupo_itens g
             JOIN produtos pm ON ((pm.codigo_produto = g.codigo_produto_membro)))
          GROUP BY g.codigo_produto_principal
        ), conjuntos AS (
         SELECT pr.codigo_produto,
            pr.nome,
            mpr.nome AS marca,
            COALESCE(cppr.nome, NULLIF(pr.categoria, ''::text)) AS categoria,
            LEAST(COALESCE(pr.estoque_showroom, 0), COALESCE(ca.min_conjuntos_membros, 0)) AS estoque_showroom,
            (COALESCE(pr.valor_venda, (0)::numeric) + COALESCE(ca.valor_membros, (0)::numeric)) AS valor_venda,
            NULLIF(pr.descricao_tecnica, ''::text) AS descricao_tecnica,
            pr.imagem_showroom_url,
            pr.updated_at AS atualizado_em
           FROM (((conjuntos_agregado ca
             JOIN produtos pr ON ((pr.codigo_produto = ca.codigo_produto_principal)))
             LEFT JOIN marcas mpr ON ((mpr.id = pr.marca_id)))
             LEFT JOIN categorias_produto cppr ON ((cppr.id = pr.categoria_id)))
          WHERE (pr.ativo AND (pr.imagem_showroom_url IS NOT NULL) AND (pr.imagem_showroom_url <> ''::text) AND (NOT (EXISTS ( SELECT 1
                   FROM showroom_ocultos o
                  WHERE (o.codigo_produto = pr.codigo_produto)))))
        )
 SELECT avulsas.codigo_produto,
    avulsas.nome,
    avulsas.marca,
    avulsas.categoria,
    avulsas.estoque_showroom,
    avulsas.valor_venda,
    avulsas.descricao_tecnica,
    avulsas.imagem_showroom_url,
    avulsas.atualizado_em
   FROM avulsas
UNION ALL
 SELECT conjuntos.codigo_produto,
    conjuntos.nome,
    conjuntos.marca,
    conjuntos.categoria,
    conjuntos.estoque_showroom,
    conjuntos.valor_venda,
    conjuntos.descricao_tecnica,
    conjuntos.imagem_showroom_url,
    conjuntos.atualizado_em
   FROM conjuntos
  WHERE (conjuntos.estoque_showroom > 0);

CREATE OR REPLACE VIEW public.vw_produtos_estoque_detalhado AS
 WITH estoque_calculado AS (
         SELECT ei.produto_id,
            sum(
                CASE
                    WHEN (((ei.local)::text ~~* 'estoque%'::text) AND (ei.local <> ALL (ARRAY['Estoque Garantia'::estoque_local, 'Estoque Casa Cor'::estoque_local]))) THEN ei.quantidade
                    ELSE (0)::numeric
                END) AS qtd_geral,
            sum(
                CASE
                    WHEN ((ei.local)::text ~~* 'showroom%'::text) THEN ei.quantidade
                    ELSE (0)::numeric
                END) AS qtd_showroom,
            (sum(
                CASE
                    WHEN (ei.local = 'Estoque'::estoque_local) THEN COALESCE(ei.quantidade_reservada, (0)::numeric)
                    ELSE (0)::numeric
                END) + sum(
                CASE
                    WHEN ((ei.local)::text ~~* 'reserva%'::text) THEN ei.quantidade
                    ELSE (0)::numeric
                END)) AS qtd_reserva,
            sum(
                CASE
                    WHEN (((ei.local)::text ~~* 'separacao%'::text) OR ((ei.local)::text ~~* 'separação%'::text)) THEN ei.quantidade
                    ELSE (0)::numeric
                END) AS qtd_separacao,
            sum(
                CASE
                    WHEN (ei.local = 'Estoque Garantia'::estoque_local) THEN ei.quantidade
                    ELSE (0)::numeric
                END) AS qtd_garantia,
            sum(
                CASE
                    WHEN (ei.local = 'Estoque Casa Cor'::estoque_local) THEN ei.quantidade
                    ELSE (0)::numeric
                END) AS qtd_casa_cor,
            sum(ei.quantidade) AS total_fisico
           FROM estoque_itens ei
          GROUP BY ei.produto_id
        )
 SELECT p.id,
    p.codigo_produto,
    p.nome,
    p.sku,
    p.preco_venda,
    COALESCE(ec.qtd_geral, (0)::numeric) AS estoque_geral,
    COALESCE(ec.qtd_reserva, (0)::numeric) AS reserva,
    COALESCE(ec.qtd_separacao, (0)::numeric) AS separacao,
    ((COALESCE(ec.qtd_geral, (0)::numeric) - COALESCE(ec.qtd_reserva, (0)::numeric)) - COALESCE(ec.qtd_separacao, (0)::numeric)) AS disponivel,
    COALESCE(ec.qtd_garantia, (0)::numeric) AS estoque_garantia,
    COALESCE(ec.qtd_casa_cor, (0)::numeric) AS estoque_casa_cor
   FROM (produtos p
     LEFT JOIN estoque_calculado ec ON ((p.id = ec.produto_id)));

CREATE OR REPLACE FUNCTION public.get_next_sku(prefix text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  highest_num integer := 0;
  next_sku text;
  rec record;
  num_str text;
  parsed_num integer;
BEGIN
  FOR rec IN
    SELECT sku FROM public.produtos WHERE sku LIKE prefix || '%' AND sku IS NOT NULL
  LOOP
    num_str := regexp_replace(substring(rec.sku from length(prefix) + 1), '[^0-9]', '', 'g');
    IF num_str <> '' THEN
      BEGIN
        parsed_num := CAST(num_str AS integer);
        IF parsed_num > highest_num THEN
          highest_num := parsed_num;
        END IF;
      EXCEPTION WHEN OTHERS THEN
        -- Ignore cast errors
      END;
    END IF;
  END LOOP;

  next_sku := prefix || lpad((highest_num + 1)::text, 2, '0');
  
  RETURN next_sku;
END;
$function$;

-- get_next_sku: ACL original =X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres
NOTIFY pgrst, 'reload schema';
