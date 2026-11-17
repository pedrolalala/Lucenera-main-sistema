-- SPEC-319 rollback: volta a RPC da migration 251
BEGIN;
DROP FUNCTION IF EXISTS public.relatorio_movimentacao_item(text, date, date, text);
CREATE OR REPLACE FUNCTION public.relatorio_movimentacao_item(
  p_codigo text,
  p_inicio date DEFAULT NULL,
  p_fim date DEFAULT NULL,
  p_setor text DEFAULT NULL
)
RETURNS TABLE (
  ordem bigint,
  data timestamptz,
  codigo_produto integer,
  produto text,
  historico text,
  tipo text,
  quantidade numeric,
  saldo_setor numeric,
  saldo_geral numeric,
  setor text,
  usuario text,
  sistema text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
#variable_conflict use_column
DECLARE
  v_prod record;
  v_ini timestamptz := (coalesce(p_inicio, DATE '2000-01-01')::timestamp AT TIME ZONE 'America/Sao_Paulo');
  v_fim timestamptz := ((coalesce(p_fim, (now() AT TIME ZONE 'America/Sao_Paulo')::date) + 1)::timestamp AT TIME ZONE 'America/Sao_Paulo');
  v_setor text := nullif(btrim(coalesce(p_setor, '')), '');
BEGIN
  IF NOT public.pode_acessar_algum(ARRAY['dashboard-financeiro']) THEN
    RAISE EXCEPTION 'Sem acesso ao relatório de movimentação.' USING ERRCODE = '42501';
  END IF;

  SELECT pr.id, pr.codigo_produto, pr.nome INTO v_prod
    FROM public.produtos pr
   WHERE pr.codigo_produto::text = btrim(p_codigo)
   LIMIT 1;
  IF NOT FOUND THEN RETURN; END IF;

  RETURN QUERY
  WITH anterior AS (
    -- saldo de cada setor no começo do período
    SELECT DISTINCT ON (k.setor) k.setor, k.saldo_apos
      FROM public.estoque_kardex k
     WHERE k.produto_id = v_prod.id AND k.criado_em < v_ini AND (v_setor IS NULL OR k.setor = v_setor)
     ORDER BY k.setor, k.criado_em DESC, k.id DESC
  ),
  linhas AS (
    SELECT 0::bigint AS id, v_ini AS criado_em, 'Saldo anterior'::text AS historico, ''::text AS tipo,
           NULL::numeric AS quantidade, a.saldo_apos AS saldo_setor, a.setor,
           NULL::text AS usuario, NULL::text AS sistema, a.saldo_apos AS delta_geral
      FROM anterior a
    UNION ALL
    SELECT k.id, k.criado_em, k.historico, k.tipo, k.quantidade, k.saldo_apos, k.setor, k.usuario_nome, k.sistema,
           k.quantidade
      FROM public.estoque_kardex k
     WHERE k.produto_id = v_prod.id AND k.criado_em >= v_ini AND k.criado_em < v_fim
       AND (v_setor IS NULL OR k.setor = v_setor)
  )
  SELECT row_number() OVER w, l.criado_em, v_prod.codigo_produto, v_prod.nome, l.historico, l.tipo, l.quantidade,
         l.saldo_setor, sum(l.delta_geral) OVER w, l.setor, l.usuario, l.sistema
    FROM linhas l
  WINDOW w AS (ORDER BY l.id = 0 DESC, l.criado_em, l.id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
   ORDER BY 1;
END $$;

REVOKE ALL ON FUNCTION public.relatorio_movimentacao_item(text, date, date, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.relatorio_movimentacao_item(text, date, date, text) TO authenticated;
COMMIT;
