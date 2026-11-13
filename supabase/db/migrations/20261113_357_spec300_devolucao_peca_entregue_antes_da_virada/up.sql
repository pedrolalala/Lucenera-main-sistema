-- SPEC-300 (13/11/2026): devolucao de peca entregue antes da virada (venda herdada da Connect sem o item no sistema).
-- A linha de devolucao pode ficar SEM projeto_item_origem_id quando traz origem_connect_venda (numero da venda Connect do
-- projeto, ex.: CNX-2451) + origem_connect_motivo. Nao altera venda, projeto_itens nem saldo; na aprovacao financeira o credito
-- sai normal e a linha marcada NAO chama registrar_devolucao_projeto_item* (nao movimenta estoque — regra SPEC-244).
-- Remenda as funcoes VIVAS com replace (aborta se o trecho nao for achado): replace_orcamento_itens (versao da 338) e
-- aprovar_orcamento_financeiro (versao da 350). Assinaturas inalteradas (nao cria overload).
BEGIN;

ALTER TABLE public.orcamento_itens
  ADD COLUMN IF NOT EXISTS origem_connect_venda text,
  ADD COLUMN IF NOT EXISTS origem_connect_motivo text;

COMMENT ON COLUMN public.orcamento_itens.origem_connect_venda IS
  'SPEC-300: so em linha de devolucao sem projeto_item_origem_id — numero da venda herdada da Connect (ex.: CNX-2451) de onde saiu a peca entregue antes da virada.';
COMMENT ON COLUMN public.orcamento_itens.origem_connect_motivo IS
  'SPEC-300: motivo obrigatorio quando origem_connect_venda esta preenchida.';

-- Linha marcada precisa ter venda, motivo e produto; linha sem marca nao pode ter motivo solto.
ALTER TABLE public.orcamento_itens DROP CONSTRAINT IF EXISTS orcamento_itens_origem_connect_chk;
ALTER TABLE public.orcamento_itens ADD CONSTRAINT orcamento_itens_origem_connect_chk CHECK (
  origem_connect_venda IS NULL
  OR (btrim(origem_connect_venda) <> '' AND btrim(coalesce(origem_connect_motivo, '')) <> ''
      AND produto_id IS NOT NULL AND projeto_item_origem_id IS NULL)
);

-- 1) replace_orcamento_itens grava e compara as duas colunas
DO $$
DECLARE v_def text; v_novo text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
   WHERE p.proname = 'replace_orcamento_itens';
  v_novo := v_def;

  v_novo := replace(v_novo,
$a$projeto_item_origem_id, setor_origem, ja_com_cliente
    FROM public.orcamento_itens$a$,
$b$projeto_item_origem_id, setor_origem, ja_com_cliente, origem_connect_venda, origem_connect_motivo
    FROM public.orcamento_itens$b$);
  IF v_novo = v_def THEN RAISE EXCEPTION 'SPEC-300: trecho old_rows nao encontrado'; END IF;
  v_def := v_novo;

  v_novo := replace(v_novo,
$a$COALESCE((item->>'ja_com_cliente')::boolean, false) AS ja_com_cliente
$a$,
$b$COALESCE((item->>'ja_com_cliente')::boolean, false) AS ja_com_cliente,
      NULLIF(item->>'origem_connect_venda', '') AS origem_connect_venda,
      NULLIF(item->>'origem_connect_motivo', '') AS origem_connect_motivo
$b$);
  IF v_novo = v_def THEN RAISE EXCEPTION 'SPEC-300: trecho new_rows nao encontrado'; END IF;
  v_def := v_novo;

  v_novo := replace(v_novo,
$a$ja_com_cliente = COALESCE((v_par.e->'item'->>'ja_com_cliente')::boolean, false)
$a$,
$b$ja_com_cliente = COALESCE((v_par.e->'item'->>'ja_com_cliente')::boolean, false),
      origem_connect_venda = NULLIF(v_par.e->'item'->>'origem_connect_venda', ''),
      origem_connect_motivo = NULLIF(v_par.e->'item'->>'origem_connect_motivo', '')
$b$);
  IF v_novo = v_def THEN RAISE EXCEPTION 'SPEC-300: trecho UPDATE nao encontrado'; END IF;
  v_def := v_novo;

  v_novo := replace(v_novo,
$a$item_pai_id, peca_nova, projeto_item_origem_id, setor_origem, ja_com_cliente
  )$a$,
