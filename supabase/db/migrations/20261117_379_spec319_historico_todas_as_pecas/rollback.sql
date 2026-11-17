-- SPEC-319 ajuste: volta a função da migration 378
BEGIN;
CREATE FUNCTION public.relatorio_movimentacao_item(
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
  sistema text,
  nota text,
  fornecedor text,
  venda text,
  cliente text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
#variable_conflict use_column
DECLARE
  v_prod record;
  v_role public.usuario_role;
  v_ini timestamptz := (coalesce(p_inicio, DATE '2000-01-01')::timestamp AT TIME ZONE 'America/Sao_Paulo');
  v_fim timestamptz := ((coalesce(p_fim, (now() AT TIME ZONE 'America/Sao_Paulo')::date) + 1)::timestamp AT TIME ZONE 'America/Sao_Paulo');
  v_setor text := nullif(btrim(coalesce(p_setor, '')), '');
BEGIN
  SELECT u.role INTO v_role FROM public.usuarios u WHERE u.id = auth.uid();
  IF v_role IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'Somente a Administração vê a movimentação do item.' USING ERRCODE = '42501';
  END IF;

  SELECT pr.id, pr.codigo_produto, pr.nome INTO v_prod
    FROM public.produtos pr
   WHERE pr.codigo_produto::text = btrim(p_codigo)
   LIMIT 1;
  IF NOT FOUND THEN RETURN; END IF;

  RETURN QUERY
  WITH anterior AS (
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
    SELECT k.id, k.criado_em, k.historico,
           CASE WHEN k.origem = 'devolucao' AND k.quantidade > 0 THEN 'D' ELSE k.tipo END,
           k.quantidade, k.saldo_apos, k.setor, k.usuario_nome, k.sistema, k.quantidade
      FROM public.estoque_kardex k
     WHERE k.produto_id = v_prod.id AND k.criado_em >= v_ini AND k.criado_em < v_fim
       AND (v_setor IS NULL OR k.setor = v_setor)
  ),
  enriq AS (
    SELECT l.*,
           substring(l.historico FROM '(?:Entrada NF|Cancelamento da NF) ([^ ]+)') AS nota,
           CASE WHEN l.historico ~ '^(Entrada NF|Cancelamento da NF) ' THEN nullif(substring(l.historico FROM ' — (.*)$'), '') END AS fornecedor,
           substring(l.historico FROM '^MOV ([0-9]+):')::bigint AS mov_num,
           substring(l.historico FROM '(?:Venda|venda) ([0-9A-Za-z-]+)') AS venda_num
      FROM linhas l
  )
  SELECT row_number() OVER w, e.criado_em, v_prod.codigo_produto, v_prod.nome, e.historico, e.tipo, e.quantidade,
         e.saldo_setor, sum(e.delta_geral) OVER w, e.setor, e.usuario, e.sistema,
         e.nota, e.fornecedor,
         coalesce(o.numero_venda, o.numero), coalesce(c.nome_empresa, c.nome)
    FROM enriq e
    LEFT JOIN public.movimentacoes_peca m ON m.numero = e.mov_num AND m.produto_id = v_prod.id
    LEFT JOIN public.projeto_itens pi ON pi.id = m.projeto_item_id
    LEFT JOIN LATERAL (
      SELECT oo.* FROM public.orcamentos oo
       WHERE (pi.orcamento_id IS NOT NULL AND oo.id = pi.orcamento_id)
          OR (pi.orcamento_id IS NULL AND e.venda_num LIKE 'ORC-%' AND oo.numero = e.venda_num)
          OR (pi.orcamento_id IS NULL AND e.venda_num NOT LIKE 'ORC-%' AND public._kardex_num(oo.numero_venda) = public._kardex_num(e.venda_num))
       ORDER BY oo.created_at
       LIMIT 1
    ) o ON true
    LEFT JOIN public.contatos c ON c.id = o.cliente_id
  WINDOW w AS (ORDER BY e.id = 0 DESC, e.criado_em, e.id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
   ORDER BY 1;
END $$;

REVOKE ALL ON FUNCTION public.relatorio_movimentacao_item(text, date, date, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.relatorio_movimentacao_item(text, date, date, text) TO authenticated;

COMMIT;
