-- SPEC-071: replace_orcamento_itens precisa persistir projeto_item_origem_id
-- (adicionado em orcamento_itens pela migration 20260807_088), senão o
-- BudgetFormPage.tsx perde esse vínculo toda vez que edita um orçamento de
-- devolução já existente (o fluxo de edição sempre passa por esta RPC).
CREATE OR REPLACE FUNCTION public.replace_orcamento_itens(p_orcamento_id uuid, p_items jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  inserted_count integer;
BEGIN
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