$b$item_pai_id, peca_nova, projeto_item_origem_id, setor_origem, ja_com_cliente, origem_connect_venda, origem_connect_motivo
  )$b$);
  IF v_novo = v_def THEN RAISE EXCEPTION 'SPEC-300: lista de colunas do INSERT nao encontrada'; END IF;
  v_def := v_novo;

  v_novo := replace(v_novo,
$a$COALESCE((e->'item'->>'ja_com_cliente')::boolean, false)
  FROM jsonb_array_elements(v_pares) AS e$a$,
$b$COALESCE((e->'item'->>'ja_com_cliente')::boolean, false),
    NULLIF(e->'item'->>'origem_connect_venda', ''),
    NULLIF(e->'item'->>'origem_connect_motivo', '')
  FROM jsonb_array_elements(v_pares) AS e$b$);
  IF v_novo = v_def THEN RAISE EXCEPTION 'SPEC-300: valores do INSERT nao encontrados'; END IF;

  EXECUTE v_novo;
END $$;

-- 2) aprovar_orcamento_financeiro aceita a linha marcada e nao mexe no estoque dela
DO $$
DECLARE v_def text; v_novo text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
   WHERE p.proname = 'aprovar_orcamento_financeiro';
  v_novo := v_def;

  -- (a) item sem origem so passa se for origem Connect; e a origem Connect precisa ser valida
  v_novo := replace(v_novo,
$a$WHERE oi.orcamento_id = p_orcamento_id AND oi.projeto_item_origem_id IS NULL
    ) THEN
      RAISE EXCEPTION 'Orçamento de devolução % possui item sem venda de origem vinculada.', v_numero_orcamento
        USING ERRCODE = 'P0001';
    END IF;$a$,
$b$WHERE oi.orcamento_id = p_orcamento_id AND oi.projeto_item_origem_id IS NULL AND oi.origem_connect_venda IS NULL
    ) THEN
      RAISE EXCEPTION 'Orçamento de devolução % possui item sem venda de origem vinculada.', v_numero_orcamento
        USING ERRCODE = 'P0001';
    END IF;

    -- SPEC-300: peça entregue antes da virada — a venda Connect informada precisa ser do mesmo projeto e empresa.
    IF EXISTS (
      SELECT 1 FROM public.orcamento_itens oi
      WHERE oi.orcamento_id = p_orcamento_id AND oi.origem_connect_venda IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM public.orcamentos vo
          WHERE vo.projeto_id = v_orcamento.projeto_id AND vo.empresa_id = v_orcamento.empresa_id
            AND vo.origem = 'connect' AND vo.natureza_operacao = 'venda' AND vo.numero_venda = oi.origem_connect_venda)
    ) THEN
      RAISE EXCEPTION 'Orçamento de devolução % tem peça com origem Connect que não é de uma venda Connect deste projeto e desta empresa.', v_numero_orcamento
        USING ERRCODE = 'P0001';
    END IF;$b$);
  IF v_novo = v_def THEN RAISE EXCEPTION 'SPEC-300: trava de item sem origem nao encontrada em aprovar_orcamento_financeiro'; END IF;
  v_def := v_novo;

  -- (b) so linhas com item de origem chamam o estoque (a marcada Connect nao movimenta)
  v_novo := replace(v_novo,
$a$FROM public.orcamento_itens oi
      WHERE oi.orcamento_id = p_orcamento_id
    LOOP$a$,
$b$FROM public.orcamento_itens oi
      WHERE oi.orcamento_id = p_orcamento_id AND oi.projeto_item_origem_id IS NOT NULL
    LOOP$b$);
  IF v_novo = v_def THEN RAISE EXCEPTION 'SPEC-300: loop de devolucao nao encontrado em aprovar_orcamento_financeiro'; END IF;

  EXECUTE v_novo;
END $$;

NOTIFY pgrst, 'reload schema';
COMMIT;
