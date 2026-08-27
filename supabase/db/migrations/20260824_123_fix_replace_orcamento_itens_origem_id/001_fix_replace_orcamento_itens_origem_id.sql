-- Migration 20260824_123
--
-- Achado ao vivo (24/08): tentei aprovar financeiramente um orçamento de
-- devolução (ORC-0028) e a RPC de aprovação recusou: "possui item sem
-- venda de origem vinculada". Usei "Buscar Venda de Origem" (SPEC-071) pra
-- vincular os 3 itens, salvei, e o vínculo continuava NULL no banco mesmo
-- a tela mostrando o item corretamente "vinculado".
--
-- Causa raiz confirmada: a migration 20260815_116 (SPEC-108, trava de
-- valor/produto pra admin) fez CREATE OR REPLACE FUNCTION
-- replace_orcamento_itens e, ao reescrever o INSERT, ESQUECEU a coluna
-- projeto_item_origem_id (SPEC-071, 20260807_089) — tanto na lista de
-- colunas do INSERT quanto no SELECT que lê o jsonb de entrada. Como essa
-- RPC é DELETE+INSERT de TODOS os itens a cada save (não só os novos),
-- qualquer orçamento de devolução editado desde 15/08 perde o vínculo de
-- TODOS os seus itens com a venda de origem, silenciosamente — sem erro
-- nenhum na hora de salvar, só na hora de aprovar (ou nunca, se ninguém
-- reparar).
--
-- Fix: mesma função, mesma trava de admin da SPEC-108 (não removida),
-- só devolvendo projeto_item_origem_id à lista de colunas.

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
BEGIN
  IF COALESCE(auth.role(), '') <> 'service_role' THEN
    SELECT u.role::text INTO v_user_role
    FROM public.usuarios u
    WHERE u.id = auth.uid()
      AND COALESCE(u.ativo, true) = true;

    IF v_user_role IS DISTINCT FROM 'admin' THEN
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
        RAISE EXCEPTION 'Permissão negada: alterar valor ou produto de item do orçamento requer perfil administrador.'
          USING ERRCODE = 'P0001';
      END IF;
    END IF;
  END IF;

  DELETE FROM public.orcamento_itens WHERE orcamento_id = p_orcamento_id;

  INSERT INTO public.orcamento_itens (
    orcamento_id,
    produto_id,
    descricao,
    quantidade,
    preco_unitario,
    desconto,
    custom_id,
    ordem,
    sub_ordem,
    item_pai_id,
    peca_nova,
    projeto_item_origem_id
  )
  SELECT
    p_orcamento_id,
    CASE
      WHEN item->>'produto_id' IS NULL OR item->>'produto_id' = '' THEN NULL
      ELSE (item->>'produto_id')::uuid
    END,
    NULLIF(item->>'descricao', ''),
    (item->>'quantidade')::numeric,
    (item->>'preco_unitario')::numeric,
    (item->>'desconto')::numeric,
    NULLIF(item->>'custom_id', ''),
    CASE
      WHEN item->>'ordem' IS NULL OR item->>'ordem' = '' THEN NULL
      ELSE (item->>'ordem')::integer
    END,
    CASE
      WHEN item->>'sub_ordem' IS NULL OR item->>'sub_ordem' = '' THEN NULL
      ELSE (item->>'sub_ordem')::integer
    END,
    CASE
      WHEN item->>'item_pai_id' IS NULL OR item->>'item_pai_id' = '' THEN NULL
      ELSE (item->>'item_pai_id')::uuid
    END,
    COALESCE((item->>'peca_nova')::boolean, false),
    CASE
      WHEN item->>'projeto_item_origem_id' IS NULL OR item->>'projeto_item_origem_id' = '' THEN NULL
      ELSE (item->>'projeto_item_origem_id')::uuid
    END
  FROM jsonb_array_elements(p_items) AS item
  WHERE (item->>'produto_id' IS NOT NULL AND item->>'produto_id' != '')
     OR NULLIF(item->>'descricao', '') IS NOT NULL;

  GET DIAGNOSTICS inserted_count = ROW_COUNT;
  RETURN inserted_count;
END;
$function$;

COMMENT ON FUNCTION public.replace_orcamento_itens(uuid, jsonb) IS
'SPEC-108: reforça no banco que só admin pode mudar valor (preco_unitario)
ou produto (produto_id/descricao) de item de orçamento — compara multiset
(identidade, preco) antes/depois do replace. Quantidade, desconto,
custom_id e remoção de item continuam livres pra qualquer perfil.
Fix 20260824_123: projeto_item_origem_id (SPEC-071, vínculo de devolução
com a venda de origem) foi reintroduzido no INSERT — a migration do
SPEC-108 tinha derrubado essa coluna sem querer ao reescrever a função,
quebrando silenciosamente toda aprovação de orçamento de devolução criado
ou editado desde 20260815.';
