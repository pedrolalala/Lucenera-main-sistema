-- Rollback SPEC-300: desfaz os remendos nas duas funcoes e remove as colunas.
-- ATENCAO: se ja existir devolucao aprovada com linha de origem Connect, as colunas NAO sao removidas (aborta) para nao perder o rastro.
BEGIN;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.orcamento_itens WHERE origem_connect_venda IS NOT NULL) THEN
    RAISE EXCEPTION 'SPEC-300 rollback: existem linhas com origem Connect; trate-as antes de remover as colunas.';
  END IF;
END $$;

DO $$
DECLARE v_def text; v_novo text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
   WHERE p.proname = 'replace_orcamento_itens';
  v_novo := v_def;
  v_novo := replace(v_novo, $a$setor_origem, ja_com_cliente, origem_connect_venda, origem_connect_motivo
    FROM public.orcamento_itens$a$, $b$setor_origem, ja_com_cliente
    FROM public.orcamento_itens$b$);
  v_novo := replace(v_novo, $a$AS ja_com_cliente,
      NULLIF(item->>'origem_connect_venda', '') AS origem_connect_venda,
      NULLIF(item->>'origem_connect_motivo', '') AS origem_connect_motivo
$a$, $b$AS ja_com_cliente
$b$);
  v_novo := replace(v_novo, $a$false),
      origem_connect_venda = NULLIF(v_par.e->'item'->>'origem_connect_venda', ''),
      origem_connect_motivo = NULLIF(v_par.e->'item'->>'origem_connect_motivo', '')
$a$, $b$false)
$b$);
  v_novo := replace(v_novo, $a$ja_com_cliente, origem_connect_venda, origem_connect_motivo
  )$a$, $b$ja_com_cliente
  )$b$);
  v_novo := replace(v_novo, $a$false),
    NULLIF(e->'item'->>'origem_connect_venda', ''),
    NULLIF(e->'item'->>'origem_connect_motivo', '')
  FROM$a$, $b$false)
  FROM$b$);
  IF v_novo = v_def THEN RAISE EXCEPTION 'SPEC-300 rollback: nada a desfazer em replace_orcamento_itens'; END IF;
  EXECUTE v_novo;
END $$;

DO $$
DECLARE v_def text; v_novo text; v_ini int; v_fim int;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
   WHERE p.proname = 'aprovar_orcamento_financeiro';
  v_novo := v_def;
  v_novo := replace(v_novo, $a$AND oi.projeto_item_origem_id IS NULL AND oi.origem_connect_venda IS NULL$a$,
                            $b$AND oi.projeto_item_origem_id IS NULL$b$);
  v_novo := replace(v_novo, $a$WHERE oi.orcamento_id = p_orcamento_id AND oi.projeto_item_origem_id IS NOT NULL
    LOOP$a$, $b$WHERE oi.orcamento_id = p_orcamento_id
    LOOP$b$);
  -- remove o bloco de validacao da origem Connect
  v_ini := position(E'\n    -- SPEC-300: peça entregue antes da virada' IN v_novo);
  IF v_ini > 0 THEN
    v_fim := position($e$USING ERRCODE = 'P0001';
    END IF;$e$ IN substr(v_novo, v_ini));
    v_novo := substr(v_novo, 1, v_ini - 1) || substr(v_novo, v_ini + v_fim - 1 + length($e$USING ERRCODE = 'P0001';
    END IF;$e$));
  END IF;
  IF v_novo = v_def THEN RAISE EXCEPTION 'SPEC-300 rollback: nada a desfazer em aprovar_orcamento_financeiro'; END IF;
  EXECUTE v_novo;
END $$;

ALTER TABLE public.orcamento_itens DROP CONSTRAINT IF EXISTS orcamento_itens_origem_connect_chk;
ALTER TABLE public.orcamento_itens DROP COLUMN IF EXISTS origem_connect_venda, DROP COLUMN IF EXISTS origem_connect_motivo;

NOTIFY pgrst, 'reload schema';
COMMIT;
