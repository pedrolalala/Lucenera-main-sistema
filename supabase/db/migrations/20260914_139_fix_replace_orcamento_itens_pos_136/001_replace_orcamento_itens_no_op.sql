-- Correcao pendente: a migration 20260911_135 continha 2 fixes
-- (replace_orcamento_itens + aprovar_orcamento_financeiro), mas quando a
-- 20260911_136 foi aplicada em producao em 2026-09-14, ela reescreveu
-- aprovar_orcamento_financeiro com a versao correta (bloqueio de peca sem
-- cadastro + numero_venda) -- porem NUNCA tocou replace_orcamento_itens,
-- que ficou pra tras sem o fix do "reset falso-positivo" (Prompt 1 do
-- documento Light Design 11/09: editar so forma de pagamento/data nao pode
-- reiniciar o ciclo de aprovacao do cliente).
--
-- Esta migration aplica SOMENTE o corpo de replace_orcamento_itens da
-- 20260911_135 (nao mexe em aprovar_orcamento_financeiro, que ja esta
-- correto em producao desde a 136 -- reaplicar a versao da 135 aqui
-- reverteria numero_venda).

BEGIN;

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
        RAISE EXCEPTION 'Permissao negada: alterar valor ou produto de item do orcamento requer perfil administrador.'
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
      custom_id, ordem, sub_ordem, item_pai_id, peca_nova, projeto_item_origem_id
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
      CASE WHEN item->>'projeto_item_origem_id' IS NULL OR item->>'projeto_item_origem_id' = '' THEN NULL ELSE (item->>'projeto_item_origem_id')::uuid END AS projeto_item_origem_id
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

NOTIFY pgrst, 'reload schema';

COMMIT;
