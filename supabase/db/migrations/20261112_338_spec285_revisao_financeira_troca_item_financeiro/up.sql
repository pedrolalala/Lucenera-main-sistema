-- SPEC-285: libera a troca de produto/valor de item para o financeiro na Revisao Financeira (resto = SPEC-281, migration 332).
-- SPEC-281: replace_orcamento_itens deixa de apagar-e-recriar os itens.
-- Antes: DELETE de todos + INSERT; item ja ligado a venda (projeto_itens.orcamento_item_id) ou nota parcial
-- (notas_fiscais_itens) fazia o banco recusar (FK) e NADA era salvo. Agora itens que continuam sao
-- ATUALIZADOS no lugar (id e vinculos mantidos), novos sao inseridos e so os removidos sao apagados;
-- removido com venda/nota ligada gera erro claro. Assinatura e permissao inalteradas; SPEC-135 mantida.
-- replace_orcamento_itens: passa a gravar/comparar ja_com_cliente.
CREATE OR REPLACE FUNCTION public.replace_orcamento_itens(p_orcamento_id uuid, p_items jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  inserted_count integer;
  v_user_role text;
  v_extra_count integer;
  v_itens_iguais boolean;
  v_pares jsonb;
  v_par record;
  v_old uuid;
BEGIN
  IF COALESCE(auth.role(), '') <> 'service_role' THEN
    SELECT u.role::text INTO v_user_role
    FROM public.usuarios u
    WHERE u.id = auth.uid()
      AND COALESCE(u.ativo, true) = true;

    -- SPEC-285 (reuniao 50, 12/11/2026): na Revisao Financeira quem tem acesso 'financeiro' (ex.: Carol) tambem
    -- troca produto/valor de item. So com orcamento em 'Aprovação Financeira', usuario ativo e logado.
    IF v_user_role IS DISTINCT FROM 'admin'
       AND NOT (
         v_user_role IS NOT NULL
         AND auth.uid() IS NOT NULL
         AND public.pode_acessar_sistema('financeiro')
         AND EXISTS (SELECT 1 FROM public.orcamentos o WHERE o.id = p_orcamento_id AND o.status::text = 'Aprovação Financeira')
       ) THEN
      WITH old_items AS (
        SELECT
          COALESCE(produto_id::text, '') AS identidade,
          COALESCE(descricao, '') AS descricao_,
          preco_unitario,
          row_number() OVER (
            PARTITION BY COALESCE(produto_id::text, ''), COALESCE(descricao, ''), preco_unitario
            ORDER BY id
          ) AS rn
        FROM public.orcamento_itens
        WHERE orcamento_id = p_orcamento_id
      ),
      new_items AS (
        SELECT
          COALESCE(item->>'produto_id', '') AS identidade,
          COALESCE(item->>'descricao', '') AS descricao_,
          (item->>'preco_unitario')::numeric AS preco_unitario,
          row_number() OVER (
            PARTITION BY COALESCE(item->>'produto_id', ''), COALESCE(item->>'descricao', ''), (item->>'preco_unitario')::numeric
            ORDER BY ordinality
          ) AS rn
        FROM jsonb_array_elements(p_items) WITH ORDINALITY AS t(item, ordinality)
      )
      SELECT count(*) INTO v_extra_count
      FROM new_items n
      LEFT JOIN old_items o
        ON o.identidade = n.identidade
       AND o.descricao_ = n.descricao_
       AND o.preco_unitario = n.preco_unitario
       AND o.rn = n.rn
      WHERE o.rn IS NULL;

      IF v_extra_count > 0 THEN
        RAISE EXCEPTION 'Permissao negada: alterar valor ou produto de item do orcamento requer perfil administrador (ou financeiro na Revisao Financeira).'
          USING ERRCODE = 'P0001';
      END IF;
    END IF;
  END IF;

  -- SPEC-135: o formulario reenvia os itens em QUALQUER salvamento (mesmo
  -- so mudando forma de pagamento/data/desconto, campos que nao ficam em
  -- orcamento_itens). O DELETE+INSERT abaixo disparava incondicionalmente o
  -- trigger trg_orcamento_item_change_reset, reiniciando o ciclo de
  -- aprovacao do cliente mesmo quando nenhum item mudou de fato. Se o
  -- conjunto recebido e identico ao ja salvo, nao mexe na tabela -- preserva
  -- a regra do SPEC-111 (mudanca REAL de item reseta) sem o falso positivo.
  WITH old_rows AS (
    SELECT
      produto_id, descricao, quantidade, preco_unitario, desconto,
      custom_id, ordem, sub_ordem, item_pai_id, peca_nova, projeto_item_origem_id, setor_origem, ja_com_cliente
    FROM public.orcamento_itens
    WHERE orcamento_id = p_orcamento_id
  ),
  new_rows AS (
    SELECT
      CASE WHEN item->>'produto_id' IS NULL OR item->>'produto_id' = '' THEN NULL ELSE (item->>'produto_id')::uuid END AS produto_id,
      NULLIF(item->>'descricao', '') AS descricao,
      (item->>'quantidade')::numeric AS quantidade,
      (item->>'preco_unitario')::numeric AS preco_unitario,
      (item->>'desconto')::numeric AS desconto,
      NULLIF(item->>'custom_id', '') AS custom_id,
      CASE WHEN item->>'ordem' IS NULL OR item->>'ordem' = '' THEN NULL ELSE (item->>'ordem')::integer END AS ordem,
      CASE WHEN item->>'sub_ordem' IS NULL OR item->>'sub_ordem' = '' THEN NULL ELSE (item->>'sub_ordem')::integer END AS sub_ordem,
      CASE WHEN item->>'item_pai_id' IS NULL OR item->>'item_pai_id' = '' THEN NULL ELSE (item->>'item_pai_id')::uuid END AS item_pai_id,
      COALESCE((item->>'peca_nova')::boolean, false) AS peca_nova,
      CASE WHEN item->>'projeto_item_origem_id' IS NULL OR item->>'projeto_item_origem_id' = '' THEN NULL ELSE (item->>'projeto_item_origem_id')::uuid END AS projeto_item_origem_id,
      NULLIF(item->>'setor_origem', '') AS setor_origem,
      COALESCE((item->>'ja_com_cliente')::boolean, false) AS ja_com_cliente
    FROM jsonb_array_elements(p_items) AS item
    WHERE (item->>'produto_id' IS NOT NULL AND item->>'produto_id' != '')
       OR NULLIF(item->>'descricao', '') IS NOT NULL
  )
  SELECT
    NOT EXISTS (SELECT * FROM old_rows EXCEPT ALL SELECT * FROM new_rows)
    AND NOT EXISTS (SELECT * FROM new_rows EXCEPT ALL SELECT * FROM old_rows)
  INTO v_itens_iguais;

  IF v_itens_iguais THEN
    SELECT count(*) INTO inserted_count FROM public.orcamento_itens WHERE orcamento_id = p_orcamento_id;
    RETURN inserted_count;
  END IF;

  -- SPEC-281: pareia itens antigos x novos pela mesma identidade usada na checagem de permissao
  -- (produto, descricao, preco, n-esima ocorrencia). Pareados = UPDATE; so novos = INSERT; so antigos = DELETE.
  v_pares := (
    WITH old_rows AS (
      SELECT id, produto_id::text AS prod, COALESCE(descricao, '') AS desc_, preco_unitario,
             row_number() OVER (PARTITION BY COALESCE(produto_id::text, ''), COALESCE(descricao, ''), preco_unitario ORDER BY ordem NULLS LAST, sub_ordem NULLS LAST, id) AS rn
      FROM public.orcamento_itens
      WHERE orcamento_id = p_orcamento_id
    ),
    new_rows AS (
      SELECT item, NULLIF(item->>'produto_id', '') AS prod, COALESCE(item->>'descricao', '') AS desc_,
             (item->>'preco_unitario')::numeric AS preco_unitario,
             row_number() OVER (PARTITION BY COALESCE(item->>'produto_id', ''), COALESCE(item->>'descricao', ''), (item->>'preco_unitario')::numeric ORDER BY ord) AS rn
      FROM jsonb_array_elements(p_items) WITH ORDINALITY AS t(item, ord)
      WHERE (item->>'produto_id' IS NOT NULL AND item->>'produto_id' <> '')
         OR NULLIF(item->>'descricao', '') IS NOT NULL
    )
    SELECT COALESCE(jsonb_agg(jsonb_build_object('old_id', o.id, 'item', n.item)), '[]'::jsonb)
    FROM old_rows o
    FULL JOIN new_rows n
      ON COALESCE(o.prod, '') = COALESCE(n.prod, '')
     AND o.desc_ = n.desc_ AND o.preco_unitario = n.preco_unitario AND o.rn = n.rn
  );

  -- 1) itens que continuam: atualiza no lugar (id e vinculos preservados)
  FOR v_par IN
    SELECT e FROM jsonb_array_elements(v_pares) AS e
    WHERE e->>'old_id' IS NOT NULL AND jsonb_typeof(e->'item') = 'object'
  LOOP
    UPDATE public.orcamento_itens oi SET
      produto_id = CASE WHEN v_par.e->'item'->>'produto_id' IS NULL OR v_par.e->'item'->>'produto_id' = '' THEN NULL ELSE (v_par.e->'item'->>'produto_id')::uuid END,
      descricao = NULLIF(v_par.e->'item'->>'descricao', ''),
      quantidade = (v_par.e->'item'->>'quantidade')::numeric,
      preco_unitario = (v_par.e->'item'->>'preco_unitario')::numeric,
      desconto = (v_par.e->'item'->>'desconto')::numeric,
      custom_id = NULLIF(v_par.e->'item'->>'custom_id', ''),
      ordem = CASE WHEN v_par.e->'item'->>'ordem' IS NULL OR v_par.e->'item'->>'ordem' = '' THEN NULL ELSE (v_par.e->'item'->>'ordem')::integer END,
      sub_ordem = CASE WHEN v_par.e->'item'->>'sub_ordem' IS NULL OR v_par.e->'item'->>'sub_ordem' = '' THEN NULL ELSE (v_par.e->'item'->>'sub_ordem')::integer END,
      item_pai_id = CASE WHEN v_par.e->'item'->>'item_pai_id' IS NULL OR v_par.e->'item'->>'item_pai_id' = '' THEN NULL ELSE (v_par.e->'item'->>'item_pai_id')::uuid END,
      peca_nova = COALESCE((v_par.e->'item'->>'peca_nova')::boolean, false),
      projeto_item_origem_id = CASE WHEN v_par.e->'item'->>'projeto_item_origem_id' IS NULL OR v_par.e->'item'->>'projeto_item_origem_id' = '' THEN NULL ELSE (v_par.e->'item'->>'projeto_item_origem_id')::uuid END,
      setor_origem = NULLIF(v_par.e->'item'->>'setor_origem', ''),
      ja_com_cliente = COALESCE((v_par.e->'item'->>'ja_com_cliente')::boolean, false)
    WHERE oi.id = (v_par.e->>'old_id')::uuid;
  END LOOP;

  -- 2) itens novos: insere
  INSERT INTO public.orcamento_itens (
    orcamento_id, produto_id, descricao, quantidade, preco_unitario, desconto, custom_id, ordem, sub_ordem,
    item_pai_id, peca_nova, projeto_item_origem_id, setor_origem, ja_com_cliente
  )
  SELECT
    p_orcamento_id,
    CASE WHEN e->'item'->>'produto_id' IS NULL OR e->'item'->>'produto_id' = '' THEN NULL ELSE (e->'item'->>'produto_id')::uuid END,
    NULLIF(e->'item'->>'descricao', ''),
    (e->'item'->>'quantidade')::numeric,
    (e->'item'->>'preco_unitario')::numeric,
    (e->'item'->>'desconto')::numeric,
    NULLIF(e->'item'->>'custom_id', ''),
    CASE WHEN e->'item'->>'ordem' IS NULL OR e->'item'->>'ordem' = '' THEN NULL ELSE (e->'item'->>'ordem')::integer END,
    CASE WHEN e->'item'->>'sub_ordem' IS NULL OR e->'item'->>'sub_ordem' = '' THEN NULL ELSE (e->'item'->>'sub_ordem')::integer END,
    CASE WHEN e->'item'->>'item_pai_id' IS NULL OR e->'item'->>'item_pai_id' = '' THEN NULL ELSE (e->'item'->>'item_pai_id')::uuid END,
    COALESCE((e->'item'->>'peca_nova')::boolean, false),
    CASE WHEN e->'item'->>'projeto_item_origem_id' IS NULL OR e->'item'->>'projeto_item_origem_id' = '' THEN NULL ELSE (e->'item'->>'projeto_item_origem_id')::uuid END,
    NULLIF(e->'item'->>'setor_origem', ''),
    COALESCE((e->'item'->>'ja_com_cliente')::boolean, false)
  FROM jsonb_array_elements(v_pares) AS e
  WHERE e->>'old_id' IS NULL;

  -- 3) itens removidos pelo usuario: so apaga se nao tiver venda/nota ligada
  FOR v_par IN
    SELECT e FROM jsonb_array_elements(v_pares) AS e
    WHERE e->>'old_id' IS NOT NULL AND jsonb_typeof(e->'item') <> 'object'
  LOOP
    v_old := (v_par.e->>'old_id')::uuid;
    IF EXISTS (SELECT 1 FROM public.projeto_itens WHERE orcamento_item_id = v_old)
       OR EXISTS (SELECT 1 FROM public.notas_fiscais_itens WHERE orcamento_item_id = v_old) THEN
      RAISE EXCEPTION 'Nao e possivel remover este item: ele ja esta ligado a venda/nota deste orcamento. Mantenha o item (ou desfaca a venda antes de remove-lo).'
        USING ERRCODE = 'P0001';
    END IF;
    DELETE FROM public.orcamento_itens WHERE id = v_old;
  END LOOP;

  SELECT count(*) INTO inserted_count FROM public.orcamento_itens WHERE orcamento_id = p_orcamento_id;
  RETURN inserted_count;
END;
$function$;

REVOKE ALL ON FUNCTION public.replace_orcamento_itens(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.replace_orcamento_itens(uuid, jsonb) TO authenticated, service_role;
